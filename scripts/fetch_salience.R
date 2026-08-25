# Fetch the salience signal for every candidacy in output/salience-corpus.csv.
#
# WHY A FIXED ANCHOR RATHER THAN THE SITTING MEMBER. The original gate divided
# the challenger's search interest by the INCUMBENT's. That breaks whenever the
# incumbent is a national figure: Zali Steggall against Tony Abbott scores 0.60,
# reading as a quiet challenger in the single most famous breakout in the
# corpus, because Abbott's volume is national news with nothing to do with
# Warringah. Against a fixed anchor the same candidacy scores **12.21** -- the
# loudest in the whole cached set. Measured, not assumed: AUC on the cached
# federal responses is 0.816 over 34 breakouts and 48 non-breakouts, which is
# already four times the positives the original 0.823/0.854/0.964 rested on.
#
# THE ANCHOR MUST BE SEARCHABLE IN ITS OWN ERA. Google Trends normalises 0-100
# WITHIN a query, so the anchor's job is to be a stable, non-trivial reference.
# Anthony Albanese in 2013 is not that. The anchor is therefore the prime
# minister of the day, who is always the most-searched politician in the country
# during a campaign. An anchor with near-zero volume would make every ratio
# explode, and nothing in the output would say so.
#
# TRENDS DATA STARTS IN 2004 and is thin before roughly 2008, so WA 1996 and
# 2001 are excluded by MIN_YEAR rather than fetched and quietly trusted.
#
# Resumable: every response is cached by trends_batch(), so an interrupted run
# loses nothing and a rerun costs only the queries it has not made.
#
# Emits FS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(gtrendsR))
source("scripts/trends_fetch.R")

MIN_YEAR <- as.integer(Sys.getenv("AUSPOL_SALIENCE_MIN_YEAR", "2010"))
N_CTRL   <- as.integer(Sys.getenv("AUSPOL_SALIENCE_CONTROLS", "2"))
SLEEP    <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "6"))
WINDOW   <- 70L

# Polling day per election. Hand-entered and asserted against their own keys,
# the same treatment FED_DATE and WA_DATE get in the harnesses.
POLL <- c(
  fed2010 = "2010-08-21", fed2013 = "2013-09-07", fed2016 = "2016-07-02",
  fed2019 = "2019-05-18", fed2022 = "2022-05-21", fed2025 = "2025-05-03",
  vic2014 = "2014-11-29", vic2018 = "2018-11-24", vic2022 = "2022-11-26",
  nsw2019 = "2019-03-23", nsw2023 = "2023-03-25",
  sa2022  = "2022-03-19", sa2026  = "2026-03-21",
  qld2020 = "2020-10-31", qld2024 = "2024-10-26",
  wa2013  = "2013-03-09", wa2017  = "2017-03-11", wa2021 = "2021-03-13",
  wa2025  = "2025-03-08")
stopifnot(!anyNA(as.Date(POLL)))

# Prime minister on polling day, used as the anchor.
PM <- function(d) {
  d <- as.Date(d)
  if (d < as.Date("2010-06-24")) "Kevin Rudd"
  else if (d < as.Date("2013-06-27")) "Julia Gillard"
  else if (d < as.Date("2013-09-18")) "Kevin Rudd"
  else if (d < as.Date("2015-09-15")) "Tony Abbott"
  else if (d < as.Date("2018-08-24")) "Malcolm Turnbull"
  else if (d < as.Date("2022-05-23")) "Scott Morrison"
  else "Anthony Albanese"
}

GEO <- c(fed = "AU", vic = "AU-VIC", nsw = "AU-NSW", sa = "AU-SA",
         qld = "AU-QLD", wa = "AU-WA")

C <- fread("output/salience-corpus.csv", showProgress = FALSE)
C <- C[election %in% names(POLL) & year >= MIN_YEAR]
cat(sprintf("FS1  %d candidacies in %d elections at or after %d\n",
            nrow(C), uniqueN(C$election), MIN_YEAR))

# Every breakout, plus N_CTRL non-breakouts per breakout drawn from the SAME
# election, so the control set cannot be a different era with different search
# behaviour. Seeded, because an unseeded sample makes the run unreproducible.
set.seed(20260826L)
pick <- rbindlist(lapply(split(C, C$election), function(d) {
  b <- d[breakout == TRUE]
  n <- d[breakout == FALSE]
  k <- min(nrow(n), N_CTRL * max(1L, nrow(b)))
  rbind(b, if (k > 0) n[sample(.N, k)] else n[0])
}))
cat(sprintf("FS2  selected %d candidacies (%d breakouts, %d controls)\n",
            nrow(pick), sum(pick$breakout), sum(!pick$breakout)))
print(pick[, .(n = .N, breakouts = sum(breakout)), by = election][order(election)],
      row.names = FALSE)

rows <- list(); nq <- 0L
for (el in unique(pick$election)) {
  d <- pick[election == el]
  to <- as.Date(POLL[[el]]) - 1
  from <- to - WINDOW
  anchor <- PM(POLL[[el]]); geo <- GEO[[sub("[0-9]+$", "", el)]]
  cat(sprintf("FS3  %s: %d candidacies | geo %s | anchor %s | %s..%s\n",
              el, nrow(d), geo, anchor, from, to))
  # Four keywords per query is gtrends' limit alongside the anchor.
  idx <- split(seq_len(nrow(d)), ceiling(seq_len(nrow(d)) / 4L))
  for (g in idx) {
    kw <- d$name[g]
    r <- trends_batch(kw, geo = geo, from = from, to = to, anchor = anchor)
    nq <- nq + 1L
    if (is.null(r)) { Sys.sleep(SLEEP); next }
    a <- if (anchor %in% names(r)) as.numeric(r[[anchor]]) else NA_real_
    for (i in seq_along(kw)) {
      v <- if (kw[i] %in% names(r)) as.numeric(r[[kw[i]]]) else NA_real_
      rows[[length(rows) + 1L]] <- data.table(
        election = el, seat = d$seat[g][i], name = kw[i],
        party = d$party[g][i], pcv = d$pcv[g][i], breakout = d$breakout[g][i],
        hits = v, anchor_hits = a,
        ratio = if (is.finite(a) && a > 0) v / a else NA_real_)
    }
    Sys.sleep(SLEEP)
  }
}

R <- rbindlist(rows)
fwrite(R, "output/salience-ratios.csv")
cat(sprintf("\nFS8  %d queries issued | %d candidacy rows | %d with a usable ratio\n",
            nq, nrow(R), sum(is.finite(R$ratio))))
ok <- R[is.finite(ratio)]
if (nrow(ok) && uniqueN(ok$breakout) > 1) {
  n1 <- sum(ok$breakout); n0 <- nrow(ok) - n1
  rk <- rank(ok$ratio)
  cat(sprintf("FS9  AUC %.3f over %d breakouts and %d non-breakouts\n",
              (sum(rk[ok$breakout]) - n1 * (n1 + 1) / 2) / (n1 * n0), n1, n0))
  print(ok[, .(n = .N, median = round(median(ratio), 4),
               mean = round(mean(ratio), 4)), by = breakout], row.names = FALSE)
  cat("\nFS9  by region:\n")
  print(ok[, .(n = .N, breakouts = sum(breakout)), by = .(region = sub("[0-9]+$", "", election))],
        row.names = FALSE)
}
cat("FS9  wrote output/salience-ratios.csv\n")
