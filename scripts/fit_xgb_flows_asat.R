# One xgb-flows-v1 model per election, trained ONLY on elections whose polling
# day precedes it -- the "as at" counterpart of scripts/fit_xgb_flows_loo.R,
# whose leave-one-election-out models see later elections (fed2025, sa2026)
# when predicting vic2022. Same leak shape the primary cache had until
# 2026-09-18 (scripts/fit_xgb_primary_asat.R); same fix. Same params, same
# feature file, same nrounds rule as the LOO trainer, so the only difference
# is which rows each model is allowed to learn from.
#
# Writes output/xgb-flows-v1-asat-<election>.model for every election with
# at least AUSPOL_ASAT_MIN_PAIRS (default 4) earlier elections in the
# corpus; earlier ones get no model, and xgb_flow_conditional_override_for()
# then falls back to the pooled flow table (the same failure-open path as a
# missing model today), saying so. Read by R/xgb_flow_override.R when
# AUSPOL_FLOW_ASAT=1. Stage 4b of scripts/rebuild_forecasts.sh.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))
OUT <- "output"
feat_f <- file.path(OUT, "xgb-flows-v1-features.csv")
cols_f <- file.path(OUT, "xgb-flows-v1-final-cols.json")
if (!file.exists(feat_f) || !file.exists(cols_f))
  stop("run scripts/fit_xgb_flows_v1.R first -- need ", feat_f, " and ", cols_f)
TX <- fread(feat_f, showProgress = FALSE)
feat_cols <- jsonlite::fromJSON(readLines(cols_f))
miss <- setdiff(feat_cols, names(TX))
if (length(miss)) stop("feature file lacks: ", paste(miss, collapse = ", "))
MIN_PAIRS <- as.integer(Sys.getenv("AUSPOL_ASAT_MIN_PAIRS", "4"))
dates <- election_dates()
unknown <- setdiff(unique(TX$election), names(dates))
if (length(unknown)) stop("election_dates() has no date for: ", paste(unknown, collapse = ", "))
TX[, .d := dates[election]]
cat(sprintf("XFA1 %d rows, %d features, %d elections; min prior elections %d\n",
            nrow(TX), length(feat_cols), uniqueN(TX$election), MIN_PAIRS))
X <- as.matrix(TX[, ..feat_cols]); y <- TX$y
elections <- names(sort(dates[unique(TX$election)]))
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
               subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)
# nrounds from the pooled grouped CV, as the LOO trainer does. This is one
# hyperparameter chosen with every election in view -- the same mild leak
# fit_xgb_primary_asat.R avoids by running CV per target; kept here to stay
# byte-comparable with the LOO models it replaces. Noted, not hidden.
man_f <- file.path(OUT, "xgb-flows-asat-manifest.csv")
# THE CACHE KEY IS NOT JUST THE FEATURE FILE. A params or CV-setting change
# here leaves feat_f untouched, so an mtime-only check would reuse models
# trained under the old settings and print a normal-looking no-op (review
# gate, 2026-09-18). The manifest records this hash; a mismatch refits.
CONFIG_KEY <- digest::digest(list(params = params, nrounds_cap = 1000L, early_stop = 30L, min_pairs = MIN_PAIRS, feat_cols = feat_cols))
best_n <- NULL; cache_ok <- FALSE
if (file.exists(man_f) && file.mtime(man_f) > file.mtime(feat_f) && !identical(Sys.getenv("AUSPOL_ASAT_FORCE"), "1")) {
  M0 <- fread(man_f, showProgress = FALSE)
  if ("config_key" %in% names(M0) && all(M0$config_key == CONFIG_KEY)) {
    best_n <- unique(M0$nrounds)[1]; cache_ok <- TRUE
    cat(sprintf("XFA2 nrounds %d (from the manifest; feature file and training config unchanged)\n", best_n))
  } else {
    cat("XFA2 manifest is from a different training config (params/CV/features) -- refitting every model\n")
  }
}
if (is.null(best_n) || !is.finite(best_n)) {
  set.seed(42)
  cv <- xgb.cv(params = params, data = xgb.DMatrix(X, label = y, missing = NA), nrounds = 1000,
               folds = split(seq_len(nrow(X)), match(TX$election, unique(TX$election))),
               early_stopping_rounds = 30, verbose = 0)
  best_n <- max(cv$early_stop$best_iteration, 50L)
  cat(sprintf("XFA2 nrounds %d (pooled grouped CV)\n", best_n))
}
manifest <- list()
for (e in elections) {
  prior <- unique(TX$election[TX$.d < dates[[e]]])
  if (length(prior) < MIN_PAIRS) {
    cat(sprintf("XFA3! %s (%s): only %d prior election(s) (< %d) -- NO model; the pooled flow table applies\n",
                e, dates[[e]], length(prior), MIN_PAIRS)); next
  }
  keep <- TX$election %in% prior
  f <- file.path(OUT, sprintf("xgb-flows-v1-asat-%s.model", e))
  # RESUMABLE AND INCREMENTAL: a model newer than the feature file it was
  # trained from is current -- skip it. This stage is ~5 minutes cold (21
  # models x ~1000 rounds); the feature file changes only when
  # fit_xgb_flows_v1.R reruns, so a rebuild normally pays nothing here.
  # Delete the .model files (or touch the feature file) to force a refit.
  if (cache_ok && file.exists(f) && file.mtime(f) > file.mtime(feat_f) && !identical(Sys.getenv("AUSPOL_ASAT_FORCE"), "1")) {
    m <- xgb.load(f)
    cat(sprintf("XFA3= %-8s current (model newer than %s), not refitted\n", e, basename(feat_f)))
  } else {
    set.seed(42)
    m <- xgb.train(params = params, data = xgb.DMatrix(X[keep, , drop = FALSE], label = y[keep], missing = NA),
                   nrounds = best_n, verbose = 0)
    xgb.save(m, f)
  }
  te <- TX$election == e
  pe <- pmax(0, predict(m, X[te, , drop = FALSE]))
  cat(sprintf("XFA3 %-8s (%s): %2d prior elections, %5d rows; RMSE on this election %.4f\n",
              e, dates[[e]], length(prior), sum(keep), sqrt(mean((pe - y[te])^2))))
  manifest[[e]] <- data.table(election = e, date = as.character(dates[[e]]), n_prior = length(prior),
                              n_train = sum(keep), nrounds = best_n, file = basename(f), config_key = CONFIG_KEY)
}
M <- rbindlist(manifest)
fwrite(M, file.path(OUT, "xgb-flows-asat-manifest.csv"))
cat(sprintf("\nXFA4 wrote %d as-at flow models and output/xgb-flows-asat-manifest.csv\n", nrow(M)))
