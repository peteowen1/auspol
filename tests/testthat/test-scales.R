# The logit scale is the stage-3 change; these check the transform itself,
# then the properties it was adopted for.

test_that("link round-trips and clamps out-of-range shares", {
  y <- c(0.5, 4, 12.5, 35, 62, 99)
  expect_equal(from_link(to_link(y, "logit")$z, "logit"), y, tolerance = 1e-10)
  expect_equal(from_link(to_link(y, "points")$z, "points"), y)

  # Zero and 100 would be +/-Inf; they are clamped instead
  edge <- to_link(c(0, 100), "logit")
  expect_true(all(is.finite(edge$z)))
  expect_equal(edge$n_clamped, 2L)
})

test_that("sd conversions are mutual inverses and match the delta method", {
  expect_equal(sd_from_link(sd_to_link(1.7, 35, "logit"), 35, "logit"), 1.7,
               tolerance = 1e-10)
  # 1 point at a 4% share is a much bigger move in log-odds than at 35%
  expect_gt(sd_to_link(1, 4, "logit"), sd_to_link(1, 35, "logit"))
  expect_identical(sd_to_link(1.7, 4, "points"), 1.7)
})

test_that("binomial floor rises for small shares on logit, falls on points", {
  expect_gt(binomial_sd_link(4, 2500, "logit"), binomial_sd_link(35, 2500, "logit"))
  expect_lt(binomial_sd_link(4, 2500, "points"), binomial_sd_link(35, 2500, "points"))
})

test_that("fitted trend and band stay inside (0, 100) for a tiny party", {
  syn <- make_synthetic_logit(seed = 21, start_pct = 1.5, n_polls = 150)
  fit <- fit_trend(syn$polls, "ALP", prior_result = 1.5)
  expect_true(all(fit$trend$lo95 > 0))
  expect_true(all(fit$trend$hi95 < 100))
  expect_true(all(fit$trend$mean > 0 & fit$trend$mean < 100))
  # The band is asymmetric in points, wider on the upside at a low share
  last <- fit$trend[which.max(date)]
  expect_gt(last$hi95 - last$mean, last$mean - last$lo95)
})

test_that("points-scale fitting is unchanged and still recovers the truth", {
  syn <- make_synthetic()
  fit <- fit_trend(syn$polls, "ALP", prior_result = 35, scale = "points")
  est <- fit$trend$mean[match(syn$dates, fit$trend$date)]
  expect_lt(mean(abs(est - syn$latent), na.rm = TRUE), 0.5)
  expect_identical(fit$meta$scale, "points")
})

test_that("logit fit recovers a logit-generated latent path and house effects", {
  syn <- make_synthetic_logit(seed = 5, n_polls = 300, T_days = 600, start_pct = 8)
  fit <- fit_trend(syn$polls, "ALP", prior_result = 8)

  est <- fit$trend$mean[match(syn$dates, fit$trend$date)]
  expect_lt(mean(abs(est - syn$latent), na.rm = TRUE), 0.5)

  he <- fit$house_effects
  truth <- syn$house[he$firm] - mean(syn$house)
  expect_lt(max(abs(he$effect - truth)), 0.1)
})

test_that("logit beats points on a party that multiplies its vote share", {
  # The stage-3 claim: a minor party climbing 2% -> ~25% is movement the raw
  # points scale must buy with a walk so large it also loosens the fit
  # everywhere else. logml_y is comparable across scales (Jacobian included).
  syn <- make_synthetic_logit(seed = 9, n_polls = 250, T_days = 550,
                              start_pct = 2, drift = 0.0046)
  expect_gt(max(syn$latent), 20)   # the generator did produce a big climb

  fit_logit <- estimate_trend_sigmas(list(syn$polls), "ALP", prior_results = 2,
                                     scale = "logit")
  fit_pts <- estimate_trend_sigmas(list(syn$polls), "ALP", prior_results = 2,
                                   scale = "points")
  expect_gt(fit_logit$logml_y, fit_pts$logml_y)
  expect_false(fit_logit$at_bound)
})

test_that("effect_pts equals effect exactly on the points scale", {
  syn <- make_synthetic(seed = 41, n_polls = 200)
  fit <- fit_trend(syn$polls, "ALP", prior_result = 35, scale = "points")
  expect_equal(fit$house_effects$effect_pts, fit$house_effects$effect,
               tolerance = 1e-10)
})

test_that("effect_pts uses the party's fitted level, not its stale prior", {
  # A party that has halved since the last election: converting a log-odds
  # house effect at the OLD level overstates it badly. effect_pts must be
  # computed where the polls actually sit.
  syn <- make_synthetic_logit(seed = 47, n_polls = 250, start_pct = 8,
                              house = c(A = 0.45, B = -0.45, C = 0))
  fit <- fit_trend(syn$polls, "ALP", prior_result = 16)  # stale prior, 2x high
  he <- fit$house_effects
  naive <- sd_from_link(he$effect, 16, "logit")   # the wrong conversion
  expect_lt(max(abs(he$effect_pts)), max(abs(naive)))
  # And it should match a direct calculation at the party's own level
  lvl <- mean(fit$trend$mean)
  direct <- 100 / (1 + exp(-(log(lvl / (100 - lvl)) + he$effect))) - lvl
  expect_equal(he$effect_pts, direct, tolerance = 0.4)
})

test_that("house effects stay centred on BOTH scales", {
  # Regression: the sum-to-zero tolerance was hard-coded at 0.3 percentage
  # points. Unconverted, it is ~20x weaker in log-odds, so house effects on
  # the logit scale drifted off centre and the level absorbed the difference.
  # Nothing errors when this breaks — the fit just quietly stops being
  # identified the way it claims to be.
  syn <- make_synthetic_logit(seed = 31, n_polls = 250, start_pct = 12)
  for (sc in c("logit", "points")) {
    fit <- fit_trend(syn$polls, "ALP", prior_result = 12, scale = sc)
    he <- fit$house_effects
    wmean_pts <- sum(he$effect_pts * he$n_polls) / sum(he$n_polls)
    expect_lt(abs(wmean_pts), 0.5, label = paste("weighted mean house effect,", sc))
  }
})

test_that("the guard escalates a points fit that leaves the valid range", {
  # The NSW SFF 2023 shape: a party polling ~1.5% on thin, gappy data. On the
  # points scale the walk uncertainty in the gaps takes the lower band below
  # zero; on the logit scale it cannot.
  syn <- make_synthetic_logit(seed = 63, n_polls = 20, T_days = 500,
                              start_pct = 1.5, sigma_obs = 0.12)
  polls <- syn$polls
  ov <- list(ALP = list(scale = "points", sigma_obs = 1.0, sigma_rw = 0.25))

  raw <- fit_cycle_trends(polls, parties = "ALP", priors = c(ALP = 2),
                          overrides = ov)
  expect_identical(scale_breaches(raw), "ALP")

  expect_message(
    fit_cycle_trends_guarded(polls, parties = "ALP", priors = c(ALP = 2),
                             overrides = ov),
    "escalation"
  )
  guarded <- suppressMessages(
    fit_cycle_trends_guarded(polls, parties = "ALP", priors = c(ALP = 2),
                             overrides = ov)
  )
  expect_identical(scale_breaches(guarded), character(0))
  expect_identical(guarded$ALP$meta$scale, "logit")
  # Escalation must drop the points-scale sigmas, not carry them into log-odds
  expect_lt(guarded$ALP$meta$sigma_obs, 0.5)
})

test_that("the guard is a no-op when every fit is already valid", {
  syn <- make_synthetic(seed = 71, n_polls = 150)
  fits <- fit_cycle_trends_guarded(syn$polls, parties = "ALP",
                                   priors = c(ALP = 35))
  expect_identical(scale_breaches(fits), character(0))
  expect_null(attr(fits, "escalated"))
})

test_that("logml_y differs from logml on logit but not on points", {
  syn <- make_synthetic_logit(seed = 13, n_polls = 120)
  f_logit <- fit_trend(syn$polls, "ALP", prior_result = 4)
  f_pts <- fit_trend(syn$polls, "ALP", prior_result = 4, scale = "points")
  expect_false(isTRUE(all.equal(f_logit$meta$logml, f_logit$meta$logml_y)))
  expect_equal(f_pts$meta$logml, f_pts$meta$logml_y)
})
