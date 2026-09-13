# Where does the primary model struggle, per party class, and why?
# Pete, 2026-09-12: "where does each group (ALP/LNP/GRN/ONP/IND/OTH) struggle
# the most which seats predict worst for them - why is that? can we fix it?"
#
# The pooled RMSE hides everything that matters. A class can look fine on
# average while being catastrophically wrong on the seats that decide the
# chamber, and two classes with the same RMSE can be wrong for opposite reasons
# -- one systematically biased, one unbiased but noisy.
#
# So this reports, per class: the error, how much of it is BIAS versus spread,
# where in the vote range it concentrates, and the individual worst cells with
# enough context to say why.
#
# Emits XE* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"
A <- fread(file.path(OUT, "xgb-primary-v7-arms.csv"), showProgress = FALSE)
F <- fread(file.path(OUT, "xgb-primary-v7-features.csv"), showProgress = FALSE)
keep <- setdiff(names(F), names(A))
X <- merge(A, F[, c("pair", "seat", "party", ..keep)], by = c("pair", "seat", "party"))
stopifnot(nrow(X) == nrow(A))
X[, err := pred_v7e - actual_share]
X[, region := sub("[0-9]{4}$", "", pair)]
cat(sprintf("XE1  %d cells, %d pairs, %d classes\n", nrow(X), uniqueN(X$pair), uniqueN(X$party)))

rmse <- function(e) sqrt(mean(e^2))
cat("\nXE2  ERROR BY CLASS. All in points of primary vote.\n")
cat("XE2  bias = mean(pred - actual): positive means we OVER-predict the class.\n")
cat("XE2  sd_err is the spread around that bias. bias_share is how much of the\n")
cat("XE2  squared error is systematic rather than noise -- a high value means the\n")
cat("XE2  class is fixable by correcting a level, a low one means it is genuinely hard.\n")
print(X[, .(cells = .N, mean_actual = round(mean(actual_share), 1),
            rmse = round(rmse(err), 3),
            bias = round(mean(err), 3),
            sd_err = round(sd(err), 3),
            bias_share = sprintf("%.0f%%", 100 * mean(err)^2 / mean(err^2)),
            worst = round(max(abs(err)), 1)), by = party][order(-rmse)])

cat("\nXE3  WHERE IN THE VOTE RANGE. Error by how much the class ACTUALLY polled.\n")
cat("XE3  A class whose error concentrates at the top is failing on seats it can win.\n")
X[, band := cut(actual_share, c(-.1, 2, 5, 10, 20, 35, 101),
                labels = c("0-2", "2-5", "5-10", "10-20", "20-35", "35+"))]
print(dcast(X[, .(rmse = round(rmse(err), 2)), by = .(party, band)],
            party ~ band, value.var = "rmse"))
cat("\nXE3  and the CELL COUNTS behind those, because a big RMSE on 4 cells is not a finding:\n")
print(dcast(X[, .N, by = .(party, band)], party ~ band, value.var = "N"))

cat("\nXE4  BIAS by band -- is the model systematically low on big votes?\n")
print(dcast(X[, .(bias = round(mean(err), 2)), by = .(party, band)],
            party ~ band, value.var = "bias"))

# XE4 conditions on the ACTUAL result, where finding the predictions shrunk
# toward the mean is EXPECTED, not a defect: under squared loss the optimal
# forecast is the conditional mean, so cells that turned out high were always
# going to be under-predicted on average. That table cannot tell you anything
# is fixable.
#
# THIS one conditions on the PREDICTION, which is what a forecaster actually
# has. If cells we call at 30 come in at 35 on average, that IS a correctable
# bias -- we can act on it, because we know the prediction in advance.
cat("\nXE4b THE DECISION-RELEVANT CUT: bias conditional on what we PREDICTED.\n")
cat("XE4b bias = mean(pred - actual) within each predicted band. Near zero means\n")
cat("XE4b calibrated and nothing to fix. Systematically negative means the model is\n")
cat("XE4b low at that level and could be corrected, since we know pred in advance.\n")
X[, pband := cut(pred_v7e, c(-.1, 2, 5, 10, 20, 35, 101),
                 labels = c("0-2", "2-5", "5-10", "10-20", "20-35", "35+"))]
print(dcast(X[, .(bias = round(mean(err), 2)), by = .(party, pband)],
            party ~ pband, value.var = "bias"))
cat("XE4b cell counts:\n")
print(dcast(X[, .N, by = .(party, pband)], party ~ pband, value.var = "N"))

cat("\nXE5  THE WORST CELLS PER CLASS, five each, with context.\n")
cat("XE5  x = what the class polled here last time; same_mp = sitting member returning.\n")
ctx <- intersect(c("x", "same_mp_i", "n_cand_now", "jump_pctile", "margin",
                   "is_incumbent_party_i", "cand_all_new"), names(X))
for (p in X[, .(r = rmse(err)), by = party][order(-r)]$party) {
  cat(sprintf("\n--- %s ---\n", p))
  print(head(X[party == p][order(-abs(err)),
              c(.(pair = pair, seat = seat, pred = round(pred_v7e, 1),
                  actual = round(actual_share, 1), err = round(err, 1)),
                lapply(.SD, function(v) round(v, 2))), .SDcols = ctx], 5))
}

cat("\nXE6  DOES EACH CLASS STRUGGLE IN A DIFFERENT KIND OF SEAT?\n")
cat("XE6  RMSE split by whether the class held the seat, and whether its sitting\n")
cat("XE6  member is standing again. Blank where the split does not apply.\n")
if (all(c("is_incumbent_party_i", "same_mp_i") %in% names(X))) {
  print(dcast(X[, .(rmse = round(rmse(err), 2), n = .N),
                by = .(party, held = is_incumbent_party_i == 1)],
              party ~ held, value.var = c("rmse", "n")))
}

cat("\nXE7  BY JURISDICTION -- is a class harder in one chamber?\n")
print(dcast(X[, .(rmse = round(rmse(err), 2)), by = .(party, region)],
            party ~ region, value.var = "rmse"))

fwrite(X[, .(pair, seat, party, pred = pred_v7e, actual = actual_share, err)],
       file.path(OUT, "primary-errors-by-class.csv"))
cat(sprintf("\nXE8  wrote %s/primary-errors-by-class.csv\n", OUT))
