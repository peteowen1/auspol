# PRIMARY METRIC for docs/plans/prereg-onp-flow-calibration-2026-11-26.md: flow-only One Nation TCP error.
# Each seat's ACTUAL primaries go through the count (distribute_preferences()) with the shipped per-seat flows
# (tf2, xgb_flow_conditional_override_for() fed the actual primaries, time-forward pooled table behind it) at
# AUSPOL_ONP_FLOW_CAL 0 and 1. Scored on seats whose ACTUAL final two was One Nation v Labor or the Coalition:
# |predicted One Nation share of the final two - actual|, points, where the predicted final two is the actual pair
# under both arms (so both arms are scored on the same seats). Full preferential elections only (NSW exhausts).
#
# Usage: Rscript scripts/score_onp_flow_cal.R <root with output/ and external/> <out_csv> [pairs]
args <- commandArgs(TRUE)
root <- normalizePath(args[1]); out_csv <- args[2]
pairs <- if (length(args) >= 3) strsplit(args[3], ",")[[1]] else c("fed2016", "fed2019", "fed2025", "qld2020", "qld2024", "sa2026")
options(auspol.root = root)
suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(data.table))
SMOOTH <- 0.15
SD <- fread(file.path(root, "output", "pooled-sharedetail.csv"), showProgress = FALSE)
TR <- fread(file.path(root, "output", "xgb-flows-v1-features.csv"), showProgress = FALSE,
            select = c("election", "seat", "round", "event_id", "from", "surv", "to", "votes"))
TR[, sk := normalise_seat(seat)]
RAW <- unique(TR[, c("election", "seat", "round", "from", "to", "votes")])
dates <- election_dates()
prev_of <- function(e) {
  j <- sub("[0-9]+$", "", e)
  cand <- names(dates)[startsWith(names(dates), j) & grepl("^[a-z]+[0-9]{4}$", names(dates))]
  cand <- cand[dates[cand] < dates[[e]]]
  if (!length(cand)) NA_character_ else cand[which.max(dates[cand])]
}
res <- list()
for (e in pairs) {
  pe <- prev_of(e); region <- sub("[0-9]+$", "", e)
  sd_e <- SD[SD$pair == e]
  if (!nrow(sd_e)) { cat("SOC! no sharedetail rows for", e, "\n"); next }
  M <- dcast(sd_e, seat ~ party, value.var = "actual_share", fill = 0)
  shares <- as.matrix(M[, -1]); rownames(shares) <- M$seat
  # actual final two from the count: survivors of each seat's last round
  ev <- TR[TR$election == e]
  last <- ev[, list(surv = surv[round == max(round)][1]), by = "sk"]
  fin <- last[last$surv %in% c("LNP+ONP", "ALP+ONP")]
  if (!nrow(fin)) { cat("SOC  ", e, ": no One Nation final count\n"); next }
  past <- RAW[elections_before(RAW$election, e)]
  fm <- build_flow_matrix(past, min_n = 3L)
  ovs <- list()
  for (arm in c("0", "1")) {
    Sys.setenv(AUSPOL_ONP_FLOW_CAL = arm)
    lg <- utils::capture.output(o <- xgb_flow_conditional_override_for(shares, e, pe, region))
    if (arm == "1" && !any(grepl("^ONC1 ", lg))) stop(e, ": calibration did not apply (no ONC1 line)")
    cat(sprintf("SOC  %s arm %s: %s\n", e, arm, paste(grep("^ONC1|XF9  per-seat", lg, value = TRUE), collapse = " / ")))
    ovs[[arm]] <- o
  }
  Sys.setenv(AUSPOL_ONP_FLOW_CAL = "0")
  sk_rows <- normalise_seat(rownames(shares))
  for (i in seq_len(nrow(fin))) {
    j <- match(fin$sk[i], sk_rows); if (is.na(j)) next
    pr <- strsplit(fin$surv[i], "+", fixed = TRUE)[[1]]; x_cls <- setdiff(pr, "ONP")
    v <- shares[j, ]; v <- v[v > 0]
    # actual: One Nation's share of the final two, from the transfers (full preferential)
    tv <- ev[ev$sk == fin$sk[i]]
    t_x <- sum(tv$votes[tv$to == x_cls]); t_o <- sum(tv$votes[tv$to == "ONP"])
    rest <- 100 - v[["ONP"]] - v[[x_cls]]
    act <- v[["ONP"]] + rest * t_o / (t_x + t_o)
    row <- data.table(pair = e, seat = rownames(shares)[j], fin = fin$surv[i], onp_pv = v[["ONP"]], x_pv = v[[x_cls]], actual = act)
    for (arm in c("0", "1")) {
      cond <- fm$conditional; o <- ovs[[arm]][[j]]
      if (!is.null(o)) cond[names(o)] <- o
      d <- distribute_preferences(v, conditional = cond, pooled = fm$pooled, smooth = SMOOTH)
      ok <- setequal(d$final_two, pr)
      p_onp <- if (ok) 100 * d$final_shares[["ONP"]] / sum(d$final_shares) else NA_real_
      row[[paste0("pred_", arm)]] <- p_onp
      row[[paste0("winner_", arm)]] <- d$winner
    }
    res[[length(res) + 1L]] <- row
  }
}
R <- rbindlist(res)
R[, `:=`(err_0 = abs(pred_0 - actual), err_1 = abs(pred_1 - actual), signed_0 = pred_0 - actual, signed_1 = pred_1 - actual)]
fwrite(R, out_csv)
B <- R[is.finite(err_0) & is.finite(err_1)]
cat(sprintf("\nSOC1 One Nation final counts: %d seats over %d elections; scored (actual pair predicted under both arms): %d\n",
            nrow(R), uniqueN(R$pair), nrow(B)))
print(B[, .(seats = .N, mae_off = round(mean(err_0), 2), mae_on = round(mean(err_1), 2),
            bias_off = round(mean(signed_0), 2), bias_on = round(mean(signed_1), 2)), by = .(pair, fin)])
# pooled change, SE clustered on election
per_e <- B[, list(n = .N, d = sum(err_1 - err_0)), by = "pair"]
dbar <- sum(per_e$d) / sum(per_e$n)
G <- nrow(per_e)
se <- if (G > 1) sqrt(G / (G - 1) * sum((per_e$d - per_e$n * dbar)^2)) / sum(per_e$n) else NA_real_
cat(sprintf("SOC2 pooled One Nation TCP MAE off %.2f -> on %.2f, change %+.2f points (SE %.2f, clustered on %d elections; n %d seats)\n",
            mean(B$err_0), mean(B$err_1), dbar, se, G, nrow(B)))
cat(sprintf("SOC3 bias (predicted minus actual One Nation share): off %+.2f, on %+.2f\n", mean(B$signed_0), mean(B$signed_1)))
cat(sprintf("SOC4 actual winner reproduced from actual primaries: off %d / on %d of %d\n",
            sum(R$winner_0 == ifelse(R$actual > 50, "ONP", sub("[+]?ONP[+]?", "", R$fin))),
            sum(R$winner_1 == ifelse(R$actual > 50, "ONP", sub("[+]?ONP[+]?", "", R$fin))), nrow(R)))
