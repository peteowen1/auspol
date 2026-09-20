# Move stale backtest files out of output/ so the pooling stages stop
# reading thousands of dead arms. 2026-09-20: 7,279 backtest-*.csv (2.1 GB)
# in output/, every one opened by pool_backtests.R and build_forecasts_table.R
# on every rebuild (stage 7: 122 s), and by smoke_diff.R.
#
# NOTHING IS DELETED. Files are moved to output/archive/<today>/ (gitignored
# with the rest of output/), from where a plain `mv` restores them.
#
# KEPT: any file the current scoreboard references (output/pooled-backtest.csv
# `file` column, plus its sibling sharedetail/allprobs/ourtcp/totals), any
# file newer than AUSPOL_TIDY_KEEP_DAYS (default 2), and anything under
# output/shipped/. Everything else matching ^backtest- is archived.
#
#   Rscript scripts/tidy_output.R            # dry run: prints what would move
#   Rscript scripts/tidy_output.R --apply    # moves
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
OUT <- "output"; apply <- "--apply" %in% commandArgs(TRUE)
keep_days <- as.numeric(Sys.getenv("AUSPOL_TIDY_KEEP_DAYS", "2"))
f <- list.files(OUT, pattern = "^backtest-.*[.]csv$", full.names = TRUE)
pb <- file.path(OUT, "pooled-backtest.csv")
ref <- if (file.exists(pb)) fread(pb, showProgress = FALSE)$file else character(0)
# a referenced win file's siblings share its arm/git suffix; keep the whole family
suffix_of <- function(p) sub("^.*-(a[0-9a-f]+-g[0-9a-f]+x?)[.]csv$", "\\1", basename(p))
keep_suf <- unique(suffix_of(ref[nzchar(ref)]))
age_ok <- file.mtime(f) > Sys.time() - keep_days * 86400
suf_ok <- suffix_of(f) %in% keep_suf
keep <- age_ok | suf_ok
cat(sprintf("TD1  %d backtest files: keep %d (%d referenced by the scoreboard's runs, %d newer than %g days), archive %d (%.2f GB)\n",
            length(f), sum(keep), sum(suf_ok), sum(age_ok), keep_days, sum(!keep), sum(file.size(f[!keep])) / 1e9))
if (!apply) { cat("TD2  dry run; pass --apply to move them to output/archive/\n"); quit(status = 0) }
dest <- file.path(OUT, "archive", format(Sys.Date()))
dir.create(dest, showWarnings = FALSE, recursive = TRUE)
ok <- file.rename(f[!keep], file.path(dest, basename(f[!keep])))
cat(sprintf("TD3  moved %d of %d to %s\n", sum(ok), sum(!keep), dest))
