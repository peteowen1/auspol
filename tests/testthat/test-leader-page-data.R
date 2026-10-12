# leader_page_data(): the `leaders` key of the forecast page JSON (display only). Synthetic input, no anchor.

test_that("filters to the election and the page measures, and is NULL without the table", {
  f <- tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(
    election = c("vic2026", "vic2026", "vic2026", "nsw2027"),
    date = c("2026-09-13", "2026-09-28", "2026-09-28", "2026-08-26"),
    firm = c("Resolve", "Freshwater", "Freshwater", "Resolve"),
    leader = c("Carroll", "Wilson", "Wilson", "Minns"), party = c("ALP", "LNP", "LNP", "ALP"),
    role = c("gov", "opp", "opp", "gov"), measure = c("preferred", "preferred", "something_else", "preferred"),
    value = c(20, 37, 1, 42), n_named = c(3L, 3L, NA, 2L), source = "wikipedia"), f)
  x <- leader_page_data("vic2026", f = f)
  expect_equal(nrow(x$rows), 2L)
  expect_equal(x$as_of, "2026-09-28")
  expect_setequal(x$rows$leader, c("Carroll", "Wilson"))
  expect_message(y <- leader_page_data("vic2026", f = tempfile()), "not found")
  expect_null(y)
  expect_null(suppressMessages(leader_page_data("sa2030", f = f)))
})
