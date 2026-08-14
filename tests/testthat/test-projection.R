# Projection: mixing trend and fundamentals by how far out the election is.

fake_proj <- function(horizons = c(30, 365), n_per = 30, seed = 3,
                      trend_sd = c(1, 4), fund_sd = 3) {
  set.seed(seed)
  data.table::rbindlist(lapply(seq_along(horizons), function(i) {
    actual <- rnorm(n_per, 50, 4)
    data.table::data.table(
      year = seq_len(n_per), region = "test", horizon = horizons[i],
      actual_tpp = actual,
      trend_tpp = actual + rnorm(n_per, 0, trend_sd[i]),
      fund_tpp = actual + rnorm(n_per, 0, fund_sd),
      n_polls = 50)
  }))
}

test_that("the mix leans on whichever component is more accurate", {
  # Trend is sharp at 30 days and poor at 365; the weight must follow.
  d <- fake_proj()
  mix <- fit_projection_mix(d)
  expect_equal(nrow(mix), 2)
  w30 <- mix$w[mix$horizon == 30]
  w365 <- mix$w[mix$horizon == 365]
  expect_gt(w30, 0.7)
  expect_lt(w365, w30)
})

test_that("a perfect component takes essentially all the weight", {
  d <- fake_proj(horizons = 30, trend_sd = 0.01, fund_sd = 5)
  expect_gt(fit_projection_mix(d)$w, 0.95)
  d2 <- fake_proj(horizons = 30, trend_sd = 5, fund_sd = 0.01)
  expect_lt(fit_projection_mix(d2)$w, 0.05)
})

test_that("the in-sample mix can never lose, so the held-out one is reported", {
  d <- fake_proj()
  mix <- fit_projection_mix(d)
  # By construction, since the weight grid spans 0 and 1
  expect_true(all(mix$mae_mix <= mix$mae_trend + 1e-9))
  expect_true(all(mix$mae_mix <= mix$mae_fund + 1e-9))
  # The held-out version carries a selection penalty and so cannot be lower
  expect_true(all(mix$mae_mix_loo >= mix$mae_mix - 1e-9))
})

test_that("projection_params interpolates in log-horizon and clamps outside", {
  mix <- data.table::data.table(horizon = c(30, 365), w = c(0.8, 0.2),
                                sd_err = c(2, 4), bias = c(0, 1))
  mid <- projection_params(mix, sqrt(30 * 365))   # midpoint on a log scale
  expect_gt(mid$w, 0.2); expect_lt(mid$w, 0.8)
  expect_equal(round(mid$w, 3), 0.5)
  # Beyond the fitted range the endpoints hold rather than extrapolating
  expect_equal(projection_params(mix, 5)$w, 0.8)
  expect_equal(projection_params(mix, 2000)$w, 0.2)
})

test_that("project_result combines, de-biases and widens correctly", {
  mix <- data.table::data.table(horizon = 100, w = 0.6, sd_err = 2.5, bias = 0.5)
  p <- project_result(trend_value = 48, fund_value = 53, mix, horizon = 100)
  expect_equal(p$mean, 0.6 * 48 + 0.4 * 53 - 0.5)
  expect_equal(p$w, 0.6)
  expect_equal(p$hi95 - p$lo95, 2 * 1.96 * 2.5)
})

test_that("trend_as_at uses only polls up to the cutoff", {
  skip_if_no_anchor()
  polls <- suppressMessages(load_polls("vic"))
  cycles <- load_election_cycles()
  pri <- load_prior_results()
  k <- pri$region == "vic" & pri$year == 2022
  priors <- setNames(pri$prev1[which(k)], pri$party[which(k)])
  fl <- flows_for(load_preference_flows(), 2022, "vic", quiet = TRUE)

  early <- trend_as_at(polls, 2022, cycles, as.Date("2021-06-30"), priors, fl)
  late <- trend_as_at(polls, 2022, cycles, as.Date("2022-11-26"), priors, fl)
  expect_false(is.null(early)); expect_false(is.null(late))
  expect_lt(early$n_polls, late$n_polls)
  # Truncating the cycle must change the answer; identical values would mean
  # later polls were leaking backwards into the earlier estimate.
  expect_false(isTRUE(all.equal(early$tpp, late$tpp)))
})

test_that("trend_as_at returns NULL rather than guessing when polls are thin", {
  skip_if_no_anchor()
  polls <- suppressMessages(load_polls("vic"))
  cycles <- load_election_cycles()
  pri <- load_prior_results()
  k <- pri$region == "vic" & pri$year == 2022
  priors <- setNames(pri$prev1[which(k)], pri$party[which(k)])
  fl <- flows_for(load_preference_flows(), 2022, "vic", quiet = TRUE)
  expect_null(trend_as_at(polls, 2022, cycles, as.Date("2018-12-01"),
                          priors, fl, min_polls = 8))
})
