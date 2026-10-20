# AUSPOL_SALIENCE_BLEND_ONCE (audit F5, plans/prereg-salience-blend-once-2026-10-19.md)
sb_fixture <- function() {
  shares <- matrix(c(40, 35, 20, 5, 45, 30, 15, 10), nrow = 2, byrow = TRUE,
                   dimnames = list(c("A", "B"), c("ALP", "LNP", "GRN", "IND")))
  hz <- list(seat_party_hazard = data.table::data.table(seat = c("A", "B"), party = "IND", p_hat = c(0.3, 0)))
  list(shares = shares, hz = hz)
}

test_that("off: the post-tree blend is the plain blend", {
  f <- sb_fixture()
  withr::local_envvar(AUSPOL_SALIENCE_BLEND_ONCE = "0", AUSPOL_XGB_PRIMARY = "1", AUSPOL_SALIENCE_BLEND = "1")
  expect_equal(blend_salience_post_xgb(f$shares, f$hz, 15.6), blend_salience_shares(f$shares, f$hz, 15.6))
  expect_gt(blend_salience_post_xgb(f$shares, f$hz, 15.6)["A", "IND"], 5)   # the fixture really moves a cell
})

test_that("on at stage 6 (xgb on): the blend is skipped and says so", {
  f <- sb_fixture()
  withr::local_envvar(AUSPOL_SALIENCE_BLEND_ONCE = "1", AUSPOL_XGB_PRIMARY = "1", AUSPOL_SALIENCE_BLEND = "1")
  out <- NULL
  expect_output(out <- blend_salience_post_xgb(f$shares, f$hz, 15.6, label = "vic2022", code = "SBV1"),
                "SBV1 vic2022: salience blend after the trees SKIPPED .* 1 cell\\(s\\) would have moved")
  expect_equal(unname(out), unname(f$shares), ignore_attr = "cells")
  expect_identical(attr(out, "cells"), 0L)
})

test_that("on at stage 1 (xgb off): the blend still builds the training base", {
  f <- sb_fixture()
  withr::local_envvar(AUSPOL_SALIENCE_BLEND_ONCE = "1", AUSPOL_XGB_PRIMARY = "0", AUSPOL_SALIENCE_BLEND = "1")
  expect_equal(blend_salience_post_xgb(f$shares, f$hz, 15.6), blend_salience_shares(f$shares, f$hz, 15.6))
})

test_that("a bad value stops", {
  withr::local_envvar(AUSPOL_SALIENCE_BLEND_ONCE = "yes")
  expect_error(salience_blend_once(), "must be")
})
