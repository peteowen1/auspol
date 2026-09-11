# Surge parameters, all three predicted by xgboost -- Pete's design.
#
#   1. P(surge)                      xgb classifier, leave-one-pair-out
#   2. size of the jump | surge      xgb regression, leave-one-pair-out
#   3. spread of that jump | surge   xgb on the absolute residual, same folds
#
# v1 (scripts/fit_xgb_emergence.R) did 1 with xgb and 2-3 as a per-class
# average, partially pooled, because there are only 201 emergences and a
# flexible model on 201 rows memorises them. Pete's call was to fit them with
# xgboost anyway, using xgb.cv and early stopping as the guard against exactly
# that, and then MEASURE the two against each other rather than argue about it.
# That is the right way round, and this script reports both side by side.
#
# The criterion is unchanged and predates both:
# docs/plans/prereg-xgb-surge-parameters-2026-09-11.md -- rms_z <= 2.50 on the
# 201 emergence rows, guard 1 in [0.65, 1.25], improvement in >= 6 of 10 pairs.
#
# HONEST NOTE ON MULTIPLICITY: trying two magnitude models and keeping the
# better one is two shots at the same bar. Both are reported, and if they
# straddle the bar that is a reason to be sceptical of the winner, not to
# announce it.
#
# Emits X3* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
X <- fread(file.path(OUT, "xgb-primary-v6-oof-predictions.csv"), showProgress = FALSE)
E <- fread(file.path(OUT, "emergence-cases.csv"), showProgress = FALSE)
X[, emergent := as.integer(paste(pair, seat, party) %in% paste(E$pair, E$seat, E$party))]
X[, region := sub("[0-9]{4}$", "", pair)]
X[, gain := actual_share - xgb_pred]
CLASSES <- sort(unique(X$party)); REGIONS <- sort(unique(X$region))
for (p in CLASSES) X[[paste0("cls_", p)]] <- as.integer(X$party == p)
for (r in REGIONS) X[[paste0("reg_", r)]] <- as.integer(X$region == r)
feat <- c("pred_share", "xgb_pred", "jump", "governed", "permit", "surge_h",
          "is_recipient", paste0("cls_", CLASSES), paste0("reg_", REGIONS))
M <- as.matrix(X[, ..feat])
pairs <- sort(unique(X$pair)); fold <- match(X$pair, pairs)
cat(sprintf("X31  %d rows, %d pairs, %d emergences\n", nrow(X), length(pairs), sum(X$emergent)))

# ---- 1. P(surge), unchanged from v1 ---------------------------------------
pc <- list(objective = "binary:logistic", eval_metric = "logloss", eta = 0.05,
           max_depth = 4, subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 10)
set.seed(42)
cv1 <- xgb.cv(params = pc, data = xgb.DMatrix(M, label = X$emergent), nrounds = 600,
              folds = split(seq_len(nrow(M)), fold), early_stopping_rounds = 30,
              prediction = TRUE, verbose = 0)
X[, p_emerge := cv1$cv_predict$pred[, 1]]
cat(sprintf("X31  hazard: nrounds %d\n", cv1$early_stop$best_iteration))

# ---- 2 + 3. magnitude and spread, xgboost, trained ONLY on emergences ------
# Folds are the pairs that actually contain an emergence; a pair with none
# cannot be held out of a model fitted on emergences alone.
emg <- X[emergent == 1L]
epairs <- sort(unique(emg$pair)); efold <- match(emg$pair, epairs)
ME <- as.matrix(emg[, ..feat])
cat(sprintf("X32  magnitude model trains on %d rows over %d pairs (median %d per pair)\n",
            nrow(emg), length(epairs), as.integer(stats::median(table(emg$pair)))))

pr <- list(objective = "reg:squarederror", eta = 0.03, max_depth = 3,
           subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)
set.seed(42)
cv2 <- xgb.cv(params = pr, data = xgb.DMatrix(ME, label = emg$gain), nrounds = 800,
              folds = split(seq_len(nrow(ME)), efold), early_stopping_rounds = 30,
              prediction = TRUE, verbose = 0)
n2 <- max(cv2$early_stop$best_iteration, 10L)
emg[, mu_xgb_oof := cv2$cv_predict$pred[, 1]]
cat(sprintf("X32  nrounds %d | out-of-fold RMSE on the jump: %.2f points\n",
            n2, sqrt(mean((emg$mu_xgb_oof - emg$gain)^2))))

# The spread: a second model on |residual|, same folds. E|e| for a normal is
# sd*sqrt(2/pi), so scale back up to an sd.
emg[, absres := abs(gain - mu_xgb_oof)]
set.seed(42)
cv3 <- xgb.cv(params = pr, data = xgb.DMatrix(ME, label = emg$absres), nrounds = 800,
              folds = split(seq_len(nrow(ME)), efold), early_stopping_rounds = 30,
              prediction = TRUE, verbose = 0)
n3 <- max(cv3$early_stop$best_iteration, 10L)
emg[, sd_xgb_oof := pmax(1, cv3$cv_predict$pred[, 1] / sqrt(2 / pi))]
cat(sprintf("X32  spread model nrounds %d | mean predicted sd %.1f (pooled empirical %.1f)\n",
            n3, mean(emg$sd_xgb_oof), stats::sd(emg$gain)))

# Final models, fitted on all emergences, so every row in X can be scored --
# any candidate could surge, not just the ones who did.
fin_mu <- xgb.train(pr, xgb.DMatrix(ME, label = emg$gain), nrounds = n2, verbose = 0)
fin_sd <- xgb.train(pr, xgb.DMatrix(ME, label = emg$absres), nrounds = n3, verbose = 0)
X[, mu_xgb := predict(fin_mu, M)]
X[, sd_xgb := pmax(1, predict(fin_sd, M) / sqrt(2 / pi))]
# For the 201 emergence rows use the OUT-OF-FOLD values, never the in-sample
# ones -- otherwise the scoring below grades the model on its own training data.
X <- merge(X, emg[, .(pair, seat, party, mu_xgb_oof, sd_xgb_oof)],
           by = c("pair", "seat", "party"), all.x = TRUE)
X[!is.na(mu_xgb_oof), `:=`(mu_xgb = mu_xgb_oof, sd_xgb = sd_xgb_oof)]

# ---- the v1 comparator: per-class, partially pooled ------------------------
pooled_mu <- mean(emg$gain); pooled_sd <- stats::sd(emg$gain)
cls <- emg[, .(n = .N, m = mean(gain), s = stats::sd(gain)), by = party]
cls[is.na(s), s := pooled_sd]
tau2 <- max(stats::var(cls$m) - mean(cls$s^2 / cls$n), 0)
cls[, w := tau2 / (tau2 + s^2 / n)]
cls[, `:=`(mu_pool = pooled_mu + w * (m - pooled_mu), sd_pool = pooled_sd + w * (s - pooled_sd))]
X <- merge(X, cls[, .(party, mu_pool, sd_pool)], by = "party", all.x = TRUE)
X[is.na(mu_pool), `:=`(mu_pool = pooled_mu, sd_pool = pooled_sd)]

# ---- score both against the SAME pre-registered criterion ------------------
A <- 1.10; B <- 8.67
lsd <- function(p) A + B * sqrt(pmax(0, pmin(1, p / 100)) * (1 - pmax(0, pmin(1, p / 100))))
X[, base_sd := lsd(xgb_pred)]
mixz <- function(mu, sdv) {
  m <- X$xgb_pred + X$p_emerge * mu
  v <- X$base_sd^2 + X$p_emerge * (sdv^2 + mu^2) - (X$p_emerge * mu)^2
  (X$actual_share - m) / sqrt(pmax(v, 1e-9))
}
X[, z_old  := (actual_share - xgb_pred) / base_sd]
X[, z_pool := mixz(mu_pool, sd_pool)]
X[, z_xgb  := mixz(mu_xgb, sd_xgb)]

FOCUS <- c("IND", "GRN", "ONP", "OTH_RIGHT")
rz <- function(v) sqrt(mean(v^2))
em <- X[emergent == 1L]; ne <- X[emergent == 0L & party %in% FOCUS]
cat("\nX33  PRIMARY: rms_z on the 201 emergence rows. Lower is better; bar 2.50.\n")
cat(sprintf("       today                     %.2f\n", rz(em$z_old)))
cat(sprintf("       v1  per-class pooled      %.2f\n", rz(em$z_pool)))
cat(sprintf("       v3  xgb magnitude + sd    %.2f   <- Pete's design\n", rz(em$z_xgb)))
cat("\nX34  GUARD 1: non-emergent minors, must stay in [0.65, 1.25]\n")
cat(sprintf("       today %.2f | v1 %.2f | v3 %.2f  (n=%d)\n",
            rz(ne$z_old), rz(ne$z_pool), rz(ne$z_xgb), nrow(ne)))
cat("\nX35  by class (rms_z)\n")
print(em[, .(n = .N, today = round(rz(z_old), 2), v1 = round(rz(z_pool), 2),
             v3 = round(rz(z_xgb), 2)), by = party][order(-n)])
byp <- em[, .(n = .N, v1 = rz(z_pool), v3 = rz(z_xgb), today = rz(z_old)), by = pair]
cat(sprintf("\nX36  GUARD 3: v3 improves on today in %d of %d pairs; beats v1 in %d\n",
            sum(byp$v3 < byp$today), nrow(byp), sum(byp$v3 < byp$v1)))
cat("\nX37  what the two magnitude models actually say, by class\n")
print(X[emergent == 1L, .(n = .N, actual_gain = round(mean(gain), 1),
                          v1_mu = round(mean(mu_pool), 1), v3_mu = round(mean(mu_xgb), 1),
                          v1_sd = round(mean(sd_pool), 1), v3_sd = round(mean(sd_xgb), 1)),
        by = party][order(-n)])
fwrite(X[, .(pair, seat, party, xgb_pred, actual_share, emergent, p_emerge,
             mu_pool, sd_pool, mu_xgb, sd_xgb, z_old, z_pool, z_xgb)],
       file.path(OUT, "xgb-emergence-v3-oof.csv"))
cat(sprintf("\nX38  wrote %s/xgb-emergence-v3-oof.csv\n", OUT))
