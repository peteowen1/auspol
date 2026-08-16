# Run what CI runs, the way CI runs it.
#
# This script was named check_like_ci.R while doing only HALF of what CI does:
# the test suite with no anchor data. CI also runs
# `rcmdcheck(args = "--as-cran", error_on = "warning")`, and on 2026-08-16 that
# is what failed on a PR this script had just declared clean -- an undocumented
# `...` (a WARNING, and CI errors on warnings) and two data.table NSE variables
# read as undefined globals (a NOTE).
#
# A guard named after a thing it does not do is worse than no guard: it gets
# trusted. Both halves now run here.
#
# Every developer machine that has ever worked on this package has a populated
# `external/aus-polling-analyser/` clone. CI does not: `check.yaml` runs
# `R CMD check` with no anchor data at all, so every test guarded by
# `skip_if_no_anchor()` skips there and runs here. That gap is invisible until
# it isn't -- on 2026-08-16 a change gave `flows_for()` a new dependency on the
# election calendar, six tests started needing anchor data they had never
# needed, the suite passed locally, and the PR opened red.
#
# So: point the package at an empty directory and run everything. A test that
# fails here rather than skipping is a test that will fail on CI.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/check_like_ci.R"'

suppressMessages(devtools::load_all(quiet = TRUE))

empty <- file.path(tempdir(), "auspol-no-anchor")
dir.create(empty, showWarnings = FALSE, recursive = TRUE)
options(auspol.root = empty)

cat("=== running the suite with NO anchor data ===\n")
cat("auspol.root =", empty, "\n\n")

res <- testthat::test_dir("tests/testthat", stop_on_failure = FALSE,
                          reporter = testthat::SummaryReporter$new())

df <- as.data.frame(res)
n_fail <- sum(df$failed) + sum(df$error)
n_skip <- sum(df$skipped)
n_pass <- sum(df$passed)

cat(sprintf("\n=== %d passed, %d skipped, %d failed/errored ===\n",
            n_pass, n_skip, n_fail))

if (n_fail > 0) {
  stop(sprintf("%d test(s) fail without anchor data and will fail on CI. ",
               n_fail),
       "A test that needs the anchor must call skip_if_no_anchor(); a test ",
       "that should not need it has picked up a dependency by accident.")
}

# A suite where everything skipped would pass this check vacuously, which is
# the same shape as every other guard in this package that had to learn not to
# pass on an empty set.
if (n_pass < 100) {
  stop(sprintf("Only %d assertions ran without anchor data (expected 100+). ",
               n_pass),
       "Either the suite is mostly anchor-dependent now, or something is ",
       "skipping that should not be.")
}

cat("OK: nothing depends on anchor data that should not.\n")

# ---- Half two: R CMD check --as-cran, warnings as errors --------------------
#
# The half this script was missing. Slower (a full build and check), so it runs
# second: a broken test suite should fail in seconds rather than after a build.
# Skippable with --tests-only while iterating, but never before opening a PR --
# that is exactly when it caught something.
if (!"--tests-only" %in% commandArgs(trailingOnly = TRUE)) {
  cat("\n=== R CMD check --as-cran (warnings are errors, as in CI) ===\n")
  if (!requireNamespace("rcmdcheck", quietly = TRUE)) {
    stop("rcmdcheck is not installed, so the half of CI that checks the ",
         "package cannot run here. Install it, or pass --tests-only and ",
         "accept that CI may still fail.")
  }
  res <- rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"),
                              build_args = "--no-manual",
                              error_on = "warning", quiet = TRUE)
  cat(sprintf("errors %d   warnings %d   notes %d\n",
              length(res$errors), length(res$warnings), length(res$notes)))
  if (length(res$notes)) {
    # Notes do not fail CI today, but they are how a warning starts: an
    # undefined global is a note until the same slip lands somewhere check
    # treats as an error. Print them rather than let them accumulate unseen.
    cat("\nNOTES (not fatal, but do not let them pile up):\n")
    for (x in res$notes) cat("  - ", gsub("\n", "\n    ", x), "\n", sep = "")
  }
  cat("\nOK: package checks clean the way CI checks it.\n")
}
