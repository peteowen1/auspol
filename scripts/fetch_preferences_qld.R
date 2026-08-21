# Queensland state election results, from the ECQ's own results data host.
#
# WHY QUEENSLAND MATTERS MORE THAN ITS SEAT COUNT. The flow matrix that decides
# Victorian seats is built from Victoria (452 exclusions, but almost no One
# Nation) and South Australia (294, One Nation at 22.9% but one election).
# Queensland is where One Nation has had real support for thirty years, and it
# has never been in this repo. Its transfers are the ones the matrix most
# lacks.
#
# HOW IT WAS FOUND. results.elections.qld.gov.au is an Angular application whose
# HTML is an empty shell -- the same wall as the South Australian site. The data
# host sits in plain text in its main bundle:
#
#   dm = "https://resultsdata.elections.qld.gov.au/"
#
# `elections.json` there lists every event with an `archiveXML` link to a zipped
# XML of the full result. No key, no auth.
#
# WHAT THE XML HOLDS, and it is more than any other source here:
#   * per-district first preferences, with a party code per candidate
#   * the DISTRICT-LEVEL distribution of preferences, every exclusion round
#   * per-booth versions of both, and 1,339 booths with coordinates
#   * the declared winner
#   * votingSystem per district, which reads "Compulsory Preferential" -- so
#     these transfers may be pooled with Victoria's and South Australia's.
#     Queensland used OPTIONAL preferential until 2016 and any earlier election
#     must NOT be pooled; the check below refuses one.
#
# Emits QF* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xml2))

BASE <- "https://resultsdata.elections.qld.gov.au"
RAW  <- file.path("external", "reference", "ecq")
OUT  <- election_data_path()
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)
UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")

# (year, the zip the elections.json index points at)
EVENTS <- list(
  list(year = 2020L, zip = "publicResults_State2020_aurukun2020_Final.zip"),
  list(year = 2024L, zip = "publicResults_SGE2024_ICCDiv4_Final.zip"))

grab <- function(url, dest) {
  if (!file.exists(dest) || file.info(dest)$size < 10000) {
    utils::download.file(url, dest, mode = "wb", quiet = TRUE,
                         headers = c("User-Agent" = UA))
  }
  dest
}

all_fp <- list(); all_tx <- list(); all_win <- list()
for (E in EVENTS) {
  z <- grab(file.path(BASE, "XMLData", E$zip), file.path(RAW, basename(E$zip)))
  xf <- file.path(RAW, sprintf("qld%d.xml", E$year))
  if (!file.exists(xf)) {
    tmp <- tempfile(); dir.create(tmp)
    utils::unzip(z, exdir = tmp)
    f <- list.files(tmp, pattern = "[.]xml$", full.names = TRUE, recursive = TRUE)[1]
    file.copy(f, xf, overwrite = TRUE)
  }
  doc <- read_xml(xf)

  # These archives BUNDLE unrelated events -- the 2024 file carries an Ipswich
  # City Council by-election alongside the state general. Selecting by
  # eventType rather than taking the first election is the difference between
  # 93 districts and 94.
  els <- xml_find_all(doc, "//election[@eventType='State General']")
  if (length(els) != 1L) {
    stop("qld", E$year, ": found ", length(els), " State General elections in ",
         basename(xf), ", expected 1. The archive bundles other events.")
  }
  el <- els[[1]]
  dis <- xml_find_all(el, ".//district")
  cat(sprintf("\nQF1  QLD %d (%s): %d districts\n", E$year,
              xml_attr(el, "electionName"), length(dis)))

  vs <- unique(xml_attr(dis, "votingSystem"))
  cat(sprintf("QF1  voting system: %s\n", paste(vs, collapse = ", ")))
  if (!all(grepl("Compulsory", vs))) {
    stop("qld", E$year, " is not compulsory preferential (", paste(vs, collapse = ", "),
         "). Queensland used OPTIONAL preferential until 2016, and those ",
         "transfers cannot be pooled with full-preferential elections -- ",
         "exhausted ballots make the rates mean something different.")
  }

  for (d in dis) {
    seat <- xml_attr(d, "districtName")
    cand <- xml_find_all(d, "./candidates/candidate")
    key <- xml_attr(cand, "ballotName")
    cls <- classify_party(xml_attr(cand, "party"), xml_attr(cand, "partyCode"))
    look <- setNames(cls, key)

    fpr <- xml_find_first(d, "./countRound[@preferences='NO'][@unofficial='NO']/primaryVoteResults")
    if (!inherits(fpr, "xml_missing")) {
      cc <- xml_find_all(fpr, "./candidate")
      all_fp[[length(all_fp) + 1L]] <- data.table(
        election = sprintf("qld%d", E$year),
        seat = seat, party = unname(look[xml_attr(cc, "ballotName")]),
        votes = as.numeric(xml_text(xml_find_first(cc, "./count"))))
    }

    dp <- xml_find_first(d, "./countRound[@preferences='YES']/preferenceDistributionSummary")
    if (!inherits(dp, "xml_missing")) {
      for (pd in xml_find_all(dp, "./preferenceDistribution")) {
        from <- look[[xml_attr(pd, "excludedBallotName")]]
        cp <- xml_find_all(pd, "./candidatePreferences")
        if (!length(cp)) next
        all_tx[[length(all_tx) + 1L]] <- data.table(
          election = sprintf("qld%d", E$year), seat = seat,
          round = as.integer(xml_attr(pd, "distribution")),
          from = from, to = unname(look[xml_attr(cp, "ballotName")]),
          votes = as.numeric(xml_text(xml_find_first(cp, "./count"))))
      }
    }

    dc <- xml_find_first(d, "./declaredCandidate")
    if (!inherits(dc, "xml_missing")) {
      nm <- xml_attr(dc, "ballotName")
      if (!is.na(nm) && nm %in% names(look)) {
        all_win[[length(all_win) + 1L]] <- data.table(
          election = sprintf("qld%d", E$year), seat = seat,
          winner = unname(look[[nm]]))
      }
    }
  }
}

# BY ELECTION AS WELL AS SEAT. Without the election key both years' primaries
# summed together, and because the district names are identical across the two
# polls every per-year filter then returned the same pooled rows -- so 2020 and
# 2024 printed byte-identical statewide shares. Caught only because two
# different elections cannot have the same first preferences to two decimals.
FP <- rbindlist(all_fp)[!is.na(party),
                        .(votes = sum(votes)), by = .(election, seat, party)]
TX <- rbindlist(all_tx)[!is.na(from) & !is.na(to) & votes > 0,
                        .(votes = sum(votes)), by = .(election, seat, round, from, to)]
WIN <- rbindlist(all_win)

for (E in EVENTS) {
  y <- sprintf("qld%d", E$year)
  f <- FP[election == y]
  st <- f[, .(v = sum(votes)), by = party][, .(party, pct = round(100 * v / sum(v), 2))]
  setorder(st, -pct)
  cat(sprintf("\nQF2  %s statewide first preferences\n", y))
  print(st)
  cat(sprintf("QF2  seats won: %s\n",
              paste(sprintf("%s %d", names(table(WIN[election == y, winner])),
                            as.integer(table(WIN[election == y, winner]))),
                    collapse = ", ")))
  cat(sprintf("QF3  %s: %d exclusion events, %s votes transferred\n", y,
              uniqueN(TX[election == y, paste(seat, round)]),
              format(TX[election == y, sum(votes)], big.mark = ",")))
}

# Two elections cannot share a statewide vote. This is the guard that would
# have caught the pooling bug immediately rather than leaving it to be spotted
# by eye in the printed table.
share <- FP[, .(v = sum(votes)), by = .(election, party)]
share[, pct := 100 * v / sum(v), by = election]
w <- dcast(share, party ~ election, value.var = "pct")
if (ncol(w) == 3L && isTRUE(all.equal(w[[2]], w[[3]], tolerance = 1e-6))) {
  stop("The two Queensland elections have identical statewide first ",
       "preferences, which cannot be true. The election key is missing from ",
       "the first-preference table and the years are pooled.")
}
cat("
QF3b two elections, two different statewide votes: OK
")

# One first-preference file per election, matching the Victorian and South
# Australian naming so the harnesses can find them without a special case.
for (E in EVENTS) {
  y <- sprintf("qld%d", E$year)
  fwrite(FP[election == y, .(seat, party, votes)],
         file.path(OUT, sprintf("ecq-%d-qld-firstprefs.csv", E$year)))
}
fwrite(TX, file.path(OUT, "ecq-qld-transfers.csv"))
fwrite(WIN, file.path(OUT, "ecq-qld-winners.csv"))
cat(sprintf("\nQF4  wrote firstprefs, %d transfer rows and %d winners to %s\n",
            nrow(TX), nrow(WIN), OUT))
