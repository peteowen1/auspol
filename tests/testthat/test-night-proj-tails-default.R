test_that("the live night defaults to the Student-t combine (lane D2) and 'normal' turns it off", {
  expect_identical(.NIGHT_PROJ_TAILS, "t")
  expect_identical(night_lane_a_args(proj_tails = .NIGHT_PROJ_TAILS)$proj_tails, "t")
  expect_null(night_lane_a_args(proj_tails = "normal"))   # "normal" is off: nothing is passed on
  expect_error(night_lane_a_args(proj_tails = "cauchy"), "NX30")
})
