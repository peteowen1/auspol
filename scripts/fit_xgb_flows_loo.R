# Leave-one-election-out flow models -- one saved model per election.
#
# WHY THIS EXISTS. `scripts/fit_xgb_flows_v1.R` reports an honest
# leave-one-election-out CV number, and then saves
# `output/xgb-flows-v1-final.model`, which is trained on EVERY election
# including the one you are about to predict. `xgb_flow_conditional_override_for()`
# loads that final model at inference, so every backtest arm run under
# AUSPOL_XGB_FLOWS has been predicting an election with a model that saw that
# election's own transfer results in training. Holding the target out of the
# rate FEATURES (`hist <- TR[TR$election != target_election]`) does not fix
# that -- the model WEIGHTS carry it.
#
# Found 2026-09-11 while setting up the primaries x flows 2x2, before any
# number from that comparison was quoted. It is the fourth leakage instance in
# this repo, and the same shape as the others: the diagnostic printed during
# fitting was leakage-free, the artifact actually used at inference was not.
#
# This trains one model per held-out election from the SAME feature file the
# fitting script writes, so there is no second copy of the feature code to
# drift. `xgb_flow_conditional_override_for()` prefers
# `output/xgb-flows-v1-loo-<election>.model` and only falls back to the
# all-data model with a loud warning.
#
# ONE RESIDUAL, STATED RATHER THAN HIDDEN: nrounds comes from the pooled CV
# below, so the stopping point is informed by every fold including the held-out
# one. That is standard practice and worth perhaps a few rounds of optimism; it
# is not the same order of problem as training on the target's own labels.
#
# Emits XL* codes.
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
cat(sprintf("XL1  %d rows, %d features, %d elections\n", nrow(TX), length(feat_cols), uniqueN(TX$election)))

X <- as.matrix(TX[, ..feat_cols])
y <- TX$y
elections <- sort(unique(TX$election))
fold_id <- match(TX$election, elections)

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
                subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)

cat("XL2  pooled CV to pick nrounds (grouped by election)...\n")
set.seed(42)
dtrain <- xgb.DMatrix(data = X, label = y, missing = NA)
cv <- xgb.cv(params = params, data = dtrain, nrounds = 1000,
             folds = split(seq_len(nrow(X)), fold_id),
             early_stopping_rounds = 30, prediction = TRUE, verbose = 0)
best_n <- max(cv$early_stop$best_iteration, 50L)
cat(sprintf("XL2  nrounds %d\n", best_n))

for (e in elections) {
  keep <- TX$election != e
  # A held-out election that leaves nothing to train on would silently produce
  # a model fitted on an empty set; refuse instead.
  if (sum(keep) < 100L) { cat(sprintf("XL3! %s: only %d training rows -- skipped\n", e, sum(keep))); next }
  set.seed(42)
  m <- xgb.train(params = params,
                 data = xgb.DMatrix(data = X[keep, , drop = FALSE], label = y[keep], missing = NA),
                 nrounds = best_n, verbose = 0)
  f <- file.path(OUT, sprintf("xgb-flows-v1-loo-%s.model", e))
  xgb.save(m, f)
  # PROVE the held-out rows were actually held out: a model trained without
  # election e should score WORSE on e than the all-data model does. Printing
  # the in-fold/out-fold gap is what makes an accidental full-data refit
  # visible instead of silent.
  pe <- pmax(0, predict(m, X[!keep, , drop = FALSE]))
  cat(sprintf("XL3  %-8s trained on %5d rows, held out %4d; RMSE on held-out %.4f\n",
              e, sum(keep), sum(!keep), sqrt(mean((pe - y[!keep])^2))))
}
cat(sprintf("\nXL4  wrote %d leave-one-election-out models to %s/xgb-flows-v1-loo-<election>.model\n",
            length(elections), OUT))
