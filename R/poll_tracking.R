# Does each fitted party actually follow the polls it was fitted to?
#
# This replaces the endpoint-SUM check (L3 / FL3 / NL3), which required each
# cycle's fitted first preferences to sum to 100 +/- 5. Two problems with that,
# both established in
# docs/reviews/nl3-sum-is-one-nation-2026-08-18.md:
#
#   1. The model does not promise the sum. Parties are fitted independently
#      with shrinkage toward the previous result, and FORCING them to sum was
#      measured to cost 0.33 points of first-preference MAE. The untidiness is
#      bought on purpose.
#   2. A sum cannot say which party is off, by how much, or in which direction,
#      and it stays silent when two parties err opposite ways. NSW 2027 failed
#      at 94.1; the whole shortfall was One Nation sitting 4.4 points below its
#      own recent polling while every other party tracked within 1.
#
# Designed and its threshold fixed in docs/plans/prereg-per-party-poll-check.md,
# committed before the threshold was computed.

#' Maximum permitted gap between a fitted endpoint and its recent polls
#'
#' The 99th percentile of |fitted - mean of the final 90 days of polls| over
#' the historical record of cycles with complete actuals (138 party-cycles over
#' 33 cycles), rounded up to the nearest 0.5. Measured 2026-08-18: the
#' percentile is 2.478 and two historical rows breach 2.5 (SA 2010 ALP at 2.67,
#' WA 2017 ONP at 2.50).
#'
#' The RULE that produced this number was committed in
#' `docs/plans/prereg-per-party-poll-check.md` before the number was computed,
#' so it could not be chosen to make a failing build pass. The plan also fixed
#' a refusal condition -- do not adopt if the bound exceeds 5.0, which would
#' make the per-party tolerance looser than the whole-cycle sum it replaces.
#' It came out at 2.5.
#'
#' The 99th and not the maximum, so one pathological cycle cannot set a bound
#' nothing can ever breach; not the 95th, which would fail 1 cycle in 20 by
#' construction.
#' @export
POLL_TRACKING_BOUND <- 2.5

#' Compare each fitted endpoint against the polls behind it
#'
#' @param cp Cycle polls, as returned by [cycle_polls()].
#' @param fits Named list of fits, as returned by [fit_cycle_trends()] or
#'   [fit_cycle_unfolded()].
#' @param window Days before the last poll to average over.
#' @param min_polls Parties with fewer polls in the window are reported but not
#'   asserted on — there is nothing to be close to.
#' @param bound Maximum permitted |fitted − mean poll|.
#' @return data.table: `party`, `fitted`, `poll_mean`, `n`, `dev`, `asserted`,
#'   `breach`. Attribute `bound` carries the threshold used.
#' @export
poll_tracking_check <- function(cp, fits, window = 90L, min_polls = 3L,
                                bound = POLL_TRACKING_BOUND) {
  stopifnot(length(fits) > 0L, window > 0, min_polls >= 1L, bound > 0)
  end_date <- max(cp$date)
  late <- cp$date > end_date - window

  out <- data.table::rbindlist(lapply(names(fits), function(p) {
    # `p` is deliberately not named after any column, and the vector is pulled
    # out with [[ before any data.table subsetting: a bare name matching a
    # column inside dt[...] binds to the column, which this repo has been bitten
    # by five times.
    v <- if (p %in% names(cp)) cp[[p]][late] else rep(NA_real_, sum(late))
    tr <- fits[[p]]$trend
    data.table::data.table(
      party = p,
      fitted = tr$mean[which.max(tr$date)],
      poll_mean = if (any(!is.na(v))) mean(v, na.rm = TRUE) else NA_real_,
      n = sum(!is.na(v)))
  }))

  out[, dev := abs(fitted - poll_mean)]
  out[, asserted := n >= min_polls & is.finite(dev)]
  # NOT `dev > bound` alone. A party with no polls in the window has dev = NA,
  # and NA > bound is NA, which `any()` would swallow and `which()` would drop
  # -- a check that cannot fail on exactly the input it exists to catch. The
  # unasserted rows are surfaced by the caller instead.
  out[, breach := asserted & dev > bound]
  data.table::setattr(out, "bound", bound)
  data.table::setattr(out, "window", window)
  out[order(-dev)]
}

#' Format a poll-tracking result for a check line
#'
#' @param x Result of [poll_tracking_check()].
#' @param code Check code to print, e.g. `"NL3"`.
#' @return The input, invisibly. Called for the printed output.
#' @export
report_poll_tracking <- function(x, code) {
  bound <- attr(x, "bound")
  n_skip <- sum(!x$asserted)
  # If NOTHING is asserted, max() over the empty set is -Inf with a warning and
  # which.max() returns integer(0), which would make the sprintf below fail --
  # or worse, print a triumphant "-Inf" as if the check had passed hardest of
  # all. A cycle with nothing to assert on is a REPORTABLE state, not a pass.
  if (!any(x$asserted)) {
    cat(sprintf("%s  NOT ASSERTED: no party has enough recent polls (%d parties)\n",
                code, nrow(x)))
    return(invisible(x))
  }
  worst <- which.max(replace(x$dev, !x$asserted, NA_real_))
  cat(sprintf("%s  max |fitted - polls(%dd)| = %.2f on %s (require <= %.1f)\n",
              code, attr(x, "window"), x$dev[worst], x$party[worst], bound))
  if (n_skip) {
    # A cycle where most parties are unasserted is a cycle where this check is
    # mostly vacuous. Say so rather than letting it read as a pass.
    cat(sprintf("%s  not asserted on %d of %d parties (too few polls): %s\n",
                code, n_skip, nrow(x), paste(x$party[!x$asserted],
                                             collapse = ", ")))
  }
  if (any(x$breach)) {
    b <- x[breach == TRUE]
    for (i in seq_len(nrow(b))) {
      cat(sprintf("%s  BREACH %s fitted %.2f against %.2f from %d polls\n",
                  code, b$party[i], b$fitted[i], b$poll_mean[i], b$n[i]))
    }
  }
  invisible(x)
}
