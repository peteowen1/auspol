#' First-preference shares for the page's "now" table, summing to 100
#'
#' Each party's trend is fitted on its own, so the latest means add to 97.5
#' (Victoria) or 98.2 (NSW), not 100, and the blog shows them side by side.
#' This rescales the endpoint means to 100 and rounds them to 0.1 by largest
#' remainder, so the displayed values add to exactly 100.0. Each 95% range keeps
#' its half-widths scaled by the same factor, centred on the rounded mean, so
#' lo <= m <= hi always holds. Display only: the trend series and the seat
#' forecast are untouched.
#'
#' @param tr Long trend table with `party`, `date`, `mean`, `lo95`, `hi95`.
#' @param parties First-preference parties to export, in output order.
#' @return List of `list(party, m, lo, hi)`, one per party.
#' @noRd
fp_now_normalised <- function(tr, parties) {
  end <- lapply(parties, function(p) {
    keep <- which(tr$party == p)
    if (!length(keep)) stop("fp_now: no trend rows for party ", p, call. = FALSE)
    tr[keep[which.max(tr$date[keep])], ]
  })
  m <- vapply(end, function(d) d$mean, 0)
  lo <- vapply(end, function(d) d$lo95, 0)
  hi <- vapply(end, function(d) d$hi95, 0)
  if (!all(is.finite(c(m, lo, hi))) || any(m < 0) || sum(m) <= 0)
    stop("fp_now: endpoint means and bands must be finite, means non-negative with a positive sum",
         call. = FALSE)
  k <- 100 / sum(m)
  tenths <- m * k * 10
  fl <- floor(tenths)
  short <- 1000L - as.integer(sum(fl))
  if (short > 0L) { up <- order(tenths - fl, decreasing = TRUE)[seq_len(short)]; fl[up] <- fl[up] + 1 }
  m2 <- fl / 10
  lo2 <- pmax(0, m2 - (m - lo) * k)
  hi2 <- pmin(100, m2 + (hi - m) * k)
  lapply(seq_along(parties), function(i)
    list(party = parties[i], m = round(m2[i], 1), lo = round(lo2[i], 1), hi = round(hi2[i], 1)))
}
