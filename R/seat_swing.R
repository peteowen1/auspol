# Predicting a seat's departure from the statewide swing
#
# The seat model used to treat every seat's deviation from the uniform swing as
# noise: one common spread, applied to all 88 seats. Four fields the anchor
# already computes -- and that `load_seats()` did not read until 2026-08-19 --
# predict a measurable part of it.
#
# Measured across Victoria 2022 and NSW 2023, 180 seats, leave-one-election-out:
# out-of-sample MAE falls from 3.948 to 3.425. The gain is positive in BOTH
# held-out elections (+0.213 and +0.819), which is what distinguishes a
# predictor from a coincidence when there are only two of them.
#
# Pre-registered in docs/plans/prereg-seat-swing-predictors.md, with the bar and
# all four refusal conditions fixed before anything was measured.

#' Coefficients for the seat-swing adjustment
#'
#' Fitted by `scripts/test_seat_swing_predictors.R` on all 180 seats of Victoria
#' 2022 and NSW 2023. The leave-one-election-out fits validate the model; these
#' use every seat, which is the right choice for a forecast and the wrong one
#' for scoring it.
#'
#' Signs are all as Australian psephology expects, which was a pre-registered
#' refusal condition rather than an observation made afterwards:
#'
#' - `fed` **+0.708** (t = 8.5) — a seat swinging federally swings the same way
#'   at state level. Much the strongest of the four.
#' - `retirement` **−1.396** (t = −2.1) — a departing member takes a personal
#'   vote with them.
#' - `soph_cand` **+2.559** (t = 3.0) — a first-term member defending for the
#'   first time gains on their debut margin.
#' - `soph_party` **+1.609** (t = 1.2) — same effect at party level, and the
#'   only one not statistically distinguishable from zero. Kept because the
#'   pre-registration fixed the model before fitting, and dropping a term for
#'   failing a significance test it was never required to pass is exactly the
#'   selection this repo's discipline exists to prevent.
#' @export
SEAT_SWING_COEF <- c(fed = 0.7077, retirement = -1.3955,
                     soph_cand = 2.5587, soph_party = 1.6090)

#' Predicted departure from the statewide swing, per seat
#'
#' @param seats A `load_seats()` table, carrying `incumbent`, `fed_swing`,
#'   `retirement`, `soph_cand` and `soph_party`.
#' @param coef Named coefficient vector; defaults to [SEAT_SWING_COEF].
#' @return Numeric vector, one per row, in points of two-party swing TOWARD
#'   LABOR. Seats with no transposed federal swing get the flags only.
#' @export
seat_swing_adjustment <- function(seats, coef = SEAT_SWING_COEF) {
  need <- c("incumbent", "fed_swing", "retirement", "soph_cand", "soph_party")
  miss <- setdiff(need, names(seats))
  if (length(miss)) {
    stop("seats is missing column(s): ", paste(miss, collapse = ", "),
         ". An older load_seats() did not read them.", call. = FALSE)
  }

  # Every flag is expressed FROM THE INCUMBENT'S SIDE, then converted to a swing
  # toward Labor. A retirement hurts whoever holds the seat, so its effect on
  # the Labor-facing swing flips sign depending on who that is. Fitting on the
  # raw flags instead would have made the coefficient an average of two opposite
  # effects and close to zero.
  alp_inc <- seats$incumbent == "ALP"
  side <- ifelse(alp_inc, 1, -1)

  fed <- seats$fed_swing
  # A seat with no transposed federal swing contributes nothing from that term
  # rather than dropping out of the forecast entirely.
  fed[!is.finite(fed)] <- 0
  # Centred: the statewide component is already in the projection, and this
  # function returns only the DEPARTURE from it. Leaving it uncentred would add
  # the mean federal swing to every seat and shift the whole forecast.
  fed <- fed - mean(fed)

  unname(coef[["fed"]] * fed +
         side * (coef[["retirement"]] * as.numeric(seats$retirement) +
                 coef[["soph_cand"]]  * as.numeric(seats$soph_cand) +
                 coef[["soph_party"]] * as.numeric(seats$soph_party)))
}
