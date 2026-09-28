test_that("seat_swing_port_apply is a no-op unless AUSPOL_SEAT_SWING_PORT=2", {
  m <- matrix(c(40, 35, 25, 30, 45, 25), nrow = 2, byrow = TRUE,
              dimnames = list(c("A", "B"), c("ALP", "LNP", "OTH")))
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "0")
  expect_identical(seat_swing_port_apply(m, "vic2022"), m)
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "1")
  expect_identical(seat_swing_port_apply(m, "vic2022"), m)
})

test_that("the port coefficient learns only from earlier state cycles", {
  skip_if_not(file.exists(out_path("seat-tpp-estimates.csv")), "no seat TPP estimates")
  skip_if_not(file.exists(file.path(election_data_path(), "fed-swing-transposed.csv")),
              "no transposed federal swing")
  # Nothing precedes vic2018 in the transposed file except sa2018, which has
  # no sa2014 baseline: no cycles, coefficient exactly 0.
  expect_equal(seat_swing_port_coef("vic2018")$coef, 0)
  tf <- seat_swing_port_coef("vic2022")
  # Proven to bite: with time-forward fits off, later cycles leak in.
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "0")
  leaky <- seat_swing_port_coef("vic2022")
  expect_lt(tf$k, leaky$k)
  expect_true(tf$coef >= 0 && tf$coef < 1)
})
