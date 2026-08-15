# Run the test suite the way CI does, not the way this laptop does.
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
