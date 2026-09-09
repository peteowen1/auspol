#' Root-mean-square error of a seat-by-class vote-share point estimate
#'
#' The second metric in this repo's objective, after seat log loss: how far
#' the projected first-preference share in each seat and class sits from the
#' share actually polled. Computed on the POINT estimate the simulator is
#' handed (`shares`), not on any draw, so it measures the swing model and the
#' candidate-level machinery without the Monte Carlo layer.
#'
#' Seats are matched by name; a seat present in `shares` but absent from
#' `actual_votes` (a redistribution, a rename the harness did not map) is
#' excluded and counted in `n_dropped` rather than scored against zero, which
#' would inflate the error with a data-plumbing fault. A class present in one
#' and not the other is scored against zero, which is the true share.
#'
#' @param shares Numeric matrix, seats in rows (named) and party classes in
#'   columns (named), percentages summing to ~100 per row.
#' @param actual_votes A data frame with `seat`, `party` and `votes` for the
#'   election being predicted; aggregated here, so candidate-level rows are
#'   fine.
#' @return A list: `rmse` over every seat-class cell, `mae`, `by_class` (a
#'   named vector of per-class RMSE), `n_seats` scored, `n_dropped`, and
#'   `detail` -- a long `data.table` (`seat`, `party`, `pred_share`,
#'   `actual_share`) with one row per scored seat-class cell. `detail` exists
#'   so a caller can persist the point estimate alongside the win probability
#'   it already writes, rather than recomputing this function's `pred`/`act`
#'   matrices a second time to get at them -- see
#'   `docs/reviews/rmse-persistence-2026-09-09.md`.
#' @export
seat_share_rmse <- function(shares, actual_votes) {
  stopifnot(is.matrix(shares), !is.null(rownames(shares)), !is.null(colnames(shares)))
  A <- data.table::as.data.table(actual_votes)
  need <- c("seat", "party", "votes")
  miss <- setdiff(need, names(A))
  if (length(miss)) stop("actual_votes lacks: ", paste(miss, collapse = ", "), call. = FALSE)
  A <- A[, list(v = sum(votes, na.rm = TRUE)), by = list(seat, party)]
  A[, pcv := 100 * v / sum(v), by = seat]
  seats <- intersect(rownames(shares), unique(A$seat))
  n_dropped <- nrow(shares) - length(seats)
  if (!length(seats)) stop("no seat in `shares` matches a seat in `actual_votes`", call. = FALSE)
  if (n_dropped > 0.2 * nrow(shares)) {
    warning(sprintf("seat_share_rmse: only %d of %d seats matched by name; the RMSE describes a fraction of the election",
                    length(seats), nrow(shares)), call. = FALSE)
  }
  cls <- union(colnames(shares), unique(A$party))
  pred <- matrix(0, length(seats), length(cls), dimnames = list(seats, cls))
  pred[, colnames(shares)] <- shares[seats, , drop = FALSE]
  act <- matrix(0, length(seats), length(cls), dimnames = list(seats, cls))
  A <- A[seat %in% seats]
  act[cbind(match(A$seat, seats), match(A$party, cls))] <- A$pcv
  d <- pred - act
  detail <- data.table::data.table(
    seat = rep(seats, times = length(cls)),
    party = rep(cls, each = length(seats)),
    pred_share = as.vector(pred),
    actual_share = as.vector(act))
  list(rmse = sqrt(mean(d^2)), mae = mean(abs(d)),
       by_class = sqrt(colMeans(d^2)), n_seats = length(seats), n_dropped = n_dropped,
       detail = detail)
}
