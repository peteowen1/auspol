# Query Google Trends for the emergence test, using the method validated in
# docs/reference/google-trends-method.md. READ THAT FILE FIRST.
#
# Four measurement faults produced null results that were then interpreted as
# findings. This fixes all four, and each fix is measured on a known case:
#
#   1. SEARCH FORM, NOT LEGAL FORM. "Kylea Jane Tink" returned 0.000;
#      "Kylea Tink" returns 1.479 against the same incumbent.
#   2. NINE-MONTH WINDOW TO FORCE WEEKLY BUCKETS. Google returns daily data up
#      to ~6 months and weekly beyond ~9. On daily buckets a modest candidate
#      sits under Google's publishing threshold and is reported as 0 --
#      "insufficient data", not "nobody searched". Max Chandler-Mather is 0.000
#      daily and 0.405 weekly. Averaging daily zeros CANNOT recover this: they
#      are zeroed at source.
#   3. SLICE TO THE CAMPAIGN. The long window exists ONLY to buy weekly
#      granularity, so only the final 8 weeks are averaged. Challengers peak
#      during the campaign and the campaign mean is consistently the higher.
#   4. STATE geo, NOT NATIONAL. A local candidate's volume divided by the whole
#      country's traffic falls under the threshold.
#
# LITERAL STRINGS, NOT TOPICS -- deliberately, and against the literature's
# usual advice. Trends entities are typed "Member of the Australian House of
# Representatives", a status conferred by WINNING, and entity existence itself
# tracks notability, so topics leak the outcome into a backtest and may not
# exist at all for a live candidate. The cost is accepted rather than hidden.
#
# NO LEAKAGE: the window ends the day BEFORE polling day.
#
# Emits ET* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(gtrendsR))
# normalise_name() and search_form() come from R/names.R, loaded by load_all()
# above. They were duplicated in this file and its sibling, the fix was applied
# to one and not the other, and Kylea Tink came back 0.0 for a second time.
# One definition, one place.

SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "8"))
SPAN  <- 300L   # days: forces 7-day buckets
WEEKS <- 8L     # campaign slice
CACHE <- file.path("external", "reference", "trends")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

POLL <- c(fed2010 = "2010-08-21", fed2013 = "2013-09-07", fed2016 = "2016-07-02",
          fed2019 = "2019-05-18", fed2022 = "2022-05-21", fed2025 = "2025-05-03")
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
GEO_OF <- c(NSW = "AU-NSW", VIC = "AU-VIC", QLD = "AU-QLD", SA = "AU-SA",
            WA = "AU-WA", TAS = "AU-TAS", NT = "AU-NT", ACT = "AU-ACT")


fetch_pair <- function(cand, anchor, geo, poll) {
  to <- as.Date(poll) - 1; from <- to - SPAN
  key <- gsub("[^A-Za-z0-9]", "_", sprintf("v2-%s-%s-%s-%s", geo, to, anchor, cand))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) {
    z <- readRDS(f)
    return(if (isTRUE(z$empty)) NULL else z)
  }
  r <- NULL
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = c(anchor, cand), geo = geo,
                          time = paste(from, to), onlyInterest = TRUE),
                  error = function(e) NULL)
    if (!is.null(r) && !is.null(r$interest_over_time)) break
    Sys.sleep(20 * att)
  }
  # CACHE FAILURES TOO. A row that genuinely has no data was being re-attempted
  # every run with 20+40+60s of backoff -- two minutes burnt per dead row, per
  # run, forever. Only 4 of 9 attempted rows were cached because the other 5
  # returned nothing. A negative result is a result: record it, and let a
  # deliberate cache clear be the way to retry.
  if (is.null(r) || is.null(r$interest_over_time)) {
    saveRDS(list(cand = NA_real_, anchor = NA_real_, step = NA_real_,
                 npts = 0L, empty = TRUE), f)
    return(NULL)
  }
  d <- as.data.table(r$interest_over_time)
  d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]
  d[, date := as.Date(date)]
  step <- as.numeric(stats::median(diff(sort(unique(d$date)))))
  cutoff <- max(d$date) - WEEKS * 7L
  m <- d[date > cutoff, .(m = mean(hits)), by = keyword]
  gv <- function(k) { v <- m[keyword == k, m]; if (length(v)) v else NA_real_ }
  out <- list(cand = gv(cand), anchor = gv(anchor), step = step,
              npts = uniqueN(d$date))
  saveRDS(out, f)
  out
}

S <- fread("output/emergence-test.csv", showProgress = FALSE)
S <- S[election %in% names(POLL)]
C <- fread("output/candidacies.csv", showProgress = FALSE)
st <- unique(C[region == "fed" & !is.na(state), .(year, seat, state)])
S <- merge(S, st, by = c("year", "seat"), all.x = TRUE)

S[, cand := search_form(given, surname, name)]
S[, anchor := fifelse(inc_running, search_form(inc_given, inc_surname, inc_name),
                      NA_character_)]
# Self-comparison: the sitting member IS the non-major on the ballot (Wilkie
# 2013, Katter 2013). Ratio 1.000 by construction -- incumbency, not emergence.
self <- S[!is.na(anchor) & cand == anchor]
if (nrow(self)) {
  cat(sprintf("ET0  dropping %d self-comparison row(s): %s\n", nrow(self),
              paste(unique(self$cand), collapse = ", ")))
  S <- S[is.na(anchor) | cand != anchor]
}
S[is.na(anchor), anchor := vapply(election, function(e) PM(POLL[[e]]), character(1))]
S[, anchor_type := fifelse(inc_running, "incumbent", "PM fallback")]
S[, geo := fifelse(is.na(state) | !state %in% names(GEO_OF), "AU",
                   GEO_OF[as.character(state)])]
cat(sprintf("ET1  %d rows | %d incumbent-anchored | %d with a state geo\n",
            nrow(S), sum(S$anchor_type == "incumbent"), sum(S$geo != "AU")))

# BOUNDED SLICE PER RUN. Long runs were being killed mid-flight, losing the
# uncached tail each time. Each invocation now processes at most MAX_NEW
# uncached rows and stops; the cache makes the next invocation resume. Cached
# rows are free and are always all processed, so the written file is complete
# for everything fetched so far.
MAX_NEW <- as.integer(Sys.getenv("AUSPOL_MAX_NEW", "12"))
new_done <- 0L
rows <- list()
for (i in seq_len(nrow(S))) {
  key <- gsub("[^A-Za-z0-9]", "_",
              sprintf("v2-%s-%s-%s-%s", S$geo[i], as.Date(POLL[[S$election[i]]]) - 1,
                      S$anchor[i], S$cand[i]))
  cached <- file.exists(file.path(CACHE, paste0(substr(key, 1, 150), ".rds")))
  if (!cached && new_done >= MAX_NEW) {
    rows[[i]] <- data.table(
      grp = S$grp[i], election = S$election[i], seat = S$seat[i],
      name = S$cand[i], party = S$party[i], pcv = S$pcv[i], won = S$won[i],
      our_p = S$our_p[i], anchor = S$anchor[i], anchor_type = S$anchor_type[i],
      geo = S$geo[i],
      hand_added = if ("hand_added" %in% names(S)) S$hand_added[i] else FALSE,
      cand_hits = NA_real_, anchor_hits = NA_real_, step_days = NA_real_,
      ratio = NA_real_)
    next
  }
  r <- fetch_pair(S$cand[i], S$anchor[i], S$geo[i], POLL[[S$election[i]]])
  if (!cached) new_done <- new_done + 1L
  ratio <- if (!is.null(r) && is.finite(r$anchor) && r$anchor > 0)
    r$cand / r$anchor else NA_real_
  rows[[i]] <- data.table(
    grp = S$grp[i], election = S$election[i], seat = S$seat[i], name = S$cand[i],
    party = S$party[i], pcv = S$pcv[i], won = S$won[i], our_p = S$our_p[i],
    anchor = S$anchor[i], anchor_type = S$anchor_type[i], geo = S$geo[i],
    hand_added = if ("hand_added" %in% names(S)) S$hand_added[i] else FALSE,
    cand_hits = if (is.null(r)) NA_real_ else r$cand,
    anchor_hits = if (is.null(r)) NA_real_ else r$anchor,
    step_days = if (is.null(r)) NA_real_ else r$step, ratio = ratio)
  cat(sprintf("ET2  %-8s %-14s %-20s vs %-18s %-7s ratio %s\n",
              S$election[i], substr(S$seat[i], 1, 14), substr(S$cand[i], 1, 20),
              substr(S$anchor[i], 1, 18), S$geo[i],
              if (is.finite(ratio)) sprintf("%.3f", ratio) else "--"))
  if (!cached) Sys.sleep(SLEEP)
}
R <- rbindlist(rows)
fwrite(R, "output/emergence-trends.csv")
cat(sprintf("\nET8  %d rows | %d usable | weekly buckets in %d\n", nrow(R),
            sum(is.finite(R$ratio)), sum(R$step_days == 7, na.rm = TRUE)))
cat("ET9  wrote output/emergence-trends.csv\n")
