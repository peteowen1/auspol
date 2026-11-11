# Largest win-probability change pair_cal makes where the base model's leader was above 0.9, per night (the figure
# quoted in the RESULT of docs/plans/prereg-night-pair-cal-2026-11-11.md; reported, not decisive).
#   Rscript scripts/night_pair_cal_bigmoves.R [deciding-runs/20261111-1130-night-pair-cal-r2/replay]
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
d <- if (length(a)) a[1] else "deciding-runs/20261111-1130-night-pair-cal-r2/replay"
for (nt in c("fed2022", "fed2025", "vic2022")) {
  b <- fread(file.path(d, sprintf("%s-base-seats.csv", nt))); c <- fread(file.path(d, sprintf("%s-cal-seats.csv", nt)))
  b[, time := as.character(time)]; c[, time := as.character(time)]
  m <- merge(b[, .(seat, party, time, pb = prob)], c[, .(seat, party, time, pc = prob)], by = c("seat", "party", "time"), all = TRUE)
  m[is.na(pb), pb := 0]; m[is.na(pc), pc := 0]
  lead <- m[, .(top = max(pb)), by = .(seat, time)]
  m <- merge(m, lead, by = c("seat", "time"))
  x <- m[top > 0.9]
  if (!nrow(x)) stop("NPB1! ", nt, ": no seat-time with the base leader above 0.9 in ", d)
  i <- which.max(abs(x$pc - x$pb))
  cat(sprintf("NPB1 %s: seats-times with base leader > 0.9: %d; max |win prob change| %.4f (%s %s at %s)\n", nt, uniqueN(x[, .(seat, time)]),
              max(abs(x$pc - x$pb)), x$seat[i], x$party[i], x$time[i]))
}
