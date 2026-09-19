test_that("forecast_statewide_or_oracle returns the oracle untouched unless mode is 1", {
  st_b <- c(ALP = 40, LNP = 38, GRN = 12, OTH = 10)
  expect_identical(forecast_statewide_or_oracle("vic", 2022L, "2022-11-26", names(st_b), st_b, st_b, mode = "0"), st_b)
  expect_identical(forecast_statewide_or_oracle("vic", 2022L, "2022-11-26", names(st_b), st_b, st_b, mode = ""), st_b)
})
