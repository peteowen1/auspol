# No votes for candidates who are not standing (AUSPOL_ZERO_ABSENT, default "0" = off;
# docs/plans/prereg-zero-absent-2026-10-17.md). The simulator draws noise for every class and clips at 0, so a
# class predicted at 0% (not standing) gets |N(0, sd)| points in half its draws, which then flow on by the flow
# matrix. Under "1" such a cell is set back to 0 after its draw; the draw itself is kept, so the random stream
# and every other cell are unchanged.

#' Whether the simulator holds not-standing classes at zero (AUSPOL_ZERO_ABSENT)
#'
#' The default of [simulate_seat_contests()]'s `zero_absent`, so every caller follows the switch.
#' @return `TRUE` or `FALSE`; anything but `"0"` or `"1"` stops.
#' @export
zero_absent_on <- function() {
  m <- Sys.getenv("AUSPOL_ZERO_ABSENT", "0")
  if (!m %in% c("0", "1")) stop("AUSPOL_ZERO_ABSENT must be \"0\" or \"1\", got \"", m, "\"")
  identical(m, "1")
}
