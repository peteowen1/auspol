#' Locate the anchor-model data directory
#'
#' Poll and reference data are read from a local clone of
#' d-j-hirst/aus-polling-analyser (gitignored under external/). That data is
#' publicly viewable but carries no formal license, so it is never committed
#' to this repository.
#'
#' @param subpath Path relative to the clone's `analysis/Data` directory.
#' @return Absolute path.
#' @export
anchor_data_path <- function(subpath = "") {
  root <- getOption(
    "auspol.anchor_dir",
    file.path(pkg_root(), "external", "aus-polling-analyser")
  )
  path <- file.path(root, "analysis", "Data", subpath)
  if (!file.exists(path)) {
    stop(
      "Anchor data not found at ", path,
      "\nClone https://github.com/d-j-hirst/aus-polling-analyser to external/ ",
      "or set options(auspol.anchor_dir = ...)."
    )
  }
  path
}

#' Repository root (works from package load or scripts run at repo root)
#' @keywords internal
pkg_root <- function() {
  # When installed/load_all'ed, DESCRIPTION sits at the package root, which is
  # also the repo root for this project.
  candidates <- c(
    getOption("auspol.root", NA_character_),
    getwd(),
    dirname(getwd())
  )
  for (cand in candidates) {
    if (!is.na(cand) && file.exists(file.path(cand, "DESCRIPTION"))) return(cand)
  }
  getwd()
}
