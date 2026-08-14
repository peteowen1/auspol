# Seat model: statewide two-party vote to a seat count.

fake_seats <- function(margins = seq(-20, 20, by = 2), incumbent = NULL) {
  n <- length(margins)
  if (is.null(incumbent)) incumbent <- ifelse(margins > 0, "ALP", "LNP")
  data.table::data.table(
    seat = paste0("Seat", seq_len(n)),
    incumbent = incumbent,
    challenger = ifelse(incumbent == "ALP", "LNP", "ALP"),
    seat_region = "R", margin = margins,
    prev_swing = rep(0, n), classic = TRUE)
}

test_that("margins are Labor's, not the incumbent's", {
  # A Coalition seat carries a NEGATIVE margin; reading it as the incumbent's
  # and flipping the sign gave Labor 82 of 83 seats at zero swing against an
  # actual 56 of 88.
  s <- fake_seats(margins = c(10, -10))
  expect_equal(seat_alp_tpp(s), c(60, 40))
})

test_that("load_seats parses the Victorian configuration", {
  skip_if_no_anchor()
  s <- load_seats(2026, "vic")
  expect_equal(nrow(s), 88)
  expect_true(all(c("seat", "incumbent", "challenger", "margin",
                    "classic") %in% names(s)))
  expect_true(all(is.finite(s$margin)))
  expect_gt(sum(s$classic), 70)
  expect_gt(sum(!s$classic), 0)
  expect_true("Richmond" %in% s$seat)
})

test_that("zero swing reproduces the last Victorian result", {
  skip_if_no_anchor()
  s <- load_seats(2026, "vic")
  sim <- simulate_seats(s, tpp_mean = 55.0, tpp_sd = 0, prev_tpp = 55.0,
                        seat_sd = 4.2, n_sims = 5000, seed = 1)
  expect_lt(abs(stats::median(sim$seats_won) - 56), 4)
  expect_equal(sim$n_classic + sim$n_nonclassic, 88)
})

test_that("seat_swing_spread centres near zero on real data", {
  skip_if_no_anchor()
  s <- load_seats(2026, "vic")
  sp <- seat_swing_spread(s, 55.00 - 57.60)
  expect_lt(abs(sp$mean_dev), 1.5)   # statewide swing is the seats' average
  expect_gt(sp$sd, 2); expect_lt(sp$sd, 6)
  expect_equal(sp$n, 88)
})

test_that("seat count rises monotonically with the two-party vote", {
  s <- fake_seats()
  meds <- vapply(c(42, 46, 50, 54, 58), function(v)
    stats::median(simulate_seats(s, v, 0, 50, 2, n_sims = 3000,
                                 seed = 7)$seats_won), numeric(1))
  expect_true(all(diff(meds) >= 0))
  expect_lt(meds[1], meds[5])
})

test_that("statewide uncertainty widens the seat distribution", {
  s <- fake_seats()
  tight <- simulate_seats(s, 50, 0.1, 50, 2, n_sims = 5000, seed = 3)
  loose <- simulate_seats(s, 50, 4.0, 50, 2, n_sims = 5000, seed = 3)
  expect_gt(stats::sd(loose$seats_won), stats::sd(tight$seats_won))
})

test_that("win probabilities are bounded and ordered by margin", {
  s <- fake_seats()
  sim <- simulate_seats(s, 50, 1, 50, 2, n_sims = 5000, seed = 5)
  p <- sim$by_seat
  expect_true(all(p$alp_win_prob >= 0 & p$alp_win_prob <= 1))
  # Safer Labor seats must not be less likely to be won than weaker ones
  expect_false(is.unsorted(rev(p$alp_win_prob)))
  expect_gt(p$alp_win_prob[1], p$alp_win_prob[nrow(p)])
})

test_that("simulate_seats is reproducible and refuses an all-nonclassic set", {
  s <- fake_seats()
  a <- simulate_seats(s, 50, 1, 50, 2, n_sims = 1000, seed = 11)
  b <- simulate_seats(s, 50, 1, 50, 2, n_sims = 1000, seed = 11)
  expect_equal(a$seats_won, b$seats_won)

  s2 <- data.table::copy(s)
  s2[, classic := FALSE]
  expect_error(simulate_seats(s2, 50, 1, 50, 2), "No classic")
})
