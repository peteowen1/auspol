# The arm fingerprint a backtest harness WOULD write under the current
# configuration, for rebuild_forecasts.sh's reuse_check().
#
#   Rscript scripts/expected_arm_tag.R <harness> [ENV=value]
#
# Prints e.g. "-a8c1d66" (or "" when no AUSPOL_* variable is set). Harness is
# one of fed, wa, vic, nsw, qld, sa, nt; the optional ENV=value is the pair
# selector the rebuild sets (AUSPOL_NSW_PAIR=2023). AUSPOL_XGB_PRIMARY and
# everything else come from the caller's environment, as they would for the
# harness itself.
#
# Why: AUSPOL_REBUILD_ONLY reuses the newest result of each skipped harness,
# and reuse_check() used to test only that the file was newer than the as-at
# predictions. After a switch flip in published_flags.R the newest file was
# still the old configuration's, and stage 7 pooled it with nothing to say so
# (review, 8 Nov 2026). The fingerprint already hashes every AUSPOL_* variable
# set once published defaults are applied, so a flip changes it.
#
# The fingerprint block is not copied here: it is parsed out of the harness
# script itself and evaluated, so this cannot drift from what the harness
# writes. Fails loudly if the block is not found.
args <- commandArgs(TRUE)
if (!length(args) || !args[1] %in% c("fed", "wa", "vic", "nsw", "qld", "sa", "nt"))
  stop("EAT! usage: Rscript scripts/expected_arm_tag.R <fed|wa|vic|nsw|qld|sa|nt> [ENV=value]")
h <- args[1]
if (length(args) > 1) {
  kv <- strsplit(args[2], "=", fixed = TRUE)[[1]]
  if (length(kv) != 2 || !grepl("^AUSPOL_", kv[1])) stop("EAT! second argument must be AUSPOL_X=value, got: ", args[2])
  do.call(Sys.setenv, setNames(list(kv[2]), kv[1]))
}
# The harness is read from THIS script's folder (so a worktree copy can be tested against the main checkout's
# output/); harness_defaults.R and its input checks run from the working directory, as the harness's do.
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
sdir <- if (length(self)) dirname(normalizePath(self[1])) else "scripts"
src <- readLines(file.path(sdir, sprintf("backtest_candidate_%s.R", h)), warn = FALSE)
# Same forecast-mode default the harness sets before sourcing harness_defaults.R.
if (any(grepl("^\\.harness_forecast_mode <- TRUE", src))) .harness_forecast_mode <- TRUE
invisible(capture.output(source("scripts/harness_defaults.R")))
a <- grep("^\\.arm_fingerprint <- local\\(\\{", src)
b <- grep("^\\}\\)", src); b <- b[b > a[1]][1]
if (length(a) != 1 || is.na(b)) stop("EAT! fingerprint block not found once in backtest_candidate_", h, ".R")
eval(parse(text = src[a:b]))
cat(.arm_fingerprint, "\n", sep = "")
