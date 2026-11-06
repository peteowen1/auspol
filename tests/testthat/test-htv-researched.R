# The researched Coalition card order (AUSPOL_HTV_TABLE=researched). plans/prereg-htv-researched-2026-11-06.md

test_that("the researched table maps card orders, splits seat lists and drops open, unknown and low-confidence cards", {
  f <- withr::local_tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(
    election = c("x2019", "x2019", "x2022", "x2022", "x2023", "x2024", "x2025"),
    seat = c("ALL", "Fremantle", "ALL", "A;B", "ALL", "ALL", "ALL"),
    party = c("LIB", "LIB", "LIB", "LIB", "LIB", "NAT", "LIB"),
    order = c("ALP_ABOVE_GRN", "GRN_ABOVE_ALP", "OPEN", "ALP_ABOVE_GRN", "GRN_ABOVE_ALP", "ALP_ABOVE_GRN", "UNKNOWN"),
    confidence = c("HIGH", "MED", "HIGH", "HIGH", "LOW", "HIGH", "LOW"),
    source_url = paste0("u", 1:7)), f)
  t <- htv_researched_table(f)
  data.table::setorderv(t, c("election", "seat"))
  expect_equal(t$election, c("x2019", "x2019", "x2022", "x2022"))
  expect_equal(t$seat, c("ALL", "Fremantle", "A", "B"))
  expect_equal(t$greens_above_labor, c(FALSE, TRUE, FALSE, FALSE))
})

test_that("AUSPOL_HTV_TABLE selects the table, and a bad value stops", {
  withr::local_envvar(AUSPOL_HTV_TABLE = "nonsense")
  expect_error(htv_order_table(), "shipped or researched")
  withr::local_envvar(AUSPOL_HTV_TABLE = "shipped")
  f <- withr::local_tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(election = "x2019", seat = "ALL", greens_above_labor = TRUE, source = "s"), f)
  expect_true(htv_order_table(f)$greens_above_labor)
})

test_that("two kept rows for one election and seat are refused", {
  f <- withr::local_tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(election = c("x2019", "x2019"), seat = c("ALL", "ALL"), party = "LIB",
                                            order = c("ALP_ABOVE_GRN", "GRN_ABOVE_ALP"), confidence = "HIGH", source_url = "u"), f)
  expect_error(htv_researched_table(f), "two kept rows")
})
