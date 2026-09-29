test_that("candidate_bucket_ratio reads THIS election's row, not the first one", {
  # The NSE trap: `cs$election == election` inside `[` compared the column with
  # itself and returned the first election's shares for every election.
  d <- withr::local_tempdir()
  dir.create(file.path(d, "output")); file.create(file.path(d, "DESCRIPTION"))
  data.table::fwrite(data.table::data.table(
    election = c("fed2004", "fed2004", "fed2025", "fed2025"),
    cls = c("IND", "OTH", "IND", "OTH"),
    pred_resid = c(1, 9, 6, 2), pred_naive = c(1, 9, 6, 2), arm = "resid"),
    file.path(d, "output", "minor-class-shares-v2.csv"))
  withr::local_options(auspol.root = d)
  withr::local_envvar(AUSPOL_BUCKET_SPLIT = "cand_naive")
  r <- suppressMessages(capture.output(x <- candidate_bucket_ratio("fed2025", c("IND", "OTH"))))
  expect_equal(unname(x[["IND"]]), 0.75)
  expect_equal(unname(x[["OTH"]]), 0.25)
  withr::local_envvar(AUSPOL_BUCKET_SPLIT = "prior")
  expect_null(candidate_bucket_ratio("fed2025", c("IND", "OTH")))
})
