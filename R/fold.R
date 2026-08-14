# Parties folded into "Others" ------------------------------------------
#
# Not every poll reports every party separately. When a pollster does not name
# One Nation, its supporters do not vanish — they land in the "Others" line.
# The tell is arithmetic: the reported first preferences still sum to about
# 100, so the missing party must be inside one of the reported categories.
#
# Measured federally, within the SAME firm (so this is not a house effect):
#
#   firm       mean OTH when ONP reported   when not
#   Essential                        8.5       17.6
#   Redbridge                        9.9       18.1
#   Freshwater                       9.1       15.8
#   Morgan                          12.4       17.9
#
# Left uncorrected this inflates the Others trend, and Others carries a
# preference flow into two-party-preferred, so it moves the headline number.
# It matters more in the states: only 18 of 53 Victorian polls in the 2026
# cycle name One Nation at all.
#
# The correction follows the anchor model: impute the missing party's share
# from its own fitted trend and subtract it from Others. The imputed value is
# NOT written back as an observation of that party — it carries no new
# information about it, and feeding a trend its own output would be circular.
# Only Others is corrected.

#' Polls where a modelled party is missing but its votes are inside "Others"
#'
#' Identified arithmetically rather than assumed: a poll whose reported first
#' preferences already sum to ~100 without party `p` must be carrying `p`
#' inside one of its reported categories. A poll that simply omits `p` without
#' absorbing it sums to roughly `100 - p` instead and is left alone.
#'
#' @param polls A cycle's polls from [cycle_polls()].
#' @param party The modelled party that may be folded away.
#' @param sum_range Reported-FP total that counts as "already complete".
#' @param oth Name of the residual column.
#' @return Logical vector, one per poll row.
#' @export
folded_rows <- function(polls, party, sum_range = c(97, 103), oth = "OTH") {
  parties <- attr(polls, "parties")
  stopifnot(party %in% parties, oth %in% names(polls))
  fp <- as.matrix(polls[, parties, with = FALSE])
  totals <- rowSums(fp, na.rm = TRUE)
  is.na(polls[[party]]) & !is.na(polls[[oth]]) &
    totals >= sum_range[1] & totals <= sum_range[2]
}

#' Subtract a folded party's imputed share from "Others"
#'
#' @param polls A cycle's polls from [cycle_polls()].
#' @param fits Named list from [fit_cycle_trends()]; supplies the trend used
#'   to impute each folded party.
#' @param parties Parties to check; default every fitted party that is neither
#'   a major nor the residual category.
#' @param oth Name of the residual column.
#' @param min_oth Floor for the corrected residual, in percent. Hitting it
#'   means the imputation exceeded the whole Others line, which is a modelling
#'   failure rather than something to silently clamp — it warns.
#' @param buffer_days How far outside a party's observed date range the
#'   correction may still be applied.
#' @return A copy of `polls` with `oth` corrected, carrying attributes
#'   `folded` (what was subtracted where) and `fold_skipped` (rows that looked
#'   folded but fell outside the observed window).
#' @export
unfold_others <- function(polls, fits, parties = NULL, oth = "OTH",
                          min_oth = 0.5, buffer_days = 60) {
  out <- data.table::copy(polls)
  majors <- c("ALP", "LNP", "LIB", "NAT")
  if (is.null(parties)) {
    parties <- setdiff(names(fits), c(majors, oth))
  }
  # Every mask is computed against the ORIGINAL polls, before any subtraction.
  # Detection is arithmetic — "do the reported shares already sum to ~100?" —
  # so correcting one party first would drop the total below the window and
  # hide any second folded party. A poll that omits both One Nation and UAP is
  # the common case federally, and sequential detection silently corrected
  # only the first of them.
  hits <- lapply(parties, function(p) {
    if (is.null(fits[[p]])) return(logical(nrow(polls)))
    folded_rows(polls, p, oth = oth)
  })
  names(hits) <- parties

  log <- list(); skipped <- list()
  for (p in parties) {
    if (is.null(fits[[p]])) next
    hit <- hits[[p]]
    if (!any(hit)) next

    # Only correct where the party was actually MEASURED. Outside its observed
    # window the "trend" is prior-driven interpolation carrying no information
    # about that date, and subtracting it invents vote share.
    #
    # NSW 2027 is the case that forced this. Its 20 folding polls run
    # 2023-05 to 2026-01, but One Nation is only observed from 2025-12. In
    # 2023-24 it polled ~2% in NSW, so those Others values of 15-22 are
    # genuine independents. Imputing from the trend subtracted ~13 points of
    # phantom One Nation and crushed Others to ~6, which the fitted-shares
    # sum check (L3) caught by falling to 95.
    obs_dates <- fits[[p]]$residuals$date
    lo <- min(obs_dates) - buffer_days
    hi <- max(obs_dates) + buffer_days
    outside <- hit & (polls$date < lo | polls$date > hi)
    if (any(outside)) {
      skipped[[p]] <- data.table::data.table(
        party = p, date = polls$date[outside], firm = polls$firm[outside],
        oth = polls[[oth]][outside]
      )
      hit <- hit & !outside
    }
    if (!any(hit)) next
    tr <- fits[[p]]$trend
    # A folded party's trend only spans dates where SOME firm reported it, so
    # polls after the last such date have no fitted value to read. Carry the
    # endpoint forward rather than skipping them: the posterior mean of a
    # random walk beyond its last observation is flat, so the endpoint IS the
    # expectation there. Skipping instead leaves those polls inflated, which
    # is the bug this function exists to fix.
    d <- pmin(pmax(out$date[hit], min(tr$date)), max(tr$date))
    imputed <- tr$mean[match(d, tr$date)]
    ok <- !is.na(imputed)
    idx <- which(hit)[ok]
    imputed <- imputed[ok]
    if (!length(idx)) next

    before <- out[[oth]][idx]
    after <- before - imputed
    short <- after < min_oth
    if (any(short)) {
      warning(sprintf(
        "%s: imputed share exceeds the %s line in %d poll(s); clamped to %.1f",
        p, oth, sum(short), min_oth))
      after[short] <- min_oth
    }
    out[[oth]][idx] <- after
    log[[p]] <- data.table::data.table(
      party = p, date = out$date[idx], firm = out$firm[idx],
      oth_before = before, imputed = imputed, oth_after = after
    )
  }
  for (a in c("parties", "region", "cycle_year", "cycle_start", "cycle_end")) {
    data.table::setattr(out, a, attr(polls, a))
  }
  data.table::setattr(out, "folded", data.table::rbindlist(log))
  data.table::setattr(out, "fold_skipped", data.table::rbindlist(skipped))
  out
}

#' Fit a cycle, correcting parties folded into "Others" as it goes
#'
#' Chicken-and-egg: imputing a folded party needs its trend, and its trend is
#' cleaner once Others is corrected. So fit, correct, refit, and repeat until
#' the correction stops moving. Convergence is fast (the correction is a
#' smooth function of a smooth trend) — `max_iter` is a backstop, and failing
#' to converge warns rather than passing silently.
#'
#' @inheritParams fit_cycle_trends
#' @param tol Convergence threshold: largest change in any corrected Others
#'   value between iterations, in percentage points.
#' @param max_iter Iteration cap.
#' @param verbose Report each iteration's movement.
#' @return As [fit_cycle_trends_guarded()], with attributes `polls_corrected`
#'   (the adjusted polls), `folded` (what was subtracted) and `iterations`.
#' @export
fit_cycle_unfolded <- function(polls, parties = NULL, priors = NULL,
                               overrides = list(), tol = 0.05, max_iter = 10L,
                               verbose = TRUE, ...) {
  cur <- polls
  fits <- fit_cycle_trends_guarded(cur, parties, priors, overrides,
                                   verbose = verbose, ...)
  prev_oth <- NULL
  iter <- 0L
  for (i in seq_len(max_iter)) {
    iter <- i
    cur <- unfold_others(polls, fits)     # always correct from the ORIGINAL
    delta <- if (is.null(prev_oth)) Inf else max(abs(cur$OTH - prev_oth), na.rm = TRUE)
    prev_oth <- cur$OTH
    fits <- fit_cycle_trends_guarded(cur, parties, priors, overrides,
                                     verbose = FALSE, ...)
    if (verbose) {
      message(sprintf("  unfold iteration %d: max change in OTH = %s pts",
                      i, if (is.finite(delta)) sprintf("%.4f", delta) else "-"))
    }
    if (is.finite(delta) && delta < tol) break
  }
  if (iter == max_iter) {
    warning("unfold did not converge in ", max_iter, " iterations")
  }
  data.table::setattr(fits, "polls_corrected", cur)
  data.table::setattr(fits, "folded", attr(cur, "folded"))
  data.table::setattr(fits, "fold_skipped", attr(cur, "fold_skipped"))
  data.table::setattr(fits, "iterations", iter)
  fits
}
