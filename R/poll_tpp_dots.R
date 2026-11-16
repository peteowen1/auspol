#' Each poll's own published Labor two-party figure, for the page's chart dots
#'
#' The page's two-party line (`TPP_ALP`) is implied from the primary trends and
#' past preference flows, not fitted to what pollsters publish (review
#' 2026-11-15, Issue 5). This returns the published figures so the page can plot
#' them beside the line. Polls without one are dropped; nothing is imputed.
#'
#' @param cp Cycle polls from `cycle_polls()`: `date`, `firm`, `tpp_published`.
#' @return data.table `date` (character), `firm`, `v` (Labor two-party, 0.1
#'   rounded), one row per poll that published a figure, oldest first.
#' @noRd
poll_tpp_dots <- function(cp) {
  if (!"tpp_published" %in% names(cp)) stop("poll_tpp_dots: no tpp_published column in the polls")
  keep <- which(is.finite(cp$tpp_published))
  out <- data.table::data.table(date = as.character(cp$date[keep]), firm = cp$firm[keep],
                                v = round(cp$tpp_published[keep], 1))
  out[order(out$date)]
}
