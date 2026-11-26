# FLOW-ONLY SCORE: log loss of the ACTUAL transfers in every real exclusion where One Nation was still in the count.
# For each election: the per-seat flows from xgb_flow_conditional_override_for() fed that election's ACTUAL primaries
# (time-forward trees + history), switch 0 (trees) and 1 (One Nation calibration). Each real exclusion event whose
# (from, survivors) key the seat's override carries is scored: -sum(votes_to * log p_to) / sum(votes), p after the
# simulation's 0.15 smoothing toward uniform. Lower is better. Also the 2-way version (only the X v ONP part).
root <- "C:/dev/auspol"; options(auspol.root = root)
suppressMessages(devtools::load_all(".", quiet = TRUE)); suppressMessages(library(data.table))
SMOOTH <- 0.15
ARMS <- c("0", "0.25", "1", "3", "10", "20", "30")
SD <- fread(file.path(root, "output", "pooled-sharedetail.csv"), showProgress = FALSE)
TR <- fread(file.path(root, "output", "xgb-flows-v1-features.csv"), showProgress = FALSE,
            select = c("election", "seat", "round", "event_id", "from", "surv", "to", "votes"))
TR[, sk := normalise_seat(seat)]
dates <- election_dates()
prev_of <- function(e) {
  j <- sub("[0-9]+$", "", e)
  cand <- names(dates)[startsWith(names(dates), j) & grepl("^[a-z]+[0-9]{4}$", names(dates))]
  cand <- cand[dates[cand] < dates[[e]]]; if (!length(cand)) NA_character_ else cand[which.max(dates[cand])]
}
els <- intersect(unique(TR$election[grepl("ONP", TR$surv)]), unique(SD$pair))
cat("EVL0 elections with One Nation in a count and sharedetail rows:", paste(sort(els), collapse = " "), "\n")
res <- list()
for (e in sort(els)) {
  sd_e <- SD[SD$pair == e]
  M <- dcast(sd_e, seat ~ party, value.var = "actual_share", fill = 0)
  shares <- as.matrix(M[, -1]); rownames(shares) <- M$seat
  ovs <- list()
  for (arm in ARMS) {
    Sys.setenv(AUSPOL_ONP_FLOW_CAL = if (arm == "0") "0" else "1", AUSPOL_ONP_FLOW_CAL_K = if (arm == "0") "3" else arm)
    lg <- utils::capture.output(ovs[[arm]] <- tryCatch(xgb_flow_conditional_override_for(shares, e, prev_of(e), sub("[0-9]+$", "", e)), error = function(err) NULL))
  }
  Sys.setenv(AUSPOL_ONP_FLOW_CAL = "0")
  if (is.null(ovs[["0"]])) { cat("EVL!", e, "no override (pooled table era), skipped\n"); next }
  ev <- TR[TR$election == e & grepl("ONP", TR$surv) & TR$from != "ONP"]
  sk_rows <- normalise_seat(rownames(shares))
  for (id in unique(ev$event_id)) {
    x <- ev[ev$event_id == id]
    j <- match(x$sk[1], sk_rows); if (is.na(j)) next
    sv <- sort(strsplit(x$surv[1], "+", fixed = TRUE)[[1]]); key <- paste0(x$from[1], "|", paste(sv, collapse = "+"))
    row <- list(election = e, seat = rownames(shares)[j], key = key, votes = sum(x$votes))
    ok <- TRUE
    for (arm in ARMS) {
      o <- ovs[[arm]][[j]]; p <- if (is.null(o)) NULL else o[[key]]
      if (is.null(p)) { ok <- FALSE; break }
      p <- p[sv] / 100; p[is.na(p)] <- 0; p <- (1 - SMOOTH) * p / sum(p) + SMOOTH / length(sv)
      vt <- vapply(sv, function(s) sum(x$votes[x$to == s]), 0)
      row[[paste0("ll_", arm)]] <- -sum(vt * log(p)) / sum(vt)
      # two-way: the non-One-Nation major vs One Nation only
      xm <- intersect(c("LNP", "NAT", "ALP"), setdiff(sv, x$from[1]))
      if (length(xm)) {
        xm <- xm[1]; q <- p[xm] / (p[xm] + p["ONP"]); vx <- vt[xm]; vo <- vt["ONP"]
        row[[paste0("ll2_", arm)]] <- if (vx + vo > 0) -(vx * log(q) + vo * log(1 - q)) / (vx + vo) else NA_real_
        row[[paste0("pred2_", arm)]] <- 100 * q
        row$actual2 <- if (vx + vo > 0) 100 * vx / (vx + vo) else NA_real_
        row$vote2 <- vx + vo
      }
    }
    if (ok) res[[length(res) + 1L]] <- as.data.table(row)
  }
}
R <- rbindlist(res, fill = TRUE)
fwrite(R, "C:/Users/peteo/AppData/Local/Temp/claude/dc1a17ec65ae517e/524777ae-a578-47d5-83ed-6ec87cabdd9f/scratchpad/onpf/event_ksweep.csv")
cat("EVK done", nrow(R), "events
")
