test_that("a prior-results correction applies at its wrong value, passes when fixed, stops on a third value", {
  dt <- data.table::data.table(year = 2027L, region = "nsw", party = "@TPP", prev1 = 35.37, prev2 = 47.98)
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "external", "reference", "anchor-corrections"), recursive = TRUE)
  writeLines(c("year,region,party,slot,value,was,source,note",
               "2027,nsw,@TPP,prev1,54.27,35.37,src,n"),
             file.path(tmp, "external", "reference", "anchor-corrections", "prior-results.csv"))
  local_mocked_bindings(pkg_root = function() tmp)
  out <- capture.output(r <- .apply_prior_corrections(data.table::copy(dt)))
  expect_equal(r$prev1, 54.27)
  expect_equal(r$prev2, 47.98)
  expect_match(out, "corrected 35.37 -> 54.27", all = FALSE)
  fixed <- data.table::copy(dt); fixed$prev1 <- 54.27
  out2 <- capture.output(r2 <- .apply_prior_corrections(fixed))
  expect_match(out2, "can be removed", all = FALSE)
  third <- data.table::copy(dt); third$prev1 <- 50
  expect_error(.apply_prior_corrections(third), "neither the wrong value")
})
