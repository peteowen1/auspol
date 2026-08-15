# Per-cycle walk estimation and the over-smoothing detector.
# The failure these exist to catch: a party's walk size learned from cycles
# where it was stable, then applied to a cycle where it moves fast, so the fit
# cannot bend to follow the polls and clips the peak.

test_that("trend_tracking finds no residual structure in a correct fit", {
  syn <- make_synthetic_logit(seed = 101, n_polls = 300, T_days = 600,
                              start_pct = 10, sigma_obs = 0.10, sigma_rw = 0.008)
  fit <- fit_trend(syn$polls, "ALP", prior_result = 10,
                   sigma_obs = 0.10, sigma_rw = 0.008)
  expect_lt(abs(trend_tracking(fit)$acf1), 0.25)
})

test_that("trend_tracking detects a walk that is far too slow", {
  # A steadily climbing party fitted with a walk 20x too small: the fit cannot
  # bend, so it sits below the polls for a long run and then above them.
  syn <- make_synthetic_logit(seed = 103, n_polls = 300, T_days = 600,
                              start_pct = 4, drift = 0.005, sigma_obs = 0.10,
                              sigma_rw = 0.004)
  slow <- fit_trend(syn$polls, "ALP", prior_result = 4,
                    sigma_obs = 0.10, sigma_rw = 0.0002)
  ok <- fit_trend(syn$polls, "ALP", prior_result = 4,
                  sigma_obs = 0.10, sigma_rw = 0.006)
  expect_gt(trend_tracking(slow)$acf1, 0.4)
  expect_lt(abs(trend_tracking(ok)$acf1), 0.25)
  # And the over-smoothed fit visibly clips the peak
  expect_lt(max(slow$trend$mean), max(ok$trend$mean))
})

test_that("peak_polled exceeds peak_fitted when the peak is clipped", {
  syn <- make_synthetic_logit(seed = 105, n_polls = 300, T_days = 600,
                              start_pct = 4, drift = 0.005, sigma_obs = 0.10,
                              sigma_rw = 0.004)
  slow <- fit_trend(syn$polls, "ALP", prior_result = 4,
                    sigma_obs = 0.10, sigma_rw = 0.0002)
  tk <- trend_tracking(slow)
  expect_gt(tk$peak_polled, tk$peak_fitted)
})

test_that("estimate_cycle_walk recovers a fast cycle the pooled value misses", {
  # Pooled value learned from a quiet party; this cycle is far more volatile.
  syn <- make_synthetic_logit(seed = 107, n_polls = 250, T_days = 500,
                              start_pct = 5, drift = 0.004, sigma_obs = 0.10,
                              sigma_rw = 0.010)
  est <- estimate_cycle_sigmas(syn$polls, "ALP", sigma_obs_pooled = 0.10,
                               sigma_rw_pooled = 0.001, prior_result = 5)
  expect_false(est$at_bound)
  expect_gt(est$sigma_rw_raw, 0.004)
  # With 250 polls the cycle's own estimate should dominate the stale pooled one
  expect_gt(est$weight, 0.9)
  expect_gt(est$sigma_rw, 0.004)
})

test_that("estimate_cycle_walk shrinks hard toward pooled on a thin cycle", {
  syn <- make_synthetic_logit(seed = 109, n_polls = 10, T_days = 400,
                              start_pct = 5, sigma_obs = 0.10, sigma_rw = 0.006)
  est <- estimate_cycle_sigmas(syn$polls, "ALP", sigma_obs_pooled = 0.10,
                               sigma_rw_pooled = 0.006, prior_result = 5, k0 = 25)
  expect_lt(est$weight, 0.35)
  expect_gte(est$sigma_rw, min(est$sigma_rw_raw, 0.006))
  expect_lte(est$sigma_rw, max(est$sigma_rw_raw, 0.006))
})

test_that("a stale sigma_obs would push the error into the walk", {
  # Why estimate_cycle_sigmas re-estimates BOTH. If the noise is pinned too
  # low, the walk inflates to absorb the leftover scatter and starts chasing
  # individual polls, which shows up as negative residual autocorrelation.
  syn <- make_synthetic_logit(seed = 117, n_polls = 200, T_days = 500,
                              start_pct = 12, sigma_obs = 0.16, sigma_rw = 0.004)

  # "Pinned" = a stale pooled noise of 0.06 held effectively fixed
  pinned <- estimate_cycle_sigmas(syn$polls, "ALP", sigma_obs_pooled = 0.06,
                                  sigma_rw_pooled = 0.004, prior_result = 12,
                                  lower = c(0.0599, 0.0005),
                                  upper = c(0.0601, 0.25))
  both <- estimate_cycle_sigmas(syn$polls, "ALP", sigma_obs_pooled = 0.16,
                                sigma_rw_pooled = 0.004, prior_result = 12)

  # Pinned at less than half the true noise, the walk must inflate
  expect_gt(pinned$sigma_rw_raw, 2 * both$sigma_rw_raw)
  # Freed, it recovers roughly the generating values
  expect_gt(both$sigma_obs_raw, 0.16 * 0.7)
  expect_lt(both$sigma_obs_raw, 0.16 * 1.3)

  f_pinned <- fit_trend(syn$polls, "ALP", prior_result = 12,
                        sigma_obs = 0.06, sigma_rw = pinned$sigma_rw)
  f_both <- fit_trend(syn$polls, "ALP", prior_result = 12,
                      sigma_obs = both$sigma_obs, sigma_rw = both$sigma_rw)
  expect_lt(trend_tracking(f_pinned)$acf1, -0.25)
  expect_lt(abs(trend_tracking(f_both)$acf1), 0.25)
})

test_that("optim_boxed respects the box and beats a deliberately bad start", {
  # Quadratic with its unconstrained minimum outside the box: the answer must
  # be the boundary, not the free optimum.
  fn <- function(p) sum((p - c(5, 5))^2)
  o <- optim_boxed(c(0, 0), fn, lower = c(-1, -1), upper = c(1, 1))
  expect_true(all(o$par <= 1 + 1e-6) && all(o$par >= -1 - 1e-6))
  expect_lt(abs(o$value - fn(c(1, 1))), 1e-4)
})

test_that("optim_boxed falls back when L-BFGS-B cannot make progress", {
  # A flat plateau with a narrow well: L-BFGS-B's line search stalls on the
  # plateau, which is the shape that produced convergence code 52 on real
  # federal data.
  fn <- function(p) if (max(abs(p)) > 0.5) 10 else sum(p^2)
  o <- optim_boxed(c(2, 2), fn, lower = c(-3, -3), upper = c(3, 3))
  expect_lte(o$value, 10)
  expect_true(is.finite(o$value))
  expect_true(o$method %in% c("L-BFGS-B", "L-BFGS-B(restart)", "Nelder-Mead"))
})

test_that("estimate_cycle_sigmas floors noise at the binomial bound", {
  syn <- make_synthetic_logit(seed = 121, n_polls = 200, T_days = 400,
                              start_pct = 20, sigma_obs = 0.01, sigma_rw = 0.004)
  floor_val <- binomial_sd_link(20, 2500, "logit")
  est <- estimate_cycle_sigmas(syn$polls, "ALP", sigma_obs_pooled = 0.05,
                               sigma_rw_pooled = 0.004, prior_result = 20,
                               sigma_obs_floor = floor_val)
  expect_true(est$floored)
  expect_equal(est$sigma_obs, floor_val)

  # Without a floor the sub-binomial estimate comes through untouched
  est2 <- estimate_cycle_sigmas(syn$polls, "ALP", sigma_obs_pooled = 0.05,
                                sigma_rw_pooled = 0.004, prior_result = 20)
  expect_false(est2$floored)
  expect_lt(est2$sigma_obs, floor_val)
})

test_that("per-cycle walk removes the tracking failure a stale walk creates", {
  # The end-to-end claim: estimating the walk on the cycle in question fixes
  # the flattening that a stale pooled walk produces, and recovers the peak.
  syn <- make_synthetic_logit(seed = 113, n_polls = 250, T_days = 500,
                              start_pct = 4, drift = 0.005, sigma_obs = 0.10,
                              sigma_rw = 0.004)
  pooled_rw <- 0.0002                      # learned from a quiet era
  before <- fit_trend(syn$polls, "ALP", prior_result = 4,
                      sigma_obs = 0.10, sigma_rw = pooled_rw)
  est <- estimate_cycle_sigmas(syn$polls, "ALP", sigma_obs_pooled = 0.10,
                               sigma_rw_pooled = pooled_rw, prior_result = 4)
  after <- fit_trend(syn$polls, "ALP", prior_result = 4,
                     sigma_obs = est$sigma_obs, sigma_rw = est$sigma_rw)
  expect_gt(trend_tracking(before)$acf1, 0.4)
  expect_lt(abs(trend_tracking(after)$acf1), 0.25)
  expect_gt(max(after$trend$mean), max(before$trend$mean))
})
