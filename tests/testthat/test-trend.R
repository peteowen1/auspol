# Synthetic-data recovery: the trend model must recover a known latent path
# and known house effects from data it generated itself.

make_synthetic <- function(seed = 42, n_polls = 120, T_days = 400,
                           house = c(A = 2, B = -2, C = 0)) {
  set.seed(seed)
  latent <- 35 + cumsum(rnorm(T_days + 1, 0, 0.08))
  dates <- as.Date("2024-01-01") + 0:T_days
  poll_t <- sort(sample(0:T_days, n_polls, replace = TRUE))
  firm <- sample(names(house), n_polls, replace = TRUE)
  y <- latent[poll_t + 1] + house[firm] + rnorm(n_polls, 0, 1.2)
  polls <- data.table::data.table(
    date = dates[poll_t + 1], firm = firm, tpp_published = NA_real_, ALP = y
  )
  data.table::setattr(polls, "parties", "ALP")
  data.table::setattr(polls, "region", "test")
  data.table::setattr(polls, "cycle_year", 2025)
  data.table::setattr(polls, "cycle_start", dates[1])
  data.table::setattr(polls, "cycle_end", dates[T_days + 1])
  list(polls = polls, latent = latent, dates = dates, house = house)
}

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
