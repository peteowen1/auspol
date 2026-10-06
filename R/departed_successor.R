#' Per-seat departed-independent rates for one target election
#'
#' Reads `output/departed-successor-rates.csv` (written by
#' `scripts/fit_departed_successor_rates.R`) and returns the rate each
#' successor cell of `target` takes when the departed-leader decay fires in
#' [screened_slopes()]. The rates are fitted TIME-FORWARD: the row for target T
#' uses only cells whose polling day is strictly before T's, never a
#' leave-one-out fit (`docs/plans/prereg-departed-successor-flag-2026-10-07.md`).
#'
#' Off unless `AUSPOL_DEPARTED_SUCCESSOR` is `"1"`, and then `NULL` is never
#' returned silently: a missing file or a target with no rows is an error, so
#' an arm that did not apply cannot look like an arm with no effect.
#'
#' @param target Election label, e.g. `"vic2022"`.
#' @param path The rates file.
#' @return Named numeric vector (names = seats), or `NULL` when the switch is off.
#' @export
departed_successor_rates <- function(target,
                                     path = "output/departed-successor-rates.csv") {
  if (!Sys.getenv("AUSPOL_DEPARTED_SUCCESSOR", "0") %in% c("1", "TRUE", "true")) return(NULL)
  if (!file.exists(path))
    stop("AUSPOL_DEPARTED_SUCCESSOR=1 needs ", path,
         " -- run scripts/fit_departed_successor_rates.R", call. = FALSE)
  r <- utils::read.csv(path, stringsAsFactors = FALSE)
  need <- c("target", "seat", "rate")
  if (!all(need %in% names(r)))
    stop(path, " lacks column(s): ", paste(setdiff(need, names(r)), collapse = ", "), call. = FALSE)
  hit <- r[r$target == target, , drop = FALSE]
  if (!nrow(hit))
    stop(path, " has no rows for target ", target, call. = FALSE)
  # A target fitted but with no successor cells carries one "(none)" row, so
  # "no cells here" is distinguishable from "never fitted".
  hit <- hit[hit$seat != "(none)", , drop = FALSE]
  if (anyDuplicated(hit$seat) || anyNA(hit$rate) || any(hit$rate < 0))
    stop(path, ": duplicate seats or invalid rates for ", target, call. = FALSE)
  stats::setNames(hit$rate, hit$seat)
}
