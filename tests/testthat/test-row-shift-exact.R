# row_shift_exact(): AUSPOL_ROW_SHIFT_EXACT (audit F16, 2026-10-25). The salience and seat-poll blends move a few cells
# and then rescale the whole row; "1" keeps the moved cells exact and scales only the others.
mk <- function() matrix(c(40, 30, 10, 15, 5,
                          35, 35, 12, 10, 8), nrow = 2, byrow = TRUE,
                        dimnames = list(c("A", "B"), c("ALP", "LNP", "GRN", "ONP", "IND")))

test_that("off (default) is the old whole-row rescale, bit for bit, and prints nothing", {
  withr::local_envvar(AUSPOL_ROW_SHIFT_EXACT = NA)
  b <- mk(); a <- b; a["A", "ONP"] <- 18
  expect_silent(o <- row_shift_exact(b, a, "t", "s"))
  expect_identical(o, 100 * a / rowSums(a))
  # the broken-input half: under the default the moved cell is NOT exact, so the exactness check below can fail
  expect_lt(o["A", "ONP"], 18 - 0.4)
})

test_that("on: moved cells exact, rows sum to 100, others scaled in proportion, untouched rows as before", {
  withr::local_envvar(AUSPOL_ROW_SHIFT_EXACT = "1")
  b <- mk(); a <- b; a["A", "ONP"] <- 18; a["A", "IND"] <- 6
  out <- NULL
  txt <- utils::capture.output(out <- row_shift_exact(b, a, "t", "s"))
  expect_equal(unname(out["A", c("ONP", "IND")]), c(18, 6))
  expect_equal(unname(rowSums(out)), c(100, 100))
  expect_true(all(out >= 0))
  oth <- c("ALP", "LNP", "GRN")
  expect_equal(unname(out["A", oth] / b["A", oth]), rep(76 / 80, 3))   # ratios kept among the cells not moved
  expect_identical(out["B", ], (100 * a / rowSums(a))["B", ])
  expect_match(txt, "RSX1 t s: 2 moved cell\\(s\\) in 1 row\\(s\\) kept exact")
  expect_match(txt, "lift \\+4\\.000 points, kept \\+4\\.000")
  expect_match(txt, "0 row\\(s\\) fell back")
})

test_that("a lift down (cell above the target) is kept exact too", {
  withr::local_envvar(AUSPOL_ROW_SHIFT_EXACT = "1")
  b <- mk(); a <- b; a["B", "ALP"] <- 30
  out <- NULL; utils::capture.output(out <- row_shift_exact(b, a))
  expect_equal(out[["B", "ALP"]], 30)
  expect_equal(sum(out["B", ]), 100)
})

test_that("infeasible rows fall back to the rescale and are counted, never left negative or off 100", {
  withr::local_envvar(AUSPOL_ROW_SHIFT_EXACT = "1")
  b <- mk(); a <- b
  a["A", "ONP"] <- 101                      # moved cells alone above 100
  a["B", "IND"] <- -2                       # a negative cell
  out <- NULL; txt <- utils::capture.output(out <- row_shift_exact(b, a))
  expect_match(txt, "2 row\\(s\\) fell back")
  expect_equal(out["A", ], (100 * a / rowSums(a))["A", ])
  expect_equal(unname(rowSums(out)), c(100, 100))
  # a row whose moved cells are the only non-zero ones and already make 100 is fine as is
  b2 <- matrix(c(0, 0, 100), 1, dimnames = list("C", c("X", "Y", "Z"))); a2 <- b2; a2[1, ] <- c(0, 60, 40)
  o2 <- NULL; txt2 <- utils::capture.output(o2 <- row_shift_exact(b2, a2))
  expect_equal(unname(o2[1, ]), c(0, 60, 40))
  expect_match(txt2, "0 row\\(s\\) fell back")
  # moved cells making exactly 100 beside unmoved cells that hold share: the exact rule would zero those cells
  b3 <- matrix(c(30, 30, 40), 1, dimnames = list("D", c("X", "Y", "Z"))); a3 <- b3; a3[1, c("X", "Y")] <- c(50, 50)
  o3 <- NULL; txt3 <- utils::capture.output(o3 <- row_shift_exact(b3, a3))
  expect_match(txt3, "1 row\\(s\\) fell back")
  expect_equal(o3["D", ], (100 * a3 / rowSums(a3))["D", ])
  expect_gt(o3[["D", "Z"]], 0)
})

test_that("a value other than 0 or 1 stops", {
  withr::local_envvar(AUSPOL_ROW_SHIFT_EXACT = "yes")
  expect_error(row_shift_exact(mk(), mk()), "must be")
})

test_that("blend_salience_shares: off is unchanged; on keeps the blended cell at the blend value", {
  sh <- mk()
  hz <- list(seat_party_hazard = data.table::data.table(seat = c("A", "B"), party = "ONP", p_hat = c(0.05, 0)))
  ref <- sh; ref[, "ONP"] <- (1 - c(0.05, 0)) * sh[, "ONP"] + c(0.05, 0) * 34.28
  withr::local_envvar(AUSPOL_ROW_SHIFT_EXACT = "0", AUSPOL_SALIENCE_BLEND = "1")
  o0 <- blend_salience_shares(sh, hz, 34.28)
  expect_identical(unclass(o0)[, ], (100 * ref / rowSums(ref))[, ])
  withr::local_envvar(AUSPOL_ROW_SHIFT_EXACT = "1")
  o1 <- NULL; utils::capture.output(o1 <- blend_salience_shares(sh, hz, 34.28))
  expect_equal(o1[["A", "ONP"]], ref[["A", "ONP"]])            # 15 + 0.05 * 19.28 = 15.964, in full
  expect_gt(o1[["A", "ONP"]], o0[["A", "ONP"]])
  expect_equal(unname(rowSums(o1)), c(100, 100))
  expect_equal(attr(o1, "cells"), 1L)
})

test_that("seat-poll blend modes 2 and 3 keep the polled cell at its pulled value under the switch", {
  sh <- mk()
  tb <- data.table::data.table(seat = "A", class = "ONP", poll = 25, type = "direct")
  w <- list(w_direct = 0.5, w_mrp = 0.5, w = 0.5)
  withr::local_envvar(AUSPOL_ROW_SHIFT_EXACT = "1", AUSPOL_SEAT_POLL_IND_WEIGHT = "0")
  o2 <- NULL; utils::capture.output(o2 <- .seat_poll_blend_split(sh, tb, w, "t2000"))
  expect_equal(o2[["A", "ONP"]], 20)
  expect_equal(unname(rowSums(o2)), c(100, 100))
  wj <- list(w1 = 0.5, w2 = 0, b = c(0.5, 0), se = c(0.1, 0), n = 10L, k = 2L)
  sp <- data.table::data.table(seat = "A", class = "ONP", poll = 25)
  o3 <- NULL; utils::capture.output(o3 <- .seat_poll_blend_joint(sh, "t2000", wj, sp, data.table::data.table()))
  expect_equal(o3[["A", "ONP"]], 20)
  withr::local_envvar(AUSPOL_ROW_SHIFT_EXACT = "0")
  o3b <- NULL; utils::capture.output(o3b <- .seat_poll_blend_joint(sh, "t2000", wj, sp, data.table::data.table()))
  expect_equal(o3b[["A", "ONP"]], 100 * 20 / 105)               # the old rescale, for contrast
})
