# Projection --------------------------------------------------------------
#
# The trend says where opinion is now. The fundamentals say where the result
# usually lands given a party's history and position. A forecast needs both,
# weighted by how far out we are: far from an election the polls carry little
# information about the result, and close to it they carry most of it.
#
# Following the anchor's stage 3, minus two refinements not implemented yet:
# no separate bias correction per horizon, and the error distribution is
# symmetric rather than split by sign with kurtosis.
#
# The one thing done carefully is avoiding leakage. The trend value at a given
# horizon MUST be refitted using only polls published by then. Reading a
# smoothed trend that was fitted on the whole cycle at an earlier date leaks
# later polls backwards and would make long horizons look far better than they
# are.

#' Trend-derived ALP two-party share as it would have looked on a given date
#'
#' Refits from scratch on polls up to `as_at` only.
#'
#' @param polls All polls for a region, from [load_polls()].
#' @param year,cycles Cycle identifiers.
#' @param as_at Only polls on or before this date are used.
#' @param priors Named vector of previous-election results.
#' @param flows Preference flows for the cycle, from [flows_for()].
#' @param min_polls Minimum polls for a party to be fitted.
#' @param nu Student-t degrees of freedom for the observation model, passed to
#'   [fit_trend()]; `Inf` is the Gaussian fit.
#' @return List: `tpp`, `fp` (named vector), `n_polls`; or NULL if too thin.
#' @export
trend_as_at <- function(polls, year, cycles, as_at, priors, flows,
                        min_polls = 8, nu = Inf) {
  cp <- cycle_polls(polls, year, cycles)
  keep <- cp$date <= as_at
  cp2 <- cp[which(keep), ]
  for (a in c("parties", "region", "cycle_year", "cycle_start")) {
    data.table::setattr(cp2, a, attr(cp, a))
  }
  # The cycle is truncated at the cutoff, so the trend ends there rather than
  # running on to election day with nothing to inform it.
  data.table::setattr(cp2, "cycle_end", as_at)
  if (nrow(cp2) < min_polls) return(NULL)

  cnt <- vapply(attr(cp2, "parties"), function(p) sum(!is.na(cp2[[p]])), 1L)
  ps <- names(cnt)[cnt >= min_polls]
  if (!("ALP" %in% ps)) return(NULL)

  fits <- tryCatch(
    fit_cycle_trends(cp2, parties = ps,
                     priors = priors[intersect(names(priors), ps)],
                     nu = nu),
    error = function(e) NULL)
  if (is.null(fits)) return(NULL)
  if (any(vapply(fits, function(f) !all(is.finite(f$trend$mean)), TRUE))) {
    return(NULL)
  }

  tpp <- tryCatch(derive_tpp(fits, flows), error = function(e) NULL)
  if (is.null(tpp)) return(NULL)
  end_of <- function(tr) tr$mean[which.max(tr$date)]
  list(tpp = end_of(tpp),
       fp = vapply(fits, function(f) end_of(f$trend), numeric(1)),
       n_polls = nrow(cp2))
}

#' Assemble trend-at-horizon against eventual result, across past elections
#'
#' @param horizons Days before the election at which to evaluate the trend.
#' @param regions Regions to include.
#' @param min_year Earliest election year.
#' @param min_polls Minimum polls needed at a horizon.
#' @param nu Student-t degrees of freedom, passed through to [trend_as_at()].
#' @param verbose Print progress (this is the slow step).
#' @return data.table: `year`, `region`, `horizon`, `trend_tpp`, `actual_tpp`,
#'   `n_polls`.
#' @export
build_projection_data <- function(horizons = c(30, 90, 180, 365, 730),
                                  regions = c("fed", "nsw", "vic", "qld"),
                                  min_year = 1990, min_polls = 8,
                                  nu = Inf, verbose = TRUE) {
  cycles <- load_election_cycles()
  ev <- load_eventual_results()
  pol <- load_polled_elections()
  pri_all <- load_prior_results()
  flows_all <- load_preference_flows()

  out <- list()
  for (rg in regions) {
    polls <- tryCatch(suppressMessages(load_polls(rg)), error = function(e) NULL)
    if (is.null(polls)) next
    keep <- pol$region == rg & pol$year >= min_year
    years <- sort(pol$year[which(keep)])
    for (y in years) {
      krow <- cycles$region == rg & cycles$year == y
      if (!any(krow)) next
      cyc <- cycles[which(krow), ]
      ka <- ev$region == rg & ev$year == y & ev$party == "@TPP"
      if (!any(ka)) next
      actual <- ev$actual[which(ka)][1]

      kp <- pri_all$region == rg & pri_all$year == y
      pr <- pri_all[which(kp), ]
      priors <- stats::setNames(pr$prev1, pr$party)
      fl <- tryCatch(flows_for(flows_all, y, rg, quiet = TRUE),
                     error = function(e) NULL)
      if (is.null(fl)) next

      for (h in horizons) {
        as_at <- cyc$end[1] - h
        if (as_at <= cyc$start[1]) next
        r <- tryCatch(trend_as_at(polls, y, cycles, as_at, priors, fl,
                                  min_polls = min_polls, nu = nu),
                      error = function(e) NULL)
        if (is.null(r)) next
        out[[length(out) + 1L]] <- data.table::data.table(
          year = y, region = rg, horizon = h, trend_tpp = r$tpp,
          actual_tpp = actual, n_polls = r$n_polls)
      }
      if (verbose) message(sprintf("  %s %d done", rg, y))
    }
  }
  data.table::rbindlist(out)
}

#' Optimal trend-versus-fundamentals weight at each horizon
#'
#' For each horizon, finds the weight `w` minimising mean absolute error of
#' `w * trend + (1 - w) * fundamentals`, and measures the spread of the
#' resulting errors so a band can be attached.
#'
#' The fundamentals prediction MUST be the leave-one-out one, or the mix is
#' fitted against a fundamentals number that has already seen the election it
#' is being scored on, which biases the weight toward fundamentals.
#'
#' @param dat From [build_projection_data()], with a `fund_tpp` column of
#'   leave-one-out fundamentals predictions.
#' @param w_grid Candidate weights.
#' @return data.table: one row per horizon with `w`, `mae_mix`, `mae_trend`,
#'   `mae_fund`, `sd_err`, `n`.
#' @export
fit_projection_mix <- function(dat, w_grid = seq(0, 1, by = 0.01)) {
  stopifnot("fund_tpp" %in% names(dat))
  hs <- sort(unique(dat$horizon))
  data.table::rbindlist(lapply(hs, function(h) {
    d <- dat[which(dat$horizon == h & !is.na(dat$fund_tpp)), ]
    if (nrow(d) < 5) return(NULL)
    mae_at <- function(w, rows) mean(abs(
      w * d$trend_tpp[rows] + (1 - w) * d$fund_tpp[rows] - d$actual_tpp[rows]))
    maes <- vapply(w_grid, mae_at, numeric(1), rows = seq_len(nrow(d)))
    k <- which.min(maes)
    w <- w_grid[k]
    err <- w * d$trend_tpp + (1 - w) * d$fund_tpp - d$actual_tpp

    # `mae_mix` is optimistic: the weight was chosen on these same elections,
    # and because the grid spans 0 to 1 it can never lose to trend-only or
    # fundamentals-only. The honest number re-picks the weight with each
    # election held out.
    loo_err <- vapply(seq_len(nrow(d)), function(i) {
      rest <- setdiff(seq_len(nrow(d)), i)
      wi <- w_grid[which.min(vapply(w_grid, mae_at, numeric(1), rows = rest))]
      wi * d$trend_tpp[i] + (1 - wi) * d$fund_tpp[i] - d$actual_tpp[i]
    }, numeric(1))

    data.table::data.table(
      horizon = h, n = nrow(d), w = w, mae_mix = maes[k],
      mae_mix_loo = mean(abs(loo_err)),
      mae_trend = mean(abs(d$trend_tpp - d$actual_tpp)),
      mae_fund = mean(abs(d$fund_tpp - d$actual_tpp)),
      bias = mean(err), sd_err = stats::sd(err))
  }))
}

#' Interpolate the fitted mix weight and error spread to any horizon
#'
#' Linear in log-horizon, clamped at the ends of the fitted range. The anchor
#' smooths these parameters heavily across horizons; this is the simple
#' version of the same idea, and it stops a live forecast depending on which
#' grid point happened to be nearest.
#'
#' @param mix From [fit_projection_mix()].
#' @param horizon Days until the election.
#' @return List: `w`, `sd_err`, `bias`.
#' @export
projection_params <- function(mix, horizon) {
  m <- mix[order(mix$horizon), ]
  lh <- log(pmax(horizon, 1))
  grid <- log(m$horizon)
  interp <- function(v) {
    if (nrow(m) == 1) return(v[1])
    stats::approx(grid, v, xout = lh, rule = 2)$y
  }
  list(w = interp(m$w), sd_err = interp(m$sd_err), bias = interp(m$bias))
}

#' Project an election-day result from a trend value and fundamentals
#'
#' @param trend_value,fund_value Current trend estimate and fundamentals
#'   prediction, in percent.
#' @param mix From [fit_projection_mix()].
#' @param horizon Days until the election.
#' @return List: `mean`, `sd`, `lo95`, `hi95`, `w`.
#' @export
project_result <- function(trend_value, fund_value, mix, horizon) {
  p <- projection_params(mix, horizon)
  mu <- p$w * trend_value + (1 - p$w) * fund_value - p$bias
  list(mean = mu, sd = p$sd_err, w = p$w,
       lo95 = mu - 1.96 * p$sd_err, hi95 = mu + 1.96 * p$sd_err)
}
