# WHOLE-SEAT salience: every candidate in a seat queried together, so Google's
# within-query normalisation puts them all on one scale.
#
# WHY THIS BEATS THE PAIRED RATIO. Trends normalises 0-100 WITHIN a query, so a
# seat's whole field in one call yields directly comparable numbers and a
# salience SHARE that sums to 100 -- the same scale as a vote share. It removes
# the anchor problem entirely: no PM fallback when the incumbent retires, no
# self-comparison when the sitting member is the non-major, no distortion when
# the incumbent is a former prime minister. It is also ~5x fewer queries.
#
# Measured on two seats we know:
#   Warringah 2019  Steggall salience 40.1% vs first preference 43.5%
#   Kooyong  2022   Ryan     salience 42.0% vs first preference 40.3%
# The CHALLENGER's share tracks their vote; the incumbent's is overstated
# (Abbott 59.9% salience against 39.3% of the vote), which is what you would
# expect -- nobody googles the major-party candidate they were always going to
# vote for.
#
# FIVE KEYWORDS PER QUERY is Google's limit and seats run 6-10 candidates, so
# batches are CHAINED: one candidate is carried into the next batch and used to
# rescale it onto the first batch's scale. A bad stitch silently distorts every
# share in the seat, so the overlap candidate is chosen as the LOUDEST of the
# previous batch -- rescaling on a zero-volume candidate would divide by ~0 and
# blow the scale up -- and a batch whose overlap comes back at zero is reported
# rather than rescaled.
#
# NO LEAKAGE: the window ends the day before polling day. The 300-day span
# exists only to force weekly buckets; the mean is taken over the final 8 weeks.
#
# Emits SS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(gtrendsR))
# normalise_name() and search_form() come from R/names.R, loaded by load_all()
# above. They were duplicated in this file and its sibling, the fix was applied
# to one and not the other, and Kylea Tink came back 0.0 for a second time.
# One definition, one place.

SPAN  <- 300L
WEEKS <- 8L
SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "10"))
MAXKW <- 5L
CACHE <- file.path("external", "reference", "trends")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)


# One batch of <= 5 keywords, cached. Returns mean hits per keyword over the
# final WEEKS weeks.
batch <- function(kw, geo, to) {
  from <- to - SPAN
  key <- gsub("[^A-Za-z0-9]", "_",
              sprintf("ss-%s-%s-%s", geo, to, paste(kw, collapse = "-")))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else z$m) }
  r <- NULL
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = kw, geo = geo, time = paste(from, to),
                          onlyInterest = TRUE), error = function(e) NULL)
    if (!is.null(r) && !is.null(r$interest_over_time)) break
    Sys.sleep(15 * att)
  }
  if (is.null(r) || is.null(r$interest_over_time)) {
    saveRDS(list(empty = TRUE), f); return(NULL)
  }
  d <- as.data.table(r$interest_over_time)
  d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]
  d[, date := as.Date(date)]
  cutoff <- max(d$date) - WEEKS * 7L
  m <- d[date > cutoff, .(hits = mean(hits)), by = keyword]
  out <- setNames(m$hits, m$keyword)
  saveRDS(list(m = out, empty = FALSE), f)
  out
}

seat_salience <- function(names_in, geo, poll) {
  kw <- unique(names_in)
  to <- as.Date(poll) - 1
  if (length(kw) <= MAXKW) {
    v <- batch(kw, geo, to)
    return(if (is.null(v)) NULL else v)
  }
  first <- batch(kw[1:MAXKW], geo, to)
  if (is.null(first)) return(NULL)
  acc <- first
  rest <- kw[-(1:MAXKW)]
  while (length(rest)) {
    # OVERLAP ON THE LOUDEST so far. Rescaling on a near-zero candidate divides
    # by ~0 and blows the whole seat's scale up.
    ov <- names(acc)[which.max(acc)]
    take <- utils::head(rest, MAXKW - 1L)
    v <- batch(c(ov, take), geo, to)
    if (is.null(v) || !ov %in% names(v)) {
      cat(sprintf("SS!  stitch failed for %s; %d candidate(s) dropped\n",
                  ov, length(take)))
      rest <- rest[-seq_along(take)]; next
    }
    if (!is.finite(v[[ov]]) || v[[ov]] <= 0) {
      cat(sprintf("SS!  overlap %s came back 0 -- cannot rescale, %d dropped\n",
                  ov, length(take)))
      rest <- rest[-seq_along(take)]; next
    }
    scale <- acc[[ov]] / v[[ov]]
    add <- v[setdiff(names(v), ov)] * scale
    acc <- c(acc, add)
    rest <- rest[-seq_along(take)]
    Sys.sleep(SLEEP)
  }
  acc
}

# ---- run over seats we know the answer for ----------------------------------
C <- fread("output/candidacies.csv", showProgress = FALSE)
POLL <- c(fed2019 = "2019-05-18", fed2022 = "2022-05-21", fed2025 = "2025-05-03")
GEO_OF <- c(NSW = "AU-NSW", VIC = "AU-VIC", QLD = "AU-QLD", SA = "AU-SA",
            WA = "AU-WA", TAS = "AU-TAS", NT = "AU-NT", ACT = "AU-ACT")
# WHICH SEATS. Default is the nine known cases, for validating the pipeline.
# AUSPOL_SALIENCE_ELECTION=fed2022 runs EVERY seat in that election, which is
# what the pre-registration requires: the nine were chosen because something
# happened in them, so fitting or scoring on them is selection on the outcome.
#
# AUSPOL_SALIENCE_MAX bounds how many NEW seats one invocation fetches. Long
# runs were being killed mid-flight; the cache makes each invocation resume.
EL_ALL <- Sys.getenv("AUSPOL_SALIENCE_ELECTION", "")
MAX_SEATS <- as.integer(Sys.getenv("AUSPOL_SALIENCE_MAX", "12"))
if (nzchar(EL_ALL)) {
  yr <- as.integer(sub("^fed", "", EL_ALL))
  WANT <- unique(C[region == "fed" & year == yr, .(election = EL_ALL, seat)])
  cat(sprintf("SS0  %s: all %d seats | max %d new per run
",
              EL_ALL, nrow(WANT), MAX_SEATS))
} else {
  WANT <- fread(text = "election,seat
fed2022,Wentworth
fed2022,North Sydney
fed2022,Goldstein
fed2022,Mackellar
fed2022,Curtin
fed2022,Kooyong
fed2022,Fowler
fed2019,Warringah
fed2022,Griffith
")
  MAX_SEATS <- nrow(WANT)
}
out <- list(); new_seats <- 0L
for (i in seq_len(nrow(WANT))) {
  el <- WANT$election[i]; sn <- WANT$seat[i]
  yr <- as.integer(sub("^fed", "", el))
  d <- C[region == "fed" & year == yr & seat == sn]
  if (!nrow(d)) { cat(sprintf("SS!  %s %s: no candidates\n", el, sn)); next }
  geo <- GEO_OF[[as.character(d$state[1])]]
  d[, kw := search_form(given, surname, name)]
  probe <- gsub("[^A-Za-z0-9]", "_",
                sprintf("ss-%s-%s-%s", geo, as.Date(POLL[[el]]) - 1,
                        paste(utils::head(d$kw, MAXKW), collapse = "-")))
  seen <- file.exists(file.path(CACHE, paste0(substr(probe, 1, 150), ".rds")))
  if (!seen) { if (new_seats >= MAX_SEATS) next; new_seats <- new_seats + 1L }
  v <- seat_salience(d$kw, geo, POLL[[el]])
  if (is.null(v)) { cat(sprintf("SS!  %s %s: no data\n", el, sn)); next }
  d[, sal := as.numeric(v[kw])]
  d[is.na(sal), sal := 0]
  d[, sal_share := 100 * sal / sum(sal)]
  cat(sprintf("\nSS2  %s %s (%s)\n", el, sn, geo))
  print(d[order(-sal_share), .(cand = kw, party, sal_share = round(sal_share, 1),
                               fp = round(pcv, 1), gap = round(sal_share - pcv, 1))],
        row.names = FALSE)
  out[[paste(el, sn)]] <- d[, .(election = el, seat = sn, name = kw, party,
                                sal_share, pcv)]
  Sys.sleep(SLEEP)
}
if (length(out)) {
  R <- rbindlist(out)
  fwrite(R, "output/seat-salience.csv")
  nm <- R[!party %in% c("ALP", "LNP", "NAT")]
  cat(sprintf("\nSS9  %d candidates in %d seats -> output/seat-salience.csv\n",
              nrow(R), uniqueN(paste(R$election, R$seat))))
  if (nrow(nm) > 2) {
    m <- summary(lm(pcv ~ sal_share, data = nm))
    cat(sprintf("SS9  NON-MAJORS: fp ~ salience share, slope %+.2f (SE %.2f) | R2 %.3f | n %d\n",
                coef(m)[2,1], coef(m)[2,2], m$r.squared, nrow(nm)))
    cat(sprintf("SS9  mean |salience share - fp| for non-majors: %.1f points\n",
                mean(abs(nm$sal_share - nm$pcv))))
  }
}
