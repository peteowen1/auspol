# Train the FINAL v6 XGBoost primary-share model on ALL 22 historical pairs
# (no held-out fold -- vic2026 is not in this corpus, so using every pair is
# not leakage the way it would be for scoring a historical backtest). Saves
# the model + the exact feature column order fit_seats_full.R must reproduce.
#
# Mirrors fit_xgb_primary_v5_final.R's pattern but for v6's feature set: v5's
# fields PLUS the salience/emergence features from v4 (jump, governed,
# permit, surge_h, is_recipient). Built because v5's live smoke test found a
# severe side effect -- Victoria's statewide IND/OTH_RIGHT predicted share
# collapsed ~10x/~180x across 87 seats, 55 of 87 predicting both classes
# exactly zero -- and v6 was built to test whether giving the model a
# genuine "this specific candidate/class is showing signs of a real
# emergence" signal fixes it. Measured (leave-one-pair-out, real seat log
# loss via the harnesses, all 22 pairs): pooled 0.3403 -> 0.3071, the best of
# v1-v6, AND the vic2022 backtest proxy for the degeneracy issue looks
# substantially fixed (IND/OTH_RIGHT statewide sums INCREASE slightly vs
# shipped rather than collapsing; 13 of 78 seats predict IND exactly zero,
# not 55 of 87 as v5 did). SA2026 One Nation remains a known, unfixed
# regression (log loss 0.4536, essentially unchanged from v5's 0.4537),
# per Pete's explicit instruction 2026-09-10: ship the best pooled result and
# iterate on named regressions afterward.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
ALL <- fread(file.path(OUT, "xgb-primary-features-v6.csv"), showProgress = FALSE)
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
# trained on. Same fixed party/region levels as v1/v5's final scripts.
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
               "jump", "governed", "permit", "surge_h", "is_recipient",
               paste0("party_", party_levels), paste0("region_", region_levels))
X <- as.matrix(ALL[, ..feat_cols])
y <- ALL$actual_share

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
                subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)

# nrounds: re-derive by CV (grouped by election pair) rather than guess --
# same reasoning as v1/v5's final scripts: a CV run with real held-out folds
# is what sets nrounds; the final fit then uses all 22 pairs at that fixed
# nrounds (already computed once above at 289; rerun here for a
# self-contained, reproducible script rather than hardcoding it).
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

model_file <- file.path(OUT, "xgb-primary-v6-final.model")
xgb.save(final, model_file)
cols_file <- file.path(OUT, "xgb-primary-v6-final-cols.json")
writeLines(jsonlite::toJSON(feat_cols), cols_file)

cat(sprintf("trained on %d rows, %d rounds, %d features\n", nrow(X), NROUNDS, length(feat_cols)))
cat(sprintf("wrote %s\n", model_file))
cat(sprintf("wrote %s\n", cols_file))

# in-sample sanity check only (NOT a validation metric -- the real validation
# is v6's leave-one-pair-out result, 0.3403 -> ~0.3071 pooled seat log loss).
pred <- predict(final, dtrain)
cat(sprintf("in-sample RMSE (sanity check only, not a validation metric): %.4f\n",
            sqrt(mean((pred - y)^2))))
