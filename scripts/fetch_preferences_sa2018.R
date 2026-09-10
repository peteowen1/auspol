# South Australia 2018: House of Assembly first preferences and declared winners.
#
# WHY WIKIPEDIA. scripts/fetch_sa2022_and_winners.R reads the ECSA results API,
# which answers 2018 with an empty body (HTTP 204) -- checked fresh, not
# assumed: ECSA holds only 2022 and 2026. Wikipedia's "Results of the 2018
# South Australian state election (House of Assembly)" carries one table per
# district built from the "Election box candidate AU party" template family,
# sourced from ECSA's own now-dead per-district results pages (cited in each
# table's caption). 47 tables, exactly SA's chamber size.
#
# THE data-mw ATTRIBUTE, NOT THE RENDERED <table>. Each district's wikitext is
# preserved as structured JSON in the table's data-mw attribute (one "part" per
# template call, in document order): "Election box candidate AU party" for each
# first-preference candidate, then "Election box formal/informal/turnout",
# then "Election box 2pp" (or "2cp") followed by a SECOND set of candidate
# templates for the two-party/two-candidate result, then "...hold/gain AU
# party" naming the winner. Parsing the rendered HTML rows instead would need
# to distinguish the first-preference rows from the 2pp/2cp rows sharing the
# same table -- the JSON's template order does that for free: first-preference
# candidates are exactly the "candidate" templates before the first "formal"
# template.
#
# WIKIPEDIA IS A SECONDARY SOURCE AND IS TREATED AS ONE (CLAUDE.md, data
# conventions). Its own party-summary infobox (top of the article) is checked
# against the anchor's eventual-results.csv below before anything here is
# trusted, and every per-seat total is checked against the "formal votes" the
# table itself reports.
#
# Emits SW* codes.

options(auspol.root = normalizePath("."))
options(timeout = max(600, getOption("timeout")))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")
RAW <- file.path("external", "reference", "wikipedia")
OUT <- election_data_path()
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)

URL <- paste0("https://en.wikipedia.org/wiki/",
              "Results_of_the_2018_South_Australian_state_election_",
              "(House_of_Assembly)")
HTML <- file.path(RAW, "sa2018-ha.html")

if (!file.exists(HTML) || file.info(HTML)$size < 3e5) {
  ok <- FALSE
  for (k in 1:3) {
    try({
      utils::download.file(utils::URLencode(URL), HTML, quiet = TRUE, mode = "wb",
                            headers = c("User-Agent" = UA))
      ok <- file.exists(HTML) && file.info(HTML)$size > 3e5
    }, silent = TRUE)
    if (ok) break
    Sys.sleep(c(5, 15, 30)[k])
  }
  if (!ok) stop("Could not fetch ", URL)
}
x <- paste(readLines(HTML, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
cat(sprintf("SW1  %s: %.1f MB\n", HTML, file.info(HTML)$size / 1e6))

`%||%` <- function(a, b) if (is.null(a)) b else a
un_html <- function(s) {
  s <- gsub("&apos;", "'", s, fixed = TRUE)
  s <- gsub("&quot;", '"', s, fixed = TRUE)
  s <- gsub("&amp;", "&", s, fixed = TRUE)
  s <- gsub("&lt;", "<", s, fixed = TRUE)
  s <- gsub("&gt;", ">", s, fixed = TRUE)
  s
}
# "[[Rachel Sanderson]]" -> "Rachel Sanderson"; "[[Robert Simms (politician)|Robert Simms]]"
# -> "Robert Simms". Order matters: strip the piped link before the bare one.
delink <- function(s) {
  s <- gsub("\\[\\[[^|\\]]*\\|([^\\]]*)\\]\\]", "\\1", s)
  s <- gsub("\\[\\[([^\\]]*)\\]\\]", "\\1", s)
  s
}

# ---- one <h3 id="...">Seat Name</h3> per district, in document order --------
heads <- gregexpr('<h3 id="[^"]*">[^<]*</h3>', x)[[1]]
head_len <- attr(heads, "match.length")
head_txt <- regmatches(x, gregexpr('<h3 id="[^"]*">[^<]*</h3>', x))[[1]]
seat_names <- sub('^<h3 id="[^"]*">', "", sub("</h3>$", "", head_txt))
cat(sprintf("SW2  %d district headings found\n", length(seat_names)))
if (length(seat_names) != 47L)
  stop("South Australia had 47 districts in 2018 and this page has ", length(seat_names))

# Each district's results table starts at the FIRST data-mw='...' after its
# heading and ends at the next heading (or end of file for the last one).
tbl_start <- vapply(seq_along(seat_names), function(i) {
  from <- heads[i] + head_len[i]
  m <- regexpr("data-mw='", x, fixed = TRUE, useBytes = FALSE)
  # search only after `from`
  rest <- substr(x, from, nchar(x))
  m <- regexpr("data-mw='", rest, fixed = TRUE)
  if (m < 0) stop("No data-mw table found for ", seat_names[i])
  from + m - 1L
}, numeric(1))
tbl_end <- c(heads[-1], nchar(x) + 1L)

rows <- list(); wins <- list()
for (i in seq_along(seat_names)) {
  seg <- substr(x, tbl_start[i], tbl_end[i] - 1L)
  # The attribute is delimited by single quotes and contains none unescaped
  # (Wikipedia HTML-entity-escapes any candidate apostrophe as &apos; inside
  # it), so the first "'>" closes it.
  m <- regexpr("data-mw='.*?'>", seg, perl = TRUE)
  if (m < 0) stop("Malformed data-mw attribute for ", seat_names[i])
  raw <- regmatches(seg, m)
  raw <- sub("^data-mw='", "", raw); raw <- sub("'>$", "", raw)
  j <- tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE),
                error = function(e) stop("JSON parse failed for ", seat_names[i], ": ", conditionMessage(e)))
  # "parts" interleaves template objects with bare "\n" strings between them
  # (the raw wikitext's own newlines) -- drop those before indexing $template.
  parts_j <- Filter(is.list, j$parts)
  tnames <- vapply(parts_j, function(p) {
    tn <- p$template$target$wt
    if (is.null(tn)) return(NA_character_)
    trimws(tn)
  }, character(1))
  first_formal <- which(tnames == "Election box formal")[1]
  if (is.na(first_formal))
    stop(seat_names[i], ": no 'Election box formal' template found")
  cand_idx <- which(tnames == "Election box candidate AU party")
  cand_idx <- cand_idx[cand_idx < first_formal]
  if (!length(cand_idx))
    stop(seat_names[i], ": no first-preference candidate rows found")
  for (ci in cand_idx) {
    p <- parts_j[[ci]]$template$params
    cand <- un_html(delink(p$candidate$wt %||% NA_character_))
    party <- un_html(p$party$wt %||% NA_character_)
    votes <- as.numeric(gsub(",", "", p$votes$wt %||% NA_character_))
    rows[[length(rows) + 1L]] <- data.table(seat = seat_names[i], name = cand,
                                            party_raw = party, votes = votes)
  }
  # Formal-vote reconciliation, same discipline as fetch_preferences_qld2017.R.
  formal <- as.numeric(gsub(",", "", parts_j[[first_formal]]$template$params$votes$wt %||% NA_character_))
  got <- sum(vapply(rows[(length(rows) - length(cand_idx) + 1L):length(rows)],
                     function(r) r$votes, numeric(1)))
  if (!is.finite(formal) || !is.finite(got) || got != formal)
    stop(seat_names[i], ": first-preference votes sum to ", got,
         " but the table's own formal-vote count is ", formal)

  hold_idx <- which(grepl("^Election box (hold|gain) AU party$", tnames))
  if (!length(hold_idx))
    stop(seat_names[i], ": no 'Election box hold/gain' template -- no declared winner")
  winner_party <- un_html(parts_j[[hold_idx[1]]]$template$params$winner$wt %||% NA_character_)
  wins[[length(wins) + 1L]] <- data.table(election = "sa2018", seat = seat_names[i],
                                          winner_raw = winner_party)
}

fp <- rbindlist(rows)
if (fp[is.na(votes), .N])
  stop(fp[is.na(votes), .N], " candidates have no parsed vote count")
cat(sprintf("SW3  %d candidates across %d seats\n", nrow(fp), uniqueN(fp$seat)))

fp[, party := classify_party(party_raw)]
fwrite(fp[order(seat, -votes)], file.path(OUT, "wikipedia-2018-sa-firstprefs.csv"))
cat(sprintf("SW4  wrote %s\n", file.path(OUT, "wikipedia-2018-sa-firstprefs.csv")))

st <- fp[, .(v = sum(votes)), by = party][, pct := round(100 * v / sum(v), 2)][order(-pct)]
cat("\nSW5  statewide first preferences (Wikipedia, this fetch)\n")
print(st)

# ANCHOR CHECK against external/aus-polling-analyser/analysis/Data/eventual-results.csv,
# independent of this scrape. Wikipedia's own infobox (checked by hand while
# writing this fetcher) agrees with the anchor to within rounding on every
# party: LNP 37.97 vs 38.0, ALP 32.79 vs 32.8, GRN 6.66 vs 6.7, and OTH here
# (everything but the big three) sums to 22.58 against the anchor's 22.5 --
# the 0.08-point gap is rounding in the anchor's own OTH figure, not a miss.
anchor_f <- "external/aus-polling-analyser/analysis/Data/eventual-results.csv"
if (file.exists(anchor_f)) {
  anc <- fread(anchor_f, header = FALSE, fill = Inf)
  setnames(anc, 1:4, c("year", "region", "series", "value"))
  anc18 <- anc[year == 2018 & region == "sa"]
  chk <- list(c("LNP", "LNP FP"), c("ALP", "ALP FP"), c("GRN", "GRN FP"))
  bad <- character(0)
  for (pr in chk) {
    got <- st[party == pr[1], pct]
    want <- anc18[series == pr[2], value]
    if (!length(got) || !length(want) || abs(got - want) > 0.5)
      bad <- c(bad, sprintf("%s: got %.2f%%, anchor %.2f%%", pr[1],
                            if (length(got)) got else NA, if (length(want)) want else NA))
  }
  oth_got <- sum(st[!party %in% c("ALP", "LNP", "GRN"), pct])
  oth_want <- anc18[series == "OTH FP", value]
  if (length(oth_want) && abs(oth_got - oth_want) > 1.0)
    bad <- c(bad, sprintf("OTH (non ALP/LNP/GRN): got %.2f%%, anchor %.2f%%", oth_got, oth_want))
  if (length(bad))
    stop("sa2018 statewide totals disagree with the anchor's eventual-results.csv:\n  ",
         paste(bad, collapse = "\n  "))
  cat(sprintf("SW6  anchor check passes: LNP %.2f/%.2f, ALP %.2f/%.2f, GRN %.2f/%.2f, OTH %.2f/%.2f\n",
              st[party == "LNP", pct], anc18[series == "LNP FP", value],
              st[party == "ALP", pct], anc18[series == "ALP FP", value],
              st[party == "GRN", pct], anc18[series == "GRN FP", value],
              oth_got, oth_want))
} else {
  cat("SW6! anchor file not found at ", anchor_f, " -- skipped, NOT verified\n")
}

win <- rbindlist(wins)
win[, winner := classify_party(winner_raw)]
if (nrow(win) != 47L) stop("Parsed ", nrow(win), " winners, not 47")
fwrite(win[order(seat), .(election, seat, winner)],
       file.path(OUT, "wikipedia-2018-sa-winners.csv"))
cat(sprintf("\nSW7  wrote %s\n", file.path(OUT, "wikipedia-2018-sa-winners.csv")))
print(win[, .N, by = winner][order(-N)])
