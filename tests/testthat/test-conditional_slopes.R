R0 <- data.table::data.table(
  seat = c("A", "B", "C"), party = "IND", same = c(TRUE, FALSE, TRUE))

test_that("returning seats get the same-candidate slope and others the new one", {
  s <- conditional_slopes("IND", c("A", "B", "C"), R0)
  expect_equal(s, c(0.907, 0.326, 0.907))
})

test_that("seats are matched BY NAME, not by position", {
  # The shares matrix and the corpus are ordered differently; a positional join
  # would hand a seat another seat's candidate history.
  s <- conditional_slopes("IND", c("C", "A", "B"), R0)
  expect_equal(s, c(0.907, 0.907, 0.326))
})

test_that("a seat absent from the returns table is treated as NEW", {
  s <- conditional_slopes("IND", c("A", "ZZZ"), R0)
  expect_equal(s, c(0.907, 0.326))
})

test_that("a class the fit never saw stays on uniform swing", {
  # Better than borrowing another class's number: ALP is not in the table, so
  # it must be left alone rather than given IND's 0.326.
  expect_equal(conditional_slopes("ALP", c("A", "B"), R0), c(1, 1))
})

test_that("NULL returns leaves everything on the default", {
  expect_equal(conditional_slopes("IND", c("A", "B"), NULL), c(1, 1))
})

test_that("the output always matches the seat vector length", {
  for (n in c(1L, 3L, 10L))
    expect_length(conditional_slopes("IND", paste0("s", seq_len(n)), R0), n)
})

R1 <- data.table::data.table(seat = c("A","B","C"), party = "IND", same = c(TRUE, FALSE, FALSE))

test_that("screened_slopes: returning keeps its slope regardless of permit", {
  s <- screened_slopes("IND", c("A","B","C"), R1, permit = c(FALSE, FALSE, TRUE))
  expect_equal(s[1], 0.907)   # A returns; permit is irrelevant
})

test_that("screened_slopes: new + screen-refused keeps the harsh new slope", {
  s <- screened_slopes("IND", c("A","B","C"), R1, permit = c(TRUE, FALSE, FALSE))
  expect_equal(s[2], 0.326)   # B is new and refused
})

test_that("screened_slopes: new + screen-permitted goes to UNIFORM, not the new slope", {
  # This is the whole point: arm C crushed Dai Le (new, but a real emergence)
  # with 0.326. The screen should protect her.
  s <- screened_slopes("IND", c("A","B","C"), R1, permit = c(FALSE, FALSE, TRUE))
  expect_equal(s[3], 1.0)
})

test_that("screened_slopes falls back to conditional_slopes for an unfitted class", {
  expect_equal(screened_slopes("ALP", c("A","B"), R1, permit = c(TRUE, TRUE)), c(1, 1))
})

test_that("mismatched permit length is an error", {
  expect_error(screened_slopes("IND", c("A","B"), R1, permit = TRUE), "same length")
})

test_that("screened_slopes: a permit does not override a departed leader", {
  seats <- c("s1", "s2", "s3")
  # s1: new candidate, permitted, prior leader RETURNS (elsewhere in the seat) -> 1.0
  # s2: new candidate, permitted, prior leader DEPARTED -> the new slope
  # s3: returning candidate -> the same slope, permit irrelevant
  returns <- data.table::data.table(seat = seats, party = "IND",
                                    same = c(FALSE, FALSE, TRUE), same_mp = FALSE,
                                    prior_leader_returns = c(TRUE, FALSE, TRUE))
  sl <- screened_slopes("IND", seats, returns, permit = c(TRUE, TRUE, TRUE), honour_departed = TRUE)
  expect_equal(sl[1], 1.0)
  expect_equal(sl[2], 0.326)
  expect_equal(sl[3], 0.907)
  # Old-shape `returns` without the column: every leader taken as returning.
  old <- returns[, list(seat, party, same, same_mp)]
  expect_equal(screened_slopes("IND", seats, old, permit = c(TRUE, TRUE, TRUE), honour_departed = TRUE)[2], 1.0)
  # And the DEFAULT is off (refused 2026-09-06): the departed case gets 1.0 as before.
  expect_equal(screened_slopes("IND", seats, returns, permit = c(TRUE, TRUE, TRUE))[2], 1.0)
})
