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
#' @param returns Optional pre-computed [candidate_returns()] result; computed
#'   if `NULL`.
#' @param surge_threshold Passed to [surging_parties()].
#' @return A `data.table` of `seat`, `party`, `permit`, or `NULL` if
#'   `output/salience-v6.csv` has no rows for `election`.
#' @export
salience_permit_for <- function(election, prev_election, region, returns = NULL,
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
  if (is.null(returns)) {
    returns <- tryCatch(candidate_returns(prev_election, election),
                        error = function(e) NULL)
  }
  yr <- as.integer(sub("^[a-z]+", "", election))
  py <- as.integer(sub("^[a-z]+", "", prev_election))
  surging <- tryCatch(surging_parties(region, py, yr, surge_threshold),
                      error = function(e) character(0))
  nk <- function(a, b) paste(gsub("[^a-z0-9]", "", tolower(a)), b)
  if (!is.null(returns)) {
    ret <- returns$same[match(nk(SAL$seat, SAL$party), nk(returns$seat, returns$party))]
  } else ret <- rep(FALSE, nrow(SAL))
  ret[is.na(ret)] <- FALSE
  SAL[, governed := prev_party < 15 & !(party %in% surging) & !ret]
  SAL[, permit := salience_screen(jump, governed)]
  cat(sprintf("SP1  %s screen: registration %.0f%% | governed %d | permitted %d of governed | surging: %s\n",
              election, 100 * salience_registration(SAL$jump), sum(SAL$governed),
              sum(SAL$permit[SAL$governed]),
              if (length(surging)) paste(surging, collapse = ",") else "none"))
  SAL[, .(seat, party, permit)]
}
