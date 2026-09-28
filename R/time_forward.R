#' Training elections for a constant fitted to forecast one election
#'
#' Under `AUSPOL_TIME_FORWARD_FITS=1` (the default) keeps only pairs whose
#' election is dated strictly before `target_election`'s, so a backtest never
#' learns a constant from a later election. `0` restores the old
#' leave-target-out choice, for comparison only. For the live forecast every
#' past election is earlier, so the two agree there.
#' docs/plans/prereg-time-forward-constants-2026-09-28.md.
#'
#' @param target_election Label such as `"fed2019"`.
#' @param pairs List of pairs, each with an `election` element.
#' @return The filtered list.
#' @export
fit_pairs_for <- function(target_election, pairs) {
  if (identical(Sys.getenv("AUSPOL_TIME_FORWARD_FITS", "1"), "0"))
    return(Filter(function(pr) !identical(pr$election, target_election), pairs))
  keep <- elections_before(vapply(pairs, `[[`, character(1), "election"), target_election)
  pairs[keep]
}

#' Which elections are dated strictly before a target election
#'
#' Vector form of [fit_pairs_for()] for tables keyed by an election label.
#' Under `AUSPOL_TIME_FORWARD_FITS=0` it is `elections != target_election`.
#'
#' @param elections Character vector of election labels.
#' @param target_election Label of the election being forecast.
#' @return Logical vector, `FALSE` for undated labels.
#' @export
elections_before <- function(elections, target_election) {
  if (identical(Sys.getenv("AUSPOL_TIME_FORWARD_FITS", "1"), "0"))
    return(elections != target_election)
  # The exact polling day where election_dates() has it; otherwise mid-year of
  # the 4-digit year the label ends in (test fixtures and any election added
  # to the corpus before its date is). No year either is an error.
  d <- election_dates()
  date_of <- function(x) {
    out <- suppressWarnings(as.Date(unname(d[x])))
    yr <- suppressWarnings(as.integer(sub("^.*?([0-9]{4})$", "\\1", x)))
    miss <- is.na(out) & !is.na(yr) & grepl("[0-9]{4}$", x)
    out[miss] <- as.Date(sprintf("%d-07-01", yr[miss]))
    out
  }
  td <- date_of(target_election)
  # A target that is not a datable election (no polling day, no year in its
  # label: test fixtures, a "nope" meaning exclude nothing) has no "before";
  # fall back to dropping the target itself. Every real election has a date
  # or a year, so this cannot reopen the leak for an actual backtest.
  if (length(td) != 1L || is.na(td)) return(elections != target_election)
  ed <- date_of(elections)
  !is.na(ed) & ed < td
}
