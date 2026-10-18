# bucket_split_ratio(): the one rule for dividing the unpolled others bucket, shared by training
# (forecast_statewide_for) and the live xgb layer (fit_seats_full.R). Audit 2026-10-18, F1.
test_that("prior-ratio split: absent classes count 0, ratios sum to 1", {
  withr::local_envvar(AUSPOL_BUCKET_SPLIT = "prior")
  r <- bucket_split_ratio("vic2026", c("IND", "OTH_RIGHT", "OTH"), c(ALP = 37, IND = 4, OTH = 6))
  expect_equal(unname(r), c(0.4, 0, 0.6))
  expect_equal(names(r), c("IND", "OTH_RIGHT", "OTH"))
  expect_equal(sum(r), 1)
})
test_that("a bucket absent from the previous election splits equally", {
  withr::local_envvar(AUSPOL_BUCKET_SPLIT = "prior")
  r <- bucket_split_ratio("vic2026", c("IND", "OTH"), c(ALP = 50, LNP = 50))
  expect_equal(unname(r), c(0.5, 0.5))
})
test_that("the split is NOT the state_mean the live layer used to serve (IND 0, OTH the whole bucket)", {
  withr::local_envvar(AUSPOL_BUCKET_SPLIT = "prior")
  r <- bucket_split_ratio("vic2026", c("IND", "OTH_RIGHT", "OTH"), c(IND = 3, OTH_RIGHT = 4, OTH = 3))
  expect_true(all(r[c("IND", "OTH_RIGHT")] > 0))
  expect_lt(r[["OTH"]], 1)
})
