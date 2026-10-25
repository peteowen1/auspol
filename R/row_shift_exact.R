#' Is AUSPOL_ROW_SHIFT_EXACT on?
#'
#' Validates the value: "0" (default, the whole-row rescale) or "1".
#' @return `TRUE` when the switch is "1".
#' @keywords internal
row_shift_exact_on <- function() {
  v <- Sys.getenv("AUSPOL_ROW_SHIFT_EXACT", "0")
  if (!v %in% c("0", "1")) stop("AUSPOL_ROW_SHIFT_EXACT must be \"0\" or \"1\", got \"", v, "\"", call. = FALSE)
  identical(v, "1")
}

#' Put each row back to 100 after a step moved some of its cells (audit F16)
#'
#' The salience blend and the seat-poll blend set a few (seat, class) cells to a
#' new value and then rescale the WHOLE row to 100, which hands part of every
#' move back: a cell on `s` moved by `d` in a row that was on 100 keeps
#' `d * (100 - s) / (100 + d)` of it, about 78% for a One Nation cell on 22.
#'
#' Default (`AUSPOL_ROW_SHIFT_EXACT = "0"`): exactly that rescale,
#' `100 * after / rowSums(after)`, so nothing moves.
#'
#' `"1"`: the cells this step moved (those where `after != before`) keep their
#' new values exactly, and the cells it did not move are scaled in proportion
#' to fill `100 - moved`, the rule `.shift_cell()` uses for the leader-seat
#' bonus. A row where that cannot be done (a negative cell, the moved cells
#' alone above 100, or nothing left to scale) falls back to the whole-row
#' rescale and is counted. Rows with no moved cell are rescaled exactly as
#' before. Prints one RSX1 line (cells, rows, the lift kept against what the
#' rescale would have kept, fallbacks). plans/prereg-row-shift-exact-2026-10-25.md.
#'
#' @param before Matrix of shares before the step (seats x classes).
#' @param after Same shape and dimnames: the shares after the step moved its
#'   cells, before any rescale.
#' @param label Election label for the printed line.
#' @param step Name of the calling step for the printed line.
#' @return `after`, each row summing to 100.
#' @keywords internal
row_shift_exact <- function(before, after, label = "", step = "") {
  if (!row_shift_exact_on()) return(100 * after / rowSums(after))
  stopifnot(is.matrix(before), is.matrix(after), identical(dim(before), dim(after)))
  mv <- after != before
  mv[is.na(mv)] <- FALSE
  out <- 100 * after / rowSums(after)       # every row starts as the rescale; moved rows are redone below
  rows <- which(rowSums(mv) > 0)
  fb <- 0L
  for (r in rows) {
    m <- mv[r, ]
    a <- after[r, ]
    M <- sum(a[m]); O <- sum(a[!m])
    if (all(is.finite(a)) && all(a >= 0) && M <= 100 && (O > 0 || abs(M - 100) < 1e-9)) {
      if (O > 0) a[!m] <- a[!m] * (100 - M) / O
      out[r, ] <- a
    } else fb <- fb + 1L
  }
  lift <- sum((after - before)[mv])
  kept <- sum((out - before)[mv])
  resc <- sum((100 * after / rowSums(after) - before)[mv])
  cat(sprintf("RSX1 %s %s: %d moved cell(s) in %d row(s) kept exact (AUSPOL_ROW_SHIFT_EXACT=1); lift %+.3f points, kept %+.3f (the whole-row rescale would keep %+.3f); %d row(s) fell back to the rescale\n",
              label, step, sum(mv), length(rows), lift, kept, resc, fb))
  out
}
