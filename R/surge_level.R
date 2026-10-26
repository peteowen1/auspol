# The emergence surge as a LEVEL, not a gain (AUSPOL_SURGE_LEVEL, default "0" = off;
# docs/plans/prereg-surge-level-2026-10-25.md). `surge_mu` from surge_hazard_for() is the mean
# first-preference vote of past emergence WINNERS (R/salience_surge.R, `mean(winners$pcv)`), who
# started from about 1% (docs/reviews/mildura-benambra-trace-2026-10-25.md). So it is the vote a
# surging candidate ENDS on, and adding it to a recipient already near it counts the surge twice
# (Mildura 2026: One Nation at 33.9 plus a draw of N(34.3, 9.7)). Under "1" a fired surge draws a
# level L and lifts the recipient to max(v, L), taking the difference from the others pro rata.
# The random number is the same one the gain rule draws, so every other draw is unchanged.

#' Whether the simulator treats the surge draw as a level (AUSPOL_SURGE_LEVEL)
#'
#' The default of [simulate_seat_contests()]'s `surge_level`, so the published forecast and every
#' harness follow the switch through one read. Two surge sources supply a GAIN rather than a level,
#' and the level rule would misread them: `AUSPOL_IND_MIXTURE=1` (`m2 - typical`, R/ind_mixture.R)
#' and `AUSPOL_XGB_SURGE=1` (the emergence model's predicted RISE,
#' scripts/fit_xgb_emergence_v5.R). Either one set with `"1"` here is an error, not a silent
#' reinterpretation.
#' @return `TRUE` or `FALSE`; anything but `"0"` or `"1"` stops.
#' @export
surge_level_on <- function() {
  m <- Sys.getenv("AUSPOL_SURGE_LEVEL", "0")
  if (!nzchar(m)) m <- "0"
  if (!m %in% c("0", "1")) stop("AUSPOL_SURGE_LEVEL must be \"0\" or \"1\", got \"", m, "\"", call. = FALSE)
  if (m == "1") {
    gain_src <- c(AUSPOL_IND_MIXTURE = Sys.getenv("AUSPOL_IND_MIXTURE", "0"),
                  AUSPOL_XGB_SURGE = Sys.getenv("AUSPOL_XGB_SURGE", "0"))
    bad <- names(gain_src)[gain_src == "1"]
    if (length(bad))
      stop("AUSPOL_SURGE_LEVEL=1 reads surge_mu as a LEVEL, but ", paste(bad, collapse = " and "),
           " supplies it as a GAIN; set one or the other", call. = FALSE)
  }
  identical(m, "1")
}

#' The amount a level-rule surge adds to the recipient
#'
#' The reference arithmetic of `AUSPOL_SURGE_LEVEL=1`, shared by the R engine of
#' [simulate_seat_contests()] and mirrored line for line in `src/seat_sim_core.cpp`. `level` is in
#' percent of the draw's total, so the recipient's target is `level / 100 * sum(v)`; the gain is how
#' far below that the recipient sits, and zero when it is already at or above it. The caller then
#' moves exactly that much from the other cells pro rata, which keeps the total and cannot drive a
#' cell negative.
#' @param v Numeric vector, one draw's shares in a seat (non-negative).
#' @param j Index of the recipient in `v`.
#' @param level The drawn level, in percent.
#' @return A single non-negative number.
#' @export
surge_level_gain <- function(v, j, level) {
  if (!is.numeric(v) || anyNA(v) || any(v < 0)) stop("surge_level_gain: v must be non-negative numbers")
  if (length(j) != 1L || is.na(j) || j < 1L || j > length(v)) stop("surge_level_gain: j must index v")
  if (length(level) != 1L || !is.finite(level)) stop("surge_level_gain: level must be one finite number")
  target <- level / 100 * sum(v)
  if (target > v[j]) target - v[j] else 0
}
