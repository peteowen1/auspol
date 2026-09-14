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

# THE POLLING-PLACE DOWNLOAD CARRIES AN "Informal" PSEUDO-CANDIDATE ROW that
# the candidate-level results file candidacies.csv is built from does not --
# informal ballots are not a vote for anyone and are excluded from `pcv`
# everywhere else in this repo. Left in here, they fell through
# classify_party() into OTH and inflated the per-seat denominator by the
# seat's informal rate (typically 3-6%, fairly uniform nationwide), which
# silently diluted every real party's notional share by a near-constant
# amount. Found 2026-09-13 chasing what looked like a WA-specific
# redistribution effect on Tangney/Pearce: the same ~2-3 point "gap" showed
# up in EVERY state, including ones with no federal redistribution that
# cycle -- Pearce 2019 alone carried 6,153 informal votes, exactly the size
# of its notional-vs-raw discrepancy once every other party's totals were
# checked and matched exactly.
n_informal <- sum(J[Surname == "Informal"]$OrdinaryVotes, na.rm = TRUE)
.tot_all <- sum(J$OrdinaryVotes, na.rm = TRUE)
J <- J[Surname != "Informal"]
cat(sprintf("NB2i excluded %d informal vote(s) before computing shares (%.2f%% of the count)\n",
            n_informal, 100 * n_informal / .tot_all))
# COVERAGE FLOOR, not just a printed number. This is an exact-string match on
# a field the AEC controls; if they ever reformat it, the match finds nothing,
# prints "excluded 0", and silently reinstates the very contamination this
# exclusion exists to remove -- with a log line that reads like confirmation.
# Australian informal rates run ~3-6% of the House count and have never been
# near zero, so anything under 1% means the match broke, not that the ballots
# were unusually clean.
if (n_informal / .tot_all < 0.01)
  stop(sprintf("informal votes are %.3f%% of the count -- the `Surname == \"Informal\"` match has broken; refusing to compute shares on contaminated totals",
               100 * n_informal / .tot_all))

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

# MERGE, DO NOT CLOBBER. This script builds ONE pair per invocation (PRIOR ->
# TARGET, default 2022 -> 2025), but every consumer reads the file expecting
# ALL federal pairs. A plain overwrite meant that running the documented
# command with no env vars set silently reduced a six-pair file to one pair,
# and fit_xgb_primary_v6.R would then quietly apply x_notional_adj to a single
# pair and zero for the rest -- no error anywhere in the chain. Keep the other
# pairs, replace only the one just rebuilt.
.nbf <- "output/notional-baselines.csv"
.new <- N[, .(election, prior, seat, party, votes, pcv)]
if (file.exists(.nbf)) {
  .old <- fread(.nbf, showProgress = FALSE)
  .kept <- .old[!(election == .new$election[1] & prior == .new$prior[1])]
  cat(sprintf("\nNB9  keeping %d rows for %d other pair(s) already in the file\n",
              nrow(.kept), uniqueN(.kept$election)))
  .new <- rbindlist(list(.kept, .new), use.names = TRUE, fill = TRUE)
}
setorder(.new, election, seat, party)
fwrite(.new, .nbf)
cat(sprintf("NB9  wrote %s: %d rows, %d pair(s) -- %s\n", .nbf, nrow(.new),
            uniqueN(.new$election), paste(sort(unique(.new$election)), collapse = ", ")))
