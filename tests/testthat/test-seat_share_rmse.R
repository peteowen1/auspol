test_that("seat_share_rmse scores the point estimate against realised shares, seat by seat", {
  sh <- matrix(c(40, 35, 25,  50, 45, 5), nrow = 2, byrow = TRUE,
               dimnames = list(c("A", "B"), c("ALP", "LNP", "GRN")))
  av <- data.table::data.table(seat = c("A", "A", "A", "B", "B", "B"),
                               party = c("ALP", "LNP", "GRN", "ALP", "LNP", "GRN"),
                               votes = c(42, 33, 25,  50, 45, 5))
  r <- seat_share_rmse(sh, av)
  # A is off by (-2, +2, 0); B exact -> mean squared error 8/6
  expect_equal(r$rmse, sqrt(8 / 6))
  expect_equal(r$n_seats, 2L); expect_equal(r$n_dropped, 0L)
  expect_equal(unname(r$by_class[["GRN"]]), 0)
})

test_that("a seat with no actual result is dropped and counted, not scored against zero", {
  sh <- matrix(c(40, 60,  50, 50), nrow = 2, byrow = TRUE,
               dimnames = list(c("A", "Ghost"), c("ALP", "LNP")))
  av <- data.table::data.table(seat = c("A", "A"), party = c("ALP", "LNP"), votes = c(40, 60))
  r <- seat_share_rmse(sh, av)
  expect_equal(r$rmse, 0); expect_equal(r$n_dropped, 1L)
  # A class only the actual result has is scored against zero (the true share).
  av2 <- data.table::data.table(seat = "A", party = c("ALP", "LNP", "IND"), votes = c(40, 50, 10))
  r2 <- seat_share_rmse(sh, av2)
  expect_true(r2$rmse > 0); expect_equal(unname(r2$by_class[["IND"]]), 10)
  expect_error(seat_share_rmse(sh, av2[0]), "no seat")
})
