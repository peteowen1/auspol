# Emergence model on the FULL feature set.
#
# v1 and v3 used 7 substantive predictors -- the ones that happened to be in
# output/xgb-primary-v6-oof-predictions.csv -- and concluded "we cannot predict
# who surges". That conclusion was about the feature set, not the problem. The
# primary model carries 25, and the 18 that were missing include the ones most
# likely to matter for an emergence:
#
#   retirement_i         is the sitting member retiring -- Curtin, North Sydney
#                        and Mackellar all had weak or departing Liberals
#   margin               how safe the seat was
#   same_mp_i, same_i    is this a returning candidate / sitting member
#   own_prev_pcv         what this candidate polled last time
#   n_cand_now           how crowded the field is
#   historic_elected_i   has this class ever won here
#   plus level_prev, level_now, dev_prev, prev_swing, fed_swing, soph_cand_i,
#   soph_party_i, ballot_pos_min, is_major_i, x, n_cand_prev
#
# Same three-part design as v3, same folds, and the SAME pre-registered
# criterion, which predates all of it:
# docs/plans/prereg-xgb-surge-parameters-2026-09-11.md -- rms_z <= 2.50 on the
# 201 emergence rows, guard 1 in [0.65, 1.25], improvement in >= 6 of 10 pairs.
#
# Emits X4* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
FF <- file.path(OUT, "xgb-primary-v6-features.csv")
if (!file.exists(FF)) stop("run scripts/fit_xgb_primary_v6.R first -- it writes ", FF)
F <- fread(FF, showProgress = FALSE)
O <- fread(file.path(OUT, "xgb-primary-v6-oof-predictions.csv"), showProgress = FALSE)
E <- fread(file.path(OUT, "emergence-cases.csv"), showProgress = FALSE)

X <- merge(F, O[, .(pair, seat, party, xgb_pred)], by = c("pair", "seat", "party"), all.x = TRUE)
if (any(is.na(X$xgb_pred))) stop("feature and oof files disagree on rows")
X[, emergent := as.integer(paste(pair, seat, party) %in% paste(E$pair, E$seat, E$party))]
X[, gain := actual_share - xgb_pred]

# Everything the primary model gets, plus its own point estimate -- which the
# AUC audit found is the single best emergence predictor on its own.
drop <- c("pair", "seat", "party", "actual_share", "emergent", "gain")
feat <- c(setdiff(names(X), drop))
cat(sprintf("X41  %d rows, %d features (v1/v3 used 7 substantive), %d emergences\n",
            nrow(X), length(feat), sum(X$emergent)))
M <- as.matrix(X[, ..feat])
pairs <- sort(unique(X$pair)); fold <- match(X$pair, pairs)

auc <- function(s, l) { r <- rank(s); n1 <- sum(l); n0 <- sum(!l)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  (sum(r[l == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }

# ---- 1. who surges --------------------------------------------------------
pc <- list(objective = "binary:logistic", eval_metric = "logloss", eta = 0.05,
           max_depth = 4, subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 10)
set.seed(42)
cv1 <- xgb.cv(params = pc, data = xgb.DMatrix(M, label = X$emergent, missing = NA),
              nrounds = 800, folds = split(seq_len(nrow(M)), fold),
              early_stopping_rounds = 30, prediction = TRUE, verbose = 0)
X[, p_emerge := cv1$cv_predict$pred[, 1]]
cat(sprintf("X42  hazard: nrounds %d | out-of-fold AUC %.3f  (v1/v3 got 0.751)\n",
            cv1$early_stop$best_iteration, auc(X$p_emerge, X$emergent)))
cat("X42  by class -- v1/v3 AUCs were IND 0.872, ONP 0.201, OTH_RIGHT 0.546, GRN 0.473\n")
print(X[party %in% c("IND","ONP","OTH_RIGHT","GRN"),
        .(n = .N, emerge = sum(emergent), auc = round(auc(p_emerge, emergent), 3)),
        by = party][order(-emerge)])
cat(sprintf("X42  median hazard on rows that DID surge %.3f, on rows that did not %.3f  (v3: 0.015 / 0.013)\n",
            stats::median(X[emergent == 1]$p_emerge), stats::median(X[emergent == 0]$p_emerge)))
imp <- xgb.importance(feature_names = feat,
                      model = xgb.train(pc, xgb.DMatrix(M, label = X$emergent, missing = NA),
                                        nrounds = max(cv1$early_stop$best_iteration, 20L), verbose = 0))
cat("\nX43  top 12 features for WHO SURGES:\n"); print(head(imp[, .(Feature, Gain = round(Gain, 4))], 12))

# ---- 2 + 3. how big, and how variable -------------------------------------
emg <- X[emergent == 1L]; efold <- match(emg$pair, sort(unique(emg$pair)))
ME <- as.matrix(emg[, ..feat])
pr <- list(objective = "reg:squarederror", eta = 0.03, max_depth = 3,
           subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)
set.seed(42)
cv2 <- xgb.cv(params = pr, data = xgb.DMatrix(ME, label = emg$gain, missing = NA), nrounds = 800,
              folds = split(seq_len(nrow(ME)), efold), early_stopping_rounds = 30,
              prediction = TRUE, verbose = 0)
n2 <- max(cv2$early_stop$best_iteration, 10L)
emg[, mu_oof := cv2$cv_predict$pred[, 1]]
emg[, absres := abs(gain - mu_oof)]
set.seed(42)
cv3 <- xgb.cv(params = pr, data = xgb.DMatrix(ME, label = emg$absres, missing = NA), nrounds = 800,
              folds = split(seq_len(nrow(ME)), efold), early_stopping_rounds = 30,
              prediction = TRUE, verbose = 0)
n3 <- max(cv3$early_stop$best_iteration, 10L)
emg[, sd_oof := pmax(1, cv3$cv_predict$pred[, 1] / sqrt(2 / pi))]
cat(sprintf("\nX44  jump model: out-of-fold RMSE %.2f points (v3 got 7.62; the spread itself is %.2f)\n",
            sqrt(mean((emg$mu_oof - emg$gain)^2)), stats::sd(emg$gain)))

fm <- xgb.train(pr, xgb.DMatrix(ME, label = emg$gain, missing = NA), nrounds = n2, verbose = 0)
fs <- xgb.train(pr, xgb.DMatrix(ME, label = emg$absres, missing = NA), nrounds = n3, verbose = 0)
X[, mu := predict(fm, M)]; X[, sd_j := pmax(1, predict(fs, M) / sqrt(2 / pi))]
X <- merge(X, emg[, .(pair, seat, party, mu_oof, sd_oof)], by = c("pair","seat","party"), all.x = TRUE)
X[!is.na(mu_oof), `:=`(mu = mu_oof, sd_j = sd_oof)]   # never score on in-sample values

# ---- the pre-registered criterion -----------------------------------------
A <- 1.10; B <- 8.67
X[, base_sd := A + B * sqrt(pmax(0, pmin(1, xgb_pred/100)) * (1 - pmax(0, pmin(1, xgb_pred/100))))]
X[, mixm := xgb_pred + p_emerge * mu]
X[, mixs := sqrt(pmax(base_sd^2 + p_emerge * (sd_j^2 + mu^2) - (p_emerge * mu)^2, 1e-9))]
X[, z_old := (actual_share - xgb_pred) / base_sd]
X[, z_new := (actual_share - mixm) / mixs]
rz <- function(v) sqrt(mean(v^2))
FOCUS <- c("IND","GRN","ONP","OTH_RIGHT")
em <- X[emergent == 1L]; ne <- X[emergent == 0L & party %in% FOCUS]
cat(sprintf("\nX45  PRIMARY rms_z on the %d emergence rows -- bar 2.50, LOWER IS BETTER\n", nrow(em)))
cat(sprintf("       today %.2f | v1 3.00 | v3 3.01 | v4 %.2f\n", rz(em$z_old), rz(em$z_new)))
cat(sprintf("X46  GUARD 1 non-emergent minors, must stay in [0.65, 1.25]: %.2f (v3 was 0.68)\n", rz(ne$z_new)))
byp <- em[, .(before = rz(z_old), after = rz(z_new)), by = pair]
cat(sprintf("X47  GUARD 3: improved in %d of %d pairs (need 6 of 10)\n", sum(byp$after < byp$before), nrow(byp)))
cat("\nX48  by class\n")
print(em[, .(n = .N, today = round(rz(z_old), 2), v4 = round(rz(z_new), 2)), by = party][order(-n)])
fwrite(X[, .(pair, seat, party, xgb_pred, actual_share, emergent, p_emerge, mu, sd_j, z_old, z_new)],
       file.path(OUT, "xgb-emergence-v4-oof.csv"))
cat(sprintf("\nX49  wrote %s/xgb-emergence-v4-oof.csv\n", OUT))
