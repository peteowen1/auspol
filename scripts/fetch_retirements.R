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
  wa2025  = "2025 Western Australian state election",

  # -------------------------------------------------------------- GAP FILL --
  # Eight elections (fed2004, fed2007, fed2010, sa2022, wa1996, wa2001,
  # wa2005, wa2008) have no "Retiring members" section on their own election
  # page. For these, per CLAUDE.md's "store the raw response" rule, we fetch
  # and cache BOTH the "Members of ..." page for the term ENDING at that
  # election (usually just a term-dates table, no reasons) and, where it
  # exists, the "Candidates of ..." page (usually carries a "Retiring
  # Members and Senators" list, sometimes with reasons, sometimes not). Where
  # neither gives a reason, the reason was sourced from the individual
  # member's own Wikipedia biography page (not cached here -- there are up to
  # 23 per election -- see source_url on each hand-curated row below for the
  # exact page a reason came from).
  fed2004_members    = "Members of the Australian House of Representatives, 2001–2004",
  fed2004_candidates = "Candidates of the 2004 Australian federal election",
  fed2007_members    = "Members of the Australian House of Representatives, 2004–2007",
  fed2007_candidates = "Candidates of the 2007 Australian federal election",
  fed2010_members    = "Members of the Australian House of Representatives, 2007–2010",
  fed2010_candidates = "Candidates of the 2010 Australian federal election",
  sa2022_members     = "Members of the South Australian House of Assembly, 2018–2022",
  sa2022_candidates  = "Candidates of the 2022 South Australian state election",
  wa1996_members     = "Members of the Western Australian Legislative Assembly, 1993–1996",
  wa1996_candidates  = "Candidates of the 1996 Western Australian state election",
  wa2001_members     = "Members of the Western Australian Legislative Assembly, 1996–2001",
  wa2001_candidates  = "Candidates of the 2001 Western Australian state election",
  wa2005_members     = "Members of the Western Australian Legislative Assembly, 2001–2005",
  wa2005_candidates  = "Candidates of the 2005 Western Australian state election",
  wa2008_members     = "Members of the Western Australian Legislative Assembly, 2005–2008",
  wa2008_candidates  = "Candidates of the 2008 Western Australian state election"
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
# The 16 gap-fill "Members of ..."/"Candidates of ..." pages added above are
# fetched (raw HTML cached) but never carry a "Retiring members" HEADING
# themselves -- their data is hand-curated below (like nsw2015), sourced from
# them plus individual member bio pages. Excluding them here stops
# parse_election() attempting (and failing) to find a heading on each.
ELECTION_SOURCE <- ELECTION_SOURCE[!grepl("_members$|_candidates$", election)]

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

# ------------------------------------------------------ eight-election gap --
# fed2004, fed2007, fed2010, sa2022, wa1996, wa2001, wa2005, wa2008 have no
# "Retiring members" section on their own Wikipedia election page. Hand-
# curated from the "Members of ..." / "Candidates of ..." pages fetched above
# (external/reference/retirements/raw/*_members.html, *_candidates.html) plus
# individual member biography pages where a page carried no reason of its
# own -- each row's source_url is the specific page the reason came from.
# LOWER HOUSE, sitting-at-dissolution members only: anyone replaced by a
# pre-election by-election is excluded (their seat had a different incumbent
# contesting), matching the scope of the Wikipedia-list parser above.
CAND2004 <- "https://en.wikipedia.org/wiki/Candidates_of_the_2004_Australian_federal_election"
CAND2007 <- "https://en.wikipedia.org/wiki/Candidates_of_the_2007_Australian_federal_election"
CAND2010 <- "https://en.wikipedia.org/wiki/Candidates_of_the_2010_Australian_federal_election"
CANDWA1996 <- "https://en.wikipedia.org/wiki/Candidates_of_the_1996_Western_Australian_state_election"

gap_fill_txt <- r"(election|seat|member|party|reason|note|source_url
fed2004|Kingsford Smith|Laurie Brereton|Labor|retired|Announced retirement from politics in June 2004|CAND2004
fed2004|Prospect|Janice Crosio|Labor|retired|Retired at the 2004 election; no reason stated|CAND2004
fed2004|Watson|Leo McLeay|Labor|retired|Retired from parliament at the 2004 election; no reason stated|CAND2004
fed2004|Greenway|Frank Mossfield|Labor|retired|Retired at the 2004 election; no reason stated|CAND2004
fed2004|Wakefield|Neil Andrew|Liberal|retired|Notified the PM in February 2004 he would not renominate, after redistribution turned his seat notionally Labor|CAND2004
fed2004|La Trobe|Bob Charles|Liberal|retired|Retired at the 2004 election; no reason stated|CAND2004
fed2004|Hindmarsh|Chris Gallus|Liberal|retired|Retired at the 2004 election, replaced as Liberal candidate by Simon Birmingham|CAND2004
fed2004|Goldstein|David Kemp|Liberal|retired|Retired at the 2004 election; no reason stated|CAND2004
fed2004|Tangney|Daryl Williams|Liberal|retired|Announced in April 2004 he would not contest the 2004 election|CAND2004
fed2004|Bowman|Con Sciacca|Labor|contested_other_seat|After redistribution made Bowman notionally Liberal, contested the new Division of Bonner instead; Bowman itself continued and was contested by a different Labor candidate|https://en.wikipedia.org/wiki/Con_Sciacca
fed2007|Brand|Kim Beazley|Labor|retired|Announced retirement 13 December 2006 after losing the Labor leadership|CAND2007
fed2007|Isaacs|Ann Corcoran|Labor|lost_preselection|Lost preselection in March 2006|CAND2007
fed2007|Cowan|Graham Edwards|Labor|retired|Announced retirement in January 2006|CAND2007
fed2007|Blaxland|Michael Hatton|Labor|lost_preselection|Lost preselection in May 2007|CAND2007
fed2007|Charlton|Kelly Hoare|Labor|lost_preselection|Lost preselection in May 2007|CAND2007
fed2007|Fremantle|Carmen Lawrence|Labor|retired|Announced retirement in March 2007|CAND2007
fed2007|Port Adelaide|Rod Sawford|Labor|retired|Announced retirement in August 2006|CAND2007
fed2007|Maribyrnong|Bob Sercombe|Labor|retired|Announced retirement in February 2006|CAND2007
fed2007|Cook|Bruce Baird|Liberal|retired|Announced retirement in April 2007|CAND2007
fed2007|Mitchell|Alan Cadman|Liberal|lost_preselection|Withdrew candidacy in June 2007 while facing a likely preselection defeat|CAND2007
fed2007|Makin|Trish Draper|Liberal|retired|Announced retirement in July 2006|CAND2007
fed2007|Forde|Kay Elson|Liberal|retired|Announced retirement in October 2006|CAND2007
fed2007|Leichhardt|Warren Entsch|Liberal|retired|Announced retirement in January 2006|CAND2007
fed2007|Fadden|David Jull|Liberal|retired|Announced retirement in January 2007|CAND2007
fed2007|Lindsay|Jackie Kelly|Liberal|retired|Announced retirement in May 2007|CAND2007
fed2007|Forrest|Geoff Prosser|Liberal|retired|Announced retirement in June 2006|CAND2007
fed2007|Grey|Barry Wakelin|Liberal|retired|Announced retirement in August 2006|CAND2007
fed2007|Gwydir|John Anderson|National|retired|Announced retirement after stepping down as National Party leader|CAND2007
fed2007|Page|Ian Causley|National|retired|Announced retirement in October 2006|CAND2007
fed2007|Calare|Peter Andren|Independent|resigned_or_died_before|Stood down from Calare 29 March 2007 to contest the NSW Senate; abandoned that bid after a cancer diagnosis 10 August 2007; died 3 November 2007, after the 17 October dissolution and before the 24 November election; no by-election held|https://en.wikipedia.org/wiki/Peter_Andren
fed2007|Franklin|Harry Quick|Independent|retired|Announced 12 August 2005 he would not contest the next election, citing factional disputes; expelled from Labor 20 August 2007 for non-payment of dues and sat as an independent until the election|https://en.wikipedia.org/wiki/Harry_Quick
fed2010|Dawson|James Bidgood|Labor|retired|Announced retirement 5 February 2010|CAND2010
fed2010|Bass|Jodie Campbell|Labor|retired|Announced retirement 30 October 2009|CAND2010
fed2010|Macquarie|Bob Debus|Labor|retired|Announced retirement 5 June 2009|CAND2010
fed2010|Canberra|Annette Ellis|Labor|retired|Announced retirement 22 January 2010|CAND2010
fed2010|Throsby|Jennie George|Labor|retired|Announced retirement 19 November 2009|CAND2010
fed2010|Fowler|Julia Irwin|Labor|retired|Announced retirement 14 September 2009|CAND2010
fed2010|Denison|Duncan Kerr|Labor|retired|Announced retirement 10 September 2009|CAND2010
fed2010|Fraser|Bob McMullan|Labor|retired|Announced retirement 19 January 2010|CAND2010
fed2010|Robertson|Belinda Neal|Labor|lost_preselection|Lost preselection 6 March 2010, then announced retirement 29 July 2010|CAND2010
fed2010|Chifley|Roger Price|Labor|retired|Announced retirement 19 March 2010|CAND2010
fed2010|Melbourne|Lindsay Tanner|Labor|retired|Announced retirement 24 June 2010|CAND2010
fed2010|McEwen|Fran Bailey|Liberal|retired|Announced retirement 7 October 2009|CAND2010
fed2010|Macarthur|Pat Farmer|Liberal|lost_preselection|Lost preselection 30 October 2009, then announced retirement 15 February 2010|CAND2010
fed2010|Kooyong|Petro Georgiou|Liberal|retired|Announced retirement 23 November 2008|CAND2010
fed2010|Wannon|David Hawker|Liberal|retired|Announced retirement 1 June 2009|CAND2010
fed2010|Herbert|Peter Lindsay|Liberal|retired|Announced retirement 27 January 2010|CAND2010
fed2010|McPherson|Margaret May|Liberal|retired|Announced retirement 14 August 2009|CAND2010
fed2010|Aston|Chris Pearce|Liberal|retired|Announced retirement 23 June 2009|CAND2010
fed2010|Hughes|Danna Vale|Liberal|retired|Announced retirement 4 August 2009|CAND2010
fed2010|Riverina|Kay Hull|National|retired|Announced retirement 6 April 2010|CAND2010
fed2010|Greenway|Louise Markus|Liberal|contested_other_seat|Transferred to contest Macquarie instead of recontesting Greenway; Michelle Rowland won Greenway for Labor|https://en.wikipedia.org/wiki/Division_of_Greenway
fed2010|Reid|Laurie Ferguson|Labor|contested_other_seat|Did not recontest Reid; transferred to contest Werriwa instead; John Murphy won the redrawn Reid|https://en.wikipedia.org/wiki/Division_of_Reid
fed2010|Werriwa|Chris Hayes|Labor|contested_other_seat|Did not recontest Werriwa; transferred to contest Fowler instead; Laurie Ferguson won Werriwa|https://en.wikipedia.org/wiki/Division_of_Werriwa
sa2022|Florey|Frances Bedford|Independent|contested_other_seat|Redistribution shifted her Florey base into Newland; contested Newland instead of Florey and came third; Florey was won by Labor|https://www.abc.net.au/news/2021-10-10/sa-independent-frances-bedford-moves-from-florey-to-newland/100527874
sa2022|Frome|Geoff Brock|Independent|contested_other_seat|Redistribution moved his Port Pirie base into Stuart; contested and won Stuart rather than recontesting Frome, which was won by Liberal Penny Pratt|https://www.abc.net.au/news/2020-11-20/sa-electoral-redistribution-will-see-popular-mps-go-head-to-head/12901336
sa2022|Taylor|Jon Gee|Labor|retired|Retiring Labor MP; did not recontest Taylor, succeeded by Nick Champion|https://en.wikipedia.org/wiki/Jon_Gee
sa2022|Schubert|Stephan Knoll|Liberal|retired|Announced 1 December 2020 he would not contest the 2022 election, after resigning from Cabinet amid a since-cleared accommodation-allowance scandal|https://www.abc.net.au/news/2020-12-01/former-sa-transport-minister-stephan-knoll-to-quit/12940358
sa2022|Flinders|Peter Treloar|Liberal|retired|Announced he would not seek re-election after three terms|https://www.stockjournal.com.au/story/7035866/treloar-to-retire-from-parliament/
wa1996|Rockingham|Mike Barnett|Labor|retired|Retired from parliament at the 1996 election; no reason stated|https://en.wikipedia.org/wiki/Mike_Barnett_(politician)
wa1996|Vasse|Barry Blaikie|Liberal|retired|Left parliament at the 1996 election, replaced by Bernie Masters, having been Father of the House|https://en.wikipedia.org/wiki/Barry_Blaikie
wa1996|Balcatta|Nick Catania|Labor|contested_other_seat|Balcatta abolished in the 1996 redistribution; unsuccessfully contested the new seat of Yokine instead|https://en.wikipedia.org/wiki/Electoral_district_of_Balcatta
wa1996|Marmion|Jim Clarko|Liberal|retired|Named on the Wikipedia 1996 retiring-members list; no reason stated|CANDWA1996
wa1996|Armadale|Kay Hallahan|Labor|retired|Retired at the 1996 election, succeeded by Alannah MacTiernan|https://en.wikipedia.org/wiki/Kay_Hallahan
wa1996|Thornlie|Yvonne Henderson|Labor|retired|Retired at the 1996 election; no reason stated|https://en.wikipedia.org/wiki/Yvonne_Henderson
wa1996|Northern Rivers|Kevin Leahy|Labor|contested_other_seat|Seat redrawn/renamed Ningaloo in the 1994 redistribution; ran there as Labor candidate, led on primary vote but lost on two-party-preferred|https://en.wikipedia.org/wiki/Electoral_results_for_the_district_of_Ningaloo
wa1996|Applecross|Richard Lewis|Liberal|retired|Retired at the 1996 election, did not contest|https://en.wikipedia.org/wiki/Richard_Lewis_(Australian_politician)
wa1996|Mitchell|David Smith|Labor|retired|Remained in parliament until his retirement at the 1996 election|https://en.wikipedia.org/wiki/David_Smith_(Western_Australian_politician)
wa1996|Wanneroo|Wayde Smith|Liberal|lost_preselection|Lost preselection for the 1996 election amid controversy over the operation of Wanneroo City Council|https://en.wikipedia.org/wiki/Wayde_Smith
wa1996|Kenwick|Judyth Watson|Labor|contested_other_seat|Kenwick abolished in the 1996 redistribution; unsuccessfully contested the new seat of Southern River instead|https://en.wikipedia.org/wiki/Electoral_district_of_Kenwick
wa2001|Girrawheen|Ted Cunningham|Labor|retired|Retired in 2001; no reason stated|https://en.wikipedia.org/wiki/Ted_Cunningham
wa2001|Eyre|Julian Grill|Labor|retired|Retired from politics in 2001 and did not contest the 2001 election|https://en.wikipedia.org/wiki/Julian_Grill
wa2001|Cockburn|Bill Thomas|Labor|retired|Stepped down from the front bench in 1999 and retired from politics in 2001|https://en.wikipedia.org/wiki/Bill_Thomas_(Australian_politician)
wa2001|Perth|Diana Warnock|Labor|retired|Re-elected in 1996 but did not contest the February 2001 election; no reason stated|https://en.wikipedia.org/wiki/Diana_Warnock
wa2001|Greenough|Kevin Minson|Liberal|retired|Stepped down from the front bench in 1997 and retired in 2001|https://en.wikipedia.org/wiki/Kevin_Minson
wa2001|Innaloo|George Strickland|Liberal|retired|Listed on the Wikipedia 2001 retiring-members list; no reason stated|https://en.wikipedia.org/wiki/Candidates_of_the_2001_Western_Australian_state_election
wa2001|Wagin|Bob Wiese|National|retired|Member for Wagin 1989-2001, listed as retiring; no reason stated, succeeded by Terry Waldron|https://en.wikipedia.org/wiki/Candidates_of_the_2001_Western_Australian_state_election
wa2001|Kimberley|Ernie Bridge|Independent|retired|Retired at the 2001 election after 21 years representing Kimberley; no reason stated|https://en.wikipedia.org/wiki/Ernie_Bridge
wa2005|Bassendean|Clive Brown|Labor|retired|Announced intention to retire in 2004, citing a desire to enter business|https://en.wikipedia.org/wiki/Clive_Brown
wa2005|Murdoch|Mike Board|Liberal|retired|Retired from politics in 2005; no reason stated|https://en.wikipedia.org/wiki/Mike_Board
wa2005|Murray|John Bradshaw|Liberal|retired|Served until his retirement in 2005; no reason stated|https://en.wikipedia.org/wiki/John_Bradshaw_(Australian_politician)
wa2005|Kingsley|Cheryl Edwardes|Liberal|retired|Retired from politics in 2005; no reason stated|https://en.wikipedia.org/wiki/Cheryl_Edwardes
wa2005|Dawesville|Arthur Marshall|Liberal|retired|Re-elected in 2001 and retired at the 2005 election; no reason stated|https://en.wikipedia.org/wiki/Arthur_Marshall_(Australian_politician)
wa2005|Moore|Bill McNee|Liberal|retired|Retired in 2005; no reason stated|https://en.wikipedia.org/wiki/Bill_McNee
wa2005|Ningaloo|Rod Sweetman|Liberal|lost_preselection|Ningaloo abolished (split into Murchison-Eyre and North West Coastal); chose to contest neither, instead unsuccessfully sought Liberal preselection in more winnable seats elsewhere|https://en.wikipedia.org/wiki/Rod_Sweetman
wa2005|Roe|Ross Ainsworth|National|retired|Retired at the 2005 election; seat lost to Liberal candidate Graham Jacobs|https://en.wikipedia.org/wiki/Ross_Ainsworth
wa2005|Stirling|Monty House|National|retired|Retired from politics in 2005; no reason stated|https://en.wikipedia.org/wiki/Monty_House
wa2005|Pilbara|Larry Graham|Independent|retired|Retired from politics in 2005; no reason stated|https://en.wikipedia.org/wiki/Larry_Graham_(politician)
wa2005|South Perth|Phillip Pendal|Independent|retired|Continued as independent member for South Perth until his retirement in 2005; no reason stated|https://en.wikipedia.org/wiki/Phillip_Pendal
wa2008|Murchison-Eyre|John Bowler|Independent|contested_other_seat|Seat abolished in the 2008 redistribution and split between Eyre, Kalgoorlie, North West and Pilbara; stood in and won Kalgoorlie instead|https://en.wikipedia.org/wiki/Electoral_district_of_Murchison-Eyre
wa2008|Kalgoorlie|Matt Birney|Liberal|retired|Announced 3 January 2008 he was quitting politics for the corporate world|https://en.wikipedia.org/wiki/Matt_Birney
wa2008|Maylands|Judy Edwards|Labor|retired|Retired in 2008; Lisa Baker won preselection and the seat|https://en.wikipedia.org/wiki/Judy_Edwards
wa2008|Carine|Katie Hodson-Thomas|Liberal|retired|Announced in January 2008 she would retire at the end of her term, following a leadership feud within the Liberal Party|https://en.wikipedia.org/wiki/Katie_Hodson-Thomas
wa2008|Yokine|Bob Kucera|Labor|lost_preselection|Lost Labor preselection for the new seat of Mount Lawley to Karen Brown, resigned from Labor and announced his retirement|https://en.wikipedia.org/wiki/Bob_Kucera
wa2008|Kenwick|Sheila McHale|Labor|retired|Announced in March 2008 she would retire and not contest the election|https://en.wikipedia.org/wiki/Sheila_McHale
wa2008|Warren-Blackwood|Paul Omodei|Liberal|lost_preselection|After losing the party leadership, sought Legislative Council preselection once boundary changes made his seat marginal, was placed in an unwinnable LC position and resigned from the Liberal Party rather than contest the reconfigured seat|https://en.wikipedia.org/wiki/Paul_Omodei
wa2008|Swan Hills|Jaye Radisich|Labor|other|Announced retirement to pursue postgraduate study and federal public policy interests, after concluding she would likely lose Labor preselection for the redistributed seat of West Swan|https://en.wikipedia.org/wiki/Jaye_Radisich
wa2008|North West Coastal|Fred Riebeling|Labor|retired|Retired shortly before the 2008 election; Vince Catania won preselection for the vacant seat|https://en.wikipedia.org/wiki/Fred_Riebeling
wa2008|Leschenault|Dan Sullivan|Liberal|contested_other_house|Quit the Liberal Party and unsuccessfully contested the Legislative Council South-West Region seat for Family First instead|https://en.wikipedia.org/wiki/Dan_Sullivan_(Australian_politician)
wa2008|Avon|Max Trenorden|National|contested_other_house|Stood down from the Legislative Assembly just prior to the 2008 election and contested, and won, the Legislative Council Agricultural Region seat instead|https://en.wikipedia.org/wiki/Max_Trenorden
)"

gap_fill <- fread(text = gap_fill_txt, sep = "|", header = TRUE, quote = "")
gap_fill[source_url == "CAND2004", source_url := CAND2004]
gap_fill[source_url == "CAND2007", source_url := CAND2007]
gap_fill[source_url == "CAND2010", source_url := CAND2010]
gap_fill[source_url == "CANDWA1996", source_url := CANDWA1996]
stopifnot(nrow(gap_fill) == 100, uniqueN(gap_fill$election) == 8)
parsed[["gap_fill_8_elections"]] <- gap_fill

all_rows <- rbindlist(parsed, use.names = TRUE, fill = TRUE)
all_rows <- unique(all_rows, by = c("election", "seat", "member"))
setorder(all_rows, election, seat)

dir.create(dirname(OUT_CSV), recursive = TRUE, showWarnings = FALSE)
fwrite(all_rows, OUT_CSV)

message()
message(sprintf("wrote %s: %d rows across %d elections", OUT_CSV, nrow(all_rows), uniqueN(all_rows$election)))
print(all_rows[, .N, by = .(election)][order(election)])
print(all_rows[, .N, by = .(reason)][order(-N)])

# gap-fill "_members"/"_candidates" pages are hand-curated (never expected to
# carry a "Retiring members" heading), so they're excluded from this check.
no_list <- setdiff(names(PAGES), c("nsw2023-candidates", unique(all_rows$election)))
no_list <- no_list[!grepl("_members$|_candidates$", no_list)]
if (length(no_list)) message("No Wikipedia retiring-members list found for: ", paste(no_list, collapse = ", "))
