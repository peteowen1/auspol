#' Are two (surname, given name) pairs plausibly the same person?
#'
#' The identity test behind `historic_elected` for state elections. It is the
#' person rule of [match_key()] with one addition for compound surnames:
#'
#' * surnames equal (letters only, case-folded), OR the LAST word of each
#'   surname equal while both first given names are spelled out and equal
#'   (`"HEANG TAK, Meng"` against `"TAK, Meng Heang"` is one person);
#' * and the first given names do not rule it out: same initial and no
#'   [given_conflict()]. A missing name or bare initial never conflicts, so a
#'   surname-only source (WA) still joins on the surname, as before.
#'
#' Jess KENNEDY against John KENNEDY ("je" vs "jo") and Reece CLARK against
#' Robert CLARK ("re" vs "ro") are conflicts. A surname-plus-first-initial key
#' joined both, and made two people who have never sat in the Assembly read as
#' sitting members of the 2026 Victorian forecast.
#'
#' @param sur1,giv1 Surname and first given name(s) of the first person.
#' @param sur2,giv2 Same for the second; all four recycle together.
#' @return Logical vector.
#' @export
same_person <- function(sur1, giv1, sur2, giv2) {
  lt <- function(x) tolower(trimws(ifelse(is.na(x), "", as.character(x))))
  last_word <- function(x) {
    w <- sub("^.*[^A-Za-z]", "", lt(x))
    gsub("[^a-z]", "", w)
  }
  clean <- function(x) gsub("[^a-z]", "", lt(x))
  first_given <- function(x) clean(sub("[[:space:]].*$", "", lt(x)))
  s1 <- clean(sur1); s2 <- clean(sur2)
  g1 <- first_given(giv1); g2 <- first_given(giv2)
  surname_ok <- nzchar(s1) & nzchar(s2) &
    (s1 == s2 |
       (last_word(sur1) == last_word(sur2) & nzchar(last_word(sur1)) &
          nchar(g1) >= 2L & g1 == g2))
  init_ok <- !nzchar(g1) | !nzchar(g2) | substr(g1, 1L, 1L) == substr(g2, 1L, 1L)
  surname_ok & init_ok & !given_conflict(g1, g2)
}

#' Which state candidates are sitting members seeking re-election?
#'
#' `TRUE` for a candidate who is the same person ([same_person()]) as the member
#' holding a seat when the election is called: the winner of the jurisdiction's
#' PREVIOUS general election, or the winner of a by-election or supplementary
#' election held after it and before this election (compared as full dates). Not
#' "won at any earlier election": a member who lost their seat two elections ago
#' is a former member, and flagging them told the model a challenger was an
#' incumbent (Ali Cupper, Mildura, vic2026).
#'
#' A by-election in a seat supersedes the previous general election's winner
#' there, so the member who resigned and was replaced (Tim Pallas, Werribee) is
#' not counted as sitting should they stand again, and Lidia Thorpe (Northcote
#' 2017 by-election) is the sitting member at vic2018. A by-election in a seat
#' with no previous-general-election winner row (a poll that did not complete,
#' or a renamed seat) prints an `RMF1!` line: the by-election winner is added,
#' and there is nobody to remove.
#'
#' @param cand Candidates: `region`, `year`, `seat`, `sur`, `giv`.
#' @param winners Elected candidates of general elections: `region`, `year`,
#'   `seat`, `sur`, `giv`.
#' @param byelections By-election and supplementary-election winners:
#'   `region`, `date` (Date), `seat`, `sur`, `giv`. `NULL` for none.
#' @param dates Named Date vector of general-election dates keyed by label
#'   (`"vic2022"`), as [election_dates()] returns. Required when `byelections`
#'   is given; a label missing from it is an error.
#' @return Logical vector, one per row of `cand`.
#' @export
returning_member_flags <- function(cand, winners, byelections = NULL, dates = NULL) {
  out <- rep(FALSE, nrow(cand))
  cand <- as.data.frame(cand)
  winners <- as.data.frame(winners)
  use_b <- !is.null(byelections) && nrow(byelections) > 0L
  if (use_b) {
    if (is.null(dates)) stop("returning_member_flags(): `dates` is required when `byelections` is given")
    byelections <- as.data.frame(byelections)
    byelections$date <- as.Date(byelections$date)
  }
  ns <- normalise_seat
  for (r in unique(cand$region)) {
    for (y in unique(cand$year[cand$region == r])) {
      yrs <- unique(cand$year[cand$region == r & cand$year < y])
      if (!length(yrs)) next
      py <- max(yrs)
      w <- winners[winners$region == r & winners$year == py, c("seat", "sur", "giv")]
      if (use_b) {
        l0 <- paste0(r, py); l1 <- paste0(r, y)
        if (!all(c(l0, l1) %in% names(dates)))
          stop("returning_member_flags(): no election date for ",
               paste(setdiff(c(l0, l1), names(dates)), collapse = ", "))
        b <- byelections[byelections$region == r & byelections$date > dates[[l0]] &
                           byelections$date < dates[[l1]], ]
        if (nrow(b)) {
          b <- b[order(b$date), ]
          b <- b[!duplicated(ns(b$seat), fromLast = TRUE), ]   # the last by-election in a seat decides
          orphan <- b$seat[!(ns(b$seat) %in% ns(w$seat))]
          if (length(orphan))
            cat(sprintf("RMF1! %s: by-election in %s has no %s winner row to supersede; winner added, nobody removed\n",
                        l1, paste(orphan, collapse = ", "), l0))
          w <- w[!(ns(w$seat) %in% ns(b$seat)), ]
          w <- rbind(w, b[, c("seat", "sur", "giv")])
        }
      }
      if (!nrow(w)) next
      idx <- which(cand$region == r & cand$year == y)
      out[idx] <- vapply(idx, function(i)
        any(same_person(cand$sur[i], cand$giv[i], w$sur, w$giv)), logical(1))
    }
  }
  out
}

#' By-elections in an election's window that have no winner name
#'
#' For every state election label in `labels` that has an earlier label in the
#' same region, the by-elections of `byelections` dated between the two general
#' elections whose (region, seat, date) is absent from `names_tbl`. The builder
#' stops on a non-empty result: a by-election without a winner name would leave
#' the member it replaced flagged as sitting.
#'
#' @param labels Election labels present in the corpus (`"vic2018"`).
#' @param byelections Table of ALL by-elections: `region`, `seat`, `date`.
#' @param names_tbl Table of winner names: `region`, `seat`, `date`.
#' @param dates Named Date vector, as [election_dates()].
#' @return data.table of the unnamed by-elections (`label`, `region`, `seat`,
#'   `date`); zero rows when every one is named.
#' @export
missing_byelection_names <- function(labels, byelections, names_tbl, dates) {
  b <- data.table::as.data.table(byelections)
  b[, date := as.Date(date)]
  nm <- data.table::as.data.table(names_tbl)
  key_of <- function(x) paste(x$region, normalise_seat(x$seat), as.character(as.Date(x$date)))
  have <- key_of(nm)
  reg <- sub("[0-9]{4}$", "", labels); yr <- as.integer(sub("^[a-z]+", "", labels))
  res <- list()
  for (i in seq_along(labels)) {
    prev <- yr[reg == reg[i] & yr < yr[i]]
    if (!length(prev)) next
    l0 <- paste0(reg[i], max(prev))
    if (!all(c(l0, labels[i]) %in% names(dates)))
      stop("missing_byelection_names(): no election date for ",
           paste(setdiff(c(l0, labels[i]), names(dates)), collapse = ", "))
    sel <- b[b$region == reg[i] & b$date > dates[[l0]] & b$date < dates[[labels[i]]]]
    if (!nrow(sel)) next
    miss <- sel[!(key_of(sel) %in% have)]
    if (nrow(miss)) res[[length(res) + 1L]] <- data.table::data.table(
      label = labels[i], region = miss$region, seat = miss$seat, date = miss$date)
  }
  if (length(res)) data.table::rbindlist(res) else
    data.table::data.table(label = character(0), region = character(0),
                           seat = character(0), date = as.Date(character(0)))
}
