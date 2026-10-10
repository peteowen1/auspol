# AUSPOL_IND_PERSON (R/ind_person.R; plans/prereg-ind-person-2026-10-10.md).
# The case table and the cells are mocked, so these run without the corpus.

test_that("the linear carry bounds its slope to 0..1 and refits the intercept", {
  # wa2008, n=4, had fitted 78.6 - 10.9 x record
  local_mocked_bindings(.ip_cases = function(C) data.table::data.table(
    election = c("wa2001", "wa2001", "wa2005", "wa2005"), record = c(2, 4, 6, 8), actual = c(20, 10, 4, 2)))
  f <- ind_person_carry_fit("wa2008", corpus = data.table::data.table())
  expect_true(f$linear)
  expect_true(f$bounded)
  expect_identical(f$b, 0)
  expect_equal(f$a, mean(c(20, 10, 4, 2)))
})

test_that("a constant record (NA slope) is bounded, and fewer than 3 cases keeps the ratio", {
  local_mocked_bindings(.ip_cases = function(C) data.table::data.table(
    election = c("fed2004", "fed2004", "fed2004"), record = c(5, 5, 5), actual = c(3, 4, 5)))
  f <- ind_person_carry_fit("fed2007", corpus = data.table::data.table())
  expect_identical(f$b, 0)
  expect_equal(f$a, 4)
  local_mocked_bindings(.ip_cases = function(C) data.table::data.table(
    election = c("fed2004", "fed2004"), record = c(5, 6), actual = c(3, 4)))
  expect_false(ind_person_carry_fit("fed2007", corpus = data.table::data.table())$linear)
  # nothing dated on or after the target is used
  local_mocked_bindings(.ip_cases = function(C) data.table::data.table(
    election = c("fed2007", "fed2010", "fed2013"), record = c(1, 2, 3), actual = c(1, 2, 3)))
  expect_identical(ind_person_carry_fit("fed2007", corpus = data.table::data.table())$n, 0L)
})

test_that("direction 'lower' only lowers a cell, and the row keeps its total", {
  sh <- matrix(c(50, 40, 30, 30, 10, 20), nrow = 2, dimnames = list(c("Alpha", "Beta"), c("ALP", "LNP", "IND")))
  cells <- data.table::data.table(seat = c("Alpha", "Beta"), skey = normalise_seat(c("Alpha", "Beta")),
                                  name = c("A", "B"), record = c(1, 40), record_election = "vic2014",
                                  record_seat = "X", carry = 0.5, value = c(2, 35))
  local_mocked_bindings(ind_person_cells = function(target, corpus = NULL) cells)
  withr::local_envvar(AUSPOL_IND_PERSON = "final", AUSPOL_IND_PERSON_CARRY = "ratio", AUSPOL_IND_PERSON_DIR = "lower")
  out <- NULL
  capture.output(out <- ind_person_apply(sh, "vic2022", stage = "final"))
  expect_equal(out["Alpha", "IND"], 2)            # 10 -> 2: lowered
  expect_equal(out["Beta", "IND"], 20)            # 35 would raise it: left alone
  expect_equal(rowSums(out), rowSums(sh))
  withr::local_envvar(AUSPOL_IND_PERSON_DIR = "both")
  capture.output(out <- ind_person_apply(sh, "vic2022", stage = "final"))
  expect_equal(out["Beta", "IND"], 35)
  expect_equal(rowSums(out), rowSums(sh))
  # wrong stage, or off: untouched
  expect_identical(ind_person_apply(sh, "vic2022", stage = "base"), sh)
  withr::local_envvar(AUSPOL_IND_PERSON = "0")
  expect_identical(ind_person_apply(sh, "vic2022", stage = "final"), sh)
})
