# Empirical error distribution (AUSPOL_ERROR_DIST, default "1" = shipped 2026-10-17 on Pete's override; "0" = rnorm;
# docs/plans/prereg-error-distribution-2026-10-17.md). The simulator draws each cell's noise as
# sd_cell * rnorm; under "1" it draws sd_cell * z, z from the earlier elections' standardised errors for that
# class (scripts/fit_error_distribution.R -> output/error-quantiles.csv): heavy tails everywhere, a right skew
# for the candidate classes, the width unchanged (RMS 1).

#' @noRd
error_dist_on <- function() {
  m <- Sys.getenv("AUSPOL_ERROR_DIST", "1")
  if (!m %in% c("0", "1")) stop("AUSPOL_ERROR_DIST must be \"0\" or \"1\", got \"", m, "\"")
  identical(m, "1")
}

#' The `error_q` argument for one election's simulation
#'
#' Reads `AUSPOL_ERROR_DIST`: `"0"` returns `NULL` (the simulator draws `rnorm`). `"1"` returns a classes x
#' quantiles matrix from `output/error-quantiles.csv` for `target`, rows in `classes` order, or `NULL` when the
#' table has no row for the target (too few earlier elections), which prints `ERD1` and keeps `rnorm`. A class
#' the table does not carry stops: drawing it from the wrong distribution would be silent.
#'
#' @param target Election label.
#' @param classes The simulation's class columns, in order.
#' @return `NULL` or a numeric matrix, `length(classes)` x 201.
#' @export
error_dist_args <- function(target, classes) {
  if (!error_dist_on()) return(NULL)
  f <- out_path("error-quantiles.csv")
  if (!file.exists(f)) stop("AUSPOL_ERROR_DIST=1 but output/error-quantiles.csv is missing -- run scripts/fit_error_distribution.R")
  tab <- data.table::fread(f, showProgress = FALSE)
  tgt_label <- target   # not a bare `target` inside tab[...]: it would bind to the column (data.table NSE)
  rows <- tab[tab$target %in% tgt_label]
  if (!nrow(rows)) {
    cat(sprintf("ERD1 %s: no empirical error distribution (too few earlier elections); rnorm as shipped\n", target))
    return(NULL)
  }
  miss <- setdiff(classes, rows$class)
  if (length(miss)) stop("AUSPOL_ERROR_DIST=1 but output/error-quantiles.csv has no ", target, " row for: ", paste(miss, collapse = ", "))
  qc <- grep("^q[0-9]{3}$", names(rows), value = TRUE)
  m <- as.matrix(rows[match(classes, rows$class), qc, with = FALSE])
  dimnames(m) <- list(classes, qc)
  cat(sprintf("ERD1 %s: empirical error distribution from %d earlier elections; median z %s; p99 z %s\n", target,
              as.integer(rows$n_pairs[1]),
              paste(sprintf("%s %+.2f", classes, m[, "q100"]), collapse = " "),
              paste(sprintf("%s %+.2f", classes, m[, "q198"]), collapse = " ")))
  m
}
