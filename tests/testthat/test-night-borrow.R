mk <- function(v, seats = c("A", "B", "C", "D"), cls = c("ALP", "LNP", "GRN")) {
  matrix(v, length(seats), length(cls), byrow = TRUE, dimnames = list(seats, cls))
}

test_that("night_borrow_args parses off, on and k,c0, and refuses junk", {
  expect_null(night_borrow_args("0"))
  expect_null(night_borrow_args(""))
  expect_equal(night_borrow_args("1"), list(k = 2, c0 = 0.05))
  expect_equal(night_borrow_args("10,0.1"), list(k = 10, c0 = 0.1))
  expect_error(night_borrow_args("x"), "AUSPOL_NIGHT_BORROW")
  expect_error(night_borrow_args("1,0"), "AUSPOL_NIGHT_BORROW")
})

test_that("a seat's borrowed swing comes only from the OTHER counted seats", {
  pr <- mk(c(40, 40, 20, 40, 40, 20, 40, 40, 20, 40, 40, 20))
  po <- pr
  po["A", ] <- c(46, 36, 18)            # A swings 6 points to Labor; nothing else counted
  cnt <- c(A = 0.5, B = 0.5, C = 0, D = 0)   # B counted, no swing
  b <- night_borrow_swing(pr, po, cnt, k = 0)
  expect_equal(unname(b["A", "ALP"]), 0)      # A borrows from B only, which did not move
  expect_equal(unname(b["B", "ALP"]), 6)      # B borrows A's full swing at k = 0
  expect_equal(unname(b["C", "ALP"]), 3)      # C borrows the mean of A and B
  expect_equal(unname(b["C", ]), unname(b["D", ]))
})

test_that("k shrinks the statewide swing toward zero, and one counted seat borrows nothing", {
  pr <- mk(rep(c(40, 40, 20), 4)); po <- pr; po["A", ] <- c(46, 36, 18); po["B", ] <- c(46, 36, 18)
  cnt <- c(A = 1, B = 1, C = 0, D = 0)
  b0 <- night_borrow_swing(pr, po, cnt, k = 0); b5 <- night_borrow_swing(pr, po, cnt, k = 5)
  expect_gt(b0["C", "ALP"], b5["C", "ALP"]); expect_gt(b5["C", "ALP"], 0)
  one <- night_borrow_swing(pr, po, c(A = 1, B = 0, C = 0, D = 0), k = 0)
  expect_true(all(one == 0))
})

test_that("a class not standing stays at zero after applying the borrow", {
  pr <- mk(c(40, 40, 20, 40, 40, 20, 50, 50, 0, 40, 40, 20))
  po <- pr; po["A", ] <- c(36, 40, 24); po["B", ] <- c(36, 40, 24)
  b <- night_borrow_swing(pr, po, c(A = 1, B = 1, C = 0, D = 0), k = 0)
  expect_equal(unname(b["C", "GRN"]), 0)
  s2 <- night_apply_borrow(pr, b)
  expect_equal(unname(s2["C", "GRN"]), 0)
  expect_equal(unname(rowSums(s2)), rep(100, 4))
})

test_that("the cluster term adds the cluster's own residual, weighted by rho", {
  pr <- mk(rep(c(40, 40, 20), 4)); po <- pr
  po["A", ] <- c(48, 34, 18)   # cluster 1 seat swings 8
  po["C", ] <- c(40, 40, 20)   # cluster 2 seat, no swing
  cnt <- c(A = 1, B = 0, C = 1, D = 0)
  base <- night_borrow_swing(pr, po, cnt, k = 0)
  cl <- night_borrow_swing(pr, po, cnt, cluster = c(1L, 1L, 2L, 2L), rho = c(ALP = 0.5, LNP = 0.5, GRN = 0.5), k = 0)
  expect_gt(cl["B", "ALP"], base["B", "ALP"])   # B shares A's cluster: pulled further toward Labor
  expect_lt(cl["D", "ALP"], base["D", "ALP"])   # D shares C's cluster: pulled back
})
