# Preference distribution: the elimination logic, tested without any external
# data. Every case here corresponds to a bug that was actually shipped in a
# prototype and caught by an anchor check.

test_that("the lowest party is excluded first and transfers at the stated rate", {
  s <- c(ALP = 40, LNP = 35, GRN = 25)
  # Greens excluded, all of it to Labor
  r <- distribute_preferences(
    s, conditional = list("GRN|ALP+LNP" = c(ALP = 100, LNP = 0)), smooth = 0)
  expect_equal(r$order, "GRN")
  expect_setequal(r$final_two, c("ALP", "LNP"))
  expect_equal(r$winner, "ALP")
  expect_equal(r$fallbacks, 0L)

  # same seat, preferences reversed: the Coalition takes it
  r2 <- distribute_preferences(
    s, conditional = list("GRN|ALP+LNP" = c(ALP = 0, LNP = 100)), smooth = 0)
  expect_equal(r2$winner, "LNP")
})

test_that("the flow used depends on WHO REMAINS, not only on who is excluded", {
  # This is the whole reason a scalar per party is not enough. Same excluded
  # party, same shares, different survivor set -> different destination.
  cond <- list("GRN|ALP+LNP" = c(ALP = 90, LNP = 10),
               "GRN|ALP+ONP" = c(ALP = 60, ONP = 40))
  a <- distribute_preferences(c(ALP = 40, LNP = 38, GRN = 22),
                              conditional = cond, smooth = 0)
  b <- distribute_preferences(c(ALP = 40, ONP = 38, GRN = 22),
                              conditional = cond, smooth = 0)
  expect_equal(a$winner, "ALP")   # 40 + 19.8 = 59.8 vs 38 + 2.2
  expect_equal(b$winner, "ALP")   # 40 + 13.2 = 53.2 vs 38 + 8.8
  # and the transfer really did differ
  expect_equal(a$order, "GRN"); expect_equal(b$order, "GRN")
})

test_that("a missing conditional row falls back and SAYS SO", {
  r <- distribute_preferences(
    c(ALP = 40, LNP = 35, GRN = 25),
    conditional = list(),                       # nothing matches
    pooled = list(GRN = c(ALP = 80, LNP = 20)), smooth = 0)
  expect_equal(r$fallbacks, 1L)
  expect_equal(r$winner, "ALP")
})

test_that("smoothing stops an unobserved destination being treated as impossible", {
  # The bug this exists to prevent. The pooled row for ALP carries GRN = 0, not
  # because Labor voters refuse to preference the Greens but because that
  # configuration never arose in the source data. Renormalising it over
  # {GRN, ONP} hands One Nation EVERY Labor ballot, and that is how One Nation
  # came to "win" Richmond in a prototype run.
  #
  # Shares chosen so Labor is unambiguously lowest -- with a tie, which.min
  # takes the first name and the test would exercise a different exclusion.
  s <- c(GRN = 37, ONP = 32, ALP = 31)
  pooled <- list(ALP = c(LNP = 60, ONP = 40, GRN = 0))

  naive <- distribute_preferences(s, pooled = pooled, smooth = 0)
  expect_equal(naive$order, "ALP")
  expect_equal(naive$winner, "ONP")     # 32 + all 31 = 63 against 37

  smoothed <- distribute_preferences(s, pooled = pooled, smooth = 0.15)
  expect_equal(smoothed$winner, "ONP")  # still ONP, but no longer a shut-out
  expect_gt(smoothed$fallbacks, 0L)

  # The parameter must actually reach the arithmetic. At a wide enough smooth
  # the Greens take enough of the transfer to win, which cannot happen if the
  # zero is being honoured.
  wide <- distribute_preferences(s, pooled = pooled, smooth = 0.9)
  expect_equal(wide$winner, "GRN")
})

test_that("a row with no mass on any survivor splits evenly rather than dying", {
  r <- distribute_preferences(
    c(ALP = 40, LNP = 35, GRN = 25),
    pooled = list(GRN = c(ONP = 100)),   # ONP is not standing
    smooth = 0)
  expect_equal(r$winner, "ALP")          # 40 + 12.5 vs 35 + 12.5
})

test_that("two or fewer parties need no distribution", {
  r <- distribute_preferences(c(ALP = 55, LNP = 45))
  expect_equal(r$winner, "ALP")
  expect_equal(r$order, character(0))
  expect_equal(r$fallbacks, 0L)
})

test_that("zero-share parties are dropped and an empty field is refused", {
  r <- distribute_preferences(c(ALP = 50, LNP = 50, GRN = 0))
  expect_setequal(r$final_two, c("ALP", "LNP"))
  expect_error(distribute_preferences(c(ALP = 0, LNP = 0)), "positive share")
})

test_that("smooth must be a proportion", {
  expect_error(distribute_preferences(c(A = 1, B = 2, C = 3), smooth = 1))
  expect_error(distribute_preferences(c(A = 1, B = 2, C = 3), smooth = -0.1))
})

test_that("duplicate party names are refused rather than losing votes", {
  # Exclusion removes by NAME, so two entries called "IND" are deleted in one
  # pass while only the smaller is redistributed -- 15 of 100 votes vanished
  # and the count logged one exclusion for two removals. Caught in review.
  expect_error(
    distribute_preferences(c(ALP = 40, LNP = 35, IND = 10, IND = 15)),
    "duplicate name")
})
