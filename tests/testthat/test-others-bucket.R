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

.jur_hist <- function() {
  data.table::data.table(
    pair = c(paste0("vic", 2000 + 0:3), paste0("fed", 2000 + 0:3)),
    date = as.Date("2000-01-01") + c(0:3, 0:3) * 365 + c(0, 0, 0, 0, 30, 30, 30, 30),
    bucket_fc = 10,
    bucket_act = c(7.0, 7.2, 6.9, 7.1, 10.4, 10.6, 10.5, 10.3))
}

test_that("others_bucket_scale_jur falls back to the pooled scale with no earlier election of the jurisdiction", {
  h <- .jur_hist()
  s <- others_bucket_scale_jur(as.Date("2010-01-01"), "nsw", h)
  expect_equal(s$n_jur, 0L)
  expect_equal(s$w, 0)
  expect_equal(s$k, others_bucket_scale(as.Date("2010-01-01"), h)$k)
  # no history at all: k = 1, no error
  expect_equal(others_bucket_scale_jur(as.Date("1999-01-01"), "vic", h)$k, 1)
})

test_that("others_bucket_scale_jur is graceful with one earlier election of the jurisdiction", {
  h <- .jur_hist()
  one <- others_bucket_scale_jur(as.Date("2000-03-01"), "vic", h)  # one vic, one fed election before
  expect_equal(one$n_jur, 1L)
  expect_true(is.finite(one$k)); expect_gt(one$k, 0)
  # a single earlier election overall: no noise estimate, so k = 1
  expect_equal(others_bucket_scale_jur(as.Date("2000-01-15"), "vic", h)$k, 1)
})

test_that("others_bucket_scale_jur is time-forward", {
  h <- .jur_hist()
  s1 <- others_bucket_scale_jur(as.Date("2002-06-01"), "vic", h)
  # a later election with a wild miss, in this jurisdiction and in another
  h2 <- rbind(h, data.table::data.table(pair = c("vic2050", "fed2050"),
                                        date = as.Date(c("2050-01-01", "2050-01-01")),
                                        bucket_fc = 10, bucket_act = c(1, 30)))
  s2 <- others_bucket_scale_jur(as.Date("2002-06-01"), "vic", h2)
  expect_identical(s1[c("k", "w", "n", "n_jur", "tau2")], s2[c("k", "w", "n", "n_jur", "tau2")])
  expect_false("vic2050" %in% s2$pairs)
})

test_that("others_bucket_scale_jur follows a jurisdiction whose bias differs from the pool", {
  h <- .jur_hist()
  before <- as.Date("2004-01-01")
  sv <- others_bucket_scale_jur(before, "vic", h)
  sf <- others_bucket_scale_jur(before, "fed", h)
  pooled <- others_bucket_scale(before, h)$k
  expect_lt(sv$k, pooled)   # vic bucket over-forecast: shrinks harder than the pool
  expect_gt(sf$k, pooled)   # fed under-forecast: shrinks less
  expect_gt(sv$w, 0.5)
  expect_equal(sv$region, "vic")
})

test_that("AUSPOL_OTHERS_SCALE_JUR is off by default in both the registry and the code", {
  pf_path <- testthat::test_path("..", "..", "scripts", "published_flags.R")
  skip_if_not(file.exists(pf_path))   # the installed package and R CMD check carry no scripts/
  pf <- readLines(pf_path, warn = FALSE)
  line <- grep("^\\s*AUSPOL_OTHERS_SCALE_JUR\\s*=", pf, value = TRUE)
  expect_length(line, 1L)
  expect_match(line, "=\\s*\"0\"")
  fm <- readLines(file.path(dirname(dirname(pf_path)), "R", "forecast_mode.R"), warn = FALSE)
  expect_true(any(grepl("Sys.getenv(\"AUSPOL_OTHERS_SCALE_JUR\", \"0\")", fm, fixed = TRUE)))
})
