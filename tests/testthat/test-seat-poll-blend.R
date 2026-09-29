test_that("seat_poll_blend_apply is a no-op unless AUSPOL_SEAT_POLL_BLEND=1", {
  m <- matrix(c(40, 35, 25, 30, 45, 25), nrow = 2, byrow = TRUE,
              dimnames = list(c("A", "B"), c("ALP", "LNP", "IND")))
  withr::local_envvar(AUSPOL_SEAT_POLL_BLEND = "0")
  expect_identical(seat_poll_blend_apply(m, "fed2022"), m)
})

test_that("the blend weight learns only from earlier elections", {
  skip_if_not(file.exists(out_path("forecasts.csv")), "no forecasts table")
  skip_if_not(file.exists(file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")),
              "no seat polls")
  expect_equal(seat_poll_weight("fed2019")$w, 0)
  expect_equal(seat_poll_weight("fed2022")$k, 1L)
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "0")
  expect_gt(seat_poll_weight("fed2022")$k, 1L)
})
