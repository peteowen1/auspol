#' Which candidates salience permits to emerge
#'
#' The seat model cannot distinguish a new candidate who will poll 2% from one
#' who will win, because neither has a prior vote in the seat. Dai Le had 0.0%
#' and won Fowler on 29.5%. Applying an emergent's treatment to all ~300 such
#' candidates is what made conditional slopes hurt every emergence election they
#' touched.
#'
#' Salience separates them, and it does so in ONE direction only. Measured across
#' five elections after correcting the population definition: **709 governed
#' candidates were silent and none of them won**. Firing is therefore permission,
#' never a prediction — Ian Cook topped Victoria on 18.0% and lost, David Speirs
#' topped South Australia on 14.1%.
#'
#' @section The registration test:
#' A field where almost nobody registers carries no information, and treating
#' silence as evidence there would be wrong. South Australia had 7 of 111
#' candidates fire; federal elections have a third. Below `min_fire` the screen
#' returns all-permit, which reproduces the unscreened model exactly.
#'
#' @param jump Numeric campaign-salience values, one per candidate.
#' @param governed Logical: is this candidate one the screen speaks about? A
#'   sitting member is not, nor is a candidate of a class whose statewide vote
#'   surged — see [candidate_returns()] and [surging_parties()].
#' @param min_fire Minimum share of the field that must register for the screen
#'   to apply at all.
#' @return Logical vector, `TRUE` where the candidate may emerge. Ungoverned
#'   candidates are always `TRUE`: the screen makes no claim about them.
#' @export
salience_screen <- function(jump, governed, min_fire = 0.10) {
  if (length(jump) != length(governed)) {
    stop("jump and governed must be the same length: ", length(jump), " vs ",
         length(governed), call. = FALSE)
  }
  if (!length(jump)) return(logical(0))
  jump[!is.finite(jump)] <- 0
  fired <- jump > 0
  # DECIDED FROM THE FIELD, with no outcome data.
  if (mean(fired) < min_fire) return(rep(TRUE, length(jump)))
  # Silence is only evidence about candidates the screen governs.
  !governed | fired
}

#' Share of a field that registers any campaign salience
#'
#' The quantity the registration test reads. Reported separately so a run can
#' print it before any result is looked at.
#'
#' @param jump Numeric campaign-salience values.
#' @return Proportion in `[0, 1]`.
#' @export
salience_registration <- function(jump) {
  if (!length(jump)) return(0)
  jump[!is.finite(jump)] <- 0
  mean(jump > 0)
}

#' The screen's permit vector for one election, built once and shared
#'
#' Wraps [candidate_returns()], [surging_parties()] and [salience_screen()]
#' into the single lookup every backtest harness needs: for each seat and party
#' class, may this candidate be treated as a potential emergence?
#'
#' One implementation because five harnesses build shares five different ways,
#' and a governed-population definition assembled slightly differently in each
#' is how a bug like the Donato mismatch survives in one harness after being
#' fixed in another.
#'
#' @param election,prev_election Election labels as used in
#'   `output/candidacies.csv` and `output/salience-v6.csv`.
#' @param region The region code (`"fed"`, `"vic"`, `"sa"`, `"nsw"`), for
#'   [surging_parties()].
#' @param surge_threshold Passed to [surging_parties()].
#' @return A `data.table` of `seat`, `party`, `permit`, or `NULL` if
#'   `output/salience-v6.csv` has no rows for `election`.
#' @export
salience_permit_for <- function(election, prev_election, region,
                                surge_threshold = 5) {
  sf <- file.path("output", "salience-v6.csv")
  if (!file.exists(sf)) return(NULL)
  # NOT a bare `election` inside `[`: `raw` has a column of that name, and
  # data.table scopes columns into the `i` expression's evaluation, so
  # `raw$election == election` silently resolved to `raw$election ==
  # raw$election` -- always TRUE, matching every row regardless of the
  # argument. The sixth instance of the NSE trap CLAUDE.md already records five
  # times. Renamed to a value with no column-name collision.
  raw <- data.table::fread(sf, showProgress = FALSE)
  target_election <- election
  SAL <- raw[raw$election == target_election]
  if (!nrow(SAL)) return(NULL)
  yr <- as.integer(sub("^[a-z]+", "", election))
  py <- as.integer(sub("^[a-z]+", "", prev_election))
  surging <- tryCatch(surging_parties(region, py, yr, surge_threshold),
                      error = function(e) character(0))
  # MATCH EACH CANDIDATE PERSONALLY, not their class. output/salience-v6.csv is
  # already one row per NAMED candidate -- unlike a class-level `returns` table,
  # which has one row per (seat, party) and answers "did ANYONE of this class
  # return here". Joining that in by (seat, party) broadcasts one class-level
  # verdict to every candidate sharing it: a genuinely new minor candidate in a
  # multi-independent seat inherited "returning" from an unrelated person who
  # happened to share the class. Measured across the five elections this screen
  # scores: 54 seat-class instances where the class-level flag disagreed with
  # the actual leading candidate, none of them affecting a seat that was won --
  # but SAL already carries names, so the correct match uses them directly.
  C <- tryCatch(data.table::fread("output/candidacies.csv", showProgress = FALSE),
               error = function(e) NULL)
  if (!is.null(C)) {
    PREVT <- C[C$election == prev_election]
    # search_form(), not surname_of()/given_of(): SAL$keyword is already this
    # function's own output ("Aaron Kelly", given-name first -- confirmed
    # against output/salience-v6.csv), while surname_of()/given_of() assume
    # the OPPOSITE, surname-first convention used by raw commission name
    # fields. Applying them to `keyword` silently took the first token as the
    # surname, which is the given name here -- the match key would have
    # compared the wrong pieces even after the (seat, party) join was fixed.
    # Reusing search_form() on PREVT's own given/surname/name compares two
    # values built the same way, rather than reimplementing its name-order
    # guess a second time.
    pk <- search_form(PREVT$given, PREVT$surname, PREVT$name)
    ns <- function(x) gsub("[^a-z0-9]", "", tolower(x))
    pseat <- ns(PREVT$seat)
    sk <- SAL$keyword
    sseat <- ns(SAL$seat)
    # %in%, not `any(sk[i] == pk & ...)`: pk/pseat can hold NA for a candidate
    # with no usable name, and `any()` over a vector that is all FALSE/NA with
    # no TRUE returns NA, not FALSE -- that NA then corrupted `governed`
    # downstream (observed: sum(SAL$governed) printed NA on a real run).
    .valid <- !is.na(pk) & nzchar(pk) & !is.na(pseat)
    prev_keys <- unique(paste(pseat[.valid], pk[.valid]))
    ret <- nzchar(sk) & !is.na(sk) & paste(sseat, sk) %in% prev_keys
  } else ret <- rep(FALSE, nrow(SAL))
  SAL[, governed := prev_party < 15 & !(party %in% surging) & !ret]
  SAL[, permit := salience_screen(jump, governed)]
  cat(sprintf("SP1  %s screen: registration %.0f%% | governed %d | permitted %d of governed | surging: %s\n",
              election, 100 * salience_registration(SAL$jump), sum(SAL$governed),
              sum(SAL$permit[SAL$governed]),
              if (length(surging)) paste(surging, collapse = ",") else "none"))
  SAL[, .(seat, party, permit)]
}
