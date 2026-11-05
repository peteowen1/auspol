# fed_state_breakdowns_merge(): BludgerTrack rows that Wikipedia lacks are added; a poll both have keeps the Wikipedia
# row exactly (same state, canonical firm, fieldwork end within 3 days). 2026-11-05.
test_that("merge keeps Wikipedia's row and adds only unmatched BludgerTrack polls", {
  alias <- data.table::data.table(pattern = c("yougov", "resolve"), canonical = c("yougov", "resolve"))
  w <- data.table::data.table(st = c("vic", "vic"), date = as.Date(c("2026-09-01", "2026-09-20")), firm = c("YouGov", "Resolve Strategic"),
                              end = as.Date(c("2026-09-03", "2026-09-22")), ALP = c(30, 28), LNP = c(31, 33), GRN = c(13, 12))
  b <- data.table::data.table(st = c("vic", "vic", "vic", "nsw"), date = as.Date(c("2026-09-02", "2026-09-10", "2026-10-20", "2026-09-02")),
                              firm = c("YouGov", "YouGov", "Resolve", "YouGov"), end = as.Date(c("2026-09-05", "2026-09-12", "2026-10-22", "2026-09-05")),
                              ALP = c(99, 29, 27, 33), LNP = c(1, 30, 32, 29), GRN = c(1, 14, 12, 11), src = "bt")
  m <- fed_state_breakdowns_merge(w, b, alias)
  expect_equal(attr(m, "n_bt_matched"), 1L)                       # vic YouGov ending 2 days after Wikipedia's
  expect_equal(attr(m, "n_bt_added"), 3L)
  expect_equal(nrow(m), 5L)
  expect_false(any(m$ALP == 99))                                   # the matched poll keeps Wikipedia's numbers
  expect_equal(m[src == "wiki"]$ALP, c(30, 28))
  expect_true(all(c("nsw") %in% m[src == "bt"]$st))               # other states are never matched to Victoria
})

test_that("the BludgerTrack reader keeps federal state rows only, drops results, and dates at the midpoint", {
  f <- tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(
    cycle = "fed2025", section = c("federal", "federal", "federal", "federal", "victoria"),
    scope = c("VIC", "NAT", "Age 18-34", "VIC", "STATEWIDE"),
    pollster = c("YouGov", "YouGov", "YouGov", "Election", "Resolve Strategic"),
    start = c("2024-11-01", "2024-11-01", "2024-11-01", "2022-05-21", "2024-11-01"),
    end = c("2024-11-11", "2024-11-11", "2024-11-11", "2022-05-21", "2024-11-11"),
    ALP = c(31, 30, 40, 32.9, 28), LNC = c(34, 35, 25, 33.1, 38), GRN = c(14, 13, 20, 13.7, 13)), f)
  b <- fed_state_breakdowns_bt(f)
  expect_equal(nrow(b), 1L)                                   # only the federal VIC row: no NAT, no demographic, no result, no state poll
  expect_equal(b$st, "vic"); expect_equal(b$LNP, 34); expect_equal(b$src, "bt")
  expect_equal(b$date, as.Date("2024-11-06")); expect_equal(b$end, as.Date("2024-11-11"))
  expect_error(fed_state_breakdowns_bt(tempfile()), "not found")
})
