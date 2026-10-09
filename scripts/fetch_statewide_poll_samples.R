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

base_dir <- "external/reference/polls/statewide-samples"
raw_dir  <- file.path(base_dir, "raw")
out_csv  <- file.path(base_dir, "statewide_polls_wiki.csv")
man_csv  <- file.path(base_dir, "pages_manifest.csv")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

ua <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36 auspol-research/1.0 (contact: fptpost@gmail.com)"
wp <- "https://en.wikipedia.org/wiki/"

# ---- page list ---------------------------------------------------------------
state_names <- c(vic = "Victorian", nsw = "New South Wales", qld = "Queensland",
                 wa = "Western Australian", sa = "South Australian")
elections <- list(
  fed = c(2007, 2010, 2013, 2016, 2019, 2022, 2025, 2028),
  vic = c(2010, 2014, 2018, 2022, 2026),
  nsw = c(2011, 2015, 2019, 2023, 2027),
  qld = c(2012, 2015, 2017, 2020, 2024, 2028),
  wa  = c(2008, 2013, 2017, 2021, 2025),
  sa  = c(2010, 2014, 2018, 2022, 2026)
)
pg <- list()
for (rg in names(elections)) for (yr in elections[[rg]]) {
  key <- paste0(rg, yr)
  if (rg == "fed") {
    op   <- if (yr == 2028) "Opinion_polling_for_the_next_Australian_federal_election"
            else sprintf("Opinion_polling_for_the_%d_Australian_federal_election", yr)
    main <- if (yr == 2028) NA_character_ else sprintf("%d_Australian_federal_election", yr)
  } else {
    op   <- sprintf("Opinion_polling_for_the_%d_%s_state_election", yr, gsub(" ", "_", state_names[[rg]]))
    main <- sprintf("%d_%s_state_election", yr, gsub(" ", "_", state_names[[rg]]))
  }
  pg[[length(pg) + 1]] <- data.table(page_key = paste0(key, "_opinion"), region = rg, election = key, kind = "opinion", title = op)
  if (!is.na(main))
    pg[[length(pg) + 1]] <- data.table(page_key = paste0(key, "_main"), region = rg, election = key, kind = "main", title = main)
}
pages <- rbindlist(pg)
# Election dates (polling day). 2028 federal is a placeholder: it is only used as an upper bound.
elec_dates <- rbindlist(list(
  data.table(region = "fed", year = c(2007, 2010, 2013, 2016, 2019, 2022, 2025, 2028),
             election_date = as.Date(c("2007-11-24", "2010-08-21", "2013-09-07", "2016-07-02", "2019-05-18", "2022-05-21", "2025-05-03", "2028-12-31"))),
  data.table(region = "vic", year = c(2010, 2014, 2018, 2022, 2026),
             election_date = as.Date(c("2010-11-27", "2014-11-29", "2018-11-24", "2022-11-26", "2026-11-28"))),
  data.table(region = "nsw", year = c(2011, 2015, 2019, 2023, 2027),
             election_date = as.Date(c("2011-03-26", "2015-03-28", "2019-03-23", "2023-03-25", "2027-03-27"))),
  data.table(region = "qld", year = c(2012, 2015, 2017, 2020, 2024, 2028),
             election_date = as.Date(c("2012-03-24", "2015-01-31", "2017-11-25", "2020-10-31", "2024-10-26", "2028-10-28"))),
  data.table(region = "wa", year = c(2008, 2013, 2017, 2021, 2025),
             election_date = as.Date(c("2008-09-06", "2013-03-09", "2017-03-11", "2021-03-13", "2025-03-08"))),
  data.table(region = "sa", year = c(2010, 2014, 2018, 2022, 2026),
             election_date = as.Date(c("2010-03-20", "2014-03-15", "2018-03-17", "2022-03-19", "2026-03-21")))
))
elec_dates[, election := paste0(region, year)]
fwrite(elec_dates, file.path(base_dir, "election_dates.csv"))
pages[, url := paste0(wp, title)]

# ---- download once -----------------------------------------------------------
pages[, status := NA_character_]
for (i in seq_len(nrow(pages))) {
  f  <- file.path(raw_dir, paste0(pages$page_key[i], ".html"))
  nf <- file.path(raw_dir, paste0(pages$page_key[i], ".notfound"))
  if (file.exists(f) && file.size(f) > 0) {
    pages$status[i] <- "on_disk"
  } else if (file.exists(nf)) {
    pages$status[i] <- "not_found"
  } else {
    message("Fetching: ", pages$page_key[i])
    ok <- tryCatch({
      suppressWarnings(download.file(pages$url[i], destfile = f, method = "libcurl",
                                     headers = c(`User-Agent` = ua), quiet = TRUE))
      file.exists(f) && file.size(f) > 0
    }, error = function(e) FALSE)
    if (ok) {
      pages$status[i] <- "on_disk"
    } else {
      if (file.exists(f)) file.remove(f)
      # HTTP 404 is a real answer ("no such page"); remember it so a re-run does not ask again.
      writeLines(paste("404 or fetch failure", Sys.time()), nf)
      pages$status[i] <- "not_found"
    }
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
  tok <- gregexpr("(?i)\\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\b|\\b\\d{4}\\b|\\b\\d{1,2}(?:st|nd|rd|th)?\\b", s, perl = TRUE)
  tk <- regmatches(s, tok)[[1]]
  if (!length(tk)) return(na)
  days <- integer(0); mons <- integer(0); yrs <- integer(0)   # one entry per date
  pend <- integer(0)        # days still waiting for a month (day-first: "1-3 Mar")
  open_month <- NA_integer_ # month seen before its days (month-first: "Feb 3-10")
  open_used <- TRUE
  for (t in tk) {
    if (grepl("^\\d{4}$", t)) {
      yrs[is.na(yrs)] <- as.integer(t)
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
  if (!open_used) { days <- c(days, 15L); mons <- c(mons, open_month); yrs <- c(yrs, NA_integer_) }   # "Mar 2022": mid-month
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
coalition_names <- c("L/NP", "LNP", "Coalition", "L/NP*", "LIB/NAT", "LIB+NAT", "C")
parse_poll_table <- function(tab, page_key, region, election, kind, url, tidx, section) {
  raw <- tryCatch(html_table(tab, header = FALSE, fill = TRUE), error = function(e) NULL)
  if (is.null(raw) || nrow(raw) < 2 || ncol(raw) < 3) return(NULL)
  raw <- as.data.frame(lapply(raw, function(x) clean_ws(as.character(x))), stringsAsFactors = FALSE)
  raw[is.na(raw)] <- ""
  names(raw) <- paste0("V", seq_len(ncol(raw)))
  # header rows: leading rows whose first date-looking column says "Date"
  # (some pages open with a blank spacer row; the sub-header rows can have a blank date cell)
  is_hdr <- function(r) any(grepl("^dates?$", strip_fn(as.character(raw[r, ])), ignore.case = TRUE))
  r0 <- NA_integer_
  for (r in seq_len(min(4L, nrow(raw)))) if (is_hdr(r)) { r0 <- r; break }
  if (is.na(r0)) return(NULL)
  dcol <- which(grepl("^dates?$", strip_fn(as.character(raw[r0, ])), ignore.case = TRUE))[1]
  dstart <- r0 + 1L     # first data row = first row whose date cell holds a digit or the word "election"
  while (dstart <= nrow(raw) && !grepl("[0-9]|election", raw[dstart, dcol], ignore.case = TRUE)) dstart <- dstart + 1L
  if (dstart > nrow(raw)) return(NULL)
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
  if (!"date" %in% roles || !"firm" %in% roles) return(NULL)
  roles[duplicated(roles) & roles %in% c("date", "firm", "client", "sample", "mode", "seat")] <- "other"
  col_date <- which(roles == "date")[1]; col_firm <- which(roles == "firm")[1]
  col_cli <- which(roles == "client")[1]; col_smp <- which(roles == "sample")[1]
  col_mode <- which(roles == "mode")[1]; col_seat <- which(roles == "seat")[1]
  has_pv <- any(roles == "pv"); has_tpp <- any(roles == "tpp")
  table_type <- if (!is.na(col_seat)) "seat" else if (has_pv) "primary" else if (has_tpp) "tpp_only" else "other"
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
  if (!nrow(data)) return(NULL)
  rows <- list()
  for (i in seq_len(nrow(data))) {
    cells <- as.character(data[i, ])
    dt_v <- cells[col_date]; fm_v <- cells[col_firm]
    nonblank <- cells[-col_date][nzchar(cells[-col_date])]
    # spacer / year separator / dated EVENT row ("Albanese replaces Shorten": one cell spanning
    # every column but the date): everything except the date is one repeated string or blank.
    if (!nzchar(dt_v) || length(unique(nonblank)) <= 1) next
    if (!grepl("[0-9]", dt_v)) next
    row_type <- if (grepl("election", fm_v, ignore.case = TRUE) || grepl("election", dt_v, ignore.case = TRUE) ||
                    any(grepl("^(20|19)[0-9]{2} election$", strip_fn(cells)))) "result" else "poll"
    pdts <- parse_dates(dt_v)
    r <- data.table(
      page_key = page_key, region = region, election = election, page_kind = kind, source_url = url,
      table_idx = tidx, section = section, table_type = table_type, row_in_table = i, row_type = row_type,
      date_raw = strip_fn(dt_v), firm_raw = strip_fn(fm_v),
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
  if (!length(rows)) return(NULL)
  rbindlist(rows, fill = TRUE)
}

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
pages[, `:=`(n_tables = NA_integer_, n_tables_parsed = NA_integer_, n_poll_rows = NA_integer_)]
for (i in seq_len(nrow(pages))) {
  f <- file.path(raw_dir, paste0(pages$page_key[i], ".html"))
  if (pages$status[i] != "on_disk") next
  page <- tryCatch(read_html(f), error = function(e) { message("PARSE ERROR ", pages$page_key[i], ": ", conditionMessage(e)); NULL })
  if (is.null(page)) next
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
             error = function(e) { message("  table ", t, " of ", pages$page_key[i], " failed: ", conditionMessage(e)); NULL }))
  pages$n_tables[i] <- length(tabs)
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
        if (!is.na(ref)) {
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
  cols <- intersect(paste0(prefix, cands), names(d))
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
fwrite(pages[, .(page_key, region, election, kind, title, url, status, n_tables, n_tables_parsed, n_poll_rows)], man_csv)

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
message("STAT5 per election: primary poll rows / with sample_n")
print(pp[, .(rows = .N, with_sample = sum(!is.na(sample_n)), with_client = sum(!is.na(client))), by = .(region, election)][order(region, election)], nrows = 100)
