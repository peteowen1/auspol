#!/usr/bin/env Rscript
# Fetch Wikipedia's per-electorate ("seat poll") opinion-polling tables for a
# fixed list of past Australian elections and derive a tidy long CSV.
#
# WHY THIS SHAPE (CLAUDE.md "Store the raw response, never the summary"): every
# page is downloaded once and kept forever in raw/ as plain HTML. Nothing is
# hand-typed -- parsing is done programmatically (rvest) straight off that HTML
# on every run, so re-running never drifts from what the page actually says.
# Re-running only re-fetches pages missing on disk, and always re-parses and
# re-writes seat_polls.csv from whatever HTML is present.
#
# COVERAGE, checked directly by fetching every candidate URL (curl HEAD/GET,
# 2026-09-29) before writing this parser -- not inferred from a search summary:
#
#   Federal: dedicated "Electorate opinion polling for the <year> Australian
#   federal election" pages exist ONLY for 2016, 2019, 2022, 2025 (2010 and
#   2013 have no such page and their main "Opinion polling for..." pages carry
#   no per-seat tables either -- confirmed by grepping the fetched HTML for
#   "wikitable"/"seat poll"/"electorate poll", not assumed from silence).
#
#   State elections: NO dedicated seat-poll or "Opinion polling for..." page
#   exists at all for vic2014, vic2018, nsw2015/2019/2023, qld2017/2020/2024,
#   sa2018/2022, wa2017/2025 (all checked directly, HTTP 404 on the standard
#   title, and their MAIN election-result articles were also grepped and carry
#   no seat/electorate polling section). The only state elections with seat-poll
#   content are:
#     - vic2026: main "Opinion polling for the 2026 Victorian state election"
#       page, section "Individual seat polling" (Hawthorn only, 1 poll)
#     - sa2026: main "Opinion polling for the 2026 South Australian state
#       election" page, section "Individual seat polling" (Mount Gambier only,
#       1 poll; candidate-name columns, not party, since it's an independent-
#       held seat)
#     - wa2021: main "2021 Western Australian state election" article, section
#       "Electorate polling" (Dawesville only, 1 poll)
#   vic2022 and sa2022 DO have a live "Opinion polling for..." page but neither
#   carries any seat/electorate-level section (checked directly) -- the seat-
#   poll practice only shows up for the two most recent state elections here.
#
# This is a real, checked finding, not a gap in the search: seat-level MRP/
# polling only became common for Australian state elections very recently
# (RedBridge/YouGov-style seat MRP), and Wikipedia's per-seat compilation is a
# federal-election tradition going back to 2016 but not (yet) a state one,
# except where a minor-party breakthrough story (ONP in SA/Vic 2026) made
# individual seats newsworthy enough for one-off polls.
#
# A poll row is distinguished from the "actual result" reference row that
# these tables always include (labelled e.g. "2019 federal election" or
# "2016 federal election") by requiring neither the firm cell nor the date
# cell contain the word "election".

suppressPackageStartupMessages({
  library(rvest)
  library(xml2)
})

raw_dir <- "external/reference/polls/seat-polls/raw"
out_csv <- "external/reference/polls/seat-polls/seat_polls.csv"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

ua <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36 auspol-research/1.0 (contact: fptpost@gmail.com)"

# key -> wikipedia URL. Every key in the requested election list is included,
# even the ones confirmed to carry zero seat polls, so the per-election
# row count below is a complete, honest accounting rather than a silent
# omission of "nothing found there".
pages <- c(
  fed2010 = "https://en.wikipedia.org/wiki/Opinion_polling_for_the_2010_Australian_federal_election",
  fed2013 = "https://en.wikipedia.org/wiki/Opinion_polling_for_the_2013_Australian_federal_election",
  fed2016 = "https://en.wikipedia.org/wiki/Electorate_opinion_polling_for_the_2016_Australian_federal_election",
  fed2019 = "https://en.wikipedia.org/wiki/Electorate_opinion_polling_for_the_2019_Australian_federal_election",
  fed2022 = "https://en.wikipedia.org/wiki/Electorate_opinion_polling_for_the_2022_Australian_federal_election",
  fed2025 = "https://en.wikipedia.org/wiki/Electorate_opinion_polling_for_the_2025_Australian_federal_election",
  vic2014 = "https://en.wikipedia.org/wiki/2014_Victorian_state_election",
  vic2018 = "https://en.wikipedia.org/wiki/2018_Victorian_state_election",
  vic2022 = "https://en.wikipedia.org/wiki/Opinion_polling_for_the_2022_Victorian_state_election",
  vic2026 = "https://en.wikipedia.org/wiki/Opinion_polling_for_the_2026_Victorian_state_election",
  nsw2015 = "https://en.wikipedia.org/wiki/2015_New_South_Wales_state_election",
  nsw2019 = "https://en.wikipedia.org/wiki/2019_New_South_Wales_state_election",
  nsw2023 = "https://en.wikipedia.org/wiki/2023_New_South_Wales_state_election",
  qld2017 = "https://en.wikipedia.org/wiki/2017_Queensland_state_election",
  qld2020 = "https://en.wikipedia.org/wiki/2020_Queensland_state_election",
  qld2024 = "https://en.wikipedia.org/wiki/2024_Queensland_state_election",
  sa2018  = "https://en.wikipedia.org/wiki/2018_South_Australian_state_election",
  sa2022  = "https://en.wikipedia.org/wiki/2022_South_Australian_state_election",
  sa2026  = "https://en.wikipedia.org/wiki/Opinion_polling_for_the_2026_South_Australian_state_election",
  wa2017  = "https://en.wikipedia.org/wiki/2017_Western_Australian_state_election",
  wa2021  = "https://en.wikipedia.org/wiki/2021_Western_Australian_state_election",
  wa2025  = "https://en.wikipedia.org/wiki/2025_Western_Australian_state_election"
)

# h2/h3 section-heading keywords that mark a "these subsections are seat polls"
# block, checked against every page above.
seat_section_re <- "individual seat polling|electorate polling|polling for individual seats"
h2_stoplist_re <- "^(contents|see also|notes|references|external links|graphical summary)$"

# The 4 dedicated "Electorate opinion polling for..." federal pages have no
# wrapping "individual seat polling" heading at all -- the WHOLE page is that,
# with h2 = state name and h3 = seat name directly underneath. Confirmed by
# fetching and inspecting each page's heading structure directly.
whole_page_seat <- c(fed2016 = TRUE, fed2019 = TRUE, fed2022 = TRUE, fed2025 = TRUE)

failed <- character(0)
for (key in names(pages)) {
  f <- file.path(raw_dir, paste0(key, ".html"))
  if (file.exists(f) && file.size(f) > 0) {
    message("SKIP (already on disk): ", key)
  } else {
    message("Fetching: ", key)
    ok <- tryCatch({
      download.file(pages[[key]], destfile = f, method = "libcurl",
                    headers = c(`User-Agent` = ua), quiet = TRUE)
      TRUE
    }, error = function(e) { message("  FAILED: ", conditionMessage(e)); FALSE })
    if (!ok) failed <- c(failed, key)
    Sys.sleep(1)
  }
}

pct_num <- function(x) {
  x <- trimws(x)
  x[x %in% c("", "-", "—", "–", "N/A", "n/a")] <- NA
  suppressWarnings(as.numeric(gsub("[%,]", "", x)))
}
sample_num <- function(x) {
  x <- trimws(x)
  x[x %in% c("", "-", "—")] <- NA
  suppressWarnings(as.integer(gsub("[^0-9]", "", x)))
}

month_re <- "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"
parse_daterange <- function(s) {
  s <- trimws(s)
  if (is.na(s) || s == "") return(list(start = NA_character_, end = NA_character_))
  s2 <- gsub("–|‒|‑", "-", s) # normalise en/other dashes to hyphen
  parts <- trimws(strsplit(s2, "-")[[1]])
  parse_one <- function(p, fallback_year = NA) {
    p <- trimws(p)
    if (!grepl("[0-9]{4}", p) && !is.na(fallback_year)) p <- paste(p, fallback_year)
    d <- suppressWarnings(as.Date(p, format = "%d %b %Y"))
    if (is.na(d)) d <- suppressWarnings(as.Date(paste0("1 ", p), format = "%d %b %Y"))
    d
  }
  if (length(parts) >= 2) {
    end_d <- parse_one(parts[length(parts)])
    yr <- if (!is.na(end_d)) format(end_d, "%Y") else NA
    start_d <- parse_one(parts[1], fallback_year = yr)
    list(start = if (is.na(start_d)) NA_character_ else as.character(start_d),
         end   = if (is.na(end_d))   NA_character_ else as.character(end_d))
  } else {
    d <- parse_one(parts[1])
    list(start = if (is.na(d)) NA_character_ else as.character(d),
         end   = if (is.na(d)) NA_character_ else as.character(d))
  }
}

# Parse one <table class="wikitable"> that sits directly under a seat/electorate
# heading into a list of tidy rows (one row per poll x party). Returns NULL if
# the table has no genuine poll rows (only the "actual result" reference rows).
#
# Header rows are identified structurally, not by counting: Wikipedia's seat-poll
# template gives "Date"/"Firm"/"Client"/"Samplesize" columns a rowspan across
# EVERY header row (so fill=TRUE echoes their header text 2 or 3 times), while
# the grouped columns (Primary vote / 2PP vote) carry a group-label row then a
# party-abbreviation row then, sometimes, a genuinely blank third row. So: walk
# down the firm column until its cell stops looking like a header token -- that
# row is data_start -- then pick whichever row ABOVE it has the most non-blank
# cells among the grouped columns as the party-name sub-header (never assume it
# is literally row 2, since a trailing blank header row would win a "row2" guess).
parse_seat_table <- function(tab, election, seat, source_url) {
  raw <- tryCatch(html_table(tab, header = FALSE, fill = TRUE), error = function(e) NULL)
  if (is.null(raw) || nrow(raw) < 2) return(NULL)
  raw <- as.data.frame(lapply(raw, as.character), stringsAsFactors = FALSE)
  raw[is.na(raw)] <- ""
  # Footnote sponsors (see the SPL2 step): one per row, then stripped so no
  # other column's text changes.
  client_re <- "\\s*\\{\\{CLIENT:([^}]*)\\}\\}"
  row_client <- apply(raw, 1, function(r) {
    m <- regmatches(r, regexpr("\\{\\{CLIENT:[^}]*\\}\\}", r))
    if (length(m)) sub("^\\{\\{CLIENT:(.*)\\}\\}$", "\\1", m[1]) else NA_character_
  })
  raw[] <- lapply(raw, function(x) gsub(client_re, "", x))

  # Some tables (fed2016's per-state aggregate) open with a genuinely blank
  # spacer row before the real header -- find the first row that actually
  # looks like a header (>=1 cell matching a known column-name token) among
  # the first few rows, rather than assuming row 1 is it.
  header_tok_re <- "^date$|firm|pollster|^brand$|^seat$|^electorate$|^division$|primary|2pp|tpp|2cp|tcp|^client$|sample"
  hdr <- 1L
  while (hdr <= min(5, nrow(raw)) &&
         !any(grepl(header_tok_re, as.character(raw[hdr, ]), ignore.case = TRUE))) hdr <- hdr + 1L
  if (hdr > min(5, nrow(raw))) return(NULL)

  row1 <- as.character(raw[hdr, ])
  find_col <- function(pattern) which(grepl(pattern, row1, ignore.case = TRUE))
  date_col   <- find_col("^date$")
  firm_col   <- find_col("firm|pollster|^brand$")
  electorate_col <- find_col("^electorate$|^division$|^seat$")
  if (length(date_col) == 0) return(NULL)
  date_col <- date_col[1]
  # Some legacy tables (fed2016's per-state aggregate) carry no Firm column at
  # all -- pollster is then unrecorded on the page itself, not dropped by us.
  firm_col <- if (length(firm_col)) firm_col[1] else NA
  electorate_col <- if (length(electorate_col)) electorate_col[1] else NA

  # A real poll (or result) row always has an actual date -- a 4-digit year --
  # in the date column. Header rows (however many there are: some tables
  # repeat "Date"/"Firm" text 2-3 times via rowspan, some insert a genuinely
  # blank spacer row) never do, regardless of which column carries the
  # recognisable "Date"/"Firm" token text. Walking on this is far more robust
  # than counting rows or matching a specific column's header token.
  looks_like_date <- function(x) grepl("[0-9]{4}", x)
  data_start <- hdr + 1L
  while (data_start <= nrow(raw) && !looks_like_date(raw[data_start, date_col])) data_start <- data_start + 1L
  if (data_start > nrow(raw)) return(NULL)
  header_rows <- if (data_start > hdr + 1) hdr:(data_start - 1) else hdr
  data <- raw[data_start:nrow(raw), , drop = FALSE]
  row_client_data <- row_client[data_start:nrow(raw)]

  client_col <- find_col("^client$")
  sample_col <- find_col("sample")
  fp_cols  <- find_col("primary")
  tcp_cols <- find_col("2pp|tpp|2cp|tcp|two.party|two.candidate")
  # A colspan/rowspan combination rvest sometimes miscounts can bleed a
  # neighbouring "swing"/"classification"/"sample size" column into the tcp
  # group -- exclude anything whose own header text is plainly not a party.
  last_hdr <- as.character(raw[data_start - 1, ])
  not_a_party <- function(cols) !grepl("swing|classification|^sample", row1[cols], ignore.case = TRUE) &
                                 !grepl("swing|classification|^sample", last_hdr[cols], ignore.case = TRUE)
  if (length(fp_cols))  fp_cols  <- fp_cols[not_a_party(fp_cols)]
  if (length(tcp_cols)) tcp_cols <- tcp_cols[not_a_party(tcp_cols)]
  sample_col <- if (length(sample_col)) sample_col[1] else NA
  client_col <- if (length(client_col)) client_col[1] else NA

  # sub-header row = the header row (besides row1) with the most non-blank
  # cells among the fp/tcp columns; falls back to row1 if there is no row 2+
  # (a flat single-row header, e.g. a table whose columns ARE the party codes).
  grouped_cols <- union(fp_cols, tcp_cols)
  sub_row_idx <- hdr
  if (length(header_rows) > 1 && length(grouped_cols) > 0) {
    cand <- setdiff(header_rows, hdr)
    nonblank <- vapply(cand, function(r) sum(nzchar(trimws(as.character(raw[r, grouped_cols])))), integer(1))
    if (any(nonblank > 0)) sub_row_idx <- cand[which.max(nonblank)]
  }
  row2 <- as.character(raw[sub_row_idx, ])

  party_of <- function(j) {
    p <- if (nzchar(trimws(row2[j]))) row2[j] else row1[j]
    trimws(gsub("\\s+", " ", p))
  }

  out <- list()
  for (i in seq_len(nrow(data))) {
    firm_v <- if (!is.na(firm_col)) data[i, firm_col] else NA_character_
    date_v <- data[i, date_col]
    if (!is.na(firm_v) && grepl("election", firm_v, ignore.case = TRUE)) next   # actual-result row
    if (grepl("election", date_v, ignore.case = TRUE)) next
    if ((!is.na(firm_col) && trimws(firm_v) == "") || trimws(date_v) == "") next

    seat_i <- if (!is.na(electorate_col) && nzchar(trimws(data[i, electorate_col]))) data[i, electorate_col] else seat
    dr <- parse_daterange(date_v)
    n  <- if (!is.na(sample_col)) sample_num(data[i, sample_col]) else NA_integer_
    client_v <- if (!is.na(client_col) && nzchar(trimws(data[i, client_col]))) data[i, client_col] else row_client_data[i]

    # Some tables (e.g. fed2022/fed2025's per-state flat aggregate, where one
    # table covers many seats) carry MORE than 2 tcp columns because the
    # two-candidate pairing differs by seat (a major-party seat reports
    # L/NP vs ALP; a teal seat in the SAME table reports IND vs GRN in two
    # otherwise-unused columns for that row). So the populated pair is
    # chosen PER ROW from whichever tcp columns actually have a value here,
    # never a fixed pair of columns assumed to hold every row's numbers.
    tcp_party_a <- NA_character_; tcp_party_b <- NA_character_; tcp_a <- NA_real_
    if (length(tcp_cols) >= 2) {
      tcp_vals <- pct_num(as.character(data[i, tcp_cols]))
      populated <- tcp_cols[!is.na(tcp_vals)]
      if (length(populated) >= 2) populated <- populated[1:2]
      if (length(populated) == 2) {
        tcp_party_a <- party_of(populated[1])
        tcp_party_b <- party_of(populated[2])
        tcp_a <- pct_num(data[i, populated[1]])
      }
    }

    emit_cols <- if (length(fp_cols)) fp_cols else tcp_cols
    if (length(emit_cols) == 0) next
    for (j in emit_cols) {
      fp_val <- if (j %in% fp_cols) pct_num(data[i, j]) else NA_real_
      out[[length(out) + 1]] <- data.frame(
        election = election, seat = seat_i,
        pollster = if (!is.na(firm_v)) trimws(firm_v) else NA_character_,
        client = client_v,
        fieldwork_start = dr$start, fieldwork_end = dr$end, date_raw = date_v,
        published = NA_character_, sample_n = n,
        party = party_of(j), fp = fp_val,
        tcp_party_a = tcp_party_a, tcp_party_b = tcp_party_b, tcp_a = tcp_a,
        source_url = source_url, stringsAsFactors = FALSE
      )
    }
  }
  if (length(out) == 0) return(NULL)
  do.call(rbind, out)
}

all_rows <- list()
counts <- list()

for (key in names(pages)) {
  f <- file.path(raw_dir, paste0(key, ".html"))
  if (!file.exists(f) || file.size(f) == 0) { counts[[key]] <- NA_integer_; failed <- union(failed, key); next }
  page <- tryCatch(read_html(f), error = function(e) { message("PARSE ERROR ", key, ": ", conditionMessage(e)); NULL })
  if (is.null(page)) { counts[[key]] <- NA_integer_; failed <- union(failed, key); next }
  # Sponsors live in footnotes ("Commissioned by Climate 200"), which the
  # sup.reference removal below would discard. Replace each footnote marker
  # whose note names a sponsor with a {{CLIENT:...}} token in the cell text,
  # read back into `client` by parse_seat_table(); other markers are removed.
  notes <- html_elements(page, "span.mw-reference-text")
  note_txt <- setNames(trimws(html_text2(notes)), sub("^mw-reference-text-", "", xml_attr(notes, "id")))
  sups <- html_elements(page, "sup.reference")
  sup_note <- sub("^.*#", "", xml_attr(html_element(sups, "a"), "href"))
  sup_txt <- unname(note_txt[sup_note])
  is_client <- !is.na(sup_txt) & grepl("commissioned (by|for)", sup_txt, ignore.case = TRUE)
  for (k in which(is_client)) {
    who <- sub("[.;](\\s.*)?$", "", trimws(sub("^.*?commissioned (by|for)\\s+(the\\s+)?", "", sup_txt[k], ignore.case = TRUE, perl = TRUE)))
    # A sibling span, not xml_text<-: the marker's own [a]-style link text
    # survives an in-place text set and glues itself onto the pollster name.
    xml_add_sibling(sups[[k]], "span", paste0(" {{CLIENT:", who, "}}"))
  }
  message(sprintf("SPL2 %s: %d footnote markers name a sponsor", key, sum(is_client)))
  xml_remove(sups)
  xml_remove(html_elements(page, "style, script"))

  nodes <- html_elements(page, "h2, h3, h4, table.wikitable, table.toccolours")
  tags  <- html_name(nodes)
  txts  <- trimws(gsub("\\[edit\\]", "", html_text2(nodes)))

  whole <- isTRUE(unname(whole_page_seat[key]))
  in_seat_section <- whole
  section_source <- if (whole) "h2" else "none"  # "h2" persists across h3/h4 siblings; "h3" does not
  current_seat <- NA_character_
  n_before <- length(all_rows)
  for (i in seq_along(nodes)) {
    if (tags[i] == "h2") {
      if (whole) {
        in_seat_section <- !grepl(h2_stoplist_re, txts[i], ignore.case = TRUE)
      } else {
        in_seat_section <- grepl(seat_section_re, txts[i], ignore.case = TRUE)
      }
      section_source <- if (in_seat_section) "h2" else "none"
      current_seat <- if (whole) txts[i] else NA_character_  # whole-page: h2 = state, kept as fallback seat label
    } else if (tags[i] %in% c("h3", "h4")) {
      if (grepl(seat_section_re, txts[i], ignore.case = TRUE)) {
        in_seat_section <- TRUE   # e.g. wa2021: "Electorate polling" is itself an h3
        section_source <- tags[i]
        current_seat <- NA_character_
      } else if (section_source == "h2") {
        current_seat <- txts[i]   # a seat name nested under an h2 seat-section, e.g. "Hawthorn"
      } else if (section_source %in% c("h3", "h4")) {
        in_seat_section <- FALSE  # sibling heading at the same level ends an h3/h4-sourced section
        section_source <- "none"
      }
    } else if (tags[i] == "table" && in_seat_section) {
      seat_label <- if (is.na(current_seat)) "(unspecified)" else current_seat
      res <- tryCatch(parse_seat_table(nodes[[i]], key, seat_label, pages[[key]]),
                       error = function(e) NULL)
      if (!is.null(res)) all_rows[[length(all_rows) + 1]] <- res
    }
  }
  # count distinct (seat, pollster, fieldwork_start) rows added for this election
  added <- if (length(all_rows) > n_before) {
    do.call(rbind, all_rows[(n_before + 1):length(all_rows)])
  } else NULL
  counts[[key]] <- if (is.null(added)) 0L else nrow(unique(added[, c("seat", "pollster", "date_raw")]))
}

seat_polls <- if (length(all_rows)) do.call(rbind, all_rows) else data.frame()
if (nrow(seat_polls)) {
  seat_polls <- seat_polls[order(seat_polls$election, seat_polls$seat, seat_polls$fieldwork_start), ]
  # Wikipedia interleaves campaign events ("Ian Goodenough resigns from the
  # Liberal Party...") as rows in the poll tables; they parse into the firm
  # column and carry no numbers. Kept (they are dated events, possibly useful),
  # but marked so nothing treats them as polls.
  has_num <- ave(!is.na(seat_polls$fp) | !is.na(seat_polls$tcp_a),
                 seat_polls$election, seat_polls$seat, seat_polls$date_raw, seat_polls$pollster,
                 FUN = any)
  seat_polls$row_type <- ifelse(has_num, "poll", "event")
  # fed2016 labels seats "Adelaide (SA)"; strip the state for joining.
  seat_polls$seat_name <- trimws(sub("\\s*\\((NSW|VIC|Vic|QLD|Qld|SA|WA|TAS|Tas|ACT|NT)\\)$", "", seat_polls$seat))
  message(sprintf("SPL1 %d poll rows, %d event rows (no numbers); %d seats renamed by state-suffix strip",
                  sum(has_num), sum(!has_num), sum(seat_polls$seat_name != seat_polls$seat)))
}
write.csv(seat_polls, out_csv, row.names = FALSE, na = "")

if (length(failed)) message("\nSPL0!! NOT CHECKED (fetch or parse failed; NA below, not a confirmed zero): ", paste(failed, collapse = ", "))
message("\n---- seat polls found per election (distinct poll x seat) ----")
for (key in names(pages)) message(sprintf("  %-8s %d", key, counts[[key]]))
message("\nWrote ", nrow(seat_polls), " total rows (poll x party) to ", out_csv)
