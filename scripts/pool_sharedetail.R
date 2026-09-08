# Pool every backtest's per-seat, per-party PRIMARY VOTE point estimate into
# ONE table: our predicted primary, the actual primary, for every seat in
# every election we forecast.
#
# WHY THIS EXISTS. Until 2026-09-09 "what did we predict for seat X's primary
# vote" meant re-running that pair's harness from scratch -- seat_share_rmse()
# always computed this internally (for the RMSE line every harness already
# prints) and threw it away. Now every harness persists it
# (backtest-*-sharedetail*.csv); this script is the pool_backtests.R-style
# reader that turns those files into one answerable table instead of Pete
# having to ask for a fresh sim every time he wants a seat's numbers.
#
# Same discipline as pool_backtests.R: newest file per pair, staleness
# printed rather than assumed, a pair missing entirely is a visible warning
# not a silently short table. Re-run this after any backtest run that should
# be reflected here -- it does not run anything itself.
#
# Emits PS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))  # for all_election_pairs()

OUT <- "output"
files <- list.files(OUT, pattern = "-sharedetail.*[.]csv$", full.names = TRUE)
if (!length(files)) stop("No sharedetail files in ", OUT, " -- run a harness first")

rows <- rbindlist(lapply(files, function(f) {
  d <- tryCatch(fread(f, showProgress = FALSE), error = function(e) {
    cat(sprintf("PS0! %s: unreadable (%s) -- dropped\n", basename(f), conditionMessage(e)))
    NULL
  })
  if (is.null(d)) return(NULL)
  if (!nrow(d)) { cat(sprintf("PS0! %s: 0 rows -- dropped\n", basename(f))); return(NULL) }
  need <- c("seat", "party", "pred_share", "actual_share", "pair")
  miss <- setdiff(need, names(d))
  if (length(miss)) {
    cat(sprintf("PS0! %s: missing column(s) %s -- dropped\n", basename(f), paste(miss, collapse = ", ")))
    return(NULL)
  }
  d[, .(file = f, mtime = file.mtime(f), pair = as.character(pair), seat, party,
        pred_share, actual_share)]
}))
if (!nrow(rows)) stop("No readable sharedetail files")

# NEWEST FILE PER PAIR -- two arms of the same pair must never blend, exactly
# the reason pool_backtests.R does this.
pick <- rows[, .(mtime = max(mtime)), by = pair]
rows <- merge(rows, pick, by = c("pair", "mtime"))
keep <- rows[, .(file = file[1]), by = pair]
rows <- merge(rows, keep, by = c("pair", "file"))

tagof <- function(f) {
  m <- regmatches(basename(f), regexpr("-g[0-9a-f]+x?", basename(f)))
  if (length(m)) sub("^-g", "", m) else "(untagged)"
}
per <- rows[, .(n = .N, mtime = max(mtime), file = file[1]), by = pair]
per[, code := vapply(file, tagof, character(1))]
setorder(per, pair)
newest <- max(per$mtime)
per[, stale_h := round(as.numeric(difftime(newest, mtime, units = "hours")), 1)]

cat(sprintf("PS1  %d pairs, %d seat-class rows, newest file %s\n",
            nrow(per), nrow(rows), format(newest, "%Y-%m-%d %H:%M")))
print(per[, .(pair, n, code, stale_h)])

old <- per[stale_h > 24]
if (nrow(old)) {
  cat(sprintf("\nPS2! %d pair(s) come from a file more than a day older than the newest: %s\n",
              nrow(old), paste(sprintf("%s (%.0fh)", old$pair, old$stale_h), collapse = ", ")))
} else {
  cat("\nPS2  every pair comes from a file within a day of the newest.\n")
}

.known <- vapply(all_election_pairs(), `[[`, character(1), "election")
.missing <- setdiff(.known, unique(rows$pair))
if (length(.missing)) {
  cat(sprintf("PS2c! %d of %d known pair(s) have NO sharedetail at all yet -- run their harness once: %s\n",
              length(.missing), length(.known), paste(.missing, collapse = ", ")))
} else {
  cat(sprintf("PS2c  all %d known pairs have sharedetail on hand.\n", length(.known)))
}

fwrite(rows[, .(pair, seat, party, pred_share, actual_share)], file.path(OUT, "pooled-sharedetail.csv"))
cat(sprintf("\nPS5  wrote %s -- %d rows, %d pairs, %d unique seats\n",
            file.path(OUT, "pooled-sharedetail.csv"), nrow(rows), uniqueN(rows$pair), uniqueN(rows$seat)))
