# AUSPOL_IND_GAP_RESTAND: carry an independent class's old gap only when one of
# its earlier candidates re-stands. docs/plans/prereg-ind-gap-restand-2026-10-25.md,
# walk in docs/reviews/overcalled-independents-walk-2026-10-03.md.
#
# The base is level_now + slope x (seat prior - level_prev) (dev_slope()). The
# seat prior for IND is the whole class's vote in the seat last time, which
# belongs to the people who earned it. Pascoe Vale vic2022 carried 32.9 points
# of 2018 independents (Yildiz 23.5, Kavanagh 7.7, Timpano 1.7), none of whom
# stood again, onto a new independent who polled 4.2 and was called 18.4.
# With the switch on, such a cell takes slope 0: it starts from the statewide
# IND level, like any other independent with no record in the seat.

#' The value of `AUSPOL_IND_GAP_RESTAND`, validated
#'
#' @return `"0"` (off, the published value) or `"1"`. Anything else is an error,
#'   so a typo cannot silently run the published model.
#' @keywords internal
#' @noRd
ind_gap_restand_mode <- function() {
  v <- Sys.getenv("AUSPOL_IND_GAP_RESTAND", "0")
  if (!v %in% c("0", "1"))
    stop("AUSPOL_IND_GAP_RESTAND must be \"0\" or \"1\", not \"", v, "\"", call. = FALSE)
  v
}

#' Seats where an independent class gap has nobody to carry it
#'
#' TRUE for a seat where the IND class had candidates at the previous election
#' and none of them stands for the class again (and the current leader has no
#' record in the seat under any label): `candidate_returns()`'s
#' `class_gap_restand` is FALSE. Every other class, and every seat absent from
#' `returns`, is FALSE.
#'
#' @param cls Party class being projected. Only `"IND"` can be TRUE.
#' @param seats Seat names, in the order of the shares matrix.
#' @param returns [candidate_returns()] output. Must carry `class_gap_restand`;
#'   a table without it is an error, so an arm that did not apply cannot look
#'   like an arm with no effect.
#' @return Logical vector the length of `seats`.
#' @keywords internal
#' @noRd
ind_gap_drop <- function(cls, seats, returns) {
  if (!identical(cls, "IND") || is.null(returns)) return(rep(FALSE, length(seats)))
  R <- data.table::as.data.table(returns)
  if (!"class_gap_restand" %in% names(R))
    stop("AUSPOL_IND_GAP_RESTAND=1 needs candidate_returns() output carrying ",
         "`class_gap_restand`; this returns table predates it", call. = FALSE)
  cls_now <- cls
  h <- R[R$party == cls_now]
  if (anyDuplicated(h$seat))
    stop("ind_gap_drop(): duplicate IND seat rows in returns", call. = FALSE)
  i <- match(seats, h$seat)
  rs <- h$class_gap_restand[i]
  !is.na(i) & (rs %in% FALSE)
}

# One line per IND slope call, so a run says what the switch applied.
.igr_report <- function(cls, seats, drop, path) {
  if (!identical(cls, "IND")) return(invisible(NULL))
  cat(sprintf("IGR1 IND class gap dropped (%s path; no earlier IND candidate re-stands): %d seat(s)%s\n",
              path, sum(drop), if (any(drop)) paste0(": ", paste(seats[drop], collapse = ", ")) else ""))
  invisible(NULL)
}
