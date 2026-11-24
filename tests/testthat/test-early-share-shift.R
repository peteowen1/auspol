# AUSPOL_DEMO_RESID_EARLY: Labor's shift from the previous election's early-vote share
# (R/demographic_residual.R, plans/prereg-early-share-labor-2026-11-24.md). Synthetic tables only: no output/ files.

.es_fixture <- function(slope = -0.8, seed = 1L) {
  set.seed(seed)
  pairs <- c("fed2013", "vic2014", "fed2016", "vic2018", "fed2019", "vic2022")
  tab <- data.table::rbindlist(lapply(pairs, function(p) {
    data.table::data.table(pair = p, seat = sprintf("S%02d", 1:60), prev_early = 20 + 8 * stats::rnorm(60))
  }))
  tr <- data.table::copy(tab)
  tr[, z := (prev_early - mean(prev_early)) / stats::sd(prev_early), by = pair]
  tr[, `:=`(party = "ALP", xgb_pred = 35, actual_share = 35 + slope * z + stats::rnorm(.N, sd = 2))]
  list(tab = tab, training = tr[, c("pair", "seat", "party", "actual_share", "xgb_pred"), with = FALSE])
}

test_that("the slope is recovered from earlier elections only, and shrunk toward zero", {
  fx <- .es_fixture()
  fit <- auspol:::early_share_slope("vic2022", fx$training, census = "no-such-file.csv", feats = character(0), es_tab = fx$tab)
  expect_equal(fit$n_el, 5L)                       # vic2022 itself is not in its own training rows
  expect_equal(fit$n, 300L)
  expect_lt(abs(fit$b - (-0.8)), 0.3)
  expect_true(fit$w > 0 && fit$w < 1)
  expect_lt(abs(fit$b_shrunk), abs(fit$b))
  # fewer than three earlier elections: no slope, not a guess
  expect_null(auspol:::early_share_slope("fed2016", fx$training, "no-such-file.csv", character(0), fx$tab))
})

test_that("a deliberately broken input changes the answer: no signal keeps almost nothing", {
  fx <- .es_fixture(slope = 0, seed = 7L)
  fit <- auspol:::early_share_slope("vic2022", fx$training, "no-such-file.csv", character(0), fx$tab)
  expect_lt(abs(fit$b_shrunk), 0.25)
  fx2 <- .es_fixture(slope = -0.8)
  fit2 <- auspol:::early_share_slope("vic2022", fx2$training, "no-such-file.csv", character(0), fx2$tab)
  expect_lt(fit2$b_shrunk, -0.4)
})

test_that("shifts sum to zero, an uncovered seat gets exactly zero, and off means NULL", {
  fx <- .es_fixture()
  seats <- c(sprintf("S%02d", 1:60), "Brand New Seat")
  withr::local_envvar(AUSPOL_DEMO_RESID_EARLY = "1")
  out <- NULL
  expect_output(out <- auspol:::early_share_adjust(seats, "vic2022", fx$training, "no-such-file.csv", character(0), tab = fx$tab), "DRE1")
  expect_length(out$adj, 61L)
  expect_equal(sum(out$adj), 0, tolerance = 1e-9)
  expect_identical(out$adj[61], 0)
  expect_equal(out$covered, 60L)
  # an election with no previous early share on file: nothing, so its forecast is unchanged
  expect_output(none <- auspol:::early_share_adjust(seats, "sa2026", fx$training, "no-such-file.csv", character(0), tab = fx$tab), "no previous early share")
  expect_null(none)
  withr::local_envvar(AUSPOL_DEMO_RESID_EARLY = "0")
  expect_null(auspol:::early_share_adjust(seats, "vic2022", fx$training, "no-such-file.csv", character(0), tab = fx$tab))
})

test_that("the placebo permutes the column, and a bad switch value stops", {
  fx <- .es_fixture()
  seats <- sprintf("S%02d", 1:60)
  withr::local_envvar(AUSPOL_DEMO_RESID_EARLY = "1")
  real <- suppressMessages({ utils::capture.output(r <- auspol:::early_share_adjust(seats, "vic2022", fx$training, "x.csv", character(0), tab = fx$tab)); r })
  withr::local_envvar(AUSPOL_DEMO_RESID_EARLY = "shuffle")
  utils::capture.output(plc <- auspol:::early_share_adjust(seats, "vic2022", fx$training, "x.csv", character(0), tab = fx$tab))
  expect_false(isTRUE(all.equal(real$adj, plc$adj)))
  expect_lt(abs(plc$fit$b), abs(real$fit$b))
  withr::local_envvar(AUSPOL_DEMO_RESID_EARLY = "yes")
  expect_error(auspol:::early_share_mode(), "must be")
})
