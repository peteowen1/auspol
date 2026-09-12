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
# EXCLUDE THIS SCRIPT'S OWN OUTPUT. "pooled-sharedetail.csv" matches the pattern
# above, carries EVERY pair, and is by construction the newest file the moment
# this has been run once -- so the "newest file per pair" rule below selected it
# for all 23 pairs and the script silently re-copied its own previous output
# instead of re-deriving from the harness runs. Whether it re-derived or
# self-copied depended purely on mtime order, which is not a property anything
# downstream could see. Found 2026-09-12.
files <- files[basename(files) != "pooled-sharedetail.csv"]
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

# N_SIMS GUARD. `pred_share` here is a SIMULATION MEAN, and this file is not
# only a scoreboard -- fit_xgb_primary_v6.R reads it and trains the shipped
# primary model on that column. So it has two consumers with different precision
# needs, and only one of them tolerates an exploratory run.
#
# CLAUDE.md endorses AUSPOL_N_SIMS=5000 for exploratory arms and 20,000 only for
# a deciding run, which is correct for SCORING. On 2026-09-12 I regenerated all
# 22 pairs at 5,000 to measure the salience percentile fix -- a valid,
# correctly-matched measurement -- and then fed the by-product here. The extra
# sampling noise alone moved v6's pooled primary RMSE from 3.9201 to 4.0729 and
# flipped it from beating its baseline to losing to it by 3.65%. The tell was
# that WA pairs moved (wa2021 +0.672) when the change under test provably does
# nothing in WA, and that old and new correlated at r = 0.9991 -- noise, not a
# systematic shift.
#
# Nothing flagged it: the staleness check passed (all files minutes old), the
# code tag matched, and the column was fully populated. n_sims lives only in the
# filename, so read it and refuse.
# COMPUTED OUTSIDE THE BRACKETS, on a plain named vector. `file` is both a
# column here AND a base R function, so a bare `file` inside j does not resolve
# to the column -- the first version of this check silently found no n_sims on
# any of the 23 pairs and refused for the wrong reason. Tenth instance of the
# data.table NSE trap in this repo; CLAUDE.md says never use a bare column-name
# symbol inside `[`, and that is why.
.sims_for <- function(paths) {
  bn <- basename(paths)
  m <- regmatches(bn, regexpr("-n[0-9]+-", bn))
  out <- rep(NA_integer_, length(bn))
  hit <- regexpr("-n[0-9]+-", bn) > 0
  out[hit] <- as.integer(gsub("[^0-9]", "", m))
  stats::setNames(out, paths)
}
.ufiles <- unique(rows$file)
rows[, n_sims := .sims_for(.ufiles)[file]]
MIN_SIMS <- as.integer(Sys.getenv("AUSPOL_POOL_MIN_SIMS", "20000"))
.low <- unique(rows[is.finite(n_sims) & n_sims < MIN_SIMS, .(pair, n_sims)])
.unk <- unique(rows[!is.finite(n_sims), .(pair)])
if (nrow(.unk))
  cat(sprintf("PS1! %d pair(s) have no n_sims in the filename, so it cannot be checked: %s\n",
              nrow(.unk), paste(.unk$pair, collapse = ", ")))
if (nrow(.low)) {
  print(.low[order(n_sims)])
  stop(sprintf(paste0("refusing to pool: %d pair(s) come from runs below %d sims. ",
                      "pred_share is a simulation mean and fit_xgb_primary_v6.R trains on it. ",
                      "Re-run those pairs at AUSPOL_N_SIMS=%d, or set AUSPOL_POOL_MIN_SIMS ",
                      "lower if this file is only being used as a scoreboard."),
               nrow(.low), MIN_SIMS, MIN_SIMS))
}
cat(sprintf("PS1  n_sims per pair: min %d, max %d (floor %d)\n",
            min(rows$n_sims, na.rm = TRUE), max(rows$n_sims, na.rm = TRUE), MIN_SIMS))

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
