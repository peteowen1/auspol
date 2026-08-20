# seat_swing_adjustment() turns seat-file flags into a predicted departure from
# the statewide swing. Its main hazard is sign: every flag acts on the
# INCUMBENT, and the output is expressed toward Labor, so the same retirement
# helps Labor in one seat and hurts it in another.
#
# SINCE 2026-08-20 the default coefficient vector has ONE term. The other three
# were removed after re-validation on five elections found them worth less than
# nothing. The side-flipping mechanism is retained and still tested here, by
# passing the historical four-term vector explicitly -- so a caller who supplies
# their own flags still gets correct behaviour, and a regression in that
# machinery is still caught.
OLD4 <- c(fed = 0.7077, retirement = -1.3955,
          soph_cand = 2.5587, soph_party = 1.6090)

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
  a <- seat_swing_adjustment(mk(ret = c(TRUE, FALSE)), OLD4)
  expect_lt(a[1], 0)          # ALP retires -> swing away from Labor
  b <- seat_swing_adjustment(mk(incumbent = c("LNP", "LNP"), ret = c(TRUE, FALSE)), OLD4)
  expect_gt(b[1], 0)          # Coalition retires -> swing toward Labor
  expect_equal(abs(a[1]), abs(b[1]))
})

test_that("a sophomore candidate helps whoever holds the seat", {
  a <- seat_swing_adjustment(mk(sc = c(TRUE, FALSE)), OLD4)
  expect_gt(a[1], 0)
  b <- seat_swing_adjustment(mk(incumbent = c("LNP", "LNP"), sc = c(TRUE, FALSE)), OLD4)
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
  adj <- seat_swing_adjustment(mk(fed = c(NA, 0), ret = c(TRUE, FALSE)), OLD4)
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

test_that("the default is ONE term, and it is the federal swing", {
  # Guards the 2026-08-20 removal. If a future change re-adds the flags without
  # re-validating them, this fails and points at the review that removed them.
  expect_named(SEAT_SWING_COEF, "fed")
  expect_gt(SEAT_SWING_COEF[["fed"]], 0)
})

test_that("a caller supplying only some flags is not silently given zeros", {
  # The required columns follow the COEFFICIENTS, so a four-term vector against
  # a table lacking the flags must error rather than treat them as absent.
  bare <- data.table::data.table(seat = "S1", incumbent = "ALP", fed_swing = 0)
  expect_equal(seat_swing_adjustment(bare), 0)
  expect_error(seat_swing_adjustment(bare, OLD4), "missing column")
})
