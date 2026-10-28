# Election-night replay update (R/night_update.R, issue #153). Synthetic booths; no anchor data.

nu_booths <- function(alp, lnp, booths = c("B1", "B2", "B3"), district = "Seat A") {
  data.table::rbindlist(lapply(seq_along(booths), function(i) data.table::data.table(
    district = district, booth = booths[i], booth_type = "ordinary",
    party = c("Australian Labor Party", "Liberal"), votes = c(alp[i], lnp[i]))))
}

test_that("the switch parses strictly and is off when unset", {
  withr::local_envvar(AUSPOL_NIGHT_REPLAY_FRAC = NA)
  expect_true(is.na(night_replay_frac()))
  withr::local_envvar(AUSPOL_NIGHT_REPLAY_FRAC = "0.5")
  expect_identical(night_replay_frac(), 0.5)
  for (bad in c("-0.1", "1.5", "half")) {
    withr::local_envvar(AUSPOL_NIGHT_REPLAY_FRAC = bad)
    expect_error(night_replay_frac(), "must be a number from 0 to 1")
  }
})

test_that("the prior sd matches the simulator's level formula and honours the override", {
  sh <- matrix(c(50, 30, 20), 1, dimnames = list("Seat A", c("ALP", "LNP", "GRN")))
  sd <- night_prior_sd(sh, c(1, 10), c(GRN = 2))
  expect_equal(unname(sd[1, "ALP"]), 1 + 10 * sqrt(0.5 * 0.5))
  expect_equal(unname(sd[1, "GRN"]), 1 + 10 * 2 * sqrt(0.2 * 0.8))
  ov <- matrix(c(NA, 7, NA), 1, dimnames = dimnames(sh))
  expect_equal(unname(night_prior_sd(sh, c(1, 10), NULL, ov)[1, ]), c(1 + 10 * 0.5, 7, 1 + 10 * sqrt(0.16)))
  expect_error(night_prior_sd(sh, NULL), "needs level_sd")
})

test_that("nothing counted leaves the prior untouched; everything counted lands on the final count", {
  ref  <- nu_booths(c(50, 60, 40), c(50, 40, 60))
  live <- nu_booths(c(60, 70, 50), c(40, 30, 50))          # a uniform 10-point swing to ALP
  sh <- matrix(c(52, 48), 1, dimnames = list("Seat A", c("ALP", "LNP")))
  psd <- matrix(4, 1, 2, dimnames = dimnames(sh))
  u0 <- night_booth_update(sh, psd, 0, live, ref)
  expect_identical(u0$shares, sh); expect_identical(u0$sd, psd); expect_identical(u0$n_updated, 0L)
  u1 <- night_booth_update(sh, psd, 1, live, ref)
  expect_equal(unname(u1$shares[1, "ALP"]), 60, tolerance = 0.5)   # final ALP share is 180/300
  expect_true(all(u1$sd < psd)); expect_equal(unname(u1$counted["Seat A"]), 1)
  expect_gt(u1$resolved, 0.9)
  expect_equal(sum(u1$shares[1, ]), 100)
})

test_that("a seat with no booth data keeps its prior, and the replay leaves the caller's random stream alone", {
  ref  <- nu_booths(c(50, 60, 40), c(50, 40, 60))
  live <- nu_booths(c(60, 70, 50), c(40, 30, 50))
  sh <- matrix(c(52, 48, 45, 55), 2, byrow = TRUE, dimnames = list(c("Seat A", "Seat Z"), c("ALP", "LNP")))
  psd <- matrix(4, 2, 2, dimnames = dimnames(sh))
  set.seed(7); before <- .Random.seed
  u <- night_booth_update(sh, psd, 0.5, live, ref)
  expect_identical(.Random.seed, before)
  expect_identical(u$shares["Seat Z", ], sh["Seat Z", ])
})

test_that("statewide draws shrink around their own centre", {
  d <- matrix(c(40, 44, 36, 30, 28, 32), 3, dimnames = list(NULL, c("ALP", "LNP")))
  s <- night_shrink_draws(d, 0.5)
  expect_equal(colMeans(s), colMeans(d))
  expect_equal(apply(s, 2, sd), apply(d, 2, sd) * 0.5)
  expect_identical(night_shrink_draws(d, 1), d)
  expect_null(night_shrink_draws(NULL, 0.5))
})
