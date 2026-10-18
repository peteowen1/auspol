# FLOW-ONLY SCORE: judge preference flows with the primary vote taken out.
#
# Seat log loss scores flows and primaries together, so a flow change can be
# blamed for a primary miss it stops hiding: fed2025's flows got MORE accurate
# under the recency arm while its seat log loss got worse, because Labor's
# primary was under-called 4.6 points and the old flows had been offsetting it
# (docs/reviews/lnp-onp-flows-by-election-2026-10-11.md). This scores flows
# against the count alone, two ways, for every flow configuration named below:
#
#  E  EVENT level: at every real exclusion in the election (its actual excluded
#     party and actual survivor set), the predicted split against the actual
#     split, vote-weighted absolute error in points. Lower is better.
#  W  WINNER level: each seat's ACTUAL first preferences run through
#     distribute_preferences() with the configuration's flows; winner right or
#     wrong against the actual winner. Higher is better.
#
# Flows per configuration: the per-seat xgb override
# (xgb_flow_conditional_override_for(), fed the seat's ACTUAL primaries), then a
# time-forward pooled table (build_flow_matrix() over every earlier election's
# transfers, identical across configurations) where the override has no key,
# smoothing 0.15 as published. NSW is optional preferential: exhaustion is not
# modelled here, so its winner column is indicative only.
#
# Run: Rscript scripts/score_flows_oracle.R [pairs comma-separated | all]
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
a <- commandArgs(TRUE)
# "shipped" is the leave-one-out family that shipped until 2026-10-12 (tf2 since);
# the label is kept so output/flow-oracle-score.csv reads as it did in the review.
CONFIGS <- list(
  shipped   = c(AUSPOL_FLOW_TF = "0", AUSPOL_FLOW_MODEL_TAG = "none", AUSPOL_FLOW_RATE_HL = "0"),
  infer_hl2 = c(AUSPOL_FLOW_TF = "0", AUSPOL_FLOW_MODEL_TAG = "none", AUSPOL_FLOW_RATE_HL = "2"),
  tf0       = c(AUSPOL_FLOW_TF = "1", AUSPOL_FLOW_MODEL_TAG = "tf0", AUSPOL_FLOW_RATE_HL = "0"),
  tf2       = c(AUSPOL_FLOW_TF = "1", AUSPOL_FLOW_MODEL_TAG = "tf2", AUSPOL_FLOW_RATE_HL = "2"))
SMOOTH <- 0.15
# AUSPOL_FLOW_ORACLE_CONFIGS=tf2 scores only the named configurations (comma-separated) and then writes
# output/flow-oracle-score-<names>.csv, so the full table above is never overwritten by a partial run. Every
# event's predicted and actual split for the SHIPPED configuration (tf2) goes to output/flow-event-residuals.csv
# (pair, seat key, excluded class, survivors, destination, predicted, actual, event votes): the input for
# measuring how much of the flow miss is statewide (NEXT-STEPS, statewide flow shocks, 2026-10-17).
.only <- Sys.getenv("AUSPOL_FLOW_ORACLE_CONFIGS", "")
if (nzchar(.only)) {
  .keep <- trimws(strsplit(.only, ",")[[1]])
  if (!all(.keep %in% names(CONFIGS))) stop("AUSPOL_FLOW_ORACLE_CONFIGS names unknown configuration(s): ", paste(setdiff(.keep, names(CONFIGS)), collapse = ", "))
  CONFIGS <- CONFIGS[.keep]
}
EV_OUT <- list()

SD <- fread("output/pooled-sharedetail.csv", showProgress = FALSE)
pairs <- sort(unique(SD$pair))
if (length(a) && a[1] != "all") pairs <- intersect(pairs, strsplit(a[1], ",")[[1]])
dates <- election_dates()

# ACTUAL WINNERS from output/published-predictions.csv (`won`, one row per
# candidate, every election). Exactly one winner per seat, or the seat is refused.
PP <- fread("output/published-predictions.csv", select = c("pair", "seat", "party", "won"), showProgress = FALSE)
W <- PP[PP$won %in% TRUE]
W[, sk := normalise_seat(seat)]
W <- W[, list(actual = party[1], n_won = .N), by = c("pair", "sk")]
if (any(W$n_won != 1L)) stop("seats with more than one recorded winner: ",
                             paste(head(paste(W$pair, W$sk)[W$n_won != 1L], 3), collapse = "; "))
cat(sprintf("FLO0  actual winners: %d seats over %d elections\n", nrow(W), uniqueN(W$pair)))

# TRANSFERS: the shared historical corpus (same file the flow trees learn from).
TR <- fread("output/xgb-flows-v1-features.csv", showProgress = FALSE,
            select = c("election", "seat", "round", "event_id", "from", "surv", "to", "votes", "event_votes"))
TR[, sk := normalise_seat(seat)]
RAW <- unique(TR[, c("election", "seat", "round", "from", "to", "votes")])

prev_of <- function(e) {
  j <- sub("[0-9]+$", "", e)
  cand <- names(dates)[startsWith(names(dates), j) & grepl("^[a-z]+[0-9]{4}$", names(dates))]
  cand <- cand[dates[cand] < dates[[e]]]
  if (!length(cand)) NA_character_ else cand[which.max(dates[cand])]
}

with_env <- function(vals, code) {
  old <- Sys.getenv(names(vals), unset = NA)
  do.call(Sys.setenv, as.list(vals))
  on.exit({ for (n in names(old)) if (is.na(old[[n]])) Sys.unsetenv(n) else do.call(Sys.setenv, stats::setNames(list(old[[n]]), n)) })
  force(code)
}

res <- list()
for (e in pairs) {
  region <- sub("[0-9]+$", "", e); pe <- prev_of(e)
  sd_e <- SD[SD$pair == e]
  M <- dcast(sd_e, seat ~ party, value.var = "actual_share", fill = 0)
  shares <- as.matrix(M[, -1]); rownames(shares) <- M$seat
  win_e <- W[W$pair == e]
  # time-forward pooled fallback, same for every configuration
  past <- RAW[elections_before(RAW$election, e)]
  fm <- if (nrow(past)) build_flow_matrix(past, min_n = 3L) else list(conditional = list(), pooled = list())
  ev <- TR[TR$election == e]
  ev_split <- split(ev, ev$event_id)
  for (cf in names(CONFIGS)) {
    ov <- with_env(CONFIGS[[cf]], tryCatch({
      o <- NULL
      log_lines <- utils::capture.output(o <- xgb_flow_conditional_override_for(shares, e, pe, region))
      if (cf != "shipped" && !any(grepl(if (CONFIGS[[cf]][["AUSPOL_FLOW_TF"]] == "1") "time-forward flow features" else "recency-weighted", log_lines)))
        stop("configuration did not apply (no confirming XF9 line)")
      o
    }, error = function(err) { message(sprintf("%s %s: override failed: %s", e, cf, conditionMessage(err))); NULL }))
    names_ov <- if (is.null(ov)) character(0) else normalise_seat(names(ov))
    seat_flows <- function(sk) {
      i <- match(sk, names_ov)
      cond <- fm$conditional
      if (!is.na(i) && !is.null(ov[[i]])) cond[names(ov[[i]])] <- ov[[i]]
      cond
    }
    # E: event level
    eerr <- NA_real_; n_ev <- 0L
    if (nrow(ev)) {
      evs <- unique(ev[, c("event_id", "sk", "from", "surv", "event_votes")])
      cache <- list(); err <- 0; wsum <- 0
      for (k in seq_len(nrow(evs))) {
        sk <- evs$sk[k]
        if (is.null(cache[[sk]])) cache[[sk]] <- seat_flows(sk)
        surv <- strsplit(evs$surv[k], "+", fixed = TRUE)[[1]]
        key <- paste0(evs$from[k], "|", evs$surv[k])
        row <- cache[[sk]][[key]]; if (is.null(row)) row <- fm$pooled[[evs$from[k]]]
        w <- setNames(rep(0, length(surv)), surv)
        if (!is.null(row)) { r <- row[intersect(names(row), surv)]; if (length(r)) w[names(r)] <- pmax(0, r) }
        p <- if (sum(w) <= 0) rep(1 / length(surv), length(surv)) else (1 - SMOOTH) * w / sum(w) + SMOOTH / length(surv)
        names(p) <- surv
        act <- ev_split[[evs$event_id[k]]]
        y <- setNames(act$votes / evs$event_votes[k], act$to)
        y_full <- setNames(rep(0, length(surv)), surv); y_full[names(y)] <- y
        err <- err + evs$event_votes[k] * sum(abs(p - y_full)) / 2
        if (cf == "tf2") EV_OUT[[length(EV_OUT) + 1L]] <- data.table(pair = e, sk = sk, from = evs$from[k], surv = evs$surv[k],
                                                                       to = names(p), pred = unname(p), actual = unname(y_full[names(p)]),
                                                                       event_votes = evs$event_votes[k])
        wsum <- wsum + evs$event_votes[k]
      }
      eerr <- 100 * err / wsum; n_ev <- nrow(evs)
    }
    # W: winner level
    right <- 0L; n_w <- 0L
    for (s in rownames(shares)) {
      sk <- normalise_seat(s); aw <- win_e$actual[win_e$sk == sk]
      if (length(aw) != 1L) next
      v <- shares[s, ]; v <- v[v > 0]
      if (length(v) < 2) next
      d <- distribute_preferences(v, conditional = seat_flows(sk), pooled = fm$pooled, smooth = SMOOTH)
      n_w <- n_w + 1L; right <- right + as.integer(d$winner == aw)
    }
    res[[length(res) + 1]] <- data.table(pair = e, config = cf, event_err = eerr, events = n_ev,
                                         winners_right = right, seats = n_w, override = !is.null(ov))
  }
  cat(sprintf("%-8s done (prev %s, %d seats with a recorded winner)\n", e, pe, nrow(win_e)))
}
R <- rbindlist(res)
fwrite(R, if (nzchar(.only)) sprintf("output/flow-oracle-score-%s.csv", gsub(",", "-", .only)) else "output/flow-oracle-score.csv")
if (length(EV_OUT)) {
  EV <- rbindlist(EV_OUT)
  fwrite(EV, "output/flow-event-residuals.csv")
  cat(sprintf("FOE1 wrote output/flow-event-residuals.csv: %d rows, %d events, %d elections (shipped tf2 flows)\n",
              nrow(EV), uniqueN(EV[, paste(pair, sk, from, surv, event_votes)]), uniqueN(EV$pair)))
}
cat("\nE = vote-weighted absolute error of the predicted split at each real exclusion, points (lower is better)\n")
cat("W = seats whose actual winner comes out of ACTUAL primaries + these flows (higher is better)\n")
wideE <- dcast(R, pair ~ config, value.var = "event_err"); wideW <- dcast(R, pair ~ config, value.var = "winners_right")
setcolorder(wideE, c("pair", names(CONFIGS))); setcolorder(wideW, c("pair", names(CONFIGS)))
print(merge(wideE, R[config == "shipped", c("pair", "events", "seats")], by = "pair"), digits = 3)
print(wideW)
# COVERAGE, printed: a configuration whose override came back NULL was scored
# on the pooled table alone and looks like "no effect". Only elections where
# EVERY configuration loaded its own model are pooled (review 2026-10-12).
cov <- dcast(R, pair ~ config, value.var = "override")
cat("\nFLO1  per-seat override loaded (FALSE = scored on the pooled table alone):\n"); print(cov)
fair <- R[, list(all_ov = all(override)), by = pair][all_ov == TRUE, pair]
cat(sprintf("FLO2  pooled over %d of %d elections where every configuration loaded its own model; excluded: %s\n",
            length(fair), length(pairs), paste(setdiff(pairs, fair), collapse = ", ")))
tot <- R[pair %in% fair, list(event_err_wmean = sum(event_err * events, na.rm = TRUE) / sum(events[!is.na(event_err)]),
                              exclusions = sum(events[!is.na(event_err)]),
                              winners_right = sum(winners_right), seats = sum(seats)), by = config]
print(tot)
