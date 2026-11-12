# dedupe_reference_rows() is the guard added after eventual-results.csv was
# found to carry WA 1993 twice, all six rows duplicated verbatim, silently
# double-counting that cycle in every mean taken over the table.
#
# Tested directly rather than through load_eventual_results(), so it runs in CI,
# which has no anchor clone.

lbl <- function(d) sprintf("%s %s", d$region, d$year)
KEY <- c("year", "region", "party")

make <- function() data.table::data.table(
  year   = c(1993L, 1993L, 1996L),
  region = c("wa", "wa", "fed"),
  party  = c("ALP", "GRN", "ALP"),
  actual = c(37.08, 4.31, 38.75)
)

test_that("a clean table is returned unchanged", {
  x <- make()
  expect_silent(out <- dedupe_reference_rows(x, KEY, "t.csv", lbl))
  expect_identical(out, x)
})

test_that("identical duplicates are dropped, and the cycle is named", {
  x <- rbind(make(), make()[1:2])   # WA 1993 twice, verbatim
  expect_warning(out <- dedupe_reference_rows(x, KEY, "t.csv", lbl),
                 "dropped 2 duplicate row\\(s\\), affecting wa 1993")
  expect_equal(nrow(out), 3L)
  expect_false(as.logical(anyDuplicated(out, by = KEY)))
  # The point of the guard: the mean must stop being dragged by the copy.
  expect_equal(mean(out$actual), mean(make()$actual))
})

test_that("rows that share a key but disagree are REFUSED, not silently picked", {
  x <- rbind(make(), data.table::data.table(
    year = 1993L, region = "wa", party = "ALP", actual = 99.99))
  expect_error(dedupe_reference_rows(x, KEY, "t.csv", lbl),
               "disagreeing on the value: wa 1993")
})

test_that("a disagreement in a NON-value column is caught too", {
  # The first draft compared only `actual`. A table whose rows agree on the
  # number but differ elsewhere would have passed, and one of the two rows
  # would then have been dropped at random.
  x <- data.table::data.table(
    year = c(1993L, 1993L), region = c("wa", "wa"), party = c("ALP", "ALP"),
    actual = c(37.08, 37.08), source = c("official", "estimate"))
  expect_error(dedupe_reference_rows(x, KEY, "t.csv", lbl),
               "disagreeing on the value")
})

test_that("a key column that is not present is refused", {
  expect_error(dedupe_reference_rows(make(), c("year", "nope"), "t.csv", lbl))
})

test_that("apply_eventual_result_fixes corrects only the known-wrong value", {
  fx <- data.table::data.table(year = 2007L, region = "nsw", party = "ALP", wrong = 36.99, right = 38.98, source = "test")
  x <- data.table::data.table(year = c(2007L, 2007L), region = "nsw", party = c("ALP", "LNP"), actual = c(36.99, 38.98))
  expect_message(y <- apply_eventual_result_fixes(x, fx), "EVR1 eventual-results.csv: nsw 2007 ALP corrected 36.99 -> 38.98")
  expect_equal(y$actual, c(38.98, 38.98))
  x2 <- data.table::copy(x); x2$actual[1] <- 38.98                 # upstream already fixed: silent no-op
  expect_silent(y2 <- apply_eventual_result_fixes(x2, fx)); expect_equal(y2$actual[1], 38.98)
  x3 <- data.table::copy(x); x3$actual[1] <- 40                    # neither value: the file changed unchecked
  expect_error(apply_eventual_result_fixes(x3, fx), "EVR1! .*neither")
  expect_error(apply_eventual_result_fixes(x[party == "LNP"], fx), "EVR1! .*found 0")
  # the shipped table swaps the pair back
  z <- apply_eventual_result_fixes(x)
  expect_equal(z$actual, c(38.98, 36.99))
})
