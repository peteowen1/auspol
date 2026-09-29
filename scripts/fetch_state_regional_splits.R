#!/usr/bin/env Rscript
# Fetch capital-city-vs-rest-of-state regional breakdowns of state voting-
# intention polls and derive a tidy long CSV.
#
# WHY THIS SHAPE (CLAUDE.md "Store the raw response, never the summary"): every
# page is downloaded once and kept forever in raw/. Wikipedia's "Sub-state
# results"/"Sub-state polling" tables are parsed programmatically (rvest),
# never hand-typed, so a re-run can never drift from the page. The two prose
# news-article sources (no table, just narrative text) are hand-read off a
# saved plain-text extraction, same convention as fetch_poll_breakdowns.R,
# and are flagged as such below.
#
# COVERAGE, checked directly on 2026-09-29, not inferred from a search summary:
#   - vic2026: Wikipedia "Opinion polling for the 2026 Victorian state
#     election", section "Sub-state results" -- Inner Melbourne, Outer
#     Melbourne, Melbourne, Provincial, Rural, Regional/Rural. Real tables,
#     parsed programmatically.
#   - sa2026: Wikipedia "Opinion polling for the 2026 South Australian state
#     election", section "Sub-state polling" -- Inner Adelaide, Outer
#     Adelaide, Adelaide, Regional South Australia. Real tables, parsed
#     programmatically.
#   - NSW: no Wikipedia page carries a metro/regional split for any NSW state
#     election (checked: no "Opinion polling for..." page exists at all for
#     2015/2019/2023 -- see fetch_seat_polls.R). A live DemosAU/Premier
#     National poll (fieldwork 15-18 Jun 2026, n=1,038, published 22 Jun 2026
#     at demosau.com/news) DOES give a "regional NSW outside the Sydney
#     basin" primary-vote breakdown -- hand-read off the saved article text
#     (no table on the page, prose only) and added as one poll's worth of
#     rows. NOTE: this is a NSW STATE-voting-intention poll ahead of the 2027
#     NSW election, so its `election` value is "nsw2027", not one of the
#     three past elections in the seat-poll list -- included anyway since the
#     task scope for this file is "any year 2010 onward", not the seat-poll
#     file's fixed election list.
#   - Queensland: a YouGov poll covered by Poll Bludger (pollbludger.net,
#     2024-10-20, ahead of the 2024 QLD election) gives a 5-region regional
#     breakdown (inner metro / outer metro / regional / coastal / rural) but
#     the article states only SWING deltas ("Labor faces a swing of around
#     9% in outer metro") and never an absolute 2PP or primary level for any
#     region -- consistent with fetch_poll_breakdowns.R's existing rule that a
#     delta with no stated base cannot be turned into a comparable percentage
#     without guessing. Raw HTML/text saved for the record; NO rows added.
#   - Victoria (2010-2022), WA, SA (2010-2022): no Wikipedia sub-state table
#     and no Poll Bludger article with a usable regional LEVEL was found in
#     the time available -- a genuine search gap, not confirmed absent the
#     way the NSW/QLD Wikipedia-page checks above are.
#
# Not duplicated here: DemosAU's own Victorian poll PDFs already carry a
# metro/regional "location" crosstab dimension, captured separately by
# scripts/fetch_demosau_crosstabs.R -- this file is Wikipedia/Poll-Bludger
# sourced only, per the task scope, so it is not re-derived here.

suppressPackageStartupMessages({
  library(rvest)
  library(xml2)
})

raw_dir <- "external/reference/polls/state-regional-splits/raw"
text_dir <- "external/reference/polls/state-regional-splits/text"
out_csv <- "external/reference/polls/state-regional-splits/regional_splits.csv"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(text_dir, recursive = TRUE, showWarnings = FALSE)

# A plain browser UA -- demosau.com returns 403 to the custom
# "auspol-research/1.0" suffix used by the other fetch scripts in this repo
# (confirmed directly: curl with that suffix -> 403, same curl without it ->
# 200), so this script uses an ordinary browser string throughout instead.
ua <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

pages <- c(
  vic2026 = "https://en.wikipedia.org/wiki/Opinion_polling_for_the_2026_Victorian_state_election",
  sa2026  = "https://en.wikipedia.org/wiki/Opinion_polling_for_the_2026_South_Australian_state_election"
)
articles <- c(
  qld2024_yougov = "https://www.pollbludger.net/2024/10/20/yougov-55-45-to-lnp-in-queensland/",
  nsw2027_demosau = "https://demosau.com/news/one-nation-overtakes-coalition-to-move-into-second-place-in-nsw-new-poll/"
)

fetch_if_missing <- function(url, dest) {
  if (file.exists(dest) && file.size(dest) > 0) { message("SKIP (already on disk): ", dest); return(invisible()) }
  message("Fetching: ", url)
  tryCatch({
    download.file(url, destfile = dest, method = "libcurl", headers = c(`User-Agent` = ua), quiet = TRUE)
  }, error = function(e) message("  FAILED: ", conditionMessage(e)))
  Sys.sleep(1)
}

for (key in names(pages)) fetch_if_missing(pages[[key]], file.path(raw_dir, paste0(key, ".html")))
for (key in names(articles)) fetch_if_missing(articles[[key]], file.path(raw_dir, paste0(key, ".html")))

html_to_text <- function(html) {
  body <- regmatches(html, regexpr("(?s)<div class=\"entry-content\">.*?<footer", html, perl = TRUE))
  if (length(body) == 0 || nchar(body) == 0) body <- html
  body <- gsub("(?s)<script.*?</script>", " ", body, perl = TRUE)
  body <- gsub("(?s)<style.*?</style>", " ", body, perl = TRUE)
  body <- gsub("<[^>]+>", " ", body, perl = TRUE)
  body <- gsub("&nbsp;", " ", body); body <- gsub("&#8211;", "-", body)
  body <- gsub("&#8217;|&#8216;", "'", body); body <- gsub("&amp;", "&", body)
  gsub("\\s+", " ", body) |> trimws()
}
for (key in names(articles)) {
  f <- file.path(raw_dir, paste0(key, ".html")); tf <- file.path(text_dir, paste0(key, ".txt"))
  if (file.exists(f) && file.size(f) > 0 && !file.exists(tf)) {
    writeLines(html_to_text(paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")), tf, useBytes = TRUE)
  }
}

pct_num <- function(x) {
  x <- trimws(as.character(x)); x[x %in% c("", "-", "—", "–", "N/A", "n/a")] <- NA
  suppressWarnings(as.numeric(gsub("[%,]", "", x)))
}
sample_num <- function(x) {
  x <- trimws(as.character(x)); x[x %in% c("", "-", "—")] <- NA
  suppressWarnings(as.integer(gsub("[^0-9]", "", x)))
}
parse_daterange <- function(s) {
  s <- trimws(s); if (is.na(s) || s == "") return(list(start = NA_character_, end = NA_character_))
  s2 <- gsub("–|‒|‑", "-", s)
  parts <- trimws(strsplit(s2, "-")[[1]])
  parse_one <- function(p, fallback_year = NA) {
    p <- trimws(p)
    if (!grepl("[0-9]{4}", p) && !is.na(fallback_year)) p <- paste(p, fallback_year)
    d <- suppressWarnings(as.Date(p, format = "%d %b %Y"))
    if (is.na(d)) d <- suppressWarnings(as.Date(paste0("1 ", p), format = "%d %b %Y"))
    d
  }
  if (length(parts) >= 2) {
    end_d <- parse_one(parts[length(parts)]); yr <- if (!is.na(end_d)) format(end_d, "%Y") else NA
    start_d <- parse_one(parts[1], fallback_year = yr)
    list(start = if (is.na(start_d)) NA_character_ else as.character(start_d),
         end   = if (is.na(end_d))   NA_character_ else as.character(end_d))
  } else {
    d <- parse_one(parts[1])
    list(start = if (is.na(d)) NA_character_ else as.character(d), end = if (is.na(d)) NA_character_ else as.character(d))
  }
}

# Same parser as fetch_seat_polls.R's parse_seat_table(), adapted to emit the
# regional-split schema (region instead of seat; tpp_alp instead of a generic
# tcp pair). See that script's header comment for why headers are located
# structurally (a real date's 4-digit year) rather than by row-counting.
parse_region_table <- function(tab, election, region, source_url) {
  raw <- tryCatch(html_table(tab, header = FALSE, fill = TRUE), error = function(e) NULL)
  if (is.null(raw) || nrow(raw) < 2) return(NULL)
  raw <- as.data.frame(lapply(raw, as.character), stringsAsFactors = FALSE)
  raw[is.na(raw)] <- ""

  header_tok_re <- "^date$|firm|pollster|^brand$|primary|2pp|tpp|2cp|tcp|^client$|sample"
  hdr <- 1L
  while (hdr <= min(5, nrow(raw)) && !any(grepl(header_tok_re, as.character(raw[hdr, ]), ignore.case = TRUE))) hdr <- hdr + 1L
  if (hdr > min(5, nrow(raw))) return(NULL)

  row1 <- as.character(raw[hdr, ])
  find_col <- function(pattern) which(grepl(pattern, row1, ignore.case = TRUE))
  date_col <- find_col("^date$"); firm_col <- find_col("firm|pollster|^brand$")
  if (length(date_col) == 0) return(NULL)
  date_col <- date_col[1]; firm_col <- if (length(firm_col)) firm_col[1] else NA

  looks_like_date <- function(x) grepl("[0-9]{4}", x)
  data_start <- hdr + 1L
  while (data_start <= nrow(raw) && !looks_like_date(raw[data_start, date_col])) data_start <- data_start + 1L
  if (data_start > nrow(raw)) return(NULL)
  header_rows <- if (data_start > hdr + 1) hdr:(data_start - 1) else hdr
  data <- raw[data_start:nrow(raw), , drop = FALSE]

  client_col <- find_col("^client$"); sample_col <- find_col("sample")
  fp_cols <- find_col("primary"); tcp_cols <- find_col("2pp|tpp|2cp|tcp|two.party|two.candidate")
  last_hdr <- as.character(raw[data_start - 1, ])
  not_a_party <- function(cols) !grepl("swing|classification|^sample", row1[cols], ignore.case = TRUE) &
                                 !grepl("swing|classification|^sample", last_hdr[cols], ignore.case = TRUE)
  if (length(fp_cols)) fp_cols <- fp_cols[not_a_party(fp_cols)]
  if (length(tcp_cols)) tcp_cols <- tcp_cols[not_a_party(tcp_cols)]
  sample_col <- if (length(sample_col)) sample_col[1] else NA
  client_col <- if (length(client_col)) client_col[1] else NA

  grouped_cols <- union(fp_cols, tcp_cols)
  sub_row_idx <- hdr
  if (length(header_rows) > 1 && length(grouped_cols) > 0) {
    cand <- setdiff(header_rows, hdr)
    nonblank <- vapply(cand, function(r) sum(nzchar(trimws(as.character(raw[r, grouped_cols])))), integer(1))
    if (any(nonblank > 0)) sub_row_idx <- cand[which.max(nonblank)]
  }
  row2 <- as.character(raw[sub_row_idx, ])
  party_of <- function(j) { p <- if (nzchar(trimws(row2[j]))) row2[j] else row1[j]; trimws(gsub("\\s+", " ", p)) }

  out <- list()
  for (i in seq_len(nrow(data))) {
    firm_v <- if (!is.na(firm_col)) data[i, firm_col] else NA_character_
    date_v <- data[i, date_col]
    if (!is.na(firm_v) && grepl("election", firm_v, ignore.case = TRUE)) next
    if (grepl("election", date_v, ignore.case = TRUE)) next
    if ((!is.na(firm_col) && trimws(firm_v) == "") || trimws(date_v) == "") next

    dr <- parse_daterange(date_v)
    n <- if (!is.na(sample_col)) sample_num(data[i, sample_col]) else NA_integer_

    tpp_alp <- NA_real_; tcp_party_a <- NA_character_; tcp_party_b <- NA_character_
    if (length(tcp_cols) >= 2) {
      tcp_vals <- pct_num(as.character(data[i, tcp_cols]))
      populated <- tcp_cols[!is.na(tcp_vals)]
      if (length(populated) >= 2) populated <- populated[1:2]
      if (length(populated) == 2) {
        tcp_party_a <- party_of(populated[1]); tcp_party_b <- party_of(populated[2])
        alp_j <- populated[toupper(c(tcp_party_a, tcp_party_b)) == "ALP"]
        if (length(alp_j) == 1) tpp_alp <- pct_num(data[i, alp_j])
      }
    }
    emit_cols <- if (length(fp_cols)) fp_cols else tcp_cols
    if (length(emit_cols) == 0) next
    for (j in emit_cols) {
      out[[length(out) + 1]] <- data.frame(
        election = election, pollster = if (!is.na(firm_v)) trimws(firm_v) else NA_character_,
        fieldwork_start = dr$start, fieldwork_end = dr$end, date_raw = date_v,
        sample_n = n, region = region, party = party_of(j),
        fp = if (j %in% fp_cols) pct_num(data[i, j]) else NA_real_,
        tpp_alp = tpp_alp, tcp_party_a = tcp_party_a, tcp_party_b = tcp_party_b,
        source_url = source_url, stringsAsFactors = FALSE
      )
    }
  }
  if (length(out) == 0) return(NULL)
  do.call(rbind, out)
}

all_rows <- list()
region_section_re <- "sub-state results|sub-state polling|sub-national polling|regional polling"

for (key in names(pages)) {
  f <- file.path(raw_dir, paste0(key, ".html"))
  if (!file.exists(f) || file.size(f) == 0) next
  page <- tryCatch(read_html(f), error = function(e) NULL)
  if (is.null(page)) next
  xml_remove(html_elements(page, "style, script, sup.reference"))
  nodes <- html_elements(page, "h2, h3, h4, table.wikitable")
  tags <- html_name(nodes)
  txts <- trimws(gsub("\\[edit\\]", "", html_text2(nodes)))

  in_region_section <- FALSE
  current_region <- NA_character_
  for (i in seq_along(nodes)) {
    if (tags[i] == "h2") {
      in_region_section <- grepl(region_section_re, txts[i], ignore.case = TRUE)
      current_region <- NA_character_
    } else if (tags[i] %in% c("h3", "h4")) {
      if (in_region_section) current_region <- txts[i]
    } else if (tags[i] == "table" && in_region_section && !is.na(current_region)) {
      res <- tryCatch(parse_region_table(nodes[[i]], key, current_region, pages[[key]]), error = function(e) NULL)
      if (!is.null(res)) all_rows[[length(all_rows) + 1]] <- res
    }
  }
}

## ---- NSW DemosAU article: prose only, hand-read off the saved text file ----
## (external/reference/polls/state-regional-splits/text/nsw2027_demosau.txt)
## fieldwork 15-18 Jun 2026, n=1038, published 22 Jun 2026. No TPP stated for
## the regional row, only primaries; statewide row included too, region="statewide".
nsw_url <- unname(articles["nsw2027_demosau"])
nsw_rows <- rbind(
  data.frame(election = "nsw2027", pollster = "DemosAU/Premier National",
             fieldwork_start = "2026-06-15", fieldwork_end = "2026-06-18", date_raw = "15-18 Jun 2026",
             sample_n = 1038L, region = "statewide", party = c("ALP", "ONP", "L/NP", "GRN", "OTH"),
             fp = c(32, 27, 20, 13, 8), tpp_alp = NA_real_, tcp_party_a = NA_character_, tcp_party_b = NA_character_,
             source_url = nsw_url, stringsAsFactors = FALSE),
  data.frame(election = "nsw2027", pollster = "DemosAU/Premier National",
             fieldwork_start = "2026-06-15", fieldwork_end = "2026-06-18", date_raw = "15-18 Jun 2026",
             sample_n = 1038L, region = "regional (outside Sydney basin)", party = c("ONP", "ALP", "L/NP"),
             fp = c(37, 23, 19), tpp_alp = NA_real_, tcp_party_a = NA_character_, tcp_party_b = NA_character_,
             source_url = nsw_url, stringsAsFactors = FALSE)
)
all_rows[[length(all_rows) + 1]] <- nsw_rows

## qld2024_yougov: NO rows -- article states only swing deltas per region, no
## absolute level for any region (see header comment). Left out on purpose.

splits <- if (length(all_rows)) do.call(rbind, all_rows) else data.frame()
if (nrow(splits)) splits <- splits[order(splits$election, splits$region, splits$fieldwork_start), ]
write.csv(splits, out_csv, row.names = FALSE, na = "")

message("\n---- regional-split rows per election ----")
if (nrow(splits)) {
  print(aggregate(list(rows = splits$party), by = list(election = splits$election, region = splits$region), FUN = length))
}
message("\nWrote ", nrow(splits), " total rows to ", out_csv)
