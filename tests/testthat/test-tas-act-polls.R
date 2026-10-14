# Tasmania and the ACT have no anchor poll file; load_polls() reads our supplements
# (scripts/build_tas_act_polls.R), same pattern as the NT.

test_that("load_polls('tas') reads the supplement: EMRS and others, 2008-2025", {
  f <- file.path(pkg_root(), "external", "reference", "anchor-supplement", "poll-data-tas.csv")
  skip_if_not(file.exists(f), "anchor supplement not shipped in the check build")
  p <- suppressMessages(load_polls("tas"))
  expect_gt(nrow(p), 80L)
  expect_equal(attr(p, "region"), "tas")
  expect_true("EMRS" %in% p$firm)
  fp <- as.matrix(p[, c("ALP", "LNP", "GRN", "OTH"), with = FALSE])
  expect_true(all(abs(rowSums(fp) - 100) < 0.5))            # undecided divided out
  expect_true(all(p$date >= as.Date("2008-01-01") & p$date <= as.Date("2025-07-19")))
})

test_that("load_polls('act') reads the hand-keyed supplement: 3 polls, 2012 and 2020", {
  f <- file.path(pkg_root(), "external", "reference", "anchor-supplement", "poll-data-act.csv")
  skip_if_not(file.exists(f), "anchor supplement not shipped in the check build")
  p <- suppressMessages(load_polls("act"))
  expect_equal(nrow(p), 3L)
  fp <- as.matrix(p[, c("ALP", "LNP", "GRN", "OTH"), with = FALSE])
  expect_true(all(abs(rowSums(fp) - 100) < 0.5))
})
