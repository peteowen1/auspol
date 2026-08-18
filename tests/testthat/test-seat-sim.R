# Candidate-level seat simulation. Synthetic seats only: the property being
# tested is that the machinery resolves contests correctly, not that any
# particular election comes out a particular way.

fake_matrix <- function() {
  build_flow_matrix(data.table::data.table(
    election = "x", seat = rep(c("a","b","c"), each = 2), round = 1L,
    from = "GRN", to = rep(c("ALP","LNP"), 3),
    votes = c(900,100, 850,150, 800,200)), min_n = 2L)
}

test_that("a party can win without ever leading on first preferences", {
  # LNP leads the primaries; Greens preferences carry Labor past it. This is
  # the thing simulate_seats() cannot express at all.
  sh <- matrix(c(38, 40, 22), nrow = 1,
               dimnames = list("seat1", c("ALP","LNP","GRN")))
  r <- simulate_seat_contests(sh, fake_matrix(),
                              party_sd = c(ALP=0, LNP=0, GRN=0),
                              seat_sd = 0, n_sims = 50, seed = 1)
  expect_equal(r$win_prob$party[which.max(r$win_prob$prob)], "ALP")
  expect_equal(unname(r$totals[1, "ALP"]), 1L)
})

test_that("a minor party CAN win a seat outright", {
  sh <- matrix(c(20, 25, 55), nrow = 1,
               dimnames = list("green_seat", c("ALP","LNP","GRN")))
  r <- simulate_seat_contests(sh, fake_matrix(),
                              party_sd = c(ALP=0, LNP=0, GRN=0),
                              seat_sd = 0, n_sims = 20, seed = 2)
  expect_equal(r$win_prob$party[which.max(r$win_prob$prob)], "GRN")
})

test_that("every simulation awards exactly one winner per seat", {
  sh <- matrix(c(35,33,32, 40,35,25), nrow = 2, byrow = TRUE,
               dimnames = list(c("s1","s2"), c("ALP","LNP","GRN")))
  r <- simulate_seat_contests(sh, fake_matrix(),
                              party_sd = c(ALP=2, LNP=2, GRN=2),
                              seat_sd = 3, n_sims = 100, seed = 3)
  expect_true(all(rowSums(r$totals) == nrow(sh)))
  # and each seat's probabilities sum to 1
  agg <- tapply(r$win_prob$prob, r$win_prob$seat, sum)
  expect_true(all(abs(agg - 1) < 1e-9))
})

test_that("statewide uncertainty moves every seat together", {
  # With no seat-level noise, a shared statewide draw must produce PERFECTLY
  # correlated outcomes: either party wins both identical seats or neither.
  sh <- matrix(rep(c(40, 38, 22), 2), nrow = 2, byrow = TRUE,
               dimnames = list(c("s1","s2"), c("ALP","LNP","GRN")))
  r <- simulate_seat_contests(sh, fake_matrix(),
                              party_sd = c(ALP=6, LNP=6, GRN=1),
                              seat_sd = 0, n_sims = 200, seed = 4)
  expect_true(all(r$totals[, "ALP"] %in% c(0L, 2L)))
})

test_that("more uncertainty makes a safe seat less certain", {
  sh <- matrix(c(52, 30, 18), nrow = 1,
               dimnames = list("safe", c("ALP","LNP","GRN")))
  tight <- simulate_seat_contests(sh, fake_matrix(),
                                  party_sd = c(ALP=1,LNP=1,GRN=1),
                                  seat_sd = 1, n_sims = 400, seed = 5)
  loose <- simulate_seat_contests(sh, fake_matrix(),
                                  party_sd = c(ALP=9,LNP=9,GRN=3),
                                  seat_sd = 9, n_sims = 400, seed = 5)
  p <- function(r) r$prob[r$seat == "safe" & r$party == "ALP"]
  expect_gt(p(tight$win_prob), p(loose$win_prob))
})

test_that("the fallback rate is reported, not hidden", {
  sh <- matrix(c(35, 33, 20, 12), nrow = 1,
               dimnames = list("s", c("ALP","LNP","GRN","ONP")))
  r <- simulate_seat_contests(sh, fake_matrix(),   # matrix knows nothing of ONP
                              party_sd = c(ALP=0,LNP=0,GRN=0,ONP=0),
                              seat_sd = 0, n_sims = 10, seed = 6)
  expect_gt(r$fallback_rate, 0)
  expect_lte(r$fallback_rate, 1)
})

test_that("it is reproducible and refuses unnamed input", {
  sh <- matrix(c(40,38,22), nrow = 1,
               dimnames = list("s", c("ALP","LNP","GRN")))
  a <- simulate_seat_contests(sh, fake_matrix(), c(ALP=2,LNP=2,GRN=2),
                              n_sims = 50, seed = 9)
  b <- simulate_seat_contests(sh, fake_matrix(), c(ALP=2,LNP=2,GRN=2),
                              n_sims = 50, seed = 9)
  expect_equal(a$totals, b$totals)
  bad <- matrix(c(40,38,22), nrow = 1)
  expect_error(simulate_seat_contests(bad, fake_matrix(), c(a=1)), "party names")
})

test_that("a flow cell for a party absent from these seats is skipped, not fatal", {
  # Historical transfer data contains exclusions of parties that do not
  # contest every seat being projected. Looking that party up with [[ threw
  # "subscript out of bounds" and killed the entire run rather than skipping
  # one unusable cell. Caught in review.
  m <- build_flow_matrix(data.table::data.table(
    election = "x", seat = rep(c("a","b","c"), each = 2), round = 1L,
    from = "FF",                       # a party none of the seats below field
    to = rep(c("ALP","LNP"), 3),
    votes = c(900,100, 850,150, 800,200)), min_n = 2L)
  sh <- matrix(c(38, 40, 22), nrow = 1,
               dimnames = list("seat1", c("ALP","LNP","GRN")))
  expect_no_error(
    r <- simulate_seat_contests(sh, m, party_sd = c(ALP=0, LNP=0, GRN=0),
                                seat_sd = 0, n_sims = 5, seed = 1))
  expect_equal(sum(r$totals), 5L)
})
