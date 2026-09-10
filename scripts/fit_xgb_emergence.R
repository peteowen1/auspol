# Predict the SURGE PARAMETERS with xgboost, leave-one-pair-out.
#
# docs/plans/prereg-xgb-surge-parameters-2026-09-11.md is the committed
# criterion. Read it before changing anything here.
#
# THE TARGET. The xgb primary's point estimate is already unbiased at every
# level; the SPREAD is wrong. For IND predicted at 10-15% the actual runs
# p10 = 2.0, p50 = 10.1, p90 = 26.3, against an assumed sd of 3.70. The
# simulator already implements the right SHAPE -- with probability surge_h,
# add N(surge_mu, surge_sd) -- so this fits the parameters rather than
# changing the simulator.
#
#   surge_h     <- P(this class emerges in this seat)      xgb classifier
#   surge_party <- the class with the highest such P
#   surge_mu/sd <- the conditional gain and its spread     empirical, shrunk
#
# WHY THE MAGNITUDE IS NOT AN XGB REGRESSION. There are 201 emergence rows.
# Fitting a tree model to their magnitudes would overfit, and CLAUDE.md's rule
# is to partial-pool a thin cell toward the pooled mean rather than trust it or
# discard it. So the magnitude is a per-class empirical mean and sd, shrunk
# toward the all-class pooled value by how precisely each class is measured,
# and computed leave-one-pair-out like everything else.
#
# Emits XE* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
X <- fread(file.path(OUT, "xgb-primary-v6-oof-predictions.csv"), showProgress = FALSE)
E <- fread(file.path(OUT, "emergence-cases.csv"), showProgress = FALSE)
X[, emergent := as.integer(paste(pair, seat, party) %in% paste(E$pair, E$seat, E$party))]
X[, region := sub("[0-9]{4}$", "", pair)]
cat(sprintf("XE1  %d rows, %d pairs, %d emergences (%.2f%%)\n",
            nrow(X), uniqueN(X$pair), sum(X$emergent), 100 * mean(X$emergent)))

# The gain an emergence actually delivered over what the primary model said.
# This is what surge_mu has to reproduce.
X[, gain := actual_share - xgb_pred]

# ---- features -------------------------------------------------------------
# Deliberately the columns the oof file already carries, plus class and region
# one-hots. The AUC audit (scripts/diag_emergence_calibration.R) found the
# model's OWN pred_share is the single best emergence predictor (0.75-0.85 by
# class), ahead of salience `jump` (0.756 for IND, useless for the rest), so
# the point estimate has to be in here -- this model is learning WHEN the
# primary model is about to be wrong, not re-deriving it.
CLASSES <- sort(unique(X$party))
REGIONS <- sort(unique(X$region))
for (p in CLASSES) X[[paste0("cls_", p)]] <- as.integer(X$party == p)
for (r in REGIONS) X[[paste0("reg_", r)]] <- as.integer(X$region == r)
feat <- c("pred_share", "xgb_pred", "jump", "governed", "permit", "surge_h",
          "is_recipient", paste0("cls_", CLASSES), paste0("reg_", REGIONS))
miss <- setdiff(feat, names(X)); if (length(miss)) stop("missing features: ", paste(miss, collapse = ", "))
M <- as.matrix(X[, ..feat])
y <- X$emergent
pairs <- sort(unique(X$pair))
fold <- match(X$pair, pairs)

# ---- 1. the hazard, leave-one-pair-out ------------------------------------
params <- list(objective = "binary:logistic", eval_metric = "logloss",
               eta = 0.05, max_depth = 4, subsample = 0.8,
               colsample_bytree = 0.8, min_child_weight = 10)
cat("XE2  fitting the emergence hazard, grouped folds by pair...\n")
set.seed(42)
cv <- xgb.cv(params = params, data = xgb.DMatrix(M, label = y), nrounds = 600,
             folds = split(seq_len(nrow(M)), fold), early_stopping_rounds = 30,
             prediction = TRUE, verbose = 0)
best_n <- max(cv$early_stop$best_iteration, 30L)
X[, p_emerge := cv$cv_predict$pred[, 1]]
auc <- function(s, l) { r <- rank(s); n1 <- sum(l); n0 <- sum(!l)
  (sum(r[l == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
cat(sprintf("XE2  nrounds %d | out-of-fold AUC %.3f (0.50 = no signal)\n",
            best_n, auc(X$p_emerge, y)))
cat("XE2  by class, against the best single feature found earlier (pred_share):\n")
print(X[, .(n = .N, emerge = sum(emergent),
            auc_model = round(auc(p_emerge, emergent), 3),
            auc_pred_share = round(auc(pred_share, emergent), 3)),
        by = party][order(-emerge)])

# ---- 2. the magnitude, shrunk, leave-one-pair-out --------------------------
# tau^2 = between-class variance of the mean gain; each class is pulled toward
# the pooled mean by how precisely its own mean is measured. A class with three
# emergences ends up near the prior instead of trusting three numbers.
emg <- X[emergent == 1L]
pooled_mu <- mean(emg$gain); pooled_sd <- stats::sd(emg$gain)
cls <- emg[, .(n = .N, m = mean(gain), s = stats::sd(gain)), by = party]
cls[is.na(s), s := pooled_sd]
tau2 <- max(stats::var(cls$m) - mean(cls$s^2 / cls$n), 0)
cls[, w := tau2 / (tau2 + (s^2 / n))]
cls[, mu_shrunk := pooled_mu + w * (m - pooled_mu)]
cls[, sd_shrunk := pooled_sd + w * (s - pooled_sd)]
cat(sprintf("\nXE3  conditional gain given emergence: pooled mean %.1f, sd %.1f (n=%d)\n",
            pooled_mu, pooled_sd, nrow(emg)))
cat("XE3  per class, partially pooled -- w is how much the class's own estimate is trusted\n")
print(cls[, .(party, n, raw_mean = round(m, 1), raw_sd = round(s, 1),
              w = round(w, 2), mu = round(mu_shrunk, 1), sd = round(sd_shrunk, 1))][order(-n)])

X <- merge(X, cls[, .(party, mu_shrunk, sd_shrunk)], by = "party", all.x = TRUE)
X[is.na(mu_shrunk), `:=`(mu_shrunk = pooled_mu, sd_shrunk = pooled_sd)]

# ---- 3. score the PRE-REGISTERED criterion, no simulator needed ------------
# The mixture's own mean and sd, which is what the simulator would draw:
#   mean = pred + p*mu
#   var  = level_sd^2 + p*(sd^2 + mu^2) - (p*mu)^2
A <- 1.10; B <- 8.67
lsd <- function(p) A + B * sqrt(pmax(0, pmin(1, p / 100)) * (1 - pmax(0, pmin(1, p / 100))))
X[, base_sd := lsd(xgb_pred)]
X[, mix_mean := xgb_pred + p_emerge * mu_shrunk]
X[, mix_sd := sqrt(base_sd^2 + p_emerge * (sd_shrunk^2 + mu_shrunk^2) - (p_emerge * mu_shrunk)^2)]
X[, z_old := (actual_share - xgb_pred) / base_sd]
X[, z_new := (actual_share - mix_mean) / mix_sd]

FOCUS <- c("IND", "GRN", "ONP", "OTH_RIGHT")
rz <- function(v) sqrt(mean(v^2))
em <- X[emergent == 1L]; ne <- X[emergent == 0L & party %in% FOCUS]
cat("\nXE4  THE PRE-REGISTERED PRIMARY: rms_z on the 201 emergence rows. Target 1.00, pass bar 2.50.\n")
cat(sprintf("XE4    before %.2f   after %.2f   (%% beyond z=2: %.1f -> %.1f)\n",
            rz(em$z_old), rz(em$z_new), 100 * mean(em$z_old > 2), 100 * mean(abs(em$z_new) > 2)))
cat("\nXE5  GUARD 1: non-emergent minor rows must stay in [0.65, 1.25] and <=5% beyond z=2.\n")
cat(sprintf("XE5    before %.2f   after %.2f   (%% beyond z=2: %.1f -> %.1f, n=%d)\n",
            rz(ne$z_old), rz(ne$z_new), 100 * mean(ne$z_old > 2), 100 * mean(abs(ne$z_new) > 2), nrow(ne)))
cat("\nXE6  GUARD 3: rms_z must improve in at least 6 of the 10 pairs holding an emergence win.\n")
byp <- em[, .(n = .N, before = rz(z_old), after = rz(z_new)), by = pair]
byp[, better := after < before]
print(byp[, .(pair, n, before = round(before, 2), after = round(after, 2), better)][order(-n)])
cat(sprintf("XE6    improved in %d of %d pairs\n", sum(byp$better), nrow(byp)))

fwrite(X[, .(pair, seat, party, xgb_pred, actual_share, emergent, p_emerge,
             mu_shrunk, sd_shrunk, mix_mean, mix_sd, z_old, z_new)],
       file.path(OUT, "xgb-emergence-oof.csv"))
final <- xgb.train(params = params, data = xgb.DMatrix(M, label = y), nrounds = best_n, verbose = 0)
xgb.save(final, file.path(OUT, "xgb-emergence-final.model"))
writeLines(jsonlite::toJSON(feat), file.path(OUT, "xgb-emergence-cols.json"))
fwrite(cls, file.path(OUT, "xgb-emergence-magnitude.csv"))
cat(sprintf("\nXE7  wrote xgb-emergence-oof.csv, -final.model, -cols.json, -magnitude.csv\n"))
