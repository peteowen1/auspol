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

test_that("screened_slopes: a PERMITTED successor wins regardless of departure (Wentworth shape)", {
  # REVISED 2026-09-18. The original version of this test asserted the
  # opposite -- that departure overrides a permit -- which is exactly the
  # Wentworth 2022 bug (Spender was permitted, got decayed anyway) that got
  # this whole mechanism refused. Departure and a real new emergence are
  # different, independent things; the screen's permit signal wins when it
  # fires, whether or not the old leader also departed.
  seats <- c("s1", "s2", "s3")
  # s1: new candidate, permitted, prior leader RETURNS (elsewhere in the seat) -> 1.0
  # s2: new candidate, permitted, prior leader DEPARTED (Wentworth shape) -> STILL 1.0
  # s3: returning candidate -> the same slope, permit irrelevant
  returns <- data.table::data.table(seat = seats, party = "IND",
                                    same = c(FALSE, FALSE, TRUE), same_mp = FALSE,
                                    prior_leader_returns = c(TRUE, FALSE, TRUE))
  sl <- screened_slopes("IND", seats, returns, permit = c(TRUE, TRUE, TRUE), honour_departed = TRUE)
  expect_equal(sl[1], 1.0)
  expect_equal(sl[2], 1.0)
  expect_equal(sl[3], 0.907)
  # Old-shape `returns` without the column: every leader taken as returning.
  old <- returns[, list(seat, party, same, same_mp)]
  expect_equal(screened_slopes("IND", seats, old, permit = c(TRUE, TRUE, TRUE), honour_departed = TRUE)[2], 1.0)
})

test_that("screened_slopes: a departed leader with NO permitted successor decays to departed_rate (New England shape)", {
  # The case the 2026-09-06 version could never express correctly: nobody
  # new is visibly emerging (screen does not permit), AND the old leader is
  # gone. docs/reviews/departed-leader-retention-2026-09-15.md: n=305,
  # departing non-major retains 0.38 against 1.01 for one who recontests.
  seats <- c("s1", "s2")
  returns <- data.table::data.table(seat = seats, party = "IND",
                                    same = c(FALSE, FALSE), same_mp = FALSE,
                                    prior_leader_returns = c(FALSE, TRUE))
  sl <- screened_slopes("IND", seats, returns, permit = c(FALSE, FALSE), honour_departed = TRUE)
  expect_equal(sl[1], 0.38)   # departed, not permitted -> the measured rate
  expect_equal(sl[2], 0.326)  # not departed, not permitted -> the generic new rate, unchanged
  # honour_departed DEFAULTS TO FALSE: a departed leader's seat (s1), even
  # unpermitted, gets the old pre-fix behaviour if a caller doesn't opt in.
  expect_equal(screened_slopes("IND", seats, returns, permit = c(FALSE, FALSE))[1], 0.326)
})

test_that("screened_slopes: departure decay fires even when is_same is TRUE (Morwell shape)", {
  # Morwell 2022's real shape, verified directly against candidate_returns():
  # same = TRUE because Tracie Lund personally stood as IND in both 2018 and
  # 2022 on 2-3%, but prior_leader_returns = FALSE because Russell Northe --
  # who actually carried 19.6 of the class's 28.2-point base -- did not
  # recontest. Without checking prior_leader_returns independently of
  # is_same, this seat would get the "same" slope (0.907) on its WHOLE base,
  # applying incumbent-level retention to a base that is overwhelmingly a
  # departed leader's personal vote.
  seats <- "Morwell"
  returns <- data.table::data.table(seat = seats, party = "IND",
                                    same = TRUE, same_mp = FALSE,
                                    prior_leader_returns = FALSE)
  sl <- screened_slopes("IND", seats, returns, permit = FALSE, honour_departed = TRUE)
  expect_equal(sl, 0.38)
  # Without honour_departed, same = TRUE alone still drives the old (wrong
  # for this shape) behaviour -- the "same" slope, not the new one.
  expect_equal(screened_slopes("IND", seats, returns, permit = FALSE), 0.907)
})

test_that("screened_slopes flags the seats the departed decay fired in, and not permitted ones", {
  seats <- c("s1", "s2", "s3", "s4")
  returns <- data.table::data.table(seat = seats, party = "IND",
                                    same = c(FALSE, FALSE, FALSE, TRUE), same_mp = FALSE,
                                    prior_leader_returns = c(FALSE, FALSE, TRUE, TRUE))
  # s1 departed, no permit -> decays; s2 departed but permitted -> uniform, NOT flagged;
  # s3 leader returned; s4 returning
  sl <- screened_slopes("IND", seats, returns, permit = c(FALSE, TRUE, FALSE, FALSE), honour_departed = TRUE, with_flags = TRUE)
  expect_equal(unname(attr(sl, "departed")), c(TRUE, FALSE, FALSE, FALSE))
  expect_equal(sl[[1]], 0.38)
  off <- screened_slopes("IND", seats, returns, permit = c(FALSE, TRUE, FALSE, FALSE), honour_departed = FALSE, with_flags = TRUE)
  expect_false(any(attr(off, "departed")))
})

test_that("renorm_hold keeps a held cell at its value and scales only the others", {
  # New England 2013 after the slope step (scratchpad walk): row totals 58.8
  m <- rbind(NE = c(ALP = 4.9, GRN = 1.9, IND = 21.1, LNP = 26.5, ONP = 0.6, OTH_RIGHT = 3.8))
  h <- matrix(FALSE, nrow(m), ncol(m), dimnames = dimnames(m)); h[, "IND"] <- TRUE
  old <- 100 * m / rowSums(m)
  expect_equal(old[, "IND"], 100 * 21.1 / sum(m), ignore_attr = TRUE)   # the problem: ~35.9
  new <- renorm_hold(m, h)
  expect_equal(unname(new[, "IND"]), 21.1)
  expect_equal(sum(new), 100)
  # the others keep their relative proportions
  expect_equal(unname(new[, "LNP"] / new[, "ALP"]), 26.5 / 4.9)
})

test_that("renorm_hold is byte-identical to plain renormalisation where nothing is held", {
  m <- rbind(a = c(A = 30, B = 20, C = 10), b = c(A = 5, B = 40, C = 15), c = c(A = 25, B = 25, C = 25))
  plain <- 100 * m / rowSums(m)
  h <- matrix(FALSE, nrow(m), ncol(m), dimnames = dimnames(m)); h["b", "B"] <- TRUE
  out <- renorm_hold(m, h)
  expect_identical(unname(out[c("a", "c"), ]), unname(plain[c("a", "c"), ]))
  expect_equal(out["b", "B"], 40)
  expect_identical(unname(renorm_hold(m, NULL)), unname(plain))
  expect_identical(unname(renorm_hold(m, h & FALSE)), unname(plain))
})

test_that("renorm_hold falls back and names the seat when the others are zero or the hold reaches 100", {
  m <- rbind(z = c(A = 0, B = 40), w = c(A = 10, B = 120), n = c(A = 10, B = 30))
  h <- matrix(FALSE, nrow(m), ncol(m), dimnames = dimnames(m)); h[, "B"] <- TRUE
  out <- renorm_hold(m, h)
  expect_identical(unname(out["z", ]), unname((100 * m / rowSums(m))["z", ]))
  expect_identical(unname(out["w", ]), unname((100 * m / rowSums(m))["w", ]))
  expect_setequal(attr(out, "skipped"), c("z", "w"))
  expect_equal(out["n", "B"], 30)
  expect_error(renorm_hold(m, h[1:2, ]), "dim")
})

test_that("with_flags = FALSE (the default) returns exactly what it always did", {
  returns <- data.table::data.table(seat = "s1", party = "IND", same = FALSE, same_mp = FALSE,
                                    prior_leader_returns = FALSE)
  expect_null(attr(screened_slopes("IND", "s1", returns, permit = FALSE, honour_departed = TRUE), "departed"))
  expect_identical(screened_slopes("IND", "s1", returns, permit = FALSE, honour_departed = TRUE),
                   screened_slopes("IND", "s1", returns, permit = FALSE, honour_departed = TRUE, with_flags = FALSE))
})

test_that("renorm_hold refuses a non-logical held matrix rather than coercing it", {
  m <- rbind(a = c(A = 30, B = 20))
  expect_error(renorm_hold(m, m * 0 + 1), "logical")
})
