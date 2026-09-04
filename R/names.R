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
  # BUILD FROM THE PARSED PARTS, always. The previous version fell back to the
  # raw `fallback` string whenever `given` or `surname` was missing, and every
  # state commission supplies ONE combined name field -- so half the corpus went
  # to Google surname-first:
  #
  #   sent            should have been
  #   "Hood, Lucy"    "Lucy Hood"
  #   "Clancy Justin" "Justin Clancy"
  #   "Enoch, Leeanne" "Leeanne Enoch"
  #
  # 7,505 of 14,953 rows. Nobody searches a name that way, so South Australia
  # returned 104 of 109 candidates at exactly zero and could not be ranked at
  # all. surname_of() and given_of() already parse both state layouts; this now
  # uses them instead of guessing from field presence.
  # Use the RAW fields where a commission supplies them: surname_of() strips
  # spaces because matching wants "wykanak", but a search term does not --
  # Dominic Wy Kanak's surname is two words and "Wykanak" finds nothing. Only
  # the combined single-field layouts get parsed.
  sur_raw <- trimws(ifelse(is.na(surname), "", surname))
  giv_raw <- trimws(ifelse(is.na(given), "", given))
  # Combined single-field names come in THREE layouts and the reliable signal is
  # which token is ALL CAPS, not where it sits:
  #     "HOOD, Lucy"     comma, surname first
  #     "GREENWICH Alex" no comma, surname first
  #     "Zoe DANIEL"     surname LAST
  # Guessing by position gets one of them wrong, and the previous version sent
  # 7,505 of 14,953 rows to Google surname-first.
  split_one <- function(fb) {
    fb <- trimws(ifelse(is.na(fb), "", fb))
    if (!nzchar(fb)) return(c("", ""))
    if (grepl(",", fb, fixed = TRUE)) {
      return(c(trimws(sub(",.*$", "", fb)), trimws(sub("^[^,]*,[[:space:]]*", "", fb))))
    }
    tk <- strsplit(fb, "[[:space:]]+")[[1]]
    caps <- grepl("^[^a-z]+$", tk) & grepl("[A-Z]", tk)
    if (any(caps) && !all(caps)) {
      return(c(paste(tk[caps], collapse = " "), paste(tk[!caps], collapse = " ")))
    }
    # No case signal: assume the natural order, given then surname.
    c(tk[length(tk)], paste(tk[-length(tk)], collapse = " "))
  }
  parsed <- vapply(fallback, split_one, c("", ""), USE.NAMES = FALSE)
  sur <- ifelse(nzchar(sur_raw), tolower(sur_raw), tolower(parsed[1, ]))
  giv <- ifelse(nzchar(giv_raw), tolower(sub("[[:space:]].*$", "", giv_raw)),
                tolower(sub("[[:space:]].*$", "", parsed[2, ])))
  # Preserve the original capitalisation where the fields carry it; the parsed
  # forms are lower-case and Trends is case-insensitive, so title-case here is
  # for readability in logs rather than for matching.
  # Title-case each word, so a two-word surname reads "Wy Kanak" not "Wy kanak".
  tc <- function(x) vapply(x, function(z) {
    if (!nzchar(z)) return(z)
    paste(vapply(strsplit(z, "[[:space:]]+")[[1]], function(w)
      paste0(toupper(substr(w, 1, 1)), substr(w, 2, nchar(w))), ""), collapse = " ")
  }, "", USE.NAMES = FALSE)
  out <- ifelse(nzchar(giv) & nzchar(sur), paste(tc(giv), tc(sur)),
         ifelse(nzchar(sur), tc(sur), tc(giv)))
  normalise_name(out)
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

#' Normalise a seat name for cross-election joins, case/punctuation only
#'
#' Strips case and punctuation so `"Albert Park"` and `"albertpark"` join --
#' the fix for the vic2014/vic2018 mismatch that once matched ZERO Victorian
#' seat-classes and read as "Victoria has few returners" (see
#' `candidate_returns()`). Does NOT resolve a genuine redistribution rename;
#' that needs [seat_rename_map()] as well, matched against both spellings.
#'
#' @param x Character vector of seat names.
#' @return Character vector, lower-case with only `[a-z0-9]` retained.
#' @export
normalise_seat <- function(x) gsub("[^a-z0-9]", "", tolower(x))

#' Known cross-election seat renames not captured by case/punctuation alone
#'
#' `THIS LIVES IN R/` because it was fixed once inside `governed_population()`
#' (`R/salience_screen.R`) and, being local to that function, was not carried
#' into `candidate_returns()` / `personal_prior_vote()` (`R/candidate_returns.R`)
#' -- the exact "fixed once, not in its sibling" failure [[normalise_name]]'s
#' own docs record for candidate names. Found 2026-09-04 building a
#' candidate-performance feature: Andrew Wilkie's continuous Denison (2016,
#' 44.1%) -> Clark (2019, 50.0%) hold read as a brand-new IND candidate
#' massively "overperforming" a 2.2% expectation, because `candidate_returns()`
#' only strips case/punctuation and Denison/Clark share neither.
#'
#' A caller must match against BOTH the pre- and post-rename spelling, never
#' just the renamed one -- applying the rename unconditionally is wrong for
#' any election pair entirely BEFORE it took effect (both elections still
#' call a seat by its old name), which was a second, separate bug found the
#' same day (see `R/salience_screen.R`'s `governed_population()`).
#'
#' Only high-confidence, independently-verifiable renames are listed. Diffing
#' seat-name sets between election pairs surfaces 1-10 unmatched names per
#' pair, most of them genuine seat creation/abolition from population growth,
#' not renames -- guessing which is which from name similarity alone would
#' repeat the exact error this map exists to prevent. An unmapped rename is a
#' known, disclosed gap, not a silently-assumed-complete one.
#'
#' @return A named character vector, pre-rename [[normalise_seat]] key ->
#'   post-rename key.
#' @export
seat_rename_map <- function() {
  c(denison = "clark", batman = "cooper", melbourneports = "macnamara")
}
