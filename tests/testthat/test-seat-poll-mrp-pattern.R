# Arm AUSPOL_SEAT_POLL_MRP_PATTERN (docs/plans/prereg-mrp-seat-pattern-2026-11-23.md)

test_that("MRP polls decay at their own half-life only when one is fitted", {
  pp <- data.table::data.table(fp = c(40, 40), n_seat = c(600, NA), mrp = c(FALSE, TRUE), days = c(60, 60),
                               group = c("direct", "mrp"))
  base <- list(H = 30, floor = c(mrp = 25, direct = 16), n_fill = 800)
  w0 <- .seat_poll_cell_weights(pp, base)
  expect_equal(w0[2], 0.25 / 25)                                  # no H_mrp: both at H = 30 (the shipped weights)
  w1 <- .seat_poll_cell_weights(pp, c(base, list(H_mrp = 60)))
  expect_equal(w1[1], w0[1])                                      # direct poll unchanged
  expect_equal(w1[2], 0.5 / 25)                                   # MRP: 60 days at its own 60-day half-life
  expect_equal(.seat_poll_cell_weights(pp, c(base, list(H_mrp = NA_real_))), w0)
})

test_that("a live MRP release's seat deviations are anchored on the run's own shares, mean-preserving", {
  shares <- matrix(c(30, 20, 40,
                     40, 30, 30,
                     20, 50,  0), nrow = 3, byrow = TRUE,
                   dimnames = list(c("Alpha", "Beta", "Gamma"), c("ALP", "LNP", "ONP")))
  tb <- data.table::data.table(seat = c("Alpha", "Beta", "Gamma", "Alpha", "Beta", "Gamma", "Beta"),
                               class = c("ALP", "ALP", "ALP", "ONP", "ONP", "ONP", "LNP"),
                               type = c(rep("mrp_dev", 6), "direct"),
                               poll = c(5, -1, -4, 3, -1, -2, 33), n_polls = 1L, n_mrp = c(rep(1L, 6), 0L), wsum = 0.01)
  out <- NULL
  invisible(utils::capture.output(out <- .seat_poll_mrp_anchor(tb, shares, "test")))
  alp <- out[out$class == "ALP"]
  expect_equal(alp$poll, c(5, -1, -4) + mean(c(30, 40, 20)))     # anchor = mean of the run's ALP shares
  expect_equal(mean(alp$poll), mean(shares[, "ALP"]))             # deviations summing to 0 leave the mean alone
  onp <- out[out$class == "ONP"]
  expect_equal(onp$seat, c("Alpha", "Beta"))                      # Gamma's ONP share is 0: not blended, not in the anchor
  expect_equal(mean(onp$poll), mean(shares[onp$seat, "ONP"]))     # dropping Gamma must not move the class mean (review)
  expect_equal(onp$poll, c(3, -1) - mean(c(3, -1)) + mean(c(40, 30)))
  expect_equal(out[out$class == "LNP"]$poll, 33)                  # direct polls untouched
  expect_true(all(out$type %in% c("mrp", "direct")))
})

test_that("the anchor stops when no MRP cell matches the shares (label mismatch), instead of dropping the release", {
  shares <- matrix(c(30, 70), nrow = 1, dimnames = list("Alpha", c("ALP", "LNP")))
  tb <- data.table::data.table(seat = "Alpha", class = "L/NP", type = "mrp_dev", poll = 2, n_polls = 1L, n_mrp = 1L, wsum = 0.01)
  expect_error(utils::capture.output(.seat_poll_mrp_anchor(tb, shares, "test")), "SPMA!")
})

test_that("the arm switch refuses values it does not know", {
  withr::local_envvar(AUSPOL_SEAT_POLL_MRP_PATTERN = "yes")
  expect_error(.seat_poll_mrp_pattern_on())
})
