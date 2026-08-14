#' Estimate sigma_obs and sigma_rw for one party by marginal likelihood
#'
#' The Gaussian-exact trend model has an exact evidence (see [fit_trend()]'s
#' internals), so the two variance hyperparameters can be estimated by
#' maximising log marginal likelihood — no cross-validation, no MCMC. When
#' several cycles are supplied the log evidences are summed, i.e. one
#' (sigma_obs, sigma_rw) pair is assumed to hold across cycles; estimate from
#' PAST (completed) cycles and apply to the live one.
#'
#' Optimisation is L-BFGS-B on the log scale. Hitting a box bound is reported
#' via `at_bound` — treat that as "the method is wrong", not as an estimate.
#'
#' @param polls_list List of cycle polls (each from [cycle_polls()]).
#' @param party Party column name.
#' @param prior_results Numeric vector of day-0 anchors, one per cycle
#'   (NA = anchor loosely to first poll).
#' @param sigma_house,min_firm_polls,firm_factors As in [fit_trend()].
#' @param min_polls Cycles where the party has fewer polls than this are
#'   dropped (too little data to inform the sigmas).
#' @param start Starting values c(sigma_obs, sigma_rw); also the reference
#'   point for `logml0`.
#' @param lower,upper Box bounds c(sigma_obs, sigma_rw), in points.
#' @return List: `sigma_obs`, `sigma_rw`, `logml` (at optimum), `logml0`
#'   (at the starting values, for a monotonicity sanity check), `n_cycles`,
#'   `n_polls`, `at_bound`, `convergence` (0 = optim converged).
#' @export
estimate_trend_sigmas <- function(polls_list, party, prior_results = NULL,
                                  sigma_house = 3, min_firm_polls = 3,
                                  firm_factors = NULL, min_polls = 25,
                                  start = c(1.7, 0.10),
                                  lower = c(0.5, 0.015),
                                  upper = c(4.0, 0.60)) {
  if (is.null(prior_results)) prior_results <- rep(NA_real_, length(polls_list))
  stopifnot(length(prior_results) == length(polls_list))

  preps <- list(); anchors <- list()
  for (i in seq_along(polls_list)) {
    n_avail <- sum(!is.na(polls_list[[i]][[party]]))
    if (n_avail < min_polls) next
    prep <- prep_trend_obs(polls_list[[i]], party, min_firm_polls)
    preps[[length(preps) + 1L]] <- prep
    anchors[[length(preps)]] <- trend_anchor(prep, prior_results[i])
  }
  if (!length(preps)) stop("No cycle has >= ", min_polls, " polls for ", party)

  total_logml <- function(log_par) {
    s_obs <- exp(log_par[1]); s_rw <- exp(log_par[2])
    sum(vapply(seq_along(preps), function(i) {
      trend_solve(preps[[i]], s_obs, s_rw, sigma_house, anchors[[i]],
                  firm_factors = firm_factors, want_var = FALSE)$logml
    }, numeric(1)))
  }

  logml0 <- total_logml(log(start))
  opt <- stats::optim(log(start), function(p) -total_logml(p),
                      method = "L-BFGS-B", lower = log(lower), upper = log(upper))
  est <- exp(opt$par)
  tol <- 1e-3
  at_bound <- any(est <= lower * (1 + tol)) || any(est >= upper * (1 - tol))

  list(
    sigma_obs = est[1], sigma_rw = est[2],
    logml = -opt$value, logml0 = logml0,
    n_cycles = length(preps),
    n_polls = sum(vapply(preps, function(p) nrow(p$obs), 1L)),
    at_bound = at_bound, convergence = opt$convergence
  )
}

#' Per-pollster noise factors from pooled standardised residuals
#'
#' Empirical-Bayes second stage: pool each firm's poll residuals across the
#' supplied fits (all parties, all cycles — noisiness is a property of the
#' firm's methodology, not of one party's series), standardise by each fit's
#' sigma_obs, normalise so the poll-weighted average squared residual is 1
#' (the fitted trend absorbs some noise, so raw standardised residuals sit
#' below 1), then shrink each firm's variance ratio toward 1 with prior
#' weight `k0` pseudo-polls. Approximate — the exact route is per-firm sigmas
#' inside the marginal likelihood — but cheap and stable.
#'
#' @param fits List of [fit_trend()] results (nest freely; flattened on
#'   `residuals` presence).
#' @param k0 Shrinkage prior weight in pseudo-polls.
#' @param clip Factors are clipped to this range.
#' @return data.table: `firm`, `n` (residuals pooled), `raw_ratio`
#'   (normalised variance ratio), `factor` (sd multiplier, shrunk + clipped).
#'   Pass `setNames(out$factor, out$firm)` as `firm_factors` to [fit_trend()].
#' @export
estimate_firm_factors <- function(fits, k0 = 12, clip = c(0.6, 2.0)) {
  flatten <- function(x) {
    if (is.list(x) && !is.null(x$residuals)) return(list(x))
    if (is.list(x)) return(do.call(c, lapply(x, flatten)))
    list()
  }
  fl <- flatten(fits)
  if (!length(fl)) stop("No fit_trend results found in `fits`")

  z <- data.table::rbindlist(lapply(fl, function(f) {
    data.table::data.table(firm = f$residuals$firm,
                           z2 = (f$residuals$resid / f$meta$sigma_obs)^2)
  }))
  # Normalise: trend shrinkage deflates all residuals; only ratios are meaningful
  z[, z2 := z2 / mean(z2)]
  out <- z[, .(n = .N, raw_ratio = mean(z2)), by = firm]
  out[, factor := sqrt((n * raw_ratio + k0) / (n + k0))]
  out[, factor := pmin(pmax(factor, clip[1]), clip[2])]
  out[order(-factor)]
}
