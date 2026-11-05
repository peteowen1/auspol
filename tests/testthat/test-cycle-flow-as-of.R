# .cycle_flow_as_of(): the flow date is the TARGET cycle's start, not the earliest cycle on file.
# Written 2026-11-05 after statewide_draws_as_at() matched all 88 cycles through the data.table
# name trap and dated every target's flows 1969-10-26 (no election "held", so flows were never
# estimated and backtests read the target's own recorded flows).

test_that("the flow date is the target cycle's start, with a data.table calendar", {
  cy <- data.table::data.table(
    region = c("vic", "vic", "nsw", "fed"),
    year   = c(2018L, 2022L, 2023L, 2022L),
    start  = as.Date(c("2014-11-30", "2018-11-25", "2019-03-24", "2019-05-19")))
  expect_equal(.cycle_flow_as_of(cy, "vic", 2022L, as.Date("2022-11-25")), as.Date("2018-11-25"))
  expect_equal(.cycle_flow_as_of(cy, "nsw", 2023L, NA), as.Date("2019-03-24"))
  # a cycle not on file falls back
  expect_equal(.cycle_flow_as_of(cy, "qld", 2024L, as.Date("2024-10-25")), as.Date("2024-10-25"))
  # the broken form this replaced: bare names inside [ ] bind to the columns and match every row
  region <- "vic"; year <- 2022L
  broken <- cy[cy$region == region & cy$year == year, ]
  expect_equal(nrow(broken), nrow(cy))
  expect_equal(min(broken$start), as.Date("2014-11-30"))
})

test_that("on the real calendar every scored target gets its own cycle start", {
  skip_if_not(file.exists(file.path(getOption("auspol.root", "."), "external", "aus-polling-analyser")) ||
                nzchar(Sys.getenv("AUSPOL_ANCHOR_DIR")), "no anchor calendar on this machine")
  cy <- tryCatch(load_election_cycles(), error = function(e) NULL)
  skip_if(is.null(cy), "election calendar not loadable")
  d <- .cycle_flow_as_of(cy, "vic", 2022L, as.Date(NA))
  expect_true(d > as.Date("2018-01-01") && d < as.Date("2022-11-26"))
})
