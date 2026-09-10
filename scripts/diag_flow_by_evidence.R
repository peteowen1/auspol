# Does the xgb flow model beat the lookup table EVERYWHERE, or only where the
# table has nothing to say?
#
# Two seat walkthroughs (scripts/diag_flow_one_seat.R) found the same shape in
# both regressing pairs: on a key the table HAS measured, xgb pulls the
# distribution back toward a corpus-wide average and loses a real local signal.
#
#   wa2001 Alfred Cove, ALP|IND+LNP:  table IND 90.8 / LNP 9.2
#                                       xgb IND 72.8 / LNP 27.2   (IND won)
#   fed2016 Herbert,  GRN|ALP+IND+LNP: table ALP 49.1 / IND 40.7 / LNP 10.3
#                                       xgb ALP 46.7 / IND 33.6 / LNP 19.7
#
# Both walkthroughs also found the override supplying ~90 keys per seat the
# table never had (118 vs 13 in Alfred Cove, 117 vs 28 in Herbert), where the
# shipped model falls back to pooled.
#
# So the anecdote says: xgb HURTS on well-measured keys and probably HELPS on
# unmeasured ones. That is a testable claim on all 36,064 rows, and it decides
# whether the fix is "drop the flow model" or "use it only where the table is
# thin" -- which is the shrinkage principle in CLAUDE.md, applied to flows.
#
# base_pred is the shipped mechanism's own prediction for the same row
# (0.85 * conditional-or-pooled + 0.15 * uniform) and cond_rate is computed
# leave-one-election-out, so both columns are honest. xgb_pred is out-of-fold.
#
# Emits DE* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

X <- fread("output/xgb-flows-v1-oof-predictions.csv", showProgress = FALSE)
cat(sprintf("DE1  %d rows, %d elections\n", nrow(X), uniqueN(X$election)))

rmse <- function(a, b) sqrt(mean((a - b)^2))
cat(sprintf("DE1  overall row-level RMSE (share of pot, 0-1): table %.4f | xgb %.4f\n",
            rmse(X$base_pred, X$y), rmse(X$xgb_pred, X$y)))

# THE SPLIT THAT MATTERS. cond_n is how many historical events back this exact
# (from, survivor-set, to) cell, leave-one-election-out. cond_n == 0 means the
# table has NO measurement and the shipped model falls back; the build_flow_matrix
# min_n default is 3, so cond_n < 3 is where the shipped model also falls back.
X[, bucket := cut(cond_n, breaks = c(-1, 0, 2, 9, 29, 99, Inf),
                  labels = c("0 (no data)", "1-2 (below min_n)", "3-9", "10-29", "30-99", "100+"))]
B <- X[, .(rows = .N,
           table_rmse = rmse(base_pred, y),
           xgb_rmse = rmse(xgb_pred, y)), by = bucket]
B[, gain := table_rmse - xgb_rmse]
B[, pct := 100 * gain / table_rmse]
setorder(B, bucket)
cat("\nDE2  RMSE by how much evidence the TABLE has for that cell. LOWER IS BETTER.\n")
cat("     gain = table - xgb, so POSITIVE means the xgb model is better there.\n")
print(B[, .(bucket, rows, table_rmse = round(table_rmse, 4), xgb_rmse = round(xgb_rmse, 4),
            gain = round(gain, 4), pct = round(pct, 1))])

# WHAT WOULD A HYBRID SCORE? Use the table where it is well-measured and xgb
# where it is thin, at each possible cut. This is the whole decision in one
# table: if the best cut is at the top end, the flow model adds nothing the
# table does not already have; if it is low, the model's real value is filling
# gaps, not overriding measurements.
cat("\nDE3  hybrid: xgb only where cond_n < k, table otherwise. LOWER IS BETTER.\n")
cuts <- c(0, 1, 3, 10, 30, 100, Inf)
H <- rbindlist(lapply(cuts, function(k) {
  use_xgb <- X$cond_n < k
  data.table(k = k, share_xgb = mean(use_xgb),
             rmse = rmse(ifelse(use_xgb, X$xgb_pred, X$base_pred), X$y))
}))
H[, vs_table := rmse - rmse(X$base_pred, X$y)]
H[, vs_allxgb := rmse - rmse(X$xgb_pred, X$y)]
print(H[, .(k, share_xgb = round(share_xgb, 3), rmse = round(rmse, 4),
            vs_table = round(vs_table, 4), vs_allxgb = round(vs_allxgb, 4))])
best <- H[which.min(rmse)]
cat(sprintf("DE3  best cut k = %s: RMSE %.4f, against %.4f for the table alone and %.4f for xgb everywhere\n",
            format(best$k), best$rmse, rmse(X$base_pred, X$y), rmse(X$xgb_pred, X$y)))

# The two regressing pairs, on their own. A rule chosen on the pooled corpus
# has to be checked on the cases that motivated it -- CLAUDE.md's "scope the
# metric to the change".
for (e in c("wa1996", "fed2016")) {
  E <- X[election == e]
  if (!nrow(E)) { cat(sprintf("\nDE4  %s: no rows in the flow corpus\n", e)); next }
  cat(sprintf("\nDE4  %s (%d rows): table %.4f | xgb %.4f | best hybrid %.4f at k=%s\n",
              e, nrow(E), rmse(E$base_pred, E$y), rmse(E$xgb_pred, E$y),
              min(sapply(cuts, function(k) rmse(ifelse(E$cond_n < k, E$xgb_pred, E$base_pred), E$y))),
              format(cuts[which.min(sapply(cuts, function(k) rmse(ifelse(E$cond_n < k, E$xgb_pred, E$base_pred), E$y)))])))
}
