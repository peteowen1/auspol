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
# The published configuration for every switch the caller left unset: this
# script reads switches only from the environment, so without this a plain run
# used its own inline defaults, not what ships (v57's x_notional_adj, 2026-10-02).
source("scripts/published_flags.R"); apply_published_flags()
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

# TRAINING-ROW WEIGHTS AND LABELS (plans/prereg-training-weights-2026-10-13.md; all off by default):
#   AUSPOL_TRAIN_DECAY_H       half-life in years: a row from an election `age` years before the target counts 0.5^(age/h)
#   AUSPOL_TRAIN_COMPLETENESS  "1": also scale by the row's share of non-missing features (relative to the training
#                              set's 90th percentile, capped at 1)
#   AUSPOL_TRAIN_DEMEAN        "1": subtract each training election's mean residual (actual - base_pred) per party
#                              class from the label, so the model learns within-election structure, not that election's
#                              statewide miss (vic2010 taught "Greens -4.4, Coalition +3.1"; vic2018 was the opposite)
.decay_h <- suppressWarnings(as.numeric(Sys.getenv("AUSPOL_TRAIN_DECAY_H", "Inf"))); if (is.na(.decay_h) || .decay_h <= 0) .decay_h <- Inf
.compl_on <- identical(Sys.getenv("AUSPOL_TRAIN_COMPLETENESS", "0"), "1")
.demean_on <- identical(Sys.getenv("AUSPOL_TRAIN_DEMEAN", "0"), "1")
cat(sprintf("XA0w training weights: decay half-life %s years, completeness %s, per-election demean %s\n",
            format(.decay_h), if (.compl_on) "ON" else "off", if (.demean_on) "ON" else "off"))
train_w <- function(D, cutoff) {
  age <- as.numeric(as.Date(cutoff) - as.Date(D$.date)) / 365.25
  w <- if (is.finite(.decay_h)) 0.5^(age / .decay_h) else rep(1, nrow(D))
  if (.compl_on) {
    cmp <- rowMeans(!is.na(as.matrix(D[, feat_cols, with = FALSE])))
    w <- w * pmin(1, cmp / stats::quantile(cmp, 0.9))
  }
  w
}
train_label <- function(D) {
  if (!.demean_on) return(D$actual_share)
  r <- D$actual_share - D$base_pred
  D$actual_share - stats::ave(r, D$pair, D$party)
}
git_hash <- tryCatch(system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE), error = function(e) NA_character_)
built_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

# SKIP-IF-CURRENT (2026-09-20, the fast loop): a target's model depends only on
# its training rows, its own rows, the feature list, the params and the
# base-margin mode. Hash those; if the previous manifest carries the same key
# and the model file exists, reuse the saved predictions instead of the
# ~15 s xgb.cv + train. A rebuild that changes one election's base_pred then
# retrains only the targets dated after it. AUSPOL_ASAT_FORCE=1 retrains all.
man_f <- file.path(OUT, "xgb-primary-asat-manifest.csv"); pred_f <- file.path(OUT, "xgb-primary-asat-predictions.csv")
# Checkpoints go to .partial copies, renamed over the real files only when every target is done, so a killed run
# never leaves a half-new predictions file for a resume from stage 5 or 6 to read. A rerun of this stage resumes
# from the .partial pair when both exist (they hold the finished targets plus the previous files' other rows).
man_part <- paste0(man_f, ".partial"); pred_part <- paste0(pred_f, ".partial")
.resume <- file.exists(man_part) && file.exists(pred_part)
if (.resume) cat(sprintf("XA0p resuming from %s and %s (a previous run of this stage was killed)\n", man_part, pred_part))
OLDM <- if (.resume) fread(man_part, showProgress = FALSE) else if (file.exists(man_f)) fread(man_f, showProgress = FALSE) else NULL
OLDP <- if (.resume) fread(pred_part, showProgress = FALSE) else if (file.exists(pred_f)) fread(pred_f, showProgress = FALSE) else NULL
if (!is.null(OLDM) && !"input_key" %in% names(OLDM)) OLDM <- NULL
.force <- identical(Sys.getenv("AUSPOL_ASAT_FORCE", "0"), "1")
n_cached <- 0L
preds <- list(); manifest <- list()
.train_skip <- trimws(strsplit(Sys.getenv("AUSPOL_TRAIN_SKIP_PAIRS", ""), ",")[[1]]); .train_skip <- .train_skip[nzchar(.train_skip)]
if (length(.train_skip)) cat(sprintf("XA0t AUSPOL_TRAIN_SKIP_PAIRS: %s scored but never used as training rows\n", paste(.train_skip, collapse = ", ")))
for (tg in targets) {
  t0 <- Sys.time()
  cutoff <- dates[[tg]]
  train_pairs <- names(dates)[dates < cutoff]
  # AUSPOL_TRAIN_SKIP_PAIRS (2026-10-13, Pete): pairs SCORED but kept out of every target's training rows, until the
  # decay + completeness weights exist (docs/plans/weighting-design-2026-10-13.md; vic2010 as training data made later
  # elections worse per person, AEF-7 +0.0043 beyond 1 SE).
  train_pairs <- setdiff(train_pairs, .train_skip)
  if (length(train_pairs) < MIN_PRIOR_PAIRS) {
    cat(sprintf("XA1! %s (%s): only %d prior pair(s) (< %d) -- NO model, harness keeps base_pred\n",
                tg, cutoff, length(train_pairs), MIN_PRIOR_PAIRS))
    manifest[[tg]] <- data.table(target = tg, cutoff_date = cutoff, n_train_pairs = length(train_pairs),
                                 train_pairs = paste(train_pairs, collapse = ";"), n_train_rows = 0L,
                                 nrounds = NA_integer_, n_features = length(feat_cols),
                                 rmse_base = NA_real_, rmse_asat = NA_real_,
                                 model_file = NA_character_, git_hash = git_hash, built_at = built_at, input_key = NA_character_)
    next
  }
  TR <- ALL[pair %in% train_pairs]
  TE <- ALL[pair == tg]
  # The SEED is part of the key: without it a run that changed only
  # AUSPOL_XGB_SEED silently reused the previous seed's models (2026-10-02,
  # the noise-floor measurement's seed-99 run returned seed 7's predictions).
  key <- digest::digest(list(params, feat_cols, .base_margin_mode, Sys.getenv("AUSPOL_XGB_SEED", "42"),
                             Sys.getenv("AUSPOL_XGB_ENSEMBLE", "1"), .decay_h, .compl_on, .demean_on,
                             as.data.frame(TR[, c(id_cols, feat_cols), with = FALSE]),
                             as.data.frame(TE[, c(id_cols, feat_cols), with = FALSE])))
  mf <- file.path(MDIR, paste0(tg, ".ubj"))
  if (!.force && !is.null(OLDM) && !is.null(OLDP) && tg %in% OLDM$target && identical(OLDM[target == tg]$input_key[1], key) &&
      file.exists(mf) && nrow(OLDP[pair == tg]) == nrow(TE)) {
    preds[[tg]] <- OLDP[pair == tg]; manifest[[tg]] <- OLDM[target == tg][1]
    n_cached <- n_cached + 1L
    cat(sprintf("XA2  %s (%s): CACHED, inputs unchanged (key %s) | RMSE base %.4f -> as-at %.4f
", tg, cutoff,
                substr(key, 1, 8), manifest[[tg]]$rmse_base, manifest[[tg]]$rmse_asat))
    next
  }
  Xtr <- as.matrix(TR[, ..feat_cols]); ytr <- train_label(TR)
  Xte <- as.matrix(TE[, ..feat_cols])
  dtr <- xgb.DMatrix(data = Xtr, label = ytr, missing = NA)
  setinfo(dtr, "base_margin", TR$base_pred)
  .wtr <- train_w(TR, cutoff)
  if (is.finite(.decay_h) || .compl_on) setinfo(dtr, "weight", .wtr)
  # nrounds by grouped CV within the TRAINING set only -- the target never
  # touches the early-stopping decision either.
  fold_id <- match(TR$pair, sort(unique(TR$pair)))
  set.seed(as.integer(Sys.getenv("AUSPOL_XGB_SEED", "42")))
  cv <- xgb.cv(params = params, data = dtr, nrounds = 2000,
               folds = split(seq_len(nrow(Xtr)), fold_id),
               early_stopping_rounds = 30, verbose = 0)
  nr <- cv$early_stop$best_iteration
  # SEED ENSEMBLE (AUSPOL_XGB_ENSEMBLE = K, default 1 = unchanged): K models on
  # the SAME rounds (the CV above, the expensive part, runs once) with seeds
  # base, base+1, ...; raw predictions averaged, then floored at 0. An equally
  # valid refit moved Victoria's log loss by up to 0.011 (plans/noise-floor-
  # 2026-10-02.md); averaging K fits shrinks that by ~sqrt(K).
  .K <- max(1L, as.integer(Sys.getenv("AUSPOL_XGB_ENSEMBLE", "1")))
  .seed0 <- as.integer(Sys.getenv("AUSPOL_XGB_SEED", "42"))
  dte <- xgb.DMatrix(data = Xte, missing = NA)
  setinfo(dte, "base_margin", TE$base_pred)
  .raw <- 0
  for (.k in seq_len(.K)) {
    set.seed(.seed0 + .k - 1L)
    m <- xgb.train(params = params, data = dtr, nrounds = nr, verbose = 0)
    .raw <- .raw + predict(m, dte) / .K
    xgb.save(m, if (.k == 1L) mf else sub("[.]ubj$", sprintf("-m%d.ubj", .k), mf))
  }
  p <- pmax(0, .raw)
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
                               model_file = mf, git_hash = git_hash, built_at = built_at, input_key = key)
  # CHECKPOINT after every trained target (2026-10-14): the run is ~25 min at 35 elections and wrote only at the
  # end, so a kill at nsw2023 (01:34 that night) lost every target before it. Targets done so far, plus the previous
  # files' rows for targets not reached yet, are written now to the .partial pair; a rerun WITHOUT AUSPOL_ASAT_FORCE
  # then reuses each finished target by its input key and trains only the rest. The real files change only at the end.
  .ck <- function(new, old, idcol) data.table::rbindlist(c(new, if (!is.null(old)) list(old[!old[[idcol]] %in% names(new)])), fill = TRUE)
  fwrite(.ck(preds, OLDP, "pair"), pred_part, na = "NA")
  fwrite(.ck(manifest, OLDM, "target"), man_part, na = "NA")
}
writeLines(feat_cols, file.path(MDIR, "feat_cols.txt"))
saveRDS(params, file.path(MDIR, "params.rds"))

cat(sprintf("XA3  %d of %d targets reused from cache (AUSPOL_ASAT_FORCE=1 to retrain all)
", n_cached, length(targets)))
P <- rbindlist(preds); M <- rbindlist(manifest)
fwrite(P, file.path(OUT, "xgb-primary-asat-predictions.csv"), na = "NA")
fwrite(M, file.path(OUT, "xgb-primary-asat-manifest.csv"), na = "NA")
unlink(c(pred_part, man_part))
cat(sprintf("\nXA3  wrote %s (%d rows, %d targets with a model)\n",
            file.path(OUT, "xgb-primary-asat-predictions.csv"), nrow(P), sum(!is.na(M$nrounds))))
cat(sprintf("XA3  wrote %s and %d model file(s) under %s\n", file.path(OUT, "xgb-primary-asat-manifest.csv"),
            sum(!is.na(M$model_file)), MDIR))

# Pooled, and against the leave-one-out cache if it exists -- the honest
# comparison: as-at is expected to be somewhat WORSE than leave-one-out on
# early targets (less data) and that is the price of not seeing the future.
# Headline is WEIGHTED by actual vote share (Pete, 2026-09-18: "primary RMSE
# should always be actual weighted"): a 2-point miss on a 40% candidate is a
# forecast error, the same miss on a 3% candidate barely moves any seat. The
# unweighted figure is kept beside it because that is what the training
# objective minimises.
wrmse <- function(p, a) sqrt(sum(a * (p - a)^2) / sum(a))
cat(sprintf("\nXA4  pooled primary RMSE over %d rows, WEIGHTED by actual share: base %.4f -> as-at %.4f  (unweighted %.4f -> %.4f)\n",
            nrow(P), wrmse(P$base_pred, P$actual_share), wrmse(P$xgb_pred, P$actual_share),
            sqrt(mean((P$base_pred - P$actual_share)^2)), sqrt(mean((P$xgb_pred - P$actual_share)^2))))
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
