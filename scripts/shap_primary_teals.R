# SHAP for the primary model on the fed2022 teal seats. Pete, 2026-09-12:
# "Does the xGboost not use her high salience at all? Surely that earns her a
#  few points? Check the shap values to see how it gets to 14% for her primary"
#
# SHAP decomposes ONE prediction into a base value plus a contribution per
# feature, and the parts sum exactly to the prediction. So this answers "how did
# it get to 14.4" rather than xgb.importance()'s "which features matter on
# average", which cannot speak about a single row.
#
# Trained with fed2022 HELD OUT, matching the leave-one-pair-out prediction in
# xgb-primary-v6-oof-predictions.csv -- a SHAP built from the all-data model
# would explain a number the backtest never used.
#
# Emits XP* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
FE <- fread(file.path(OUT, "xgb-primary-v6-features.csv"), showProgress = FALSE)
P  <- fread(file.path(OUT, "xgb-primary-v6-oof-predictions.csv"), showProgress = FALSE)
feat_cols <- setdiff(names(FE), c("pair", "seat", "party", "actual_share"))
cat(sprintf("XP1  %d rows, %d features\n", nrow(FE), length(feat_cols)))

HOLD <- "fed2022"
tr <- which(FE$pair != HOLD)
te <- which(FE$pair == HOLD)
M <- as.matrix(FE[, ..feat_cols])
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
               subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)
set.seed(42)
fit <- xgb.train(params, xgb.DMatrix(M[tr, , drop = FALSE],
                                     label = FE$actual_share[tr], missing = NA),
                 nrounds = 700, verbose = 0)

# Sanity: this refit must land near the committed out-of-fold number, or the
# SHAP below explains a different model from the one that was measured.
pred <- predict(fit, M[te, , drop = FALSE])
chk <- merge(FE[te, .(pair, seat, party)][, refit := pred],
             P[P$pair == HOLD, .(seat, party, xgb_pred)], by = c("seat", "party"))
cat(sprintf("XP1  refit vs committed out-of-fold on %s: correlation %.4f, mean abs gap %.2f pts\n",
            HOLD, cor(chk$refit, chk$xgb_pred), mean(abs(chk$refit - chk$xgb_pred))))

TEALS <- c("Wentworth", "Mackellar", "Kooyong", "Curtin", "North Sydney", "Goldstein")
rows <- which(FE$pair == HOLD & FE$party == "IND" & FE$seat %in% TEALS)
SH <- predict(fit, M[rows, , drop = FALSE], predcontrib = TRUE)
colnames(SH) <- c(feat_cols, "BIAS")
rownames(SH) <- FE$seat[rows]

cat("\nXP2  SHAP for each teal seat. Contributions are POINTS OF PRIMARY VOTE and\n")
cat("XP2  sum to the prediction: BIAS + every contribution = predicted share.\n")
cat("XP2  Positive means that feature pushed her vote UP.\n")
for (s in c("Wentworth", "Kooyong", "Mackellar")) {
  i <- match(s, rownames(SH))
  v <- SH[i, ]
  bias <- v[["BIAS"]]
  v <- v[names(v) != "BIAS"]
  ord <- order(-abs(v))
  top <- v[ord][1:10]
  cat(sprintf("\n--- %s: base %.2f + contributions = %.2f (actual was %.1f) ---\n",
              s, bias, bias + sum(v), FE$actual_share[rows][i]))
  print(data.table(feature = names(top),
                   value = round(unlist(FE[rows][i, names(top), with = FALSE]), 3),
                   shap_points = round(unname(top), 2)))
  # The salience block specifically, because that is the question asked.
  sal <- c("jump", "governed", "permit", "surge_h", "is_recipient")
  sal <- intersect(sal, names(v))
  cat(sprintf("    salience block total: %+.2f points  (%s)\n", sum(v[sal]),
              paste(sprintf("%s %+.2f", sal, v[sal]), collapse = ", ")))
}

cat("\nXP2b EVERY feature for Allegra SPENDER, Wentworth fed2022 -- all of them,\n")
cat("XP2b not a top-10. shap_points is in points of primary vote and the whole\n")
cat("XP2b column plus the base value sums to the prediction.\n")
iw <- match("Wentworth", rownames(SH))
vw <- SH[iw, ]
bw <- vw[["BIAS"]]
vw <- vw[names(vw) != "BIAS"]
full <- data.table(feature = names(vw),
                   value = round(unlist(FE[rows][iw, names(vw), with = FALSE]), 3),
                   shap_points = round(unname(vw), 3))
print(full[order(-abs(shap_points))], nrows = 100)
cat(sprintf("\nXP2b base %.3f + sum of contributions %.3f = %.3f | actual %.1f\n",
            bw, sum(vw), bw + sum(vw), FE$actual_share[rows][iw]))
cat(sprintf("XP2b features contributing exactly zero: %d of %d\n",
            sum(vw == 0), length(vw)))

cat("\nXP3  salience contribution across all six, in points of primary vote.\n")
sal <- intersect(c("jump", "governed", "permit", "surge_h", "is_recipient"), colnames(SH))
tb <- data.table(seat = rownames(SH),
                 pred = round(SH %*% rep(1, ncol(SH)), 1)[, 1],
                 actual = round(FE$actual_share[rows], 1),
                 salience_pts = round(rowSums(SH[, sal, drop = FALSE]), 2),
                 x_prev_class = round(FE$x[rows], 1),
                 x_shap = round(SH[, "x"], 2),
                 dev_prev_shap = round(SH[, "dev_prev"], 2),
                 same_mp_shap = round(SH[, "same_mp_i"], 2))
print(tb[order(-actual)])

cat("\nXP4  COUNTERFACTUAL: what if her salience were the corpus MAXIMUM?\n")
cat("XP4  Sets jump/surge_h to the largest value any row has and re-predicts.\n")
cat("XP4  This bounds how much the model is willing to pay for salience at all.\n")
Mx <- M[rows, , drop = FALSE]
for (f in intersect(c("jump", "surge_h"), colnames(Mx))) Mx[, f] <- max(M[, f], na.rm = TRUE)
cat(sprintf("XP4  max jump in corpus %.3f, max surge_h %.3f\n",
            max(M[, "jump"], na.rm = TRUE), max(M[, "surge_h"], na.rm = TRUE)))
print(data.table(seat = rownames(SH), actual = round(FE$actual_share[rows], 1),
                 as_is = round(predict(fit, M[rows, , drop = FALSE]), 1),
                 max_salience = round(predict(fit, Mx), 1))[order(-actual)])

cat("\nXP5  COUNTERFACTUAL: what if the SAME MP were standing again (same_mp_i = 1)?\n")
cat("XP5  The 0.44 retention rule is driven by this flag, so this shows what the\n")
cat("XP5  model would say if it believed the previous vote were being defended.\n")
Mm <- M[rows, , drop = FALSE]
if ("same_mp_i" %in% colnames(Mm)) Mm[, "same_mp_i"] <- 1
if ("same_i" %in% colnames(Mm)) Mm[, "same_i"] <- 1
print(data.table(seat = rownames(SH), actual = round(FE$actual_share[rows], 1),
                 as_is = round(predict(fit, M[rows, , drop = FALSE]), 1),
                 same_mp = round(predict(fit, Mm), 1))[order(-actual)])
