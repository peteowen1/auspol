# How much of each seat's early vote has been counted, for a partly reported early unit (election night).
#
# The night model treats a district's early votes as ONE unit (every early voting centre, mobile team and the central
# out-of-district count), and that unit counts as reported once any of it has. In 2022 the largest centre held a
# median 54% of a district's early vote (range 32-93%, 88 districts, upper-house count), so a district can sit
# part-way through its early vote for much of the night. project_seat_from_booths() projects the remainder when told
# this share.
#
# OFF in the runner (opt-in --early-partial=1). Tested 2026-10-30 on an approximated vic2022 replay
# (scripts/test_early_partial_replay.R): it made the projected night share worse (RMSE 0.95 -> 1.15 with the true
# share; 1.02 with this estimate), because the early swing is measured on whichever centre came first and the
# remainder copies that skew. And this estimate read 83% counted against a true 53%: it uses last election's early
# share, and early voting grew from 37% to 50% of the vote between 2018 and 2022. A per-centre lean correction (each
# counted centre against its own last-time result) is what would make it work; 2026's centre names come on 10 Nov.
#
# The 2026 centres are named afresh ("<District> - EVC 1" in the VEC's sample), so they cannot be sized from 2022 by
# name. The share is estimated by size instead: early votes counted so far, against the expected early total, which
# is the seat's expected night vote (enrolment x turnout, night_expected_votes()) times its early share of the night
# vote last time.

#' Share of each seat's early vote counted so far
#'
#' @param live [night_booth_table()]'s `live` table (`district, booth_type, votes`).
#' @param expected Named numeric: expected NIGHT votes per seat ([night_expected_votes()], `basis = "night"`).
#' @param ref The previous election's booth table (`district, booth_type, votes`), for each seat's early share.
#' @return Named numeric in (0, 1] for every seat with early votes counted and an expected early total; capped at 1
#'   (more early votes than expected means the expectation was low, and the unit is then treated as complete, the
#'   previous behaviour). Seats with nothing counted, or no basis, are absent.
#' @export
night_early_frac <- function(live, expected, ref) {
  L <- data.table::as.data.table(live); R <- data.table::as.data.table(ref)
  R[is.na(votes), votes := 0]
  night_types <- c("ordinary", "early", "postal")
  rs <- R[R$booth_type %in% night_types, list(early = sum(votes[booth_type == "early"]), night = sum(votes)), by = "district"]
  rs <- rs[rs$night > 0]
  share_prev <- stats::setNames(rs$early / rs$night, rs$district)
  ce <- L[L$booth_type == "early", list(v = sum(votes, na.rm = TRUE)), by = "district"]
  ce <- ce[ce$v > 0]
  if (!nrow(ce) || is.null(expected)) return(stats::setNames(numeric(0), character(0)))
  exp_early <- unname(expected[ce$district]) * unname(share_prev[ce$district])
  f <- ce$v / exp_early
  ok <- is.finite(f) & f > 0
  out <- stats::setNames(pmin(1, f[ok]), ce$district[ok])
  out
}
