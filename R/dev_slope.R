#' Project a seat's class share, shrinking its deviation from the statewide mean
#'
#' Uniform swing moves every seat by the same number of points. That is the same
#' as asserting a seat's DEVIATION from the statewide mean carries forward
#' intact, which is a slope of exactly 1. Estimated across the 17 election pairs
#' in `output/candidacies.csv`, a slope of 1 is rejected for every party class:
#'
#' \tabular{lrr}{
#'   class \tab slope \tab t vs 1 \cr
#'   OTH \tab 0.215 \tab -29.9 \cr
#'   ONP \tab 0.551 \tab -16.1 \cr
#'   OTH_RIGHT \tab 0.580 \tab -20.9 \cr
#'   IND \tab 0.618 \tab -17.8 \cr
#'   LNP \tab 0.863 \tab -11.2 \cr
#'   ALP \tab 0.901 \tab -8.9 \cr
#'   GRN \tab 0.926 \tab -6.1
#' }
#'
#' The statewide level is an INPUT here, not something fitted. Only the seat's
#' deviation around it is shrunk, so a level that came from a poll trend stays
#' intact. A plain `share_now ~ share_prev` regression would absorb the
#' statewide movement into its intercept and discard the polls entirely.
#'
#' This lives in one place because five backtest harnesses and the published
#' model each build their shares differently -- additive swing in two forms, an
#' elasticity-pinned variant, and a multiplicative rescale -- and a parameter
#' added to some but not all of them produces numbers that look like findings.
#' That has happened twice on this repo, and cost four days the first time.
#'
#' @param x Numeric vector of the class's seat-level shares at the PREVIOUS
#'   election, in percentage points.
#' @param level_prev The class's statewide share at the previous election.
#' @param level_now The class's statewide share being projected for the target
#'   election -- an actual result when backtesting, a poll-trend draw when
#'   forecasting.
#' @param slope Deviation slope. 1 reproduces uniform swing exactly; below 1
#'   shrinks each seat toward the statewide level. Either one number for every
#'   seat, or one PER SEAT the same length as `x` — the latter is what a
#'   conditional slope needs, since whether the same candidate is standing again
#'   is a property of the seat, not of the class. Measured, that distinction is
#'   worth more than the class: IND carries 0.907 when the person returns and
#'   0.326 when they do not.
#' @return Numeric vector of projected shares, floored at zero.
#' @export
dev_slope <- function(x, level_prev, level_now, slope = 1) {
  if (!length(slope) %in% c(1L, length(x)) || !all(is.finite(slope))) {
    stop("slope must be one finite number, or one per seat matching x (",
         length(x), "); got ", length(slope), call. = FALSE)
  }
  if (!is.finite(level_prev) || !is.finite(level_now))
    stop("level_prev and level_now must both be finite")
  pmax(0, level_now + slope * (x - level_prev))
}

#' Per-class deviation slopes, defaulting to uniform swing
#'
#' Reads the `AUSPOL_DEV_SLOPE` environment variable, formatted as
#' `"IND=0.618,ONP=0.551"`. Classes not named keep `default`.
#'
#' A name that is not a real party class is an ERROR: a typo that quietly leaves
#' every slope at 1 produces a run that looks like "this parameter does not
#' matter", which is the failure mode this repo has already recorded once.
#'
#' A name that IS a real class but is absent from this particular election is
#' NOT an error -- One Nation did not contest Western Australia in 2001, and one
#' spec has to run across every harness. Those are reported in the returned
#' vector's "absent" attribute so the caller can print them. Distinguishing the
#' two cases is the whole point: the first is a mistake, the second is data.
#'
#' @param parties Character vector of class names in play for this election.
#' @param default Slope for any class not named in the variable.
#' @return Named numeric vector over `parties`, with an `absent` attribute
#'   naming any valid class that was specified but does not appear here.
#' @export
dev_slopes_for <- function(parties, default = 1) {
  known <- c("ALP", "LNP", "GRN", "ONP", "IND", "OTH", "OTH_RIGHT")
  s <- stats::setNames(rep(as.numeric(default), length(parties)), parties)
  raw <- Sys.getenv("AUSPOL_DEV_SLOPE", "")
  if (!nzchar(raw)) return(s)
  absent <- character(0)
  for (e in strsplit(strsplit(raw, ",")[[1]], "=")) {
    if (length(e) != 2L) stop("AUSPOL_DEV_SLOPE entry must be CLASS=value: ", paste(e, collapse = "="))
    cls <- trimws(e[1]); val <- suppressWarnings(as.numeric(e[2]))
    if (!is.finite(val)) stop("AUSPOL_DEV_SLOPE value for ", cls, " is not a number")
    if (!cls %in% known)
      stop("AUSPOL_DEV_SLOPE names '", cls, "', which is not a party class. ",
           "Known classes: ", paste(known, collapse = ", "),
           ". Silently ignoring it would read as 'this parameter has no effect'.")
    if (!cls %in% parties) { absent <- c(absent, cls); next }
    s[[cls]] <- val
  }
  attr(s, "absent") <- absent
  s
}

#' Per-seat conditional slopes, from whether the same candidate stands again
#'
#' Builds the slope vector arm C needs: for each seat in `seats`, the
#' same-candidate slope where that class's candidate is returning and the
#' new-candidate slope where they are not.
#'
#' Fitted across 17 election pairs. A single per-class slope averages two
#' populations that behave nothing alike, and is therefore wrong for every
#' individual seat:
#'
#' \tabular{lrr}{
#'   class \tab same \tab new \cr
#'   IND \tab 0.907 \tab 0.326 \cr
#'   OTH_RIGHT \tab 0.891 \tab 0.325 \cr
#'   GRN \tab 0.994 \tab 0.880 \cr
#'   ONP \tab 0.610 \tab 0.545
#' }
#'
#' Classes with no entry in either table keep `default`, so a class the fit
#' never saw is left on uniform swing rather than given someone else's number.
#'
#' @param cls The party class being projected.
#' @param seats Character vector of seat names, in the order the shares matrix
#'   uses. The returned vector matches it element for element.
#' @param returns A `data.table` from [candidate_returns()], or `NULL` to leave
#'   every seat on `default`.
#' @param same,new Named numeric vectors of slopes by class.
#' @param default Slope for a class absent from `same`/`new`.
#' @param same_mp Optional named numeric vector of slopes by class, applied
#'   where the returning candidate was the SITTING MEMBER. `NULL` (the
#'   default) keeps the two-tier `same`/`new` behaviour byte-identical.
#'
#'   `same` pools a returning member with a returning also-ran. Measured
#'   separately over 531 returning non-major candidacies across 10 election
#'   pairs, they are 0.954 (se 0.026) and 0.800 (se 0.046) -- about 2.9 SE
#'   apart. Pooling shrinks an entrenched independent toward a ~5% statewide
#'   IND average every cycle, which is where most of this model's fed2025 seat
#'   log-loss gap to AE Forecasts sits. Requires `returns` to carry a
#'   `same_mp` column, which [candidate_returns()] now supplies.
#' @return Numeric vector the length of `seats`.
#' @export
conditional_slopes <- function(cls, seats, returns,
                               same = c(IND = 0.907, OTH_RIGHT = 0.891,
                                        GRN = 0.994, ONP = 0.610),
                               new  = c(IND = 0.326, OTH_RIGHT = 0.325,
                                        GRN = 0.880, ONP = 0.545),
                               default = 1,
                               same_mp = NULL) {
  # SITTING-MEMBER TIER, opt-in via `same_mp` (AUSPOL_MP_SLOPE=1 in the
  # harnesses). `same` above pools a returning MEMBER with a returning
  # also-ran; measured separately over 531 returning non-major candidacies
  # across 10 election pairs they are 0.954 (se 0.026) and 0.800 (se 0.046),
  # about 2.9 SE apart. See candidate_returns()'s own comment for why the
  # pooled value systematically understates an entrenched independent.
  # NULL keeps the previous two-tier behaviour byte-identical.
  if (is.null(returns) || !cls %in% names(same) || !cls %in% names(new)) {
    return(rep(as.numeric(default), length(seats)))
  }
  R <- data.table::as.data.table(returns)
  hit <- R[R$party == cls]
  # Match BY NAME, never by position -- the shares matrix and the corpus are
  # ordered differently and a positional join would assign another seat's
  # candidate history. Seats absent from `returns` get FALSE, meaning nobody of
  # this class stood before, which is the correct reading.
  idx <- match(seats, hit$seat)
  # leader_same (does the class's CURRENT LEADING candidate personally
  # return), not `same` (any() across every candidate of the class) -- see
  # the note on this exact line in screened_slopes(). This is the actual
  # branch that mis-slopes New England fed2022 (Sharpham, new, wrongly gets
  # the returning-candidate slope because Ledger, a different, minor-polling
  # IND candidate, personally returned): screened_slopes()'s "!is_same &
  # permit -> 1.0" branch doesn't fire there (permit is FALSE, since Ledger's
  # own return makes the class read as having a governed history), so it
  # falls through to THIS function's base slope, which needs the same fix.
  # Falls back to `same` for a returns table that predates this column.
  same_col <- if ("leader_same" %in% names(hit)) hit$leader_same else hit$same
  is_same <- !is.na(idx) & same_col[idx]
  is_same[is.na(is_same)] <- FALSE
  out <- ifelse(is_same, as.numeric(same[[cls]]), as.numeric(new[[cls]]))
  if (!is.null(same_mp) && cls %in% names(same_mp) && "same_mp" %in% names(hit)) {
    is_mp <- !is.na(idx) & hit$same_mp[idx]
    is_mp[is.na(is_mp)] <- FALSE
    out[is_mp] <- as.numeric(same_mp[[cls]])
  }
  out
}

#' Per-seat slopes conditioned on candidate identity AND the salience screen
#'
#' Arm C (`conditional_slopes()`) split a class into two: a returning candidate
#' (slope 0.907) and a new one (slope ~0.33). Measured across five harnesses it
#' was refused -- the new-candidate slope is fitted on ~300 candidates who are
#' overwhelmingly no-hopers, so it crushed the rare emergent toward the mean and
#' hurt every emergence election it touched: vic2018 +0.191 log loss, fed2022
#' +0.143, sa2026 +0.114.
#'
#' Salience separates exactly that rare group. `salience_screen()` refuses a
#' governed candidate who never registers -- 709 of them across five elections,
#' zero winners -- and permits one who does, or one the screen makes no claim
#' about. This adds a THIRD slope for that permitted-but-new group: uniform swing
#' (1.0), because there is no fitted value for "new candidate who fires" and
#' shrinking them is precisely the failure being fixed.
#'
#' \tabular{lll}{
#'   group \tab condition \tab slope \cr
#'   returning \tab same person stood here before \tab 0.907 etc, per class \cr
#'   screened out \tab new, governed, screen refuses \tab ~0.33, per class \cr
#'   screen-permitted \tab new, and either ungoverned or fired \tab 1.0 (uniform)
#' }
#'
#' @inheritParams conditional_slopes
#' @param honour_departed Logical, default `FALSE`. When `TRUE`, a departed
#'   prior leader's (`returns$prior_leader_returns`) class base decays toward
#'   `departed_rate` INSTEAD of the generic `new` rate -- but only when the
#'   screen does NOT independently permit a successor. A screen-permitted
#'   successor still gets the uniform 1.0 treatment regardless of departure,
#'   because departure and a real new emergence are different mechanisms that
#'   can coincide in the same seat (Wentworth 2022: Phelps departs, Spender
#'   emerges -- both true at once). The original 2026-09-06 version did not
#'   make this distinction (`permit & plr` collapsed to FALSE the moment a
#'   leader departed, regardless of the successor's own signal), which is
#'   exactly why it traded New England 2013 for Wentworth 2022 and was
#'   refused on that basis. Revised 2026-09-18 after
#'   `docs/reviews/departed-leader-retention-2026-09-15.md` measured the real
#'   departure retention (0.38, n=305) and found it was never wired past that
#'   two-seat refusal. See `docs/plans/prereg-vote-belongs-to-the-person-
#'   2026-09-06.md` for the original design.
#'
#'   The departure check applies WHENEVER `prior_leader_returns` is FALSE and
#'   no successor is permitted, EVEN WHEN `is_same` (the same/new split
#'   `conditional_slopes()` itself already applies) is TRUE. Those two are
#'   NOT the same question: `is_same` is `any()` across every candidate of
#'   the class, so a departed leader's seat still reads `is_same = TRUE`
#'   whenever some OTHER, minor perennial candidate of the same class also
#'   happened to stand both times -- Morwell 2022 is exactly this shape
#'   (Tracie Lund ran IND in both 2018 and 2022 on 2-3%, while Russell
#'   Northe, who actually carried 19.6 of the class's 28.2-point base, did
#'   not recontest at all). Gating only on `!is_same` would apply the "same"
#'   slope (0.907, built for a genuine incumbent-level return) to a base
#'   that is overwhelmingly a departed leader's personal vote. Checking
#'   `prior_leader_returns` directly asks the right question regardless of
#'   what any other class member did.
#' @param departed_rate Named numeric vector by class, the retention rate for
#'   a departed leader's class base when the screen does NOT permit a
#'   successor. Default `c(IND = 0.38)` -- `departed-leader-retention-2026-
#'   09-15.md`, a sitting non-major who departs keeps a bit over a third of
#'   their vote (n=305) against ~101% for one who recontests (n=288), a 2.6x
#'   split on a well-powered sample, not the thin-data case CLAUDE.md's
#'   shrinkage caveat is about. Other classes fall back to the generic `new`
#'   rate (no departure-specific measurement exists for them yet -- MINOR
#'   retirements are only 2 corpus-wide, too thin to fit separately).
#' @param permit Logical vector the length of `seats`, from
#'   [salience_screen()]: does the screen allow this seat's candidate of `cls`
#'   to emerge?
#' @return Numeric vector the length of `seats`.
#' @param same_mp Passed through to [conditional_slopes()]; see there.
#' @export
screened_slopes <- function(cls, seats, returns, permit, honour_departed = FALSE,
                            same = c(IND = 0.907, OTH_RIGHT = 0.891,
                                     GRN = 0.994, ONP = 0.610),
                            new  = c(IND = 0.326, OTH_RIGHT = 0.325,
                                     GRN = 0.880, ONP = 0.545),
                            default = 1, same_mp = NULL,
                            departed_rate = c(IND = 0.38)) {
  if (length(permit) != length(seats)) {
    stop("permit must be the same length as seats: ", length(permit),
         " vs ", length(seats), call. = FALSE)
  }
  base <- conditional_slopes(cls, seats, returns, same, new, default, same_mp)
  if (is.null(returns) || !cls %in% names(same) || !cls %in% names(new)) {
    return(base)   # class never fitted: conditional_slopes already left it at default
  }
  R <- data.table::as.data.table(returns)
  hit <- R[R$party == cls]
  idx <- match(seats, hit$seat)
  # is_same keys on the CLASS LEADER personally returning (leader_same), not
  # `same` (any() across every candidate of the class) -- New England fed2022
  # is `same = TRUE` because Natasha Ledger personally stood as IND in both
  # 2019 and 2022, but she polled 2.8% in 2022; Matt Sharpham, a genuinely new
  # candidate, LED the class at 7.9% and is who this slope actually multiplies.
  # `same` routed him to the 0.907 "returning" slope instead of ~0.33 "new" --
  # a ~2x over-prediction. `leader_same` falls back to `same` itself when a
  # returns table predates this column (candidate_returns()'s own guard), so
  # this degrades to the old behaviour rather than erroring on stale input.
  same_col <- if ("leader_same" %in% names(hit)) hit$leader_same else hit$same
  is_same <- !is.na(idx) & same_col[idx]; is_same[is.na(is_same)] <- FALSE
  # A DEPARTED LEADER DECAYS TOWARD `departed_rate`, BUT ONLY WHEN THE SCREEN
  # DOES NOT ALSO SEE A REAL SUCCESSOR. The 1.0 (uniform) path exists for a
  # small base plus a salient newcomer (Goldstein 2022); a departed leader and
  # a genuine new emergence are DIFFERENT, INDEPENDENT things that can both be
  # true in the same seat -- Wentworth 2022 is exactly that: Phelps departs
  # (leader gone) AND Spender emerges (screen-permitted, real campaign). The
  # ORIGINAL 2026-09-06 version of this logic collapsed `permit & plr` to
  # FALSE the moment a leader departed, REGARDLESS of the successor's own
  # signal -- so it fixed New England 2013 (Windsor -> McIntyre, no permitted
  # successor, retention should be low) and broke Wentworth (Spender WAS
  # permitted, but got decayed anyway), a wash on the six-pair mean, and was
  # refused on exactly that basis. Revised 2026-09-18: a permitted successor
  # now wins regardless of departure; departure only matters when the screen
  # has NOTHING to say. `returns` from before 2026-09-06 lacks the
  # `prior_leader_returns` column; then every leader is taken as returning,
  # the pre-2026-09-06 behaviour exactly.
  plr <- if (honour_departed && "prior_leader_returns" %in% names(hit)) hit$prior_leader_returns[idx] else rep(TRUE, length(idx))
  plr[is.na(plr)] <- TRUE
  # DEPARTURE IS GATED ON `prior_leader_returns`, NOT `is_same`, AND CAN FIRE
  # EVEN WHEN is_same IS TRUE. `same` (feeding is_same, from
  # candidate_returns()) is `any(hit)` across EVERY candidate of this class,
  # not just the leader -- Morwell 2022 is `same = TRUE` because Tracie Lund
  # personally stood as IND in both 2018 (2.1%) and 2022 (2.8%), even though
  # Russell Northe -- the actual leader carrying 19.6% of the class's 28.2%
  # prior base -- did not recontest at all. Gating on `!is_same` alone would
  # have routed Morwell to the "same" slope (0.907) on its WHOLE base,
  # applying incumbent-level retention to a base that is overwhelmingly a
  # departed leader's personal vote plus a minor perennial candidate's own
  # unrelated 2-3%. `prior_leader_returns` asks the right question directly:
  # did THE LEADER specifically come back, under any label, anywhere in this
  # seat -- decoupled from whether some other class member also happened to.
  departed <- honour_departed & !plr & !permit
  dep_rate <- if (cls %in% names(departed_rate)) departed_rate[[cls]] else new[[cls]]
  ifelse(!is_same & permit, 1.0,
         ifelse(departed, dep_rate, base))
}
