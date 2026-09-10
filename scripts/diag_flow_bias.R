# Is the xgb flow model BIASED per destination party, even though its RMSE is
# better?
#
# Two hypotheses are already dead:
#   - "the table holds a local signal xgb washes out" -- no: xgb beats the real
#     harness table in 7 of 8 elections, fed2016 by 19% (diag_flow_vs_real_table.R);
#   - "a better flow exposes a bad primary pot" -- no: correlation between
#     primary RMSE and flow damage is r = 0.129, p = 0.567, and the median split
#     runs the WRONG way (diag_flow_gain_vs_primary.R).
#
# WHAT IS LEFT. RMSE averages over every (from, to) cell, most of which never
# decide anything. A seat is decided by the NET transfer between the top two
# candidates. A model can cut RMSE across all destinations while carrying a
# small systematic bias on one destination class -- and a bias moves every
# marginal seat in a jurisdiction the SAME WAY, which is exactly the shape
# fed2016 showed: 83 seats worse, nearly all of them ALP-won marginals the
# model already had below 0.20, and the IND/GRN/OTH_RIGHT seats better.
#
# So: signed error (prediction minus truth) by destination class, per election.
# Positive = this destination is sent MORE preference share than it really got.
#
# Emits DB* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

X <- fread("output/xgb-flows-v1-oof-predictions.csv", showProgress = FALSE)
cat(sprintf("DB1  %d rows, %d elections\n", nrow(X), uniqueN(X$election)))

B <- X[, .(rows = .N,
           table_bias = mean(base_pred - y),
           xgb_bias   = mean(xgb_pred - y),
           table_rmse = sqrt(mean((base_pred - y)^2)),
           xgb_rmse   = sqrt(mean((xgb_pred - y)^2))), by = to]
setorder(B, -rows)
cat("\nDB2  signed error by DESTINATION class, pooled over all 25 elections.\n")
cat("     bias > 0 means that class is sent MORE preference share than it actually received.\n")
print(B[, .(to, rows, table_bias = round(table_bias, 4), xgb_bias = round(xgb_bias, 4),
            table_rmse = round(table_rmse, 4), xgb_rmse = round(xgb_rmse, 4))])

# THE TWO REGRESSING PAIRS, and two of the biggest winners, side by side. A
# bias that flips sign between them is the mechanism; one that does not, is not.
FOCUS <- c("fed2016", "wa1996", "fed2013", "vic2014", "wa2005", "nsw2019")
E <- X[election %in% FOCUS & to %in% c("ALP", "LNP", "GRN", "IND")]
EB <- E[, .(rows = .N, table_bias = mean(base_pred - y), xgb_bias = mean(xgb_pred - y)),
        by = .(election, to)]
EB[, shift := xgb_bias - table_bias]
W <- dcast(EB, election ~ to, value.var = "shift")
cat("\nDB3  SHIFT in signed error, xgb minus table, by destination. Per election.\n")
cat("     Positive = xgb sends that class MORE preference share than the table did.\n")
cat("     fed2016 and wa1996 are the pairs that REGRESSED; the rest are big winners.\n")
print(W)

# The number that actually moves a two-party seat: ALP's share of the ALP+LNP
# transfer. Everything else is noise for a classic marginal.
TP <- X[to %in% c("ALP", "LNP")]
TP[, side := to]
A <- TP[, .(table_bias = mean(base_pred - y), xgb_bias = mean(xgb_pred - y), rows = .N),
        by = .(election, side)]
A2 <- dcast(A, election ~ side, value.var = c("table_bias", "xgb_bias"))
A2[, table_net_alp := table_bias_ALP - table_bias_LNP]
A2[, xgb_net_alp := xgb_bias_ALP - xgb_bias_LNP]
A2[, shift_to_alp := xgb_net_alp - table_net_alp]
setorder(A2, shift_to_alp)
cat("\nDB4  NET two-party effect: (bias toward ALP) minus (bias toward LNP), per election.\n")
cat("     shift_to_alp < 0 means the xgb model moves preferences AWAY from ALP relative to the table.\n")
print(A2[, .(election, table_net_alp = round(table_net_alp, 4),
             xgb_net_alp = round(xgb_net_alp, 4), shift_to_alp = round(shift_to_alp, 4))])
