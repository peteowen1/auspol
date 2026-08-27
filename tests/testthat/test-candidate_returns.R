mk <- function() data.table::data.table(
  election = c(rep("e1", 4), rep("e2", 5)),
  seat  = c("A", "A", "B", "B",  "A", "A", "B", "B", "C"),
  party = c("IND", "ALP", "IND", "ALP",  "IND", "ALP", "IND", "ALP", "IND"),
  surname = c("SMITH", "JONES", "BROWN", "LEE",
              "SMITH", "JONES", "TAYLOR", "LEE", "NEW"),
  given = c("Jane", "Bob", "Ann", "Kim",  "Jane", "Bob", "Ray", "Kim", "Zoe"),
  name = NA_character_)

test_that("a returning candidate is found and a replacement is not", {
  r <- candidate_returns("e1", "e2", mk())
  expect_true(r[seat == "A" & party == "IND"]$same)   # Jane Smith, both
  expect_false(r[seat == "B" & party == "IND"]$same)  # Brown -> Taylor
})

test_that("a seat with no prior election of that class reads FALSE, not NA", {
  # There is nobody to return, which is the correct reading and must not be
  # missing -- an NA would propagate into a slope and silently produce NA shares.
  r <- candidate_returns("e1", "e2", mk())
  expect_false(r[seat == "C" & party == "IND"]$same)
  expect_false(anyNA(r$same))
})

test_that("every seat/class at the target election is present", {
  r <- candidate_returns("e1", "e2", mk())
  expect_equal(nrow(r), 5L)
})

test_that("a candidate switching CLASS in the same seat does not count", {
  # Party class is the unit the slope applies to, so a person who moves from
  # IND to ALP has not returned FOR THAT CLASS.
  d <- mk()
  d[election == "e2" & seat == "A" & party == "ALP", `:=`(surname = "SMITH", given = "Jane")]
  d[election == "e2" & seat == "A" & party == "IND", `:=`(surname = "OTHER", given = "Pat")]
  r <- candidate_returns("e1", "e2", d)
  expect_false(r[seat == "A" & party == "IND"]$same)
})

test_that("a missing corpus column is an error rather than a silent FALSE", {
  expect_error(candidate_returns("e1", "e2", data.table::data.table(x = 1)), "lacks")
})

test_that("an unknown election label is an error, not an empty result", {
  expect_error(candidate_returns("nope", "e2", mk()), "no rows for election nope")
})

test_that("seat names are matched across differing conventions", {
  # The corpus stores vic2018 as "albertpark" and vic2022 as "Albert Park".
  # An exact join matched ZERO of 508 seat-classes and read as "nobody
  # re-stands in Victoria", which is false and would make arm C a silent no-op
  # in the live target state.
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = c("albertpark", "Albert Park"),
    party = "IND", surname = "SMITH", given = "Jane", name = NA_character_)
  r <- candidate_returns("e1", "e2", d)
  expect_true(r$same)
  expect_equal(r$seat, "Albert Park")   # the TARGET election's spelling
})
