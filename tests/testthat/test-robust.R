# Student-t observation noise, fitted by reweighting the exact Gaussian solve.
# What it fixes: individual rogue polls. What it does NOT fix: every pollster
# being wrong the same way, which is a correlated error, not an outlier.

test_that("nu = Inf leaves the Gaussian fit bit-for-bit unchanged", {
  syn <- make_synthetic_logit(seed = 201, n_polls = 150, start_pct = 12)
  a <- fit_trend(syn$polls, "ALP", prior_result = 12)
  b <- fit_trend(syn$polls, "ALP", prior_result = 12, nu = Inf)
  expect_equal(a$trend$mean, b$trend$mean)
  expect_equal(a$house_effects$effect, b$house_effects$effect)
  expect_equal(b$meta$nu_iters, 0L)
  expect_true(all(b$residuals$weight == 1))
})

test_that("robust_weights discounts by size of residual, not by disagreement", {
  z <- c(0, 1, 2, 3, 5, 10)
  w <- robust_weights(z, nu = 4)
  expect_equal(w[1], 1.25)                    # (nu+1)/nu at zero residual
  expect_true(all(diff(w) < 0))               # monotonically decreasing
  expect_lt(w[6] / w[1], 0.1)                 # a 10-sd poll is nearly ignored
  expect_true(all(robust_weights(z, Inf) == 1))
})

test_that("a rogue poll moves the Gaussian fit but not the robust one", {
  syn <- make_synthetic_logit(seed = 203, n_polls = 120, T_days = 400,
                              start_pct = 30, sigma_obs = 0.06, sigma_rw = 0.004)
  clean <- syn$polls
  dirty <- data.table::copy(clean)
  for (a in c("parties", "region", "cycle_year", "cycle_start", "cycle_end")) {
    data.table::setattr(dirty, a, attr(clean, a))
  }
  # One wildly wrong poll near the end of the cycle
  k <- which.max(dirty$date)
  dirty$ALP[k] <- dirty$ALP[k] + 20

  end_of <- function(f) f$trend$mean[which.max(f$trend$date)]
  g_clean <- end_of(fit_trend(clean, "ALP", prior_result = 30))
  g_dirty <- end_of(fit_trend(dirty, "ALP", prior_result = 30))
  t_dirty <- end_of(fit_trend(dirty, "ALP", prior_result = 30, nu = 4))

  expect_gt(abs(g_dirty - g_clean), 0.5)           # Gaussian is dragged
  expect_lt(abs(t_dirty - g_clean), abs(g_dirty - g_clean))   # t is dragged less
})

test_that("the robust fit recovers the truth better under contamination", {
  syn <- make_synthetic_logit(seed = 207, n_polls = 200, T_days = 500,
                              start_pct = 20, sigma_obs = 0.07, sigma_rw = 0.005)
  d <- data.table::copy(syn$polls)
  for (a in c("parties", "region", "cycle_year", "cycle_start", "cycle_end")) {
    data.table::setattr(d, a, attr(syn$polls, a))
  }
  set.seed(11)
  bad <- sample(nrow(d), 12)                 # 6% contamination
  d$ALP[bad] <- d$ALP[bad] + sample(c(-15, 15), 12, replace = TRUE)

  mae <- function(f) {
    est <- f$trend$mean[match(syn$dates, f$trend$date)]
    mean(abs(est - syn$latent), na.rm = TRUE)
  }
  g <- fit_trend(d, "ALP", prior_result = 20)
  t4 <- fit_trend(d, "ALP", prior_result = 20, nu = 4)
  expect_lt(mae(t4), mae(g))
  expect_gt(t4$meta$n_downweighted, 5)       # it found the contaminated polls
})

test_that("robustness costs nothing when the data are clean", {
  syn <- make_synthetic_logit(seed = 211, n_polls = 200, T_days = 500,
                              start_pct = 15, sigma_obs = 0.08, sigma_rw = 0.005)
  mae <- function(f) {
    est <- f$trend$mean[match(syn$dates, f$trend$date)]
    mean(abs(est - syn$latent), na.rm = TRUE)
  }
  g <- fit_trend(syn$polls, "ALP", prior_result = 15)
  t4 <- fit_trend(syn$polls, "ALP", prior_result = 15, nu = 4)
  # Within a tenth of a point of the Gaussian fit: no meaningful price paid
  expect_lt(abs(mae(t4) - mae(g)), 0.1)
  expect_lt(max(abs(t4$trend$mean - g$trend$mean)), 0.5)
})

test_that("the reweighting converges quickly and reports how far it went", {
  syn <- make_synthetic_logit(seed = 213, n_polls = 150, start_pct = 25)
  f <- fit_trend(syn$polls, "ALP", prior_result = 25, nu = 4)
  expect_gt(f$meta$nu_iters, 0L)
  expect_lt(f$meta$nu_iters, 25L)            # converged before the cap
  expect_true(all(f$residuals$weight > 0))
  expect_identical(f$meta$nu, 4)
})
