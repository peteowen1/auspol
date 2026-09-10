# Pre-nomination candidate list for the 2026 Victorian election, from
# Wikipedia's "Candidates of the 2026 Victorian state election" (Legislative
# Assembly table). THIS IS NOT THE OFFICIAL LIST -- official nominations
# close 12 noon, 9 November 2026 (docs/NEXT-STEPS.md). It is necessarily
# partial and will change before then. Every row carries `fetched_at` so
# nobody downstream mistakes this for the final VEC-published list.
#
# Built to unblock the salience/Google-Trends pipeline (which needs actual
# candidate NAMES to search for) before nominations close, given the model
# currently has zero signal for Victoria's live independent/minor-right
# candidates. See scripts/victoria_salience_dryrun.R for the pipeline this
# feeds; on 9 November this fetcher is superseded by the real nomination
# list, same as that script's own header describes.
#
# RAW HTML IS CACHED, never just the parsed summary -- this repo's own rule
# (a Google Trends refetch disaster cost 259 batches because only a derived
# stat had been kept; the same applies to any scrape).
#
# Emits VP* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(rvest))

URL <- "https://en.wikipedia.org/wiki/Candidates_of_the_2026_Victorian_state_election"
CACHE_DIR <- file.path("external", "reference", "wikipedia")
dir.create(CACHE_DIR, showWarnings = FALSE, recursive = TRUE)
RAW <- file.path(CACHE_DIR, "vic2026-candidates-prenomination.html")

if (!file.exists(RAW) || file.size(RAW) < 1e4) {
  ok <- tryCatch({
    utils::download.file(URL, RAW, quiet = TRUE, mode = "wb",
                          headers = c("User-Agent" = "Mozilla/5.0 auspol-research"))
    TRUE
  }, error = function(e) { cat("VP1! download failed:", conditionMessage(e), "\n"); FALSE })
  if (!ok || !file.exists(RAW) || file.size(RAW) < 1e4) {
    stop("Could not fetch or verify ", URL, " -- see VP1! above")
  }
  cat(sprintf("VP1  fetched %s (%.0f KB)\n", URL, file.size(RAW)/1024))
} else {
  cat(sprintf("VP1  using cached %s (%.0f KB) -- delete it to refetch\n", RAW, file.size(RAW)/1024))
}

pg <- read_html(RAW)
tabs <- html_table(pg, fill = TRUE)

# The Legislative Assembly table is the one with an "Electorate" column and
# per-party candidate columns -- found by content, not a fixed table index,
# since Wikipedia's own table ordering on this page is not part of any
# contract with us.
la_idx <- which(vapply(tabs, function(t) "Electorate" %in% names(t) &&
                          any(grepl("candidate", names(t), ignore.case = TRUE)), logical(1)))
if (length(la_idx) != 1) {
  stop("Expected exactly one Legislative Assembly table (Electorate + candidate columns), found ",
       length(la_idx), " -- Wikipedia's page structure has changed, do not parse blindly")
}
LA <- as.data.table(tabs[[la_idx[1]]])
LA <- LA[LA$Electorate != ""]
if (nrow(LA) != 88L) {
  cat(sprintf("VP2! expected 88 Victorian Legislative Assembly seats, found %d -- proceeding, but name this if it recurs\n", nrow(LA)))
}
cat(sprintf("VP2  Legislative Assembly table: %d seats, columns: %s\n",
            nrow(LA), paste(names(LA), collapse = " | ")))

strip_refs <- function(x) trimws(gsub("\\[\\d+\\]", "", x))

# Major/named-party columns: one candidate (rarely a short list) per cell,
# no bracket code needed since the COLUMN itself names the party.
MAJOR_COLS <- list(
  "Labor candidate"      = "ALP",
  "Coalition candidate"  = "LNP",   # Liberal or National, both LNP in this repo's classes
  "Liberal candidate"    = "LNP",
  "Greens candidate"     = "GRN",
  "One Nation candidate" = "ONP",
  "Socialists candidate" = "OTH"
)

rows <- list()
for (col in names(MAJOR_COLS)) {
  if (!col %in% names(LA)) next
  cls <- MAJOR_COLS[[col]]
  d <- LA[, list(seat = Electorate, raw = get(col))]
  d <- d[nzchar(trimws(raw))]
  if (!nrow(d)) next
  d[, cand := strip_refs(raw)]
  d[, party := cls]
  rows[[length(rows) + 1L]] <- d[, list(seat, cand, party)]
}

# "Other candidates": one cell can hold several "Name (CODE)[refs]" entries
# concatenated with NO separator between them (confirmed directly against
# the cached page, e.g. "Lachie McKeeman (Ind)[45]Mike Fruery (AJP)[46]").
# Parsed by regex rather than split on whitespace/newline, which would not
# reliably separate them.
CODE_TO_NAME <- c(
  Ind = "Independent", FF = "Family First", AJP = "Animal Justice Party",
  SFF = "Shooters, Fishers and Farmers", DLP = "Democratic Labour Party",
  SA = "Socialist Alliance", Freedom = "Freedom Party of Victoria",
  Libertarian = "Libertarian", HEART = "Australian HEART Party"
)
if ("Other candidates" %in% names(LA)) {
  other <- LA[, list(seat = Electorate, raw = `Other candidates`)]
  other <- other[nzchar(trimws(raw))]
  other_rows <- list()
  for (i in seq_len(nrow(other))) {
    txt <- strip_refs(other$raw[i])
    m <- gregexpr("([^()]+?)\\s*\\(([A-Za-z]+)\\)", txt, perl = TRUE)
    hits <- regmatches(txt, m)[[1]]
    if (!length(hits)) next
    for (h in hits) {
      mm <- regmatches(h, regexec("([^()]+?)\\s*\\(([A-Za-z]+)\\)", h, perl = TRUE))[[1]]
      cand_name <- trimws(mm[2]); code <- trimws(mm[3])
      full_name <- if (code %in% names(CODE_TO_NAME)) unname(CODE_TO_NAME[code]) else code
      cls <- classify_party(full_name, code = toupper(code))
      other_rows[[length(other_rows) + 1L]] <- data.table(
        seat = other$seat[i], cand = cand_name, party = cls, .code = code)
    }
  }
  if (length(other_rows)) {
    OTH <- rbindlist(other_rows)
    unclassified <- OTH[is.na(party), sort(unique(.code))]
    if (length(unclassified)) {
      cat(sprintf("VP3! %d row(s) with an unrecognised code, defaulted to OTH -- add to CODE_TO_NAME: %s\n",
                  OTH[is.na(party), .N], paste(unclassified, collapse = ", ")))
      OTH[is.na(party), party := "OTH"]
    }
    rows[[length(rows) + 1L]] <- OTH[, list(seat, cand, party)]
  }
}

ALL <- rbindlist(rows)
ALL <- unique(ALL)
ALL[, fetched_at := as.character(Sys.Date())]
ALL[, source := "wikipedia-prenomination"]

setorder(ALL, seat, party)
fwrite(ALL, "output/vic2026-prenomination-candidates.csv")

n_seats_total <- uniqueN(ALL$seat)
non_major <- ALL[!party %in% c("ALP", "LNP")]
n_seats_nonmajor <- uniqueN(non_major$seat)
cat(sprintf("\nVP5  wrote output/vic2026-prenomination-candidates.csv: %d candidates, %d seats\n",
            nrow(ALL), n_seats_total))
cat(sprintf("VP5  seats with at least one non-major (IND/GRN/ONP/OTH/OTH_RIGHT) candidate named: %d of %d\n",
            n_seats_nonmajor, n_seats_total))
cat("\nVP6  candidates by class:\n")
print(ALL[, .N, by = party][order(-N)])
cat(sprintf("\nVP7  as of %s -- PRE-NOMINATION, expect this to grow before 9 Nov 2026\n", Sys.Date()))
