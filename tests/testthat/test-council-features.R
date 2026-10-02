test_that("council_features maps history to classes, mayor outranks councillor, missing is 0", {
  hist <- data.table::data.table(
    election = c("vic2018", "vic2018", "vic2018", "vic2018"),
    seat = c("Pascoe Vale", "Pascoe Vale", "Mildura", "Mildura"),
    name = c("YILDIZ, Oscar", "OTHER, A", "CUPPER, Ali", "LOSER, B"),
    party = c("IND", "IND", "IND", "GRN"),
    council_any = c(TRUE, TRUE, TRUE, TRUE), council_elected = c(TRUE, TRUE, TRUE, FALSE),
    council_mayor = c(TRUE, FALSE, FALSE, FALSE), council_pct = c(28.1, 5, 10.2, 3))
  keys <- data.table::data.table(pair = c("vic2018", "vic2018", "vic2018", "vic2018", "vic2014"),
                                 seat = c("Pascoe Vale", "Mildura", "Mildura", "Bendigo East", "Pascoe Vale"),
                                 party = c("IND", "IND", "GRN", "IND", "IND"))
  x <- council_features(keys, hist = hist)
  expect_identical(x$seat, keys$seat)                                     # row order kept
  expect_equal(x$council_mayor,   c(1, 0, 0, 0, 0))
  expect_equal(x$council_elected, c(0, 1, 0, 0, 0))                       # mayor is not also a councillor
  expect_equal(x$council_lost,    c(0, 0, 1, 0, 0))
  expect_equal(x$council_pct,     c(28.1, 10.2, 3, 0, 0))
  expect_true(all(x[4:5, c(council_mayor, council_elected, council_lost, council_pct)] == 0))  # no record -> 0, other year -> 0
})

test_that("council_features gives NA, not 0, where the seat has no council data at all", {
  hist <- data.table::data.table(
    election = c("fed2004", "vic2018"), seat = c("Lyne", "Mildura"), name = c("X, A", "CUPPER, Ali"),
    party = c("IND", "IND"), council_any = c(FALSE, TRUE), council_elected = c(FALSE, TRUE),
    council_mayor = c(FALSE, FALSE), council_pct = c(NA, 10.2), council_coverage = c(FALSE, TRUE))
  keys <- data.table::data.table(pair = c("fed2004", "vic2018", "vic2018"), seat = c("Lyne", "Mildura", "Mildura"),
                                 party = c("IND", "IND", "GRN"))
  x <- council_features(keys, hist = hist)
  expect_true(all(is.na(x[1, c(council_mayor, council_elected, council_lost, council_pct)])))  # no data -> NA
  expect_equal(x$council_elected[2], 1)                                                         # covered, councillor
  expect_equal(x$council_elected[3], 0)                                                         # covered, no record -> 0
})

test_that("booth_features maps by pair, seat and class and leaves the rest NA", {
  tab <- data.table::data.table(pair = c("vic2022", "vic2022"), seat = c("Mildura", "Mildura"),
                                party = c("IND", "ALP"), booth_spread = c(12.5, 6.1), early_gap = c(-3.2, 1.4))
  keys <- data.table::data.table(pair = c("vic2022", "vic2022", "vic2018"), seat = c("Mildura", "Mildura", "Mildura"),
                                 party = c("ALP", "GRN", "ALP"))
  x <- booth_features(keys, tab = tab)
  expect_identical(x$party, keys$party)
  expect_equal(x$booth_spread, c(6.1, NA, NA))
  expect_equal(x$early_gap, c(1.4, NA, NA))
})
