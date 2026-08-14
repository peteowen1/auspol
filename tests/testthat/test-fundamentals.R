# Fundamentals: the expected result knowing no current polling.

test_that("ragged anchor CSVs are read in full, not truncated", {
  skip_if_no_anchor()
  # Regression: fread STOPS EARLY on the first row carrying a trailing comment
  # field, which read 263 of eventual-results.csv's 421 lines and quietly
  # trained the model on 62% of the data.
  ev <- load_eventual_results()
  expect_gt(nrow(ev), 380)
  expect_true(all(c("fed", "nsw", "vic", "qld") %in% ev$region))
  expect_true("@TPP" %in% ev$party)
  # The comment-bearing row itself must be present and correctly parsed
  qld04 <- ev[which(ev$year == 2004 & ev$region == "qld" & ev$party == "@TPP"), ]
  expect_equal(nrow(qld04), 1)
  expect_equal(qld04$actual, 56.0)
})

test_that("ridge_loo recovers a known linear relationship", {
  set.seed(1)
  n <- 120
  X <- cbind(a = rnorm(n), b = rnorm(n), noise = rnorm(n))
  y <- 3 + 2 * X[, "a"] - 1.5 * X[, "b"] + rnorm(n, 0, 0.3)
  m <- ridge_loo(X, y)
  b <- setNames(m$beta, m$features)
  expect_gt(b["a"], 1.5); expect_lt(b["a"], 2.5)
  expect_lt(b["b"], -1.0); expect_gt(b["b"], -2.0)
  expect_lt(abs(b["noise"]), 0.4)
  expect_equal(length(m$loo_errors), n)
})

test_that("ridge_loo penalises harder when the signal is weaker", {
  set.seed(2)
  n <- 60
  X <- cbind(a = rnorm(n), b = rnorm(n))
  clean <- ridge_loo(X, 2 * X[, "a"] + rnorm(n, 0, 0.05))
  noisy <- ridge_loo(X, 2 * X[, "a"] + rnorm(n, 0, 8))
  expect_gt(noisy$lambda, clean$lambda)
})

test_that("build_fundamentals_data filters by party rather than returning all", {
  skip_if_no_anchor()
  # The data.table NSE trap: `dat[dat$party == party]` resolves the bare name
  # to the column, so every category came back with identical coefficients.
  dat <- build_fundamentals_data()
  expect_true(all(c("@TPP", "ALP", "LNP") %in% dat$party))
  n_tpp <- fit_fundamentals(dat, "@TPP")$n
  n_grn <- fit_fundamentals(dat, "GRN")$n
  expect_lt(n_grn, n_tpp)            # Greens have fewer usable elections
  expect_lt(n_tpp, nrow(dat))        # not simply the whole table
})

test_that("fundamentals beat the naive baselines on two-party vote", {
  skip_if_no_anchor()
  dat <- build_fundamentals_data()
  m <- fit_fundamentals(dat, "@TPP")
  expect_lt(m$loo_mae, m$baseline_prev1_mae)
  expect_lt(m$loo_mae, m$baseline_avg_mae)
  expect_gt(m$n, 40)
})

test_that("fundamentals coefficients carry the expected political signs", {
  skip_if_no_anchor()
  # Two effects that must appear if the model is picking up real structure:
  # a long-serving government loses ground ("it's time"), and a state party
  # whose federal counterpart governs is punished.
  dat <- build_fundamentals_data()
  m <- fit_fundamentals(dat, "@TPP")
  b <- setNames(m$beta, m$features)
  expect_lt(b["govt_years"], 0)
  expect_lt(b["fed_aligned"], 0)
  expect_gt(b["prev1"], 0)
})

test_that("an election with no result yet can still get a prediction", {
  skip_if_no_anchor()
  live <- build_fundamentals_data(polled_only = FALSE, require_actual = FALSE)
  row <- live[which(live$region == "vic" & live$year == 2026 &
                      live$party == "@TPP"), ]
  expect_equal(nrow(row), 1)
  expect_true(is.na(row$actual))
  expect_equal(row$prev1, 55.0)          # the 2022 Victorian result

  m <- fit_fundamentals(build_fundamentals_data(), "@TPP")
  p <- predict_fundamentals(m, row)
  expect_length(p, 1)
  expect_gt(p, 20); expect_lt(p, 80)
})

test_that("predict_fundamentals reproduces the fit on its own training rows", {
  skip_if_no_anchor()
  dat <- build_fundamentals_data()
  m <- fit_fundamentals(dat, "@TPP")
  p <- predict_fundamentals(m, m$data)
  # In-sample residuals must be no worse than the held-out ones
  expect_lt(mean(abs(p - m$data$actual)), m$loo_mae)
})
