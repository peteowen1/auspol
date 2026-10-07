#' Per-seat departed-independent rates for one target election
#'
#' Reads `output/departed-successor-rates.csv` (written by
#' `scripts/fit_departed_successor_rates.R`) and returns the rate each
#' successor cell of `target` takes when the departed-leader decay fires in
#' [screened_slopes()]. The rates are fitted TIME-FORWARD: the row for target T
#' uses only cells whose polling day is strictly before T's, never a
#' leave-one-out fit (`docs/plans/prereg-departed-successor-flag-2026-10-07.md`).
#'
#' Off unless `AUSPOL_DEPARTED_SUCCESSOR` is `"1"` (rates split by the
#' hand-coded successor flag) or `"sitting"` (split by whether the departed
#' leader was the sitting member,
#' `docs/plans/prereg-departed-sitting-split-2026-10-07.md`), and then `NULL` is never
#' returned silently: a missing file or a target with no rows is an error, so
#' an arm that did not apply cannot look like an arm with no effect.
#'
#' @param target Election label, e.g. `"vic2022"`.
#' @param path The rates file; `NULL` picks the file for the switch's value.
#' @return Named numeric vector (names = seats), or `NULL` when the switch is off.
#' @export
departed_successor_rates <- function(target, path = NULL) {
  mode <- departed_successor_mode()
  if (mode == "0") return(NULL)
  if (is.null(path)) path <- switch(mode,
    "1"       = "output/departed-successor-rates.csv",   # hand-coded successor flag
    "sitting" = "output/departed-sitting-rates.csv")     # sitting member vs not
  if (!file.exists(path))
    stop("AUSPOL_DEPARTED_SUCCESSOR=", mode, " needs ", path,
         " -- run scripts/fit_departed_successor_rates.R",
         if (mode == "sitting") " --split=sitting" else "", call. = FALSE)
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

#' The value of `AUSPOL_DEPARTED_SUCCESSOR`, validated
#'
#' @return `"0"` (off), `"1"` (successor flag) or `"sitting"`. Anything else is
#'   an error, so a typo cannot silently run the shipped model.
#' @export
departed_successor_mode <- function() {
  v <- Sys.getenv("AUSPOL_DEPARTED_SUCCESSOR", "1")   # the shipped value (scripts/published_flags.R)
  if (v %in% c("", "0", "FALSE", "false")) return("0")
  if (v %in% c("1", "TRUE", "true")) return("1")
  if (identical(v, "sitting")) return("sitting")
  stop("AUSPOL_DEPARTED_SUCCESSOR must be \"0\", \"1\" or \"sitting\", not \"", v, "\"", call. = FALSE)
}
