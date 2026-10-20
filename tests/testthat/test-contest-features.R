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

# AUSPOL_CONTEST_BASE (plans/prereg-contest-base-2026-10-20.md)
test_that("contest_base_gap spreads what returning seats leave over the new-to-seat seats", {
  # 4 seats, level 3 -> 12 seat-points. Returning seat A holds 6; new seats B, C share the other 6 -> fill 3 each.
  g <- contest_base_gap(rep("e", 4), c("A", "B", "C", "D"), rep("ONP", 4), base_pred = c(6, 1, 2, 0),
                        prev_share = c(5, NA, 0, NA), level_pred = rep(3, 4), stands = c(TRUE, TRUE, TRUE, FALSE))
  expect_equal(g, c(0, 2, 1, 0))
  # another class, or a seat it does not stand in, never moves
  expect_equal(contest_base_gap("e", "A", "IND", 1, NA, 3, TRUE), 0)
  # returning seats already over the whole level -> fill floored at 0, gap negative
  expect_equal(contest_base_gap(rep("e", 2), c("A", "B"), rep("ONP", 2), c(9, 1), c(5, NA), c(2, 2), c(TRUE, TRUE)), c(0, -1))
})

test_that("fit_contest_base_weight uses earlier elections only and shrinks a noisy slope", {
  pair <- rep(c("nsw2015", "nsw2019", "nsw2023"), each = 4)
  gap <- rep(c(2, 4, 6, 8), 3)
  resid <- c(1, 2, 3, 4, 1.2, 1.8, 3.1, 4.0, 50, 50, 50, 50)    # nsw2023 is wild
  w19 <- fit_contest_base_weight(gap, resid, pair, "nsw2019")
  expect_equal(w19$w, 0)                                          # one earlier election -> no weight
  w23 <- fit_contest_base_weight(gap, resid, pair, "nsw2023")
  expect_equal(w23$k, 2L)
  expect_true(w23$w > 0.45 && w23$w < 0.51)                        # ~0.5, untouched by nsw2023's own rows
  expect_true(w23$w <= w23$raw)                                   # shrunk toward 0, never away
  expect_equal(fit_contest_base_weight(gap, resid, pair, "nsw2027")$w, 1)   # the wild election clips at 1
})
