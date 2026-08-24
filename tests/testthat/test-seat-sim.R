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

test_that("seat TCP is retained: winner, runner-up and share", {
  sh <- matrix(c(40, 38, 22), nrow = 1,
               dimnames = list("s", c("ALP","LNP","GRN")))
  r <- simulate_seat_contests(sh, fake_matrix(), c(ALP=2,LNP=2,GRN=2),
                              seat_sd = 2, n_sims = 100, seed = 11)
  expect_false(anyNA(r$tcp_winner))
  expect_false(anyNA(r$tcp_runnerup))
  # the winner's share of the two-candidate-preferred total is, by
  # definition of "winner", never below half
  expect_true(all(r$tcp_share >= 0.5 & r$tcp_share <= 1))
  expect_true(all(r$tcp_winner[, "s"] != r$tcp_runnerup[, "s"]))
})

test_that("an uncontested seat has no TCP pair to report", {
  sh <- matrix(c(100, 0, 0), nrow = 1,
               dimnames = list("safe", c("ALP","LNP","GRN")))
  r <- simulate_seat_contests(sh, fake_matrix(), c(ALP=0,LNP=0,GRN=0),
                              seat_sd = 0, n_sims = 20, seed = 12)
  expect_true(all(is.na(r$tcp_winner)))
  expect_true(all(is.na(r$tcp_runnerup)))
  expect_true(all(is.na(r$tcp_share)))
})

test_that("tcp_winner reflects the vote count, not the shrink coin toss", {
  # ALP leads the count in every draw (60 vs 40, no noise), so tcp_winner
  # must be ALP throughout -- but shrink = 0.99 coin-tosses the party
  # CREDITED as winner in wins/totals almost every draw, so that should land
  # close to 50/50. If a future edit reordered the shrink toss ahead of the
  # TCP write, tcp_winner would track the coin toss instead and this fails.
  sh <- matrix(c(60, 40), nrow = 1, dimnames = list("s", c("ALP","LNP")))
  r <- simulate_seat_contests(sh, fake_matrix(), party_sd = c(ALP=0, LNP=0),
                              seat_sd = 0, n_sims = 200, seed = 20, shrink = 0.99)
  expect_true(all(r$tcp_winner[, "s"] == "ALP"))
  expect_gt(sum(r$totals[, "LNP"]), 60)
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

test_that("supplied statewide draws drive the result instead of party_sd", {
  # Drawing each party independently inside the simulator and renormalising
  # destroys the Labor-versus-Coalition covariance: measured against the real
  # projection it reproduced only 60% of the two-party spread and centred 1.2
  # points too favourable to Labor, making the seat range about 40% too tight.
  # A caller with a calibrated statewide distribution must be able to hand it
  # over whole.
  #
  # Draws are applied as a DEVIATION from their own centre, because `shares`
  # already carries each seat's central projection. So the test moves the state
  # in opposite directions across two halves of the run and checks the seats
  # follow.
  sh <- matrix(rep(c(40, 38, 22), 2), nrow = 2, byrow = TRUE,
               dimnames = list(c("s1","s2"), c("ALP","LNP","GRN")))
  n <- 50
  half <- c(rep(10, n/2), rep(-10, n/2))       # ALP up, then ALP down
  d <- cbind(ALP = 40 + half, LNP = 38 - half, GRN = rep(22, n))

  r <- simulate_seat_contests(sh, fake_matrix(),
                              party_sd = c(ALP = 9, LNP = 9, GRN = 9),
                              seat_sd = 0, n_sims = n, seed = 3,
                              statewide_draws = d)
  alp <- r$totals[, "ALP"]
  expect_true(all(alp[1:(n/2)] == 2L))          # Labor ahead: wins both
  expect_true(all(alp[(n/2 + 1):n] == 0L))      # Labor behind: wins neither
  # party_sd is 9 points and would swamp this if it were still being applied
  expect_equal(sum(r$totals), 2L * n)
})

test_that("malformed statewide draws are refused", {
  sh <- matrix(c(40, 38, 22), nrow = 1,
               dimnames = list("s", c("ALP","LNP","GRN")))
  expect_error(
    simulate_seat_contests(sh, fake_matrix(), c(ALP=1,LNP=1,GRN=1), n_sims = 10,
                           statewide_draws = cbind(ALP=1:5, LNP=1:5, GRN=1:5)),
    "n_sims rows")
  expect_error(
    simulate_seat_contests(sh, fake_matrix(), c(ALP=1,LNP=1,GRN=1), n_sims = 5,
                           statewide_draws = cbind(ALP=1:5, LNP=1:5)),
    "missing column")
})
