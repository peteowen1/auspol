# Fetch South Australian 2026 preference distributions from the ECSA API.
#
# ECSA's results site is an Angular app: every path returns the same 1.5 KB
# shell, which is why an earlier plan budgeted for browser automation and
# deprioritised South Australia. It does not need one. The app's own JS bundle
# names a public API with no key and no auth, and HAChange carries the full
# distribution for all 47 districts.
#
# South Australia matters for one reason: One Nation contested every seat there
# in 2026 and polled 22.9%, so it is the only Australian election that can
# supply ONP preference behaviour. Victoria cannot -- One Nation contested 5 of
# 88 seats in 2022 and appears in two exclusion events.
#
# Writes to output/, which is gitignored. The data is public but carries no
# licence statement, so it is fetched rather than committed -- the same rule
# R/paths.R states for the anchor's data.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fetch_preferences_sa.R"'

suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

API <- "https://apim-ecsa-production.azure-api.net/results-display"
ELECTION <- "2026-03-21"
OUT <- file.path("output", "preferences")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

get_json <- function(path) {
  url <- paste0(API, "/", path)
  message("  GET ", url)
  jsonlite::fromJSON(url, simplifyVector = FALSE)
}

# Names differ between the two endpoints -- "CASEY, Dan" against "Dan CASEY" --
# and the candidateId numbering is NOT shared, so the join is on a normalised
# name within a district. Sorting the tokens makes the ordering irrelevant.
norm <- function(x) {
  x <- toupper(gsub("[^A-Za-z ]", " ", ifelse(is.na(x), "", x)))
  vapply(strsplit(trimws(gsub(" +", " ", x)), " "),
         function(p) paste(sort(p[nzchar(p)]), collapse = " "), character(1))
}

stat <- get_json(paste0("HAStatic/", ELECTION))
chg  <- get_json(paste0("HAChange/", ELECTION, "/0"))

party_map <- rbindlist(lapply(stat$districts, function(d) {
  cands <- d$candidates
  if (!length(cands)) return(NULL)
  data.table(
    seat = d$districtName,
    # NOT `key`: data.table() treats that as its key= argument and errors with
    # "some columns are not in the data.table", naming the candidates.
    cand_key = norm(vapply(cands, function(c) c$candidateName %||% "", character(1))),
    party = classify_party(
      vapply(cands, function(c) c$partyName %||% "", character(1)),
      vapply(cands, function(c) c$partyId   %||% "", character(1))))
}))
message(sprintf("candidates with a party: %d across %d districts",
                nrow(party_map), uniqueN(party_map$seat)))

rows <- list(); unmatched <- character(0)
for (d in chg$districts) {
  seat <- d$districtId
  fd <- d$finalDistribution
  if (!length(fd)) next
  # Mask computed OUTSIDE the brackets. Written the obvious way,
  # `party[party$seat == seat, ]`, data.table binds the bare `party` to the
  # COLUMN of that name and `$` fails on an atomic vector -- and `seat` is
  # itself a column too, so the comparison would be a self-match. Both traps
  # are recorded in CLAUDE.md; this is the third and fourth time.
  keep <- which(party_map$seat == seat)
  pmap <- party_map[keep, ]
  look <- setNames(pmap$party, pmap$cand_key)
  for (rnd in fd) {
    if (identical(rnd$roundType, "FirstPreference")) next
    exk <- norm(rnd$excludedCandidateName %||% "")
    from <- look[[exk]]
    if (is.null(from)) { unmatched <- c(unmatched, paste(seat, exk)); next }
    for (cr in rnd$candidateResults) {
      if (isTRUE(cr$isExcluded)) next
      v <- cr$voteChange %||% 0
      if (!is.numeric(v) || v <= 0) next
      to <- look[[norm(cr$candidateName %||% "")]]
      if (is.null(to)) { unmatched <- c(unmatched, paste(seat, cr$candidateName)); next }
      rows[[length(rows) + 1L]] <- data.table(
        election = "sa2026", seat = seat, round = rnd$roundNumber,
        from = from, to = to, votes = as.numeric(v))
    }
  }
}
tx <- rbindlist(rows)
# Transfers to the same class from one exclusion are one edge, not several.
tx <- tx[, list(votes = sum(votes)), by = c("election","seat","round","from","to")]

stopifnot(nrow(tx) > 0)
cat(sprintf("\nexclusion events : %d\nseats            : %d\ntransfer rows    : %d\n",
            uniqueN(tx[, list(seat, round)]), uniqueN(tx$seat), nrow(tx)))
if (length(unmatched)) {
  cat(sprintf("!! %d candidate(s) could not be matched to a party\n", length(unmatched)))
  print(utils::head(unique(unmatched), 5))
}
f <- file.path(OUT, "transfers-sa2026.csv")
fwrite(tx, f)
cat("wrote", f, "\n")
