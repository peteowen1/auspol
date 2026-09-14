# Per-party level_pred RMSE and bias, restricted to the 7 AEF-comparable
# elections, old (hand-blended) method vs new (xgboost raw-components) method.
#
# WHY. Pete's request, 2026-09-13: does letting xgboost see trend_level_raw /
# fund_level_raw separately (instead of a single hand-blended level_pred)
# produce a better-calibrated implied STATEWIDE prediction per party, on the
# exact 7 elections AE Forecasts also scores (scripts/build_aef_comparison.R's
# MAP table)?
#
# "New method" = each party's xgb_pred averaged across the seats it contested
# in that pair, weighted by that seat's actual votes (so it approximates a
# vote-weighted statewide share the same way level_pred is one number per
# pair/party, not an unweighted seat average which would over-count small
# seats equally with large ones).
#
# The two xgb inputs are whatever the caller has put at these paths -- this
# script does not build them, so check their provenance before quoting a
# number out of it:
#   output/xgb-primary-v6-oof-predictions-BASELINE4.csv  -- the comparison arm
#   output/xgb-primary-v6-oof-predictions.csv            -- v6's live output
# Written 2026-09-13 to compare AUSPOL_XGB_RAW_LEVEL=0 against =1 (the raw
# trend/fundamentals split, since refused). The =0 side used `level_pred` and
# `level_from_polls`; the =1 side replaced them with trend_level_raw/
# fund_level_raw.
#
# Actual = statewide % of formal first-preference votes per party, from
# output/candidacies.csv, informal rows already excluded upstream.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

PAIRS7 <- c("fed2022", "nsw2023", "vic2022", "qld2024", "fed2025", "wa2025", "sa2026")

C <- fread("output/candidacies.csv", showProgress = FALSE)
C <- C[election %in% PAIRS7]
tot_by_pair <- C[, .(tot = sum(votes, na.rm = TRUE)), by = .(pair = election)]
ACTUAL <- C[, .(v = sum(votes, na.rm = TRUE)), by = .(pair = election, party)]
ACTUAL <- merge(ACTUAL, tot_by_pair, by = "pair")
ACTUAL[, actual := 100 * v / tot]
ACTUAL <- ACTUAL[, .(pair, party, actual)]

OLD <- fread("output/level-pred.csv", showProgress = FALSE)[pair %in% PAIRS7]

xgb_stateweight <- function(oof_path) {
  # Share of the STATEWIDE vote, same denominator as `actual` and
  # `level_pred` (all votes cast in the pair, every seat). Two wrong versions
  # on the way here: (1) dividing by the party's own contested-seat vote
  # total inflates every minor party hugely, since IND's per-seat predictions
  # run 20-40% in the handful of seats an independent actually stands in; (2)
  # weighting each seat's xgb_pred by the PARTY's own actual vote count
  # (`votes`, per seat per candidate) rather than the SEAT's total formal
  # vote double-applies the actual result as a weight, dragging every major
  # party's aggregate down to a fraction of its true share. `xgb_pred` is a
  # share of a seat's total formal vote, so it must be weighted by that
  # seat's total (`tot`, one value per seat, constant across candidates),
  # not by any one candidate's own vote count.
  X <- fread(oof_path, showProgress = FALSE)
  X <- X[pair %in% PAIRS7]
  seat_tot <- unique(C[, .(pair = election, seat, seat_votes = tot)])
  M <- merge(X[, .(pair, seat, party, xgb_pred)], seat_tot, by = c("pair", "seat"), all.x = TRUE)
  M <- M[!is.na(seat_votes)]
  M[, .(pred_votes = sum(xgb_pred / 100 * seat_votes)), by = .(pair, party)] |>
    merge(tot_by_pair, by = "pair") |>
    (\(d) d[, .(pair, party, pred = 100 * pred_votes / tot)])()
}

XGB_OLD <- xgb_stateweight("output/xgb-primary-v6-oof-predictions-BASELINE4.csv")
XGB_NEW <- xgb_stateweight("output/xgb-primary-v6-oof-predictions.csv")

CLASSES <- c("ALP", "LNP", "GRN", "ONP", "IND", "OTH", "OTH_RIGHT")

build_side <- function(pred_dt, pred_col, label) {
  m <- merge(pred_dt, ACTUAL, by = c("pair", "party"))
  m[, err := get(pred_col) - actual]
  m[, .(bias = mean(err), rmse = sqrt(mean(err^2)), n = .N), by = party][, method := label]
}

r_old_lp  <- build_side(OLD[, .(pair, party, level_pred)], "level_pred", "old_level_pred")
r_old_xgb <- build_side(XGB_OLD, "pred", "old_xgb_baseline")
r_new_xgb <- build_side(XGB_NEW, "pred", "new_xgb_raw_level")

ALL <- rbindlist(list(r_old_lp, r_old_xgb, r_new_xgb))
ALL <- ALL[party %in% CLASSES]

cat(sprintf("\nPer-party statewide-level RMSE/bias, %d AEF elections (%s)\n",
            length(PAIRS7), paste(PAIRS7, collapse = ", ")))
cat("bias = mean(predicted - actual): negative means we UNDER-predict that party's vote share, positive OVER-predicts. rmse: lower is better, in percentage points.\n\n")

WIDE_BIAS <- dcast(ALL, party ~ method, value.var = "bias")
WIDE_RMSE <- dcast(ALL, party ~ method, value.var = "rmse")
WIDE_N    <- dcast(ALL, party ~ method, value.var = "n")

setcolorder(WIDE_BIAS, c("party", "old_level_pred", "old_xgb_baseline", "new_xgb_raw_level"))
setcolorder(WIDE_RMSE, c("party", "old_level_pred", "old_xgb_baseline", "new_xgb_raw_level"))

cat("BIAS (pred - actual, pp):\n"); print(WIDE_BIAS[order(party)])
cat("\nRMSE (pp):\n"); print(WIDE_RMSE[order(party)])
cat("\nn (party-elections, of 7 possible):\n"); print(WIDE_N[order(party)])

fwrite(ALL, "output/level-pred-aef-compare.csv")
cat("\nwrote output/level-pred-aef-compare.csv\n")
