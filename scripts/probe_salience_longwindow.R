# PROBE: can ONE long Trends window put two elections on ONE scale?
#
# THE BLOCKER (docs/reviews/salience-scale-blocker-2026-08-26.md): each election's
# chain is rescaled onto its own first batch, so a `jump` of 10 in fed2022 units
# and 10 in fed2025 units are not the same quantity. fed2025's gate-eligible
# candidates top out at 1.6 against fed2022's 57.6, and we cannot tell whether
# 2025 was quiet or merely compressed. That kills every threshold rule, which is
# what a salience-for-emergents gate needs.
#
# THE IDEA: Google renormalises 0-100 ONCE across whatever range is requested,
# and switches to weekly buckets above ~269 days. So a single 2021-2025 window
# returns both campaigns under one normalisation -- no chaining across elections,
# no anchor keyword, no ratio of ratios.
#
# RAW SERIES IS CACHED, per the keep-all-data rule: a re-fetch is rate-limited,
# a disk write is free, and every other statistic (level, rise, slope, peak) is
# derivable later from what is stored here.
#
# Emits PL* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(gtrendsR))

CACHE <- file.path("external", "reference", "trends")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)
GEO <- "AU"
FROM <- "2021-06-01"; TO <- "2025-06-01"

# Five candidates chosen to span the question, NOT to flatter it:
#   Ryan/Daniel/Chaney -- fed2022 emergences, the loud end of the 2022 scale
#   Boele              -- the ONE genuine fed2025 near-emergence (won Bradfield)
#   Bandt              -- fed2025's chain anchor, a LOUD NON-emergent
# If the long window works, Boele's 2025 campaign should be visible on the same
# scale as Ryan's 2022 campaign rather than 30x smaller.
KW <- c("Monique Ryan", "Nicolette Boele", "Zoe Daniel", "Adam Bandt", "Kate Chaney")

key <- gsub("[^A-Za-z0-9]", "_", sprintf("lw-%s-%s-%s-%s", GEO, FROM, TO, paste(KW, collapse="-")))
f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
if (file.exists(f)) {
  s <- readRDS(f)$series; cat("PL0  cache hit\n")
} else {
  r <- NULL
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = KW, geo = GEO, time = paste(FROM, TO), onlyInterest = TRUE),
                  error = function(e) NULL)
    if (!is.null(r) && !is.null(r$interest_over_time)) break
    Sys.sleep(12 * att)
  }
  if (is.null(r) || is.null(r$interest_over_time)) stop("PL!  Trends returned nothing")
  d <- as.data.table(r$interest_over_time)
  d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]
  d[, date := as.Date(date)]
  s <- d[, .(keyword, date, hits)]
  saveRDS(list(series = s, empty = FALSE, fetched = Sys.Date()), f)
  cat("PL0  fetched and cached RAW series\n")
}

cat(sprintf("PL1  %d rows | %s to %s | %d buckets | granularity %s\n",
            nrow(s), min(s$date), max(s$date), uniqueN(s$date),
            if (as.integer(median(diff(sort(unique(s$date))))) >= 6) "WEEKLY" else "DAILY"))
stopifnot(uniqueN(s$keyword) == length(KW))

jump_at <- function(poll, weeks = 8L) {
  p <- as.Date(poll); camp <- s[date > p - weeks*7L & date <= p]
  base <- s[date > p - 300L & date <= p - weeks*7L]
  merge(camp[, .(camp = mean(hits)), by = keyword],
        base[, .(base = mean(hits)), by = keyword], by = "keyword")[
        , .(keyword, camp = round(camp,2), base = round(base,2), jump = round(camp-base,2))]
}
J22 <- jump_at("2022-05-21"); J25 <- jump_at("2025-05-03")
M <- merge(J22[, .(keyword, jump22 = jump)], J25[, .(keyword, jump25 = jump)], by = "keyword")

cat("\nPL2  BOTH campaigns on ONE normalisation (no chaining, no anchor)\n")
print(M[order(-jump22)], row.names = FALSE)

cat("\nPL3  THE TEST: is fed2025 still ~30x compressed relative to fed2022?\n")
cat(sprintf("     old election-local scales: fed2022 eligible max 57.6 | fed2025 eligible max 1.6  (36x)\n"))
cat(sprintf("     long window:               Ryan 2022 jump %.2f | Boele 2025 jump %.2f  (%.1fx)\n",
            M[keyword=="Monique Ryan", jump22], M[keyword=="Nicolette Boele", jump25],
            M[keyword=="Monique Ryan", jump22] / max(M[keyword=="Nicolette Boele", jump25], 1e-9)))
cat("\nPL4  each candidate should peak in THEIR OWN election -- a sanity check the\n")
cat("     old method could not perform at all\n")
pk <- s[, .SD[which.max(hits)], by = keyword][, .(keyword, peak_date = date, peak = hits)]
print(pk[order(peak_date)], row.names = FALSE)
