# .statewide_endpoints(): which trend rows statewide_draws_as_at() reads (AUSPOL_STATEWIDE_ENDPOINT, 2026-11-06).
# The real case: nsw2023 One Nation's series ended 12 days before the others, so "global" dropped it.
test_that("global keeps only the latest date; party keeps each party's own latest row", {
  s <- data.table::data.table(
    party = c("ALP", "ALP", "ONP", "ONP", "TPP_ALP"),
    date  = as.Date(c("2023-03-12", "2023-03-24", "2023-03-01", "2023-03-12", "2023-03-24")),
    mean  = c(36, 36.5, 4.4, 4.6, 53.1))
  g <- .statewide_endpoints(s, "global")
  expect_setequal(g$party, c("ALP", "TPP_ALP"))            # One Nation dropped: the bug
  p <- .statewide_endpoints(s, "party")
  expect_setequal(p$party, c("ALP", "ONP", "TPP_ALP"))     # kept, at its own last date
  expect_equal(p$mean[p$party == "ONP"], 4.6)
  expect_equal(p$date[p$party == "ONP"], as.Date("2023-03-12"))
  expect_equal(p$mean[p$party == "ALP"], 36.5)              # latest row, not the earlier one
  expect_identical(.statewide_endpoints(s), g)              # default is the old behaviour
})
