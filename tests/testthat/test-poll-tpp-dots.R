test_that("poll_tpp_dots keeps only polls with a published two-party figure, oldest first", {
  cp <- data.table::data.table(date = as.Date(c("2026-11-10", "2026-10-01", "2026-11-01")),
                               firm = c("A", "B", "C"), tpp_published = c(44.04, NA, 45.96), ALP = c(25, 26, 27))
  d <- poll_tpp_dots(cp)
  expect_equal(nrow(d), 2L)
  expect_equal(d$date, c("2026-11-01", "2026-11-10"))
  expect_equal(d$firm, c("C", "A"))
  expect_equal(d$v, c(46.0, 44.0))
})

test_that("poll_tpp_dots stops when the polls carry no two-party column", {
  cp <- data.table::data.table(date = as.Date("2026-11-10"), firm = "A", ALP = 25)
  expect_error(poll_tpp_dots(cp), "no tpp_published")
})

test_that("poll_tpp_dots returns zero rows, not an error, when no poll published one", {
  cp <- data.table::data.table(date = as.Date("2026-11-10"), firm = "A", tpp_published = NA_real_)
  expect_equal(nrow(poll_tpp_dots(cp)), 0L)
})
