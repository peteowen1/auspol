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

# ---- level_mult: the per-class slope multiplier ----------------------------
# Pre-registered in docs/plans/prereg-class-specific-variance.md. Every one of
# these is a dry-run case named in that document BEFORE any arm ran.

test_that("level_mult = NULL and an all-ones vector are both exact no-ops", {
  m <- mk()
  P <- colnames(m$shares)
  run <- function(...) simulate_seat_contests(m$shares, m$fm, m$psd, seat_sd = 3.5,
                                              level_sd = c(1.10, 8.67),
                                              n_sims = 200, seed = 42, ...)$win
  a <- run()
  expect_equal(a, run(level_mult = stats::setNames(rep(1, length(P)), P)))
  # A PARTIAL vector must also be a no-op: absent parties take 1.
  expect_equal(a, run(level_mult = c(IND = 1)))
})

test_that("a non-unit multiplier actually changes the answer", {
  # A parameter that cannot move the output is dead code, and an arm that
  # silently did not apply looks exactly like an arm with no effect.
  m <- mk()
  run <- function(...) simulate_seat_contests(m$shares, m$fm, m$psd, seat_sd = 3.5,
                                              level_sd = c(1.10, 8.67),
                                              n_sims = 200, seed = 42, ...)$win
  expect_false(isTRUE(all.equal(run(), run(level_mult = c(IND = 2)))))
})

test_that("level_mult refuses the inputs that would fail silently", {
  m <- mk()
  run <- function(...) simulate_seat_contests(m$shares, m$fm, m$psd, seat_sd = 3.5,
                                              level_sd = c(1.10, 8.67),
                                              n_sims = 50, seed = 42, ...)
  # A name that is not a share column is a typo, and a typo that were tolerated
  # would produce an arm indistinguishable from one that made no difference.
  expect_error(run(level_mult = c(NOPE = 1.5)), "no such party")
  expect_error(run(level_mult = 2), "named vector")
  expect_error(run(level_mult = c(IND = 1, IND = 2)), "unique names")
  expect_error(run(level_mult = c(IND = -1)), "non-negative")
  # Without level_sd there is no slope to multiply, so this is a user error
  # rather than a quiet no-op.
  expect_error(simulate_seat_contests(m$shares, m$fm, m$psd, seat_sd = 3.5,
                                      level_sd = NULL, n_sims = 50, seed = 42,
                                      level_mult = c(IND = 2)),
               "no effect without")
})

test_that("level_mult_for puts every class in the right bucket", {
  P <- c("ALP", "LNP", "NAT", "GRN", "IND", "ONP", "OTH_RIGHT")
  v <- level_mult_for(P, m_ind = 2, m_oth = 1.5)
  expect_equal(unname(v[c("ALP", "LNP", "NAT")]), c(1, 1, 1))
  expect_equal(unname(v[["IND"]]), 2)
  expect_equal(unname(v[c("GRN", "ONP", "OTH_RIGHT")]), c(1.5, 1.5, 1.5))
  # NULL when both are 1, so the no-op reaches simulate_seat_contests() as NULL
  # rather than as a vector that merely behaves like one.
  expect_null(level_mult_for(P))
  # A party the seat file does not carry must not appear, or the multiplier
  # would be rejected downstream for naming a column that is not there.
  expect_equal(names(level_mult_for(c("ALP", "IND"), 2, 1.5)), c("ALP", "IND"))
})
