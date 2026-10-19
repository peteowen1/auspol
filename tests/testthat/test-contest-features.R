# AUSPOL_XGB_CONTEST (plans/prereg-contest-features-2026-10-20.md)
test_that("stands_i marks candidacies, level_contested scales the level to the seats contested", {
  pair <- rep(c("e1", "e2"), each = 8)
  seat <- rep(rep(c("A", "B", "C", "D"), each = 2), 2)
  party <- rep(c("ALP", "ONP"), 8)
  lvl <- rep(c(40, 2), 8)
  cand <- data.frame(election = c(rep("e1", 5), rep("e2", 6)),
                     seat = c("A", "B", "C", "D", "A", "A", "B", "C", "D", "A", "B"),
                     party = c("ALP", "ALP", "ALP", "ALP", "ONP", "ALP", "ALP", "ALP", "ALP", "ONP", "ONP"))
  cf <- contest_features(pair, seat, party, lvl, paste(cand$election, cand$seat, cand$party), cand$election, cand$seat)
  # e1: One Nation stands in A only -> its level where it stands is 2 * 4 / 1 = 8
  expect_equal(cf$stands_i[pair == "e1" & party == "ONP"], c(1L, 0L, 0L, 0L))
  expect_equal(cf$level_contested[pair == "e1" & party == "ONP"], rep(8, 4))
  # e2: in A and B -> 2 * 4 / 2 = 4; Labor everywhere -> unchanged
  expect_equal(cf$level_contested[pair == "e2" & party == "ONP"], rep(4, 4))
  expect_equal(cf$level_contested[party == "ALP"], rep(40, 8))
  expect_equal(attr(cf, "unknown_seats"), 0L)
})

test_that("a seat with no candidacy at all is unknown and counts as standing", {
  cf <- contest_features(rep("e", 4), c("A", "A", "B", "B"), c("ALP", "ONP", "ALP", "ONP"), c(40, 2, 40, 2),
                         c("e A ALP"), "e", "A")
  expect_equal(cf$stands_i, c(1L, 0L, 1L, 1L))
  expect_equal(attr(cf, "unknown_seats"), 1L)
  expect_equal(cf$level_contested[2], 2 * 2 / 1)
})

test_that("duplicate rows stop", {
  expect_error(contest_features(c("e", "e"), c("A", "A"), c("ALP", "ALP"), c(1, 1), "e A ALP", "e", "A"), "duplicate")
})
