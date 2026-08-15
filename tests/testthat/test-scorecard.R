# Pollster scorecard: lean, noise and final-poll accuracy.

fake_fits <- function(effects = c(A = 1.5, B = -1.5, C = 0), n = c(20, 20, 20)) {
  list(ALP = list(
    house_effects = data.table::data.table(
      firm = names(effects), effect = unname(effects),
      effect_pts = unname(effects), sd = 0.2, n_polls = n),
    trend = data.table::data.table(date = as.Date("2024-01-01") + 0:99,
                                   mean = rep(38, 100)),
    meta = list(sigma_obs = 1.6, scale = "points")))
}

test_that("pollster_lean pools house effects by poll count", {
  a <- fake_fits(c(A = 2, B = -2, C = 0), n = c(10, 10, 10))
  b <- fake_fits(c(A = 0, B = -2, C = 0), n = c(30, 10, 10))
  l <- pollster_lean(list(a, b), "ALP")
  # A: (2*10 + 0*30) / 40 = 0.5
  expect_equal(l$lean_pts[l$firm == "A"], 0.5)
  expect_equal(l$n_polls[l$firm == "A"], 40)
  expect_equal(l$n_cycles[l$firm == "A"], 2)
})

test_that("pollster_lean drops the pooled other-firms bucket", {
  a <- fake_fits(c(A = 1, B = -1, `(other firms)` = 0.5), n = c(20, 20, 5))
  expect_false("(other firms)" %in% pollster_lean(list(a), "ALP")$firm)
})

test_that("noise is compared with the binomial floor, not with other firms", {
  # A firm factor is RELATIVE, normalised so the average pollster is 1.
  # Reading 0.7 as "below the sampling floor" confuses "quieter than peers"
  # with "quieter than physics", which is what this function exists to avoid.
  fits <- list(fake_fits(c(A = 0, B = 0), n = c(50, 50)))
  factors <- data.table::data.table(firm = c("A", "B"), factor = c(0.7, 1.3))
  h <- pollster_noise_vs_binomial(fits, factors, "ALP", n_ref = 1500)

  floor_expected <- binomial_sd_link(38, 1500, "points")
  expect_equal(h$binomial_floor[h$firm == "A"], floor_expected)
  # sigma_obs 1.6 x factor 0.7 = 1.12, against a floor near 1.25
  expect_equal(h$implied_sd_pts[h$firm == "A"], 1.6 * 0.7)
  expect_lt(h$ratio[h$firm == "A"], 1)     # genuinely below the floor
  expect_gt(h$ratio[h$firm == "B"], 1)
})

test_that("pollster_accuracy grades each firm's last poll of the campaign", {
  skip_if_no_anchor()
  acc <- pollster_accuracy(regions = "fed", min_year = 1990)
  expect_gt(nrow(acc), 30)
  expect_true(all(acc$days_before >= 0 & acc$days_before <= 30))
  expect_equal(acc$error, acc$poll_tpp - acc$actual_tpp)
  # One row per firm per election, never more
  expect_equal(nrow(acc), nrow(unique(acc[, c("year", "region", "firm")])))
})

test_that("within-election centring removes a shared field-wide miss", {
  # Every firm three points high at one election, and correct at another.
  # Raw errors show a bias for all; centred errors show none, which is the
  # point — a common miss is not a house effect.
  acc <- data.table::data.table(
    year = rep(c(2019, 2022), each = 3), region = "fed",
    firm = rep(c("A", "B", "C"), 2),
    error = c(3, 3, 3, 0, 0, 0))
  lean <- data.table::data.table(firm = c("A", "B", "C"),
                                 lean_pts = c(1, 0, -1), n_polls = c(50, 50, 50))
  raw <- pollster_lean_predicts_error(lean, acc, within_election = FALSE)
  cen <- pollster_lean_predicts_error(lean, acc, within_election = TRUE)
  expect_true(all(raw$data$mean_error == 1.5))
  expect_true(all(abs(cen$data$mean_error) < 1e-12))
})

test_that("the scorecard lists only firms with enough polls", {
  lean <- data.table::data.table(firm = c("Big", "Tiny"),
                                 lean_pts = c(0.5, -0.5),
                                 n_polls = c(100, 5), n_cycles = c(5, 1))
  acc <- data.table::data.table(year = 2022, region = "fed",
                                firm = c("Big", "Tiny"), error = c(1, -2))
  fac <- data.table::data.table(firm = c("Big", "Tiny"), factor = c(1.1, 0.9))
  card <- pollster_scorecard(lean, fac, acc, min_polls = 20)
  expect_equal(card$firm, "Big")
  expect_equal(card$final_mae, 1)
  expect_true("noise_factor" %in% names(card))
})
