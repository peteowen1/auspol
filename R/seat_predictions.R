#' This rebuild's as-at seat predictions, for the post-xgb corrections to learn from
#'
#' The seat-poll blend, the demographic correction and the leader-seat bonus
#' each learn from earlier elections' misses of the as-at xgb prediction. They
#' used to read `output/forecasts.csv`, which is written at rebuild stage 7,
#' so stage 6 always learned from the PREVIOUS rebuild's predictions and every
#' result depended on the run before it (vic2026's leader bonus 2.33 or 1.05
#' depending on which rebuild came first). Stage 4 writes the same predictions
#' for THIS run to `output/xgb-primary-asat-predictions.csv` (identical to the
#' forecasts table within a run, 11,643 of 11,643 rows, 2026-09-30); this reads
#' that, falling back to the forecasts table only when it is absent.
#'
#' @return data.table `election`, `seat`, `party`, `xgb_pred_seat`,
#'   `actual_share`, or NULL when neither file exists.
#' @export
current_seat_predictions <- function() {
  f <- out_path("xgb-primary-asat-predictions.csv")
  if (file.exists(f)) {
    a <- data.table::fread(f, showProgress = FALSE)
    a[, xgb_pred_seat := 100 * xgb_pred / sum(xgb_pred), by = list(pair, seat)]
    return(a[, list(election = pair, seat, party, xgb_pred_seat, actual_share)])
  }
  fc <- out_path("forecasts.csv")
  if (!file.exists(fc)) return(NULL)
  cat("SPR0! xgb-primary-asat-predictions.csv absent: corrections learn from the previous rebuild's forecasts.csv\n")
  x <- data.table::fread(fc, showProgress = FALSE)
  x[, list(xgb_pred_seat = sum(xgb_pred_seat), actual_share = sum(actual_share)), by = list(election, seat, party)]
}

#' Whether this machine has seat predictions to learn from (else: shipped tables)
#' @keywords internal
.has_seat_predictions <- function() {
  file.exists(out_path("xgb-primary-asat-predictions.csv")) || file.exists(out_path("forecasts.csv"))
}
