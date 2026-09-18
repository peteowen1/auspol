# Scrapes ABC's per-seat election-guide pages for all 660 AEF7 seats and
# caches the RAW HTML (never just the parsed summary -- CLAUDE.md's rule for
# any scraped source: a re-fetch is rate-limited/unavailable, a disk write is
# free) under external/reference/abc/<election>/<slug>.html.
#
# WHY: Pete asked whether ABC's site could verify our TCP reference after
# spot-checking https://www.abc.net.au/news/elections/nsw/2023/guide/pmac --
# that one page turned out to carry the REAL Liberal-vs-National TCP
# (60.8/39.2) for a seat our own classify_party() collapses to one "LNP"
# bucket, i.e. a seat we currently EXCLUDE for lack of a pairable second
# class. 51% of our current TCP reference (334/660 rows) is fsrc="derived"
# -- reconstructed from preference-flow modelling, not the declared result --
# so a real, independently-sourced TCP for every seat is a genuine upgrade,
# not just a cross-check.
#
# Pages are static server-rendered HTML (confirmed via curl -L; no JS
# execution needed), so a plain GET + rvest parse is enough. Structure
# confirmed 2026-09-18 against pmac (nsw2023) via raw grep before writing
# any selector:
#   Primary:  h3.Candidate_partyName__* / h4.Candidate_candidateName__*
#             span.Candidate_votes__* (raw count; pct computed from the
#             count total since no per-row pct span was found in the DOM)
#   TCP ("after preferences"): h3.AfterPreferenceCandidate_candidateParty__*,
#             h4.AfterPreferenceCandidate_candidateName__*,
#             p.AfterPreferenceCandidate_votePct__* (e.g. "60.8%"),
#             p.AfterPreferenceCandidate_voteCount__* (e.g. "25,372")
# CSS-module hash suffixes (the "__d11wP" part) are build-specific and NOT
# stable across ABC deploys -- every selector below uses [class^="Prefix_"]
# (starts-with) so a future hash change doesn't silently break the parse.
#
# Emits ABCc/ABC0-ABC4 log codes. Politeness: 1 request/sec, single thread.

options(auspol.root = normalizePath("."))
suppressMessages(library(rvest)); suppressMessages(library(xml2))
suppressMessages(library(data.table)); suppressMessages(library(jsonlite))

RAW <- file.path("external", "reference", "abc")
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)
UA <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

# pair name -> ABC's own state/year path segments
ELECTIONS <- list(
  fed2022 = c(seg = "federal/2022", tag = "fed2022"),
  fed2025 = c(seg = "federal/2025", tag = "fed2025"),
  nsw2023 = c(seg = "nsw/2023",     tag = "nsw2023"),
  qld2024 = c(seg = "qld/2024",     tag = "qld2024"),
  sa2026  = c(seg = "sa/2026",      tag = "sa2026"),
  vic2022 = c(seg = "vic/2022",     tag = "vic2022"),
  wa2025  = c(seg = "wa/2025",      tag = "wa2025")
)

fetch_html <- function(url) {
  tf <- tempfile(fileext = ".html")
  on.exit(unlink(tf), add = TRUE)
  code <- suppressWarnings(system2("curl", c("-sL", "-o", tf, "-w", "%{http_code}",
                                              "-A", shQuote(UA), shQuote(url)),
                                    stdout = TRUE, stderr = FALSE))
  code <- suppressWarnings(as.integer(tail(code, 1)))
  if (is.na(code) || code != 200L || !file.exists(tf) || file.size(tf) < 1000) return(NULL)
  paste(readLines(tf, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

get_seat_slugs <- function(seg) {
  url <- sprintf("https://www.abc.net.au/news/elections/%s/guide/electorates", seg)
  html <- fetch_html(url)
  if (is.null(html)) { cat(sprintf("ABC1! failed to fetch electorate index %s\n", url)); return(character()) }
  doc <- read_html(html)
  hrefs <- html_attr(html_elements(doc, "a[href*='/guide/']"), "href")
  slugs <- unique(sub("^.*/guide/([a-z0-9-]+)/?.*$", "\\1", hrefs))
  slugs <- slugs[nchar(slugs) > 0 & slugs != "electorates" & slugs != "candidates"]
  slugs
}

parse_seat_page <- function(html, pair, seat_slug) {
  doc <- read_html(html)

  # Candidate_votes__* is already a PERCENTAGE ("39.5%"), not a count -- the
  # raw vote count lives in a separate sibling, Candidate_voteRaw__*. And
  # Candidate_partyName__* wraps TWO text nodes (shortName + longName, e.g.
  # "Liberal"+"Liberal Party"); html_text2() on the parent concatenates both,
  # so the party name is read from Candidate_longName__* alone. Both traps
  # found by dry-running this parser against a cached page before trusting
  # it at 660-page scale -- see file header.
  primary <- rbindlist(lapply(seq_along(html_elements(doc, "h4[class^='Candidate_candidateName']")), function(i) {
    party_el <- html_elements(doc, "span[class^='Candidate_longName']")
    name_el  <- html_elements(doc, "h4[class^='Candidate_candidateName']")
    pct_el   <- html_elements(doc, "span[class^='Candidate_votes__']")
    raw_el   <- html_elements(doc, "span[class^='Candidate_voteRaw']")
    if (i > length(party_el) || i > length(pct_el)) return(NULL)
    data.table(
      party = trimws(html_text2(party_el[[i]])),
      name  = trimws(html_text2(name_el[[i]])),
      pct   = suppressWarnings(as.numeric(gsub("[^0-9.]", "", html_text2(pct_el[[i]])))),
      votes = if (i <= length(raw_el)) suppressWarnings(as.numeric(gsub("[^0-9]", "", html_text2(raw_el[[i]])))) else NA_real_
    )
  }), fill = TRUE)

  tcp_name  <- html_elements(doc, "h4[class^='AfterPreferenceCandidate_candidateName']")
  tcp_party <- html_elements(doc, "h3[class^='AfterPreferenceCandidate_candidateParty']")
  tcp_pct   <- html_elements(doc, "p[class^='AfterPreferenceCandidate_votePct']")
  tcp_cnt   <- html_elements(doc, "p[class^='AfterPreferenceCandidate_voteCount']")
  tcp <- NULL
  if (length(tcp_name) == 2 && length(tcp_pct) == 2) {
    tcp <- data.table(
      party = trimws(html_text2(tcp_party)),
      name  = trimws(html_text2(tcp_name)),
      pct   = suppressWarnings(as.numeric(gsub("[^0-9.]", "", html_text2(tcp_pct)))),
      votes = if (length(tcp_cnt) == 2) suppressWarnings(as.numeric(gsub("[^0-9]", "", html_text2(tcp_cnt)))) else NA_real_
    )
  }
  list(pair = pair, seat_slug = seat_slug, primary = primary, tcp = tcp)
}

all_primary <- list()
all_tcp <- list()
n_ok <- 0L; n_fail <- 0L

for (pr in names(ELECTIONS)) {
  seg <- ELECTIONS[[pr]][["seg"]]
  outdir <- file.path(RAW, pr)
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

  slugs <- get_seat_slugs(seg)
  cat(sprintf("ABCc %s: %d seat slugs found\n", pr, length(slugs)))

  for (sl in slugs) {
    fp <- file.path(outdir, paste0(sl, ".html"))
    if (file.exists(fp) && file.size(fp) > 1000) {
      html <- paste(readLines(fp, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    } else {
      url <- sprintf("https://www.abc.net.au/news/elections/%s/guide/%s/", seg, sl)
      html <- fetch_html(url)
      if (is.null(html)) { cat(sprintf("ABC2! %s/%s failed\n", pr, sl)); n_fail <- n_fail + 1L; Sys.sleep(1); next }
      writeLines(html, fp, useBytes = TRUE)
      Sys.sleep(1)
    }
    parsed <- tryCatch(parse_seat_page(html, pr, sl), error = function(e) NULL)
    if (is.null(parsed)) { cat(sprintf("ABC3! %s/%s parse failed\n", pr, sl)); n_fail <- n_fail + 1L; next }
    if (!is.null(parsed$primary) && nrow(parsed$primary)) all_primary[[paste(pr, sl)]] <- parsed$primary[, `:=`(pair = pr, seat_slug = sl)]
    if (!is.null(parsed$tcp) && nrow(parsed$tcp)) all_tcp[[paste(pr, sl)]] <- parsed$tcp[, `:=`(pair = pr, seat_slug = sl)]
    n_ok <- n_ok + 1L
  }
  cat(sprintf("ABC0 %s done: %d/%d seats parsed so far (cumulative)\n", pr, n_ok, n_ok + n_fail))
}

primary_dt <- rbindlist(all_primary, fill = TRUE)
tcp_dt <- rbindlist(all_tcp, fill = TRUE)

fwrite(primary_dt, file.path("output", "abc-scrape-primary.csv"))
fwrite(tcp_dt, file.path("output", "abc-scrape-tcp.csv"))

cat(sprintf("ABC4 wrote output/abc-scrape-primary.csv (%d rows) and output/abc-scrape-tcp.csv (%d rows)\n",
            nrow(primary_dt), nrow(tcp_dt)))
cat(sprintf("ABC4 seats parsed OK: %d, failed: %d\n", n_ok, n_fail))
