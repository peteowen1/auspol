# v3: adds the surge-v2 hazard (surge_h per seat, plus which class it names
# as recipient) on top of v2's salience features. Pete asked for salience
# AND surge; v2 only had salience. Same leave-one-pair-out discipline.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
ALL <- fread(file.path(OUT, "xgb-primary-features.csv"), showProgress = FALSE)
ALL <- ALL[is.finite(level_prev) & is.finite(level_now)]

PAIRS <- list(
  list(election = "fed2007", prev = "fed2004", region = "fed"),
  list(election = "fed2010", prev = "fed2007", region = "fed"),
  list(election = "fed2013", prev = "fed2010", region = "fed"),
  list(election = "fed2016", prev = "fed2013", region = "fed"),
  list(election = "fed2019", prev = "fed2016", region = "fed"),
  list(election = "fed2022", prev = "fed2019", region = "fed"),
  list(election = "fed2025", prev = "fed2022", region = "fed"),
  list(election = "nsw2019", prev = "nsw2015", region = "nsw"),
  list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
  list(election = "qld2020", prev = "qld2017", region = "qld"),
  list(election = "qld2024", prev = "qld2020", region = "qld"),
  list(election = "sa2026",  prev = "sa2022",  region = "sa"),
  list(election = "vic2014", prev = "vic2010", region = "vic"),
  list(election = "vic2018", prev = "vic2014", region = "vic"),
  list(election = "vic2022", prev = "vic2018", region = "vic")
)

cat("=== salience features (same as v2) ===\n")
sal_rows <- list()
for (pr in PAIRS) {
  s <- tryCatch(governed_population(pr$election, pr$prev, pr$region), error = function(e) NULL)
  if (is.null(s) || !nrow(s)) next
  s[, permit := salience_screen(jump, governed)]
  sal_rows[[pr$election]] <- s[, .(pair = pr$election, seat, party, jump, governed = as.integer(governed), permit = as.integer(permit))]
}
SAL <- rbindlist(sal_rows, fill = TRUE)
ALL <- merge(ALL, SAL, by = c("pair","seat","party"), all.x = TRUE)
ALL[, jump := ifelse(is.na(jump), 0, jump)]
ALL[, governed := ifelse(is.na(governed), 0L, governed)]
ALL[, permit := ifelse(is.na(permit), 0L, permit)]

cat("\n=== surge-v2 hazard features (NEW in v3) ===\n")
SURGE_CANON <- list(
  list(election = "fed2010", prev = "fed2007", region = "fed"),
  list(election = "fed2013", prev = "fed2010", region = "fed"),
  list(election = "fed2016", prev = "fed2013", region = "fed"),
  list(election = "fed2019", prev = "fed2016", region = "fed"),
  list(election = "fed2022", prev = "fed2019", region = "fed"),
  list(election = "vic2022", prev = "vic2018", region = "vic"),
  list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
  list(election = "sa2026",  prev = "sa2022",  region = "sa"),
  list(election = "wa2008",  prev = "wa2005",  region = "wa")
)
surge_rows <- list()
for (pr in PAIRS) {
  in_canon <- any(vapply(SURGE_CANON, function(p) identical(p$election, pr$election), TRUE))
  if (!in_canon) { cat(sprintf("XG3! %s not in surge-v2 training population; surge_h = 0\n", pr$election)); next }
  train_pairs <- Filter(function(p) !identical(p$election, pr$election), SURGE_CANON)
  hz <- tryCatch(surge_hazard_for(pr$election, pr$prev, pr$region, train_pairs), error = function(e) {
    cat(sprintf("XG3! surge_hazard_for FAILED for %s: %s\n", pr$election, conditionMessage(e))); NULL
  })
  if (is.null(hz)) next
  sh <- hz$seat_hazard[, .(pair = pr$election, seat, surge_h)]
  rc <- hz$seat_recipient[, .(pair = pr$election, seat, recipient_party = party)]
  m <- merge(sh, rc, by = c("pair","seat"), all = TRUE)
  surge_rows[[pr$election]] <- m
  cat(sprintf("XG3  %s: surge hazard for %d seats\n", pr$election, nrow(m)))
}
SURGE <- rbindlist(surge_rows, fill = TRUE)
ALL <- merge(ALL, SURGE, by = c("pair","seat"), all.x = TRUE)
ALL[, surge_h := ifelse(is.na(surge_h), 0, surge_h)]
ALL[, is_recipient := as.integer(!is.na(recipient_party) & recipient_party == party)]

base_rmse <- sqrt(mean((ALL$pred_share - ALL$actual_share)^2))
cat(sprintf("\nBASELINE (shipped model) pooled primary RMSE, this population: %.4f  (n=%d)\n", base_rmse, nrow(ALL)))

ALL[, same_i := as.integer(same)]
ALL[, same_mp_i := as.integer(same_mp)]
ALL[, is_major_i := as.integer(is_major)]
party_levels <- sort(unique(ALL$party))
region_levels <- sort(unique(ALL$region))
for (p in party_levels) ALL[[paste0("party_", p)]] <- as.integer(ALL$party == p)
for (r in region_levels) ALL[[paste0("region_", r)]] <- as.integer(ALL$region == r)

feat_cols <- c("pred_share", "x", "level_prev", "level_now", "dev_prev",
               "n_cand_prev", "n_cand_now", "same_i", "same_mp_i", "is_major_i",
               "jump", "governed", "permit", "surge_h", "is_recipient",
               paste0("party_", party_levels), paste0("region_", region_levels))
X <- as.matrix(ALL[, ..feat_cols])
y <- ALL$actual_share
pairs <- sort(unique(ALL$pair))
fold_id <- match(ALL$pair, pairs)
dtrain <- xgb.DMatrix(data = X, label = y)
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
                subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)

cat("\nrunning xgb.cv with salience + surge features, leave-one-pair-out...\n")
set.seed(42)
cv <- xgb.cv(params = params, data = dtrain, nrounds = 2000, folds = split(seq_len(nrow(X)), fold_id),
             early_stopping_rounds = 30, prediction = TRUE, verbose = 0)
best_n <- cv$early_stop$best_iteration
oof_pred <- cv$cv_predict$pred[, 1]
xgb_rmse <- sqrt(mean((oof_pred - y)^2))
cat(sprintf("best nrounds: %d\n", best_n))
cat(sprintf("XGBOOST v3 (+ salience + surge) pooled primary RMSE: %.4f  (n=%d)\n", xgb_rmse, length(y)))
cat(sprintf("improvement vs shipped model: %.2f%%\n", 100 * (base_rmse - xgb_rmse) / base_rmse))

final <- xgb.train(params = params, data = dtrain, nrounds = best_n, verbose = 0)
imp <- xgb.importance(feature_names = feat_cols, model = final)
cat("\ntop 15 features by gain:\n")
print(head(imp, 15))

ALL[, xgb_pred_v3 := oof_pred]
fwrite(ALL[, .(pair, seat, party, pred_share, actual_share, xgb_pred_v3, jump, governed, permit, surge_h, is_recipient)],
       file.path(OUT, "xgb-primary-oof-predictions-v3.csv"))

cat("\n=== SA2026 ONP specifically ===\n")
sa <- ALL[pair == "sa2026" & party == "ONP"]
sa[, err_shipped := abs(pred_share - actual_share)]
sa[, err_v3 := abs(xgb_pred_v3 - actual_share)]
print(sa[order(-err_shipped), .(seat, actual_share = round(actual_share,1), pred_share = round(pred_share,1),
                                 xgb_v3 = round(xgb_pred_v3,1), surge_h = round(surge_h,3), is_recipient, permit)][1:10])
cat(sprintf("\nSA ONP mean abs error: shipped %.2f -> xgb v1 (no salience/surge) 5.52 -> xgb v3 %.2f\n",
            mean(sa$err_shipped), mean(sa$err_v3)))
