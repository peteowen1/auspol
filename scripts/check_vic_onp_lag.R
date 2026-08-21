# Does Victoria have NSW's One Nation lag, and is it the same cause?
#
# docs/reviews/nsw-onp-walk-2026-08-19.md diagnosed NSW: a party needs 15 polls
# in the cycle to be given its own per-cycle volatility, One Nation had 8, so it
# was fitted with the generic default random walk -- one calibrated on parties
# that do not move twenty points in three months. NSW fits it at 19.52 against
# 24.67 in polling.
#
# Victoria's published forecast has One Nation at 20.2% while YouGov has 24 and
# Roy Morgan 23.5, and docs/reviews/comparison-statistics-2026-08-21.md shows
# roughly half the seat disagreement with YouGov traces to that gap through
# threshold amplification. So: same symptom, and the question is whether it is
# the same cause.
#
# MEASUREMENT ONLY. Nothing here changes a model; a fix needs its own
# pre-registration, which is what the NSW review said and why that thread is
# still open.
#
# Emits VL* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

polls <- as.data.table(load_polls("vic"))
cyc <- as.data.table(load_election_cycles())
vic <- cyc[region == "vic" & year == 2026L]
stopifnot(nrow(vic) == 1L)
# `load_polls` returns one COLUMN per party, not a party/value pair, and the
# cycle table carries start/end rather than a polling date. Both were assumed
# the other way round on the first attempt; the script died rather than
# reporting something plausible, which is the preferable failure.
PARTIES <- intersect(c("ALP", "LNP", "GRN", "ONP", "UAP", "DEM", "OTH"),
                     names(polls))
p <- polls[as.Date(date) >= as.Date(vic$start[1])]
cat(sprintf("
VL1  Victorian polls this cycle (since %s): %d
",
            as.character(vic$start[1]), nrow(p)))

cnt <- data.table(party = PARTIES,
                  N = vapply(PARTIES, function(q) sum(!is.na(p[[q]])), integer(1)))
setorder(cnt, -N)
cnt[, own_walk := N >= 15L]
cat("
VL2  polls naming each party this cycle, against the 15 needed for a
")
cat("VL2  per-cycle random walk of its own
")
print(cnt)
denied <- cnt[own_walk == FALSE & N > 0]
if (nrow(denied)) {
  cat(sprintf("VL2  denied their own volatility: %s
",
              paste(sprintf("%s (%d)", denied$party, denied$N), collapse = ", ")))
}

tr <- fread(file.path("output", "trend-vic-2026.csv"), showProgress = FALSE)
last_day <- max(tr$date)
end <- tr[date == last_day, .(party, fitted = mean)]
recent <- rbindlist(lapply(PARTIES, function(q) {
  v <- p[as.Date(date) >= as.Date(last_day) - 90][[q]]
  v <- v[!is.na(v)]
  if (!length(v)) return(NULL)
  data.table(party = q, polls = length(v), poll_mean = mean(v))
}))
m <- merge(end, recent, by = "party")
m[, gap := fitted - poll_mean]
setorder(m, gap)
cat(sprintf("
VL3  fitted endpoint (%s) against the last 90 days of polling
",
            as.character(last_day)))
print(m[, .(party, polls, poll_mean = round(poll_mean, 2),
            fitted = round(fitted, 2), gap = round(gap, 2))])


cat("\nVL4  NSW for comparison, from docs/reviews/nsw-onp-walk-2026-08-19.md:\n")
cat("VL4    One Nation fitted 19.52 against 24.67 polled, gap -5.15, on 8 polls.\n")

onp <- m[party == "ONP"]
if (nrow(onp)) {
  same <- onp$gap < -2 && cnt[party == "ONP", N] < 15L
  cat(sprintf("\nVL5  Victoria One Nation: fitted %.2f, polled %.2f, gap %+.2f, on %d polls\n",
              onp$fitted, onp$poll_mean, onp$gap, cnt[party == "ONP", N]))
  cat(sprintf("VL5  same cause as NSW (denied its own walk AND lagging by >2)? %s\n",
              if (same) "YES" else "NO"))
  if (!same && cnt[party == "ONP", N] >= 15L) {
    cat("VL5  Victoria's One Nation DOES get its own per-cycle walk, so whatever\n")
    cat("VL5  gap remains is not the NSW mechanism and needs its own explanation.\n")
  }
} else {
  cat("\nVL5  One Nation has no fitted trend for Victoria 2026 at all.\n")
}
fwrite(m, file.path("output", "vic-onp-lag.csv"))
