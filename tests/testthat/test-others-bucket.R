test_that("others_bucket_scale never uses an election on or after `before`", {
  h <- data.table::data.table(
    pair = c("a", "b", "c", "d"),
    date = as.Date(c("2010-01-01", "2012-01-01", "2014-01-01", "2016-01-01")),
    bucket_fc = c(10, 10, 10, 10), bucket_act = c(8, 8.5, 8, 2))
  s <- others_bucket_scale("2014-01-01", h)
  expect_equal(s$pairs, c("a", "b"))
  expect_equal(s$n, 2L)
  # a later election with a huge miss must not reach it
  s2 <- others_bucket_scale("2014-01-01", h[pair != "d"])
  expect_equal(s$k, s2$k)
})

test_that("others_bucket_scale is 1 with under two earlier elections", {
  h <- data.table::data.table(pair = c("a", "b"), date = as.Date(c("2010-01-01", "2012-01-01")),
                              bucket_fc = c(10, 10), bucket_act = c(5, 5))
  expect_equal(others_bucket_scale("2011-01-01", h)$k, 1)
  expect_equal(others_bucket_scale("2010-01-01", h)$k, 1)
})

test_that("others_bucket_scale shrinks toward 1 when the bias is noise", {
  clear <- data.table::data.table(pair = letters[1:6], date = as.Date("2000-01-01") + 0:5,
                                  bucket_fc = 10, bucket_act = c(8.6, 8.7, 8.8, 8.6, 8.7, 8.8))
  noisy <- data.table::data.table(pair = letters[1:6], date = as.Date("2000-01-01") + 0:5,
                                  bucket_fc = 10, bucket_act = c(5, 15, 6, 14, 7, 13))
  kc <- others_bucket_scale("2001-01-01", clear)
  kn <- others_bucket_scale("2001-01-01", noisy)
  expect_gt(kc$w, 0.95)
  expect_lt(kc$k, 0.9)
  expect_lt(kn$w, 0.5)
  expect_gt(abs(log(kc$k)), abs(log(kn$k)))
})

test_that("others_bucket_apply keeps each row total and scales only the bucket", {
  d <- matrix(c(40, 35, 10, 15,
                30, 40, 12, 18), nrow = 2, byrow = TRUE,
              dimnames = list(NULL, c("ALP", "LNP", "GRN", "OTH")))
  out <- others_bucket_apply(d, "OTH", 0.8)
  expect_equal(rowSums(out), rowSums(d))
  expect_equal(unname(out[, "OTH"]), unname(d[, "OTH"] * 0.8))
  # the rest keep their proportions
  expect_equal(unname(out[1, "ALP"] / out[1, "LNP"]), 40 / 35)
  expect_identical(others_bucket_apply(d, "OTH", 1), d)
})
