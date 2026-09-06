# Fetches the WAEC's separate /candidates endpoint (docs/plans/waec-data-access.md
# already names it in its endpoint table; nothing had actually called it) for
# every WA state election, to recover candidate GIVEN names.
#
# WHY. output/candidacies.csv's WA rows come from the /results endpoint's
# resultsCandidates array (BALLOT_PAPER_NAME e.g. "MOIR" -- surname only), so
# every WA candidacy carries surname = NA, given = NA. That is 2,803 rows
# (19% of the whole corpus) where identity is scoped to a seat only, and a WA
# candidate who moves seats between elections reads as two different people
# (docs/plans/plan-candidate-level-model.md, D2). /candidates' own
# districtCandidates array carries the SAME BALLOT_PAPER_NAME field but
# formatted "SURNAME, Given" -- e.g. "MOIR, Bob" -- confirmed live across all
# eight elections (1996-2025), not just recent ones.
#
# CACHED RAW, per CLAUDE.md's own rule on scraped/fetched data: the response is
# stored as-is, never reduced to just the given name at fetch time.
#
# Emits WCN* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

API <- "https://eis.waec.wa.gov.au/api"
RAW <- file.path("external", "reference", "waec")
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)
# ALL EIGHT, not fetch_preferences_wa.R's default three: build_candidacies.R
# already reads every sg{YEAR}-{CODE}.json on disk regardless of election, and
# all eight are already cached from that fetch.
ELECTIONS <- c("sg1996", "sg2001", "sg2005", "sg2008", "sg2013", "sg2017", "sg2021", "sg2025")

get_json <- function(path, cache) {
  f <- file.path(RAW, cache)
  if (!file.exists(f) || file.info(f)$size < 200) {
    utils::download.file(paste0(API, path), f, quiet = TRUE, mode = "wb")
    Sys.sleep(0.15)   # be polite: this runs to ~470 calls across 8 elections
  }
  jsonlite::fromJSON(f, simplifyVector = FALSE)
}

total <- 0L; total_with_names <- 0L
for (E in ELECTIONS) {
  mem <- get_json(sprintf("/sgElections/%s/LAElectedMembers", E),
                  sprintf("%s-members.json", E))
  # NOTE THE SPELLING (theirs, not a typo): ElelctorateType.
  els <- Filter(function(x) identical(x$ElelctorateType, "District"), mem$electorates)
  codes <- vapply(els, function(x) x$ElectorateCode, character(1))
  cat(sprintf("WCN1 %s: %d districts\n", E, length(codes)))
  if (length(codes) < 50L) {
    stop(E, ": only ", length(codes), " districts. Western Australia has 59; ",
         "the ElelctorateType filter has probably stopped matching.")
  }
  n_seat <- 0L; n_named <- 0L
  for (code in codes) {
    r <- tryCatch(
      get_json(sprintf("/sgElections/%s/%s/candidates", E, code),
              sprintf("%s-%s-candidates.json", E, code)),
      error = function(e) NULL)
    if (is.null(r) || !length(r$districtCandidates)) next
    n_seat <- n_seat + 1L
    n_named <- n_named + sum(vapply(r$districtCandidates,
      function(c) grepl(",", c$BALLOT_PAPER_NAME %||% ""), logical(1)))
  }
  total <- total + n_seat
  total_with_names <- total_with_names + n_named
  cat(sprintf("WCN2 %s: %d/%d districts fetched, %d candidates with a given name\n",
              E, n_seat, length(codes), n_named))
}
cat(sprintf("\nWCN9 done: %d districts fetched across %d elections, %d candidates carry a given name\n",
            total, length(ELECTIONS), total_with_names))
