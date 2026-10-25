# AUSPOL_SURGE_LEVEL: a fired surge's draw read as the LEVEL the recipient
# reaches, not an amount added (R/surge_level.R, src/seat_sim_core.cpp).
# docs/plans/prereg-surge-level-2026-10-25.md. Synthetic data only.

sl_fixture <- function() {
  sh <- matrix(c(38, 30, 12, 20,  45, 35, 15, 5,  30, 30, 25, 15), nrow = 3, byrow = TRUE,
               dimnames = list(c("s1", "s2", "s3"), c("ALP", "LNP", "GRN", "IND")))
  fm <- build_flow_matrix(data.table::data.table(
    election = "x", seat = rep(c("a", "b", "c", "d"), each = 3), round = 1L,
    from = c("GRN", "GRN", "GRN", "IND", "IND", "IND", "GRN", "GRN", "GRN", "IND", "IND", "IND"),
    to = c("ALP", "LNP", "IND", "ALP", "LNP", "GRN", "ALP", "LNP", "IND", "ALP", "LNP", "GRN"),
    votes = c(700, 200, 100, 300, 500, 200, 650, 250, 100, 350, 450, 200)), min_n = 2L)
  list(shares = sh, matrix = fm, party_sd = c(ALP = 2, LNP = 2, GRN = 1.5, IND = 1), seat_sd = 3,
       n_sims = 300, seed = 11, surge_h = c(0.6, 0, 0.5), surge_mu = 30, surge_sd = 8,
       surge_party = c(s1 = "IND", s2 = NA, s3 = "GRN"), keep_fp = TRUE)
}
sl_strip <- function(r) r[c("win_prob", "totals", "tcp_winner", "tcp_runnerup", "tcp_share", "fallback_rate", "fp_draws")]
sl_sim <- function(a, ...) {
  out <- NULL
  utils::capture.output(out <- do.call(simulate_seat_contests, c(a, list(...))))
  out
}
# The check every level-rule test relies on: the recipient never ends below
# where it started, the draw keeps its total, and nothing goes negative.
sl_ok <- function(before, after, j) {
  all(after[j] >= before[j] - 1e-9) && abs(sum(after) - sum(before)) < 1e-9 && all(after >= -1e-12)
}
sl_apply <- function(v, j, level) {
  add <- surge_level_gain(v, j, level)
  if (add > 0) {
    pool <- sum(v[-j])
    if (pool > add) { v[-j] <- v[-j] * (pool - add) / pool; v[j] <- v[j] + add }
  }
  v
}

test_that("the check fails on a deliberately broken level rule before it is trusted to pass", {
  v <- c(ALP = 20, LNP = 20, ONP = 60)
  broken <- v; broken["ONP"] <- 40; broken[c("ALP", "LNP")] <- 30   # sets to L, LOWERING the recipient
  expect_false(sl_ok(v, broken, 3L))
  neg <- c(ALP = -5, LNP = 45, ONP = 60)                              # keeps the total, goes negative
  expect_false(sl_ok(v, neg, 3L))
  leak <- c(ALP = 20, LNP = 20, ONP = 70)                             # raises, does not take it from anyone
  expect_false(sl_ok(v, leak, 3L))
  expect_true(sl_ok(v, sl_apply(v, 3L, 40), 3L))
})

test_that("surge_level_gain never lowers the recipient, keeps the total and leaves nobody negative", {
  set.seed(5)
  for (t in 1:500) {
    k <- sample(2:6, 1); v <- stats::rexp(k) * stats::runif(1, 50, 120); v[sample.int(k, 1)] <- 0
    j <- sample.int(k, 1); L <- stats::rnorm(1, 34, 15)
    g <- surge_level_gain(v, j, L)
    expect_gte(g, 0)
    expect_equal(g, max(0, L / 100 * sum(v) - v[j]))
    expect_true(sl_ok(v, sl_apply(v, j, L), j))
  }
  # already above its level: unchanged
  expect_identical(surge_level_gain(c(20, 20, 60), 3L, 40), 0)
  # below it: lifted exactly to the level, as a share of the draw's own total
  v2 <- sl_apply(c(30, 60, 10), 3L, 40)
  expect_equal(v2[3] / sum(v2), 0.40)
  expect_equal(v2[1] / v2[2], 0.5)
})

test_that("bad inputs are refused, not silently ignored", {
  expect_error(surge_level_gain(c(10, -1, 5), 1L, 30), "non-negative")
  expect_error(surge_level_gain(c(10, NA, 5), 1L, 30), "non-negative")
  expect_error(surge_level_gain(c(10, 1, 5), 4L, 30), "index")
  expect_error(surge_level_gain(c(10, 1, 5), 1L, NA_real_), "finite")
  a <- sl_fixture()
  expect_error(sl_sim(a, surge_level = NA), "TRUE or FALSE")
  expect_error(sl_sim(a, surge_level = c(TRUE, FALSE)), "TRUE or FALSE")
  withr::with_envvar(c(AUSPOL_SURGE_LEVEL = "2"), expect_error(surge_level_on(), "must be"))
  withr::with_envvar(c(AUSPOL_SURGE_LEVEL = "1", AUSPOL_IND_MIXTURE = "1"),
                     expect_error(surge_level_on(), "GAIN"))
  withr::with_envvar(c(AUSPOL_SURGE_LEVEL = "1", AUSPOL_XGB_SURGE = "1", AUSPOL_IND_MIXTURE = "0"),
                     expect_error(surge_level_on(), "GAIN"))
  withr::with_envvar(c(AUSPOL_SURGE_LEVEL = "1", AUSPOL_XGB_SURGE = "0", AUSPOL_IND_MIXTURE = "0"),
                     expect_true(surge_level_on()))
  withr::with_envvar(c(AUSPOL_SURGE_LEVEL = NA), expect_false(surge_level_on()))
})

test_that("switch off is byte-identical to the engine before the switch existed, both engines", {
  # tests/testthat/fixtures/surge-level-off-ref.csv was written by the code at
  # 37ccddf (before AUSPOL_SURGE_LEVEL), from this exact fixture.
  ref <- utils::read.csv(test_path("fixtures", "surge-level-off-ref.csv"), colClasses = "character")
  a <- sl_fixture()
  for (eng in c("cpp", "r")) {
    withr::with_envvar(c(AUSPOL_SURGE_LEVEL = NA), r0 <- sl_sim(a, engine = eng))   # the default
    r1 <- sl_sim(a, engine = eng, surge_level = FALSE)
    expect_identical(sl_strip(r0), sl_strip(r1))
    expect_null(r1$surge_level_raised)
    rf <- ref[ref$engine == eng, ]
    wp <- r1$win_prob
    expect_identical(paste(wp$seat, wp$party), rf$key[rf$kind == "win"])
    expect_identical(wp$prob, as.numeric(rf$value[rf$kind == "win"]))
    expect_identical(as.numeric(r1$totals), as.numeric(rf$value[rf$kind == "total"]))
    expect_identical(as.numeric(apply(r1$fp_draws, c(2, 3), mean)), as.numeric(rf$value[rf$kind == "fpmean"]))
  }
})

test_that("level on: the compiled core reproduces the R loop, and prints what it applied", {
  a <- sl_fixture()
  out_r <- utils::capture.output(rr <- do.call(simulate_seat_contests, c(a, list(engine = "r", surge_level = TRUE))))
  out_c <- utils::capture.output(rc <- do.call(simulate_seat_contests, c(a, list(engine = "cpp", surge_level = TRUE))))
  expect_identical(rr$engine, "r"); expect_identical(rc$engine, "cpp")
  rr$engine <- NULL; rc$engine <- NULL
  expect_identical(rr, rc)
  expect_identical(out_r, out_c)
  expect_match(out_c, "^SLV1 ", all = FALSE)
  expect_gt(sum(rc$surge_level_raised), 0L)
  expect_identical(unname(rc$surge_level_raised["s2"]), 0L)       # hazard 0: never fires
  expect_identical(unname(rc$surge_level_unchanged["s2"]), 0L)
  # and the rule actually moves something
  r0 <- sl_sim(a, engine = "cpp", surge_level = FALSE)
  expect_false(identical(r0$fp_draws[, "s1", ], rc$fp_draws[, "s1", ]))
  # nothing is printed with the switch off
  expect_false(any(grepl("SLV1", utils::capture.output(sl_sim(a, engine = "cpp", surge_level = FALSE)))))
})

test_that("level on: rows sum to 100, no negatives, a hazard-0 seat does not move", {
  a <- sl_fixture()
  for (eng in c("cpp", "r")) {
    on <- sl_sim(a, engine = eng, surge_level = TRUE)
    off <- sl_sim(a, engine = eng, surge_level = FALSE)
    fp <- on$fp_draws
    expect_true(all(abs(apply(fp, c(1, 2), sum) - 100) < 1e-9))
    expect_true(all(fp >= 0))
    # same random numbers in both modes, so the seat with no hazard is identical draw for draw
    expect_identical(on$fp_draws[, "s2", ], off$fp_draws[, "s2", ])
    # a level is never more than the same draw added on top of the recipient
    expect_true(all(on$fp_draws[, "s1", "IND"] <= off$fp_draws[, "s1", "IND"] + 1e-9))
  }
})

test_that("level on: a low recipient is lifted to the level, a high one is left exactly where it was", {
  sh <- matrix(c(40, 35, 5, 20,   25, 20, 10, 45), nrow = 2, byrow = TRUE,
               dimnames = list(c("lo", "hi"), c("ALP", "LNP", "GRN", "IND")))
  fm <- sl_fixture()$matrix
  base <- list(shares = sh, matrix = fm, party_sd = c(ALP = 1, LNP = 1, GRN = 0.5, IND = 0.5), seat_sd = 1,
               n_sims = 200, seed = 4, surge_h = c(1, 1), surge_sd = 0.01,
               surge_party = c(lo = "IND", hi = "IND"), keep_fp = TRUE)
  for (eng in c("cpp", "r")) {
    on <- sl_sim(c(base, list(surge_mu = 40)), engine = eng, surge_level = TRUE)
    # surge_mu = -100 draws the same random numbers but can never add anything:
    # the recipient's share as it stood before the surge, draw for draw
    pre <- sl_sim(c(base, list(surge_mu = -100)), engine = eng, surge_level = TRUE)
    expect_true(all(abs(on$fp_draws[, "lo", "IND"] - pmax(pre$fp_draws[, "lo", "IND"], 40)) < 0.05))
    expect_true(all(on$fp_draws[, "lo", "IND"] >= pre$fp_draws[, "lo", "IND"] - 1e-9))
    expect_identical(on$fp_draws[, "hi", ], pre$fp_draws[, "hi", ])     # 45 is above 40: untouched
    expect_identical(unname(on$surge_level_raised["lo"]), 200L)
    expect_identical(unname(on$surge_level_unchanged["hi"]), 200L)
    # the gain rule, for contrast, adds 40 on top of the 45
    gain <- sl_sim(c(base, list(surge_mu = 40)), engine = eng, surge_level = FALSE)
    expect_true(all(gain$fp_draws[, "hi", "IND"] > 75))
  }
})
