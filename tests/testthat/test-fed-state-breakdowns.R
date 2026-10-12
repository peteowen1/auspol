# fed_state_breakdowns_parse(): the federal-poll state breakdowns the recent-poll blend adds at
# AUSPOL_LEVEL_FED_R (docs/plans/prereg-federal-breakdowns-in-blend-2026-10-12.md). Synthetic input, no anchor.

test_that("results, duplicates and non-state rows are dropped; aggregates dated at the midpoint", {
  f <- tempfile(fileext = ".csv")
  d <- data.table::data.table(
    region = c("fed", "fed", "fed", "fed", "fed", "fed", "vic"),
    section = c("Sub-national polling > Victoria", "Sub-national polling > Victoria",
                "Sub-national polling > Victoria", "Sub-national polling > South Australia > Graphical summary",
                "Sub-national polling > Victoria", "Voting intention > 2026", "Sub-national polling > Victoria"),
    row_type = c("poll", "poll", "result", "poll", "poll", "poll", "poll"),
    firm = c("Resolve", "Resolve", "Election", "Newspoll", "YouGov", "YouGov", "Resolve"),
    fieldwork_start = c("2022-10-01", "2022-10-01", "2022-05-21", "2022-01-01", "2022-11-01", "2022-11-01", "2022-10-01"),
    fieldwork_end = c("2022-10-05", "2022-10-05", "2022-05-21", "2022-03-31", "2022-11-03", "2022-11-03", "2022-10-05"),
    alp_fp = c(38, 38, 33, 40, 36, 35, 38), lnp_fp = c(31, 31, 33, NA, 32, 36, 31),
    lib_fp = c(NA, NA, NA, 30, NA, NA, NA), nat_fp = c(NA, NA, NA, NA, NA, NA, NA),
    pv_GRN = c("12%", "12%", "13%", "9.5%", "—", "12%", "12%"))
  data.table::fwrite(d, f)
  out <- fed_state_breakdowns_parse(f)
  expect_equal(nrow(out), 3L)                                   # duplicate once, result/national/state-region rows gone
  expect_false(any(out$firm == "Election"))
  expect_setequal(out$st, c("vic", "sa"))
  sa <- out[out$st == "sa"]
  expect_equal(sa$LNP, 30)                                      # Liberal alone when there is no LNP column value
  expect_equal(sa$GRN, 9.5)                                     # "9.5%" parsed
  expect_equal(sa$date, as.Date("2022-02-14"))                  # midpoint of 1 Jan - 31 Mar
  expect_equal(sa$end, as.Date("2022-03-31"))
  expect_true(is.na(out[out$firm == "YouGov"]$GRN))             # a dash is missing, not zero
})
