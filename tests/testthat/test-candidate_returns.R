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

test_that("a candidate switching PARTY in the same seat still counts as returning", {
  # Philip Donato held Orange with 49.1% as a Shooter in 2019 and 53.1% as an
  # independent in 2023. Matching within (seat, party) made a five-year sitting
  # member read as a NEW independent -- and as the only failure of the salience
  # screen in an election where it otherwise had none.
  d <- mk()
  d[election == "e2" & seat == "A" & party == "IND", `:=`(surname = "JONES", given = "Bob")]
  r <- candidate_returns("e1", "e2", d)
  expect_true(r[seat == "A" & party == "IND"]$same)   # Bob Jones stood in A as ALP at e1
})

test_that("a DIFFERENT person in the same seat is still new", {
  d <- mk()
  d[election == "e2" & seat == "A" & party == "IND", `:=`(surname = "NOBODY", given = "Zed")]
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

test_that("leading_candidate_returns follows the TOP candidate, not any candidate", {
  # A minor candidate matches a prior name; the actual front-runner is new.
  # Class-level candidate_returns() would say TRUE; the leader-level fact is
  # what a slope should key on.
  d <- data.table::data.table(
    election = c(rep("e1", 2), rep("e2", 2)),
    seat = "A", party = "IND",
    surname = c("MINOR", "OTHER", "FRONTRUNNER", "MINOR"),
    given = c("Pat", "Sam", "Alex", "Pat"),
    pcv = c(3, 20, 40, 2), name = NA_character_)
  cr <- candidate_returns("e1", "e2", d)
  expect_true(cr[seat == "A" & party == "IND"]$same)   # class-level: TRUE (Pat Minor matches)
  lr <- leading_candidate_returns("e1", "e2", d)
  expect_false(lr[seat == "A" & party == "IND"]$leader_same)  # leader Frontrunner is new
})

test_that("leading_candidate_returns matches candidate_returns when there is one candidate", {
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = "A", party = "IND",
    surname = "SMITH", given = "Jane", pcv = c(30, 32), name = NA_character_)
  expect_equal(leading_candidate_returns("e1", "e2", d)$leader_same,
               candidate_returns("e1", "e2", d)$same)
})

test_that("leading_candidate_returns is robust to the seat-naming mismatch that broke a debug script", {
  # vic2018 stores "mildura" lower-case, vic2022 "Mildura" -- the fault
  # candidate_returns() already normalises. An ad-hoc verification script that
  # skipped this normalisation produced a false misattribution for Ali Cupper,
  # who genuinely stood in both elections.
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = c("mildura", "Mildura"), party = "IND",
    surname = "CUPPER", given = "Ali", pcv = c(32.7, 33.9), name = NA_character_)
  expect_true(leading_candidate_returns("e1", "e2", d)$leader_same)
})
