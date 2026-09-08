#' The statewide party-correlation matrix for one election
#'
#' `scripts/estimate_statewide_cov.R` writes both an all-pairs correlation of
#' statewide first-preference changes and, since 2026-09-07, one matrix per
#' target fitted with that target's own pair removed. This function picks the
#' right one and says which it picked, so a caller cannot silently score an
#' election against a matrix that saw it.
#'
#' Three cases, and the distinction between them is the point:
#'
#' * `target` is in the fit — return the leave-one-out matrix. Scoring nsw2023
#'   against a correlation estimated partly from nsw2023's own swing is the leak
#'   this exists to close.
#' * `target` is NOT in the fit — return the all-pairs matrix. Nothing is being
#'   leaked, and withholding data would be superstition rather than hygiene.
#'   Western Australian and Queensland pairs are in this case while the fit
#'   covers ten elections and the harnesses score twenty-two.
#' * `target` is `NULL` — return the all-pairs matrix. This is the live forecast:
#'   `fit_seats_full.R` predicts an election that has not happened, so there is
#'   nothing to leave out.
#'
#' The choice is recorded on the result as the `"cor_source"` attribute, and
#' callers are expected to print it. A silent fallback here would reproduce the
#' failure this repo keeps finding, where a run uses a different input from the
#' one its log implies.
#'
#' @param target Election label being predicted, e.g. `"nsw2023"`, or `NULL` for
#'   a live forecast.
#' @param mode `"shrunk"` for the matrix shrunk toward independence at the
#'   pre-registered lambda, or `"raw"` for the unshrunk correlation.
#' @param path Path to the saved object. Defaults to `output/statewide-cov.rds`
#'   under the package root.
#' @return A correlation matrix, with a `"cor_source"` attribute describing
#'   which of the three cases applied.
#' @export
statewide_cor <- function(target = NULL, mode = c("shrunk", "raw"),
                          path = NULL) {
  mode <- match.arg(mode)
  if (is.null(path)) {
    root <- getOption("auspol.root", ".")
    path <- file.path(root, "output", "statewide-cov.rds")
  }
  if (!file.exists(path)) {
    stop("No statewide covariance at ", path,
         " -- run scripts/estimate_statewide_cov.R")
  }
  co <- readRDS(path)
  pick <- function(x) if (identical(mode, "raw")) x$cor else x$cor_shrunk

  # AUSPOL_COV_LOO=0 forces the all-pairs matrix for every target, which is the
  # behaviour before 2026-09-07. It exists so the leave-one-out change can be
  # MEASURED on identical data rather than against a baseline that also moved
  # for other reasons, and it is in scripts/published_flags.R at 1 so a bare run
  # gets the leakage-free matrix. Reading the environment inside a package
  # function is unusual here; it is done because all seven callers would
  # otherwise have to thread the same flag through.
  if (identical(Sys.getenv("AUSPOL_COV_LOO", "1"), "0")) {
    out <- pick(co)
    attr(out, "cor_source") <- sprintf(
      "all %d pairs (AUSPOL_COV_LOO=0: IN-SAMPLE for a target inside the fit)",
      nrow(co$change))
    return(out)
  }

  if (is.null(target)) {
    out <- pick(co)
    attr(out, "cor_source") <- sprintf("all %d pairs (live forecast: nothing to leave out)",
                                       nrow(co$change))
    return(out)
  }
  # `by_target` is absent from an object written before 2026-09-07. Refuse
  # rather than fall back to the all-pairs matrix, which is exactly the leak
  # this function exists to close and would be invisible in the output.
  if (is.null(co$by_target)) {
    stop(path, " has no per-target matrices, so it predates the ",
         "leave-one-election-out change. Re-run scripts/estimate_statewide_cov.R ",
         "rather than scoring against an in-sample correlation.")
  }
  if (target %in% names(co$by_target)) {
    e <- co$by_target[[target]]
    out <- pick(e)
    attr(out, "cor_source") <- sprintf("leave-one-out, %d pairs (%s held out)",
                                       e$n_pairs, target)
    return(out)
  }
  out <- pick(co)
  attr(out, "cor_source") <- sprintf("all %d pairs (%s is not in the fit, so nothing to hold out)",
                                     nrow(co$change), target)
  out
}
