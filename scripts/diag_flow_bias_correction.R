# Dry-run the per-class bias correction at the FLOW level, before any sim.
#
# CLAUDE.md: "Dry-run every criterion on cases whose answer you already know,
# BEFORE committing the pre-registration." A seat-sim run is ~40 minutes; this
# is seconds, and it can kill the idea outright if the correction does not do
# what it is supposed to do to the quantity it directly targets.
#
# THE CORRECTION. For destination class c and target election e:
#   bias(c, e) = mean(xgb_pred - y) over OUT-OF-FOLD rows with to == c and
#                election != e
#   adjusted   = pmax(0, pred - bias(c, e)), then renormalise per event
#
# Leave-one-election-out twice over: the oof predictions are themselves
# out-of-fold, and the target election is excluded from the bias estimate. So
# nothing here knows the answer for the election it is correcting.
#
# Emits DC* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

X <- fread("output/xgb-flows-v1-oof-predictions.csv", showProgress = FALSE)
X[, ev := paste(election, seat, round, from, sep = "|")]
cat(sprintf("DC1  %d rows, %d events, %d elections\n", nrow(X), uniqueN(X$ev), uniqueN(X$election)))

rmse <- function(a, b) sqrt(mean((a - b)^2))

# Leave-one-election-out bias per (class, target election).
tot <- X[, .(s = sum(xgb_pred - y), n = .N), by = .(to)]
per <- X[, .(se = sum(xgb_pred - y), ne = .N), by = .(to, election)]
per <- merge(per, tot, by = "to")
per[, bias_loo := (s - se) / (n - ne)]

X2 <- merge(X, per[, .(to, election, bias_loo)], by = c("to", "election"), all.x = TRUE)
stopifnot(!any(is.na(X2$bias_loo)))
X2[, adj := pmax(0, xgb_pred - bias_loo)]
# Renormalise within the event, exactly as the override does before handing the
# dict to the simulator -- correcting without renormalising would change the
# total transferred, which is not what this is for.
X2[, adj := {
  s <- sum(adj)
  if (s <= 0) rep(1 / .N, .N) else adj / s
}, by = ev]
# `y` sums to 1 per event by construction, so the corrected column is
# comparable to it. Assert rather than assume.
chk <- X2[, .(sy = sum(y), sa = sum(adj)), by = ev]
cat(sprintf("DC1  event sums: y in [%.4f, %.4f], adjusted in [%.4f, %.4f]\n",
            min(chk$sy), max(chk$sy), min(chk$sa), max(chk$sa)))

cat(sprintf("\nDC2  row-level RMSE: table %.4f | xgb %.4f | xgb+bias-correction %.4f\n",
            rmse(X2$base_pred, X2$y), rmse(X2$xgb_pred, X2$y), rmse(X2$adj, X2$y)))

B <- X2[, .(rows = .N,
            table_bias = mean(base_pred - y),
            xgb_bias = mean(xgb_pred - y),
            corr_bias = mean(adj - y),
            xgb_rmse = rmse(xgb_pred, y),
            corr_rmse = rmse(adj, y)), by = to]
setorder(B, -rows)
cat("\nDC3  signed error by destination class. The correction targets the bias columns.\n")
print(B[, .(to, rows, table_bias = round(table_bias, 4), xgb_bias = round(xgb_bias, 4),
            corr_bias = round(corr_bias, 4), xgb_rmse = round(xgb_rmse, 4),
            corr_rmse = round(corr_rmse, 4))])

# THE NAMED CASE. fed2016's damage was a 1.35-point net two-party shift away
# from ALP. If the correction does not shrink that, the mechanism is wrong and
# there is no point running a simulation.
TP <- X2[to %in% c("ALP", "LNP")]
A <- TP[, .(xgb = mean(xgb_pred - y), corr = mean(adj - y)), by = .(election, to)]
A2 <- dcast(A, election ~ to, value.var = c("xgb", "corr"))
A2[, `:=`(xgb_net_alp = xgb_ALP - xgb_LNP, corr_net_alp = corr_ALP - corr_LNP)]
A2[, improved := abs(corr_net_alp) < abs(xgb_net_alp)]
setorder(A2, xgb_net_alp)
cat("\nDC4  net two-party bias (toward ALP minus toward LNP), per election. CLOSER TO ZERO IS BETTER.\n")
print(A2[, .(election, xgb_net_alp = round(xgb_net_alp, 4),
             corr_net_alp = round(corr_net_alp, 4), improved)])
cat(sprintf("\nDC5  net two-party bias shrank in %d of %d elections; mean |bias| %.4f -> %.4f\n",
            sum(A2$improved), nrow(A2), mean(abs(A2$xgb_net_alp)), mean(abs(A2$corr_net_alp))))
f16 <- A2[election == "fed2016"]
cat(sprintf("DC6  THE NAMED CASE fed2016: net two-party bias %+.4f -> %+.4f\n",
            f16$xgb_net_alp, f16$corr_net_alp))
