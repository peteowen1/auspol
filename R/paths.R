#' Locate the anchor-model data directory
#'
#' Poll and reference data are read from a local clone of
#' d-j-hirst/aus-polling-analyser (gitignored under external/). That data is
#' publicly viewable but carries no formal license, so it is never committed
#' to this repository.
#'
#' @param subpath Path relative to the clone's `analysis/Data` directory.
#' @param must_exist Stop if the path is absent. Set FALSE to test for an
#'   optional file — the alternative is wrapping the call in a blanket
#'   `tryCatch`, which also swallows the deliberate data-corruption stop in
#'   [load_polls()] and lets a bad region disappear silently.
#' @return Absolute path.
#' @export
anchor_data_path <- function(subpath = "", must_exist = TRUE) {
  root <- getOption(
    "auspol.anchor_dir",
    file.path(pkg_root(), "external", "aus-polling-analyser")
  )
  path <- file.path(root, "analysis", "Data", subpath)
  if (!must_exist) return(path)
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

#' Locate fetched election-commission data
#'
#' Results fetched from electoral commissions (VEC, ECSA, AEC) live under
#' `external/elections/`, alongside the anchor clone and gitignored for the
#' same reason: it is third-party data, none of these commissions publishes a
#' licence, and none of it is ours to redistribute. It is disposable — every
#' file is reproducible by rerunning the fetch scripts.
#'
#' `external/` rather than `output/` deliberately. These are model INPUTS, so
#' clearing generated forecasts must not also delete an hour of fetching.
#'
#' Naming is `{source}-{year}-{region}-{content}.csv`, e.g.
#' `vec-2022-vic-transfers.csv`. Sortable, unambiguous, and extends to further
#' sources and elections without renaming what is already there.
#'
#' @param subpath Path relative to `external/elections`.
#' @param must_exist Stop if absent. `FALSE` to test for an optional file.
#' @return Absolute path.
#' @export
election_data_path <- function(subpath = "", must_exist = FALSE) {
  root <- getOption(
    "auspol.elections_dir",
    file.path(pkg_root(), "external", "elections")
  )
  path <- file.path(root, subpath)
  if (!must_exist) return(path)
  if (!file.exists(path)) {
    stop("Fetched election data not found at ", path,
         "\nRun scripts/fetch_preferences_vic.R and ",
         "scripts/fetch_preferences_sa.R to create it.")
  }
  path
}

#' Record a fetch in the election-data manifest
#'
#' Fetched files carry no dates in their names and no provenance in their
#' contents, so a stale one is indistinguishable from a fresh one — the same
#' trap as a GitHub release whose tag date is months older than its assets.
#' This appends one row per fetch: what was fetched, from where, when, and how
#' many rows, so the next reader can tell.
#'
#' @param source Short source name, e.g. `"vec"` or `"ecsa"`.
#' @param dataset File written, e.g. `"vec-2022-vic-transfers.csv"`.
#' @param url The endpoint or page pattern it came from.
#' @param rows Row count written.
#' @return The manifest path, invisibly.
#' @export
record_fetch <- function(source, dataset, url, rows) {
  path <- election_data_path("MANIFEST.csv")
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  row <- data.frame(source = source, dataset = dataset, url = url,
                    rows = as.integer(rows),
                    fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                    stringsAsFactors = FALSE)
  old <- if (file.exists(path)) {
    utils::read.csv(path, stringsAsFactors = FALSE)
  } else NULL
  if (!is.null(old)) old <- old[old$dataset != dataset, , drop = FALSE]
  utils::write.csv(rbind(old, row), path, row.names = FALSE)
  invisible(path)
}
