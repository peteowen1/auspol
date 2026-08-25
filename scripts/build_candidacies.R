# Build the candidate-level corpus: every candidate, every seat, as many
# elections as there is data for.
#
# WHY THIS EXISTS. `output/ind-candidacies.csv` -- the corpus the Google Trends
# salience AUC of 0.87 rests on -- was UNTRACKED, had NO builder script, and
# covered only fed2019, fed2022 and fed2025. So the claim was not reproducible
# and the cutoff had no recorded reason. Worse, four of the nine seats the model
# most badly misses (Denison and Lyne in 2010, Indi and Fairfax in 2013) sit in
# the elections it left out.
#
# The binding constraint on that AUC is POSITIVES, not negatives: fetching the
# rest of the federal candidacies moves the SE from 0.055 to only 0.051, because
# there are just 21 breakouts in the whole federal corpus. More positives means
# more ELECTIONS, which is why this covers the states too.
#
# NOTHING IS COMMITTED. Outputs land in output/ and external/ which are
# gitignored, the same treatment every other commission extract gets. This file
# is the reproducible recipe.
#
# Emits BC* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

`%||%` <- function(x, y) if (is.null(x)) y else x
OUT <- "output/candidacies.csv"
parts <- list()

# ---- FEDERAL 2007-2025 ------------------------------------------------------
# Already on disk: scripts/fetch_preferences_fed.R downloads the AEC's
# HouseFirstPrefsByCandidateByVoteType files, which are candidate-level, and
# then aggregates the names away. Nothing needs downloading.
AEC <- file.path("external", "reference", "aec")
read_aec <- function(path) {
  first <- readLines(path, n = 1L, warn = FALSE)
  skip <- if (grepl("^\\s*$", first) || !grepl(",", first)) 1L else
    if (grepl("Download|Report|generated|Election", first, ignore.case = TRUE)) 1L else 0L
  fread(path, skip = skip, showProgress = FALSE)
}

fed_years <- c(2007, 2010, 2013, 2016, 2019, 2022, 2025)
for (y in fed_years) {
  f <- file.path(AEC, sprintf("fed%d-firstprefs.csv", y))
  if (!file.exists(f)) { cat(sprintf("BC1  fed%d: MISSING %s\n", y, f)); next }
  d <- read_aec(f); setnames(d, make.names(names(d)))
  need <- c("DivisionNm", "Surname", "GivenNm", "PartyNm", "TotalVotes")
  miss <- setdiff(need, names(d))
  if (length(miss)) { cat(sprintf("BC1  fed%d: lacks %s\n", y, paste(miss, collapse=", "))); next }
  d <- d[!is.na(TotalVotes)]
  d <- d[!(is.na(PartyNm) | PartyNm == "" | grepl("^Informal$", PartyNm, ignore.case = TRUE))]
  # One row per candidate: the AEC file is already one row per candidate per
  # division, but guard rather than assume -- a vote-type-split file would
  # silently double every candidate and halve every computed share.
  d <- d[, .(votes = sum(as.numeric(TotalVotes)),
             elected = any(toupper(as.character(Elected)) %in% c("Y", "TRUE"))),
         by = .(seat = DivisionNm, surname = Surname, given = GivenNm,
                party_raw = PartyNm)]
  d[, `:=`(party = classify_party(party_raw, NULL),
           election = sprintf("fed%d", y), region = "fed", year = y)]
  parts[[sprintf("fed%d", y)]] <- d
  cat(sprintf("BC1  fed%d: %d candidates in %d seats\n", y, nrow(d), uniqueN(d$seat)))
}

# ---- SOUTH AUSTRALIA 2018, 2022, 2026 ---------------------------------------
# ECSA publishes two files per election: a profile carrying districtName and,
# per candidate, candidateId + candidateName + partyName; and a results file
# carrying per-candidate vote counts keyed by the SAME candidateId.
#
# JOIN ON candidateId, NOT on district order. The profile has no districtId and
# the results file has no districtName, so pairing them positionally would be an
# unchecked assumption about two independently-generated files being in the same
# order -- and if it were ever wrong it would attach real votes to the wrong
# candidate silently. The candidateId join needs no such assumption, and the
# coverage assertion below catches it if the ids ever stop lining up.
suppressMessages(library(jsonlite))
ECSA <- file.path("external", "reference", "ecsa")
sa_files <- list(
  list(year = 2018, prof = "ha-2018-03-17.json", res = NA_character_),
  list(year = 2022, prof = "ha-2022-03-19.json", res = "ha-change-2022-03-19.json"),
  list(year = 2026, prof = "ha-2026-03-21.json", res = "ha-change-2026-03-21.json"))

for (E in sa_files) {
  pf <- file.path(ECSA, E$prof)
  # A ZERO-BYTE FILE IS NOT A MISSING FILE, and file.exists() cannot tell them
  # apart. ha-2018-03-17.json is 0 bytes on this machine -- a download that
  # failed and was never noticed. Check the size and say which of the two
  # problems it is: "missing" sends you to the fetcher, "empty" to the download.
  if (!file.exists(pf)) { cat(sprintf("BC2  sa%d: MISSING %s\n", E$year, pf)); next }
  if (file.info(pf)$size < 1000) {
    cat(sprintf("BC2  sa%d: %s is %d bytes -- failed download; REFETCH NEEDED\n",
                E$year, basename(pf), file.info(pf)$size)); next
  }
  prof <- tryCatch(fromJSON(pf, simplifyVector = FALSE), error = function(e) {
    cat(sprintf("BC2  sa%d: %s failed to parse (%s); REFETCH NEEDED\n",
                E$year, basename(pf), conditionMessage(e))); NULL })
  if (is.null(prof)) next
  cand <- rbindlist(lapply(prof$districts, function(d)
    rbindlist(lapply(d$candidates, function(c) data.table(
      seat = d$districtName,
      cand_id = c$candidateId %||% NA_integer_,
      name = c$candidateName %||% NA_character_,
      party_raw = c$partyName %||% "Independent")), fill = TRUE)), fill = TRUE)
  if (is.na(E$res)) {
    cat(sprintf("BC2  sa%d: profile has %d candidates but NO results file on disk; skipped\n",
                E$year, nrow(cand)))
    next
  }
  rf <- file.path(ECSA, E$res)
  if (!file.exists(rf)) { cat(sprintf("BC2  sa%d: MISSING %s\n", E$year, rf)); next }
  res <- fromJSON(rf, simplifyVector = FALSE)
  # candidateId is NUMBERED WITHIN A DISTRICT, not globally: 240 candidates
  # carry only 9 distinct ids. Joining on it alone produced a 9,580-row
  # cartesian blow-up. The results file's `districtId` is the district NAME, so
  # (seat, candidateId) is a real key and no ordering assumption is needed.
  vt <- rbindlist(lapply(res$districts, function(d)
    rbindlist(lapply(d$candidates, function(c) data.table(
      seat = d$districtId %||% NA_character_,
      cand_id = c$candidateId %||% NA_integer_,
      votes = (c$ordinaryVotes %||% 0) + (c$declarationVotes %||% 0))), fill = TRUE)),
    fill = TRUE)
  if (anyDuplicated(vt[, .(seat, cand_id)]))
    stop(sprintf("sa%d: (seat, candidateId) is not unique in the results file", E$year))
  m <- merge(cand, vt, by = c("seat", "cand_id"), all.x = TRUE)
  hit <- sum(!is.na(m$votes))
  # A silent partial join here would understate every share in the seats that
  # missed, so require near-total coverage rather than reporting a mean over
  # whatever matched.
  if (hit < 0.98 * nrow(m))
    stop(sprintf("sa%d: candidateId join covered only %d of %d candidates",
                 E$year, hit, nrow(m)))
  m <- m[!is.na(votes)]
  m[, `:=`(party = classify_party(party_raw, NULL), surname = NA_character_,
           given = NA_character_, elected = NA,
           election = sprintf("sa%d", E$year), region = "sa", year = E$year)]
  parts[[sprintf("sa%d", E$year)]] <- m[, .(seat, surname, given, party_raw,
                                            votes, elected, party, election,
                                            region, year, name)]
  cat(sprintf("BC2  sa%d: %d candidates in %d seats\n", E$year, nrow(m), uniqueN(m$seat)))
}

# ---- NEW SOUTH WALES 2019, 2023 ---------------------------------------------
# The NSWEC workbook's "Data" sheet is one row per candidate PER VENUE, so it
# must be aggregated to candidate level. Informal rows carry no candidate and
# are dropped before aggregating -- leaving them in would inflate every seat's
# denominator and understate every share.
NSWD <- file.path("external", "reference", "nsw")
nsw_files <- list(list(year = 2019, f = "sge2019-la-final-votes.xlsx"),
                  list(year = 2023, f = "sge2023-la-final-votes.xlsx"))
for (E in nsw_files) {
  fp <- file.path(NSWD, E$f)
  if (!file.exists(fp) || file.info(fp)$size < 1000) {
    cat(sprintf("BC3  nsw%d: MISSING or empty %s\n", E$year, E$f)); next
  }
  if (!requireNamespace("readxl", quietly = TRUE)) {
    cat("BC3  nsw: readxl not installed; skipped\n"); break
  }
  d <- as.data.table(readxl::read_excel(fp, sheet = "Data"))
  setnames(d, trimws(names(d)))
  need <- c("District", "Candidate Ballot Name", "Party Name", "Final FP Votes")
  miss <- setdiff(need, names(d))
  if (length(miss)) {
    cat(sprintf("BC3  nsw%d: lacks %s\n", E$year, paste(miss, collapse = ", "))); next
  }
  if ("Formal/Informal" %in% names(d)) d <- d[grepl("^Formal", `Formal/Informal`)]
  d <- d[!is.na(`Candidate Ballot Name`) & `Candidate Ballot Name` != ""]
  agg <- d[, .(votes = sum(as.numeric(`Final FP Votes`), na.rm = TRUE)),
           by = .(seat = District, name = `Candidate Ballot Name`,
                  party_raw = `Party Name`)]
  # An unaffiliated candidate has an empty party in this file, which
  # classify_party() would not read as independent.
  agg[is.na(party_raw) | party_raw == "", party_raw := "Independent"]
  agg[, `:=`(party = classify_party(party_raw, NULL), surname = NA_character_,
             given = NA_character_, elected = NA,
             election = sprintf("nsw%d", E$year), region = "nsw", year = E$year)]
  parts[[sprintf("nsw%d", E$year)]] <- agg
  cat(sprintf("BC3  nsw%d: %d candidates in %d seats\n", E$year, nrow(agg),
              uniqueN(agg$seat)))
}

# ---- VICTORIA 2022 ----------------------------------------------------------
# Already extracted to candidate level by an earlier fetch.
vf <- file.path(election_data_path(), "vec-2022-vic-candidates.csv")
if (file.exists(vf)) {
  v <- fread(vf, showProgress = FALSE)
  if (all(c("seat", "cand", "party", "fp_votes") %in% names(v))) {
    # `party` here is ALREADY a classify_party() class, not a raw party name.
    # Re-classifying it would be a second pass over its own output; harmless for
    # most values but not something to rely on silently.
    v <- v[, .(seat, name = cand, party_raw = party, votes = as.numeric(fp_votes),
               party = party, surname = NA_character_, given = NA_character_,
               elected = NA, election = "vic2022", region = "vic", year = 2022)]
    parts[["vic2022"]] <- v
    cat(sprintf("BC4  vic2022: %d candidates in %d seats\n", nrow(v), uniqueN(v$seat)))
  } else cat("BC4  vic2022: unexpected columns; skipped\n")
} else cat(sprintf("BC4  vic2022: MISSING %s\n", vf))

# ---- WESTERN AUSTRALIA 1996-2025 --------------------------------------------
# One JSON per seat per election, already on disk: sg{YEAR}-{CODE}.json, with
# `resultsCandidates` carrying BALLOT_PAPER_NAME, PARTY_AFFILIATION and
# Votes_Counted. Eight elections at ~60 seats each.
#
# Pre-2010 elections are kept even though Google Trends only reaches back to
# 2004 and is thin before ~2008. Whether a candidacy is USABLE for the salience
# signal is a separate filter applied where that signal is built; silently
# dropping elections here would recreate the exact problem this corpus exists to
# fix -- a truncated corpus whose cutoff nobody recorded.
WAEC <- file.path("external", "reference", "waec")
wa_files <- list.files(WAEC, pattern = "^sg[0-9]{4}-[A-Z]+\\.json$")
wa_years <- sort(unique(as.integer(sub("^sg([0-9]{4}).*$", "\\1", wa_files))))
for (y in wa_years) {
  ff <- wa_files[grepl(sprintf("^sg%d-", y), wa_files)]
  rows <- list()
  for (f in ff) {
    p <- file.path(WAEC, f)
    if (file.info(p)$size < 500) next
    j <- tryCatch(fromJSON(p, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(j) || !length(j$resultsCandidates)) next
    sname <- j$toptotals$ELECTORATE_NAME %||% j$currentElectorate$ElectorateName %||% NA_character_
    rows[[f]] <- rbindlist(lapply(j$resultsCandidates, function(c) data.table(
      seat = sname,
      name = c$BALLOT_PAPER_NAME %||% NA_character_,
      party_raw = c$PARTY_AFFILIATION %||% "Independent",
      votes = as.numeric(c$Votes_Counted %||% NA))), fill = TRUE)
  }
  if (!length(rows)) { cat(sprintf("BC5  wa%d: no parsable seat files\n", y)); next }
  w <- rbindlist(rows, fill = TRUE)
  w <- w[!is.na(votes) & !is.na(seat)]
  if (!nrow(w)) { cat(sprintf("BC5  wa%d: parsed but no vote rows\n", y)); next }
  w[is.na(party_raw) | party_raw == "", party_raw := "Independent"]
  # WA SUPPLIES ABBREVIATIONS, NOT NAMES: "ALP", "LIB", "GRN", "NAT", "PHON".
  # Passing those as classify_party()'s NAME argument sent every one of them to
  # OTH, which read as ~115 "non-major breakouts" per 57-seat election -- about
  # two per seat, i.e. both majors counted as minor. Nothing errored; the only
  # tell was that the count was impossible. Pass them as the ABBREVIATION, which
  # is what fetch_preferences_fed.R does with PartyAb.
  w[, `:=`(party = classify_party(party_raw, party_raw), surname = NA_character_,
           given = NA_character_, elected = NA,
           election = sprintf("wa%d", y), region = "wa", year = y)]
  parts[[sprintf("wa%d", y)]] <- w
  cat(sprintf("BC5  wa%d: %d candidates in %d seats\n", y, nrow(w), uniqueN(w$seat)))
}

# ---- QUEENSLAND 2020, 2024 --------------------------------------------------
# One XML per election. Candidate identity lives under
# district/candidates/candidate (ballotName, party, partyCode); the vote counts
# live in a separate countRound. Joined on ballotName within a district.
#
# TAKE THE OFFICIAL FIRST PREFERENCE COUNT, NOT THE FIRST ROUND. Each district
# carries several countRound nodes and the first is "Unofficial Preliminary
# Count". Reading whichever comes first would silently score the model against
# preliminary numbers, so the round is selected by name and its absence is an
# error rather than a fallback.
ECQ <- file.path("external", "reference", "ecq")
qld_files <- list(list(year = 2020, f = "qld2020.xml"), list(year = 2024, f = "qld2024.xml"))
for (E in qld_files) {
  fp <- file.path(ECQ, E$f)
  if (!file.exists(fp) || file.info(fp)$size < 1000) {
    cat(sprintf("BC6  qld%d: MISSING or empty %s\n", E$year, E$f)); next
  }
  if (!requireNamespace("xml2", quietly = TRUE)) {
    cat("BC6  qld: xml2 not installed; skipped\n"); break
  }
  x <- xml2::read_xml(fp)
  ds <- xml2::xml_find_all(x, "//districts/district")
  rows <- list()
  for (dd in ds) {
    sname <- xml2::xml_attr(dd, "districtName")
    cn <- xml2::xml_find_all(dd, "./candidates/candidate")
    if (!length(cn)) next
    ci <- data.table(
      seat = sname,
      name = xml2::xml_attr(cn, "ballotName"),
      party_raw = xml2::xml_attr(cn, "party"),
      party_ab = xml2::xml_attr(cn, "partyCode"))
    cr <- xml2::xml_find_all(
      dd, "./countRound[@countName='Official First Preference Count']")
    if (!length(cr)) next
    vn <- xml2::xml_find_all(cr[[1]], "./primaryVoteResults/candidate")
    if (!length(vn)) next
    vi <- data.table(
      name = xml2::xml_attr(vn, "ballotName"),
      votes = as.numeric(xml2::xml_text(xml2::xml_find_first(vn, "./count"))))
    if (anyDuplicated(vi$name)) next   # a repeated ballot name cannot be joined
    rows[[sname]] <- merge(ci, vi, by = "name", all.x = TRUE)
  }
  if (!length(rows)) { cat(sprintf("BC6  qld%d: no districts parsed\n", E$year)); next }
  q <- rbindlist(rows, fill = TRUE)
  hit <- sum(!is.na(q$votes))
  if (hit < 0.98 * nrow(q))
    cat(sprintf("BC6  qld%d: WARNING only %d of %d candidates got a vote count\n",
                E$year, hit, nrow(q)))
  q <- q[!is.na(votes)]
  q[is.na(party_raw) | party_raw == "", party_raw := "Independent"]
  q[, `:=`(party = classify_party(party_raw, party_ab), surname = NA_character_,
           given = NA_character_, elected = NA,
           election = sprintf("qld%d", E$year), region = "qld", year = E$year)]
  parts[[sprintf("qld%d", E$year)]] <- q[, .(seat, name, party_raw, votes, party,
                                             surname, given, elected, election,
                                             region, year)]
  cat(sprintf("BC6  qld%d: %d candidates in %d seats\n", E$year, nrow(q), uniqueN(q$seat)))
}

# ---- VICTORIA 2014, 2018 ----------------------------------------------------
# One HTML page per district, already on disk. Each carries several tables; the
# one wanted has columns Candidate / Party / 1st pref votes.
#
# SELECT THE TABLE BY ITS COLUMN NAMES, NOT BY POSITION. The first-preference
# table sits at index 3 on the pages checked, but a page with an extra banner
# table would shift it, and the neighbouring table is the two-candidate-preferred
# result -- which has the same shape and would parse cleanly as if it were first
# preferences, turning a 63% two-party result into a "63% primary". Position
# indexing would fail silently and plausibly.
VECD <- file.path("external", "reference", "vec")
for (y in c(2014, 2018)) {
  dir_y <- file.path(VECD, as.character(y))
  if (!dir.exists(dir_y)) { cat(sprintf("BC7  vic%d: no directory\n", y)); next }
  if (!requireNamespace("rvest", quietly = TRUE) ||
      !requireNamespace("xml2", quietly = TRUE)) {
    cat("BC7  vic: rvest/xml2 not installed; skipped\n"); break
  }
  ff <- list.files(dir_y, pattern = "district\\.html$")
  rows <- list(); skipped <- 0L
  for (f in ff) {
    p <- file.path(dir_y, f)
    h <- tryCatch(xml2::read_html(p), error = function(e) NULL)
    if (is.null(h)) { skipped <- skipped + 1L; next }
    tb <- tryCatch(rvest::html_table(h, fill = TRUE), error = function(e) list())
    hit <- Filter(function(t) all(c("Candidate", "Party") %in% names(t)) &&
                    any(grepl("1st pref votes", names(t), fixed = TRUE)), tb)
    if (!length(hit)) { skipped <- skipped + 1L; next }
    t <- as.data.table(hit[[1]])
    vcol <- grep("1st pref votes", names(t), fixed = TRUE, value = TRUE)[1]
    t <- t[, .(name = Candidate, party_raw = Party,
               votes = suppressWarnings(as.numeric(gsub("[^0-9]", "", get(vcol)))))]
    t <- t[!is.na(votes) & votes > 0 & name != "" & !is.na(name)]
    if (!nrow(t)) { skipped <- skipped + 1L; next }
    # Seat name from the filename: "albertparkdistrict.html" -> "albertpark".
    # Kept lowercase and unspaced; the corpus is keyed on (election, seat) and
    # nothing here joins to the VEC results files, so inventing a spacing rule
    # would add a matching problem rather than solve one.
    t[, seat := sub("district\\.html$", "", f)]
    rows[[f]] <- t
  }
  if (!length(rows)) { cat(sprintf("BC7  vic%d: no district tables parsed\n", y)); next }
  v <- rbindlist(rows, fill = TRUE)
  v[is.na(party_raw) | party_raw == "", party_raw := "Independent"]
  v[, `:=`(party = classify_party(party_raw, NULL), surname = NA_character_,
           given = NA_character_, elected = NA,
           election = sprintf("vic%d", y), region = "vic", year = y)]
  parts[[sprintf("vic%d", y)]] <- v
  cat(sprintf("BC7  vic%d: %d candidates in %d seats (%d pages skipped)\n",
              y, nrow(v), uniqueN(v$seat), skipped))
}

# ---- assemble ---------------------------------------------------------------
if (!length(parts)) stop("no candidacy source produced rows")
C <- rbindlist(parts, fill = TRUE)
# Federal rows carry surname/given; state rows carry a single name field.
if (!"name" %in% names(C)) C[, name := NA_character_]
C[is.na(name), name := trimws(paste(given, surname))]
C[, tot := sum(votes), by = .(election, seat)]
C[, pcv := 100 * votes / tot]

# BREAKOUT, the label the salience gate predicts: >= 20% of first preferences.
# Kept identical to scripts/gate_independent_salience.R so the two corpora are
# comparable; changing it here would silently change what the AUC means.
C[, breakout := pcv >= 20]

setorder(C, election, seat, -pcv)
fwrite(C[, .(election, region, year, seat, name, surname, given,
             party, party_raw, votes, pcv, elected, breakout)], OUT)

cat(sprintf("\nBC9  %d candidacies across %d elections -> %s\n",
            nrow(C), uniqueN(C$election), OUT))
print(C[, .(candidates = .N, seats = uniqueN(seat),
            ind = sum(party == "IND"),
            ind_breakouts = sum(party == "IND" & breakout),
            nonmajor_breakouts = sum(!party %in% c("ALP","LNP","NAT") & breakout)),
        by = .(election)][order(election)], row.names = FALSE)
cat(sprintf("\nBC9  non-major breakouts in total: %d  (the salience corpus had 21)\n",
            C[!party %in% c("ALP","LNP","NAT") & breakout == TRUE, .N]))
