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
# Writes to external/elections/, gitignored alongside the anchor clone. The data
# is public but carries no licence statement, so none of it is committed --
# see election_data_path().
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fetch_preferences_sa.R"'

suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

API <- "https://apim-ecsa-production.azure-api.net/results-display"
ELECTION <- "2026-03-21"
OUT <- election_data_path()   # external/elections
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
# But HOW MANY candidates made that edge is information, and it is destroyed
# by this aggregation, so it is counted first.
# PER-ROUND CLASS MULTIPLICITY, against docs/plans/prereg-survivor-
# multiplicity.md. `to_n` is how many CANDIDATES of that class received
# votes in this round. Our classes are buckets -- OTH_RIGHT holds every
# minor-right party and IND every independent -- so a seat with three
# minor-right candidates gives OTH_RIGHT three candidates' worth of
# preferences while keying identically to a seat with one. Counted HERE,
# before the aggregation below destroys the candidate rows.
tx[, to_n := .N, by = c("election","seat","round","from","to")]
tx <- tx[, list(votes = sum(votes), to_n = to_n[1]),
         by = c("election","seat","round","from","to")]

stopifnot(nrow(tx) > 0)
cat(sprintf("\nexclusion events : %d\nseats            : %d\ntransfer rows    : %d\n",
            uniqueN(tx[, list(seat, round)]), uniqueN(tx$seat), nrow(tx)))
if (length(unmatched)) {
  cat(sprintf("!! %d candidate(s) could not be matched to a party\n", length(unmatched)))
  print(utils::head(unique(unmatched), 5))
}
f <- file.path(OUT, "ecsa-2026-sa-transfers.csv")
fwrite(tx, f)
cat("wrote", f, "\n")
record_fetch("ecsa", "ecsa-2026-sa-transfers.csv", API, nrow(tx))

# Per-seat One Nation first-preference shares. Not used for preference flows:
# this is the only measurement of how widely a party polling around 23% varies
# BETWEEN seats, and the Victorian seat model borrows that spread because
# Victoria has never had a large One Nation vote to measure its own.
fp_rows <- list()
for (d in chg$districts) {
  seat <- d$districtId
  fd <- d$finalDistribution
  if (!length(fd)) next
  first <- Filter(function(r) identical(r$roundType, "FirstPreference"), fd)
  if (!length(first)) next
  keep <- which(party_map$seat == seat)
  look <- setNames(party_map$party[keep], party_map$cand_key[keep])
  tot <- 0; onp <- 0
  for (cr in first[[1]]$candidateResults) {
    v <- cr$progressiveTotal %||% 0
    if (!is.numeric(v) || v <= 0) next
    tot <- tot + v
    cls <- look[[norm(cr$candidateName %||% "")]]
    if (!is.null(cls) && identical(cls, "ONP")) onp <- onp + v
  }
  if (tot > 0 && onp > 0) {
    fp_rows[[length(fp_rows) + 1L]] <- data.table(seat = seat, pct = 100 * onp / tot)
  }
}

# The SAME first-preference round, kept for EVERY party class rather than One
# Nation alone. Needed to score the Victorian One Nation seat allocation: that
# allocation orders seats by GREENS share, so measuring how well the ordering
# works against South Australia needs SA's Greens share per district, which
# the One Nation-only extract above cannot give. See
# docs/plans/prereg-onp-seat-uncertainty.md.
all_rows <- list()
for (d in chg$districts) {
  seat <- d$districtId
  fd <- d$finalDistribution
  if (!length(fd)) next
  first <- Filter(function(r) identical(r$roundType, "FirstPreference"), fd)
  if (!length(first)) next
  keep <- which(party_map$seat == seat)
  look <- setNames(party_map$party[keep], party_map$cand_key[keep])
  for (cr in first[[1]]$candidateResults) {
    v <- cr$progressiveTotal %||% 0
    if (!is.numeric(v) || v <= 0) next
    cls <- look[[norm(cr$candidateName %||% "")]]
    if (is.null(cls)) next
    all_rows[[length(all_rows) + 1L]] <- data.table(
      seat = seat, party = cls, votes = as.numeric(v))
  }
}
sa_fp <- rbindlist(all_rows)[, list(votes = sum(votes)), by = c("seat", "party")]
stopifnot(nrow(sa_fp) > 0)
fwrite(sa_fp, file.path(OUT, "ecsa-2026-sa-firstprefs.csv"))
record_fetch("ecsa", "ecsa-2026-sa-firstprefs.csv", API, nrow(sa_fp))
cat(sprintf("SA first preferences: %d seat-party rows across %d seats\n",
            nrow(sa_fp), uniqueN(sa_fp$seat)))

onp_fp <- rbindlist(fp_rows)
stopifnot(nrow(onp_fp) > 0)
fwrite(onp_fp, file.path(OUT, "ecsa-2026-sa-onp-shares.csv"))
record_fetch("ecsa", "ecsa-2026-sa-onp-shares.csv", API, nrow(onp_fp))
cat(sprintf("One Nation seat shares: %d seats, %.1f%% to %.1f%%, mean %.1f%%\n",
            nrow(onp_fp), min(onp_fp$pct), max(onp_fp$pct), mean(onp_fp$pct)))
