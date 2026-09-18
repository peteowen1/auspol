# A BY-ELECTION IS THE SEAT'S MOST RECENT RESULT, AND THE MODEL WAS IGNORING
# IT. Black sa2026: Speirs (Liberal, 50.1 in 2022) resigned, Dighton (ALP)
# won the 2024 by-election on 47.9 and held the seat in 2026 on 43.2; our
# baseline was sa2022, so ALP started at 34.7 and the seat scored 2.1 of log
# loss. Prahran, Werribee, Mulgrave and Narracan all had by-elections since
# vic2022 and the live forecast starts from vic2022 for every one of them.
#
# external/reference/byelections/byelection-results.csv holds candidate-
# level first preferences (Wikipedia). This replaces a seat's prior row with
# the by-election's class shares when BOTH majors stood -- a by-election one
# major skipped (Prahran 2025, Warrandyte 2023, North West Central 2022, no
# Labor candidate) is not a usable baseline for a general election where
# they will stand, and is skipped, saying so.

#' Read the by-election results table
#'
#' @param path CSV with columns region, seat, date, candidate, party_raw,
#'   votes, pct, source.
#' @return data.table with an added `party` class column, or NULL when absent.
#' @export
byelection_table <- function(path = file.path("external", "reference", "byelections", "byelection-results.csv")) {
  if (!file.exists(path)) { cat(sprintf("BF0b! by-election table missing at %s -- AUSPOL_BYELECTION_PRIOR does NOTHING this run\n", path)); return(NULL) }
  d <- data.table::fread(path, showProgress = FALSE)
  need <- c("region", "seat", "date", "party_raw", "pct")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop("by-election table lacks: ", paste(miss, collapse = ", "), call. = FALSE)
  d[, date := as.Date(date)]
  d[, party := classify_party(party_raw)]
  d
}

#' By-elections that fall between two general elections, as class shares
#'
#' @param election_from,election_to Election labels (dates from
#'   [election_dates()]); the region is the label's letters.
#' @param table From [byelection_table()]; read from disk when `NULL`.
#' @return data.table: seat, date, party, share (per cent, summing to 100
#'   within a seat), both_majors (logical, same for every row of a seat).
#'   Zero rows when none qualify.
#' @export
byelections_between <- function(election_from, election_to, table = NULL) {
  tab <- if (is.null(table)) byelection_table() else data.table::as.data.table(table)
  empty <- data.table::data.table(seat = character(0), date = as.Date(character(0)), party = character(0),
                                  share = numeric(0), both_majors = logical(0))
  if (is.null(tab) || !nrow(tab)) { attr(empty, "reason") <- "no-table"; return(empty) }
  tab <- data.table::copy(tab)
  if (!"party" %in% names(tab)) tab[, party := classify_party(party_raw)]
  if (!inherits(tab$date, "Date")) tab[, date := as.Date(date)]
  dates <- election_dates()
  d0 <- dates[[election_from]]; d1 <- dates[[election_to]]
  reg <- sub("[0-9]{4}$", "", election_to)
  b <- tab[tab$region == reg & tab$date > d0 & tab$date < d1]
  if (!nrow(b)) return(empty)
  # the LAST by-election in a seat wins if there were two
  last <- b[, list(date = max(date)), by = seat]
  b <- merge(b, last, by = c("seat", "date"))
  s <- b[, list(share = sum(pct)), by = list(seat, date, party)]
  s[, share := 100 * share / sum(share), by = seat]
  s[, both_majors := all(c("ALP", "LNP") %in% party), by = seat]
  s[]
}

#' Replace prior rows in the class-share matrix with by-election shares
#'
#' For every seat in [byelections_between()] with both majors standing and
#' a row in `mat`, the row becomes the by-election's class shares (classes
#' absent at the by-election get 0). Seats where a major skipped the
#' by-election, or whose name is not a row of `mat`, are skipped and named.
#'
#' @param mat Prior share matrix, seats by classes, in points.
#' @param election_from,election_to,table As in [byelections_between()].
#' @param weight Share of the by-election in the replaced row: 1 replaces it
#'   outright, 0.5 blends half and half with the general-election prior
#'   (`AUSPOL_BYELECTION_PRIOR=blend`).
#' @return `mat` with attribute `byelection` = list(applied, skipped, cases).
#' @export
byelection_prior <- function(mat, election_from, election_to, table = NULL, weight = 1) {
  s <- byelections_between(election_from, election_to, table = table)
  applied <- character(0); skipped <- character(0)
  if (identical(attr(s, "reason"), "no-table")) {
    attr(mat, "byelection") <- list(applied = applied, skipped = "NO TABLE -- nothing could apply", cases = s)
    return(mat)
  }
  if (nrow(s)) for (st in unique(s$seat)) {
    rows <- s[s$seat == st]
    if (!isTRUE(rows$both_majors[1])) { skipped <- c(skipped, sprintf("%s (a major did not stand)", st)); next }
    if (!st %in% rownames(mat)) { skipped <- c(skipped, sprintf("%s (no such seat in the prior)", st)); next }
    new <- stats::setNames(rep(0, ncol(mat)), colnames(mat))
    known <- rows$party %in% names(new)
    new[rows$party[known]] <- rows$share[known]
    if (sum(new) <= 0) { skipped <- c(skipped, sprintf("%s (no class matched)", st)); next }
    mat[st, ] <- (1 - weight) * mat[st, ] + weight * 100 * new / sum(new)
    applied <- c(applied, st)
  }
  attr(mat, "byelection") <- list(applied = applied, skipped = skipped, cases = s)
  mat
}
