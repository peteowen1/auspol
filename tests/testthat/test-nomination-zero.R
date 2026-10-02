test_that("zero_unnominated zeroes a class with no candidate and renormalises", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1")
  sh <- matrix(c(40, 35, 25,
                 50, 30, 20), nrow = 2, byrow = TRUE,
               dimnames = list(c("Narracan", "Morwell"), c("ALP", "LNP", "IND")))
  tg <- data.table::data.table(seat = c("Narracan", "Narracan", "Morwell", "Morwell", "Morwell"),
                               party = c("LNP", "IND", "ALP", "LNP", "IND"),
                               votes = c(100, 50, 10, 10, 10))
  out <- zero_unnominated(sh, tg, "test")
  expect_equal(unname(out["Narracan", "ALP"]), 0)
  expect_equal(unname(rowSums(out)), c(100, 100))
  expect_equal(out["Morwell", ], sh["Morwell", ])          # everyone stood: untouched
  expect_equal(unname(out["Narracan", "LNP"]), 35 / 60 * 100)
})

test_that("zero_unnominated never zeroes a class the result table does not use, or an unknown seat", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1")
  sh <- matrix(c(40, 35, 25), nrow = 1, dimnames = list("Nowhere-Not-A-Seat", c("ALP", "NAT", "LNP")))
  tg <- data.table::data.table(seat = "Elsewhere", party = c("ALP", "LNP"), votes = c(1, 1))
  expect_equal(zero_unnominated(sh, tg, "test"), sh)     # seat absent from the table
  sh2 <- matrix(c(40, 35, 25), nrow = 1, dimnames = list("Elsewhere", c("ALP", "NAT", "LNP")))
  out <- zero_unnominated(sh2, tg, "test")
  expect_gt(out[1, "NAT"], 0)                             # NAT never appears in the result table
})

test_that("zero_unnominated is a no-op when the switch is off", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "0")
  sh <- matrix(c(40, 60), nrow = 1, dimnames = list("A", c("ALP", "LNP")))
  expect_identical(zero_unnominated(sh, data.table::data.table(seat = "A", party = "LNP", votes = 1), "t"), sh)
})
