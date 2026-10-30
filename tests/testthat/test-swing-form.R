# AUSPOL_SWING_FORM: points (shipped) vs hybrid (logit when the class level falls).
# docs/plans/prereg-swing-form-hybrid-2026-10-30.md

test_that("points is the default and byte-identical to the old formula", {
  withr::local_envvar(AUSPOL_SWING_FORM = NA)
  x <- c(0, 6.51, 20, 45)
  expect_identical(swing_form_mode(), "points")
  expect_identical(dev_slope(x, 36.66, 24.47, 0.922), pmax(0, 24.47 + 0.922 * (x - 36.66)))
  expect_identical(dev_slope(x, 36.66, 24.47, 0.922, form = "points"), dev_slope(x, 36.66, 24.47, 0.922))
})

test_that("hybrid: Mildura Labor is no longer floored, and matches the prereg's dry run", {
  b <- dev_slope(6.51, 36.66, 24.47, 0.922, form = "hybrid")
  expect_equal(b, 5.16, tolerance = 0.005)          # the prereg's hand figure
  expect_identical(dev_slope(6.51, 36.66, 24.47, 0.922, form = "points"), 0)
})

test_that("hybrid equals points wherever the level rises or holds", {
  x <- c(0, 2.3, 11, 40, 70)
  expect_identical(dev_slope(x, 11.5, 14.27, 0.994, form = "hybrid"), dev_slope(x, 11.5, 14.27, 0.994, form = "points"))
  expect_identical(dev_slope(x, 11.5, 11.5, 0.9, form = "hybrid"), dev_slope(x, 11.5, 11.5, 0.9, form = "points"))
})

test_that("hybrid on a falling class: in range, ordered, continuous at no change, zero stays zero", {
  x <- c(0, 1, 5, 20, 60, 95)
  h <- dev_slope(x, 36.66, 24.47, 1, form = "hybrid")
  expect_true(all(h >= 0 & h <= 100))
  expect_false(is.unsorted(h))                       # order of seats is kept
  expect_identical(h[1], 0)                          # nothing to shrink from
  expect_true(all(h[-1] > 0))                        # no small seat floored
  expect_lt(h[6], x[6])                              # big seats of a falling class still fall
  near <- dev_slope(x, 30, 29.999, 0.95, form = "hybrid"); same <- dev_slope(x, 30, 30, 0.95, form = "hybrid")
  expect_equal(near, same, tolerance = 1e-3)         # no jump where the level stops falling
  expect_true(is.na(dev_slope(NA_real_, 30, 20, form = "hybrid")))
})

test_that("the switch is validated and listed as post-xgb", {
  withr::local_envvar(AUSPOL_SWING_FORM = "logit")
  expect_error(swing_form_mode(), "must be")
  expect_error(dev_slope(1, 2, 1), "must be")
  withr::local_envvar(AUSPOL_SWING_FORM = "hybrid")
  expect_identical(post_xgb_switches()[["AUSPOL_SWING_FORM"]], "hybrid")
  withr::local_envvar(AUSPOL_SWING_FORM = "points")
  expect_false("AUSPOL_SWING_FORM" %in% names(post_xgb_switches()))
})
