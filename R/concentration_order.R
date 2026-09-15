#' Order seats by how favourable they are to a right-minor party
#'
#' The seat-level concentration mechanisms in `backtest_candidate_sa.R` and
#' `fit_seats_full.R` both work the same way: rank the seats on some signal,
#' then spread a fitted amount of concentration along that ranking. The
#' shipped ranking is the transposed federal vote for the same party, and it
#' EXISTS FOR ONE PAIR -- sa2026 -- which is why sa2022 is skipped and why the
#' other 22 pairs run with no concentration at all.
#'
#' Year 12 completion is available for every seat in every pair, and its
#' correlation with a right-minor party's vote is negative in **43 of 43**
#' party-elections measured: One Nation in 7 of 7, OTH_RIGHT in 13 of 13, and
#' the mirror image for the Greens, positive in 23 of 23. Its Spearman against
#' the actual vote runs 0.665 to 0.800 wherever the party is non-trivial.
#'
#' NOT A REPLACEMENT FOR THE FEDERAL SIGNAL. On sa2026, the one pair carrying
#' both, federal ranks better (0.939 against 0.922 for One Nation, and 0.538
#' against 0.144 for OTH_RIGHT). This exists to extend the mechanism to pairs
#' that have no federal signal, not to displace it where one exists. See
#' docs/plans/prereg-education-ranked-concentration-2026-09-15.md.
#'
#' @param pair Election label, e.g. `"qld2020"`, matching `census-features.csv`.
#' @param seats Character vector of seat names, in the order the caller wants
#'   the result in.
#' @param file Census feature table.
#' @return Numeric vector, one value per seat, HIGHER meaning more favourable
#'   to a right-minor party -- so it can be used wherever the federal vote
#'   currently is, with the same direction. `NA` for a seat with no census row;
#'   the caller decides what to do about that, as it already must for the
#'   federal signal.
#' @export
education_order <- function(pair, seats,
                            file = "output/census-features.csv") {
  if (!file.exists(file)) {
    return(rep(NA_real_, length(seats)))
  }
  C <- data.table::fread(file, showProgress = FALSE)
  if (!all(c("pair", "seat", "yr12_pct") %in% names(C))) {
    return(rep(NA_real_, length(seats)))
  }
  # `.p` and `.s`, not `pair`/`seat`: a bare argument name matching a column
  # inside `[` binds to the COLUMN, which CLAUDE.md records eight times.
  .p <- pair
  sub <- C[C$pair == .p]
  if (!nrow(sub)) return(rep(NA_real_, length(seats)))
  v <- suppressWarnings(as.numeric(sub$yr12_pct))
  # NEGATED. yr12_pct rises where the party does WORSE, and the callers all
  # treat a higher ordering value as more favourable, so flipping it here
  # keeps this a drop-in for the federal vote rather than something every
  # caller has to remember to reverse.
  -v[match(seats, sub$seat)]
}

#' Spread a level across seats to hit a target concentration
#'
#' Normal quantile map: rank the seats on `ix`, assign z-scores, scale to
#' `target_sd`, recentre on `level`. Lifted verbatim from
#' `backtest_candidate_sa.R` so the two cannot drift, and so the mechanism can
#' be applied in harnesses that never had it.
#'
#' It imports no shape information from the election being predicted -- only
#' the ordering and the target spread.
#'
#' @param level Statewide share, in points.
#' @param target_sd Target standard deviation across seats, in points.
#' @param ix Ordering signal, higher = more favourable. Ties broken by first.
#' @return Numeric vector of per-seat shares, mean preserved at `level`.
#' @export
concentration_allocate <- function(level, target_sd, ix) {
  stopifnot(length(ix) > 1, is.finite(level), is.finite(target_sd),
            target_sd >= 0)
  if (anyNA(ix)) {
    stop("concentration_allocate(): ", sum(is.na(ix)), " of ", length(ix),
         " seats have no ordering value. The caller must decide whether to ",
         "skip the pair or fall back -- silently ranking NAs would assign a ",
         "position to a seat we know nothing about.")
  }
  rk <- rank(ix, ties.method = "first")
  z <- stats::qnorm((rk - 0.5) / length(rk))
  out <- pmax(0, level + target_sd * z)
  m <- mean(out)
  if (m <= 0) return(out)
  out * (level / m)
}
