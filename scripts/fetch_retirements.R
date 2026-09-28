# Fetch and parse Wikipedia "Retiring members" sections for every election
# pair used to derive the seat file's `retirement` flag.
#
# WHY. CLAUDE.md ("Store the raw response, never the summary you happen to
# want today"): the candidate-list derivation (build_retirement_derived.py)
# can only say a sitting member did not recontest, never WHY. This script
# gets the reason from each election's Wikipedia article and, per the same
# rule, saves the RAW page HTML to disk before parsing anything out of it --
# a re-fetch is rate-limited and may be unavailable later, a disk write is
# free.
#
# Re-runnable: skips any raw HTML already on disk. Sleeps ~1s between live
# requests only (never between cache hits), and sends a real UA per
# Wikipedia's policy.
#
# LOWER HOUSE ONLY. Every election here is scored against the candidate-level
# seat model, which is Assembly/House (division) level. Upper-house members
# (Senators federally, MLCs in every state) are filtered out even where
# Wikipedia lists them in the same "Retiring members" section.
options(auspol.root = normalizePath("."))
suppressMessages(library(httr))
suppressMessages(library(rvest))
suppressMessages(library(xml2))
suppressMessages(library(data.table))

RAW_DIR <- "external/reference/retirements/raw"
OUT_CSV <- "external/reference/retirements/retirements.csv"
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)

UA <- "auspol-research/1.0 (https://github.com/peteowen1/auspol; fptpost@gmail.com) R httr"

# election -> Wikipedia article title. nsw2023's own article page transcludes
# its "Retiring MPs" list from a separate article via {{Excerpt}} -- the
# transcluded content is NOT present in the parent page's served HTML (only a
# hatnote pointing at it), so we fetch the source page under its own key.
PAGES <- c(
  fed2004 = "2004 Australian federal election",
  fed2007 = "2007 Australian federal election",
  fed2010 = "2010 Australian federal election",
  fed2013 = "2013 Australian federal election",
  fed2016 = "2016 Australian federal election",
  fed2019 = "2019 Australian federal election",
  fed2022 = "2022 Australian federal election",
  fed2025 = "2025 Australian federal election",
  nsw2015 = "2015 New South Wales state election",
  nsw2019 = "2019 New South Wales state election",
  nsw2023 = "2023 New South Wales state election",
  `nsw2023-candidates` = "Candidates of the 2023 New South Wales state election",
  qld2017 = "2017 Queensland state election",
  qld2020 = "2020 Queensland state election",
  qld2024 = "2024 Queensland state election",
  sa2018  = "2018 South Australian state election",
  sa2022  = "2022 South Australian state election",
  sa2026  = "2026 South Australian state election",
  vic2010 = "2010 Victorian state election",
  vic2014 = "2014 Victorian state election",
  vic2018 = "2018 Victorian state election",
  vic2022 = "2022 Victorian state election",
  vic2026 = "2026 Victorian state election",
  wa1996  = "1996 Western Australian state election",
  wa2001  = "2001 Western Australian state election",
  wa2005  = "2005 Western Australian state election",
  wa2008  = "2008 Western Australian state election",
  wa2013  = "2013 Western Australian state election",
  wa2017  = "2017 Western Australian state election",
  wa2021  = "2021 Western Australian state election",
  wa2025  = "2025 Western Australian state election"
)

is_federal <- function(election) grepl("^fed", election)
page_url <- function(title) paste0("https://en.wikipedia.org/wiki/", utils::URLencode(gsub(" ", "_", title)))

# ---------------------------------------------------------------- fetching --

fetch_raw <- function(key, title) {
  dest <- file.path(RAW_DIR, paste0(key, ".html"))
  if (file.exists(dest) && file.info(dest)$size > 1000) {
    return(invisible(dest))
  }
  resp <- httr::GET(page_url(title), httr::user_agent(UA), httr::timeout(30))
  if (httr::status_code(resp) != 200) {
    stop(sprintf("%s: HTTP %d fetching %s", key, httr::status_code(resp), page_url(title)))
  }
  writeBin(httr::content(resp, as = "raw"), dest)
  message(sprintf("fetched %s -> %s (%d bytes)", key, dest, file.info(dest)$size))
  Sys.sleep(1)
  invisible(dest)
}

for (k in names(PAGES)) {
  already <- file.exists(file.path(RAW_DIR, paste0(k, ".html")))
  tryCatch(
    fetch_raw(k, PAGES[[k]]),
    error = function(err) message(sprintf("FAILED %s: %s", k, conditionMessage(err)))
  )
}

# ----------------------------------------------------------------- parsing --
# Wikipedia's "Retiring members"/"Retiring MPs" sections are, on every page
# checked, one or more <ul> lists (grouped by party under h3 subheadings)
# immediately following the matching h2/h3 heading, each <li> reading
# roughly "Name TITLE (Seat[, State]) [– note]" with citation <sup> markers
# to strip. We walk siblings of the heading's wrapper div until the next
# heading of h2 level, collect every <li>, and drop upper-house members
# (Senator.../ "MLC") since the seat model is lower-house only.

HEADING_CANDIDATES <- c(
  "^Retiring members$", "^Retiring MPs$", "^Retiring MPs and senators$",
  "^Candidates and retiring MPs$"
)

find_heading <- function(doc) {
  h <- doc %>% html_elements("h2,h3,h4")
  txt <- trimws(h %>% html_text2())
  for (pat in HEADING_CANDIDATES) {
    idx <- which(grepl(pat, txt))
    if (length(idx)) return(h[[idx[1]]])
  }
  NULL
}

collect_party_sections <- function(heading_node) {
  # Returns a list of list(party = <h3 text or NA>, lis = <xml_nodeset>)
  parent <- xml2::xml_parent(heading_node) # div.mw-heading wrapper
  sib <- parent
  out <- list()
  for (k in 1:60) {
    sib <- tryCatch(xml2::xml_find_first(sib, "following-sibling::*[1]"), error = function(e) NA)
    if (length(sib) == 0 || is.na(sib)) break
    nm <- xml2::xml_name(sib)
    cls <- xml2::xml_attr(sib, "class")
    if (nm == "div" && !is.na(cls) && grepl("mw-heading2", cls)) break
    if (nm == "section") {
      h3 <- xml2::xml_find_first(sib, ".//h3|.//h4")
      party <- if (length(h3) && !is.na(h3)) html_text2(h3) else NA_character_
      lis <- xml2::xml_find_all(sib, ".//li")
      if (length(lis)) out[[length(out) + 1]] <- list(party = party, lis = lis)
    } else {
      lis <- xml2::xml_find_all(sib, ".//li")
      if (length(lis)) out[[length(out) + 1]] <- list(party = NA_character_, lis = lis)
    }
  }
  out
}

clean_li_text <- function(li) {
  # re-parse this node's own HTML into an independent doc so removing <sup>
  # citation markers doesn't mutate the shared page tree
  li2 <- xml2::read_html(paste0("<html><body>", as.character(li), "</body></html>"))
  for (s in xml2::xml_find_all(li2, "//sup")) xml2::xml_remove(s)
  trimws(html_text2(xml2::xml_find_first(li2, "//li")))
}

STATE_TOKENS <- c("NSW", "VIC", "QLD", "WA", "SA", "TAS", "NT", "ACT")
PARTY_WORDS <- c(
  "Labor", "Liberal", "Nationals", "National", "Greens", "Independent",
  "One Nation", "Palmer United", "Katter's Australian Party",
  "Shooters, Fishers and Farmers", "Liberal Democrats", "Legalise Cannabis",
  "Animal Justice Party", "Country Liberal", "WA Nationals"
)

parse_line <- function(raw) {
  # Split off the first parenthetical and, after it, a dash-led note.
  m <- regexpr("\\(([^)]*)\\)", raw)
  if (m[1] == -1) {
    parts <- strsplit(raw, "\\s[\u2013\u2014-]\\s", perl = TRUE)[[1]]
    namepart <- trimws(parts[1])
    paren <- NA_character_
    note <- if (length(parts) > 1) trimws(paste(parts[-1], collapse = " - ")) else ""
  } else {
    paren <- trimws(substr(raw, m[1] + 1, m[1] + attr(m, "match.length") - 2))
    namepart <- trimws(substr(raw, 1, m[1] - 1))
    rest <- trimws(substr(raw, m[1] + attr(m, "match.length"), nchar(raw)))
    rest <- sub("^[\u2013\u2014-]\\s*", "", rest)
    note <- trimws(rest)
  }
  # upper-house filter: MLC or a name-line starting "Senator "
  is_upper <- grepl("\\bMLC\\b", namepart) || grepl("^Senator\\b", trimws(raw))
  # strip trailing title token off the name
  title <- NA_character_
  mt <- regmatches(namepart, regexpr("\\s+(MP|MLA|MHA|MLC)$", namepart))
  if (length(mt) && nzchar(mt)) {
    title <- trimws(mt)
    namepart <- trimws(sub("\\s+(MP|MLA|MHA|MLC)$", "", namepart))
  }
  namepart <- sub("^Senator\\s+", "", namepart)

  seat <- NA_character_
  state <- NA_character_
  party_from_paren <- NA_character_
  if (!is.na(paren) && nzchar(paren)) {
    bits <- strsplit(paren, ",")[[1]]
    bits <- trimws(bits)
    seat <- bits[1]
    if (length(bits) > 1) {
      second <- bits[2]
      second_tok <- trimws(strsplit(second, ";")[[1]][1])
      if (toupper(second_tok) %in% STATE_TOKENS) {
        state <- second_tok
      } else if (any(sapply(PARTY_WORDS, function(p) grepl(p, second_tok, fixed = TRUE)))) {
        party_from_paren <- second_tok
      } else if (nzchar(second_tok)) {
        note <- if (nzchar(note)) paste0(second_tok, "; ", note) else second_tok
      }
    }
  }
  list(is_upper = is_upper, member = namepart, title = title, seat = seat,
       state = state, party_from_paren = party_from_paren, note = note)
}

classify_reason <- function(note) {
  n <- tolower(note)
  if (!nzchar(trimws(n))) return("retired")
  if (grepl("preselection", n) && !grepl("did not nominate|did not seek", n)) return("lost_preselection")
  if (grepl("senate|legislative council|upper house", n) &&
      grepl("contest|running|stand|move|switch|transfer", n)) return("contested_other_house")
  if (grepl("seat of |division of |electoral district of |contest.*instead|renominat|stand(ing)? in |run(ning)? in ", n) &&
      !grepl("did not (re-?)?contest|will not (re-?)?contest|not (re-?)?contest", n)) return("contested_other_seat")
  if (grepl("resign|died|deceased|passed away", n)) return("resigned_or_died_before")
  if (grepl("announce|retir|not (re-?)?contest|not stand|not run|did not nominate|stepping down|dumped", n)) return("retired")
  "other"
}

parse_election <- function(key, election, title) {
  f <- file.path(RAW_DIR, paste0(key, ".html"))
  if (!file.exists(f)) return(NULL)
  doc <- read_html(f)
  hn <- find_heading(doc)
  if (is.null(hn)) return(NULL)
  sections <- collect_party_sections(hn)
  url <- page_url(title)
  rows <- list()
  for (sec in sections) {
    for (li in sec$lis) {
      raw <- clean_li_text(li)
      if (!nzchar(raw)) next
      p <- parse_line(raw)
      if (p$is_upper) next
      if (is.na(p$member) || !nzchar(p$member)) next
      # the paren-stated party (e.g. "(Balmain, Greens)") is more specific
      # than a generic bucket heading like "Other"; prefer it when present
      sec_party <- if (!is.na(sec$party) && sec$party %in% c("Other", "")) NA_character_ else sec$party
      party <- if (!is.na(p$party_from_paren)) p$party_from_paren else sec_party
      rows[[length(rows) + 1]] <- data.table(
        election = election, seat = ifelse(is.na(p$seat), "", p$seat),
        member = p$member, party = ifelse(is.na(party), "", party),
        reason = classify_reason(p$note), note = p$note, source_url = url
      )
    }
  }
  if (!length(rows)) return(NULL)
  rbindlist(rows)
}

ELECTION_SOURCE <- data.table(
  election = names(PAGES),
  src_key = names(PAGES)
)
# nsw2023's real list lives on the candidates page, not the election page.
ELECTION_SOURCE[election == "nsw2023", src_key := "nsw2023-candidates"]
ELECTION_SOURCE <- ELECTION_SOURCE[election != "nsw2023-candidates"]

parsed <- list()
for (i in seq_len(nrow(ELECTION_SOURCE))) {
  e <- ELECTION_SOURCE$election[i]
  k <- ELECTION_SOURCE$src_key[i]
  res <- tryCatch(parse_election(k, e, PAGES[[k]]),
                   error = function(err) { message(sprintf("PARSE FAILED %s: %s", e, conditionMessage(err))); NULL })
  if (!is.null(res)) parsed[[e]] <- res else message(sprintf("%s: no 'Retiring members' list found on Wikipedia (or none matched the lower house)", e))
}

# ---------------------------------------------------- nsw2015: prose, not a
# list -- Wikipedia's "Retiring members" section for this election is three
# paragraphs of prose (no <li> at all). Hand-transcribed from
# external/reference/retirements/raw/nsw2015.html (fetched above), Legislative
# Assembly members only (four Legislative Council mentions -- Charlie Lynn,
# Jenny Gardiner, Marie Ficarra, Amanda Fazio -- excluded, upper house).
nsw2015_url <- page_url(PAGES[["nsw2015"]])
nsw2015 <- data.table(
  election = "nsw2015", source_url = nsw2015_url,
  seat    = c("Ku-ring-gai","Epping","Ballina","Maitland","Upper Hunter","Oxley",
              "Londonderry","Port Stephens","Terrigal","The Entrance","Wyong",
              "Auburn","Toongabbie","Marrickville","Mount Druitt","Kogarah",
              "Miranda","Lakemba","Macquarie Fields"),
  member  = c("Barry O'Farrell","Greg Smith","Don Page","Robyn Parker","George Souris","Andrew Stoner",
              "Bart Bassett","Craig Baumann","Chris Hartcher","Christopher Spence","Darren Webber",
              "Barbara Perry","Nathan Rees","Carmel Tebbutt","Richard Amery","Cherie Burton",
              "Barry Collier","Robert Furolo","Andrew McDonald"),
  party   = c("Liberal","Liberal","Nationals","Liberal","Nationals","Nationals",
              "Liberal","Liberal","Liberal","Liberal","Liberal",
              "Labor","Labor","Labor","Labor","Labor","Labor","Labor","Labor"),
  reason  = c("retired","retired","retired","retired","retired","retired",
              "other","other","other","other","other",
              "lost_preselection","retired","retired","retired","retired","retired","retired","retired"),
  note    = c("Did not re-contest his seat (former Premier)","Dumped former minister; did not re-contest",
              "Did not re-contest","Dumped former minister; did not re-contest","Dumped former minister; did not re-contest",
              "Dumped former minister; did not re-contest",
              "Implicated by Operation Spicer ICAC inquiry; announced would not re-contest",
              "Implicated by Operation Spicer ICAC inquiry; announced would not re-contest",
              "Implicated by Operation Spicer ICAC inquiry; announced would not re-contest",
              "Implicated by Operation Spicer ICAC inquiry; announced would not re-contest",
              "Implicated by Operation Spicer ICAC inquiry; announced would not re-contest",
              "Facing a preselection challenge for Auburn, withdrew to allow Luke Foley's nomination unopposed",
              "Former Premier; announced intention to quit politics","Former Deputy Premier; announced intention to quit politics",
              "Father of the House; announced intention to quit politics","Announced intention to quit politics",
              "Announced intention to quit politics","Announced intention to quit politics","Announced intention to quit politics")
)
parsed[["nsw2015"]] <- nsw2015

all_rows <- rbindlist(parsed, use.names = TRUE, fill = TRUE)
all_rows <- unique(all_rows, by = c("election", "seat", "member"))
setorder(all_rows, election, seat)

dir.create(dirname(OUT_CSV), recursive = TRUE, showWarnings = FALSE)
fwrite(all_rows, OUT_CSV)

message()
message(sprintf("wrote %s: %d rows across %d elections", OUT_CSV, nrow(all_rows), uniqueN(all_rows$election)))
print(all_rows[, .N, by = .(election)][order(election)])
print(all_rows[, .N, by = .(reason)][order(-N)])

no_list <- setdiff(names(PAGES), c("nsw2023-candidates", unique(all_rows$election)))
if (length(no_list)) message("No Wikipedia retiring-members list found for: ", paste(no_list, collapse = ", "))
