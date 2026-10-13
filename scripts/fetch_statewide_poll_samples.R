#!/usr/bin/env Rscript
# Fetch Wikipedia's STATEWIDE (and national) voting-intention poll tables for every
# election the anchor poll files span, and keep every column of every poll row, so
# the trend model can weight polls by sample size (step 1 of
# docs/plans/statewide-poll-weighting-scope-2026-10-09.md).
#
# WHY THIS SHAPE (CLAUDE.md "Store the raw response, never the summary" and
# "Capture EVERY field"): every page is downloaded once to
# external/reference/polls/statewide-samples/raw/<key>.html and never re-fetched
# while on disk. Each run re-parses the HTML, so a parser fix needs no re-download.
# Every cell is kept as raw text; the parsed columns (fieldwork_start/end,
# sample_n, alp_fp, ...) sit beside it, never instead of it.
#
# WHICH PAGES. For every election we try BOTH a dedicated "Opinion polling for the
# <year> <State> state election" page (kind "opinion") and the main election
# article (kind "main"), because Wikipedia only has dedicated pages for the recent
# ones (checked 2026-10-09 by HTTP status; see pages_manifest.csv, which records
# every page we asked for, including the ones that do not exist). The main
# articles are mostly poll-free, but a few (qld2015, sa2018, nsw2023, qld2024)
# carry a statewide table, so they are parsed too. Federal 2007 has no page of
# its own: the 2010 page's tables start after the 2007 election.
#
# A poll row is separated from the "actual result" reference row ("2022 election")
# by row_type; only row_type == "poll" in a table_type == "primary" table is a
# voting-intention poll the join uses. Seat-poll, leader-approval and
# right-direction tables are parsed and kept (table_type says which) because the
# columns are free.

suppressPackageStartupMessages({
  library(rvest)
  library(xml2)
  library(data.table)
})

base_dir <- Sys.getenv("AUSPOL_POLL_BASE", "external/reference/polls/statewide-samples")   # env override is a test hook
raw_dir  <- file.path(base_dir, "raw")
out_csv  <- file.path(base_dir, "statewide_polls_wiki.csv")
man_csv  <- file.path(base_dir, "pages_manifest.csv")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

ua <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36 auspol-research/1.0 (contact: fptpost@gmail.com)"
wp <- "https://en.wikipedia.org/wiki/"

# ---- page list ---------------------------------------------------------------
state_names <- c(vic = "Victorian", nsw = "New South Wales", qld = "Queensland",
                 wa = "Western Australian", sa = "South Australian", tas = "Tasmanian")
# Territories hold "general elections" (2026-10-13 coverage program: every election since 2000, all nine
# jurisdictions; pages found by docs/reviews/wiki-poll-pages-2026-10-13.md).
territory_names <- c(nt = "Northern Territory", act = "Australian Capital Territory")
elections <- list(
  fed = c(2001, 2004, 2007, 2010, 2013, 2016, 2019, 2022, 2025, 2028),
  vic = c(2002, 2006, 2010, 2014, 2018, 2022, 2026),
  nsw = c(2003, 2007, 2011, 2015, 2019, 2023, 2027),
  qld = c(2001, 2004, 2006, 2009, 2012, 2015, 2017, 2020, 2024, 2028),
  wa  = c(2001, 2005, 2008, 2013, 2017, 2021, 2025),
  sa  = c(2002, 2006, 2010, 2014, 2018, 2022, 2026),
  tas = c(2002, 2006, 2010, 2014, 2018, 2021, 2024, 2025),
  nt  = c(2001, 2005, 2008, 2012, 2016, 2020, 2024),
  act = c(2001, 2004, 2008, 2012, 2016, 2020, 2024)
)
pg <- list()
for (rg in names(elections)) for (yr in elections[[rg]]) {
  key <- paste0(rg, yr)
  if (rg == "fed") {
    op   <- if (yr == 2028) "Opinion_polling_for_the_next_Australian_federal_election"
            else sprintf("Opinion_polling_for_the_%d_Australian_federal_election", yr)
    main <- if (yr == 2028) NA_character_ else sprintf("%d_Australian_federal_election", yr)
  } else if (rg %in% names(territory_names)) {
    op   <- sprintf("Opinion_polling_for_the_%d_%s_general_election", yr, gsub(" ", "_", territory_names[[rg]]))
    main <- sprintf("%d_%s_general_election", yr, gsub(" ", "_", territory_names[[rg]]))
  } else {
    op   <- sprintf("Opinion_polling_for_the_%d_%s_state_election", yr, gsub(" ", "_", state_names[[rg]]))
    main <- sprintf("%d_%s_state_election", yr, gsub(" ", "_", state_names[[rg]]))
  }
  pg[[length(pg) + 1]] <- data.table(page_key = paste0(key, "_opinion"), region = rg, election = key, kind = "opinion", title = op)
  if (!is.na(main))
    pg[[length(pg) + 1]] <- data.table(page_key = paste0(key, "_main"), region = rg, election = key, kind = "main", title = main)
}
# The current federal term keeps its leadership polling (preferred PM, approval) on a page of its own; the
# term's opinion page has no leadership section (2026-10-12, Pete asked for leader trends).
pg[[length(pg) + 1]] <- data.table(page_key = "fed2028_leaders", region = "fed", election = "fed2028", kind = "opinion",
                                   title = "Leadership_approval_opinion_polling_for_the_next_Australian_federal_election")
pages <- rbindlist(pg)
# Election dates (polling day). 2028 federal is a placeholder: it is only used as an upper bound.
# Pre-2010 state dates and Tas/NT/ACT added 2026-10-13 (from memory; to be checked against the commissions with
# the move into R/election_dates.R).
elec_dates <- rbindlist(list(
  data.table(region = "fed", year = c(2001, 2004, 2007, 2010, 2013, 2016, 2019, 2022, 2025, 2028),
             election_date = as.Date(c("2001-11-10", "2004-10-09", "2007-11-24", "2010-08-21", "2013-09-07", "2016-07-02", "2019-05-18", "2022-05-21", "2025-05-03", "2028-12-31"))),
  data.table(region = "vic", year = c(2002, 2006, 2010, 2014, 2018, 2022, 2026),
             election_date = as.Date(c("2002-11-30", "2006-11-25", "2010-11-27", "2014-11-29", "2018-11-24", "2022-11-26", "2026-11-28"))),
  data.table(region = "nsw", year = c(2003, 2007, 2011, 2015, 2019, 2023, 2027),
             election_date = as.Date(c("2003-03-22", "2007-03-24", "2011-03-26", "2015-03-28", "2019-03-23", "2023-03-25", "2027-03-27"))),
  data.table(region = "qld", year = c(2001, 2004, 2006, 2009, 2012, 2015, 2017, 2020, 2024, 2028),
             election_date = as.Date(c("2001-02-17", "2004-02-07", "2006-09-09", "2009-03-21", "2012-03-24", "2015-01-31", "2017-11-25", "2020-10-31", "2024-10-26", "2028-10-28"))),
  data.table(region = "wa", year = c(2001, 2005, 2008, 2013, 2017, 2021, 2025),
             election_date = as.Date(c("2001-02-10", "2005-02-26", "2008-09-06", "2013-03-09", "2017-03-11", "2021-03-13", "2025-03-08"))),
  data.table(region = "sa", year = c(2002, 2006, 2010, 2014, 2018, 2022, 2026),
             election_date = as.Date(c("2002-02-09", "2006-03-18", "2010-03-20", "2014-03-15", "2018-03-17", "2022-03-19", "2026-03-21"))),
  data.table(region = "tas", year = c(2002, 2006, 2010, 2014, 2018, 2021, 2024, 2025),
             election_date = as.Date(c("2002-07-20", "2006-03-18", "2010-03-20", "2014-03-15", "2018-03-03", "2021-05-01", "2024-03-23", "2025-07-19"))),
  data.table(region = "nt", year = c(2001, 2005, 2008, 2012, 2016, 2020, 2024),
             election_date = as.Date(c("2001-08-18", "2005-06-18", "2008-08-09", "2012-08-25", "2016-08-27", "2020-08-22", "2024-08-24"))),
  data.table(region = "act", year = c(2001, 2004, 2008, 2012, 2016, 2020, 2024),
             election_date = as.Date(c("2001-10-20", "2004-10-16", "2008-10-18", "2012-10-20", "2016-10-15", "2020-10-17", "2024-10-19")))
))
elec_dates[, election := paste0(region, year)]
fwrite(elec_dates, file.path(base_dir, "election_dates.csv"))
pages[, url := paste0(wp, title)]

# ---- download once -----------------------------------------------------------
pages[, status := NA_character_]
# A page is on disk only if it ends properly (closing </html>); HTTP 404/410 are remembered in a
# marker, anything else is "fetch_failed" and retried next run. See scripts/fetch_page_lib.R.
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "fetch_page_lib.R"))
only_keys <- Sys.getenv("AUSPOL_POLL_ONLY", "")   # test hook: restrict to these page keys
for (i in seq_len(nrow(pages))) {
  f  <- file.path(raw_dir, paste0(pages$page_key[i], ".html"))
  nf <- file.path(raw_dir, paste0(pages$page_key[i], ".notfound"))
  if (nzchar(only_keys) && !pages$page_key[i] %in% strsplit(only_keys, ",")[[1]]) { pages$status[i] <- "skipped_test"; next }
  if (page_complete(f)) {
    pages$status[i] <- "on_disk"
  } else if (file.exists(nf) && grepl("^status=(404|410) ", readLines(nf, n = 1, warn = FALSE))) {
    pages$status[i] <- "not_found"
  } else {
    # no page, no marker, a legacy marker ("404 or fetch failure": it never recorded the status), or an
    # incomplete file: ask again and record what was actually said.
    if (file.exists(f)) file.remove(f)
    message("Fetching: ", pages$page_key[i])
    r <- fetch_page(pages$url[i], f, ua)
    pages$status[i] <- r$status
    if (r$status == "not_found") writeLines(sprintf("status=%d %s", r$code, format(Sys.time())), nf)
    else if (file.exists(nf)) file.remove(nf)    # a stale marker that is not a 404/410 must not survive
    if (r$status == "fetch_failed") message("  FETCH FAILED (status ", r$code, "): ", pages$page_key[i], " -- will retry next run")
    Sys.sleep(1)
  }
}

# ---- cell helpers -----------------------------------------------------------
clean_ws <- function(x) {
  x <- gsub("[       ]", " ", x)
  trimws(gsub("[ \t\r\n]+", " ", x))
}
dash_re <- "[–—‒‑−‐]"   # en, em, figure, non-breaking hyphen, minus, hyphen
strip_fn <- function(x) trimws(gsub("\\s*\\{\\{FN:.*?\\}\\}", "", x))
get_fn   <- function(r) {
  m <- unlist(regmatches(r, gregexpr("\\{\\{FN:.*?\\}\\}", r)))
  if (!length(m)) return(NA_character_)
  paste(unique(sub("^\\{\\{FN:(.*)\\}\\}$", "\\1", m)), collapse = " || ")
}
pct_num <- function(x) {
  # keeps digits and the decimal point only, so "32.5%*", "38%†" and "1,234" read as numbers;
  # a cell with no digit ("—", "N/a", "<") is NA.
  x <- clean_ws(strip_fn(x))
  out <- suppressWarnings(as.numeric(gsub("[^0-9.]", "", x)))
  out[!grepl("[0-9]", x)] <- NA_real_
  out
}

# sample size. A range is its MIDPOINT; thousands separators (comma, space, NBSP,
# thin space) must not split a number; "~800" is 800; ANYTHING ELSE is NA, so the
# digits of two numbers can never be glued together.
num_tok <- "(?:\\d{1,3}(?:[, ]\\d{3})+|\\d+)"
sample_num <- function(x) {
  vapply(x, function(v) {
    if (is.na(v)) return(NA_real_)
    v <- clean_ws(strip_fn(v))
    v <- gsub("\\s*\\([^)]*\\)\\s*", " ", v)              # drop "(online)" style asides
    v <- gsub(dash_re, "-", v)
    v <- trimws(sub("^(~|c\\.|ca\\.|approx\\.?|circa|n\\s*=|about)\\s*", "", v, ignore.case = TRUE))
    m <- regmatches(v, regexec(sprintf("^(%s)(?:\\s*-\\s*(%s))?$", num_tok, num_tok), v, perl = TRUE))[[1]]
    if (!length(m)) return(NA_real_)
    one <- function(s) as.numeric(gsub("[, ]", "", s))
    a <- one(m[2])
    if (length(m) >= 3 && nzchar(m[3])) mean(c(a, one(m[3]))) else a
  }, numeric(1), USE.NAMES = FALSE)
}

month_idx <- c(jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6, jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12)
# Returns list(start, end, year_given, exact). Dates are returned as Date; when the
# string carries no year, the year is left NA and start/end are NA (the caller resolves
# it from neighbouring rows and passes the pieces back through `ymd_parts`).
parse_dates <- function(s) {
  na <- list(start = as.Date(NA), end = as.Date(NA), year_given = FALSE, parts = NULL)
  if (is.na(s)) return(na)
  s <- clean_ws(strip_fn(s))
  if (!nzchar(s)) return(na)
  s <- gsub(dash_re, "-", s)
  s <- gsub("\\s+to\\s+", "-", s)
  s <- gsub("\\bMac\\b", "Mar", s)   # typo on the fed2025 page ("21 Mac 2023")
  # "Early/Mid/Late May 2019" -> 5th / 15th / 25th (do not split on its hyphen).
  th <- regmatches(s, regexec("^(early|mid|late)[- ]+(?:to[- ]+)?(?:(?:early|mid|late)[- ]+)?([A-Za-z]+)\\.? +(\\d{4})", s, ignore.case = TRUE))[[1]]
  if (length(th) == 4) {
    mo <- month_idx[tolower(substr(th[3], 1, 3))]
    if (!is.na(mo)) {
      d <- as.Date(sprintf("%s-%02d-%02d", th[4], mo, c(early = 5, mid = 15, late = 25)[[tolower(th[2])]]))
      return(list(start = d, end = d, year_given = TRUE, parts = NULL))
    }
  }
  # "Oct-Dec 2012" / "Jan-Mar 2010": Newspoll's quarterly aggregate, two months and no day. It
  # spans the whole quarter (first of month 1 to last of month 2), not "mid-December".
  # "Nov 2016-Jan 2017" (across a year boundary) carries its own first year; otherwise both months share the last.
  qm <- regmatches(s, regexec("^([A-Za-z]{3,9})\\.? *(?:(\\d{4}) *)?- *([A-Za-z]{3,9})\\.? +(\\d{4})$", s))[[1]]
  if (length(qm) == 5) {
    m1 <- month_idx[tolower(substr(qm[2], 1, 3))]; m2 <- month_idx[tolower(substr(qm[4], 1, 3))]
    y1 <- if (nzchar(qm[3])) qm[3] else qm[5]
    if (!is.na(m1) && !is.na(m2)) {
      st <- as.Date(sprintf("%s-%02d-01", y1, m1))
      en <- seq(as.Date(sprintf("%s-%02d-01", qm[5], m2)), by = "month", length.out = 2)[2] - 1
      if (en >= st) return(list(start = st, end = en, year_given = TRUE, parts = NULL))
    }
  }
  tok <- gregexpr("(?i)\\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\b|\\b\\d{4}\\b|\\b\\d{1,2}(?:st|nd|rd|th)?\\b", s, perl = TRUE)
  tk <- regmatches(s, tok)[[1]]
  if (!length(tk)) return(na)
  days <- integer(0); mons <- integer(0); yrs <- integer(0)   # one entry per date
  last_year <- NA_integer_  # most recent 4-digit year token, for a month-only date ("March 2021")
  pend <- integer(0)        # days still waiting for a month (day-first: "1-3 Mar")
  open_month <- NA_integer_ # month seen before its days (month-first: "Feb 3-10")
  open_used <- TRUE
  for (t in tk) {
    if (grepl("^\\d{4}$", t)) {
      yrs[is.na(yrs)] <- as.integer(t)
      last_year <- as.integer(t)
    } else if (grepl("^[A-Za-z]", t)) {
      mo <- month_idx[tolower(substr(t, 1, 3))]
      if (is.na(mo)) next
      if (length(pend)) { mons[pend] <- as.integer(mo); pend <- integer(0); open_month <- NA_integer_; open_used <- TRUE }
      else { open_month <- as.integer(mo); open_used <- FALSE }
    } else {
      d <- as.integer(sub("\\D+$", "", t))
      if (d < 1 || d > 31) next
      days <- c(days, d); yrs <- c(yrs, NA_integer_)
      if (is.na(open_month)) { mons <- c(mons, NA_integer_); pend <- c(pend, length(days)) }
      else { mons <- c(mons, open_month); open_used <- TRUE }
    }
  }
  # "Mar 2022": mid-month. The year token came AFTER the month, so it must be carried over here:
  # appended as NA, "March 2021" was year-less and was inferred into 2019 (nsw2023 page, 2026-10-11).
  if (!open_used) { days <- c(days, 15L); mons <- c(mons, open_month); yrs <- c(yrs, last_year) }
  if (!length(days) || anyNA(mons)) return(na)
  list(start = as.Date(NA), end = as.Date(NA), year_given = !anyNA(yrs),
       parts = list(d = days, m = mons, y = yrs))
}
# Turn parts into start/end Dates given a (possibly NA) default year for year-less dates.
resolve_dates <- function(parts, default_year = NA_integer_) {
  y <- parts$y; y[is.na(y)] <- default_year
  if (anyNA(y)) return(list(start = as.Date(NA), end = as.Date(NA)))
  mk <- function(i) tryCatch(as.Date(sprintf("%04d-%02d-%02d", y[i], parts$m[i], parts$d[i]), format = "%Y-%m-%d"), error = function(e) as.Date(NA))
  n <- length(y)
  st <- mk(1); en <- mk(n)
  # "28 Dec - 3 Jan 2022": the start belongs to the year before.
  if (!is.na(st) && !is.na(en) && st > en) { y[1] <- y[1] - 1L; st <- mk(1) }
  list(start = st, end = en)
}

# ---- self-tests: known inputs, known answers (fail the script if a parser regresses) ----
local({
  d <- function(x, dflt = NA_integer_) { p <- parse_dates(x); if (is.null(p$parts)) c(p$start, p$end) else { r <- resolve_dates(p$parts, dflt); c(r$start, r$end) } }
  chk <- function(x, s, e, dflt = NA_integer_) { r <- d(x, dflt); stopifnot(identical(as.character(r), c(s, e))) }
  chk("1-3 Mar 2022", "2022-03-01", "2022-03-03")
  chk("1–3 Mar 2022", "2022-03-01", "2022-03-03")
  chk("22−23 Jun 2016", "2016-06-22", "2016-06-23")
  chk("28 Feb - 3 Mar 2022", "2022-02-28", "2022-03-03")
  chk("28 Dec 2021 – 3 Jan 2022", "2021-12-28", "2022-01-03")
  chk("28 Dec–3 Jan 2022", "2021-12-28", "2022-01-03")
  chk("Early May 2019", "2019-05-05", "2019-05-05")
  chk("Mid-May 2019", "2019-05-15", "2019-05-15")
  chk("Late May 2019", "2019-05-25", "2019-05-25")
  chk("17, 21 March 2022", "2022-03-17", "2022-03-21")
  chk("11–12, 18–19 Dec 2021", "2021-12-11", "2021-12-19")
  chk("27–28 Nov, 4–5 Dec 2021", "2021-11-27", "2021-12-05")
  chk("Feb 3–10 2026", "2026-02-03", "2026-02-10")
  chk("30 Mar – Apr 5 2026", "2026-03-30", "2026-04-05")
  chk("March 2021", "2021-03-15", "2021-03-15")                 # was read as year-less and inferred into 2019
  chk("Mar 2022", "2022-03-15", "2022-03-15")
  chk("Oct–Dec 2012", "2012-10-01", "2012-12-31")
  chk("Jan-Mar 2010", "2010-01-01", "2010-03-31")
  chk("2 – 4 Sep 2008", "2008-09-02", "2008-09-04")
  chk("24–28 Sep", "2026-09-24", "2026-09-28", 2026L)
  stopifnot(is.na(d("24–28 Sep")[1]))                       # no year, no default -> NA, not a guess
  stopifnot(identical(sample_num(c("1,000", "1000–1500", "1,000-1,500", "~800", "4 909", "4 909", "1 000",
                                   "800 1000", "N/a", "—", "12", "1,200 (online)", "2,000+", "n/a", NA)),
                      c(1000, 1250, 1250, 800, 4909, 4909, 1000, NA, NA, NA, 12, 1200, NA, NA, NA)))
})

# ---- one table ---------------------------------------------------------------
role_of <- function(g) {
  g <- tolower(g)
  if (grepl("^date", g)) "date"
  else if (grepl("firm|pollster|^brand$|polling", g)) "firm"
  else if (grepl("^client|commission", g)) "client"
  else if (grepl("sample", g)) "sample"
  else if (grepl("interview|^mode", g)) "mode"
  else if (grepl("^seat$|electorate|division", g)) "seat"
  else if (grepl("primary|political part", g)) "pv"
  else if (grepl("2pp|tpp|2cp|tcp|two.party|two.candidate", g)) "tpp"
  else "other"
}
# Pollster (or commissioning outlet) names looked for where a table has no firm column (2026-10-13). The
# first one found in the text wins; NA when there is none. Used only for tables the older fallbacks
# (footer, "Source:" row) did not name, so it never touches a page that has a firm column.
firm_names <- c("Newspoll", "Roy Morgan", "Morgan Poll", "ReachTEL", "EMRS", "uComms", "MediaReach", "Galaxy", "Lonergan",
                "Redbridge", "Resolve", "YouGov", "Ipsos", "Essential", "Auspoll", "Fieldworks", "JWS Research", "Painted Dog",
                "DemosAU", "Compass", "Utting", "ACNielsen", "Nielsen", "Westpoll", "Patterson Research", "Colmar Brunton",
                "Dynata", "Omnipoll", "Statistica", "Insightfully", "Quantum", "Spectre", "Territory Insights", "Market Facts",
                "Mackerras", "NT News", "Northern Territory News", "Canberra Times", "Hobart Mercury", "Mercury")
firm_names_re <- paste0("\\b(?:", paste(gsub(" ", "\\\\s+", firm_names), collapse = "|"), ")\\b")
find_firm <- function(x) {
  if (length(x) != 1L || is.na(x) || !nzchar(x)) return(NA_character_)
  m <- regmatches(x, regexpr(firm_names_re, x, perl = TRUE))
  if (length(m)) clean_ws(m) else NA_character_
}
stopifnot(identical(find_firm("South Australian state voting intention (Roy Morgan)"), "Roy Morgan"),
          identical(find_firm("House of Assembly (lower house) polling"), NA_character_),
          identical(find_firm("Newspoll polling was conducted via random telephone"), "Newspoll"))
# The all-elections extension (2026-10-13) changed two rules, and both apply to every page. On the 34 pages parsed
# before it: fed2010_opinion table 4 gains 4 Roy Morgan polls (blank-first-header-cell rule), and 66 seat or
# sub-state rows are retyped "seat" (wiki_polls() already dropped them by section name, so no poll reaching the
# trend changed). Checked by diffing both outputs; deciding-runs/statewide_polls_wiki-frozen.csv is the before copy.
coalition_names <- c("L/NP", "LNP", "Coalition", "L/NP*", "LIB/NAT", "LIB+NAT", "C")
# Every table's fate is logged in tbl_log: outcome is "parsed", a DELIBERATE refusal ("refused_nonvoting",
# "skipped_small", "no_date_header") or a LOSS ("lost", "parse_error"). The run fails at the end on any loss.
tbl_log <- list()
note_tbl <- function(page_key, tidx, outcome, detail = "") {
  tbl_log[[length(tbl_log) + 1L]] <<- data.table(page_key = page_key, table_idx = tidx, outcome = outcome, detail = detail)
}
# Independent of parse_poll_table: does this table have a date-like header cell (a "Date" cell in
# the first four rows, or the blank-first-cell "Primary vote / TPP vote" group row)?
has_date_header <- function(tab) {
  raw <- tryCatch(html_table(tab, header = FALSE, fill = TRUE), error = function(e) NULL)
  if (is.null(raw)) return(NA)
  for (r in seq_len(min(4L, nrow(raw)))) {
    cl <- clean_ws(strip_fn(as.character(unlist(raw[r, ]))))
    if (any(grepl("^dates?$", cl, ignore.case = TRUE))) return(TRUE)
    if (length(cl) && !nzchar(cl[1]) && any(grepl("^(primary vote|2pp vote|tpp vote)", cl, ignore.case = TRUE))) return(TRUE)
  }
  FALSE
}
parse_poll_table <- function(tab, page_key, region, election, kind, url, tidx, section) {
  refuse <- function(outcome, detail = "") { note_tbl(page_key, tidx, outcome, detail); NULL }
  raw <- tryCatch(html_table(tab, header = FALSE, fill = TRUE), error = function(e) NULL)
  if (is.null(raw)) return(refuse("parse_error", "html_table failed"))
  if (nrow(raw) < 2 || ncol(raw) < 3) return(refuse("skipped_small", sprintf("%d x %d", nrow(raw), ncol(raw))))
  raw <- as.data.frame(lapply(raw, function(x) clean_ws(as.character(x))), stringsAsFactors = FALSE)
  raw[is.na(raw)] <- ""
  names(raw) <- paste0("V", seq_len(ncol(raw)))
  # header rows: leading rows whose first date-looking column says "Date"
  # (some pages open with a blank spacer row; the sub-header rows can have a blank date cell)
  is_hdr <- function(r) any(grepl("^dates?$", strip_fn(as.character(raw[r, ])), ignore.case = TRUE))
  r0 <- NA_integer_
  for (r in seq_len(min(4L, nrow(raw)))) if (is_hdr(r)) { r0 <- r; break }
  # Older Newspoll tables (wa2013, sa2010, sa2014) have NO "Date" header: the first column's
  # header cells are blank and the group row reads "Primary vote | TPP vote". Name that column
  # "Date" so the rest of the parser treats it like any other table.
  if (is.na(r0)) {
    for (r in seq_len(min(4L, nrow(raw)))) {
      cl <- strip_fn(as.character(raw[r, ]))
      if (!nzchar(cl[1]) && any(grepl("^(primary vote|2pp vote|tpp vote)", cl, ignore.case = TRUE))) {
        raw[r, 1] <- "Date"; r0 <- r; break
      }
    }
  }
  # Older / Tasmanian layouts (added 2026-10-13): the date column has NO header text at all. The first header
  # cell is blank and the row names a column group other than "Primary vote" ("Political parties" on the
  # Tasmanian pages, "Firm" on tas2018/tas2021). It is a poll table only if its first column then holds
  # month-year dates, so a results / pendulum / preferred-premier table (no such group row, no dates) still
  # falls through to the refusal below.
  if (is.na(r0)) {
    grp_re <-"^(political part|two.party|firm$|pollster)"
    for (r in seq_len(min(4L, nrow(raw)))) {
      cl <- strip_fn(as.character(raw[r, ]))
      if (r >= nrow(raw) || nzchar(cl[1]) || !any(grepl(grp_re, cl, ignore.case = TRUE))) next
      below <- strip_fn(raw[seq.int(r + 1L, nrow(raw)), 1])
      if (sum(grepl("[A-Za-z]{3,9}\\.? *(19|20)[0-9]{2}", below)) >= 2L) { raw[r, 1] <- "Date"; r0 <- r; break }
    }
  }
  if (is.na(r0)) {
    # A refusal always says why (found 2026-10-13: a bare "no_date_header" hid whether a table was a poll).
    cap0 <- tryCatch(clean_ws(html_text2(html_element(tab, "caption"))), error = function(e) "")
    if (length(cap0) != 1L || is.na(cap0)) cap0 <- ""
    hdr_txt <- paste(unlist(raw[seq_len(min(3L, nrow(raw))), ]), collapse = " ")
    why <- if (grepl("votes|seats|swing|margin|member|pendulum|endorse|electorate|party|candidate|affiliation", hdr_txt, ignore.case = TRUE) &&
               !grepl("primary vote|2pp|tpp|political part", hdr_txt, ignore.case = TRUE))
             "election result, seat, pendulum or endorsement table: not a poll"
           else if (grepl("prefer|better|approval|satisf|leader|net", paste(cap0, section, hdr_txt), ignore.case = TRUE))
             "leader preference / approval table: no voting intention"
           else "no Date header cell and no party-group header row above a month-year date column: not a voting-intention poll table"
    return(refuse("no_date_header", why))
  }
  # wa2008: the "Date" label sits on the PARTY row and the "Primary vote | 2PP vote" group row is
  # above it with a blank first cell. Promote the group row to be the header (Date is relabelled).
  if (r0 > 1L) {
    pr <- strip_fn(as.character(raw[r0 - 1L, ]))
    # (the "political part|two party" group labels of the Tasmanian / Queensland 2009 layouts were added 2026-10-13)
    if (!nzchar(pr[1]) && any(grepl("^(primary vote|2pp vote|tpp vote|political part|two party)", pr, ignore.case = TRUE))) {
      raw[r0 - 1L, 1] <- "Date"; r0 <- r0 - 1L
    }
  }
  dcol <- which(grepl("^dates?$", strip_fn(as.character(raw[r0, ])), ignore.case = TRUE))[1]
  dstart <- r0 + 1L     # first data row = first row whose date cell holds a digit or the word "election"
  while (dstart <= nrow(raw) && !grepl("[0-9]|election", raw[dstart, dcol], ignore.case = TRUE)) dstart <- dstart + 1L
  if (dstart > nrow(raw)) return(refuse("lost", "date header but no data row"))
  nh <- dstart - r0
  hdr <- lapply(r0:(dstart - 1L), function(r) strip_fn(as.character(raw[r, ])))
  g <- hdr[[1]]
  sub_of <- function(j) { v <- vapply(hdr[-1], function(h) h[j], ""); v <- v[nzchar(v) & v != g[j]]; if (length(v)) v[1] else "" }
  s <- if (nh > 1) vapply(seq_along(g), sub_of, "") else rep("", length(g))
  # A blank group label over a column that has a party sub-label (vic2018: the Coalition columns sit
  # under an empty cell next to "Primary vote") takes the label of the next group to its right.
  for (j in seq_along(g)) if (!nzchar(g[j]) && nzchar(s[j])) {
    k <- which(seq_along(g) > j & nzchar(g))[1]
    if (!is.na(k) && role_of(g[k]) == "pv") g[j] <- g[k]
  }
  roles <- vapply(g, role_of, "")
  # No firm column (fed2010 Newspoll table, wa2008, wa2013, sa2010, sa2014): the table's last row is a
  # footer "Polling conducted by Newspoll and published in The Australian". That names the firm for
  # every row; firm_from records that it came from the footer, not a column.
  firm_default <- NA_character_
  if (!"firm" %in% roles) {
    tail_txt <- unlist(raw[max(1L, nrow(raw) - 2L):nrow(raw), ], use.names = FALSE)
    mm <- regmatches(tail_txt, regexec("[Pp]olling (?:was )?conducted by ([A-Za-z][A-Za-z&' -]*?)(?: and | for |,|\\.|$)", tail_txt, perl = TRUE))
    mm <- Filter(function(x) length(x) == 2, mm)
    if (length(mm)) firm_default <- trimws(mm[[1]][2])
  }
  firm_default_from <- "table_footer"
  # Older pages (added 2026-10-13) name the pollster elsewhere than a column or a "Polling conducted by" footer.
  # Tried in order, the table's own text first: a "Source: Newspoll/The Australian" row, a caption such as
  # "(Roy Morgan)", the paragraph just above the table. A per-row footnote naming the pollster is the last
  # resort and is applied row by row below.
  if (!"firm" %in% roles && is.na(firm_default)) {
    tail_cells <- strip_fn(unlist(raw[max(1L, nrow(raw) - 2L):nrow(raw), ], use.names = FALSE))
    src <- sub("^Source:?\\s*", "", tail_cells[grepl("^Source:?\\s*\\S", tail_cells)])
    if (length(src)) {
      firm_default <- trimws(strsplit(src[1], "\\s*/\\s*|\\s+and\\s+|\\s+[–—-]\\s+|\\s*[¹²³]", perl = TRUE)[[1]][1]); firm_default_from <- "table_source_row"   # "Roy Morgan Research – ¹ Post-election ..." is a legend, not the firm; firm_default_from <- "table_source_row"
    }
  }
  if (!"firm" %in% roles && is.na(firm_default)) {
    cap_f <- tryCatch(clean_ws(strip_fn(html_text2(html_element(tab, "caption")))), error = function(e) NA_character_)
    kf <- find_firm(cap_f)
    if (!is.na(kf)) { firm_default <- kf; firm_default_from <- "table_caption" }
  }
  if (!"firm" %in% roles && is.na(firm_default)) {
    prev_p <- xml_find_all(tab, "preceding-sibling::*[position()<=2]")
    prev_p <- prev_p[xml_name(prev_p) == "p"]
    kf <- if (length(prev_p)) find_firm(clean_ws(strip_fn(html_text2(prev_p[[length(prev_p)]])))) else NA_character_
    if (!is.na(kf)) { firm_default <- kf; firm_default_from <- "preceding_paragraph" }
  }
  if (!"date" %in% roles) return(refuse("lost", "date header but no date role"))
  firm_unstated <- FALSE
  if (!"firm" %in% roles && is.na(firm_default)) {
    # A ratings/approval table is not a poll of voting intention. A voting-intention table whose pollster the
    # page never names IS a poll: kept, with firm NA and firm_from "not_stated" (rows may still pick the pollster
    # from their own footnote below). Before 2026-10-13 this was a hard "lost" that stopped the run.
    if (!any(roles %in% c("pv", "tpp"))) return(refuse("refused_nonvoting", "no firm column or footer; no primary/2PP columns"))
    firm_unstated <- TRUE
  }
  roles[duplicated(roles) & roles %in% c("date", "firm", "client", "sample", "mode", "seat")] <- "other"
  col_date <- which(roles == "date")[1]; col_firm <- which(roles == "firm")[1]
  col_cli <- which(roles == "client")[1]; col_smp <- which(roles == "sample")[1]
  col_mode <- which(roles == "mode")[1]; col_seat <- which(roles == "seat")[1]
  has_pv <- any(roles == "pv"); has_tpp <- any(roles == "tpp")
  table_type <- if (!is.na(col_seat)) "seat" else if (has_pv) "primary" else if (has_tpp) "tpp_only" else "other"
  # A seat-by-seat or region-by-region table (NT 2016 has seven, under "By region") is sub-state, never statewide:
  # typed "seat" so the statewide join cannot pick it up, whatever columns it carries.
  cap_s <- tryCatch(clean_ws(html_text2(html_element(tab, "caption"))), error = function(e) "")
  if (table_type %in% c("primary", "tpp_only") &&
      grepl("by region|regional|by seat|seat polling|by electorate|electorate polling|seat-by-seat", paste(section, cap_s), ignore.case = TRUE))
    table_type <- "seat"
  # name the party / value columns
  cname <- function(j) {
    lab <- if (nzchar(s[j])) s[j] else g[j]
    lab <- trimws(gsub("[*†]+", "", gsub("\\s+", " ", lab)))
    switch(roles[j], pv = paste0("pv_", lab), tpp = paste0("tpp_", lab),
           other = paste0("x_", gsub("[^A-Za-z0-9]+", "_", paste(g[j], s[j]))), NULL)
  }
  val_cols <- which(roles %in% c("pv", "tpp", "other"))
  nms <- vapply(val_cols, function(j) { x <- cname(j); if (is.null(x)) "" else x }, "")
  nms <- make.unique(nms, sep = "_")
  data <- raw[dstart:nrow(raw), , drop = FALSE]
  if (!nrow(data)) return(refuse("lost", "no data rows"))
  rows <- list()
  for (i in seq_len(nrow(data))) {
    cells <- as.character(data[i, ])
    dt_v <- cells[col_date]; fm_v <- if (is.na(col_firm)) firm_default else cells[col_firm]
    ff <- if (is.na(col_firm)) firm_default_from else "column"
    if (firm_unstated) {
      rf <- find_firm(paste(cells, collapse = " "))   # the date cell too: that is where the row's footnote usually sits
      if (!is.na(rf)) { fm_v <- rf; ff <- "row_footnote" } else ff <- "not_stated"
    }
    nonblank <- cells[-col_date][nzchar(cells[-col_date])]
    # spacer / year separator / dated EVENT row ("Albanese replaces Shorten": one cell spanning
    # every column but the date): everything except the date is one repeated string or blank.
    if (!nzchar(dt_v) || length(unique(nonblank)) <= 1) next
    if (!grepl("[0-9]", dt_v)) next
    # Tested on the cell text WITHOUT its footnotes: a footnote such as "conducted ahead of the 2013 federal
    # election" sits inside the firm cell, and testing the raw text typed 658 real polls (final-week Morgan,
    # ReachTEL, Newspoll, Galaxy ...) as election results, which the loader then dropped (found 2026-10-13 by
    # scripts/audit_ae_missing.R).
    row_type <- if (grepl("election", strip_fn(fm_v), ignore.case = TRUE) || grepl("election", strip_fn(dt_v), ignore.case = TRUE) ||
                    any(grepl("^(20|19)[0-9]{2} election$", strip_fn(cells)))) "result" else "poll"
    # a footnote number typed straight after the year ("27–29 Jul 20161") is not part of the year
    pdts <- parse_dates(sub("([A-Za-z]\\.? *(?:19|20)[0-9]{2})[0-9]{1,2}$", "\\1", dt_v, perl = TRUE))
    r <- data.table(
      page_key = page_key, region = region, election = election, page_kind = kind, source_url = url,
      table_idx = tidx, section = section, table_type = table_type, row_in_table = i, row_type = row_type,
      date_raw = strip_fn(dt_v), firm_raw = strip_fn(fm_v),
      firm_from = ff,
      firm = trimws(gsub("\\s*\\[[^]]*\\]", "", strip_fn(fm_v))),
      client_raw = if (!is.na(col_cli)) strip_fn(cells[col_cli]) else NA_character_,
      sample_raw = if (!is.na(col_smp)) strip_fn(cells[col_smp]) else NA_character_,
      mode_raw = if (!is.na(col_mode)) strip_fn(cells[col_mode]) else NA_character_,
      seat_raw = if (!is.na(col_seat)) strip_fn(cells[col_seat]) else NA_character_,
      footnote_raw = get_fn(paste(cells, collapse = " "))
    )
    # footnote that names a sponsor ("Commissioned by ...")
    fn <- r$footnote_raw
    r[, client_fn := if (!is.na(fn) && grepl("commissioned (by|for)", fn, ignore.case = TRUE))
        trimws(sub("[.;|](\\s.*)?$", "", sub("^.*?commissioned (by|for)\\s+(the\\s+)?", "", fn, ignore.case = TRUE, perl = TRUE))) else NA_character_]
    for (k in seq_along(val_cols)) set(r, j = nms[k], value = strip_fn(cells[val_cols[k]]))
    r[, `:=`(.parts = list(pdts$parts), .year_given = pdts$year_given)]
    rows[[length(rows) + 1]] <- r
  }
  if (!length(rows)) return(refuse("lost", "no row survived the spacer/event filters"))
  out <- rbindlist(rows, fill = TRUE)
  note_tbl(page_key, tidx, "parsed",
           if (firm_unstated) sprintf("pollster not named in the table: %d of %d rows from their own footnote, the rest firm_from = not_stated",
                                      sum(out$firm_from == "row_footnote"), nrow(out)) else "")
  out
}

# ---- self-test of the table shapes added 2026-10-11 (known table in, known rows out) ------
# (a) wa2013/sa2010/sa2014: no "Date" header, no firm column, firm named only by the footer row.
# (b) wa2008: "Date" sits on the party row, the "Primary vote | 2PP vote" group row is above it.
# (c) the same table with the footer removed has no firm anywhere and MUST be refused -- a
#     table that named no firm would otherwise enter the file with a blank firm.
local({
  tr <- function(...) paste0("<tr>", paste0("<td>", c(...), "</td>", collapse = ""), "</tr>")
  tbl <- function(rows) rvest::html_element(rvest::minimal_html(paste0("<table>", paste(rows, collapse = ""), "</table>")), "table")
  foot <- tr(rep("Polling conducted by Newspoll and published in The Australian.", 6))
  body <- c(tr("2013 election", "47.1%", "33.1%", "57.3%", "42.7%"),
            tr("4–7 Mar 2013", "48%", "32%", "59.5%", "40.5%"),
            tr("Oct–Dec 2012", "43%", "30%", "58%", "42%"))
  hdr_a <- c(tr("", "Primary vote", "Primary vote", "TPP vote", "TPP vote"), tr("", "Lib", "ALP", "Lib/Nat", "ALP"))
  hdr_b <- c(tr("", "Primary vote", "Primary vote", "2PP vote", "2PP vote"), tr("Date", "Lib", "ALP", "Lib/Nat", "ALP"))
  go <- function(rows) parse_poll_table(tbl(rows), "t_a", "wa", "wa2013", "main", "u", 1L, "Polling")
  a <- go(c(hdr_a, body, foot))
  stopifnot(!is.null(a), nrow(a) == 3, all(a$firm == "Newspoll"), all(a$firm_from == "table_footer"),
            identical(a$row_type, c("result", "poll", "poll")), a$table_type[1] == "primary")
  b <- go(c(hdr_b, body, foot))
  stopifnot(!is.null(b), nrow(b) == 3, identical(b$row_type, c("result", "poll", "poll")), b$table_type[1] == "primary")
  # no footer, no firm anywhere: since 2026-10-13 the poll is KEPT (it is a poll) but flagged, never given a firm
  stopifnot(!is.null(go(c(hdr_a, body))), all(is.na(go(c(hdr_a, body))$firm)), all(go(c(hdr_a, body))$firm_from == "not_stated"),
            !is.null(go(c(hdr_b, body))), all(go(c(hdr_b, body))$firm_from == "not_stated"))
  # a "Source:" row names the firm (vic2006 / sa2006 layout) and a caption "(Roy Morgan)" names it for a table with neither
  src_row <- tr(rep("Source: Newspoll/The Australian", 6))
  stopifnot(all(go(c(hdr_a, body, src_row))$firm == "Newspoll"), all(go(c(hdr_a, body, src_row))$firm_from == "table_source_row"))
  cap_tbl <- rvest::html_element(rvest::minimal_html(paste0("<table><caption>State voting intention (Roy Morgan)</caption>",
                                                            paste(c(hdr_a, body), collapse = ""), "</table>")), "table")
  cp <- parse_poll_table(cap_tbl, "t_c", "wa", "wa2013", "main", "u", 1L, "Polling")
  stopifnot(all(cp$firm == "Roy Morgan"), all(cp$firm_from == "table_caption"))
})

# Pages that resolve to the same canonical article (a "state election" opinion title that
# redirects to the main article) are parsed once, so no poll is double counted.
pages[, canon := NA_character_]
for (i in which(pages$status == "on_disk")) {
  txt <- paste(readLines(file.path(raw_dir, paste0(pages$page_key[i], ".html")), n = 400, warn = FALSE), collapse = "
")
  m <- regmatches(txt, regexec('<link rel="canonical" href="([^"]+)"', txt))[[1]]
  pages$canon[i] <- if (length(m) == 2) sub("#.*$", "", m[2]) else NA_character_
}
dup <- !is.na(pages$canon) & duplicated(pages$canon)
for (i in which(dup)) pages$status[i] <- paste0("duplicate_of_", pages$page_key[match(pages$canon[i], pages$canon)])

# ---- parse every downloaded page --------------------------------------------
all_pages <- list()
pages[, `:=`(n_tables = NA_integer_, n_tables_parsed = NA_integer_, n_poll_rows = NA_integer_, n_datelike = NA_integer_)]
tbl_log <- list()   # drop the self-test tables logged above
for (i in seq_len(nrow(pages))) {
  f <- file.path(raw_dir, paste0(pages$page_key[i], ".html"))
  if (pages$status[i] != "on_disk") next
  page <- tryCatch(read_html(f), error = function(e) { message("PARSE ERROR ", pages$page_key[i], ": ", conditionMessage(e)); NULL })
  if (is.null(page)) { pages$status[i] <- "parse_error"; next }
  # Footnote markers: replace each with a {{FN:note text}} token so the sponsor
  # ("Commissioned by ...") and any caveat on the row survive in footnote_raw.
  notes <- html_elements(page, "span.mw-reference-text")
  note_txt <- setNames(clean_ws(html_text2(notes)), sub("^mw-reference-text-", "", xml_attr(notes, "id")))
  sups <- html_elements(page, "sup.reference")
  if (length(sups)) {
    sup_note <- sub("^.*#", "", xml_attr(html_element(sups, "a"), "href"))
    sup_txt  <- unname(note_txt[sup_note])
    for (k in seq_along(sups)) {
      tx <- if (is.na(sup_txt[k])) "" else gsub("[{}]", "", sup_txt[k])
      xml_add_sibling(sups[[k]], "span", paste0(" {{FN:", tx, "}}"))
    }
    xml_remove(sups)
  }
  xml_remove(html_elements(page, "style, script, .sr-only"))
  nodes <- html_elements(page, "h2, h3, h4, table.wikitable, table.toccolours")
  nm <- html_name(nodes)
  hd <- c(h2 = "", h3 = "", h4 = "")
  sec <- character(0)
  for (k in seq_along(nodes)) {
    if (nm[k] %in% c("h2", "h3", "h4")) {
      lv <- nm[k]; hd[[lv]] <- trimws(gsub("\\[edit\\]", "", html_text2(nodes[[k]])))
      if (lv == "h2") hd[c("h3", "h4")] <- ""
      if (lv == "h3") hd[["h4"]] <- ""
    } else sec <- c(sec, paste(hd[hd != ""], collapse = " > "))
  }
  tabs <- nodes[nm == "table"]
  parsed <- lapply(seq_along(tabs), function(t)
    tryCatch(parse_poll_table(tabs[[t]], pages$page_key[i], pages$region[i], pages$election[i], pages$kind[i], pages$url[i], t, sec[t]),
             error = function(e) {
               message("  table ", t, " of ", pages$page_key[i], " failed: ", conditionMessage(e))
               note_tbl(pages$page_key[i], t, "parse_error", conditionMessage(e)); NULL }))
  pages$n_tables[i] <- length(tabs)
  # Completeness: every table with a date-like header must have an outcome logged, parsed or refused.
  dl <- which(vapply(tabs, function(tb) isTRUE(has_date_header(tb)), logical(1)))
  logged <- Filter(function(x) x$page_key == pages$page_key[i], tbl_log)
  logged_idx <- vapply(logged, function(x) x$table_idx, 0L)
  unlogged <- setdiff(dl, logged_idx)
  for (t in unlogged) note_tbl(pages$page_key[i], t, "lost", "date-like header but no outcome recorded")
  pages$n_datelike[i] <- length(dl)
  ok <- !vapply(parsed, is.null, logical(1))
  pages$n_tables_parsed[i] <- sum(ok)
  if (any(ok)) {
    d <- rbindlist(parsed[ok], fill = TRUE)
    pages$n_poll_rows[i] <- sum(d$row_type == "poll")
    all_pages[[length(all_pages) + 1]] <- d
  } else pages$n_poll_rows[i] <- 0L
  message(sprintf("%-18s tables %2d, with poll columns %2d, poll rows %d", pages$page_key[i], length(tabs), sum(ok), pages$n_poll_rows[i]))
}
wiki <- rbindlist(all_pages, fill = TRUE)
stopifnot(nrow(wiki) > 0)

# ---- dates: resolve year-less rows from the row/table below them ----------------
# Tables run newest-first. A row with no year takes the smallest year that puts it
# no more than 30 days before the next-older dated row; the newest table (often
# year-less for the election year) is anchored on the first dated row of the next
# table of the same type on the page.
wiki[, `:=`(fieldwork_start = as.Date(NA), fieldwork_end = as.Date(NA), year_inferred = FALSE)]
setorder(wiki, page_key, table_idx, row_in_table)
for (pk in unique(wiki$page_key)) {
  idx_page <- which(wiki$page_key == pk)
  tabs_here <- unique(wiki$table_idx[idx_page])
  # pass 1: rows whose dates carry a year
  for (r in idx_page) {
    p <- wiki$.parts[[r]]
    if (!is.null(p) && wiki$.year_given[r]) {
      d <- resolve_dates(p)
      set(wiki, r, "fieldwork_start", d$start); set(wiki, r, "fieldwork_end", d$end)
    } else if (is.null(p)) {   # early/mid/late
      d <- parse_dates(wiki$date_raw[r])
      set(wiki, r, "fieldwork_start", d$start); set(wiki, r, "fieldwork_end", d$end)
    }
  }
  # pass 2: year-less rows, bottom-up within each table
  for (ti in rev(tabs_here)) {
    idx <- idx_page[wiki$table_idx[idx_page] == ti]
    ttype <- wiki$table_type[idx[1]]
    ref <- as.Date(NA)
    later <- tabs_here[tabs_here > ti]
    for (tj in later) {
      ij <- idx_page[wiki$table_idx[idx_page] == tj & wiki$table_type[idx_page] == ttype & !is.na(wiki$fieldwork_end[idx_page])]
      if (length(ij)) { ref <- wiki$fieldwork_end[ij[1]]; break }
    }
    for (r in rev(idx)) {
      p <- wiki$.parts[[r]]
      if (is.na(wiki$fieldwork_end[r]) && !is.null(p) && !wiki$.year_given[r]) {
        # The table sits under a year heading ("Voting intention > 2025"): that year is the answer.
        # (Before this, fed2028's 2025 table was inferred into 2027 from the 2026 table's dates,
        # which tripped STAT6 -- 39 rows, 2026-10-11.)
        sy <- regmatches(wiki$section[r], regexec("(?:^|[ >])((?:19|20)[0-9]{2})$", wiki$section[r]))[[1]]
        if (length(sy) == 2) {
          d <- resolve_dates(p, as.integer(sy[2]))
          set(wiki, r, "fieldwork_start", d$start); set(wiki, r, "fieldwork_end", d$end)
          set(wiki, r, "year_inferred", TRUE)
        } else if (!is.na(ref)) {
          y0 <- as.integer(format(ref, "%Y"))
          for (yy in y0 + 0:1) {
            d <- resolve_dates(p, yy)
            if (!is.na(d$end) && d$end >= ref - 30) break
          }
          set(wiki, r, "fieldwork_start", d$start); set(wiki, r, "fieldwork_end", d$end)
          set(wiki, r, "year_inferred", TRUE)
        } else {
          # Nothing dated below it: the poll cannot be later than the election (or today, for a
          # future election), so take the latest year that keeps it at or before that bound.
          ub <- min(elec_dates$election_date[elec_dates$election == wiki$election[r]], Sys.Date())
          yb <- as.integer(format(ub, "%Y"))
          for (yy in c(yb, yb - 1L)) {
            d <- resolve_dates(p, yy)
            if (!is.na(d$end) && d$end <= ub + 30) break
          }
          set(wiki, r, "fieldwork_start", d$start); set(wiki, r, "fieldwork_end", d$end)
          set(wiki, r, "year_inferred", TRUE)
        }
      }
      if (!is.na(wiki$fieldwork_end[r])) ref <- wiki$fieldwork_end[r]
    }
  }
}
wiki[, c(".parts", ".year_given") := NULL]

# ---- parsed numbers ---------------------------------------------------------
wiki[, sample_n := sample_num(sample_raw)]
pick <- function(d, cands, prefix) {
  # case-insensitive: the older tables say "Lib", "Nat", "Gre", the newer "LIB", "NAT"
  nn <- names(d); want <- tolower(paste0(prefix, cands))
  cols <- nn[tolower(nn) %in% want]
  cols <- cols[order(match(tolower(cols), want))]
  if (!length(cols)) return(rep(NA_real_, nrow(d)))
  m <- vapply(cols, function(cn) pct_num(d[[cn]]), numeric(nrow(d)))
  if (is.null(dim(m))) m <- matrix(m, ncol = length(cols))
  apply(m, 1, function(v) { v <- v[!is.na(v)]; if (length(v)) v[1] else NA_real_ })
}
wiki[, alp_fp := pick(.SD, c("ALP", "Labor", "ALP*"), "pv_")]
wiki[, lnp_fp := pick(.SD, c("L/NP", "LNP", "Coalition", "L/NP*"), "pv_")]
wiki[, lib_fp := pick(.SD, c("LIB", "Liberal", "LIB*"), "pv_")]
wiki[, nat_fp := pick(.SD, c("NAT", "Nationals", "NPA"), "pv_")]
wiki[, alp_tpp := pick(.SD, c("ALP", "Labor", "ALP*"), "tpp_")]
# One merged "Liberal/National" cell is echoed into both the LIB and NAT columns (vic2018 "38%*" twice):
# that is the combined Coalition figure, not a Liberal 38 plus a National 38.
if (all(c("pv_LIB", "pv_NAT") %in% names(wiki))) {
  merged <- !is.na(wiki$lib_fp) & !is.na(wiki$nat_fp) & wiki$pv_LIB == wiki$pv_NAT
  merged <- merged %in% TRUE
  wiki[, coalition_merged := merged]
  wiki[merged, nat_fp := NA_real_]
  message(sprintf("STAT6 %d rows have one merged Liberal/National cell (read as the combined Coalition figure)", sum(merged)))
}
# headline = a statewide (or national, for fed) voting-intention table: primary-vote columns, and NOT
# a sub-national / demographic / sub-state / seat / hypothetical / upper-house / leader table.
wiki[, headline := table_type == "primary" & !grepl("sub-national|subpopulation|sub-state|individual|hypothetical|leader|legislative council|consideration|electorate", section, ignore.case = TRUE)]
wiki[, client := fifelse(!is.na(client_raw) & nzchar(client_raw) & !client_raw %in% c("—", "-", "N/a", "n/a"),
                         client_raw, client_fn)]

# ---- write + report ---------------------------------------------------------
meta <- c("page_key", "region", "election", "page_kind", "source_url", "table_idx", "section", "table_type", "row_in_table", "row_type", "headline",
          "date_raw", "fieldwork_start", "fieldwork_end", "year_inferred", "firm_raw", "firm", "client_raw", "client_fn", "client",
          "sample_raw", "sample_n", "mode_raw", "seat_raw", "footnote_raw", "alp_fp", "lnp_fp", "lib_fp", "nat_fp", "alp_tpp")
setcolorder(wiki, c(meta, setdiff(names(wiki), meta)))
fwrite(wiki, out_csv)
fwrite(pages[, .(page_key, region, election, kind, title, url, status, n_tables, n_datelike, n_tables_parsed, n_poll_rows)], man_csv)
tl <- rbindlist(tbl_log, fill = TRUE)
fwrite(tl, file.path(base_dir, "table_outcomes.csv"))
# ---- LOUD FAILURES: nothing may be lost silently (written AFTER the outputs so they can be inspected) ----
nd <- tl[, .N, by = outcome]
message("TBL1 table outcomes: ", paste0(nd$outcome, "=", nd$N, collapse = ", "))
bad_tbl <- tl[outcome %in% c("lost", "parse_error")]
bad_pg  <- pages[status %in% c("fetch_failed", "parse_error")]
if (nrow(bad_tbl)) { print(bad_tbl); message("TBL2 tables LOST or errored: ", nrow(bad_tbl)) }
if (nrow(bad_pg))  { print(bad_pg[, .(page_key, status)]); message("TBL3 pages not fetched or not parsed: ", nrow(bad_pg)) }
stopifnot("a poll table was lost, a parse failed, or a page could not be fetched -- see TBL2/TBL3 above" = !nrow(bad_tbl) && !nrow(bad_pg))

message("\n---- pages ----")
print(pages[, .(page_key, status, n_tables, n_tables_parsed, n_poll_rows)], nrows = 200)
message("\nSTAT1 wrote ", nrow(wiki), " rows, ", ncol(wiki), " columns to ", out_csv)
pp <- wiki[row_type == "poll" & table_type == "primary"]
message(sprintf("STAT2 primary-vote poll rows: %d; fieldwork_end parsed %d; sample_raw non-blank %d, sample_n parsed %d",
                nrow(pp), sum(!is.na(pp$fieldwork_end)), sum(!is.na(pp$sample_raw) & nzchar(pp$sample_raw) & !pp$sample_raw %in% c("—", "-")),
                sum(!is.na(pp$sample_n))))
bad <- pp[!is.na(sample_raw) & nzchar(sample_raw) & !sample_raw %in% c("—", "-") & is.na(sample_n)]
if (nrow(bad)) { message("STAT3 sample_raw values that did NOT parse to a number (count by text):"); print(as.data.frame(head(bad[, .(n_rows = .N), by = .(text = sample_raw)][order(-n_rows)], 25))) }
if (anyNA(pp$fieldwork_end)) { message("STAT4 primary poll rows with no parsed date:"); print(head(pp[is.na(fieldwork_end), .(page_key, date_raw)], 25)) }
# A date after today is a year-inference failure, not a poll: 39 fed2028_opinion
# headline rows (May-Aug 2025 polls) landed in 2027, plus 2 qld2028 rows (review gate, 2026-10-09). Fails
# AFTER the write so the file can be inspected; root cause not yet diagnosed.
fut <- wiki[row_type == "poll" & !is.na(fieldwork_end) & as.Date(fieldwork_end) > Sys.Date()]
if (nrow(fut)) {
  print(head(fut[, .(page_key, table_idx, date_raw, fieldwork_end)], 25))
  stop(sprintf("STAT6! %d poll row(s) dated after today: year inference is wrong for them", nrow(fut)))
}
message("STAT5 per election: primary poll rows / with sample_n")
print(pp[, .(rows = .N, with_sample = sum(!is.na(sample_n)), with_client = sum(!is.na(client))), by = .(region, election)][order(region, election)], nrows = 100)
