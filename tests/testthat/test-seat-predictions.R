test_that("this rebuild's as-at predictions match the forecasts table built from them", {
  a <- out_path("xgb-primary-asat-predictions.csv"); f <- out_path("forecasts.csv")
  skip_if_not(file.exists(a) && file.exists(f), "no rebuild outputs")
  skip_if(file.mtime(f) < file.mtime(a), "forecasts.csv older than the as-at predictions (mid-rebuild)")
  x <- current_seat_predictions()
  y <- data.table::fread(f)[, list(fc = sum(xgb_pred_seat)), by = list(election, seat, party)]
  m <- merge(x, y, by = c("election", "seat", "party"))
  expect_equal(nrow(m), nrow(x))
  expect_lt(max(abs(m$xgb_pred_seat - m$fc)), 1e-8)
})
