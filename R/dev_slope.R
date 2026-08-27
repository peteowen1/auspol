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
#' @return Numeric vector the length of `seats`.
#' @export
conditional_slopes <- function(cls, seats, returns,
                               same = c(IND = 0.907, OTH_RIGHT = 0.891,
                                        GRN = 0.994, ONP = 0.610),
                               new  = c(IND = 0.326, OTH_RIGHT = 0.325,
                                        GRN = 0.880, ONP = 0.545),
                               default = 1) {
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
  is_same <- !is.na(idx) & hit$same[idx]
  is_same[is.na(is_same)] <- FALSE
  ifelse(is_same, as.numeric(same[[cls]]), as.numeric(new[[cls]]))
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
#' @param permit Logical vector the length of `seats`, from
#'   [salience_screen()]: does the screen allow this seat's candidate of `cls`
#'   to emerge?
#' @return Numeric vector the length of `seats`.
#' @export
screened_slopes <- function(cls, seats, returns, permit,
                            same = c(IND = 0.907, OTH_RIGHT = 0.891,
                                     GRN = 0.994, ONP = 0.610),
                            new  = c(IND = 0.326, OTH_RIGHT = 0.325,
                                     GRN = 0.880, ONP = 0.545),
                            default = 1) {
  if (length(permit) != length(seats)) {
    stop("permit must be the same length as seats: ", length(permit),
         " vs ", length(seats), call. = FALSE)
  }
  base <- conditional_slopes(cls, seats, returns, same, new, default)
  if (is.null(returns) || !cls %in% names(same) || !cls %in% names(new)) {
    return(base)   # class never fitted: conditional_slopes already left it at default
  }
  R <- data.table::as.data.table(returns)
  hit <- R[R$party == cls]
  idx <- match(seats, hit$seat)
  is_same <- !is.na(idx) & hit$same[idx]; is_same[is.na(is_same)] <- FALSE
  # new AND screen-permitted -> uniform swing, overriding the harsh new-slope.
  ifelse(!is_same & permit, 1.0, base)
}
