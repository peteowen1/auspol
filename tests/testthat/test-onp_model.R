# AUSPOL_ONP_ALLOC=model: One Nation's seat relativity from Senate share and Year 12 (R/onp_newseat.R).
# docs/plans/prereg-onp-direct-model-2026-11-22.md

mk_rows <- function(b_s = 0.6, b_y = -0.1, elections = c(a = 3, b = 8, c = 20), n = 60, seed = 1) {
  set.seed(seed)
  data.table::rbindlist(lapply(names(elections), function(e) {
    s <- stats::rnorm(n, 0, 0.5); s <- s - mean(s)
    y <- stats::rnorm(n); y <- (y - mean(y)) / stats::sd(y)
    data.table::data.table(election = e, seat = paste0(e, seq_len(n)), v = elections[[e]] * exp(b_s * s + b_y * y), s = s, y12 = y)
  }))
}

test_that("the switch reads rank by default and refuses a typo", {
  withr::local_envvar(AUSPOL_ONP_ALLOC = NA)
  expect_identical(onp_alloc_mode(), "rank")
  withr::local_envvar(AUSPOL_ONP_ALLOC = "model")
  expect_identical(onp_alloc_mode(), "model")
  withr::local_envvar(AUSPOL_ONP_ALLOC = "modle")
  expect_error(onp_alloc_mode(), "must be")
})

test_that("the fit recovers a known slope and Year 12 effect whatever each election's level", {
  f <- onp_model_fit("zz2099", rows = mk_rows(0.6, -0.1))
  expect_equal(f$b_s, 0.6, tolerance = 1e-6)
  expect_equal(f$b_y, -0.1, tolerance = 1e-6)
  expect_identical(f$n_elections, 3L)
  # the level does not leak into the slope: the same seats at 10 times the vote give the same answer
  f2 <- onp_model_fit("zz2099", rows = mk_rows(0.6, -0.1, elections = c(a = 30, b = 80, c = 200)))
  expect_equal(f2$b_s, f$b_s, tolerance = 1e-6)
})

test_that("a deliberately wrong slope is not what the fit returns", {
  f <- onp_model_fit("zz2099", rows = mk_rows(0.2, -0.3))
  expect_gt(abs(f$b_s - 0.6), 0.3)
  expect_equal(f$b_s, 0.2, tolerance = 1e-6)
})

test_that("fewer than two earlier elections is no fit, not a guess", {
  one <- mk_rows(elections = c(a = 5))
  expect_null(onp_model_fit("zz2099", rows = one))
  expect_null(onp_model_fit("zz2099", rows = one[0]))
})

test_that("ratios average 1, follow the Senate share, and fall with Year 12", {
  fit <- list(b_s = 0.5, b_y = -0.2, n_rows = 10L, n_elections = 3L, sources = "x", skipped = character(0))
  seats <- paste0("S", 1:6)
  cen <- data.table::data.table(pair = "zz2099", seat = seats, yr12_pct = c(40, 40, 40, 70, 70, 70))
  r <- onp_model_ratio(seats, c(2, 4, 8, 2, 4, 8), "zz2099", level = 20, fit = fit, census = cen)
  expect_equal(mean(r$ratio), 1)
  expect_identical(names(r$ratio), seats)
  expect_true(all(diff(r$ratio[1:3]) > 0))                 # more Senate vote, more One Nation
  expect_true(all(r$ratio[1:3] > r$ratio[4:6]))            # same Senate vote, higher Year 12, less One Nation
  expect_identical(r$no_census, 0L)
  # the level does not change the ratios in this form
  expect_equal(onp_model_ratio(seats, c(2, 4, 8, 2, 4, 8), "zz2099", level = 5, fit = fit, census = cen)$ratio, r$ratio)
})

test_that("a seat without census sits at the average, and too little census is no model", {
  fit <- list(b_s = 0.5, b_y = -0.2, n_rows = 10L, n_elections = 3L, sources = "x", skipped = character(0))
  seats <- paste0("S", 1:20)
  cen <- data.table::data.table(pair = "zz2099", seat = seats[-1], yr12_pct = seq(40, 78, length.out = 19))
  r <- onp_model_ratio(seats, rep(5, 20), "zz2099", level = 20, fit = fit, census = cen)
  expect_identical(r$no_census, 1L)
  expect_gt(r$ratio[["S1"]], min(r$ratio)); expect_lt(r$ratio[["S1"]], max(r$ratio))
  expect_null(onp_model_ratio(seats, rep(5, 20), "zz2099", level = 20, fit = fit, census = cen[1:10]))
  expect_error(onp_model_ratio(seats, c(NA, rep(5, 19)), "zz2099", level = 20, fit = fit, census = cen), "missing")
})

test_that("AUSPOL_ONP_IN_TRAINING takes the two One Nation switches out of the post-xgb list, and only those", {
  withr::local_envvar(AUSPOL_ONP_NEWSEAT_RULE = "1", AUSPOL_ONP_ORDER = "senate_rank", AUSPOL_ONP_IN_TRAINING = "0")
  off <- post_xgb_switches()
  expect_true(all(c("AUSPOL_ONP_NEWSEAT_RULE", "AUSPOL_ONP_ORDER") %in% names(off)))
  withr::local_envvar(AUSPOL_ONP_IN_TRAINING = "1")
  on <- post_xgb_switches()
  expect_false(any(c("AUSPOL_ONP_NEWSEAT_RULE", "AUSPOL_ONP_ORDER") %in% names(on)))
  expect_identical(on, off[!names(off) %in% c("AUSPOL_ONP_NEWSEAT_RULE", "AUSPOL_ONP_ORDER")])
  withr::local_envvar(AUSPOL_ONP_IN_TRAINING = "yes")
  expect_error(onp_in_training(), "must be")
})
