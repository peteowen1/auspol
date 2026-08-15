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
