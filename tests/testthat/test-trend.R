# Synthetic-data recovery: the trend model must recover a known latent path
# and known house effects from data it generated itself.
# (make_synthetic lives in helper-synthetic.R, shared with test-hyperpars.R)

test_that("fit_trend recovers latent path and house effects from synthetic data", {
  syn <- make_synthetic()
  fit <- fit_trend(syn$polls, "ALP", prior_result = 35)

  # Latent path recovered within half a point on average
  est <- fit$trend$mean[match(syn$dates, fit$trend$date)]
  mae <- mean(abs(est - syn$latent), na.rm = TRUE)
  expect_lt(mae, 0.5)

  # House effects recovered to within ~0.5 pts (relative to their mean,
  # since the model centres them via soft sum-to-zero)
  he <- fit$house_effects
  truth <- syn$house[he$firm] - mean(syn$house)
  expect_lt(max(abs(he$effect - truth)), 0.6)

  # 95% band covers the truth close to nominally (allow 85%+)
  lo <- fit$trend$lo95[match(syn$dates, fit$trend$date)]
  hi <- fit$trend$hi95[match(syn$dates, fit$trend$date)]
  coverage <- mean(syn$latent >= lo & syn$latent <= hi, na.rm = TRUE)
  expect_gt(coverage, 0.85)
})

test_that("fit_trend errors on too few polls", {
  syn <- make_synthetic(n_polls = 4)
  expect_error(fit_trend(syn$polls, "ALP"), "not enough")
})
