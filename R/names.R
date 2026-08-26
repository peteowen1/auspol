#' Normalise a candidate name into the form people actually search
#'
#' Electoral commissions record legal names: `"Kylea Jane TINK"`,
#' `"Clive Frederick PALMER"`. People search `"Kylea Tink"`. Querying the legal
#' form returns **zero** for both of those, and that single fault produced two
#' wrong conclusions on 2026-08-26 -- "Tink won with no salience signal" and a
#' whole narrative about Greens breakthroughs being party-driven.
#'
#' THIS LIVES IN `R/` BECAUSE IT WAS FIXED TWICE AND BROKE A THIRD TIME. The fix
#' existed in `scripts/fetch_emergence_trends.R`, was not carried into
#' `scripts/fetch_seat_salience.R`, and Tink came back 0.0 again. Three separate
#' occasions in one day where a correction lived in one file and not its
#' sibling. A shared function is the only version of this that stays fixed.
#'
#' @param x Character vector of names in any case.
#' @return Character vector: titles and post-nominals removed, hyphens replaced
#'   with spaces, apostrophes and full stops dropped, each word capitalised.
#' @examples
#' normalise_name("Dr Monique RYAN")          # "Monique Ryan"
#' normalise_name("Max CHANDLER-MATHER")      # "Max Chandler Mather"
#' normalise_name("Rebekha SHARKIE AM")       # "Rebekha Sharkie"
#' @export
normalise_name <- function(x) {
  titles  <- "^(dr|mr|mrs|ms|miss|prof|professor|hon|the hon|sen|senator|rev)[.]? "
  postnom <- " (am|ao|oam|mp|qc|sc|kc|jr|snr|sr|ii|iii)$"
  x <- tolower(trimws(gsub("[[:space:]]+", " ", x)))
  x <- gsub(titles, "", x)
  # Repeated: "Rebekha Sharkie AM MP" carries two.
  for (i in 1:3) x <- gsub(postnom, "", x)
  x <- gsub("-", " ", x)
  x <- gsub("[.']", "", x)
  x <- gsub(intToUtf8(8217), "", x)   # curly apostrophe, by code point
  x <- gsub("[[:space:]]+", " ", trimws(x))
  vapply(strsplit(x, " "), function(p)
    paste(toupper(substring(p, 1, 1)), substring(p, 2), sep = "", collapse = " "),
    character(1))
}

#' The search form of a candidate name: first given name plus surname
#'
#' Built from the `given` and `surname` FIELDS, never by stripping the middle
#' word from a full name. That heuristic turns `"Dominic WY KANAK"` into
#' `"Dominic Kanak"`, because his surname is two words.
#'
#' @param given Character vector of given names; only the first is used.
#' @param surname Character vector of surnames.
#' @param fallback Character vector used where `given` or `surname` is missing —
#'   state commissions supply a single `name` field rather than the two.
#' @return Character vector, normalised by [normalise_name()].
#' @export
search_form <- function(given, surname, fallback) {
  first <- sub(" .*$", "", trimws(given))
  normalise_name(ifelse(is.na(given) | is.na(surname) | first == "",
                        fallback, paste(first, surname)))
}

#' A candidate's surname, from either field layout
#'
#' The AEC supplies `surname` and `given` separately; state commissions supply a
#' single `name` field, and in two different shapes -- `"ROYLANCE, Robert"` with
#' a comma, and `"GREENWICH Alex"` without. Both put the surname FIRST, so the
#' comma is a separator rather than the signal.
#'
#' @param surname Character vector, possibly `NA` for state rows.
#' @param name Character vector fallback carrying the whole name.
#' @return Lower-case surname with punctuation and spacing removed, `""` where
#'   nothing usable is present.
#' @export
surname_of <- function(surname, name) {
  s <- trimws(ifelse(is.na(surname), "", surname))
  fb <- trimws(ifelse(is.na(name), "", name))
  # comma first: everything before it. otherwise the leading token.
  from_name <- ifelse(grepl(",", fb, fixed = TRUE),
                      sub(",.*$", "", fb),
                      sub("[[:space:]].*$", "", fb))
  tolower(gsub("[^A-Za-z]", "", ifelse(nzchar(s), s, from_name)))
}

#' Did the same person contest this seat at the previous election?
#'
#' Compares SURNAMES ONLY, and exactly. A prefix or whole-name match is not safe
#' here: matching six characters of `"DANIEL, Zoe"` against the Goldstein 2019
#' field hit `Daniel POLLOCK`, a given name colliding with a surname, and
#' recorded Zoe Daniel as a returning candidate when 2022 was her first contest.
#'
#' This decides whether a win counts as an EMERGENCE, so a false match removes a
#' real case from a test set and a missed one admits an incumbent. Surname alone
#' will occasionally join two different people who share one in the same seat;
#' that direction is the safe one, because it only ever discards a case.
#'
#' @param sur Character vector of surnames for the candidates in question.
#' @param prev_sur Character vector of surnames that contested that seat last
#'   time.
#' @return Logical vector, `TRUE` where the surname appears in `prev_sur`.
#' @export
stood_before <- function(sur, prev_sur) {
  sur <- tolower(gsub("[^A-Za-z]", "", sur))
  prev_sur <- tolower(gsub("[^A-Za-z]", "", prev_sur))
  nzchar(sur) & sur %in% prev_sur[nzchar(prev_sur)]
}

#' A candidate's first given name, from either field layout
#'
#' Mirrors [surname_of()]. The AEC supplies `given` separately; state
#' commissions put the whole name in one field, surname first, either
#' `"ROYLANCE, Robert"` or `"GREENWICH Alex"`.
#'
#' @param given Character vector, possibly `NA` for state rows.
#' @param name Character vector fallback carrying the whole name.
#' @return Lower-case first given name, `""` where nothing usable is present.
#' @export
given_of <- function(given, name) {
  g <- trimws(ifelse(is.na(given), "", given))
  fb <- trimws(ifelse(is.na(name), "", name))
  rest <- ifelse(grepl(",", fb, fixed = TRUE),
                 sub("^[^,]*,[[:space:]]*", "", fb),
                 sub("^[^[:space:]]+[[:space:]]*", "", fb))
  out <- ifelse(nzchar(g), g, rest)
  tolower(gsub("[^A-Za-z]", "", sub("[[:space:]].*$", "", trimws(out))))
}

#' Match key for one candidate, at a chosen strictness
#'
#' Which rule is right is an empirical question, so all three are available and
#' `scripts/estimate_candidate_persistence.R` reports the answer under each.
#'
#' * `"surname"` — surname alone. Joins two different people who share a surname
#'   in one seat, which inflates the "same person" group.
#' * `"initial"` — surname plus first initial. The electoral-research default.
#'   It survives Kate/Katherine and Mike/Michael, but NOT the nicknames that
#'   change the initial — Bob/Robert, Bill/William, Dick/Richard — all common in
#'   Australian politics. Those split into two people under this rule.
#' * `"full"` — surname plus whole first name. Strictest, and splits every
#'   nickname case including Kate/Katherine.
#'
#' No rule is safe in both directions. Surname-only wrongly JOINS two people
#' sharing a surname; the other two wrongly SPLIT one person recorded under two
#' first names. Splitting is the more dangerous error here, because it turns a
#' returning member into a fabricated emergence.
#'
#' @param sur Character vector of surnames, from [surname_of()].
#' @param giv Character vector of first given names, from [given_of()].
#' @param rule One of `"surname"`, `"initial"`, `"full"`.
#' @return Character vector of match keys.
#' @export
match_key <- function(sur, giv, rule = c("initial", "surname", "full")) {
  rule <- match.arg(rule)
  sur <- tolower(gsub("[^A-Za-z]", "", sur))
  giv <- tolower(gsub("[^A-Za-z]", "", giv))
  switch(rule,
         surname = sur,
         initial = ifelse(nzchar(giv), paste0(sur, "|", substr(giv, 1, 1)), sur),
         full    = ifelse(nzchar(giv), paste0(sur, "|", giv), sur))
}
