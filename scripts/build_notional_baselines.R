# Notional prior-election results for redistributed and NEW federal seats.
#
# WHY. A seat created or redrawn by a redistribution has no prior result under
# its new name, so `backtest_candidate_fed.R` drops it:
#
#   BF1  1 divisions have no 2022 baseline and are not scored: Bullwinkel
#
# That is a structural blind spot, not a scoring convenience. AE Forecasts
# called Bullwinkel at 0.748 and was right; we cannot forecast it at all, and
# on the 150-seat basis that single seat was 85% of our entire remaining
# log-loss deficit to them (docs/reviews/fed2025-closing-the-aef-gap-2026-09-04.md).
# It matters well beyond fed2025: Victoria redistributes before 2026, and any
# new or heavily redrawn seat is currently unforecastable.
#
# HOW. The AEC publishes first preferences BY POLLING PLACE per state, and
# `PollingPlaceID` is stable across elections. So the target election's file
# says which division each booth now sits in, and the prior election's file
# says how that same booth voted. Summing the prior votes grouped by the
# TARGET division gives each seat -- including a brand-new one -- a notional
# prior result on its current boundaries.
#
# No coordinates or boundary files are needed for booths that persist, which
# is the large majority: 90.9% of WA's 2022 booth rows map to a 2025 division.
# The unmatched remainder is mostly closed booths and special hospital teams,
# which is a coverage limitation reported below rather than silently absorbed.
#
# Emits NB* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

RAW <- file.path("external", "reference", "aec", "booths")
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)
UA <- "Mozilla/5.0 (auspol research; contact via github.com/peteowen1/auspol)"
STATES <- c("NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT")
IDS <- c("2007" = 13745, "2010" = 15508, "2013" = 17496, "2016" = 20499,
         "2019" = 24310, "2022" = 27966, "2025" = 31496)

# Pair: prior election -> target election whose boundaries we project onto.
PRIOR  <- as.integer(Sys.getenv("AUSPOL_NB_PRIOR", "2022"))
TARGET <- as.integer(Sys.getenv("AUSPOL_NB_TARGET", "2025"))

grab <- function(year, st) {
  id <- IDS[[as.character(year)]]
  f <- file.path(RAW, sprintf("pp-fed%d-%s.csv", year, st))
  if (!file.exists(f) || file.info(f)$size < 5000) {
    url <- sprintf(
      "https://results.aec.gov.au/%d/Website/Downloads/HouseStateFirstPrefsByPollingPlaceDownload-%d-%s.csv",
      id, id, st)
    ok <- tryCatch({ utils::download.file(url, f, mode = "wb", quiet = TRUE,
                                          headers = c("User-Agent" = UA)); TRUE },
                   error = function(e) FALSE)
    Sys.sleep(0.2)
    if (!ok) return(NULL)
  }
  if (!file.exists(f) || file.info(f)$size < 5000) return(NULL)
  x <- tryCatch(fread(f, skip = 1, showProgress = FALSE), error = function(e) NULL)
  if (is.null(x) || !nrow(x)) return(NULL)
  setnames(x, make.names(names(x)))
  if (!all(c("PollingPlaceID", "DivisionNm", "OrdinaryVotes") %in% names(x))) return(NULL)
  x[, state := st][]
}

cat(sprintf("NB1  building notional fed%d results on fed%d boundaries\n", PRIOR, TARGET))
A <- rbindlist(lapply(STATES, function(s) grab(PRIOR, s)), fill = TRUE)
B <- rbindlist(lapply(STATES, function(s) grab(TARGET, s)), fill = TRUE)
if (!nrow(A) || !nrow(B)) stop("NB!  could not fetch polling-place files")
cat(sprintf("NB1  fed%d: %d rows, %d booths | fed%d: %d rows, %d booths\n",
            PRIOR, nrow(A), uniqueN(A$PollingPlaceID),
            TARGET, nrow(B), uniqueN(B$PollingPlaceID)))

# A booth id can only mean one target division; assert rather than assume.
map <- unique(B[, .(PollingPlaceID, seat = DivisionNm)])
dup <- map[, .N, by = PollingPlaceID][N > 1L]
if (nrow(dup)) stop("NB!  ", nrow(dup), " polling places map to >1 target division")

J <- merge(A, map, by = "PollingPlaceID")
cov <- 100 * sum(J$OrdinaryVotes) / sum(A$OrdinaryVotes)
cat(sprintf("NB2  booth rows matched: %d of %d (%.1f%%) | VOTES matched: %.1f%%\n",
            nrow(J), nrow(A), 100 * nrow(J) / nrow(A), cov))
if (cov < 80) stop("NB!  only ", round(cov, 1), "% of prior votes map forward; refusing")

J[, party := classify_party(PartyNm, PartyAb)]
N <- J[, .(votes = sum(OrdinaryVotes)), by = .(seat, party)]
N[, pcv := 100 * votes / sum(votes), by = seat]
N[, `:=`(election = sprintf("fed%d", TARGET), prior = sprintf("fed%d", PRIOR))]

# WHICH SEATS THIS ACTUALLY RESCUES: present at the target election with no
# prior result under the same name.
C <- fread("output/candidacies.csv", showProgress = FALSE)
have_prior <- unique(C[election == sprintf("fed%d", PRIOR), seat])
now <- unique(C[election == sprintf("fed%d", TARGET), seat])
newseats <- setdiff(now, have_prior)
cat(sprintf("\nNB3  seats at fed%d with NO fed%d result under that name: %s\n",
            TARGET, PRIOR, if (length(newseats)) paste(newseats, collapse = ", ") else "none"))
for (s in newseats) {
  cat(sprintf("\nNB3  notional fed%d baseline for %s:\n", PRIOR, s))
  print(N[seat == s][order(-pcv)][, .(party, votes, pcv = round(pcv, 2))])
}

fwrite(N[, .(election, prior, seat, party, votes, pcv)],
       "output/notional-baselines.csv")
cat(sprintf("\nNB9  wrote output/notional-baselines.csv: %d rows, %d seats\n",
            nrow(N), uniqueN(N$seat)))
