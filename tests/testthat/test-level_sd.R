mk <- function() {
  sh <- matrix(c(45, 35, 12, 8,
                 38, 40, 15,  7,
                 50, 30, 12,  8), nrow = 3, byrow = TRUE,
               dimnames = list(c("A", "B", "C"), c("ALP", "LNP", "GRN", "IND")))
  # simulate_seat_contests() takes the whole build_flow_matrix() OBJECT, not a
  # bare matrix -- it reads $multiplicity off it, and `$` on an atomic vector
  # throws rather than returning NULL.
  tx <- data.frame(
    election = "e", seat = rep(c("A", "B", "C"), each = 3), round = 1L,
    from = c("IND", "GRN", "IND"), to = c("ALP", "ALP", "LNP"),
    votes = c(10, 20, 30), to_n = 1L)
  list(shares = sh, fm = build_flow_matrix(tx, min_n = 1L),
       psd = stats::setNames(rep(1.5, 4), colnames(sh)))
}

test_that("level_sd = NULL is byte-identical to the flat seat_sd", {
  m <- mk()
  a <- simulate_seat_contests(m$shares, m$fm, m$psd, seat_sd = 3.5,
                              n_sims = 200, seed = 42)
  b <- simulate_seat_contests(m$shares, m$fm, m$psd, seat_sd = 3.5, level_sd = NULL,
                              n_sims = 200, seed = 42)
  expect_equal(a$win, b$win)
})

test_that("level_sd = c(3.5, 0) also reproduces the flat behaviour", {
  # a + b*sqrt(p(1-p)) with b = 0 is the constant a, so this must match too --
  # the check that the FORM is right, not just that NULL short-circuits.
  m <- mk()
  a <- simulate_seat_contests(m$shares, m$fm, m$psd, seat_sd = 3.5,
                              n_sims = 200, seed = 42)
  b <- simulate_seat_contests(m$shares, m$fm, m$psd, seat_sd = 3.5,
                              level_sd = c(3.5, 0), n_sims = 200, seed = 42)
  expect_equal(a$win, b$win)
})

test_that("a non-zero slope actually changes the answer", {
  # A parameter that cannot move the output is dead code, and this repo has
  # already recorded a run that read as "this input does not matter".
  m <- mk()
  a <- simulate_seat_contests(m$shares, m$fm, m$psd, seat_sd = 3.5,
                              n_sims = 400, seed = 42)
  b <- simulate_seat_contests(m$shares, m$fm, m$psd, seat_sd = 3.5,
                              level_sd = c(1.10, 8.67), n_sims = 400, seed = 42)
  expect_false(isTRUE(all.equal(a$win, b$win)))
})

test_that("level_sd is validated rather than silently coerced", {
  m <- mk()
  expect_error(simulate_seat_contests(m$shares, m$fm, m$psd, level_sd = 3.5,
                                      n_sims = 50), "level_sd must be")
  expect_error(simulate_seat_contests(m$shares, m$fm, m$psd, level_sd = c(1, -2),
                                      n_sims = 50), "non-negative")
  expect_error(simulate_seat_contests(m$shares, m$fm, m$psd, level_sd = c(1, NA),
                                      n_sims = 50), "finite")
})
