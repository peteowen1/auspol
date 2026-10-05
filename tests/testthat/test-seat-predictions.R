test_that("this rebuild's as-at predictions match the forecasts table built from them", {
  a <- out_path("xgb-primary-asat-predictions.csv"); f <- out_path("forecasts.csv")
  skip_if_not(file.exists(a) && file.exists(f), "no rebuild outputs")
  skip_if(file.mtime(f) < file.mtime(a), "forecasts.csv older than the as-at predictions (mid-rebuild)")
  x <- current_seat_predictions()
  F <- data.table::fread(f)
  # v61 nomination zeroing runs in the TABLE (scripts/build_forecasts_table.R),
  # after the as-at predictions: a class that did not stand is zeroed and its
  # share redistributed across the seat, so every cell of a touched seat may
  # differ from the as-at file. Compare untouched seats exactly; for touched
  # ones, check that the zeroed cells really had no candidate.
  if ("xgb_pred_prezero" %in% names(F)) {
    expect_false(anyNA(F$xgb_pred_prezero))   # an NA would silently drop rows below
    F[, .touched := any(abs(xgb_pred - xgb_pred_prezero) > 1e-9), by = list(election, seat)]
    z <- F[.touched == TRUE & xgb_pred == 0 & xgb_pred_prezero > 0]
    expect_gt(nrow(z), 0)                     # zeroing must have fired, or all() below is vacuous
    expect_true(all(z$actual_share == 0))
  } else F[, .touched := FALSE]
  y <- F[.touched == FALSE, list(fc = sum(xgb_pred_seat)), by = list(election, seat, party)]
  # ~500 of ~1,800 SEATS are untouched (2026-10-05: a minor class is absent
  # somewhere in most seats); an empty comparison must not pass vacuously.
  expect_gt(data.table::uniqueN(y[, list(election, seat)]), 300)
  m <- merge(x, y, by = c("election", "seat", "party"))
  expect_equal(nrow(m), nrow(y))
  expect_lt(max(abs(m$xgb_pred_seat - m$fc)), 1e-8)
})
