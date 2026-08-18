# refold_unfitted() is the mirror of unfold_others(): it adds an UNFITTED
# party's reported share back into OTH on the rows that break it out, so OTH
# means one thing across the cycle. Its risk is doing something when it should
# do nothing.

mk <- function(onp = c(5, 5, NA, NA), oth = c(10, 10, 15, 15),
               alp = 40, lnp = 35, grn = 10) {
  n <- length(onp)
  d <- data.table::data.table(
    date = as.Date("2026-01-01") + seq_len(n),
    firm = rep(c("A", "B"), length.out = n),
    ALP = rep(alp, n), LNP = rep(lnp, n), GRN = rep(grn, n),
    ONP = onp, OTH = oth)
  data.table::setattr(d, "parties", c("ALP", "LNP", "GRN", "ONP", "OTH"))
  d
}

# Rows 1-2 report ONP and sum to 40+35+10+5+10 = 100, so their OTH excludes it.
# Rows 3-4 omit ONP and sum to 40+35+10+15 = 100, so their OTH includes it.

test_that("an unfitted party is added back only on the rows that break it out", {
  p <- mk()
  out <- refold_unfitted(p, fits = list(ALP = 1, LNP = 1, GRN = 1, OTH = 1))
  expect_equal(out$OTH, c(15, 15, 15, 15))
  rf <- attr(out, "refolded")
  expect_equal(nrow(rf), 2L)
  expect_true(all(rf$party == "ONP"))
  expect_equal(rf$added, c(5, 5))
})

test_that("a FITTED party is left entirely alone", {
  p <- mk()
  out <- refold_unfitted(p, fits = list(ALP = 1, GRN = 1, ONP = 1, OTH = 1))
  expect_equal(out$OTH, p$OTH)
  expect_null(attr(out, "refolded"))
})

test_that("a row that only reaches 100 WITHOUT the party is not touched", {
  # ONP reported, but the row sums to 105 with it -- so OTH already includes
  # ONP and adding it again would double-count.
  p <- mk(onp = c(5, 5, NA, NA), oth = c(15, 15, 15, 15))
  out <- refold_unfitted(p, fits = list(ALP = 1, GRN = 1))
  expect_equal(out$OTH, p$OTH)
  expect_null(attr(out, "refolded"))
})

test_that("majors and the residual are never candidates", {
  p <- mk()
  out <- refold_unfitted(p, fits = list(GRN = 1))
  rf <- attr(out, "refolded")
  expect_false(any(c("ALP", "LNP", "OTH") %in% rf$party))
})

test_that("a party with no OTH column value is skipped", {
  p <- mk()
  p[, OTH := NA_real_]
  out <- refold_unfitted(p, fits = list(ALP = 1, GRN = 1))
  expect_null(attr(out, "refolded"))
})

test_that("poll attributes survive, so downstream fitting still works", {
  p <- mk()
  out <- refold_unfitted(p, fits = list(ALP = 1, GRN = 1))
  expect_equal(attr(out, "parties"), attr(p, "parties"))
})

test_that("the input is not modified in place", {
  p <- mk()
  before <- data.table::copy(p$OTH)
  invisible(refold_unfitted(p, fits = list(ALP = 1, GRN = 1)))
  expect_equal(p$OTH, before)
})

test_that("broken_out_rows is the exact mirror of folded_rows", {
  p <- mk()
  # Rows 1-2 break ONP out; rows 3-4 fold it in. No row can be both.
  b <- broken_out_rows(p, "ONP")
  f <- folded_rows(p, "ONP")
  expect_equal(b, c(TRUE, TRUE, FALSE, FALSE))
  expect_equal(f, c(FALSE, FALSE, TRUE, TRUE))
  expect_false(any(b & f))
})

test_that("an unfitted GRN is a candidate too -- the rule is about being unfitted", {
  # Not a quirk of the test data: the function keys on "not in fits", not on a
  # hardcoded list of small parties. Only majors and the residual are exempt.
  p <- mk()
  out <- refold_unfitted(p, fits = list(ALP = 1, ONP = 1))
  rf <- attr(out, "refolded")
  expect_true("GRN" %in% rf$party)
  expect_false("ONP" %in% rf$party)
})
