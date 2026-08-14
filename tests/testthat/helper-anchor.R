# The anchor's data lives in external/aus-polling-analyser, a gitignored
# third-party clone. testthat runs from tests/testthat, so auspol.root has to
# be pointed back at the package root; and any test reading that data must
# skip cleanly when the clone is absent (a fresh checkout, or CI).

anchor_repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."),
                                  winslash = "/", mustWork = FALSE)
options(auspol.root = anchor_repo_root)

skip_if_no_anchor <- function() {
  p <- file.path(anchor_repo_root, "external", "aus-polling-analyser",
                 "analysis", "Data", "poll-data-fed.csv")
  testthat::skip_if_not(file.exists(p), "anchor data clone not present")
}
