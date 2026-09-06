#' auspol: Australian election forecasting
#'
#' Poll trend estimation, projection and the candidate-level seat simulation.
#' The seat simulator's per-draw core is compiled (`src/seat_sim_core.cpp`) and
#' reproduces the R loop byte for byte; see [simulate_seat_contests()].
#'
#' @keywords internal
#' @useDynLib auspol, .registration = TRUE
#' @importFrom Rcpp evalCpp
"_PACKAGE"
