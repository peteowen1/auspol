test_that("surname_of uses the surname field when present", {
  expect_equal(surname_of("DANIEL", "Zoe Daniel"), "daniel")
  expect_equal(surname_of("WY KANAK", "Dominic WY Kanak"), "wykanak")
})

test_that("surname_of parses both state layouts, surname first in each", {
  expect_equal(surname_of(NA, "ROYLANCE, Robert"), "roylance")   # comma
  expect_equal(surname_of(NA, "GREENWICH Alex"), "greenwich")    # space
  expect_equal(surname_of(NA, "O'BRIEN, Sean"), "obrien")
})

test_that("surname_of returns empty rather than guessing", {
  expect_equal(surname_of(NA, NA), "")
  expect_equal(surname_of(NA, ""), "")
})

test_that("stood_before does NOT match a given name against a surname", {
  # Daniel POLLOCK contested Goldstein 2019; Zoe DANIEL first stood in 2022.
  # A six-character prefix match on the full name joined them and recorded her
  # as a returning candidate, removing a real emergence from the test set.
  prev <- c("wilson", "pollock", "pennicuik", "connolly", "hoult", "casley")
  expect_false(stood_before("daniel", prev))
})

test_that("stood_before catches a genuine return under a different party", {
  # Philip Donato held Orange for the Shooters in 2019 and won it as an
  # independent in 2023. Party class changes; the person does not.
  expect_true(stood_before("donato", c("donato", "smith", "jones")))
})

test_that("stood_before is punctuation- and case-insensitive", {
  expect_true(stood_before("O'Brien", c("obrien")))
  expect_true(stood_before("obrien", c("O'BRIEN")))
})

test_that("stood_before never matches on empty", {
  expect_false(stood_before("", c("", "smith")))
  expect_equal(stood_before(c("a", ""), c("a")), c(TRUE, FALSE))
})

test_that("given_of parses both state layouts", {
  expect_equal(given_of(NA, "ROYLANCE, Robert"), "robert")
  expect_equal(given_of(NA, "GREENWICH Alex"), "alex")
  expect_equal(given_of("Zoe", "Zoe Daniel"), "zoe")
  expect_equal(given_of(NA, "SMITH, Mary Jane"), "mary")
})

test_that("match_key separates the Daniel/Pollock collision at every strictness", {
  # Daniel POLLOCK vs Zoe DANIEL -- distinct under all three rules, because the
  # collision was a full-name substring artefact, not a surname clash.
  for (r in c("surname", "initial", "full"))
    expect_false(match_key("daniel", "zoe", r) == match_key("pollock", "daniel", r))
})

test_that("initial survives a nickname that keeps the initial", {
  expect_equal(match_key("chaney", "kate", "initial"),
               match_key("chaney", "katherine", "initial"))
  expect_false(match_key("chaney", "kate", "full") == match_key("chaney", "katherine", "full"))
})

test_that("NO rule survives a nickname that CHANGES the initial", {
  # Bob/Robert, Bill/William, Dick/Richard -- all common in Australian politics.
  # Documented rather than papered over: this is why surname-only is measured
  # alongside the others instead of being dismissed.
  expect_false(match_key("katter", "bob", "initial") == match_key("katter", "robert", "initial"))
  expect_true(match_key("katter", "bob", "surname") == match_key("katter", "robert", "surname"))
})

test_that("initial separates two people sharing a surname", {
  expect_false(match_key("smith", "john", "initial") == match_key("smith", "mary", "initial"))
  expect_true(match_key("smith", "john", "surname") == match_key("smith", "mary", "surname"))
})

test_that("a missing given name falls back to surname rather than erroring", {
  expect_equal(match_key("smith", "", "initial"), "smith")
  expect_equal(match_key("smith", "", "full"), "smith")
})
