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
#' election held after it. Not "won at any earlier election": a member who lost
#' their seat two elections ago is a former member, and flagging them told the
#' model a challenger was an incumbent (Ali Cupper, Mildura, vic2026).
#'
#' A by-election in a seat supersedes the previous general election's winner
#' there, so the member who resigned and was replaced (Tim Pallas, Werribee) is
#' not counted as sitting should they stand again.
#'
#' @param cand Candidates: `region`, `year`, `seat`, `sur`, `giv`.
#' @param winners Elected candidates of general elections: `region`, `year`,
#'   `seat`, `sur`, `giv`.
#' @param byelections By-election and supplementary-election winners:
#'   `region`, `year` (calendar year of the by-election), `seat`, `sur`, `giv`.
#'   `NULL` for none.
#' @return Logical vector, one per row of `cand`.
#' @export
returning_member_flags <- function(cand, winners, byelections = NULL) {
  out <- rep(FALSE, nrow(cand))
  cand <- as.data.frame(cand)
  winners <- as.data.frame(winners)
  if (!is.null(byelections)) byelections <- as.data.frame(byelections)
  ns <- normalise_seat
  for (r in unique(cand$region)) {
    for (y in unique(cand$year[cand$region == r])) {
      yrs <- unique(cand$year[cand$region == r & cand$year < y])
      if (!length(yrs)) next
      py <- max(yrs)
      w <- winners[winners$region == r & winners$year == py, ]
      if (!is.null(byelections) && nrow(byelections)) {
        b <- byelections[byelections$region == r & byelections$year >= py &
                           byelections$year <= y, ]
        if (nrow(b)) {
          w <- w[!(ns(w$seat) %in% ns(b$seat)), ]
          w <- rbind(w[, c("seat", "sur", "giv")], b[, c("seat", "sur", "giv")])
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
