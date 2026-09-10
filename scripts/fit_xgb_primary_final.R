# Train the FINAL XGBoost primary-share model on ALL 22 historical pairs (no
# held-out fold -- vic2026 is not in this corpus, so using every pair is not
# leakage the way it would be for scoring a historical backtest). Saves the
# model + the exact feature column order fit_seats_full.R must reproduce.
#
# Same feature set as fit_xgb_primary_cv.R's v1 (the reference result: pooled
# seat log loss 0.3358 -> 0.3122, paired t = -2.89 across the 22 backtest
# pairs) -- no salience/surge features, no row weighting; v2-v4 all measured
# worse or mixed on 2026-09-09, see docs/reviews/xgb-primary-challenger-2026-09-09.md.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
ALL <- fread(file.path(OUT, "xgb-primary-features.csv"), showProgress = FALSE)
ALL <- ALL[is.finite(level_prev) & is.finite(level_now)]

ALL[, same_i := as.integer(same)]
ALL[, same_mp_i := as.integer(same_mp)]
ALL[, is_major_i := as.integer(is_major)]
# FIXED, ALPHABETICAL, WRITTEN TO DISK -- fit_seats_full.R must build its
# live feature row with these exact columns in this exact order, or the
# matrix columns silently misalign with what the model was trained on.
party_levels <- c("ALP","GRN","IND","LNP","NAT","ONP","OTH","OTH_RIGHT")
region_levels <- c("fed","nsw","qld","sa","vic","wa")
stopifnot(all(sort(unique(ALL$party)) %in% party_levels))
stopifnot(all(sort(unique(ALL$region)) %in% region_levels))
for (p in party_levels) ALL[[paste0("party_", p)]] <- as.integer(ALL$party == p)
for (r in region_levels) ALL[[paste0("region_", r)]] <- as.integer(ALL$region == r)

feat_cols <- c("pred_share", "x", "level_prev", "level_now", "dev_prev",
               "n_cand_prev", "n_cand_now", "same_i", "same_mp_i", "is_major_i",
               paste0("party_", party_levels), paste0("region_", region_levels))
X <- as.matrix(ALL[, ..feat_cols])
y <- ALL$actual_share

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
                subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)
# nrounds fixed at v1's leave-one-pair-out best (195, measured 2026-09-09) --
# refitting nrounds by CV on the full 22 pairs with no target held out would
# have no early-stopping signal independent of the training data itself.
NROUNDS <- 195L

dtrain <- xgb.DMatrix(data = X, label = y)
set.seed(42)
final <- xgb.train(params = params, data = dtrain, nrounds = NROUNDS, verbose = 0)

model_file <- file.path(OUT, "xgb-primary-final.model")
xgb.save(final, model_file)
cols_file <- file.path(OUT, "xgb-primary-final-cols.json")
writeLines(jsonlite::toJSON(feat_cols), cols_file)

cat(sprintf("trained on %d rows, %d rounds\n", nrow(X), NROUNDS))
cat(sprintf("wrote %s\n", model_file))
cat(sprintf("wrote %s\n", cols_file))

# in-sample sanity check only (this is NOT a validation number -- the real
# validation is v1's leave-one-pair-out result, 0.3358 -> 0.3122 seat log
# loss). Just confirms the fit isn't degenerate.
pred <- predict(final, dtrain)
cat(sprintf("in-sample RMSE (sanity check only, not a validation metric): %.4f\n",
            sqrt(mean((pred - y)^2))))
