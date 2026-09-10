# Train the XGBoost primary-share challenger via leave-one-pair-out CV
# (xgb.cv folds grouped by election pair, exactly the discipline the six
# backtest harnesses use) and compare its held-out RMSE against the shipped
# model's own pred_share on the same 14,041 (pair, seat, party) cells.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
ALL <- fread(file.path(OUT, "xgb-primary-features.csv"), showProgress = FALSE)
before <- nrow(ALL)
ALL <- ALL[is.finite(level_prev) & is.finite(level_now)]
cat(sprintf("dropped %d of %d rows with no state level (class absent that cycle); %d remain\n",
            before - nrow(ALL), before, nrow(ALL)))

# --- baseline: the shipped model's own primary prediction ---
base_rmse <- sqrt(mean((ALL$pred_share - ALL$actual_share)^2))
cat(sprintf("\nBASELINE (shipped model) pooled primary RMSE: %.4f  (n=%d)\n", base_rmse, nrow(ALL)))

# --- feature matrix ---
ALL[, same_i := as.integer(same)]
ALL[, same_mp_i := as.integer(same_mp)]
ALL[, is_major_i := as.integer(is_major)]
party_levels <- sort(unique(ALL$party))
region_levels <- sort(unique(ALL$region))
for (p in party_levels) ALL[[paste0("party_", p)]] <- as.integer(ALL$party == p)
for (r in region_levels) ALL[[paste0("region_", r)]] <- as.integer(ALL$region == r)

feat_cols <- c("pred_share", "x", "level_prev", "level_now", "dev_prev",
               "n_cand_prev", "n_cand_now", "same_i", "same_mp_i", "is_major_i",
               paste0("party_", party_levels), paste0("region_", region_levels))
X <- as.matrix(ALL[, ..feat_cols])
y <- ALL$actual_share

# fold id = pair index, for grouped (leave-one-pair-out) CV
pairs <- sort(unique(ALL$pair))
fold_id <- match(ALL$pair, pairs)

dtrain <- xgb.DMatrix(data = X, label = y)

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
                subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)

cat("\nrunning xgb.cv, grouped folds by election pair (leave-one-pair-out), up to 2000 rounds, early stop 30...\n")
set.seed(42)
cv <- xgb.cv(params = params, data = dtrain, nrounds = 2000, folds = split(seq_len(nrow(X)), fold_id),
             early_stopping_rounds = 30, prediction = TRUE, verbose = 0)

best_n <- cv$early_stop$best_iteration
cat(sprintf("best nrounds: %d\n", best_n))
oof_pred <- cv$cv_predict$pred[, 1]   # genuine leave-one-pair-out predictions
xgb_rmse <- sqrt(mean((oof_pred - y)^2))
cat(sprintf("\nXGBOOST (leave-one-pair-out) pooled primary RMSE: %.4f  (n=%d)\n", xgb_rmse, length(y)))
cat(sprintf("improvement vs shipped model: %.2f%%\n", 100 * (base_rmse - xgb_rmse) / base_rmse))

# --- fit final model on ALL rows (for feature importance / to use in a follow-up pipeline test) ---
final <- xgb.train(params = params, data = dtrain, nrounds = best_n, verbose = 0)
imp <- xgb.importance(feature_names = feat_cols, model = final)
cat("\ntop 15 features by gain:\n")
print(head(imp, 15))

# --- save out-of-fold predictions for downstream use ---
ALL[, xgb_pred := oof_pred]
fwrite(ALL[, .(pair, seat, party, pred_share, actual_share, xgb_pred)],
       file.path(OUT, "xgb-primary-oof-predictions.csv"))
cat(sprintf("\nwrote %s\n", file.path(OUT, "xgb-primary-oof-predictions.csv")))

# --- per-jurisdiction breakdown ---
cat("\nRMSE by jurisdiction (shipped vs xgb):\n")
print(ALL[, .(n = .N,
              shipped_rmse = sqrt(mean((pred_share - actual_share)^2)),
              xgb_rmse = sqrt(mean((xgb_pred - actual_share)^2))), by = region])
