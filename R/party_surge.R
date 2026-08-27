#' How far a party's STATEWIDE vote moved between two elections
#'
#' A candidate with no prior vote in a seat is not necessarily an emerging
#' candidate. One Nation went from 2.63% to 22.50% across South Australia in
#' 2026, contesting 47 seats instead of 19, and 19 of its 47 candidates polled
#' above 25%. Its four winners had little or no prior vote in their seats, so a
#' candidate-level definition called them emergences — but nothing about them was
#' personal. The uniform party swing already carries most of it: Hammond's winner
#' is predicted exactly, and the others within 7 to 15 points.
#'
#' A **candidate** emergence is a person outrunning their party. A **party**
#' emergence is the party moving and taking its candidates with it. The seat
#' model handles the second through the statewide swing, and a name-search
#' signal has no reason to see it at all — asking one to explain the other is
#' what made South Australia look like a failure of the signal.
#'
#' @param region,year_from,year_to Election identifiers as used in
#'   `output/candidacies.csv`.
#' @param corpus Optional pre-read candidacy table.
#' @return A `data.table` of `party`, `prev`, `now`, `swing` in percentage
#'   points of the statewide first-preference vote.
#' @export
party_swing <- function(region, year_from, year_to, corpus = NULL) {
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) stop("needs output/candidacies.csv", call. = FALSE)
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  share <- function(y) {
    d <- C[C$region == region & C$year == y]
    if (!nrow(d)) stop("no rows for ", region, y, call. = FALSE)
    t <- d[, list(v = sum(votes)), by = party]
    t[, list(party, pct = 100 * v / sum(v))]
  }
  a <- share(year_from); b <- share(year_to)
  out <- merge(a[, list(party, prev = pct)], b[, list(party, now = pct)],
               by = "party", all = TRUE)
  out[is.na(prev), prev := 0][is.na(now), now := 0]
  out[, swing := now - prev][order(-swing)]
}

#' Is this candidate's lack of prior vote a PARTY story rather than a personal one?
#'
#' Flags classes whose statewide vote moved by more than `threshold` points. A
#' candidate of such a class with no prior seat vote is riding a party surge, not
#' emerging personally, and the salience screen makes no claim about them.
#'
#' The default of 5 points is above ordinary election-to-election movement — the
#' major parties move 1 to 4 points in a typical cycle — and well below South
#' Australian One Nation's 19.9.
#'
#' @inheritParams party_swing
#' @param threshold Statewide swing, in points, above which a class counts as
#'   surging.
#' @return Character vector of party classes.
#' @export
surging_parties <- function(region, year_from, year_to, threshold = 5,
                            corpus = NULL) {
  s <- party_swing(region, year_from, year_to, corpus)
  s[abs(swing) >= threshold, party]
}
