# Load a cached leave-one-pair-out model (scripts/fit_xgb_primary_v6.R,
# AUSPOL_XGB_SAVE_OOF_MODELS=1) and compute SHAP for specific rows, without
# retraining. Built 2026-09-16 mid the Parramatta/Mirani walkthrough -- ad
# hoc single-seat SHAP questions were each costing a full xgb.cv run.
#
# Usage: AUSPOL_SHAP_PAIR=nsw2023 AUSPOL_SHAP_SEAT=Parramatta Rscript scripts/shap_from_cached_model.R
# AUSPOL_SHAP_PARTY optionally narrows to one party; omitted prints every
# party at that seat.
#
# If output/xgb-primary-v6-featurecache.rds is missing or older than
# candidacies.csv, regenerates it (AUSPOL_XGB_SKIP_TRAIN=1 -- a few seconds,
# not a retrain). If the requested pair has no cached model
# (output/xgb-primary-v6-models/<pair>.ubj), refuses rather than silently
# falling back to a different pair's model or the leaked full-data one --
# same discipline as every other "degraded path must say so" guard in this
# repo.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
MDIR <- file.path(OUT, "xgb-primary-v6-models")
FCACHE <- file.path(OUT, "xgb-primary-v6-featurecache.rds")

PAIR <- Sys.getenv("AUSPOL_SHAP_PAIR", "")
SEAT <- Sys.getenv("AUSPOL_SHAP_SEAT", "")
PARTY <- Sys.getenv("AUSPOL_SHAP_PARTY", "")
if (!nzchar(PAIR) || !nzchar(SEAT)) {
  stop("Set AUSPOL_SHAP_PAIR and AUSPOL_SHAP_SEAT (AUSPOL_SHAP_PARTY optional).", call. = FALSE)
}

model_file <- file.path(MDIR, paste0(PAIR, ".ubj"))
if (!file.exists(model_file)) {
  stop("No cached model for pair '", PAIR, "' at ", model_file,
       ". Run AUSPOL_XGB_SAVE_OOF_MODELS=1 scripts/fit_xgb_primary_v6.R first ",
       "(caches all pairs in one run) -- refusing to fall back to a different ",
       "pair's model or the full-data one, which would leak the answer.", call. = FALSE)
}

stale <- !file.exists(FCACHE) ||
  file.info(FCACHE)$mtime < file.info(file.path(OUT, "candidacies.csv"))$mtime
if (stale) {
  cat("SF1  feature cache missing or stale -- rebuilding (fast, not a retrain)...\n")
  system2("powershell.exe", c("-Command", shQuote(
    sprintf('$env:AUSPOL_XGB_SKIP_TRAIN=1; Rscript "%s"', "scripts/fit_xgb_primary_v6.R"))))
  if (!file.exists(FCACHE)) stop("Feature cache rebuild failed -- ", FCACHE, " still missing.", call. = FALSE)
}

fc <- readRDS(FCACHE)
ALL <- fc$ALL; feat_cols <- fc$feat_cols

rows <- ALL[pair == PAIR & seat == SEAT]
if (nzchar(PARTY)) rows <- rows[party == PARTY]
if (!nrow(rows)) stop("No rows for pair='", PAIR, "' seat='", SEAT, "' party='", PARTY, "'.", call. = FALSE)

m <- xgb.load(model_file)
Xrows <- as.matrix(rows[, ..feat_cols])
pred <- predict(m, Xrows)
shap <- predict(m, Xrows, predcontrib = TRUE)
colnames(shap) <- c(feat_cols, "BIAS")

for (i in seq_len(nrow(rows))) {
  cat(sprintf("\n=== %s / %s / %s -- predicted %.2f, actual %.2f ===\n",
              rows$pair[i], rows$seat[i], rows$party[i], pred[i], rows$actual_share[i]))
  v <- shap[i, ]
  v <- v[order(-abs(v))]
  print(round(head(v, 15), 3))
  cat(sprintf("sum of contributions: %.3f (should equal predicted)\n", sum(v)))
}
