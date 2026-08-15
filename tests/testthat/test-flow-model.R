# Tests for the estimated preference flows.
#
# Written against the failure modes this file actually hit while being built,
# not hypothetical ones: every party silently receiving the same pooled value,
# and an election that has already happened having its recorded flows
# overwritten by estimates.

fake_flows <- function() {
  data.table::data.table(
    year = c(2010L, 2014L, 2018L, 2022L, 2026L,
             2010L, 2014L, 2018L, 2022L, 2026L),
    region = rep(c("vic", "vic", "vic", "vic", "vic"), 2),
    party = c(rep("AAA", 5), rep("BBB", 5)),
    flow_alp = c(10, 20, 30, 40, 50,   90, 80, 70, 60, 50),
    exhaust = 0
  )
}
fake_cycles <- function(held_through = 2022L) {
  data.table::data.table(
    year = c(2010L, 2014L, 2018L, 2022L, 2026L),
    region = "vic",
    end = as.Date(sprintf("%d-11-30", c(2010, 2014, 2018, 2022, 2026)))
  )
}

test_that("each party gets its OWN history, not a pooled average", {
  # The bug this catches: writing `flows[flows$party == party, ]` lets
  # data.table bind the bare `party` to the column, the filter matches every
  # row, and both parties come back with the mean of everything. Here that
  # pooled value would be 50 for both; the correct answers straddle it.
  fl <- fake_flows(); cyc <- fake_cycles()
  a <- estimate_flow(fl, "AAA", 2026, cyc, as_of = as.Date("2023-01-01"))
  b <- estimate_flow(fl, "BBB", 2026, cyc, as_of = as.Date("2023-01-01"))
  expect_false(isTRUE(all.equal(a$flow, b$flow)))
  expect_equal(a$flow, mean(c(10, 20, 30, 40)))
  expect_equal(b$flow, mean(c(90, 80, 70, 60)))
  expect_equal(a$n, 4L)
})

test_that("only elections already held are used", {
  fl <- fake_flows(); cyc <- fake_cycles()
  # As of 2023 the 2026 election has not happened, so its row must not inform
  # the estimate -- otherwise an assumption feeds itself back in as evidence.
  early <- estimate_flow(fl, "AAA", 2026, cyc, as_of = as.Date("2023-01-01"))
  expect_equal(early$n, 4L)
  expect_false(grepl("2026", early$years))
  # After the 2026 election it becomes usable.
  late <- estimate_flow(fl, "AAA", 2030, cyc, as_of = as.Date("2027-01-01"))
  expect_equal(late$n, 5L)
  expect_true(grepl("2026", late$years))
})

test_that("the estimate moves when a new election lands", {
  # The whole point: an assumption pinned to a literal cannot respond to
  # evidence, and this must.
  fl <- fake_flows(); cyc <- fake_cycles()
  before <- estimate_flow(fl, "AAA", 2026, cyc, as_of = as.Date("2019-01-01"))
  after  <- estimate_flow(fl, "AAA", 2026, cyc, as_of = as.Date("2023-01-01"))
  expect_gt(after$flow, before$flow)
})

test_that("a party with too little history returns NULL rather than guessing", {
  fl <- fake_flows()[1:2]
  expect_null(estimate_flow(fl, "AAA", 2026, fake_cycles(),
                            as_of = as.Date("2023-01-01")))
  expect_null(estimate_flow(fake_flows(), "ZZZ", 2026, fake_cycles()))
})

test_that("an election already held keeps its recorded flows untouched", {
  fl <- fake_flows(); cyc <- fake_cycles()
  used <- data.table::data.table(party = c("AAA", "BBB"), region = "vic",
                                 year = 2018L, flow_year = 2018L,
                                 flow_alp = c(30, 70), exhaust = 0)
  out <- estimate_flows_for(used, fl, 2018L, cyc,
                            as_of = as.Date("2023-01-01"), quiet = TRUE)
  expect_equal(out$flow_alp, c(30, 70))
  expect_true(all(grepl("already held", out$flow_source)))
})

test_that("a future election has every flow estimated, however it was authored", {
  # Including rows the source authored FOR that year. A value written for an
  # election that has not happened is a forecast, not a record -- an earlier
  # draft exempted these and would have left the assumption in place.
  fl <- fake_flows(); cyc <- fake_cycles()
  used <- data.table::data.table(party = c("AAA", "BBB"), region = "vic",
                                 year = 2026L, flow_year = 2026L,
                                 flow_alp = c(99, 1), exhaust = 0)
  out <- estimate_flows_for(used, fl, 2026L, cyc,
                            as_of = as.Date("2023-01-01"), quiet = TRUE)
  expect_false(any(out$flow_alp %in% c(99, 1)))
  expect_true(all(grepl("^fitted", out$flow_source)))
  expect_true(all(is.finite(out$flow_se)))
})

test_that("estimates stay inside [0, 100]", {
  fl <- fake_flows()
  fl$flow_alp <- c(rep(0, 5), rep(100, 5))
  out <- estimate_flow(fl, "AAA", 2026, fake_cycles(),
                       as_of = as.Date("2023-01-01"))
  expect_gte(out$flow, 0); expect_lte(out$flow, 100)
})

test_that("is_observed_election keys off the election date, not the year", {
  cyc <- fake_cycles()
  d <- data.table::data.table(year = 2026L, region = "vic")
  # Mid-2026: the year matches but the November election has not happened.
  expect_false(is_observed_election(d, cyc, as_of = as.Date("2026-08-15")))
  expect_true(is_observed_election(d, cyc, as_of = as.Date("2026-12-01")))
})
