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
#' the historical record of cycles with complete actuals, rounded up to the
#' nearest 0.5. Computed by `scripts/calibrate_poll_tracking.R`: 154
#' party-cycles over 33 cycles, percentile 2.429, one historical row breaching
#' (Victoria 1992 ALP at 5.05).
#'
#' Calibrated on the SAME model path the checks assert on -- per-cycle sigmas
#' and per-pollster noise factors -- after review caught that the first
#' derivation used `trend_as_at()` defaults instead, which is a different model
#' path this repo's CLAUDE.md says must be distinguished. Correcting it moved
#' the percentile from 2.478 to 2.429 and left the bound unchanged at 2.5. That
#' the answer did not move is not a reason the mismatch was harmless: it was
#' found by review, not by the plan, and three cycles compared by hand had
#' suggested a ratio of 1.6-3.1x. Those were maxima of very small deviations,
#' where a ratio is noise.
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

  # Iterate the UNION of fitted parties and polled parties, not just the fitted
  # ones. A party that the fit dropped -- for falling under a script's
  # `n >= 8` / `n >= 25` inclusion floor -- would otherwise have no row at all:
  # not "unasserted", simply absent, with nothing anywhere saying a polled party
  # vanished. That is the failure mode the old SUM check could catch and this
  # one could not, and it is one poll away from happening: One Nation has
  # exactly 8 polls in the NSW 2027 cycle against an inclusion floor of 8.
  #
  # The poll table's own `parties` attribute, NOT names(cp): the columns include
  # `date` and `firm`, and sweeping those in would try to subtract a Date from a
  # number. If the attribute is missing there is no way to know which columns are
  # parties, so fall back to the fitted set and say so -- silently losing
  # dropped-party detection is the exact failure this block exists to prevent.
  declared <- attr(cp, "parties")
  if (is.null(declared)) {
    warning("poll table has no `parties` attribute; a party dropped from the ",
            "fit cannot be detected", call. = FALSE)
    declared <- character(0)
  }
  polled <- intersect(declared, names(cp))
  all_parties <- union(names(fits), polled)

  out <- data.table::rbindlist(lapply(all_parties, function(p) {
    # `p` is deliberately not named after any column, and the vector is pulled
    # out with [[ before any data.table subsetting: a bare name matching a
    # column inside dt[...] binds to the column, which this repo has been bitten
    # by five times.
    v <- if (p %in% names(cp)) cp[[p]][late] else rep(NA_real_, max(sum(late), 0L))
    tr <- if (!is.null(fits[[p]])) fits[[p]]$trend else NULL
    # A fit whose trend has no rows would make `fitted` a zero-length value and
    # rbindlist would drop the party silently -- the same invisibility again,
    # arriving from the other direction. Force it to NA so the row survives and
    # shows up as unfitted.
    fit_end <- if (!is.null(tr) && nrow(tr) > 0L) {
      tr$mean[which.max(tr$date)]
    } else NA_real_
    data.table::data.table(
      party = p,
      fitted = as.numeric(fit_end)[1],
      poll_mean = if (any(!is.na(v))) mean(v, na.rm = TRUE) else NA_real_,
      n = sum(!is.na(v)),
      fitted_ok = !is.null(tr) && nrow(tr) > 0L)
  }))

  out[, dev := abs(fitted - poll_mean)]
  # A party polled often enough to be checked but MISSING from the fit is a
  # breach in its own right, not an unasserted row. Something the polls measure
  # is not in the model, and every downstream number is computed without it.
  # A party that refold_unfitted() has already folded back into OTH is NOT a
  # breach. The breach exists to say "the polls measure something the model does
  # not account for", and refolding accounts for it: OTH now means one thing
  # across the cycle and carries that party's vote coherently. Still reported,
  # because a party absent from the model matters for anything seat-level.
  refolded <- attr(cp, "refolded")
  handled <- if (!is.null(refolded) && nrow(refolded)) unique(refolded$party) else character(0)
  out[, refolded_in := party %in% handled]
  out[, dropped := n >= min_polls & !fitted_ok & !refolded_in]
  out[, asserted := n >= min_polls & is.finite(dev)]
  # NOT `dev > bound` alone. A party with no polls in the window has dev = NA,
  # and NA > bound is NA, which `any()` would swallow and `which()` would drop
  # -- a check that cannot fail on exactly the input it exists to catch. The
  # unasserted rows are surfaced by the caller instead.
  out[, breach := dropped | (asserted & dev > bound)]
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
  if (any(x$refolded_in & !x$fitted_ok)) {
    r <- x[refolded_in == TRUE & fitted_ok == FALSE]
    for (i in seq_len(nrow(r))) {
      cat(sprintf("%s  %s not fitted, but folded back into OTH -- accounted for\n",
                  code, r$party[i]))
    }
  }
  if (any(x$dropped)) {
    d <- x[dropped == TRUE]
    for (i in seq_len(nrow(d))) {
      # Deliberately not "its vote is missing". It is not: an unfitted party's
      # support stays inside OTH, and where the recorded result has no separate
      # line for that party either, OTH is the correct target. What IS wrong is
      # that OTH then mixes firms that break the party out with firms that fold
      # it in, and unfold_others() cannot reconcile them without a fitted trend
      # to impute from. Measured on NSW 2023: OTH fitted at 15.30 against an
      # actual of 17.96, with the definitional gap showing up as a Morgan house
      # effect of -0.28 rather than as the ~5 points it really is.
      cat(sprintf(paste0("%s  BREACH %s polled (%d in window, mean %.2f) but not ",
                         "fitted:\n           OTH absorbs it, and no fold ",
                         "correction can run on it\n"),
                  code, d$party[i], d$n[i], d$poll_mean[i]))
    }
  }
  if (any(x$breach & !x$dropped)) {
    b <- x[breach == TRUE & dropped == FALSE]
    for (i in seq_len(nrow(b))) {
      cat(sprintf("%s  BREACH %s fitted %.2f against %.2f from %d polls\n",
                  code, b$party[i], b$fitted[i], b$poll_mean[i], b$n[i]))
    }
  }
  invisible(x)
}
