# Train the FINAL v5 XGBoost primary-share model on ALL 22 historical pairs
# (no held-out fold -- vic2026 is not in this corpus, so using every pair is
# not leakage the way it would be for scoring a historical backtest). Saves
# the model + the exact feature column order fit_seats_full.R must reproduce.
#
# Mirrors fit_xgb_primary_final.R's pattern (v1's final-model script) but for
# v5's larger feature set: pred_share, x, level_prev, level_now, dev_prev,
# n_cand_prev, n_cand_now, same_i, same_mp_i, is_major_i, plus six
# load_seats()-derived fields, is_incumbent_party, own_prev_pcv,
# historic_elected_i, ballot_pos_min, party_*, region_*. Reference result
# (leave-one-pair-out): pooled seat log loss 0.3403 -> 0.3103, the best of
# v1-v5 (docs/reviews/xgb-primary-v5-seat-features-2026-09-10.md). Ships per
# Pete's explicit instruction 2026-09-10: best pooled log loss, iterate on
# the two known regressions (SA2026 ONP, vic2014) afterward rather than
# blocking on them.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
ALL <- fread(file.path(OUT, "xgb-primary-features-v5.csv"), showProgress = FALSE)
ALL <- ALL[is.finite(level_prev) & is.finite(level_now)]

ALL[, same_i := as.integer(same)]
ALL[, same_mp_i := as.integer(same_mp)]
ALL[, is_major_i := as.integer(is_major)]
ALL[, retirement_i := as.integer(retirement)]
ALL[, soph_cand_i := as.integer(soph_cand)]
ALL[, soph_party_i := as.integer(soph_party)]
ALL[, is_incumbent_party_i := as.integer(is_incumbent_party)]
ALL[, historic_elected_i := as.integer(historic_elected_any)]

# FIXED, ALPHABETICAL (within each dummy block), WRITTEN TO DISK -- the live
# path must build its feature row with these exact columns in this exact
# order, or the matrix columns silently misalign with what the model was
# trained on. Same fixed party/region levels as v1's final script (v5's own
# CV script derived them from the data; hardcoded here for the same reason
# v1's final script hardcodes them -- so a future corpus change can't
# silently reorder what a saved model expects).
party_levels <- c("ALP","GRN","IND","LNP","NAT","ONP","OTH","OTH_RIGHT")
region_levels <- c("fed","nsw","qld","sa","vic","wa")
stopifnot(all(sort(unique(ALL$party)) %in% party_levels))
stopifnot(all(sort(unique(ALL$region)) %in% region_levels))
for (p in party_levels) ALL[[paste0("party_", p)]] <- as.integer(ALL$party == p)
for (r in region_levels) ALL[[paste0("region_", r)]] <- as.integer(ALL$region == r)

feat_cols <- c("pred_share", "x", "level_prev", "level_now", "dev_prev",
               "n_cand_prev", "n_cand_now", "same_i", "same_mp_i", "is_major_i",
               "margin", "fed_swing", "retirement_i", "soph_cand_i", "soph_party_i",
               "prev_swing", "is_incumbent_party_i", "own_prev_pcv",
               "historic_elected_i", "ballot_pos_min",
               paste0("party_", party_levels), paste0("region_", region_levels))
X <- as.matrix(ALL[, ..feat_cols])
y <- ALL$actual_share

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
                subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)

# nrounds: re-derive by CV (grouped by election pair, same as the reference
# run) rather than guess -- no early-stopping record was saved from the
# original CV run. Same reasoning as v1's final script: refitting nrounds by
# CV on the FULL 22 pairs with no target held out would have no
# early-stopping signal independent of the training data itself, so this CV
# run (with folds held out) is what sets nrounds; the final fit below then
# uses all 22 pairs at that fixed nrounds.
pairs <- sort(unique(ALL$pair))
fold_id <- match(ALL$pair, pairs)
dtrain <- xgb.DMatrix(data = X, label = y, missing = NA)

cat("running xgb.cv (grouped folds by election pair) to fix nrounds...\n")
set.seed(42)
cv <- xgb.cv(params = params, data = dtrain, nrounds = 2000,
             folds = split(seq_len(nrow(X)), fold_id),
             early_stopping_rounds = 30, prediction = TRUE, verbose = 0)
NROUNDS <- cv$early_stop$best_iteration
cat(sprintf("CV best nrounds: %d\n", NROUNDS))

set.seed(42)
final <- xgb.train(params = params, data = dtrain, nrounds = NROUNDS, verbose = 0)

model_file <- file.path(OUT, "xgb-primary-v5-final.model")
xgb.save(final, model_file)
cols_file <- file.path(OUT, "xgb-primary-v5-final-cols.json")
writeLines(jsonlite::toJSON(feat_cols), cols_file)

cat(sprintf("trained on %d rows, %d rounds, %d features\n", nrow(X), NROUNDS, length(feat_cols)))
cat(sprintf("wrote %s\n", model_file))
cat(sprintf("wrote %s\n", cols_file))

# in-sample sanity check only (NOT a validation metric -- the real validation
# is v5's leave-one-pair-out result, 0.3403 -> 0.3103 seat log loss, see
# docs/reviews/xgb-primary-v5-seat-features-2026-09-10.md).
pred <- predict(final, dtrain)
cat(sprintf("in-sample RMSE (sanity check only, not a validation metric): %.4f\n",
            sqrt(mean((pred - y)^2))))
