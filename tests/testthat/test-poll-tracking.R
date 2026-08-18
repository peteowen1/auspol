# poll_tracking_check() replaces the endpoint-sum check. Its whole value is
# being able to FAIL, and to say so rather than passing vacuously when there is
# nothing to assert on -- the failure mode this repo has hit repeatedly
# (`all()` over an empty set is TRUE, `NA > x` is NA, `which()` drops NA).

mk_polls <- function(n = 10, onp = 23, alp = 30, date0 = as.Date("2026-05-01")) {
  d <- data.table::data.table(
    date = date0 + seq_len(n),
    ALP = rep(alp, n),
    ONP = rep(onp, n))
  # Real poll tables carry this; the check needs it to tell a party column from
  # `date`, and to notice a polled party the fit dropped.
  data.table::setattr(d, "parties", c("ALP", "ONP"))
  d
}

mk_fits <- function(alp = 30, onp = 23, date = as.Date("2026-05-20")) {
  one <- function(v) list(trend = data.table::data.table(date = date, mean = v))
  list(ALP = one(alp), ONP = one(onp))
}

test_that("a fit that tracks its polls passes, and the bound is reported", {
  x <- poll_tracking_check(mk_polls(), mk_fits(), bound = 2.5)
  expect_false(any(x$breach))
  expect_true(all(x$asserted))
  expect_equal(attr(x, "bound"), 2.5)
  expect_equal(x[party == "ONP", dev], 0)
})

test_that("a party fitted away from its polls BREACHES, and only that party", {
  x <- poll_tracking_check(mk_polls(onp = 23), mk_fits(onp = 20), bound = 2.5)
  expect_true(x[party == "ONP", breach])
  expect_false(x[party == "ALP", breach])
  expect_equal(x[party == "ONP", dev], 3)
})

test_that("a gap exactly at the bound does not breach", {
  x <- poll_tracking_check(mk_polls(onp = 23), mk_fits(onp = 20.5), bound = 2.5)
  expect_false(any(x$breach))
})

test_that("a party with too few recent polls is NOT asserted on", {
  # Three polls is the floor; two must not be asserted even though the gap is
  # enormous. Reported, not silently passed.
  p <- mk_polls(n = 2, onp = 23)
  x <- poll_tracking_check(p, mk_fits(onp = 5), bound = 2.5, min_polls = 3L)
  expect_false(x[party == "ONP", asserted])
  expect_false(x[party == "ONP", breach])
  expect_equal(x[party == "ONP", n], 2L)
})

test_that("a party with NO recent polls yields NA, never a silent pass", {
  p <- mk_polls()
  p[, ONP := NA_real_]
  x <- poll_tracking_check(p, mk_fits(onp = 99), bound = 2.5)
  expect_true(is.na(x[party == "ONP", poll_mean]))
  expect_false(x[party == "ONP", asserted])
  # The critical line: NA > bound is NA, which any() would swallow. `breach`
  # must be a hard FALSE, and the party must be visibly unasserted.
  expect_identical(x[party == "ONP", breach], FALSE)
})

test_that("polls outside the window are excluded", {
  p <- mk_polls(n = 10, onp = 23, date0 = as.Date("2026-05-01"))
  # One recent poll far from the fit, nine old ones agreeing with it.
  p[date < max(date), ONP := 23]
  p[date == max(date), ONP := 40]
  x <- poll_tracking_check(p, mk_fits(onp = 23), window = 1L, min_polls = 1L)
  expect_equal(x[party == "ONP", n], 1L)
  expect_equal(x[party == "ONP", poll_mean], 40)
  expect_true(x[party == "ONP", breach])
})

test_that("report_poll_tracking does not claim a pass when nothing is asserted", {
  p <- mk_polls(n = 1)
  x <- poll_tracking_check(p, mk_fits(), min_polls = 3L)
  expect_false(any(x$asserted))
  # Must not print "-Inf" from max() over an empty set, and must not error.
  expect_output(report_poll_tracking(x, "T9"), "NOT ASSERTED")
})

test_that("an empty fit list is refused rather than passing", {
  expect_error(poll_tracking_check(mk_polls(), list()))
})

# --- a polled party missing from the fit ------------------------------------
# The failure the SUM check could catch and the first version of this one could
# not: a party the fit dropped has no row at all, so nothing reports it. One
# Nation sits at exactly the 8-poll inclusion floor in NSW 2027, so this is one
# poll away from live, not hypothetical.

test_that("a polled party missing from the fit BREACHES rather than vanishing", {
  p <- mk_polls(n = 10, onp = 23)
  fits <- mk_fits()
  fits$ONP <- NULL                      # the fit dropped it
  x <- poll_tracking_check(p, fits, bound = 2.5)
  expect_true("ONP" %in% x$party)       # the row must EXIST
  expect_true(x[party == "ONP", dropped])
  expect_true(x[party == "ONP", breach])
  expect_equal(x[party == "ONP", n], 10L)
})

test_that("a party dropped from the fit AND barely polled is not asserted on", {
  p <- mk_polls(n = 2, onp = 23)
  fits <- mk_fits(); fits$ONP <- NULL
  x <- poll_tracking_check(p, fits, bound = 2.5, min_polls = 3L)
  expect_false(x[party == "ONP", dropped])
  expect_false(x[party == "ONP", breach])
})

test_that("a fit whose trend has no rows keeps its row instead of disappearing", {
  p <- mk_polls(n = 10)
  fits <- mk_fits()
  fits$ONP$trend <- fits$ONP$trend[0]   # zero-row trend
  x <- poll_tracking_check(p, fits, bound = 2.5)
  expect_true("ONP" %in% x$party)
  expect_true(is.na(x[party == "ONP", fitted]))
  expect_false(x[party == "ONP", fitted_ok])
  expect_true(x[party == "ONP", breach])
})

test_that("report names a dropped party distinctly from a drifted one", {
  p <- mk_polls(n = 10, onp = 23)
  fits <- mk_fits(); fits$ONP <- NULL
  x <- poll_tracking_check(p, fits, bound = 2.5)
  expect_output(report_poll_tracking(x, "T9"), "polled .* but not fitted")
})

test_that("report prints the gap for a drifted party", {
  x <- poll_tracking_check(mk_polls(onp = 23), mk_fits(onp = 20), bound = 2.5)
  expect_output(report_poll_tracking(x, "T9"), "BREACH ONP fitted 20.00 against 23.00")
})

test_that("a party already refolded into OTH is reported, not breached", {
  # refold_unfitted() accounts for an unfitted party's vote by folding it back
  # into OTH. The breach exists to say the model does not account for something
  # the polls measure; once it does, breaching would be a false alarm.
  p <- mk_polls(n = 10, onp = 23)
  data.table::setattr(p, "refolded",
                      data.table::data.table(party = "ONP", added = 23))
  fits <- mk_fits(); fits$ONP <- NULL
  x <- poll_tracking_check(p, fits, bound = 2.5)
  expect_true(x[party == "ONP", refolded_in])
  expect_false(x[party == "ONP", dropped])
  expect_false(x[party == "ONP", breach])
  expect_output(report_poll_tracking(x, "T9"), "folded back into OTH")
})

test_that("a party refolded for a DIFFERENT cycle does not excuse this one", {
  p <- mk_polls(n = 10, onp = 23)
  data.table::setattr(p, "refolded",
                      data.table::data.table(party = "UAP", added = 3))
  fits <- mk_fits(); fits$ONP <- NULL
  x <- poll_tracking_check(p, fits, bound = 2.5)
  expect_false(x[party == "ONP", refolded_in])
  expect_true(x[party == "ONP", breach])
})
