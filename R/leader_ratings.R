#' Leader ratings for a forecast page
#'
#' Preferred premier/PM, satisfaction and net satisfaction for one election cycle, one row per poll x leader x
#' measure, from `output/leader-ratings.csv` (`scripts/build_leader_ratings.R`; Pete, 2026-10-12). The page
#' builders (`scripts/build_page.R`, `scripts/build_trend_page_data.R`) put it under the JSON key `leaders`.
#' Display only: leader approval was tested as a forecast input and refused
#' (docs/plans/prereg-leader-approval-miss-2026-10-12.md).
#'
#' @param election Cycle label, e.g. `"vic2026"`.
#' @param f Path to the table.
#' @return A list with `as_of` (newest poll date), `rows` (data.frame: `date`, `firm`, `leader`, `party`,
#'   `role` gov/opp/minor, `measure`, `value`, `n_named` for preferred questions, `source`), or `NULL` when the
#'   table is missing, with a message saying so.
#' @export
leader_page_data <- function(election, f = out_path("leader-ratings.csv")) {
  if (!file.exists(f)) {
    message("leader_page_data(): ", f, " not found -- the page is built without leader ratings")
    return(NULL)
  }
  L <- data.table::fread(f, showProgress = FALSE)
  target <- election
  keep <- L$election == target & L$measure %in% c("preferred", "pref_undecided", "satisfied", "dissatisfied", "net_sat", "approve", "disapprove")
  L <- L[keep]
  if (!nrow(L)) {
    message("leader_page_data(): no leader ratings for ", target)
    return(NULL)
  }
  cols <- intersect(c("date", "firm", "leader", "party", "role", "measure", "value", "n_named", "source"), names(L))
  L <- L[, cols, with = FALSE]
  data.table::setorderv(L, c("date", "leader", "measure"))
  list(as_of = as.character(max(as.Date(L$date))), rows = as.data.frame(L))
}
