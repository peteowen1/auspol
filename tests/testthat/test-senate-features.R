test_that("senate_features joins state districts and the PREVIOUS federal election, and never reaches forward", {
  dist <- data.table::data.table(region = "vic", cycle = 2022L, fed = 2022L, district = c("Kew", "Kew", "Brunswick"),
                                 cls = c("LNP", "GRN", "GRN"), v = 1, senate_pct = c(40, 10, 30))
  divs <- data.table::data.table(fed = c(2019L, 2022L, 2025L), state = "VIC", division = "Kooyong", cls = "GRN", v = 1,
                                 senate_pct = c(15, 20, 25))
  keys <- data.table::data.table(pair = c("vic2022", "vic2022", "fed2022", "fed2025", "fed2019", "wa2013"),
                                 seat = c("Kew", "Brunswick", "Kooyong", "Kooyong", "Kooyong", "Albany"), party = "GRN")
  x <- senate_features(keys, district = dist, division = divs)
  expect_equal(x$pair, keys$pair)                                      # row order kept
  expect_equal(x$senate_pct, c(10, 30, 15, 20, NA, NA))                # fed2022 <- fed2019; fed2019 has no earlier
  expect_equal(x$senate_dev[1:2], c(-10, 10))                          # deviation from the pair's class mean
})
