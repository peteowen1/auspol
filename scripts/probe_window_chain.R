# PROBE: can two overlapping Trends windows be chained onto one scale?
#
# WHY THIS IS NEEDED. C3 needs fed2010/2013/2016/2019, and they cannot share the
# 2021-2025 window: Google drops to monthly buckets above roughly five years, and
# a monthly series cannot measure an 8-week campaign. So the earlier elections
# need their own windows, and separate windows are separately normalised -- the
# exact fault that killed the pre-gate design.
#
# THE TEST. Two windows that OVERLAP IN TIME share a period of real search
# volume. If window A and window B are each internally consistent, then for any
# keyword the ratio (A's mean over the overlap) / (B's mean over the overlap)
# estimates the scale factor between them -- and that factor must be THE SAME
# for every keyword. If it is not, the windows cannot be chained and C3 is
# abandoned rather than run on incomparable scales.
#
# Emits WC* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(gtrendsR))

CACHE <- file.path("external", "reference", "trends")
GEO <- "AU"
OLD <- c("2017-01-01", "2021-12-31")   # covers fed2019; ~5.0y
NEW <- c("2021-06-01", "2025-06-01")   # the existing window
OVL <- as.Date(c("2021-06-01", "2021-12-31"))   # 7 months in common

# Five names that were searched across BOTH windows. Deliberately spans loud and
# quiet: Bandt and Katter are constants, Steggall and Haines are the fed2019
# emergences C3 exists to score, Wilkie is a steady long-term independent.
KW <- c("Adam Bandt", "Bob Katter", "Zali Steggall", "Helen Haines", "Andrew Wilkie")

qry <- function(kw, from, to) {
  key <- gsub("[^A-Za-z0-9]", "_", sprintf("wc-%s-%s-%s-%s", GEO, from, to, paste(kw, collapse="-")))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else z$series) }
  r <- NULL
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = kw, geo = GEO, time = paste(from, to), onlyInterest = TRUE),
                  error = function(e) NULL)
    if (!is.null(r) && !is.null(r$interest_over_time)) break
    Sys.sleep(12 * att)
  }
  # A FAILED REQUEST IS NOT "NO DATA". `r` is NULL when every attempt errored,
  # and caching that as empty makes a transient throttle permanent and
  # indistinguishable from a genuine zero. Only a request that SUCCEEDED and
  # returned no series is a real empty.
  if (is.null(r)) { cat("WC!  request failed -- NOT cached, will retry\n"); return(NULL) }
  if (is.null(r$interest_over_time)) { saveRDS(list(empty=TRUE), f); return(NULL) }
  d <- as.data.table(r$interest_over_time)
  d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]
  d[, date := as.Date(date)]
  out <- d[, .(keyword, date, hits)]
  saveRDS(list(series = out, empty = FALSE, fetched = Sys.Date()), f)   # RAW
  out
}

A <- qry(KW, OLD[1], OLD[2]); Sys.sleep(4)
B <- qry(KW, NEW[1], NEW[2])
if (is.null(A) || is.null(B)) stop("WC!  a window returned nothing")
for (nm in c("A","B")) {
  s <- get(nm); g <- as.integer(median(diff(sort(unique(s$date)))))
  cat(sprintf("WC1  window %s: %d buckets, %s\n", nm, uniqueN(s$date),
              if (g >= 26) "MONTHLY -- UNUSABLE" else if (g >= 6) "weekly" else "daily"))
  if (g >= 26) stop("WC!  monthly buckets cannot measure an 8-week campaign")
}

ov <- function(s) s[date >= OVL[1] & date <= OVL[2], .(m = mean(hits)), by = keyword]
M <- merge(ov(A), ov(B), by = "keyword", suffixes = c("_old", "_new"))
M[, factor := m_new / m_old]
cat(sprintf("\nWC2  overlap %s to %s\n", OVL[1], OVL[2]))
print(M[order(-m_new), .(keyword, old_mean = round(m_old,2), new_mean = round(m_new,2),
                         factor = round(factor,3))], row.names = FALSE)

f <- M[is.finite(factor) & m_old > 0, factor]
cv <- stats::sd(f) / mean(f)
cat(sprintf("\nWC3  scale factor across %d keywords: mean %.3f | sd %.3f | CV %.3f | range %.3f-%.3f\n",
            length(f), mean(f), stats::sd(f), cv, min(f), max(f)))
cat("WC3  THE TEST: one shared scale means one factor. A CV above 0.25 means the\n")
cat("     windows disagree about their common period and cannot be chained.\n")
cat(sprintf("WC3  verdict: %s\n",
    if (length(f) < 3) "TOO FEW USABLE KEYWORDS -- inconclusive"
    else if (cv <= 0.25) "CHAINABLE" else "*** NOT CHAINABLE -- abandon C3 ***"))
