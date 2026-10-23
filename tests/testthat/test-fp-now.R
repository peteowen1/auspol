mk_tr <- function(means, lo = means - 2, hi = means + 2) {
  data.table::rbindlist(lapply(seq_along(means), function(i) data.table::data.table(
    party = names(means)[i], date = as.Date("2026-10-01") + 0:1,
    mean = c(means[[i]] + 5, means[[i]]), lo95 = c(lo[i] + 5, lo[i]), hi95 = c(hi[i] + 5, hi[i]))))
}
sum_m <- function(x) sum(vapply(x, `[[`, 0, "m"))

test_that("fp_now adds to 100.0 from the NSW and Vic live shapes, on the latest date", {
  nsw <- c(LNP = 23.4, ALP = 31.0, ONP = 22.1, GRN = 11.3, OTH = 10.4)   # sums to 98.2
  r <- fp_now_normalised(mk_tr(nsw), names(nsw))
  expect_equal(sum_m(r), 100, tolerance = 1e-9)
  expect_equal(vapply(r, `[[`, "", "party"), names(nsw))
  expect_true(all(vapply(r, function(d) d$lo <= d$m && d$m <= d$hi, TRUE)))
  # raw means were 98.2, so each share grows by about 1.8% of itself: ALP's 31.0 moves ~0.6 points
  expect_lt(max(abs(vapply(r, `[[`, 0, "m") - nsw)), 0.7)
  vic <- c(LNP = 30, ALP = 30, ONP = 14.6, GRN = 12, OTH = 10.9)           # sums to 97.5
  expect_equal(sum_m(fp_now_normalised(mk_tr(vic), names(vic))), 100, tolerance = 1e-9)
})

test_that("fp_now is untouched when the means already add to 100, and refuses bad input", {
  ok <- c(A = 40, B = 35, C = 25)
  r <- fp_now_normalised(mk_tr(ok), names(ok))
  expect_equal(vapply(r, `[[`, 0, "m"), unname(ok))
  expect_error(fp_now_normalised(mk_tr(ok), c("A", "Z")), "no trend rows")
  bad <- mk_tr(ok); bad[party == "B", lo95 := NA_real_]
  expect_error(fp_now_normalised(bad, names(ok)), "finite")
})

test_that("fp_now rounding cannot leave 99.9 or 100.1", {
  set.seed(1)
  for (i in 1:200) {
    m <- stats::setNames(stats::runif(5, 3, 40), c("LNP", "ALP", "ONP", "GRN", "OTH"))
    expect_equal(sum_m(fp_now_normalised(mk_tr(m), names(m))), 100, tolerance = 1e-9)
  }
})
