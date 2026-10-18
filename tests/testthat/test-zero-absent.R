# Not-standing classes take no votes (AUSPOL_ZERO_ABSENT). docs/plans/prereg-zero-absent-2026-10-17.md

za_fm <- function() {
  build_flow_matrix(data.table::data.table(
    election = "x", seat = rep(c("a", "b", "c"), each = 2), round = 1L,
    from = c("GRN", "GRN", "ONP", "ONP", "LNP", "LNP"),
    to = c("ALP", "LNP", "ALP", "LNP", "ALP", "GRN"),
    votes = c(800, 200, 300, 700, 900, 100)), min_n = 1L)
}
# ONP does not stand in s1 or s2 (0%), stands in s3
za_sh <- function() matrix(c(45, 45, 10, 0,  40, 42, 18, 0,  30, 35, 10, 25), nrow = 3, byrow = TRUE,
                           dimnames = list(c("s1", "s2", "s3"), c("ALP", "LNP", "GRN", "ONP")))
za_args <- function() list(za_sh(), za_fm(), party_sd = c(ALP = 2, LNP = 2, GRN = 1.5, ONP = 1), seat_sd = 3,
                           level_sd = c(1.1, 8.67), n_sims = 400, seed = 3, keep_fp = TRUE,
                           shrink = c(s1 = 0.05, s2 = 0.1, s3 = 0.2), flow_sd = 3, fallback_smooth = 0.3, smooth = 0.1)

test_that("a class at 0% gets no votes in any draw with the switch on, and some without it", {
  on <- do.call(simulate_seat_contests, c(za_args(), list(zero_absent = TRUE, engine = "cpp")))
  off <- do.call(simulate_seat_contests, c(za_args(), list(zero_absent = FALSE, engine = "cpp")))
  fp_on <- on$fp_draws; fp_off <- off$fp_draws
  expect_false(is.null(fp_on))
  onp <- function(fp, seat) fp[, seat, "ONP"]
  expect_true(all(onp(fp_on, "s1") == 0) && all(onp(fp_on, "s2") == 0))
  expect_true(any(onp(fp_off, "s1") > 0))                     # the phantom this removes
  expect_true(any(onp(fp_on, "s3") > 0))                      # a standing class is untouched
  # the first draw of the first seat comes before any count: same noise, only the phantom removed, so the
  # ratio of the standing classes is unchanged (shares are normalised, so the levels are not). After the first
  # count the streams part: a phantom's exclusion used to consume flow-noise draws.
  expect_equal(fp_on[1, "s1", "ALP"] / fp_on[1, "s1", "LNP"], fp_off[1, "s1", "ALP"] / fp_off[1, "s1", "LNP"])
  expect_true(on$zero_absent); expect_false(off$zero_absent)
})

test_that("the compiled core is byte-identical to the R engine with zero_absent on", {
  strip <- function(x) { x$engine <- NULL; x }
  r <- do.call(simulate_seat_contests, c(za_args(), list(zero_absent = TRUE, engine = "r")))
  cc <- do.call(simulate_seat_contests, c(za_args(), list(zero_absent = TRUE, engine = "cpp")))
  expect_identical(strip(cc), strip(r))
})

test_that("zero_absent defaults to the switch, off unless set", {
  withr::local_envvar(AUSPOL_ZERO_ABSENT = "0"); expect_false(zero_absent_on())
  withr::local_envvar(AUSPOL_ZERO_ABSENT = "1"); expect_true(zero_absent_on())
  withr::local_envvar(AUSPOL_ZERO_ABSENT = "yes"); expect_error(zero_absent_on(), "must be")
  withr::local_envvar(AUSPOL_ZERO_ABSENT = NA); expect_false(zero_absent_on())
})
