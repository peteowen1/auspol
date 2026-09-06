# E1 (docs/plans/plan-candidate-level-model.md): "Add the model's projection
# per row for 'performance vs expected'" to output/candidate-contests.csv, for
# the website's candidate profile pages.
#
# WHAT "EXPECTED" MEANS HERE. Not a pre-election forecast (that needs a poll
# trend as of a specific date, only available for the live target) -- this is
# retrospective: given the party's ACTUAL statewide swing between the two
# elections, what would dev_slope() (R/dev_slope.R) have projected for this
# candidate's own seat, using the same seat-deviation-shrinkage the published
# model uses? performance_vs_expected = actual pcv - that projection, so a
# positive number is a candidate who beat their party's own state-level trend
# in their own seat, not one who "won" in any absolute sense.
#
# SLOPE CHOICE: candidate_returns()'s same/new split (conditional_slopes()'s
# defaults, IND 0.907/0.326 etc -- see R/dev_slope.R), not screened_slopes().
# The screen needs output/salience-v6.csv, which only covers 9 of 18 election
# pairs in this corpus; candidate_returns() only needs candidacies.csv and
# runs for all of them. A class absent from conditional_slopes()'s tables
# (ALP/LNP/NAT, and any class conditional_slopes() has no fitted value for)
# keeps slope 1 (uniform swing) -- consistent with how majors are modelled
# everywhere else in this repo: swing-driven, not candidate-driven.
#
# First appearance of an election in a region's sequence has no "prev" and
# gets expected_pcv = NA, not zero -- there is nothing to compare against.
#
# Emits BCP* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

C <- fread("output/candidacies.csv", showProgress = FALSE)

el_by_region <- C[, .(elections = list(sort(unique(year)))), by = region]
pairs <- rbindlist(lapply(seq_len(nrow(el_by_region)), function(i) {
  yrs <- el_by_region$elections[[i]]; rg <- el_by_region$region[i]
  if (length(yrs) < 2) return(NULL)
  data.table(region = rg, prev = yrs[-length(yrs)], now = yrs[-1])
}))
pairs[, election_prev := paste0(region, prev)]
pairs[, election_now := paste0(region, now)]
cat(sprintf("BCP1 %d consecutive election pairs across %d regions\n", nrow(pairs), uniqueN(pairs$region)))

ns <- function(x) gsub("[^a-z0-9]", "", tolower(x))

project_pair <- function(el_prev, el_now, region) {
  PREVT <- C[election == el_prev]; NOWT <- C[election == el_now]
  if (!nrow(PREVT) || !nrow(NOWT)) return(NULL)
  level_prev <- PREVT[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
  level_now  <- NOWT[,  .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
  ret <- tryCatch(candidate_returns(el_prev, el_now, corpus = C),
                  error = function(e) NULL)
  # BOTH spellings again, not an unconditional rename -- got this wrong the
  # first time (renaming PT$.s outright reproduces the exact bug
  # governed_population() had BEFORE its own 2026-09-04 fix: Denison
  # unconditionally becomes Clark even for the fed2010->fed2013 pair, where
  # neither side has been renamed yet, so `x` stops matching fed2013's own
  # still-"Denison" spelling). Every PREVT row contributes its pcv under BOTH
  # its raw and (if applicable) renamed key; N then matches on its own single
  # era-correct spelling, whichever era that is.
  rn <- seat_rename_map()
  PT <- copy(PREVT)[, .s := ns(seat)]
  PT[, .s_renamed := .s]
  PT[.s %in% names(rn), .s_renamed := rn[.s]]
  seat_x <- rbind(
    PT[, .(.s, party, pcv)],
    PT[.s != .s_renamed, .(.s = .s_renamed, party, pcv)]
  )[, .(x = max(pcv, na.rm = TRUE)), by = .(.s, party)]
  N <- copy(NOWT)[, .s := ns(seat)]
  N <- merge(N, seat_x, by = c(".s", "party"), all.x = TRUE)
  # A missing match here means "no candidate of this party's class contested
  # a seat with this NORMALISED NAME last time" -- which conflates two real
  # cases. For a MAJOR party that is always a redistribution/rename artifact
  # (ALP/LNP/NAT contest essentially every seat, every time) -- Kellyville
  # (nsw2023) matched zero nsw2019 rows because the seat didn't exist under
  # that name, and treating LNP's x as a literal 0% there put the entire 55%
  # statewide deviation into the projection, scoring Ray Williams (55.4%
  # actual) as a 55-point overperformance on a perfectly ordinary safe-seat
  # hold. Fixed: majors fall back to x = level_prev (deviation collapses to
  # 0, expected = level_now, i.e. "assume this seat tracks the state
  # average" -- the same absence-is-not-a-measurement principle CLAUDE.md
  # already applies to transfer tables). For non-majors, x = 0 stays the
  # right reading: minor parties genuinely do skip seats, and that IS real
  # information a slope < 1 should shrink toward, not an artifact to erase.
  MAJ <- c("ALP", "LNP", "NAT")
  N[is.na(x) & party %in% MAJ, x := level_prev[party]]
  N[is.na(x), x := 0]
  # OVERRIDE WITH THE PERSON'S OWN PRIOR VOTE where they personally return
  # under ANY non-major label, not just their current one -- same pattern
  # fit_seats_full.R's .own_x() already uses live. Without this, `x` above
  # (seat+CURRENT-party only) misses every party-switching incumbent:
  # Helen Dalton ran Murray as Shooters/Fishers/Farmers (OTH_RIGHT, 38.75%)
  # in nsw2019 and IND in nsw2023 -- the class-level lookup finds no IND
  # history in Murray at all, x falls back to 0, and her own substantial
  # personal following reads as a from-nothing surge. This is the identical
  # cross-party-continuity fault candidate_returns() exists to fix, in the
  # BASE value rather than the slope -- reusing personal_prior_vote()
  # directly rather than re-deriving it a second, inevitably-diverging way.
  own <- tryCatch(personal_prior_vote(el_prev, el_now, corpus = C), error = function(e) NULL)
  if (!is.null(own) && nrow(own)) {
    N <- merge(N, own, by = c("seat", "party"), all.x = TRUE)
    N[!is.na(own_prev_pcv), x := own_prev_pcv]
    N[, own_prev_pcv := NULL]
  }
  # dev_slope()'s level_prev/level_now are SCALARS (one statewide number per
  # call), unlike x and slope which vectorise over seats -- so this runs once
  # PER CLASS, not once for the whole pair. conditional_slopes() also needs
  # RAW seat names (it matches against candidate_returns()'s own `seat`
  # column, built from NOWT unnormalised), not the .s join key.
  #
  # `N[idx, col := f(x[idx], ...)]` DOUBLE-SUBSETS: `i = idx` already
  # restricts `x` inside `j` to those rows (data.table's normal `[i,j]`
  # scoping), so a second `[idx]` inside `j` re-indexes the ALREADY-filtered,
  # shorter vector using the ORIGINAL full-table row positions -- out of
  # range for most of them, silently NA. Cost 82% of rows (693/844 on the
  # first pair alone) before being caught by the coverage print below.
  # Fixed: `x` inside `j` is already correctly filtered; don't re-subset it.
  N[, expected_pcv := NA_real_]
  for (cls in unique(N$party)) {
    idx <- which(N$party == cls)
    lp <- if (cls %in% names(level_prev)) level_prev[[cls]] else 0
    ln <- if (cls %in% names(level_now))  level_now[[cls]]  else 0
    slope <- conditional_slopes(cls, N$seat[idx], ret)
    N[idx, expected_pcv := dev_slope(x, lp, ln, slope)]
  }
  # ONE ROW PER (seat, party): expected_pcv is a class-level projection, so
  # two candidates sharing a party in one seat (rare, but real) already get
  # the identical value. Collapsing here, not after, keeps the join below
  # from fanning out -- the exact join-fan-out trap this repo's CLAUDE.md
  # names repeatedly, this time on (seat, party) instead of (seat) alone.
  N[, election := el_now]
  N[, .(expected_pcv = expected_pcv[1]), by = .(election, region, seat, party)]
}

proj <- rbindlist(lapply(seq_len(nrow(pairs)), function(i)
  project_pair(pairs$election_prev[i], pairs$election_now[i], pairs$region[i])), fill = TRUE)
cat(sprintf("BCP2 projected %d (election, seat, party) cells across %d target elections\n",
            nrow(proj), uniqueN(proj$election)))

CC <- fread("output/candidate-contests.csv", showProgress = FALSE)
# IDEMPOTENT: this script overwrites its own input file, so a rerun reads a
# copy that already carries these two columns -- drop them first, or the
# merge below renames both sides to expected_pcv.x/.y instead of adding one.
old_cols <- intersect(c("expected_pcv", "performance_vs_expected"), names(CC))
if (length(old_cols)) CC[, (old_cols) := NULL]
proj[, .s := ns(seat)]
CC[, .s := ns(seat)]
before <- nrow(CC)
CC <- merge(CC, proj[, .(election, region, .s, party, expected_pcv)],
           by = c("election", "region", ".s", "party"), all.x = TRUE)
stopifnot(nrow(CC) == before)  # join must not fan out
CC[, .s := NULL]
CC[, performance_vs_expected := pcv - expected_pcv]

n_scored <- sum(!is.na(CC$expected_pcv))
cat(sprintf("BCP3 %d of %d candidate-contests rows (%.1f%%) got an expected_pcv; rest are first appearances of that region's first election\n",
            n_scored, nrow(CC), 100 * n_scored / nrow(CC)))
cat(sprintf("BCP3 performance_vs_expected: mean %.2f | sd %.2f | range [%.1f, %.1f]\n",
            mean(CC$performance_vs_expected, na.rm = TRUE), sd(CC$performance_vs_expected, na.rm = TRUE),
            min(CC$performance_vs_expected, na.rm = TRUE), max(CC$performance_vs_expected, na.rm = TRUE)))

cat("\nBCP4 top 10 overperformers (candidate beat their own party's state trend by the most):\n")
top <- CC[order(-performance_vs_expected)][1:10]
print(top[, .(election, seat, party, surname, given, pcv = round(pcv,1),
             expected_pcv = round(expected_pcv,1), performance_vs_expected = round(performance_vs_expected,1))])

fwrite(CC, "output/candidate-contests.csv")
cat(sprintf("\nBCP9 wrote output/candidate-contests.csv: %d rows, %d columns\n", nrow(CC), ncol(CC)))
