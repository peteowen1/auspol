# Does NSW's departed-member variance blowup track preference exhaustion
# (the OPV mechanism) or is it something else, e.g. a bigger personal vote?
#
# docs/reviews/nsw-departed-member-2026-09-15.md found a safe NSW seat is
# called wrong 26.2% of the time when the previous winner is off the ballot,
# against 1.8% when they stand -- and it is a VARIANCE effect (sd 5.17 to
# 8.81 on the held party's own primary), not a level effect. Two mechanisms
# were left untested because the exhaustion data was still unparsed:
#   1. OPV: a departing member's personal vote exhausts rather than flowing
#      back to their party, so departed seats should show a HIGHER exhaustion
#      rate than stood seats.
#   2. NSW state members simply carry a bigger personal vote (regional /
#      institutional, nothing to do with OPV specifically).
# This is that test. It reuses the DOP pages fetch_transfers_nsw.R already
# cached but never kept the Exhausted Votes row from
# (docs/reviews/unparsed-preference-detail-2026-09-15.md: "we store class-
# level flows" and discard the exhausted line at parse time).
#
# WHY exhaustion rate and not seat_sd directly: exhaustion is the mechanism
# OPV predicts. If departed seats do not exhaust more than stood seats, OPV
# is not the explanation and the multiplier belongs on region/personal-vote,
# not on a "which votes exhaust" model.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

RAW <- file.path("external", "reference", "nsw", "dop")
OUT <- election_data_path()

strip <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", "", x)))

# Final cumulative exhausted-vote count for one seat's distribution: the last
# progressive-total cell on the "Exhausted Votes" row. NULL for seats decided
# without a full distribution (no exclusions, or an outright majority).
exhausted_final <- function(html) {
  tb <- regmatches(html, regexpr("(?s)<table.*?</table>", html, perl = TRUE))
  if (!length(tb)) return(NA_real_)
  trs <- regmatches(tb, gregexpr("(?s)<tr.*?</tr>", tb, perl = TRUE))[[1]]
  for (tr in trs) {
    cells <- strip(regmatches(tr, gregexpr("(?s)<t[hd].*?</t[hd]>", tr, perl = TRUE))[[1]])
    if (!length(cells)) next
    if (!grepl("^Exhausted", cells[1])) next
    vals <- suppressWarnings(as.numeric(gsub("[^0-9]", "", cells[-1])))
    vals <- vals[is.finite(vals)]
    if (!length(vals)) return(NA_real_)
    return(vals[length(vals)])
  }
  NA_real_
}

ELECTIONS <- list(list(year = 2019, code = "SG1901"), list(year = 2023, code = "SG2301"))

fpn_of <- function(year) {
  f <- election_data_path(sprintf("nswec-%d-nsw-firstprefs.csv", year))
  d <- as.data.table(read.csv(f))
  d[, .(formal = sum(votes)), by = seat]
}

rows <- list()
for (E in ELECTIONS) {
  fp <- fpn_of(E$year)
  files <- list.files(RAW, pattern = sprintf("^%s-.*\\.html$", E$code), full.names = TRUE)
  files <- files[!grepl("index-", files)]
  for (f in files) {
    h <- paste(readLines(f, warn = FALSE), collapse = "\n")
    ex <- exhausted_final(h)
    slug <- sub(sprintf("^%s-", E$code), "", sub("\\.html$", "", basename(f)))
    rows[[length(rows) + 1L]] <- data.table(election = sprintf("nsw%d", E$year),
                                             slug = slug, exhausted = ex)
  }
}
ex <- rbindlist(rows)

# Slug -> seat name the same way fetch_transfers_nsw.R does: match against the
# first-preference workbook's own seat names, never by un-slugging.
name_by_slug <- list()
for (E in ELECTIONS) {
  fp <- fpn_of(E$year)
  slug <- tolower(gsub(" ", "-", fp$seat))
  name_by_slug[[sprintf("nsw%d", E$year)]] <- setNames(fp$seat, slug)
}
ex[, seat := mapply(function(e, s) unname(name_by_slug[[e]][s]), election, slug)]
bad <- ex[is.na(seat)]
if (nrow(bad)) stop("Unmatched slugs: ", paste(bad$slug, collapse = ", "))

formal <- rbindlist(lapply(ELECTIONS, function(E)
  fpn_of(E$year)[, election := sprintf("nsw%d", E$year)]))
ex <- merge(ex, formal, by = c("election", "seat"))
ex[, exhaust_rate := exhausted / formal]

cat(sprintf("EX1  %d seat-elections parsed, %d with no distribution (majority/first-pref win)\n",
            nrow(ex), sum(is.na(ex$exhausted))))

dep <- fread(file.path("output", "retirement-derived.csv"))
setnames(dep, "pair", "election")
m <- merge(ex, dep, by = c("election", "seat"))
cat(sprintf("EX2  %d of %d seat-elections matched to a departure flag\n", nrow(m), nrow(ex)))

m <- m[!is.na(exhaust_rate)]

cat("\nEX3  exhaustion rate, NSW seats where a full distribution happened, by departure:\n")
print(m[, .(n = .N, mean_exhaust = mean(exhaust_rate), sd = sd(exhaust_rate)),
        by = retire_derived])

tt <- t.test(exhaust_rate ~ retire_derived, data = m)
cat(sprintf("\nEX4  t-test departed vs stood, mean diff = %.4f, t = %.3f, p = %.4f\n",
            diff(tt$estimate) * -1, tt$statistic, tt$p.value))

# The eleven seats the review named as safe-and-wrong: do THEY exhaust more
# than the rest of the departed cohort, or is the departed-vs-stood split
# already the whole story?
eleven <- data.table(
  election = c("nsw2019","nsw2019","nsw2019","nsw2019","nsw2023","nsw2023",
               "nsw2023","nsw2023","nsw2023","nsw2023","nsw2023"),
  seat = c("Barwon","Orange","Murray","Wagga Wagga","Monaro","Wakehurst",
           "Parramatta","Riverstone","South Coast","Bega","Holsworthy"))
m[, in_eleven := FALSE]
m[eleven, in_eleven := TRUE, on = c("election", "seat")]
cat("\nEX5  the eleven wrong-safe-departed seats vs the rest of the departed cohort:\n")
print(m[retire_derived == 1, .(n = .N, mean_exhaust = mean(exhaust_rate), sd = sd(exhaust_rate)),
        by = in_eleven])

fwrite(m, file.path("output", "nsw-exhaustion-by-departure.csv"))
cat(sprintf("\nEX6  wrote %s\n", file.path("output", "nsw-exhaustion-by-departure.csv")))
