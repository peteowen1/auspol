#!/usr/bin/env Rscript
# Fetch Poll Bludger "Newspoll quarterly breakdowns" posts (federal voting intention
# by state and by demographic group) and derive a tidy long CSV.
#
# WHY THIS SHAPE: the source is prose commentary on The Australian's paywalled
# Newspoll tables, not a structured table itself. So this script:
#   1. Downloads and PERMANENTLY KEEPS the raw HTML of every post (never re-derives
#      from a summary — CLAUDE.md "keep raw scraped data").
#   2. Also saves a plain-text extraction of each post's article body, so the
#      provenance of every number below can be checked against the actual text.
#   3. Encodes the tidy rows in R below, each one hand-read off the corresponding
#      text file, because a generic regex over free-form journalistic prose is not
#      reliable enough to trust unsupervised (numbers appear as deltas ("up five"),
#      absolute levels, or both, in no fixed order or units).
#
# Re-running this script only re-fetches pages that are missing on disk, and always
# re-writes breakdowns.csv from the hand-coded table below.
#
# Coverage: this captures every "Newspoll quarterly breakdowns" (or equivalent
# state/demographic aggregate) post on Poll Bludger that a search could locate,
# from Feb 2023 to Sep 2026. NOT found despite searching: a Jul-Dec 2022 post
# (the Feb-Apr 2023 post refers to one "accumulating results from July through to
# December last year" as the first post-election aggregate, but no URL for it
# was found) — so mid-late 2022 is a real gap, not an oversight. Wikipedia's
# "Opinion polling for the next Australian federal election" page was checked
# directly (fetched below) and contains NO state or demographic breakdown table
# (topline national voting intention only) — confirmed by grep, not just search.
# Resolve Political Monitor's own site was not found to publish an open,
# non-paywalled state-breakdown table in the same style; its numbers appear on
# Poll Bludger only in prose (captured here where numeric).

suppressPackageStartupMessages({
  library(utils)
})

raw_dir  <- "external/reference/polls/newspoll-quarterly/raw"
text_dir <- "external/reference/polls/newspoll-quarterly/text"
out_csv  <- "external/reference/polls/newspoll-quarterly/breakdowns.csv"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(text_dir, recursive = TRUE, showWarnings = FALSE)

ua <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36 auspol-research/1.0 (contact: fptpost@gmail.com)"

# key -> url. Keys encode publish date and (approximate) covered period.
posts <- c(
  "2023-04-15_feb-apr"   = "https://www.pollbludger.net/2023/04/15/newspoll-breakdowns-february-to-april/",
  "2023-10-23_aug-oct"   = "https://www.pollbludger.net/2023/10/23/newspoll-quarterly-breakdowns-open-thread/",
  "2024-04-01_jan-mar"   = "https://www.pollbludger.net/2024/04/01/newspoll-quarterly-breakdowns-january-to-march-open-thread/",
  "2024-10-01_jul-sep"   = "https://www.pollbludger.net/2024/10/01/federal-polls-newspoll-quarterly-and-roy-morgan-weekly-open-thread/",
  "2024-12-27_oct-dec"   = "https://www.pollbludger.net/2024/12/27/newspoll-breakdowns-october-to-december-open-thread/",
  "2025-03-24_jan-mar"   = "https://www.pollbludger.net/2025/03/24/federal-poll-aggregates-newspoll-and-freshwater-strategy-open-thread/",
  "2025-04-23_late-mar-apr" = "https://www.pollbludger.net/2025/04/23/polls-newspoll-breakdowns-and-roy-morgan-open-thread/",
  "2025-12-26_sep-nov"   = "https://www.pollbludger.net/2025/12/26/newspoll-quarterly-breakdowns-september-to-november-open-thread/",
  "2026-04-06_jan-mar"   = "https://www.pollbludger.net/2026/04/06/newspoll-quarterly-breakdowns-january-to-march-open-thread-2/",
  "2026-07-06_apr-jun"   = "https://www.pollbludger.net/2026/07/06/monday-miscellany-newspoll-quarterly-breakdowns-and-more-open-thread/",
  "2026-09-28_jul-sep"   = "https://www.pollbludger.net/2026/09/28/newspoll-quarterly-breakdowns-july-to-september-open-thread/"
)

html_to_text <- function(html) {
  # (?s) makes . match newlines (PCRE dotall) -- without it this regex only ever
  # matches within a single line and silently falls back to the whole page.
  body <- regmatches(html, regexpr('(?s)<div class="entry-content">.*?<footer', html, perl = TRUE))
  if (length(body) == 0 || nchar(body) == 0) body <- html
  body <- gsub("(?s)<script.*?</script>", " ", body, perl = TRUE)
  body <- gsub("(?s)<style.*?</style>", " ", body, perl = TRUE)
  body <- gsub("(?s)<!--.*?-->", " ", body, perl = TRUE)
  body <- gsub("<[^>]+>", " ", body, perl = TRUE)
  body <- gsub("&nbsp;", " ", body)
  body <- gsub("&#8211;", "-", body)
  body <- gsub("&#8217;|&#8216;", "'", body)
  body <- gsub("&#8220;|&#8221;", '"', body)
  body <- gsub("&amp;", "&", body)
  body <- gsub("\\s+", " ", body)
  trimws(body)
}

for (key in names(posts)) {
  f <- file.path(raw_dir, paste0(key, ".html"))
  if (file.exists(f) && file.size(f) > 0) {
    message("SKIP (already on disk): ", key)
  } else {
    message("Fetching: ", key)
    ok <- tryCatch({
      download.file(posts[[key]], destfile = f, method = "libcurl",
                    headers = c(`User-Agent` = ua), quiet = TRUE)
      TRUE
    }, error = function(e) { message("  FAILED: ", conditionMessage(e)); FALSE })
    Sys.sleep(1)
  }
  tf <- file.path(text_dir, paste0(key, ".txt"))
  if (file.exists(f) && file.size(f) > 0 && !file.exists(tf)) {
    html <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    writeLines(html_to_text(html), tf, useBytes = TRUE)
  }
}

base_url <- function(key) unname(posts[key])

# ---- Tidy rows, hand-extracted from each post's text file (see text_dir) ----
# Only rows where the source states an actual LEVEL (a percentage), not merely a
# point change ("up five"), are included — a delta with no stated base cannot be
# turned into a comparable percentage without guessing.
rows <- list()
add <- function(key, pollster, p_start, p_end, published, n, dim, group, party, fp = NA, tpp_alp = NA) {
  rows[[length(rows) + 1]] <<- data.frame(
    pollster = pollster, period_start = p_start, period_end = p_end, published = published,
    sample_n = n, dimension = dim, group = group, party = party, fp = fp, tpp_alp = tpp_alp,
    source_url = base_url(key), stringsAsFactors = FALSE
  )
}

## 2023-04-15: Feb-Apr 2023 (3 polls, 2023-02-01 to 2023-04-03), n=4756
k <- "2023-04-15_feb-apr"
add(k, "Newspoll", "2023-02-01", "2023-04-03", "2023-04-15", 4756, "state", "VIC", "ALP", tpp_alp = 58)
add(k, "Newspoll", "2023-02-01", "2023-04-03", "2023-04-15", 4756, "state", "QLD", "ALP", tpp_alp = 50)
add(k, "Newspoll", "2023-02-01", "2023-04-03", "2023-04-15", 4756, "state", "SA",  "ALP", tpp_alp = 56)
add(k, "Newspoll", "2023-02-01", "2023-04-03", "2023-04-15", 4756, "state", "NSW", "ALP", tpp_alp = 55)
add(k, "Newspoll", "2023-02-01", "2023-04-03", "2023-04-15", 4756, "state", "WA",  "ALP", tpp_alp = 55)
add(k, "Newspoll", "2023-02-01", "2023-04-03", "2023-04-15", 4756, "age", "18-34", "ALP", fp = 43)
add(k, "Newspoll", "2023-02-01", "2023-04-03", "2023-04-15", 4756, "age", "65+",   "ALP", fp = 31)
add(k, "Newspoll", "2023-02-01", "2023-04-03", "2023-04-15", 4756, "state", "VIC", "ALP", fp = 41)
add(k, "Newspoll", "2023-02-01", "2023-04-03", "2023-04-15", 4756, "state", "VIC", "GRN", fp = 11)

## 2023-10-23: Aug-Oct 2023 (4 polls, 2023-08-28 to 2023-10-12), n=6378 (incl. Voice referendum poll)
k <- "2023-10-23_aug-oct"
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "state", "NSW", "ALP", tpp_alp = 56)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "state", "SA",  "ALP", tpp_alp = 57)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "state", "VIC", "ALP", tpp_alp = 54)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "state", "WA",  "ALP", tpp_alp = 53)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "state", "QLD", "ALP", tpp_alp = 48)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "state", "TAS", "ALP", tpp_alp = 57)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "age", "18-34", "ALP", tpp_alp = 64)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "national", "national", "LNP", fp = 26)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "national", "national", "GRN", fp = 25)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "national", "national", "ALP", fp = 37)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "gender", "women", "ALP", tpp_alp = 56)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "gender", "men",   "ALP", tpp_alp = 51)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "income", "<=50000",       "ALP", tpp_alp = 57)
add(k, "Newspoll", "2023-08-28", "2023-10-12", "2023-10-23", 6378, "income", ">=150000",      "ALP", tpp_alp = 50)

## 2024-04-01: Jan-Mar 2024 (3 polls, 2024-01-31 to 2024-03-22), n=3691
k <- "2024-04-01_jan-mar"
add(k, "Newspoll", "2024-01-31", "2024-03-22", "2024-04-01", 3691, "state", "WA",  "ALP", tpp_alp = 49)
add(k, "Newspoll", "2024-01-31", "2024-03-22", "2024-04-01", 3691, "state", "NSW", "ALP", tpp_alp = 50)
add(k, "Newspoll", "2024-01-31", "2024-03-22", "2024-04-01", 3691, "state", "VIC", "ALP", tpp_alp = 55)
add(k, "Newspoll", "2024-01-31", "2024-03-22", "2024-04-01", 3691, "state", "QLD", "ALP", tpp_alp = 47)
add(k, "Newspoll", "2024-01-31", "2024-03-22", "2024-04-01", 3691, "state", "SA",  "ALP", tpp_alp = 54)
add(k, "Newspoll", "2024-01-31", "2024-03-22", "2024-04-01", 3691, "age", "18-34", "ALP", tpp_alp = 61)
add(k, "Newspoll", "2024-01-31", "2024-03-22", "2024-04-01", 3691, "gender", "men",   "ALP", tpp_alp = 50)
add(k, "Newspoll", "2024-01-31", "2024-03-22", "2024-04-01", 3691, "gender", "women", "ALP", tpp_alp = 53)
add(k, "Newspoll", "2024-01-31", "2024-03-22", "2024-04-01", 3691, "language", "non-english-speaking", "ALP", tpp_alp = 55)

## 2024-10-01: Jul-Sep 2024 (4 polls, 2024-07-15 to 2024-09-20), n=5035
k <- "2024-10-01_jul-sep"
add(k, "Newspoll", "2024-07-15", "2024-09-20", "2024-10-01", 5035, "state", "NSW", "ALP", tpp_alp = 49)
add(k, "Newspoll", "2024-07-15", "2024-09-20", "2024-10-01", 5035, "state", "VIC", "ALP", tpp_alp = 52)
add(k, "Newspoll", "2024-07-15", "2024-09-20", "2024-10-01", 5035, "state", "QLD", "ALP", tpp_alp = 46)
add(k, "Newspoll", "2024-07-15", "2024-09-20", "2024-10-01", 5035, "state", "WA",  "ALP", tpp_alp = 52)
add(k, "Newspoll", "2024-07-15", "2024-09-20", "2024-10-01", 5035, "state", "SA",  "ALP", tpp_alp = 54)
add(k, "Newspoll", "2024-07-15", "2024-09-20", "2024-10-01", 5035, "national", "national", "ALP", tpp_alp = 50)

## 2024-12-27: Oct-Dec 2024 (3 polls, 2024-10-07 to 2024-12-06), n=3775
k <- "2024-12-27_oct-dec"
add(k, "Newspoll", "2024-10-07", "2024-12-06", "2024-12-27", 3775, "state", "NSW", "ALP", tpp_alp = 50)
add(k, "Newspoll", "2024-10-07", "2024-12-06", "2024-12-27", 3775, "state", "VIC", "ALP", tpp_alp = 50)
add(k, "Newspoll", "2024-10-07", "2024-12-06", "2024-12-27", 3775, "state", "QLD", "ALP", tpp_alp = 47)
add(k, "Newspoll", "2024-10-07", "2024-12-06", "2024-12-27", 3775, "state", "WA",  "ALP", tpp_alp = 54)
add(k, "Newspoll", "2024-10-07", "2024-12-06", "2024-12-27", 3775, "state", "SA",  "ALP", tpp_alp = 53)
add(k, "Newspoll", "2024-10-07", "2024-12-06", "2024-12-27", 3775, "gender", "men",   "ALP", tpp_alp = 50)
add(k, "Newspoll", "2024-10-07", "2024-12-06", "2024-12-27", 3775, "gender", "women", "ALP", tpp_alp = 50)
add(k, "Newspoll", "2024-10-07", "2024-12-06", "2024-12-27", 3775, "income", "50000-99000",  "ALP", tpp_alp = 50)
add(k, "Newspoll", "2024-10-07", "2024-12-06", "2024-12-27", 3775, "income", ">150000",      "ALP", tpp_alp = 49)

## 2025-03-24: Jan-Mar 2025 (3 polls), n=3757
k <- "2025-03-24_jan-mar"
add(k, "Newspoll", "2025-01-01", "2025-03-24", "2025-03-24", 3757, "state", "NSW", "ALP", tpp_alp = 50)
add(k, "Newspoll", "2025-01-01", "2025-03-24", "2025-03-24", 3757, "state", "VIC", "ALP", tpp_alp = 51)
add(k, "Newspoll", "2025-01-01", "2025-03-24", "2025-03-24", 3757, "state", "QLD", "ALP", tpp_alp = 43)
add(k, "Newspoll", "2025-01-01", "2025-03-24", "2025-03-24", 3757, "state", "WA",  "ALP", tpp_alp = 54)
add(k, "Newspoll", "2025-01-01", "2025-03-24", "2025-03-24", 3757, "state", "SA",  "ALP", tpp_alp = 50)
# Freshwater Strategy, same post, same quarter, FP-implied 2pp only (primary votes not given)
add(k, "Freshwater", "2025-01-01", "2025-03-24", "2025-03-24", 3152, "state", "NSW", "ALP", tpp_alp = 48)
add(k, "Freshwater", "2025-01-01", "2025-03-24", "2025-03-24", 3152, "state", "VIC", "ALP", tpp_alp = 51)
add(k, "Freshwater", "2025-01-01", "2025-03-24", "2025-03-24", 3152, "state", "QLD", "ALP", tpp_alp = 46)
add(k, "Freshwater", "2025-01-01", "2025-03-24", "2025-03-24", 3152, "state", "WA",  "ALP", tpp_alp = 56)

## 2025-04-23: pre-election special aggregate, 4 polls "since late March" (n not stated in post)
k <- "2025-04-23_late-mar-apr"
add(k, "Newspoll", "2025-03-24", "2025-04-23", "2025-04-23", NA, "national", "national", "ALP", tpp_alp = 52)
add(k, "Newspoll", "2025-03-24", "2025-04-23", "2025-04-23", NA, "state", "NSW", "ALP", tpp_alp = 52)
add(k, "Newspoll", "2025-03-24", "2025-04-23", "2025-04-23", NA, "state", "VIC", "ALP", tpp_alp = 53)
add(k, "Newspoll", "2025-03-24", "2025-04-23", "2025-04-23", NA, "state", "QLD", "ALP", tpp_alp = 46)
add(k, "Newspoll", "2025-03-24", "2025-04-23", "2025-04-23", NA, "state", "SA",  "ALP", tpp_alp = 55)
add(k, "Newspoll", "2025-03-24", "2025-04-23", "2025-04-23", NA, "state", "WA",  "ALP", tpp_alp = 54)
add(k, "Newspoll", "2025-03-24", "2025-04-23", "2025-04-23", NA, "gender", "men",   "ALP", tpp_alp = 50)
add(k, "Newspoll", "2025-03-24", "2025-04-23", "2025-04-23", NA, "gender", "women", "ALP", tpp_alp = 54)
add(k, "Newspoll", "2025-03-24", "2025-04-23", "2025-04-23", NA, "housing", "renter",          "ALP", tpp_alp = 65)
add(k, "Newspoll", "2025-03-24", "2025-04-23", "2025-04-23", NA, "housing", "mortgage-payer",  "ALP", tpp_alp = 54)

## 2025-12-26: Sep-Nov 2025 (3 polls, 2025-09-29 to 2025-11-20), n=3774
k <- "2025-12-26_sep-nov"
add(k, "Newspoll", "2025-09-29", "2025-11-20", "2025-12-26", 3774, "national", "national", "ALP", tpp_alp = 57)
add(k, "Newspoll", "2025-09-29", "2025-11-20", "2025-12-26", 3774, "state", "NSW", "ALP", tpp_alp = 58)
add(k, "Newspoll", "2025-09-29", "2025-11-20", "2025-12-26", 3774, "state", "VIC", "ALP", tpp_alp = 60)
add(k, "Newspoll", "2025-09-29", "2025-11-20", "2025-12-26", 3774, "state", "QLD", "ALP", tpp_alp = 52)
add(k, "Newspoll", "2025-09-29", "2025-11-20", "2025-12-26", 3774, "state", "WA",  "ALP", tpp_alp = 56)
add(k, "Newspoll", "2025-09-29", "2025-11-20", "2025-12-26", 3774, "state", "SA",  "ALP", tpp_alp = 58)
add(k, "Newspoll", "2025-09-29", "2025-11-20", "2025-12-26", 3774, "state", "QLD", "ONP", fp = 18)
add(k, "Newspoll", "2025-09-29", "2025-11-20", "2025-12-26", 3774, "state", "QLD", "LNP", fp = 27)
add(k, "Newspoll", "2025-09-29", "2025-11-20", "2025-12-26", 3774, "income", "100000-150000", "ALP", tpp_alp = 60)

## 2026-04-06: Jan-Mar 2026 (national FP only stated at usable levels)
k <- "2026-04-06_jan-mar"
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "national", "national", "ALP", fp = 32)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "national", "national", "LNP", fp = 20)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "national", "national", "ONP", fp = 25)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "state", "QLD", "ONP", fp = 30)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "state", "QLD", "ALP", fp = 27)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "state", "QLD", "LNP", fp = 23)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "state", "SA",  "LNP", fp = 13)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "age", "18-34", "LNP", fp = 14)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "age", "65+",   "LNP", fp = 26)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "age", "18-34", "ONP", fp = 19)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "age", "18-34", "GRN", fp = 26)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "age", "65+",   "GRN", fp = 3)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "gender", "women", "GRN", fp = 14)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "gender", "men",   "GRN", fp = 10)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "gender", "women", "ALP", fp = 30)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "gender", "men",   "ALP", fp = 34)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "income", "<=50000",   "ONP", fp = 29)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "income", ">=150000",  "ONP", fp = 23)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "language", "non-english-speaking", "ONP", fp = 19)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "language", "english-only",         "ONP", fp = 29)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "religion", "christian", "ONP", fp = 31)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "religion", "christian", "ALP", fp = 28)
add(k, "Newspoll", "2026-01-01", "2026-03-31", "2026-04-06", NA, "religion", "christian", "LNP", fp = 24)

## 2026-07-06: Apr-Jun 2026 -- post gives ONLY point-changes and qualitative
## movement, no absolute levels ("Labor gaining three points", "One Nation up six
## among those with technical qualifications"), so NO rows are added for this
## period. It is recorded here so its absence from breakdowns.csv is a documented
## decision, not a missed fetch.

## 2026-09-28: Jul-Sep 2026 (4 polls, 2026-07-13 to 2026-09-18), n=4967
k <- "2026-09-28_jul-sep"
add(k, "Newspoll", "2026-07-13", "2026-09-18", "2026-09-28", 4967, "state", "QLD", "ALP", fp = 25)
add(k, "Newspoll", "2026-07-13", "2026-09-18", "2026-09-28", 4967, "state", "QLD", "LNP", fp = 19)
add(k, "Newspoll", "2026-07-13", "2026-09-18", "2026-09-28", 4967, "state", "QLD", "GRN", fp = 12)
add(k, "Newspoll", "2026-07-13", "2026-09-18", "2026-09-28", 4967, "state", "QLD", "ONP", fp = 36)
add(k, "Newspoll", "2026-07-13", "2026-09-18", "2026-09-28", 4967, "state", "SA",  "ALP", fp = 32)
add(k, "Newspoll", "2026-07-13", "2026-09-18", "2026-09-28", 4967, "state", "SA",  "ONP", fp = 31)
add(k, "Newspoll", "2026-07-13", "2026-09-18", "2026-09-28", 4967, "state", "SA",  "GRN", fp = 14)
add(k, "Newspoll", "2026-07-13", "2026-09-18", "2026-09-28", 4967, "state", "SA",  "LNP", fp = 13)

breakdowns <- do.call(rbind, rows)
breakdowns <- breakdowns[order(breakdowns$period_start, breakdowns$dimension, breakdowns$group), ]
write.csv(breakdowns, out_csv, row.names = FALSE, na = "")
message("Wrote ", nrow(breakdowns), " rows to ", out_csv)
