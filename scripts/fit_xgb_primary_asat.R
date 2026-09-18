# POINT-IN-TIME ("as at") XGBoost primary models: one per target election,
# each trained ONLY on election pairs whose polling day is strictly before the
# target's. Pete, 2026-09-18: the AEF-7 ledger is the main debugging surface
# for the PRODUCTION model, so it must be built by the production pipeline --
# same training recipe, same parameters, same base_margin mechanism -- just
# frozen at an earlier date. Production (scripts/fit_xgb_primary_v6_final.R,
# served by xgb_primary_predict_live()) is the SAME recipe with cutoff = now.
#
# What this replaces for the backtests: output/xgb-primary-v6-oof-predictions
# .csv, the leave-one-pair-out cache. Leave-one-out lets the model for fed2022
# learn from fed2025, vic2022, sa2026 ... -- every OTHER election, including
# ones after the target. "As at" is stricter and is what a real forecast would
# have had. The predictions file written here has the SAME schema as the OOF
# file, so xgb_primary_override() reads it with no harness change:
# published_flags.R points AUSPOL_XGB_PRIMARY_OOF at it.
#
# Inputs: output/xgb-primary-features-v6.csv, written by fit_xgb_primary_v6.R
# from pooled-sharedetail.csv -- which MUST have been pooled from harness runs
# at AUSPOL_XGB_PRIMARY=0 (scripts/pool_sharedetail.R enforces this). base_pred
# in that file is the shipped-model baseline every model here starts from
# (base_margin). If base_pred is stale, every model here is stale: the driver
# scripts/rebuild_forecasts.sh runs the chain in the right order.
#
# Outputs:
#   output/xgb-primary-asat/<target>.ubj   one saved model per target
#   output/xgb-primary-asat/feat_cols.txt  the exact column order
#   output/xgb-primary-asat-manifest.csv   what each model was trained on
#   output/xgb-primary-asat-predictions.csv  (pair, seat, party, base_pred,
#       actual_share, xgb_pred, jump, governed, permit, surge_h, is_recipient)
#
# A target with fewer than MIN_PRIOR_PAIRS prior pairs gets NO model and NO
# rows in the predictions file -- the harness then keeps base_pred for it and
# logs "no xgb predictions for X". Printed here, not silent.
#
# Emits XA* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
MDIR <- file.path(OUT, "xgb-primary-asat")
dir.create(MDIR, showWarnings = FALSE, recursive = TRUE)
MIN_PRIOR_PAIRS <- as.integer(Sys.getenv("AUSPOL_ASAT_MIN_PAIRS", "4"))

# TWO files with near-identical names come out of fit_xgb_primary_v6.R:
#   xgb-primary-features-v6.csv  the raw 40-column build table (strings,
#                                 TRUE/FALSE, region) -- NOT a model matrix
#   xgb-primary-v6-features.csv  pair/seat/party/actual_share + the exact
#                                 numeric feat_cols the model trains on
# This reads the second. The first would as.matrix() to character and
# xgboost would fail (or worse, coerce). Caught before the first run.
ff <- file.path(OUT, "xgb-primary-v6-features.csv")
if (!file.exists(ff)) stop("XA0! ", ff, " missing -- run scripts/fit_xgb_primary_v6.R first")
ALL <- fread(ff, showProgress = FALSE)
cat(sprintf("XA0  %s: %d rows, %d pairs, mtime %s\n", ff, nrow(ALL), uniqueN(ALL$pair),
            format(file.mtime(ff), "%Y-%m-%d %H:%M")))
# Staleness, said out loud: the same check xgb_primary_override() does for the
# OOF cache. A features file older than the code that shapes base_pred means
# every model below inherits a baseline that no longer exists.
.deps <- c("R/candidate_returns.R", "R/dev_slope.R", "R/salience_screen.R",
           "output/pooled-sharedetail.csv", "scripts/fit_xgb_primary_v6.R")
.deps <- .deps[file.exists(.deps)]
.stale <- .deps[file.mtime(.deps) > file.mtime(ff)]
if (length(.stale)) cat(sprintf("XA0! %s is OLDER than %s -- base_pred may be stale; rerun fit_xgb_primary_v6.R first\n",
                                basename(ff), paste(.stale, collapse = ", ")))

# The feature list is whatever fit_xgb_primary_v6.R wrote: every column after
# the four identity/label columns. Reading it from the file rather than
# restating it here is deliberate -- fit_xgb_primary_v6_final.R restates it
# and its own header documents the drift that costs.
id_cols <- c("pair", "seat", "party", "actual_share")
feat_cols <- setdiff(names(ALL), id_cols)
# SAME FEATURE SET AS THE SERVED MODEL. fit_xgb_primary_v6_final.R deliberately
# excludes x_notional_adj (constant 0 for every non-federal row -- the
# constant-within-a-subgroup-becomes-a-label hazard, documented at its
# feat_cols). These models are production frozen at a date, so they follow
# production's list, not the leave-one-out arm's.
feat_cols <- setdiff(feat_cols, "x_notional_adj")
stopifnot("base_pred" %in% feat_cols)   # base_margin needs it; mode "1" drops it
cat(sprintf("XA0  %d features: %s\n", length(feat_cols), paste(feat_cols, collapse = " ")))
.base_margin_mode <- Sys.getenv("AUSPOL_XGB_BASE_MARGIN", "2")
if (!.base_margin_mode %in% c("1", "2"))
  stop("XA0! AUSPOL_XGB_BASE_MARGIN=", .base_margin_mode, " -- production ships \"2\"; as-at models must match")
if (identical(.base_margin_mode, "1")) feat_cols <- setdiff(feat_cols, "base_pred")

dates <- election_dates(unique(ALL$pair))
ALL[, .date := dates[pair]]
targets <- names(sort(dates))
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
               subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)

git_hash <- tryCatch(system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE), error = function(e) NA_character_)
built_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

preds <- list(); manifest <- list()
for (tg in targets) {
  t0 <- Sys.time()
  cutoff <- dates[[tg]]
  train_pairs <- names(dates)[dates < cutoff]
  if (length(train_pairs) < MIN_PRIOR_PAIRS) {
    cat(sprintf("XA1! %s (%s): only %d prior pair(s) (< %d) -- NO model, harness keeps base_pred\n",
                tg, cutoff, length(train_pairs), MIN_PRIOR_PAIRS))
    manifest[[tg]] <- data.table(target = tg, cutoff_date = cutoff, n_train_pairs = length(train_pairs),
                                 train_pairs = paste(train_pairs, collapse = ";"), n_train_rows = 0L,
                                 nrounds = NA_integer_, n_features = length(feat_cols),
                                 rmse_base = NA_real_, rmse_asat = NA_real_,
                                 model_file = NA_character_, git_hash = git_hash, built_at = built_at)
    next
  }
  TR <- ALL[pair %in% train_pairs]
  TE <- ALL[pair == tg]
  Xtr <- as.matrix(TR[, ..feat_cols]); ytr <- TR$actual_share
  Xte <- as.matrix(TE[, ..feat_cols])
  dtr <- xgb.DMatrix(data = Xtr, label = ytr, missing = NA)
  setinfo(dtr, "base_margin", TR$base_pred)
  # nrounds by grouped CV within the TRAINING set only -- the target never
  # touches the early-stopping decision either.
  fold_id <- match(TR$pair, sort(unique(TR$pair)))
  set.seed(42)
  cv <- xgb.cv(params = params, data = dtr, nrounds = 2000,
               folds = split(seq_len(nrow(Xtr)), fold_id),
               early_stopping_rounds = 30, verbose = 0)
  nr <- cv$early_stop$best_iteration
  set.seed(42)
  m <- xgb.train(params = params, data = dtr, nrounds = nr, verbose = 0)
  dte <- xgb.DMatrix(data = Xte, missing = NA)
  setinfo(dte, "base_margin", TE$base_pred)
  p <- pmax(0, predict(m, dte))
  mf <- file.path(MDIR, paste0(tg, ".ubj"))
  xgb.save(m, mf)
  rb <- sqrt(mean((TE$base_pred - TE$actual_share)^2))
  ra <- sqrt(mean((p - TE$actual_share)^2))
  cat(sprintf("XA2  %s (%s): %d prior pairs, %d rows, %d rounds | primary RMSE base %.4f -> as-at %.4f | %.0fs\n",
              tg, cutoff, length(train_pairs), nrow(TR), nr, rb, ra,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  preds[[tg]] <- TE[, .(pair, seat, party, base_pred, actual_share, xgb_pred = p,
                         jump, governed, permit, surge_h, is_recipient)]
  manifest[[tg]] <- data.table(target = tg, cutoff_date = cutoff, n_train_pairs = length(train_pairs),
                               train_pairs = paste(train_pairs, collapse = ";"), n_train_rows = nrow(TR),
                               nrounds = nr, n_features = length(feat_cols),
                               rmse_base = rb, rmse_asat = ra,
                               model_file = mf, git_hash = git_hash, built_at = built_at)
}
writeLines(feat_cols, file.path(MDIR, "feat_cols.txt"))
saveRDS(params, file.path(MDIR, "params.rds"))

P <- rbindlist(preds); M <- rbindlist(manifest)
fwrite(P, file.path(OUT, "xgb-primary-asat-predictions.csv"), na = "NA")
fwrite(M, file.path(OUT, "xgb-primary-asat-manifest.csv"), na = "NA")
cat(sprintf("\nXA3  wrote %s (%d rows, %d targets with a model)\n",
            file.path(OUT, "xgb-primary-asat-predictions.csv"), nrow(P), sum(!is.na(M$nrounds))))
cat(sprintf("XA3  wrote %s and %d model file(s) under %s\n", file.path(OUT, "xgb-primary-asat-manifest.csv"),
            sum(!is.na(M$model_file)), MDIR))

# Pooled, and against the leave-one-out cache if it exists -- the honest
# comparison: as-at is expected to be somewhat WORSE than leave-one-out on
# early targets (less data) and that is the price of not seeing the future.
cat(sprintf("\nXA4  pooled primary RMSE over %d rows: base %.4f -> as-at %.4f\n",
            nrow(P), sqrt(mean((P$base_pred - P$actual_share)^2)), sqrt(mean((P$xgb_pred - P$actual_share)^2))))
oof <- file.path(OUT, "xgb-primary-v6-oof-predictions.csv")
if (file.exists(oof)) {
  O <- fread(oof, showProgress = FALSE)[, .(pair, seat, party, oof_pred = xgb_pred)]
  J <- merge(P, O, by = c("pair", "seat", "party"))
  cat(sprintf("XA4  same %d rows, leave-one-out cache: %.4f (for reference only; it sees the future)\n",
              nrow(J), sqrt(mean((J$oof_pred - J$actual_share)^2))))
  cat("XA4  by pair (RMSE, lower is better):\n")
  print(J[, .(n = .N, base = round(sqrt(mean((base_pred - actual_share)^2)), 3),
              asat = round(sqrt(mean((xgb_pred - actual_share)^2)), 3),
              loo = round(sqrt(mean((oof_pred - actual_share)^2)), 3)), by = pair][order(pair)])
}
