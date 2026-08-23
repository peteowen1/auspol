# The one rule that must never be wrong, in the one place a forecast-mode
# backtest could break it. CLAUDE.md records three leakage bugs, one introduced
# while fixing another, so these prove the guard FAILS on the input it exists to
# catch before anything is trusted to pass it.

test_that("a cutoff on or after the election is refused", {
  expect_error(
    statewide_draws_as_at("vic", 2022, as_at = "2022-11-26",
                          election_date = "2022-11-26",
                          parties = c("ALP", "LNP"), n_sims = 10L),
    "cannot see its own result")
  expect_error(
    statewide_draws_as_at("vic", 2022, as_at = "2022-12-01",
                          election_date = "2022-11-26",
                          parties = c("ALP", "LNP"), n_sims = 10L),
    "cannot see its own result")
})

test_that("a cutoff before the election is allowed past the guard", {
  # Separated from the refusals above because this one reaches the anchor clone
  # for cycle boundaries, while the refusals fire before any data is loaded.
  # scripts/check_like_ci.R caught this: the test passed locally and would have
  # failed on CI, which runs with no anchor data at all.
  skip_if_no_anchor()
  # It may still return NULL for a thin cycle, which is a different thing from
  # being refused.
  expect_no_error(
    statewide_draws_as_at("vic", 2022, as_at = "2022-11-25",
                          election_date = "2022-11-26",
                          parties = c("ALP", "LNP", "GRN", "OTH"),
                          n_sims = 50L, seed = 1L))
})

test_that("a non-date is refused rather than silently coerced", {
  expect_error(
    statewide_draws_as_at("vic", 2022, as_at = "not-a-date",
                          election_date = "2022-11-26",
                          parties = c("ALP", "LNP"), n_sims = 10L),
    "real dates")
})

test_that("the draws are a usable statewide matrix", {
  skip_if_no_anchor()
  r <- statewide_draws_as_at("vic", 2022, as_at = "2022-11-25",
                             election_date = "2022-11-26",
                             parties = c("ALP", "LNP", "GRN", "OTH"),
                             n_sims = 200L, seed = 42L)
  skip_if(is.null(r), "trend could not be fitted at this cutoff")
  expect_equal(dim(r$draws), c(200L, 4L))
  expect_equal(colnames(r$draws), c("ALP", "LNP", "GRN", "OTH"))
  # rows are shares, so they sum to 100 and none is negative
  expect_true(all(abs(rowSums(r$draws) - 100) < 1e-8))
  expect_true(all(r$draws > 0))
  # and there is genuine spread -- a degenerate matrix would reproduce the
  # zero-uncertainty anchor this whole exercise exists to remove
  expect_true(all(apply(r$draws, 2, stats::sd) > 0))
})

test_that("a party the trend cannot fit is reported, not silently dropped", {
  skip_if_no_anchor()
  # One Nation has 3 polls in the Victorian 2022 cycle against a floor of 8, so
  # it must come back in `folded` rather than appearing with an invented series.
  r <- statewide_draws_as_at("vic", 2022, as_at = "2022-11-25",
                             election_date = "2022-11-26",
                             parties = c("ALP", "LNP", "GRN", "ONP", "OTH"),
                             n_sims = 50L, seed = 1L)
  skip_if(is.null(r), "trend could not be fitted at this cutoff")
  expect_true("ONP" %in% r$folded)
})

test_that("the published first-preference widening is applied", {
  # fit_seats_full.R uses sqrt(trend_sd^2 + 2.419^2). The first version of this
  # function used trend_sd alone, understating statewide spread ~2.6x, and the
  # backtest then came out MORE over-confident -- which looked like a finding
  # about the seat model and was a missing constant.
  skip_if_no_anchor()
  P <- c("ALP", "LNP", "GRN", "OTH")
  wide <- statewide_draws_as_at("vic", 2022, "2022-11-25", "2022-11-26",
                                parties = P, n_sims = 4000L, seed = 7L)
  narrow <- statewide_draws_as_at("vic", 2022, "2022-11-25", "2022-11-26",
                                  parties = P, n_sims = 4000L, seed = 7L,
                                  fp_extra_sd = 0)
  skip_if(is.null(wide) || is.null(narrow), "trend not fittable")
  expect_true(all(apply(wide$draws, 2, stats::sd) >
                  apply(narrow$draws, 2, stats::sd)))
  # and the widening is of the documented size, not merely nonzero
  expect_gt(mean(apply(wide$draws, 2, stats::sd)) /
            mean(apply(narrow$draws, 2, stats::sd)), 1.8)
})

test_that("the seat-total check fails on each thing it exists to catch", {
  set.seed(1)
  p <- runif(88, 0.02, 0.98)
  # A correlated simulation: one shared statewide shock per draw, which is what
  # the seat model actually does. It must PASS.
  draw <- function(shift) sum(stats::runif(88) < pmin(1, pmax(0, p + shift)))
  tot <- vapply(stats::rnorm(4000, 0, 0.12), draw, numeric(1))
  good <- check_seat_totals(p, tot)
  expect_true(good$ok)
  expect_gte(good$sd_ratio, 1)

  # BROKEN 1: totals centred somewhere the probabilities do not imply. This is
  # the identity failing, and it means the totals and the probabilities came
  # from different simulations.
  expect_false(check_seat_totals(p, tot + 3)$ok)

  # BROKEN 2: a total tighter than the independence floor -- arithmetically
  # impossible for positively correlated seats, and the "range too narrow" bug
  # the retired cross-check caught by accident.
  tight <- rep(round(sum(p)), 4000)
  expect_false(check_seat_totals(p, tight)$ok)
  expect_lt(check_seat_totals(p, tight)$sd_ratio, 1)

  # and empty input is refused rather than passing vacuously
  expect_error(check_seat_totals(numeric(0), tot), "empty input")
  expect_error(check_seat_totals(c(0.5, 1.4), tot), "probabilities must lie")
})

test_that("the two-party anchor is applied and a degenerate one is refused", {
  skip_if_no_anchor()
  P <- c("ALP", "LNP", "GRN", "OTH")
  args <- list(region = "vic", year = 2022, as_at = "2022-11-25",
               election_date = "2022-11-26", parties = P,
               n_sims = 3000L, seed = 11L)
  free <- do.call(statewide_draws_as_at, args)
  skip_if(is.null(free), "trend not fittable")
  # Anchored five points below the trend's own two-party value, the ALP share
  # must move down. The anchor is the published construction; without it the
  # draws carry the raw first-preference trend's two-party implication.
  low <- do.call(statewide_draws_as_at,
                 c(args, list(tpp_target = function(t) list(mean = t - 5, sd = 1))))
  expect_lt(mean(low$draws[, "ALP"]), mean(free$draws[, "ALP"]))
  expect_gt(mean(low$draws[, "LNP"]), mean(free$draws[, "LNP"]))

  # the function form is handed the trend's own two-party value
  seen <- NULL
  invisible(do.call(statewide_draws_as_at,
    c(args, list(tpp_target = function(t) { seen <<- t; list(mean = t, sd = 1) }))))
  expect_equal(seen, free$tpp)

  # An sd of zero would anchor every draw to one value and delete the
  # uncertainty this whole exercise exists to restore.
  expect_error(do.call(statewide_draws_as_at,
    c(args, list(tpp_target = list(mean = 52, sd = 0)))), "positive `sd`")
})
