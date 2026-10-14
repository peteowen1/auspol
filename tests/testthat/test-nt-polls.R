# The Northern Territory has no anchor poll file; load_polls("nt") reads our own
# supplement in the anchor's shape (scripts/build_nt_polls.R). The anchor file
# must still win wherever it exists, so no existing region can change.

test_that("load_polls('nt') reads the supplement, 8 statewide polls 2015-2024", {
  f <- file.path(pkg_root(), "external", "reference", "anchor-supplement", "poll-data-nt.csv")
  skip_if_not(file.exists(f), "anchor supplement not shipped in the check build")
  p <- suppressMessages(load_polls("nt"))
  expect_equal(nrow(p), 8L)
  expect_equal(attr(p, "region"), "nt")
  expect_true(all(c("ALP", "LNP", "GRN", "OTH") %in% attr(p, "parties")))
  # undecided divided out: every poll with first preferences sums to 100
  fp <- as.matrix(p[, c("ALP", "LNP", "GRN", "OTH"), with = FALSE])
  ok <- is.finite(p$ALP)
  expect_true(all(abs(rowSums(fp[ok, , drop = FALSE], na.rm = TRUE) - 100) < 0.5))
})

test_that("a region with neither an anchor file nor a supplement still errors", {
  expect_error(suppressMessages(load_polls("zz")), "Anchor data not found|cannot open|does not exist")
})
