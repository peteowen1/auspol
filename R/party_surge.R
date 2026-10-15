#' How far a party's STATEWIDE vote moved between two elections
#'
#' A candidate with no prior vote in a seat is not necessarily an emerging
#' candidate. One Nation went from 2.63% to 22.50% across South Australia in
#' 2026, contesting 47 seats instead of 19, and 19 of its 47 candidates polled
#' above 25%. Its four winners had little or no prior vote in their seats, so a
#' candidate-level definition called them emergences — but nothing about them was
#' personal. The uniform party swing already carries most of it: Hammond's winner
#' is predicted exactly, and the others within 7 to 15 points.
#'
#' A **candidate** emergence is a person outrunning their party. A **party**
#' emergence is the party moving and taking its candidates with it. The seat
#' model handles the second through the statewide swing, and a name-search
#' signal has no reason to see it at all — asking one to explain the other is
#' what made South Australia look like a failure of the signal.
#'
#' @param region,year_from,year_to Election identifiers as used in
#'   `output/candidacies.csv`.
#' @param corpus Optional pre-read candidacy table.
#' @return A `data.table` of `party`, `prev`, `now`, `swing` in percentage
#'   points of the statewide first-preference vote.
#' @export
party_swing <- function(region, year_from, year_to, corpus = NULL) {
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) stop("needs output/candidacies.csv", call. = FALSE)
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  # EIGHTH instance of the data.table NSE trap (CLAUDE.md): `region` is both
  # the argument and a column of C, and inside `C[...]` the bare symbol binds
  # to the COLUMN, so `C$region == region` was always TRUE and every region's
  # votes were pooled. Copied to a differently-named local before use.
  region_arg <- region
  share <- function(y) {
    d <- C[C$region == region_arg & C$year == y]
    if (!nrow(d)) stop("no rows for ", region_arg, y, call. = FALSE)
    # AN ELECTION NOT YET HELD HAS NO SWING. The corpus carries vic2026 and
    # nsw2027 with every `votes` NA; summed, they became NA shares, the
    # `is.na(now) := 0` below read those as "polled nothing", and every class
    # above 5% "collapsed" -- so the published vic2026 forecast flagged ALP,
    # LNP, GRN, IND and OTH_RIGHT as surging and granted 6 seat-class permits
    # on it (2026-10-15). A missing vote is an error, never a zero.
    if (anyNA(d$votes))
      stop(sprintf("%d of %d rows for %s%d have no votes -- an election not yet held has no swing",
                   sum(is.na(d$votes)), nrow(d), region_arg, y), call. = FALSE)
    t <- d[, list(v = sum(votes)), by = party]
    t[, list(party, pct = 100 * v / sum(v))]
  }
  a <- share(year_from); b <- share(year_to)
  out <- merge(a[, list(party, prev = pct)], b[, list(party, now = pct)],
               by = "party", all = TRUE)
  out[is.na(prev), prev := 0][is.na(now), now := 0]
  out[, swing := now - prev][order(-swing)]
}

#' Is this candidate's lack of prior vote a PARTY story rather than a personal one?
#'
#' Flags classes whose statewide vote moved by more than `threshold` points. A
#' candidate of such a class with no prior seat vote is riding a party surge, not
#' emerging personally, and the salience screen makes no claim about them.
#'
#' The default of 5 points is above ordinary election-to-election movement — the
#' major parties move 1 to 4 points in a typical cycle — and well below South
#' Australian One Nation's 19.9.
#'
#' WHICH swing is read is set by `AUSPOL_SURGE_SOURCE`
#' (`docs/plans/prereg-surge-flag-time-forward-2026-10-15.md`):
#' \describe{
#'   \item{`"actual"`}{`abs()` of the ACTUAL swing at `year_to`. Leaks: it reads
#'     the result of the election being predicted, and counts a collapse as a
#'     surge (`docs/reviews/surge-flag-leak-2026-10-15.md`). Kept only as the
#'     arm that measures what the leak was worth.}
#'   \item{`"none"`}{no class is surging. (The live forecast did NOT already
#'     get this: until 2026-10-15 a not-yet-held `year_to` read as every class
#'     collapsing. It is now an error, see [party_swing()].)}
#'   \item{`"forecast"`}{RISES only, `level_pred - prev >= threshold`, from the
#'     time-forward statewide forecast: `levels` when given (the live run passes
#'     its own statewide forecast), else `output/level-pred.csv`. A class with
#'     no forecast row is not surging. A target with no rows at all is an error.}
#' }
#'
#' @inheritParams party_swing
#' @param threshold Statewide swing, in points, above which a class counts as
#'   surging.
#' @param source `"actual"`, `"none"` or `"forecast"`; defaults to
#'   `AUSPOL_SURGE_SOURCE`.
#' @param levels For `"forecast"`: a table of `pair`, `party`, `level_pred`;
#'   `NULL` reads `output/level-pred.csv`. Ignored by the other sources.
#' @return Character vector of party classes.
#' @export
surging_parties <- function(region, year_from, year_to, threshold = 5,
                            corpus = NULL,
                            source = Sys.getenv("AUSPOL_SURGE_SOURCE", "actual"),
                            levels = NULL) {
  if (!source %in% c("actual", "none", "forecast"))
    stop("AUSPOL_SURGE_SOURCE must be \"actual\", \"none\" or \"forecast\", not \"",
         source, "\"", call. = FALSE)
  if (identical(source, "none")) return(character(0))
  if (identical(source, "actual")) {
    s <- party_swing(region, year_from, year_to, corpus)
    return(s[abs(swing) >= threshold, party])
  }
  # "forecast" never touches `year_to`'s rows: not its votes, not which classes
  # contested it (the live target has neither). The previous result comes from
  # `year_from` alone; a class with a forecast row and no previous vote starts at 0.
  C <- corpus
  if (is.null(C)) {
    f0 <- file.path("output", "candidacies.csv")
    if (!file.exists(f0)) stop("needs output/candidacies.csv", call. = FALSE)
    C <- data.table::fread(f0, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  region_arg <- region; from_arg <- year_from
  d0 <- C[C$region == region_arg & C$year == from_arg]
  if (!nrow(d0)) stop("no rows for ", region_arg, from_arg, call. = FALSE)
  s <- d0[, list(v = sum(votes)), by = party][, list(party, prev = 100 * v / sum(v))]
  if (is.null(levels)) {
    f <- file.path("output", "level-pred.csv")
    if (!file.exists(f)) stop("AUSPOL_SURGE_SOURCE=forecast needs ", f, call. = FALSE)
    levels <- data.table::fread(f, showProgress = FALSE)
  }
  levels <- data.table::as.data.table(levels)
  target <- paste0(region, year_to)
  lp <- levels[levels$pair == target, list(party, level_pred)]
  if (!nrow(lp)) stop("no level_pred rows for ", target, call. = FALSE)
  # LIKE WITH LIKE. The live forecast models five classes and its OTH is the
  # whole minor field: fit_seats_full.R scales every class it does not model
  # (OTH_RIGHT, IND) into that one total. Compared with last time's OTH alone,
  # vic2026 read 11.47 against 4.82 -- a 6.65-point "surge" in a minor field
  # forecast to FALL from 16.87 (review of surge-live, 2026-10-15). So when the
  # levels say so, last time's classes with no level row are added into OTH's.
  # output/level-pred.csv carries no such column and keeps its classes separate.
  if ("oth_absorbs_missing" %in% names(levels) && any(levels$oth_absorbs_missing %in% TRUE)) {
    if (!"OTH" %in% lp$party)
      stop("levels for ", target, " fold the minor field into OTH but have no OTH row", call. = FALSE)
    s <- data.table::copy(s)
    s[!s$party %in% lp$party, party := "OTH"]
    s <- s[, list(prev = sum(prev)), by = party]
  }
  m <- merge(s, lp, by = "party", all.y = TRUE)
  m[is.na(prev), prev := 0]
  m[, swing_fc := level_pred - prev]
  out <- m[!is.na(swing_fc) & swing_fc >= threshold, party]
  stopifnot(all(m[party %in% out]$swing_fc > 0))   # a fall is never a surge
  # PRINTED AT THE POINT OF USE for the live target (the prereg's live clause):
  # the level each class was compared with, not just the verdict.
  if ("oth_absorbs_missing" %in% names(levels))
    cat(sprintf("SG1  %s surge flag (forecast, threshold %g): %s -> surging: %s\n", target, threshold,
                paste(sprintf("%s %.2f->%.2f", m$party, m$prev, m$level_pred), collapse = ", "),
                if (length(out)) paste(out, collapse = ",") else "none"))
  out
}

#' The live run's statewide forecast, in the shape `surging_parties(levels=)` reads
#'
#' `output/level-pred.csv` holds only elections already held, so the live
#' target has to bring its own level: the same `state_mean` the seat model is
#' simulating around, in percentage points. Its OTH is the whole minor field
#' (the live run scales every class it does not model into it), so the table
#' says so, and [surging_parties()] compares it with the previous election's
#' unlisted classes added together.
#'
#' @param election The target label, e.g. `"vic2026"`.
#' @param state_mean Named numeric vector of statewide first-preference shares
#'   in points, one per class.
#' @return A `data.table` of `pair`, `party`, `level_pred`, `oth_absorbs_missing`.
#' @keywords internal
surge_levels_live <- function(election, state_mean) {
  nm <- names(state_mean)
  if (is.null(nm) || anyNA(nm) || any(!nzchar(nm)) || anyDuplicated(nm))
    stop("surge_levels_live(): state_mean needs unique, non-empty class names", call. = FALSE)
  if (!all(is.finite(state_mean)))
    stop("surge_levels_live(): state_mean has a non-finite share", call. = FALSE)
  # points, not proportions: a 0.21 One Nation would never clear a 5-point threshold
  if (abs(sum(state_mean) - 100) > 1)
    stop(sprintf("surge_levels_live(): state_mean sums to %.2f, not 100 -- not percentage points",
                 sum(state_mean)), call. = FALSE)
  data.table::data.table(pair = election, party = nm, level_pred = unname(state_mean),
                         oth_absorbs_missing = TRUE)
}
