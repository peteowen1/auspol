# The anchor's data lives in external/aus-polling-analyser, a gitignored
# third-party clone. testthat runs from tests/testthat, so auspol.root has to
# be pointed back at the package root; and any test reading that data must skip
# cleanly when the clone is absent (a fresh checkout, or CI).

anchor_repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                                  winslash = "/", mustWork = FALSE)
if (is.null(getOption("auspol.root"))) {
  options(auspol.root = anchor_repo_root)
}

skip_if_no_anchor <- function() {
  # Resolve through anchor_data_path() rather than rebuilding the path here, so
  # the guard tests exactly the location the code will read — including any
  # auspol.anchor_dir override. A hardcoded path silently disagreed with the
  # configured one, which meant a CI dry-run appeared to pass while the guard
  # was answering about a different directory.
  p <- anchor_data_path("poll-data-fed.csv", must_exist = FALSE)
  testthat::skip_if_not(file.exists(p), "anchor data clone not present")
}

# THE SALIENCE CORPUS lives at the package root, and testthat runs from
# tests/testthat -- so `file.exists("output/salience-v6.csv")` is FALSE on
# every machine, including the ones that have it. Two tests guarded that way
# skipped unconditionally and silently, which is this repo's own recorded
# failure: an experiment that never ran looks exactly like one with no effect.
# Found by review 2026-09-07. Resolve from the root, like the anchor guard.
salience_corpus_path <- function(f) {
  file.path(normalizePath(file.path(testthat::test_path(), "..", ".."),
                          winslash = "/", mustWork = FALSE), "output", f)
}
skip_if_no_salience_corpus <- function() {
  ok <- file.exists(salience_corpus_path("salience-v6.csv")) &&
    file.exists(salience_corpus_path("candidacies.csv"))
  testthat::skip_if_not(ok, "salience corpus not present")
}

# surge_hazard_for() and its helpers read "output/candidacies.csv" as a BARE
# RELATIVE path, i.e. relative to the working directory, which is the package
# root for every script in scripts/ and tests/testthat for the suite. So a
# test of those functions has to run from the root. Recorded rather than
# refactored: making the package resolve through auspol.root is a wider change
# than a test fix, and is noted in docs/NEXT-STEPS.md.
with_package_root <- function(code) {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                        winslash = "/", mustWork = FALSE)
  withr::with_dir(root, code)
}
