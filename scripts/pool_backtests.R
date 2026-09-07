# Pool every candidate-seat backtest into ONE table: seat log loss, Brier and
# accuracy per election and across all of them.
#
# WHY THIS EXISTS. The standing objective is pooled seat log loss and seat-share
# RMSE across every election we forecast, and until now answering that meant
# reading six harness logs and adding up by hand. Twice that produced a table
# built from files that were days old while the model had moved underneath.
#
# So this script does two things a hand-assembled table cannot:
#   1. It takes the NEWEST file for each pair, and
#   2. it PRINTS that file's modification time and code tag next to the numbers,
#      so a stale row is visible in the output instead of having to be
#      remembered. A row older than the newest row is flagged.
#
# It reads only what the harnesses already write. `prob` (fed/vic/wa) and `p`
# (nsw/sa/qld) are both the probability assigned to the party that ACTUALLY won,
# which is what log loss needs; `pred`/`pred_p` are the argmax call and its
# probability, which is what accuracy needs.
#
# Emits PB* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

# THE SAME FLOOR THE HARNESSES USE. Every harness clamps at 1e-6 before taking
# a log, and this script originally used 1e-9 -- which is not a rounding
# difference. A seat the model gives probability EXACTLY zero contributes
# -log(eps) on its own, so at 1e-9 it costs 20.7 and at 1e-6 it costs 13.8, and
# over 73 seats that single choice moved vic2014 from 0.4662 to 0.5608. The
# pooled table has to agree with the harness logs or the same model reports two
# different numbers depending on who asked.
EPS <- 1e-6

OUT <- "output"
files <- list.files(OUT, pattern = "^backtest-.*[.]csv$", full.names = TRUE)
files <- grep("-totals|allprobs|-seatsd|-diag", files, value = TRUE, invert = TRUE)
if (!length(files)) stop("No backtest files in ", OUT)

# One row per (file, pair). A harness that scores several pairs writes them into
# one file with a `pair` column; the single-pair harnesses put the election in
# the filename instead.
rows <- rbindlist(lapply(files, function(f) {
  d <- tryCatch(fread(f, showProgress = FALSE), error = function(e) NULL)
  if (is.null(d) || !nrow(d)) return(NULL)
  pcol <- if ("prob" %in% names(d)) "prob" else if ("p" %in% names(d)) "p" else NA_character_
  if (is.na(pcol) || !all(c("pred", "actual") %in% names(d))) return(NULL)
  if (!"pair" %in% names(d)) {
    m <- regmatches(basename(f), regexpr("(fed|vic|nsw|sa|qld|wa)[0-9]{4}", basename(f)))
    if (!length(m)) return(NULL)
    d[, pair := m]
  }
  d[, .(file = f, mtime = file.mtime(f), pair = as.character(pair),
        p = pmin(pmax(get(pcol), EPS), 1), hit = as.integer(pred == actual))]
}))
if (!nrow(rows)) stop("No readable backtest files")

# NEWEST FILE PER PAIR. Not the newest file overall and not all of them: two
# arms of the same pair must never be averaged together, which is what globbing
# everything would silently do.
pick <- rows[, .(mtime = max(mtime)), by = pair]
rows <- merge(rows, pick, by = c("pair", "mtime"))
# A pair can still tie on mtime across two arms; keep one file per pair.
keep <- rows[, .(file = file[1]), by = pair]
rows <- merge(rows, keep, by = c("pair", "file"))

tagof <- function(f) {
  m <- regmatches(basename(f), regexpr("-g[0-9a-f]+x?", basename(f)))
  if (length(m)) sub("^-g", "", m) else "(untagged)"
}
per <- rows[, .(n = .N,
                accuracy = mean(hit),
                brier = mean((1 - p)^2),
                logloss = -mean(log(p)),
                mtime = max(mtime),
                file = file[1]), by = pair]
per[, `:=`(code = vapply(file, tagof, character(1)),
           region = sub("[0-9]{4}$", "", pair))]
setorder(per, region, pair)

newest <- max(per$mtime)
per[, stale_hours := as.numeric(difftime(newest, mtime, units = "hours"))]

cat(sprintf("\nPB1  %d pairs, %d seat-elections, newest file %s\n",
            nrow(per), sum(per$n), format(newest, "%Y-%m-%d %H:%M")))
print(per[, .(pair, n, accuracy = round(accuracy, 4), brier = round(brier, 4),
              logloss = round(logloss, 4), code,
              stale_h = round(stale_hours, 1))])

old <- per[stale_hours > 24]
if (nrow(old)) {
  cat(sprintf("\nPB2! %d pair(s) come from a file more than a day older than the newest: %s\n",
              nrow(old), paste(sprintf("%s (%.0fh)", old$pair, old$stale_hours), collapse = ", ")))
  cat("PB2! Those rows describe an older model. Re-run those harnesses before quoting this table.\n")
} else {
  cat("\nPB2  every pair comes from a file within a day of the newest.\n")
}

cat(sprintf("\nPB3  POOLED over %d seat-elections: accuracy %.4f | Brier %.4f | log loss %.4f\n",
            nrow(rows), mean(rows$hit), mean((1 - rows$p)^2), -mean(log(rows$p))))
cat(sprintf("PB3  unweighted mean over the %d pairs:      accuracy %.4f | Brier %.4f | log loss %.4f\n",
            nrow(per), mean(per$accuracy), mean(per$brier), mean(per$logloss)))

by_region <- rows[, .(pairs = uniqueN(pair), n = .N, accuracy = round(mean(hit), 4),
                      brier = round(mean((1 - p)^2), 4),
                      logloss = round(-mean(log(p)), 4)),
                  by = .(region = sub("[0-9]{4}$", "", pair))][order(region)]
cat("\nPB4  by jurisdiction\n"); print(by_region)

fwrite(per[, .(pair, n, accuracy, brier, logloss, code, mtime)],
       file.path(OUT, "pooled-backtest.csv"))
cat(sprintf("\nPB5  wrote %s\n", file.path(OUT, "pooled-backtest.csv")))
