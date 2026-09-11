# Why do MORE ACCURATE flows produce WORSE seat calls in some pairs?
#
# The chain of evidence so far:
#   - the flow override costs wa2001 +0.048 and fed2016 +0.035 seat log loss;
#   - but the xgb flow model beats the table the harness actually uses in 7 of
#     8 elections, and on fed2016 by 19% (0.0848 vs 0.1049 RMSE);
#   - and fed2016's damage is broad (83 seats worse), all of it in marginal
#     seats the model already gave LOW probability to the party that won.
#
# THE HYPOTHESIS. A preference flow is applied to the primary-vote pot. If the
# primary prediction is badly wrong, the table's own flow error can be
# COMPENSATING for it, and replacing the table with a more accurate flow
# removes the compensation and exposes the primary error.
#
#   Herbert fed2016: model said LNP 42.55, actual 35.50; ONP 1.86, actual 13.53.
#   With LNP's pot inflated by 7 points, distributing GRN preferences to LNP
#   more accurately (19.7% vs the table's 10.3%) compounds the error instead of
#   correcting it.
#
# THE TESTABLE PREDICTION. If that is the mechanism, the flow model should help
# MORE in pairs where the primary prediction is good, and hurt where it is bad.
# The 2x2 already hints at it: flows are worth -0.0037 on shipped primaries and
# -0.0068 on xgb primaries -- nearly twice as much once the pot is better.
#
# This tests it directly across all 22 pairs. A prediction made before looking
# is worth more than one fitted after, so: the correlation should be POSITIVE
# (worse primary RMSE -> more positive, i.e. worse, flow delta).
#
# Emits DP* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

BP <- fread("output/pf-arms-by-pair.csv", showProgress = FALSE)
if (!all(c("p1f0", "p1f1") %in% names(BP))) stop("run scripts/pool_pf_arms.R first")
BP[, flow_delta := p1f1 - p1f0]

SD <- fread("output/pooled-sharedetail.csv", showProgress = FALSE)
PR <- SD[, .(primary_rmse = sqrt(mean((pred_share - actual_share)^2, na.rm = TRUE)),
             cells = .N), by = .(pair)]

M <- merge(BP[, .(pair, n, p1f0, p1f1, flow_delta)], PR, by = "pair")
setorder(M, primary_rmse)
cat("\nDP1  per pair: how good the PRIMARY prediction was, against what the xgb flows did to seat log loss\n")
cat("     primary_rmse: seat-share error in percentage points, lower is better.\n")
cat("     flow_delta:   seat log loss with xgb flows MINUS with table flows; NEGATIVE = flows helped.\n")
print(M[, .(pair, n, primary_rmse = round(primary_rmse, 3), flow_delta = round(flow_delta, 4))])

ct <- cor.test(M$primary_rmse, M$flow_delta)
cat(sprintf("\nDP2  correlation between primary error and flow damage: r = %.3f, p = %.3f, n = %d pairs\n",
            unname(ct$estimate), ct$p.value, nrow(M)))
cat("DP2  the hypothesis predicts a POSITIVE r: the worse the primary pot, the more a better flow hurts.\n")

# Split at the median so the effect has a size, not just a sign. A correlation
# on 22 points is thin; the halves say whether it is worth acting on.
med <- stats::median(M$primary_rmse)
lo <- M[primary_rmse <= med]; hi <- M[primary_rmse > med]
cat(sprintf("\nDP3  pairs with the BETTER half of primary predictions (rmse <= %.3f, n=%d): mean flow delta %+.4f, helped in %d of %d\n",
            med, nrow(lo), mean(lo$flow_delta), sum(lo$flow_delta < 0), nrow(lo)))
cat(sprintf("DP3  pairs with the WORSE half  (rmse > %.3f, n=%d): mean flow delta %+.4f, helped in %d of %d\n",
            med, nrow(hi), mean(hi$flow_delta), sum(hi$flow_delta < 0), nrow(hi)))
tt <- stats::t.test(hi$flow_delta, lo$flow_delta)
cat(sprintf("DP3  difference between the halves: %+.4f, t = %.2f, p = %.3f\n",
            mean(hi$flow_delta) - mean(lo$flow_delta), unname(tt$statistic), tt$p.value))
