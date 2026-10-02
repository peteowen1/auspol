test_that("upset_floor_mix gives the floor to minor contenders only, in proportion, and leaves other seats alone", {
  probs <- data.table::data.table(seat = c("A", "A", "B", "B"), party = c("ALP", "LNP", "ALP", "LNP"),
                                  prob = c(1, 0, 0.6, 0.4))
  shares <- data.table::data.table(seat = c("A", "A", "A", "A", "B", "B"),
                                   party = c("ALP", "LNP", "IND", "GRN", "ALP", "LNP"),
                                   share = c(50, 35, 9, 3, 55, 45))
  m <- upset_floor_mix(probs, shares, eps = 0.01)
  a <- m[seat == "A"]; b <- m[seat == "B"]
  expect_equal(sum(a$prob), 1)                                         # still a distribution
  expect_equal(a[party == "IND", prob], 0.01 * 9 / 12)                 # proportional to predicted share
  expect_equal(a[party == "GRN", prob], 0.01 * 3 / 12)
  expect_equal(a[party == "ALP", prob], 0.99)
  expect_equal(b$prob[order(b$party)], c(0.6, 0.4))                     # no minor contender: untouched
  expect_identical(upset_floor_mix(probs, shares, eps = 0), data.table::copy(probs))  # eps 0 is a no-op
})

test_that("upset_floor_fit buys insurance only when history pays for it", {
  # every winner given probability ~1: no insurance is best
  expect_equal(upset_floor_fit(rep(0.99, 50), rep(0, 50), rep(TRUE, 50)), 0)
  # one winner at 0 among 50 certain calls, with weight 0.5: some insurance is best
  e <- upset_floor_fit(c(0, rep(0.999, 49)), c(0.5, rep(0, 49)), rep(TRUE, 50))
  expect_true(e > 0 && e < 0.1)
})
