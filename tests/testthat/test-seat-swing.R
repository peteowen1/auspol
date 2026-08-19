# seat_swing_adjustment() turns four seat-file flags into a predicted departure
# from the statewide swing. Its main hazard is sign: every flag acts on the
# INCUMBENT, and the output is expressed toward Labor, so the same retirement
# helps Labor in one seat and hurts it in another.

mk <- function(incumbent = c("ALP", "LNP"), fed = c(0, 0),
               ret = c(FALSE, FALSE), sc = c(FALSE, FALSE),
               sp = c(FALSE, FALSE)) {
  data.table::data.table(
    seat = paste0("S", seq_along(incumbent)), incumbent = incumbent,
    fed_swing = fed, retirement = ret, soph_cand = sc, soph_party = sp)
}

test_that("no flags and no federal swing means no adjustment", {
  expect_equal(seat_swing_adjustment(mk()), c(0, 0))
})

test_that("a retirement hurts whoever holds the seat", {
  # The decisive sign test. The same event moves the Labor-facing swing in
  # OPPOSITE directions depending on who is retiring.
  a <- seat_swing_adjustment(mk(ret = c(TRUE, FALSE)))
  expect_lt(a[1], 0)          # ALP retires -> swing away from Labor
  b <- seat_swing_adjustment(mk(incumbent = c("LNP", "LNP"), ret = c(TRUE, FALSE)))
  expect_gt(b[1], 0)          # Coalition retires -> swing toward Labor
  expect_equal(abs(a[1]), abs(b[1]))
})

test_that("a sophomore candidate helps whoever holds the seat", {
  a <- seat_swing_adjustment(mk(sc = c(TRUE, FALSE)))
  expect_gt(a[1], 0)
  b <- seat_swing_adjustment(mk(incumbent = c("LNP", "LNP"), sc = c(TRUE, FALSE)))
  expect_lt(b[1], 0)
})

test_that("the federal swing is CENTRED, so a uniform one adds nothing", {
  # Otherwise the mean federal swing would be added to every seat and shift the
  # whole forecast, double-counting what the statewide projection already has.
  expect_equal(seat_swing_adjustment(mk(fed = c(5, 5))), c(0, 0))
  # A seat above the mean swings toward Labor relative to its neighbours.
  adj <- seat_swing_adjustment(mk(fed = c(4, 0)))
  expect_gt(adj[1], 0)
  expect_lt(adj[2], 0)
  expect_equal(sum(adj), 0)
})

test_that("a missing federal swing costs the seat only that term", {
  adj <- seat_swing_adjustment(mk(fed = c(NA, 0), ret = c(TRUE, FALSE)))
  expect_true(is.finite(adj[1]))
  expect_lt(adj[1], 0)        # the retirement still applies
})

test_that("the adjustment sums to zero when only the federal term is active", {
  # It is a DEPARTURE from the statewide swing, so it must not move the mean.
  adj <- seat_swing_adjustment(mk(incumbent = rep("ALP", 4),
                                  fed = c(-3, -1, 2, 2),
                                  ret = rep(FALSE, 4), sc = rep(FALSE, 4),
                                  sp = rep(FALSE, 4)))
  expect_equal(sum(adj), 0, tolerance = 1e-10)
})

test_that("a table from an older load_seats() is refused, not silently zeroed", {
  old <- data.table::data.table(seat = "S1", incumbent = "ALP")
  expect_error(seat_swing_adjustment(old), "missing column")
})

test_that("coefficient signs match what the pre-registration required", {
  expect_gt(SEAT_SWING_COEF[["fed"]], 0)
  expect_lt(SEAT_SWING_COEF[["retirement"]], 0)
  expect_gt(SEAT_SWING_COEF[["soph_cand"]], 0)
  expect_gt(SEAT_SWING_COEF[["soph_party"]], 0)
})
