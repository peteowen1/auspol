# AUSPOL_CLASS_CONSERVE (arm A, plans/prereg-partial-contest-2026-10-19.md)
cc_fixture <- function() {
  shares <- matrix(c(48, 40, 10, 2,
                     45, 43, 10, 2,
                     50, 38, 10, 2,
                     40, 48, 10, 2), nrow = 4, byrow = TRUE,
                   dimnames = list(c("A", "B", "C", "D"), c("ALP", "LNP", "OTH", "ONP")))
  # One Nation stands in A only; every other class stands everywhere
  target <- data.table::rbindlist(lapply(rownames(shares), function(s)
    data.table::data.table(seat = s, party = c("ALP", "LNP", "OTH", if (s == "A") "ONP"), votes = 100)))
  list(shares = shares, target = target)
}

test_that("off: a skipped class's share stays in the skipped seats (today's behaviour)", {
  f <- cc_fixture()
  withr::local_envvar(AUSPOL_CLASS_CONSERVE = "0", AUSPOL_NOM_ZERO = "1")
  out <- NULL; invisible(capture.output(out <- zero_unnominated(f$shares, f$target, "t")))
  expect_equal(unname(out["A", "ONP"]), 2)
  expect_equal(mean(out[, "ONP"]), 0.5)
})

test_that("on: the class's seat-mean total comes back in the seat it contests", {
  f <- cc_fixture()
  withr::local_envvar(AUSPOL_CLASS_CONSERVE = "1", AUSPOL_NOM_ZERO = "1")
  out <- NULL
  expect_output(out <- zero_unnominated(f$shares, f$target, "t"), "ONP in 1 of 4 seats, seat-mean 2.00 -> 0.50 restored")
  expect_equal(mean(out[, "ONP"]), 2)                        # 2 statewide, all of it in seat A
  expect_equal(unname(out["A", "ONP"]), 8)
  expect_equal(unname(rowSums(out)), rep(100, 4))
  # seat A's other classes gave the 6 points up in proportion: 98 -> 92
  expect_equal(unname(out["A", c("ALP", "LNP", "OTH")]), c(48, 40, 10) * 92 / 98)
  expect_equal(unname(out[c("B", "C", "D"), "ONP"]), c(0, 0, 0))
})

test_that("on: a bucket class (IND/OTH/OTH_RIGHT) is never conserved", {
  f <- cc_fixture()
  tg <- f$target[!(f$target$party == "OTH" & f$target$seat != "A")]   # OTH stands in A only
  withr::local_envvar(AUSPOL_CLASS_CONSERVE = "1", AUSPOL_NOM_ZERO = "1")
  out <- NULL; invisible(capture.output(out <- zero_unnominated(f$shares, tg, "t")))
  # OTH stood in A only: its seat-mean stays at about a quarter of 10, not restored to 10 (it is a bucket)
  expect_lt(mean(out[, "OTH"]), 3)
  expect_equal(mean(out[, "ONP"]), 2)   # the single party alongside it is still conserved
})

test_that("a bad value stops", {
  withr::local_envvar(AUSPOL_CLASS_CONSERVE = "2")
  expect_error(class_conserve_on(), "must be")
})
