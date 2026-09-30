test_that("federal-booth primaries and departed-member inputs are built from the booth map", {
  skip_if_not(file.exists(file.path(pkg_root(), "external", "elections", "fed-booth-map.csv")), "no booth map")
  fb <- fed_booth_primaries("nsw2023")
  p <- fb[fb$seat == "Parramatta"]
  expect_equal(sum(p$fed_pct), 100, tolerance = 1e-8)
  expect_gt(p$fed_pct[p$class == "LNP"], 25); expect_lt(p$fed_pct[p$class == "LNP"], 35)
  x <- .departed_inputs("nsw2023")
  expect_true("Parramatta" %in% x$seat)
  expect_equal(x$gap, x$prev - x$fed)
})

test_that("departed-member weights learn from state elections before the target only", {
  skip_if(is.null(current_seat_predictions()), "no rebuild outputs")
  w <- departed_fed_weights("nsw2023")
  expect_false(any(w$els %in% c("nsw2023", "qld2024", "sa2026")))
  expect_false(any(grepl("^fed", w$els)))
  expect_gte(w$beta, 0); expect_lte(w$beta, 1)
  if (is.finite(w$k)) { expect_gte(w$k, 0); expect_lte(w$k, 1) }   # k is NA when too little earlier data
})
