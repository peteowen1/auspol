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

#' Coefficient for the seat-swing adjustment
#'
#' **One term, since 2026-08-20.** This was four until re-validation on five
#' elections and 629 seats showed the other three were worth less than nothing:
#' `retirement`, `soph_cand` and `soph_party` together give a pooled
#' leave-one-election-out gain of **-0.0008** against uniform swing, and on the
#' two state elections where all four coefficients exist, `fed_swing` **alone**
#' beats all four on held-out MAE (3.3655 against 3.4249). The adopted model was
#' being beaten by one of its own predictors. See
#' `docs/reviews/seat-swing-revalidation-2026-08-20.md`.
#'
#' - `fed` **+0.745** (t = 8.56) -- a seat swinging federally swings the same way
#'   at state level. Refitted alone; it was 0.708 alongside the other three.
#'
#' The removed terms all had the sign Australian psephology expects and two were
#' significant. They were not wrong about direction -- they simply did not pay
#' for the variance they added, which only a five-election sample could show.
#'
#' **`fed_swing` itself is still validated on two elections only.** It is the
#' strongest term in the seat model and the least verified; removing its
#' companions does not change that.
#'
#' `seat_swing_adjustment()` still accepts a four-term vector, so the previous
#' behaviour is reproducible by passing the old coefficients explicitly.
#' @export
SEAT_SWING_COEF <- c(fed = 0.7452)

#' Predicted departure from the statewide swing, per seat
#'
#' @param seats A `load_seats()` table, carrying `incumbent`, `fed_swing`,
#'   `retirement`, `soph_cand` and `soph_party`.
#' @param coef Named coefficient vector; defaults to [SEAT_SWING_COEF].
#' @return Numeric vector, one per row, in points of two-party swing TOWARD
#'   LABOR. Seats with no transposed federal swing get the flags only.
#' @export
seat_swing_adjustment <- function(seats, coef = SEAT_SWING_COEF) {
  need <- c("incumbent", "fed_swing")
  need <- c(need, intersect(c("retirement", "soph_cand", "soph_party"), names(coef)))
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

  # `side` is retained because a caller may supply the old four-term coefficient
  # vector, and the flags only mean anything relative to whoever holds the seat.
  out <- coef[["fed"]] * fed
  for (k in c("retirement", "soph_cand", "soph_party")) {
    if (k %in% names(coef)) {
      out <- out + side * coef[[k]] * as.numeric(seats[[k]])
    }
  }
  unname(out)
}
