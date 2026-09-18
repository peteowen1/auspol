# Every input to the AEF-7 ledger comes from the SAME harness run, per pair.
#
# Sourced by build_aef7_tcp_actual.R and build_aef7_ledger_data.R. The run is
# the one pool_backtests.R chose for that pair's win file (newest file per
# pair, by the file's own `pair` column), and its sibling files -- the
# sharedetail, allprobs and ourtcp tables -- are found by the arm+git hash
# suffix every file of one harness run shares (`-a<arm>-g<git>[x].csv`).
#
# Why (2026-09-18): the first as-at ledger build mixed three vintages on one
# page without anything failing. The seat log loss came from the new run, the
# TCP scenario columns from the previous 20,000-sim run (build_aef7_tcp_actual.R
# skipped anything named n5000), and the headline weighted primary RMSE from
# pooled-sharedetail.csv, which is the xgb-OFF pool by construction -- so
# "ours 5.28 vs AEF 5.42" was base_pred against AEF, not the shipped model
# (4.80). And during any rebuild, stage 1's xgb-off files are the newest on
# disk until stage 6 finishes, so "newest by name" is wrong for an hour.
#
# One rule, one place: ask pooled-backtest.csv which file scored the pair,
# then take only siblings of that file. Loud when a sibling is missing.

.PB <- fread(file.path(OUT, "pooled-backtest.csv"), showProgress = FALSE)
if (!"file" %in% names(.PB))
  stop("output/pooled-backtest.csv has no `file` column -- rerun scripts/pool_backtests.R (2026-09-18+) first")

run_suffix <- function(pr) {
  f <- .PB[pair == pr]$file
  if (!length(f)) stop("pooled-backtest.csv has no row for ", pr, " -- rerun that harness and pool_backtests.R")
  m <- regmatches(f, regexpr("-a[0-9a-f]+-g[0-9a-f]+x?[.]csv$", f))
  if (!length(m)) stop("cannot read an arm+git suffix from ", f)
  sub("[.]csv$", "", m)
}

# kind: "sharedetail", "allprobs", "ourtcp" (or "" for the win file itself).
# Returns ONE path. The sharedetail/allprobs files of a multi-pair harness
# carry a `pair` column and are named by region (backtest-fed-...); ourtcp
# files are always named by pair (backtest-fed2022-ourtcp-...). Both share
# the suffix, so the suffix is the key and the prefix is only a sanity check.
run_file <- function(pr, kind) {
  suf <- run_suffix(pr)
  # Two harnesses run with identical settings get the SAME arm hash (vic and
  # wa did on 2026-09-18: both a7439ff), so the suffix alone is ambiguous
  # across regions. The win file's own prefix ("backtest-vic-", "backtest-
  # nsw2023-") is the harness; siblings carry the same one, except ourtcp
  # which is always named by pair.
  prefix <- if (kind == "ourtcp") pr else sub("^backtest-([a-z0-9]+)-.*$", "\\1", .PB[pair == pr]$file)
  pat <- if (nzchar(kind)) sprintf("^backtest-%s-%s-.*%s[.]csv$", prefix, kind, suf)
         else sprintf("^backtest-%s-(?!sharedetail|allprobs|ourtcp|totals).*%s[.]csv$", prefix, suf)
  g <- list.files(OUT, pattern = "^backtest-.*[.]csv$", full.names = TRUE)
  g <- g[grepl(pat, basename(g), perl = TRUE)]
  if (!length(g)) {
    cat(sprintf("LI1! %s: no %s file from run %s -- that column will be NA for this pair\n", pr, kind, suf))
    return(NULL)
  }
  if (length(g) > 1) stop(sprintf("%s: %d %s files share run suffix %s: %s", pr, length(g), kind, suf,
                                  paste(basename(g), collapse = ", ")))
  g
}

# Read a run file and, if it has a pair column, keep this pair's rows.
run_table <- function(pr, kind) {
  f <- run_file(pr, kind)
  if (is.null(f)) return(NULL)
  x <- fread(f, showProgress = FALSE)
  if ("pair" %in% names(x)) x <- x[x$pair == pr]
  if (!nrow(x)) stop(sprintf("%s: %s has no rows for this pair", pr, basename(f)))
  x
}

cat(sprintf("LI0  ledger inputs keyed to one harness run per pair: %s\n",
            paste(sprintf("%s=%s", .PB$pair, sub("^.*-a([0-9a-f]+)-g.*$", "a\\1", .PB$file)), collapse = " ")))
