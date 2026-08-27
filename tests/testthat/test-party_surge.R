mk <- function() data.table::data.table(
  region = "xx",
  year = c(rep(2020L, 4), rep(2024L, 4)),
  seat = c("A", "A", "B", "B", "A", "A", "B", "B"),
  party = c("ALP", "ONP", "ALP", "ONP", "ALP", "ONP", "ALP", "ONP"),
  votes = c(90, 10, 90, 10,  60, 40, 60, 40))

test_that("a statewide swing is measured in points, both directions", {
  s <- party_swing("xx", 2020L, 2024L, mk())
  expect_equal(s[party == "ONP"]$swing, 30)
  expect_equal(s[party == "ALP"]$swing, -30)
})

test_that("a surging class is flagged and a stable one is not", {
  d <- mk()
  d[year == 2024L & party == "ONP", votes := 12]
  d[year == 2024L & party == "ALP", votes := 88]
  expect_length(surging_parties("xx", 2020L, 2024L, threshold = 5, corpus = d), 0L)
  expect_true("ONP" %in% surging_parties("xx", 2020L, 2024L, threshold = 1, corpus = d))
})

test_that("a class absent at one election reads as zero, not NA", {
  # One Nation contested 19 of 47 South Australian seats in 2022 and all 47 in
  # 2026. A party that did not stand has a share of zero, not a missing value.
  d <- mk()[!(year == 2020L & party == "ONP")]
  s <- party_swing("xx", 2020L, 2024L, d)
  expect_equal(s[party == "ONP"]$prev, 0)
  expect_gt(s[party == "ONP"]$swing, 0)
})

test_that("an unknown election is an error rather than an empty answer", {
  expect_error(party_swing("xx", 1999L, 2024L, mk()), "no rows for")
})
