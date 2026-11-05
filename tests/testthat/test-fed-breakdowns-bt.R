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
