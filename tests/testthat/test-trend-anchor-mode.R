# AUSPOL_ANCHOR_SD_MULT (arm ANC, docs/plans/prereg-poll-lean-2026-11-02.md): the published value must leave the
# anchor, and so every trend, byte-identical; every other value must do what it says and nothing else.

anchor_prep <- function() {
  syn <- make_synthetic_logit(seed = 5, n_polls = 60, T_days = 400, start_pct = 20,
                              sigma_obs = 0.12, sigma_rw = 0.008)
  prep_trend_obs(syn$polls, "ALP", 3, "logit", 2)
}

test_that("the published anchor mode is the old anchor exactly, with or without the switch set", {
  prep <- anchor_prep()
  withr::local_envvar(AUSPOL_ANCHOR_SD_MULT = NA)
  unset <- trend_anchor(prep, 2)
  expect_identical(trend_anchor(prep, 2, anchor_mode = "1"), unset)
  expect_identical(unset$val, to_link(2, "logit")$z)
  expect_identical(unset$sd, sd_to_link(5, prep$p_ref, "logit"))
  withr::local_envvar(AUSPOL_ANCHOR_SD_MULT = "1")
  expect_identical(trend_anchor(prep, 2), unset)
})

test_that("a number multiplies the sd and leaves the value", {
  prep <- anchor_prep()
  base <- trend_anchor(prep, 2, anchor_mode = "1")
  a4 <- trend_anchor(prep, 2, anchor_mode = "4")
  expect_identical(a4$val, base$val)
  expect_equal(a4$sd, 4 * base$sd)
})

test_that("none ignores the previous result, exactly as when there is none", {
  prep <- anchor_prep()
  expect_identical(trend_anchor(prep, 2, anchor_mode = "none"), trend_anchor(prep, NA_real_, anchor_mode = "1"))
})

test_that("gap widens the sd with the distance from the first poll, and only by that", {
  prep <- anchor_prep()
  base <- trend_anchor(prep, 2, anchor_mode = "1")
  gap <- abs(prep$obs$y[which.min(prep$obs$t)] - base$val)
  expect_gt(gap, 1)                                    # a 2% result against polls near 20%: far apart
  a <- trend_anchor(prep, 2, anchor_mode = "gap:1")
  expect_identical(a$val, base$val)
  expect_equal(a$sd, base$sd * sqrt(1 + gap^2))
  # a previous result equal to the first poll is not widened at all
  near <- trend_anchor(prep, from_link(prep$obs$y[which.min(prep$obs$t)], "logit"), anchor_mode = "gap:1")
  near1 <- trend_anchor(prep, from_link(prep$obs$y[which.min(prep$obs$t)], "logit"), anchor_mode = "1")
  expect_equal(near$sd, near1$sd)
})

test_that("a malformed mode stops rather than falling back to the published anchor", {
  prep <- anchor_prep()
  expect_error(trend_anchor(prep, 2, anchor_mode = "two"), "AUSPOL_ANCHOR_SD_MULT")
  expect_error(trend_anchor(prep, 2, anchor_mode = "0"), "AUSPOL_ANCHOR_SD_MULT")
  expect_error(trend_anchor(prep, 2, anchor_mode = "gap:x"), "gap scale")
})
