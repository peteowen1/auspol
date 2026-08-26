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
