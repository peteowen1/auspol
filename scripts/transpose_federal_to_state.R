# Federal first preferences, transposed onto STATE district boundaries.
#
# WHY. The seat model's single best predictor is `fed_swing` -- how a seat swung
# at the last federal election -- at t = 8.46, better than anything else
# measured here. But it exists in only two seat files (2022vic, 2023nsw), which
# is why the seat-swing work is stuck at two elections and why the port into the
# candidate model cannot be validated.
#
# It is also the missing input for the One Nation allocation. That currently
# orders seats by GREENS share and quantile-maps magnitudes onto South
# Australia, and comes out 22 points below YouGov in Lowan and Ovens Valley.
# The federal One Nation vote in those districts' own booths is a direct
# measurement rather than a two-step proxy.
#
# HOW. The anchor ships booth-level correspondences -- `booths-2026vic.txt` and
# friends -- mapping each state district to the federal booths inside it. The
# AEC publishes first preferences per booth. Joining them gives each state
# district's federal profile: not an inferred demographic correspondence but
# actual votes cast in actual places.
#
# LIMITATION, measured rather than assumed: declaration votes (postal, absent,
# pre-poll) cannot be tied to a booth and so cannot be geolocated to a state
# district. The share of the federal vote this loses is reported per state, and
# it is why the output is a district PROFILE rather than a district total.
#
# Emits TF* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")
RAW <- file.path("external", "reference", "aec", "booths")
CORR <- file.path("external", "aus-polling-analyser", "analysis", "Federal-State")
OUT <- election_data_path()
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)

# (state cycle file, its state, the federal election that PRECEDED it, AEC id)
JOBS <- list(
  list(corr = "booths-2019nsw.txt", region = "nsw", cycle = 2019, fed = 2016, id = 20499),
  # Federal 2022, not 2019. The Victorian election is NOVEMBER 2022 and the
  # federal one was May 2022, so 2022 is the election that precedes it -- and
  # the correspondence file proves it, referencing the division "Hawke", which
  # the 2021 federal redistribution created and which did not exist in 2019.
  # Pairing it with 2019 matched 70.9% of booths and left Melton and Sunbury
  # with none at all, which the district guard caught.
  list(corr = "booths-2022vic.txt", region = "vic", cycle = 2022, fed = 2022, id = 27966),
  list(corr = "booths-2023nsw.txt", region = "nsw", cycle = 2023, fed = 2022, id = 27966),
  list(corr = "booths-2026vic.txt", region = "vic", cycle = 2026, fed = 2025, id = 31496),
  list(corr = "booths-2027nsw.txt", region = "nsw", cycle = 2027, fed = 2025, id = 31496),
  # SOUTH AUSTRALIA VOTES IN MARCH, so its 2022 poll is preceded by federal
  # 2019 -- not 2022, which came two months AFTER it and would leak. Its 2026
  # poll is preceded by federal 2025 (May 2025).
  #
  # sa2026 is here because the One Nation ORDERING rule can be tested on it
  # without circularity: the ordering uses only federal booth data, whereas the
  # allocation's SHAPE (`sa_ratio` in fit_seats_full.R) is fitted on SA 2026
  # itself and therefore cannot be.
  list(corr = "booths-2022sa.txt",  region = "sa",  cycle = 2022, fed = 2019, id = 24310),
  list(corr = "booths-2026sa.txt",  region = "sa",  cycle = 2026, fed = 2025, id = 31496))

read_corr <- function(f) {
  ln <- readLines(file.path(CORR, f), warn = FALSE)
  ln <- ln[nzchar(ln)]
  district <- NA_character_; out <- list()
  for (l in ln) {
    if (startsWith(l, "#")) { district <- substring(l, 2); next }
    parts <- strsplit(l, ",", fixed = TRUE)[[1]]
    if (length(parts) < 2 || is.na(district)) next
    out[[length(out) + 1L]] <- data.table(
      district = district, division = trimws(parts[1]),
      booth = trimws(paste(parts[-1], collapse = ",")))
  }
  rbindlist(out)
}

grab_booths <- function(id, state, year) {
  dest <- file.path(RAW, sprintf("fed%d-%s.csv", year, state))
  if (!file.exists(dest) || file.info(dest)$size < 50000) {
    utils::download.file(
      sprintf("https://results.aec.gov.au/%d/Website/Downloads/HouseStateFirstPrefsByPollingPlaceDownload-%d-%s.csv",
              id, id, state), dest, mode = "wb", quiet = TRUE,
      headers = c("User-Agent" = UA))
  }
  # The AEC prefixes a one-line banner before the header row.
  d <- fread(dest, skip = 1L, showProgress = FALSE)
  setnames(d, make.names(names(d)))
  need <- c("DivisionNm", "PollingPlace", "PartyNm", "PartyAb", "OrdinaryVotes")
  miss <- setdiff(need, names(d))
  if (length(miss)) {
    stop("Booth file for ", year, " ", state, " lacks: ", paste(miss, collapse = ", "))
  }
  d
}

all_out <- list()
for (J in JOBS) {
  corr <- read_corr(J$corr)
  st <- toupper(J$region)
  bo <- grab_booths(J$id, st, J$fed)
  bo[, votes := as.numeric(OrdinaryVotes)]
  bo <- bo[is.finite(votes) & votes >= 0]
  # Classify outside the brackets -- `party` would shadow a column inside `[`.
  cls <- classify_party(bo$PartyNm, bo$PartyAb)
  bo[, party_class := cls]

  m <- merge(corr, bo, by.x = c("division", "booth"),
             by.y = c("DivisionNm", "PollingPlace"),
             allow.cartesian = TRUE)
  matched_booths <- uniqueN(m[, .(division, booth)])
  corr_booths <- uniqueN(corr[, .(division, booth)])
  cat(sprintf("\nTF1  %s %d <- federal %d: %d of %d correspondence booths matched (%.1f%%)\n",
              toupper(J$region), J$cycle, J$fed, matched_booths, corr_booths,
              100 * matched_booths / corr_booths))
  cat(sprintf("TF1  %s of the state's ordinary federal vote is inside a mapped booth (%.1f%%)\n",
              format(sum(m$votes), big.mark = ","),
              100 * sum(m$votes) / sum(bo$votes)))
  # Districts are the unit that must be complete; a district with no booths at
  # all would silently vanish from the output.
  got <- uniqueN(m$district); want <- uniqueN(corr$district)
  if (got < want) {
    stop(J$corr, ": only ", got, " of ", want, " districts matched any booth. ",
         "Missing: ", paste(setdiff(unique(corr$district), unique(m$district)),
                            collapse = ", "))
  }

  agg <- m[, .(votes = sum(votes)), by = .(seat = district, party = party_class)]
  agg[, pct := 100 * votes / sum(votes), by = seat]
  agg[, `:=`(region = J$region, cycle = J$cycle, fed_election = J$fed)]
  sh <- agg[, .(v = sum(votes)), by = party][, .(party, pct = round(100 * v / sum(v), 2))]
  print(sh[order(-pct)])
  # Anchor: a transposed major-party share outside 20-55% means the join or the
  # classifier is wrong, whatever the booth match rate says.
  for (p in c("ALP", "LNP")) {
    v <- sh[party == p, pct]
    if (!length(v) || v < 20 || v > 55) {
      stop(J$corr, ": transposed ", p, " share is ",
           if (length(v)) round(v, 1) else "NA", "%, outside any plausible range.")
    }
  }
  all_out[[length(all_out) + 1L]] <- agg
}

res <- rbindlist(all_out)
fwrite(res, file.path(OUT, "federal-transposed-to-state.csv"))
cat(sprintf("\nTF2  wrote %s\n", file.path(OUT, "federal-transposed-to-state.csv")))
cat(sprintf("TF2  %d rows, %d state-cycles, %d districts\n", nrow(res),
            uniqueN(res[, .(region, cycle)]), uniqueN(res[, .(region, cycle, seat)])))

cat("\nTF3  One Nation's transposed federal vote, by state cycle\n")
print(res[party == "ONP", .(districts = .N, mean = round(mean(pct), 2),
                            sd = round(stats::sd(pct), 2),
                            max = round(max(pct), 1)), by = .(region, cycle)])
