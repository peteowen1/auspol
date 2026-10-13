test_that("jurisdiction_of strips the year", {
  expect_identical(jurisdiction_of(c("wa2017", "fed2025", "NT2024", "act2020")),
                   c("wa", "fed", "nt", "act"))
})

test_that("pool_by_group: no between-group spread gives everyone the common centre", {
  x <- c(0.30, 0.32, 0.28, 0.31, 0.29, 0.30)
  g <- c("a", "a", "a", "b", "b", "b")
  p <- pool_by_group(x, g, "a")
  expect_equal(p$tau2, 0)
  expect_equal(p$estimate, p$mu)
  expect_equal(p$groups$w, c(0, 0))
})

test_that("pool_by_group: a target group with no cases gets mu", {
  p <- pool_by_group(c(0.2, 0.3, 0.6, 0.7), c("a", "a", "b", "b"), "wa")
  expect_equal(p$estimate, p$mu)
  expect_identical(p$n_target, 0L)
})

test_that("pool_by_group: well-separated, well-measured groups keep their own centres", {
  set.seed(1)
  x <- c(0.2 + stats::rnorm(30, 0, 0.01), 0.6 + stats::rnorm(30, 0, 0.01), 0.4 + stats::rnorm(30, 0, 0.01))
  g <- rep(c("a", "b", "c"), each = 30)
  p <- pool_by_group(x, g, "b")
  expect_gt(p$tau2, 0)
  expect_equal(p$estimate, stats::median(x[g == "b"]), tolerance = 0.005)
})

test_that("pool_by_group: shrunk estimate lies between the group centre and mu", {
  x <- c(0.1, 0.5, 0.3, 0.6, 0.9, 0.2, 0.25, 0.8)
  g <- c("a", "a", "b", "b", "b", "c", "c", "c")
  for (t in c("a", "b", "c")) {
    p <- pool_by_group(x, g, t)
    est <- p$groups$est[p$groups$group == t]
    expect_true(p$estimate >= min(est, p$mu) - 1e-12 && p$estimate <= max(est, p$mu) + 1e-12)
  }
})

test_that("pool_by_group: empty and non-finite input give NA, never an error", {
  p <- pool_by_group(numeric(), character(), "wa")
  expect_true(is.na(p$estimate))
  p2 <- pool_by_group(c(NA, Inf, 0.3), c("a", "a", "b"), "b")
  expect_identical(p2$n, 1L)
  expect_equal(p2$estimate, 0.3)
  expect_error(pool_by_group(1:3, c("a", "b"), "a"), "differ in length")
})

# THE DELIBERATELY BROKEN INPUT. One jurisdiction arrives with many extreme cases
# (the shape NT gave the defector carry on 2026-10-13). It must not move another
# jurisdiction's estimate by more than its one-group share of the gap: with G
# groups after it arrives, (1/G) of the distance between the newcomer's centre
# and the target's own centre. The case-level median -- what the switch replaces
# -- is shown to break the same bound, so the bound has teeth.
test_that("pool_by_group: a many-case extreme group moves another group by at most its one-group share", {
  base_x <- c(0.25, 0.30, 0.28, 0.20, 0.33, 0.27, 0.22, 0.31)
  base_g <- c("wa", "wa", "wa", "vic", "vic", "vic", "fed", "fed")
  ext_x  <- c(0.85, 0.88, 0.90, 0.87, 0.86, 0.89, 0.92, 0.84, 0.91, 0.88, 0.90, 0.86)
  ext_g  <- rep("nt", length(ext_x))
  before <- pool_by_group(base_x, base_g, "wa")
  after  <- pool_by_group(c(base_x, ext_x), c(base_g, ext_g), "wa")
  G <- 4
  gap <- stats::median(ext_x) - before$groups$est[before$groups$group == "wa"]
  bound <- abs(gap) / G
  expect_lte(abs(after$estimate - before$estimate), bound)
  # the old case-level median breaks the bound on the same input
  naive_move <- abs(stats::median(c(base_x, ext_x)) - stats::median(base_x))
  expect_gt(naive_move, bound)
  # and the extreme group itself is still allowed to be extreme
  nt <- pool_by_group(c(base_x, ext_x), c(base_g, ext_g), "nt")
  expect_gt(nt$estimate, 0.7)
})

test_that("AUSPOL_POOL_BY_JURISDICTION: '0' leaves the defector fits unchanged, '1' pools them", {
  f <- out_path("candidacies.csv")
  skip_if_not(file.exists(f), "no candidacies corpus")
  C <- data.table::fread(f, showProgress = FALSE)
  run <- function(sw, fn, t) withr::with_envvar(c(AUSPOL_POOL_BY_JURISDICTION = sw), {
    utils::capture.output(r <- fn(t, corpus = C)); r })
  unset <- withr::with_envvar(c(AUSPOL_POOL_BY_JURISDICTION = NA), {
    utils::capture.output(r <- fit_defector_discount("wa2017", corpus = C)); r })
  off <- run("0", fit_defector_discount, "wa2017")
  expect_identical(off, unset)
  on <- run("1", fit_defector_discount, "wa2017")
  expect_false(is.null(on$by_jurisdiction))
  expect_identical(on$by_jurisdiction$mp$target_group, "wa")
  expect_true(is.finite(on$discount_mp) && is.finite(on$discount_loser))
  # the switch must reach the sitting-minor fit too
  expect_false(is.null(run("1", fit_sitting_minor_level, "wa2017")$by_jurisdiction))
  expect_null(run("0", fit_sitting_minor_level, "wa2017")$by_jurisdiction)
})

test_that("pool_by_group: the bound holds whatever the newcomer's case count", {
  base_x <- c(0.25, 0.30, 0.28, 0.20, 0.33, 0.27, 0.22, 0.31, 0.29)
  base_g <- rep(c("wa", "vic", "fed"), each = 3)
  before <- pool_by_group(base_x, base_g, "wa")$estimate
  for (k in c(1L, 3L, 10L, 50L)) {
    ext_x <- rep(0.9, k) + seq(-0.01, 0.01, length.out = k)
    after <- pool_by_group(c(base_x, ext_x), c(base_g, rep("nt", k)), "wa")$estimate
    expect_lte(abs(after - before), abs(0.9 - stats::median(c(0.25, 0.30, 0.28))) / 4)
  }
})
