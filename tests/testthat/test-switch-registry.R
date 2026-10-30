# MR4 as a CI failure: every AUSPOL_* switch the code reads is registered in scripts/published_flags.R or listed in
# scripts/non_model_switches.R (Pete, 2026-10-29: 140 had drifted in unlisted while the check only printed).

test_that("every AUSPOL_* switch read in code is registered or listed, once, and every listed one is still read", {
  root <- testthat::test_path("..", "..")
  skip_if_not(file.exists(file.path(root, "scripts", "non_model_switches.R")), "scripts/ not shipped in the check build")
  e <- new.env()
  sys.source(file.path(root, "scripts", "non_model_switches.R"), envir = e)
  s <- e$mr4_scan(root)
  expect_gt(s$n_files, 100)                    # the scan found the code, not an empty directory
  expect_gt(length(s$read), 300)               # and its reads: an empty scan would pass every check below
  expect_identical(s$unlisted, character(), label = "read but neither registered nor listed")
  expect_identical(s$stale_listed, character(), label = "listed in non_model_switches.R but no longer read")
  expect_identical(s$both, character(), label = "both registered and listed")
})

test_that("the scan catches a new unlisted read and ignores one on a comment line", {
  root <- testthat::test_path("..", "..")
  skip_if_not(file.exists(file.path(root, "scripts", "non_model_switches.R")), "scripts/ not shipped in the check build")
  d <- withr::local_tempdir()
  dir.create(file.path(d, "R")); dir.create(file.path(d, "scripts"))
  writeLines(c('AUSPOL_KNOWN = "1",'), file.path(d, "scripts", "published_flags.R"))
  writeLines(c('a <- Sys.getenv("AUSPOL_KNOWN", "1")', 'b <- Sys.getenv( "AUSPOL_NEW_ONE", "0")',
               '# Sys.getenv("AUSPOL_ONLY_IN_COMMENT")'), file.path(d, "R", "x.R"))
  e <- new.env()
  sys.source(file.path(root, "scripts", "non_model_switches.R"), envir = e)
  assign("NON_MODEL_SWITCHES", c(AUSPOL_GONE = "RUN"), envir = e)
  s <- e$mr4_scan(d)
  expect_identical(s$unlisted, "AUSPOL_NEW_ONE")
  expect_identical(s$stale_listed, "AUSPOL_GONE")
  expect_false("AUSPOL_ONLY_IN_COMMENT" %in% s$read)
})
