#' Which seats have the SAME candidate standing again for a class
#'
#' The seat model is party-class based, so a returning independent and a
#' stranger are projected identically. Measured across 17 election pairs that is
#' the largest single effect available: a seat polling 30% for an independent
#' projects to 30.3% if the same person stands and 12.1% if they do not.
#'
#' \tabular{lrrr}{
#'   class \tab same person \tab person gone \tab t \cr
#'   IND \tab 0.907 \tab 0.326 \tab 12.3 \cr
#'   OTH_RIGHT \tab 0.891 \tab 0.325 \tab 15.4 \cr
#'   GRN \tab 0.994 \tab 0.880 \tab 4.5 \cr
#'   ONP \tab 0.610 \tab 0.545 \tab 0.7
#' }
#'
#' Matching is on SURNAME plus first initial within the seat and class, via
#' [match_key()]. Surname alone wrongly joins two people sharing one; a full
#' first name wrongly splits Bob from Robert. Neither error is symmetric —
#' splitting turns a returning member into a fabricated emergence, which is what
#' four NSW seats did when the emergence definition keyed on party class.
#'
#' Western Australia publishes bare surnames with no given name, so matching
#' there falls back to surname within seat. That is stated rather than hidden:
#' two different candidates sharing a surname in one WA seat would read as
#' persistence, and WA is 7 of the 17 pairs.
#'
#' @param election_from,election_to Election labels as they appear in the
#'   corpus, e.g. `"fed2019"` and `"fed2022"`.
#' @param corpus Optional pre-read candidacy table; read from
#'   `output/candidacies.csv` when `NULL`.
#' @return A `data.table` of `seat`, `party`, `same` covering every seat/class
#'   present at `election_to`. `same` is `FALSE` where nobody of that class stood
#'   before, which is the correct reading: there is no one to return.
#' @export
candidate_returns <- function(election_from, election_to, corpus = NULL) {
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) {
      stop("candidate_returns() needs output/candidacies.csv; run ",
           "scripts/build_candidacies.R", call. = FALSE)
    }
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  need <- c("election", "seat", "party")
  miss <- setdiff(need, names(C))
  if (length(miss)) stop("corpus lacks: ", paste(miss, collapse = ", "), call. = FALSE)

  # NOT `now`/`prev` as names: those collide with columns built below, and a bare
  # symbol inside dt[...] binds to the column. Six instances in this repo.
  NOWT  <- C[C$election == election_to]
  PREVT <- C[C$election == election_from]
  if (!nrow(NOWT)) stop("no rows for election ", election_to, call. = FALSE)
  if (!nrow(PREVT)) stop("no rows for election ", election_from, call. = FALSE)

  kf <- function(d) {
    sur <- surname_of(if ("surname" %in% names(d)) d$surname else NA_character_,
                      if ("name" %in% names(d)) d$name else NA_character_)
    giv <- given_of(if ("given" %in% names(d)) d$given else NA_character_,
                    if ("name" %in% names(d)) d$name else NA_character_)
    match_key(sur, giv, "initial")
  }
  NOWT  <- data.table::copy(NOWT)[,  .k := kf(.SD), .SDcols = names(NOWT)]
  PREVT <- data.table::copy(PREVT)[, .k := kf(.SD), .SDcols = names(PREVT)]

  # JOIN ON A NORMALISED SEAT KEY. The corpus is not internally consistent:
  # vic2014 and vic2018 store seats as "albertpark" while vic2022 stores
  # "Albert Park", so an exact join between them matched ZERO of 508 seat-classes
  # and reported that no Victorian candidate had ever re-stood. That reads as a
  # real answer -- some elections genuinely have few returners -- and Victoria is
  # the live target. Caught only because every other pair ran 15-26%.
  #
  # Normalising here rather than in the corpus keeps this fix at the point of
  # use; the corpus inconsistency is a separate defect and is recorded as one.
  NOWT[,  .s := normalise_seat(seat)]
  PREVT[, .s := normalise_seat(seat)]
  # MATCH THE PERSON ACROSS THE SEAT, NOT WITHIN THE PARTY CLASS.
  #
  # Philip Donato held Orange with 49.1% as a Shooter in 2019 and 53.1% as an
  # independent in 2023. Matching within (seat, party) called him a NEW
  # independent, so a sitting member with a five-year incumbency counted as an
  # emergence -- and as the single failure of the salience screen in an election
  # where it otherwise had none. Every party-switcher had the same fault, which
  # is the NSW Shooters-to-independent trap CLAUDE.md already records in another
  # form.
  #
  # A returning candidate is the same PERSON in the same SEAT. Which label they
  # stand under is a separate question and belongs to the party swing.
  #
  # MATCH BOTH PRE- AND POST-RENAME SPELLING of PREVT's seat, not just the
  # renamed one -- found 2026-09-04 building a candidate-performance feature:
  # Andrew Wilkie's continuous Denison (2016) -> Clark (2019) hold read as a
  # brand-new candidate because `normalise_seat()` alone doesn't equate them.
  # seat_rename_map() was fixed for this exact fault in governed_population()
  # (R/salience_screen.R) five commits earlier the same day and not carried
  # here -- the identical "fixed once, not in its sibling" failure
  # [[normalise_name]]'s own docs record. Matching only the renamed spelling
  # would be wrong the other way, for any pair entirely BEFORE the rename (see
  # governed_population()'s own history of that exact second bug) -- both
  # PREVT keys are kept, matched against NOWT's own (already-current-era) seat
  # spelling, correct regardless of which side of a rename either election
  # falls on.
  rn <- seat_rename_map()
  PREVT[, .s_renamed := .s]
  PREVT[.s %in% names(rn), .s_renamed := rn[.s]]
  prev_keys <- unique(rbind(
    PREVT[nzchar(PREVT$.k), list(.s = .s,         .k)],
    PREVT[nzchar(PREVT$.k), list(.s = .s_renamed, .k)]))
  out <- unique(NOWT[nzchar(NOWT$.k), list(seat, .s, party, .k)])
  out <- merge(out, unique(prev_keys)[, `:=`(hit = TRUE)],
               by = c(".s", ".k"), all.x = TRUE)
  out[is.na(hit), hit := FALSE]
  # WAS THAT RETURNING PERSON THE SITTING MEMBER? A returning candidate and a
  # returning MEMBER behave measurably differently, and pooling them costs
  # real accuracy on exactly the seats this model is worst at. Regressing the
  # seat's deviation-from-statewide at the target election on the same
  # deviation at the previous one, over 531 returning non-major candidacies
  # across 10 election pairs:
  #
  #   returning, WAS the sitting MP   n= 52  slope 0.954 (se 0.026)
  #   returning, was NOT the MP       n=479  slope 0.800 (se 0.046)
  #   pooled (what conditional_slopes() used)  0.924
  #
  # The two differ by 0.154, about 2.9 SE. Pooling shrinks an entrenched
  # independent toward a ~5% statewide IND average every cycle: a teal on 36%
  # is projected at 5 + 0.907*(36-5) = 33.1 when the measured expectation is
  # flat (mean vote change -0.13 points across 52 sitting non-major MPs, who
  # hold their seat 82.7% of the time). That understatement is where nearly
  # all of the fed2025 seat log-loss gap to AE Forecasts sits.
  #
  # `elected` is optional in the corpus, so its absence degrades to same_mp =
  # FALSE (i.e. exactly the previous behaviour) rather than erroring.
  if ("elected" %in% names(PREVT)) {
    mp_keys <- unique(rbind(
      PREVT[nzchar(PREVT$.k) & PREVT$elected %in% TRUE, list(.s = .s,         .k)],
      PREVT[nzchar(PREVT$.k) & PREVT$elected %in% TRUE, list(.s = .s_renamed, .k)]))
    out <- merge(out, unique(mp_keys)[, `:=`(mp_hit = TRUE)],
                 by = c(".s", ".k"), all.x = TRUE)
    out[is.na(mp_hit), mp_hit := FALSE]
  } else {
    out[, mp_hit := FALSE]
  }
  res <- out[, list(same = any(hit), same_mp = any(mp_hit)),
             by = list(seat, party)]  # target's own names
  # Every seat/class at the target election, so a caller can index without
  # worrying about which ones had a match at all.
  full <- unique(NOWT[, list(seat, party)])
  res <- merge(full, res, by = c("seat", "party"), all.x = TRUE)
  res[is.na(same), same := FALSE]
  res[is.na(same_mp), same_mp := FALSE][]
}

#' Does the LEADING candidate of a class personally return, not just anyone in it?
#'
#' `candidate_returns()` answers "does ANY candidate of this class in this seat
#' match a prior one" -- a class-level fact. In a multi-candidate seat that can
#' misattribute identity: if a minor candidate happens to match a prior name
#' while the actual front-runner is new, the class reads "returning" and a
#' slope meant for a specific person's history gets applied to a swing that is
#' mostly driven by someone else entirely.
#'
#' Measured across the five elections arm CS was scored on: 111 multi-candidate
#' class instances read "returning" at the class level; correcting for a seat-
#' naming mismatch in the FIRST attempt at this check (vic2018 stores seats
#' lower-case, vic2022 titlecase -- the exact fault [[candidate_returns]] was
#' built to fix, reintroduced by a verification script that did not reuse it)
#' found the true count. No misattributed leader won the seat in any of the
#' five, so nothing shipped changes -- but the leader-level fact is more
#' correct and is what a future slope-selection step should key on.
#'
#' @inheritParams candidate_returns
#' @return A `data.table` of `seat`, `party`, `leader_same` -- TRUE only when
#'   the candidate with the LARGEST current share of that class personally
#'   stood before, using the same seat-normalisation and name-matching as
#'   [candidate_returns()].
#' @export
leading_candidate_returns <- function(election_from, election_to, corpus = NULL) {
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) {
      stop("leading_candidate_returns() needs output/candidacies.csv; run ",
           "scripts/build_candidacies.R", call. = FALSE)
    }
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  need <- c("election", "seat", "party", "pcv")
  miss <- setdiff(need, names(C))
  if (length(miss)) stop("corpus lacks: ", paste(miss, collapse = ", "), call. = FALSE)

  NOWT  <- C[C$election == election_to]
  PREVT <- C[C$election == election_from]
  if (!nrow(NOWT))  stop("no rows for election ", election_to, call. = FALSE)
  if (!nrow(PREVT)) stop("no rows for election ", election_from, call. = FALSE)

  kf <- function(d) {
    sur <- surname_of(if ("surname" %in% names(d)) d$surname else NA_character_,
                      if ("name" %in% names(d)) d$name else NA_character_)
    giv <- given_of(if ("given" %in% names(d)) d$given else NA_character_,
                    if ("name" %in% names(d)) d$name else NA_character_)
    match_key(sur, giv, "initial")
  }
  NOWT  <- data.table::copy(NOWT)[,  .k := kf(.SD), .SDcols = names(NOWT)]
  PREVT <- data.table::copy(PREVT)[, .k := kf(.SD), .SDcols = names(PREVT)]
  NOWT[,  .s := normalise_seat(seat)]
  PREVT[, .s := normalise_seat(seat)]

  # The LEADING row per (seat, party): highest current pcv.
  data.table::setorder(NOWT, seat, party, -pcv)
  lead <- NOWT[nzchar(.k), .SD[1], by = .(seat, party)]

  # Match both spellings of a renamed seat -- see the matching comment in
  # candidate_returns() above; same fault, same fix, kept in sync because
  # both read the identical PREVT$seat/NOWT$seat shape.
  rn <- seat_rename_map()
  PREVT[, .s_renamed := .s]
  PREVT[.s %in% names(rn), .s_renamed := rn[.s]]
  prev_keys <- unique(rbind(
    PREVT[nzchar(PREVT$.k), list(.s = .s,         .k)],
    PREVT[nzchar(PREVT$.k), list(.s = .s_renamed, .k)]))
  out <- merge(lead[, list(seat, .s, party, .k)], prev_keys[, `:=`(hit = TRUE)],
               by = c(".s", ".k"), all.x = TRUE)
  out[is.na(hit), hit := FALSE]
  out[, list(seat, party, leader_same = hit)]
}

#' A personally-returning leading candidate's OWN prior vote, under whatever
#' party they ran as then
#'
#' [candidate_returns()] and [screened_slopes()] correctly identify a
#' returning candidate regardless of party -- Philip Donato held Orange with
#' 49.1% as a Shooter in 2019 and 53.1% as an independent in 2023 -- and use
#' that to pick a gentler SLOPE. But the slope multiplies the seat's
#' CLASS-level prior vote (`mat[, "IND"]`), which is 0% for Orange in 2019
#' since Donato was registered OTH_RIGHT then. A correct slope applied to a
#' near-zero base still projects him near zero: Dalton (Murray) and Butler
#' (Barwon) show the identical fault, all sitting members whose entire
#' personal incumbency vanished because their registered party changed
#' between elections. `candidate_returns()`'s own docs anticipated only half
#' of this -- "which label they stand under ... belongs to the party swing" --
#' and the party swing never picked it up, because it has no path from a
#' person's identity to their own history under a different label.
#'
#' This closes that gap directly: for each seat/class where the LEADING
#' candidate personally returns (same matching as
#' [leading_candidate_returns()]) AND their prior registration was NOT a
#' major party, their own `pcv` from whichever (non-major) party they
#' contested under at the prior election -- to be used as `x` in
#' [dev_slope()] in place of the class's seat-level prior vote. The
#' major-party exclusion is deliberate, not an oversight -- see the inline
#' comment above `MAJ` for the Ward/McBride case that motivates it.
#'
#' @inheritParams candidate_returns
#' @return A `data.table` of `seat`, `party`, `own_prev_pcv` (`NA_real_` where
#'   the leading candidate does not personally return).
#' @export
personal_prior_vote <- function(election_from, election_to, corpus = NULL) {
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) {
      stop("personal_prior_vote() needs output/candidacies.csv; run ",
           "scripts/build_candidacies.R", call. = FALSE)
    }
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  need <- c("election", "seat", "party", "pcv")
  miss <- setdiff(need, names(C))
  if (length(miss)) stop("corpus lacks: ", paste(miss, collapse = ", "), call. = FALSE)

  NOWT  <- C[C$election == election_to]
  PREVT <- C[C$election == election_from]
  if (!nrow(NOWT))  stop("no rows for election ", election_to, call. = FALSE)
  if (!nrow(PREVT)) stop("no rows for election ", election_from, call. = FALSE)

  kf <- function(d) {
    sur <- surname_of(if ("surname" %in% names(d)) d$surname else NA_character_,
                      if ("name" %in% names(d)) d$name else NA_character_)
    giv <- given_of(if ("given" %in% names(d)) d$given else NA_character_,
                    if ("name" %in% names(d)) d$name else NA_character_)
    match_key(sur, giv, "initial")
  }
  NOWT  <- data.table::copy(NOWT)[,  .k := kf(.SD), .SDcols = names(NOWT)]
  PREVT <- data.table::copy(PREVT)[, .k := kf(.SD), .SDcols = names(PREVT)]
  NOWT[,  .s := normalise_seat(seat)]
  PREVT[, .s := normalise_seat(seat)]

  # The LEADING row per (seat, party) at the TARGET election: the one whose
  # personal history actually drives this class's swing.
  data.table::setorder(NOWT, seat, party, -pcv)
  lead <- NOWT[nzchar(.k), .SD[1], by = .(seat, party)]

  # EXCLUDE A PRIOR MAJOR-PARTY REGISTRATION. Nick McBride won MacKillop as
  # LNP with 62.3% in 2022, then re-contested as IND in 2026 and got 14.8% --
  # using his LNP-era vote as the base badly overestimated him, because most
  # of it was the party's machine, not personal support. Gareth Ward (Kiama)
  # is the counter-case: LNP 53.6% -> IND 38.8%, still won, and the override
  # would have been correct there. With only these two examples of a
  # major-party defector, there is no basis to fit how much to discount --
  # so this stays conservative and excludes ALP/LNP/NAT prior registrations
  # entirely, falling back to the class-level base exactly as before this
  # function existed. Switching FROM an already-minor label (Shooters,
  # Fishers and Farmers, One Nation, Green, other independent) is a much
  # smaller behavioural jump for voters and is not excluded.
  MAJ <- c("ALP", "LNP", "NAT")
  # BOTH SPELLINGS of a renamed seat, unioned onto PREVT before grouping --
  # not an unconditional rename. An unconditional rename reproduces the exact
  # bug governed_population() had BEFORE its own 2026-09-04 fix: Wilkie's
  # Denison -> Clark rename is applied even to a pair entirely BEFORE it took
  # effect (e.g. fed2010 -> fed2013, both still "Denison"), which then fails
  # to match `lead`'s own still-"denison" spelling and silently loses his
  # continuity. Every eligible PREVT row is duplicated under its renamed key
  # too, and `lead` matches whichever spelling its own era actually uses.
  rn <- seat_rename_map()
  PT <- PREVT[nzchar(PREVT$.k) & !PREVT$party %in% MAJ]
  PT[, .s_renamed := .s]
  PT[.s %in% names(rn), .s_renamed := rn[.s]]
  PTx <- rbind(PT[, .(.s, .k, pcv)], PT[.s != .s_renamed, .(.s = .s_renamed, .k, pcv)])
  # if (.N) guards max(): when the ONLY prior row for a (.s, .k) group is a
  # major party, filtering it out can leave that group with zero rows, and
  # max() over nothing warns "no non-missing arguments" and returns -Inf.
  prev_best <- PTx[, .(own_prev_pcv = if (.N) max(pcv, na.rm = TRUE) else NA_real_),
                   by = .(.s, .k)]
  out <- merge(lead[, list(seat, .s, party, .k)], prev_best, by = c(".s", ".k"), all.x = TRUE)
  out[, list(seat, party, own_prev_pcv)]
}
