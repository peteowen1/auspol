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
#'   shrinks each seat toward the statewide level.
#' @return Numeric vector of projected shares, floored at zero.
#' @export
dev_slope <- function(x, level_prev, level_now, slope = 1) {
  if (length(slope) != 1L || !is.finite(slope)) stop("slope must be one finite number")
  if (!is.finite(level_prev) || !is.finite(level_now))
    stop("level_prev and level_now must both be finite")
  pmax(0, level_now + slope * (x - level_prev))
}

#' Per-class deviation slopes, defaulting to uniform swing
#'
#' Reads the `AUSPOL_DEV_SLOPE` environment variable, formatted as
#' `"IND=0.618,ONP=0.551"`. Classes not named keep `default`. Unknown class
#' names are an ERROR rather than a silent no-op: a typo that quietly leaves
#' every slope at 1 produces a run that looks like "this parameter does not
#' matter", which is the failure mode this repo has already recorded once.
#'
#' @param parties Character vector of class names in play.
#' @param default Slope for any class not named in the variable.
#' @return Named numeric vector over `parties`.
#' @export
dev_slopes_for <- function(parties, default = 1) {
  s <- stats::setNames(rep(as.numeric(default), length(parties)), parties)
  raw <- Sys.getenv("AUSPOL_DEV_SLOPE", "")
  if (!nzchar(raw)) return(s)
  for (e in strsplit(strsplit(raw, ",")[[1]], "=")) {
    if (length(e) != 2L) stop("AUSPOL_DEV_SLOPE entry must be CLASS=value: ", paste(e, collapse = "="))
    cls <- trimws(e[1]); val <- suppressWarnings(as.numeric(e[2]))
    if (!is.finite(val)) stop("AUSPOL_DEV_SLOPE value for ", cls, " is not a number")
    if (!cls %in% parties)
      stop("AUSPOL_DEV_SLOPE names class '", cls, "', which is not present. ",
           "Classes here: ", paste(parties, collapse = ", "),
           ". Silently ignoring it would read as 'this parameter has no effect'.")
    s[[cls]] <- val
  }
  s
}
