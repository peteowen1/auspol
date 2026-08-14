# Pre-registered recovery checks (H5 from session notes): marginal-likelihood
# estimation must recover known sigmas from data the model generated itself,
# and per-firm noise factors must separate a noisy firm from a quiet one.

test_that("estimate_trend_sigmas recovers known sigmas within 30%", {
  # More polls than the real-data case so the evidence surface is informative
  syn <- make_synthetic(seed = 7, n_polls = 400, T_days = 700,
                        sigma_obs = 2.0, sigma_rw = 0.15)
  est <- estimate_trend_sigmas(list(syn$polls), "ALP", prior_results = 35)

  expect_equal(est$convergence, 0)
  expect_false(est$at_bound)
  expect_gt(est$sigma_obs, 2.0 * 0.7); expect_lt(est$sigma_obs, 2.0 * 1.3)
  expect_gt(est$sigma_rw, 0.15 * 0.7); expect_lt(est$sigma_rw, 0.15 * 1.3)
  # Optimum can't be worse than the (wrong) starting values
  expect_gte(est$logml, est$logml0)
})

test_that("logml prefers the generating sigmas over badly wrong ones", {
  syn <- make_synthetic(seed = 11, n_polls = 300, T_days = 600,
                        sigma_obs = 1.5, sigma_rw = 0.10)
  prep <- prep_trend_obs(syn$polls, "ALP", 3)
  anchor <- trend_anchor(prep, 35)
  ml_true <- trend_solve(prep, 1.5, 0.10, 3, anchor, want_var = FALSE)$logml
  ml_obs_off <- trend_solve(prep, 3.5, 0.10, 3, anchor, want_var = FALSE)$logml
  ml_rw_off <- trend_solve(prep, 1.5, 0.55, 3, anchor, want_var = FALSE)$logml
  expect_gt(ml_true, ml_obs_off)
  expect_gt(ml_true, ml_rw_off)
})

test_that("estimate_firm_factors separates a noisy firm from a quiet one", {
  syn <- make_synthetic(seed = 3, n_polls = 450, T_days = 700,
                        sigma_obs = 1.5, sigma_rw = 0.08,
                        firm_noise = c(A = 2.0, B = 1.0, C = 0.6))
  fit <- fit_trend(syn$polls, "ALP", prior_result = 35,
                   sigma_obs = 1.5, sigma_rw = 0.08)
  fac <- estimate_firm_factors(list(fit))

  f <- setNames(fac$factor, fac$firm)
  expect_gt(f["A"], f["B"])
  expect_gt(f["B"], f["C"])
  expect_gt(f["A"], 1.3)   # genuinely flagged as noisy
  expect_lt(f["C"], 0.95)  # genuinely flagged as quiet
  expect_true(all(fac$factor >= 0.6 & fac$factor <= 2.0))
})

test_that("estimate_trend_sigmas drops thin cycles and errors when none remain", {
  syn <- make_synthetic(seed = 5, n_polls = 15)
  expect_error(estimate_trend_sigmas(list(syn$polls), "ALP"), "polls")
})
