fake_error_table <- function() {
  set.seed(1)
  mk <- function(firm, sd, election, n = 40) data.table::data.table(
    region = "vic", year = as.integer(format(election, "%Y")), election = election, firm = firm,
    party = "ALP", d = stats::rnorm(n, 0, sd), rec = 1)
  data.table::rbindlist(list(
    mk("Good", 1, as.Date("2018-11-24")), mk("Bad", 4, as.Date("2018-11-24")),
    mk("Good", 1, as.Date("2022-11-26")), mk("Bad", 1, as.Date("2022-11-26"))))
}

with_fake_table <- function(code) {
  key <- paste(sort(c("fed", "vic", "nsw", "qld", "wa", "sa")), collapse = ",")
  old <- .poll_record_cache[[key]]
  assign(key, fake_error_table(), envir = .poll_record_cache)
  on.exit(if (is.null(old)) rm(list = key, envir = .poll_record_cache) else assign(key, old, envir = .poll_record_cache))
  force(code)
}

test_that("a pollster with a worse record against results gets a larger noise factor", {
  with_fake_table({
    f <- firm_record_factors(as.Date("2020-01-01"))
    expect_true(f[["Bad"]] > 1)
    expect_true(f[["Good"]] < 1)
    expect_equal(attr(f, "n_elections"), 1L)
  })
})

test_that("no record from an election on or after the cutoff is used (leakage)", {
  with_fake_table({
    # Before any election: no record at all.
    expect_length(firm_record_factors(as.Date("2018-01-01")), 0)
    # Cutoff ON the 2022 election day: 2022 must be excluded, so the result
    # equals the 2018-only record exactly.
    on_day <- firm_record_factors(as.Date("2022-11-26"))
    only_2018 <- firm_record_factors(as.Date("2020-01-01"))
    expect_equal(on_day, only_2018)
    # The day after, the 2022 record is used: the factors change and two
    # elections count.
    after <- firm_record_factors(as.Date("2022-11-27"))
    expect_false(isTRUE(all.equal(after, on_day)))
    expect_equal(attr(after, "n_elections"), 2L)
  })
})

test_that("the time-forward noise arm refuses unknown values loudly", {
  expect_error(trend_as_at(NULL, 2022L, NULL, Sys.Date(), NULL, NULL, sigmas = "nope"), "should be one of")
  expect_error(trend_as_at(NULL, 2022L, NULL, Sys.Date(), NULL, NULL, weights = "nope"), "should be one of")
})
