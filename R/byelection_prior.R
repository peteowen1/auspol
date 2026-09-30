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
# they will stand, and is skipped, saying so -- unless AUSPOL_BYELECTION_FILL
# is on, which fills the absent major back in (18 of 54 by-elections skip a
# major, four of them live Victorian seats).

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
#' @param fill When a major skipped the by-election, use it anyway: the
#'   absent major gets its row's share moved by the statewide swing to the
#'   by-election date, taken proportionally from every non-major class
#'   (`AUSPOL_BYELECTION_FILL=1`; plans/prereg-byelection-fill-2026-09-30.md).
#' @param swing Optional named override of that swing (party -> points).
#' @return `mat` with attribute `byelection` = list(applied, skipped, filled, cases).
#' @export
byelection_prior <- function(mat, election_from, election_to, table = NULL, weight = 1,
                             fill = identical(Sys.getenv("AUSPOL_BYELECTION_FILL", "0"), "1"), swing = NULL) {
  s <- byelections_between(election_from, election_to, table = table)
  applied <- character(0); skipped <- character(0)
  if (identical(attr(s, "reason"), "no-table")) {
    attr(mat, "byelection") <- list(applied = applied, skipped = "NO TABLE -- nothing could apply", cases = s)
    return(mat)
  }
  filled <- character(0)
  if (nrow(s)) for (st in unique(s$seat)) {
    rows <- s[s$seat == st]
    if (!isTRUE(rows$both_majors[1]) && !fill) { skipped <- c(skipped, sprintf("%s (a major did not stand)", st)); next }
    if (!st %in% rownames(mat)) { skipped <- c(skipped, sprintf("%s (no such seat in the prior)", st)); next }
    new <- stats::setNames(rep(0, ncol(mat)), colnames(mat))
    known <- rows$party %in% names(new)
    new[rows$party[known]] <- rows$share[known]
    if (sum(new) <= 0) { skipped <- c(skipped, sprintf("%s (no class matched)", st)); next }
    new <- 100 * new / sum(new)
    if (!isTRUE(rows$both_majors[1])) {
      # A major skipped it: give it back its general-election share moved by
      # the statewide swing to the by-election date, taken proportionally
      # from everyone who is not a major (they picked its vote up).
      absent <- intersect(setdiff(c("ALP", "LNP"), rows$party), colnames(mat))
      if (!length(absent)) { skipped <- c(skipped, sprintf("%s (absent major not a class of the prior)", st)); next }
      put <- stats::setNames(pmax(0, mat[st, absent] + .byelection_swing(election_from, election_to, rows$date[1], absent, mat, swing)), absent)
      minors <- setdiff(names(new), c("ALP", "LNP"))
      pool <- sum(new[minors])
      if (sum(put) >= pool) put <- put * pool / sum(put)   # cannot take more than the minors hold
      if (pool > 0) new[minors] <- new[minors] * (pool - sum(put)) / pool
      new[absent] <- put
      filled <- c(filled, sprintf("%s (%s)", st, paste(sprintf("%s %.1f", absent, put), collapse = ", ")))
    }
    mat[st, ] <- (1 - weight) * mat[st, ] + weight * new
    applied <- c(applied, st)
  }
  if (length(filled)) cat(sprintf("BYF1  %s: by-election absent major filled in: %s\n", election_to, paste(filled, collapse = "; ")))
  attr(mat, "byelection") <- list(applied = applied, skipped = skipped, filled = filled, cases = s)
  mat
}

#' Statewide swing to a party from the last general election to a date
#'
#' Mean of the region's polls in the 90 days to `date` minus the party's
#' statewide share at `election_from` (the anchor's prior results; the
#' unweighted seat mean of `mat` when that is missing). Zero, said out loud,
#' when there are no polls to read.
#' @param swing Optional named numeric override (party -> points), for tests.
#' @return Named numeric, points, one per party.
#' @keywords internal
.byelection_swing <- function(election_from, election_to, date, parties, mat, swing = NULL) {
  if (!is.null(swing)) return(stats::setNames(unname(swing[parties]), parties))
  reg <- sub("[0-9]{4}$", "", election_to)
  pol <- tryCatch(suppressMessages(load_polls(reg)), error = function(e) NULL)
  out <- stats::setNames(rep(0, length(parties)), parties)
  if (is.null(pol)) { cat(sprintf("BYF1! %s: no polls readable -- absent major filled at ZERO swing\n", election_to)); return(out) }
  d0 <- as.Date(date)
  win <- pol[which(pol$date <= d0 & pol$date > d0 - 90), ]
  pr <- tryCatch(load_prior_results(), error = function(e) NULL)
  yr_to <- as.integer(sub("^[a-z]+", "", election_to))
  for (p in parties) {
    now <- if (p %in% names(win)) mean(win[[p]], na.rm = TRUE) else NA_real_
    then <- NA_real_
    if (!is.null(pr)) {
      k <- which(pr$year == yr_to & pr$region == reg & pr$party == p)
      if (length(k)) then <- pr$prev1[k[1]]
    }
    if (!is.finite(then)) then <- mean(mat[, p])
    if (is.finite(now)) out[p] <- now - then
    else cat(sprintf("BYF1! %s: no %s polls in the 90 days to %s -- zero swing\n", election_to, p, format(d0)))
  }
  out
}

#' The by-election winner as the seat's sitting member
#'
#' For the pair `election_from -> election_to`, one row per by-election in
#' the window whose winner is known (`byelection-winners.csv`): the winning
#' candidate's name, party class and by-election first-preference share,
#' shaped like a candidacy row with `elected = TRUE`. [candidate_returns()]
#' uses it (under `AUSPOL_BYELECTION_MP=1`) to replace the previous general
#' election's `elected` flags for that seat, so a member who resigned and
#' lost the seat at a by-election (Speirs, Black sa2026) stops reading as
#' the returning sitting member, and the by-election winner (Dighton) starts.
#'
#' @param election_from,election_to Election labels.
#' @param results,winners Injectable tables; read from disk when `NULL`.
#' @return data.table: seat, party, name, surname, given, pcv, elected; zero
#'   rows when nothing applies.
#' @export
byelection_winner_rows <- function(election_from, election_to, results = NULL, winners = NULL) {
  empty <- data.table::data.table(seat = character(0), party = character(0), name = character(0),
                                  surname = character(0), given = character(0), pcv = numeric(0), elected = logical(0))
  res <- if (is.null(results)) byelection_table() else data.table::as.data.table(results)
  wf <- file.path("external", "reference", "byelections", "byelection-winners.csv")
  win <- if (!is.null(winners)) data.table::as.data.table(winners) else if (file.exists(wf)) data.table::fread(wf, showProgress = FALSE) else {
    cat(sprintf("BYW0! by-election winners table missing at %s -- AUSPOL_BYELECTION_MP has no input\n", wf)); NULL }
  if (is.null(res) || is.null(win)) return(empty)
  if (!nrow(res) || !nrow(win)) { cat("BYW0! by-election tables are empty -- nothing to apply\n"); return(empty) }
  res <- data.table::copy(res); win <- data.table::copy(win)
  if (!"party" %in% names(res)) res[, party := classify_party(party_raw)]
  if (!inherits(res$date, "Date")) res[, date := as.Date(date)]
  if (!inherits(win$date, "Date")) win[, date := as.Date(date)]
  win[, party := classify_party(winner_party_raw)]
  dates <- election_dates(); d0 <- dates[[election_from]]; d1 <- dates[[election_to]]
  reg <- sub("[0-9]{4}$", "", election_to)
  w <- win[win$region == reg & win$date > d0 & win$date < d1]
  if (!nrow(w)) return(empty)
  w <- w[order(-date), .SD[1L], by = seat]   # the last by-election in a seat decides
  unmatched <- character(0)
  out <- data.table::rbindlist(lapply(seq_len(nrow(w)), function(i) {
    r <- res[res$region == reg & res$seat == w$seat[i] & res$date == w$date[i] & res$party == w$party[i]]
    if (!nrow(r)) { unmatched <<- c(unmatched, sprintf("%s %s (%s)", w$seat[i], w$date[i], w$party[i])); return(NULL) }
    r <- r[which.max(r$pct)]
    nm <- r$candidate
    sp <- strsplit(trimws(nm), " ")[[1]]
    if (length(sp) < 2L) { unmatched <<- c(unmatched, sprintf("%s: one-token name '%s'", w$seat[i], nm)); return(NULL) }
    data.table::data.table(seat = r$seat, party = r$party, name = nm,
                           surname = toupper(sp[length(sp)]), given = paste(sp[-length(sp)], collapse = " "),
                           pcv = r$pct, elected = TRUE)
  }), fill = TRUE)
  # A winner whose result row cannot be matched is a data defect, said out loud:
  # otherwise "no by-election here" and "by-election found, winner unmatched"
  # look identical to the caller.
  if (length(unmatched)) cat(sprintf("BYW1! %d by-election winner(s) not matched to a results row, skipped: %s\n", length(unmatched), paste(unmatched, collapse = "; ")))
  if (is.null(out) || !nrow(out)) empty else out
}
