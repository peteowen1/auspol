# Time-forward, optionally recency-weighted, flow models: the strong version of
# the AUSPOL_FLOW_RATE_HL arm (docs/reviews/lnp-onp-flows-by-election-2026-10-11.md).
#
# The shipped flow trees (fit_xgb_flows_v1.R -> fit_xgb_flows_asat.R) learn from
# a rate feature built leave-one-election-out -- every OTHER election, later ones
# included -- while prediction feeds them an earlier-only, equal-weight rate. This
# rebuilds the four rate columns (cond_rate, cond_n, pool_rate, pool_n) for every
# row of election E from elections BEFORE E only, through .flow_rates_tf() (the
# same function prediction calls under AUSPOL_FLOW_TF=1), then trains one as-at
# model per election exactly as fit_xgb_flows_asat.R does: same params, same
# nrounds (read from the shipped manifest), same minimum of earlier elections.
# Every other feature column is untouched.
#
# Writes, never overwriting a shipped file:
#   output/xgb-flows-v1-<tag>-features.csv
#   output/xgb-flows-v1-<tag>-asat-<election>.model
#   output/xgb-flows-<tag>-asat-manifest.csv
# Run: Rscript scripts/fit_xgb_flows_tf.R <tag> <half-life years, 0 = equal>
# Read with AUSPOL_FLOW_TF=1 AUSPOL_FLOW_MODEL_TAG=<tag> AUSPOL_FLOW_RATE_HL=<same half-life>.
# No live (vic2026) model is written: backtests only until an arm earns it.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))
a <- commandArgs(TRUE)
if (length(a) < 2) stop("usage: Rscript scripts/fit_xgb_flows_tf.R <tag> <half-life years>")
TAG <- a[1]; HL <- as.numeric(a[2])
if (!nzchar(TAG) || !grepl("^[A-Za-z0-9]+$", TAG)) stop("tag must be alphanumeric")
if (!is.finite(HL) || HL < 0) stop("half-life must be a number >= 0")
OUT <- "output"
feat_f <- file.path(OUT, "xgb-flows-v1-features.csv")
cols_f <- file.path(OUT, "xgb-flows-v1-final-cols.json")
man0_f <- file.path(OUT, "xgb-flows-asat-manifest.csv")
TX <- fread(feat_f, showProgress = FALSE)
feat_cols <- jsonlite::fromJSON(readLines(cols_f))
M0 <- fread(man0_f, showProgress = FALSE)
NROUNDS <- unique(M0$nrounds); stopifnot(length(NROUNDS) == 1L, is.finite(NROUNDS))
MIN_PAIRS <- as.integer(Sys.getenv("AUSPOL_ASAT_MIN_PAIRS", "4"))
dates <- election_dates()
unknown <- setdiff(unique(TX$election), names(dates))
if (length(unknown)) stop("election_dates() has no date for: ", paste(unknown, collapse = ", "))
el_dates <- dates[TX$election]
elections <- names(sort(dates[unique(TX$election)]))
cat(sprintf("XFT0  tag %s | half-life %s | %d rows, %d elections (%s..%s) | nrounds %d (shipped manifest) | min prior %d\n",
            TAG, if (HL > 0) sprintf("%.2f y", HL) else "none (equal weight)", nrow(TX), length(elections),
            elections[1], elections[length(elections)], NROUNDS, MIN_PAIRS))

# ---- 1. time-forward rate columns, election by election ----------------------
old <- TX[, c("cond_rate", "cond_n", "pool_rate", "pool_n")]
rows_out <- vector("list", length(elections)); names(rows_out) <- elections
for (e in elections) {
  te <- which(TX$election == e)
  prior <- which(el_dates < dates[[e]])
  R <- TX[te]
  if (length(prior)) {
    rt <- .flow_rates_tf(TX[prior], dates[[e]], HL, dates)
    R[, c("cond_rate", "cond_n", "pool_rate", "pool_n") := NULL]
    R <- merge(R, rt$cond[, c("from", "surv", "to", "cond_rate", "cond_n")], by = c("from", "surv", "to"), all.x = TRUE)
    R <- merge(R, rt$pool, by = c("from", "to"), all.x = TRUE)
  } else {
    R[, `:=`(cond_rate = NA_real_, cond_n = NA_real_, pool_rate = NA_real_, pool_n = NA_real_)]
  }
  rows_out[[e]] <- R
}
TF <- rbindlist(rows_out, use.names = TRUE)
for (cc in c("cond_rate", "cond_n", "pool_rate", "pool_n")) set(TF, which(is.na(TF[[cc]])), cc, 0)
if (nrow(TF) != nrow(TX)) stop(sprintf("row count changed: %d -> %d", nrow(TX), nrow(TF)))
cat(sprintf("XFT1  rate columns rebuilt: cond_rate populated (>0 n) on %d of %d rows (%.1f%%); old LOO feature populated on %.1f%%\n",
            sum(TF$cond_n > 0), nrow(TF), 100 * mean(TF$cond_n > 0), 100 * mean(old$cond_n > 0)))
# ANCHOR: One Nation -> Liberal, Labor and Liberal left, the cell that started this.
.a <- TF[from == "ONP" & surv == "ALP+LNP" & to == "LNP", list(feature = round(100 * mean(cond_rate), 1),
                                                               actual = round(100 * sum(votes) / sum(event_votes), 1)), by = election]
cat("XFT2  ON -> Lib (ALP+LNP left): time-forward feature vs actual, percent\n"); print(.a[order(dates[election])])
tf_feat_f <- file.path(OUT, sprintf("xgb-flows-v1-%s-features.csv", TAG))
fwrite(TF, tf_feat_f)

# ---- 2. one as-at model per election ------------------------------------------
X <- as.matrix(TF[, ..feat_cols]); y <- TF$y
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
               subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)
tf_dates <- dates[TF$election]
man <- list()
for (e in elections) {
  prior <- unique(TF$election[tf_dates < dates[[e]]])
  if (length(prior) < MIN_PAIRS) { cat(sprintf("XFT3! %-8s only %d prior election(s): no model\n", e, length(prior))); next }
  keep <- TF$election %in% prior
  set.seed(as.integer(Sys.getenv("AUSPOL_XGB_SEED", "42")))
  m <- xgb.train(params = params, data = xgb.DMatrix(X[keep, , drop = FALSE], label = y[keep], missing = NA),
                 nrounds = NROUNDS, verbose = 0)
  f <- file.path(OUT, sprintf("xgb-flows-v1-%s-asat-%s.model", TAG, e))
  xgb.save(m, f)
  te <- TF$election == e
  pe <- pmax(0, predict(m, X[te, , drop = FALSE]))
  cat(sprintf("XFT3  %-8s %2d prior elections, %5d rows; RMSE on this election %.4f\n",
              e, length(prior), sum(keep), sqrt(mean((pe - y[te])^2))))
  man[[e]] <- data.table(election = e, n_prior = length(prior), n_train = sum(keep), nrounds = NROUNDS,
                         half_life = HL, rmse = sqrt(mean((pe - y[te])^2)), file = basename(f))
}
# ---- 3. live targets: elections not yet held, trained on every corpus row ------
# Every corpus election precedes them, so the all-rows model IS as-at for them.
# Named on the command line (default vic2026), never inferred from the date list.
LIVE <- if (length(a) >= 3) strsplit(a[3], ",")[[1]] else "vic2026"
for (e in LIVE) {
  if (!e %in% names(dates)) stop("live target ", e, " has no election date")
  if (!all(TF$election %in% names(dates)[dates < dates[[e]]]))
    stop("live target ", e, ": the corpus holds elections on or after it, so an all-rows model would leak")
  set.seed(as.integer(Sys.getenv("AUSPOL_XGB_SEED", "42")))
  m <- xgb.train(params = params, data = xgb.DMatrix(X, label = y, missing = NA), nrounds = NROUNDS, verbose = 0)
  f <- file.path(OUT, sprintf("xgb-flows-v1-%s-asat-%s.model", TAG, e))
  xgb.save(m, f)
  cat(sprintf("XFT5  %-8s LIVE: all %d corpus elections, %d rows -> %s\n", e, uniqueN(TF$election), nrow(TF), basename(f)))
  man[[e]] <- data.table(election = e, n_prior = uniqueN(TF$election), n_train = nrow(TF), nrounds = NROUNDS,
                         half_life = HL, rmse = NA_real_, file = basename(f))
}
M <- rbindlist(man)
fwrite(M, file.path(OUT, sprintf("xgb-flows-%s-asat-manifest.csv", TAG)))
cat(sprintf("\nXFT4  wrote %d as-at flow models (tag %s) and %s\n", nrow(M), TAG, basename(tf_feat_f)))
