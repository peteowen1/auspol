mk_pair <- function() data.table::data.table(
  election = c(rep("e1", 4), rep("e2", 3)),
  seat  = "A",
  party = c("IND", "IND", "IND", "ALP",  "IND", "IND", "ALP"),
  surname = c("STAYER", "LEAVER", "ALSOGONE", "MAJOR",
              "STAYER", "NEWBIE", "MAJOR"),
  given = c("Sam", "Pat", "Jo", "Kim",  "Sam", "Alex", "Kim"),
  pcv   = c(10, 6, 4, 50,   9, 3, 55),
  votes = c(10, 6, 4, 50,   9, 3, 55) * 100,
  tot   = 7000,
  name = NA_character_)

test_that("returning_vote_fraction splits a class by who is standing again", {
  r <- returning_vote_fraction("e1", "e2", mk_pair())
  ind <- r[seat == "A" & party == "IND"]
  # Stayer (10) came back; Leaver (6) and Alsogone (4) did not -> 10/20
  expect_equal(ind$ret_frac, 0.5)
  expect_equal(ind$n_prior, 3L)
  expect_equal(ind$n_returning, 1L)
})

test_that("returning_vote_fraction is NA, not 0, for a class with no prior vote", {
  # A class that did not contest the prior election has no composition to
  # report. NA keeps a caller from reading "nobody returned" out of "nobody
  # stood" -- the absence-of-evidence trap CLAUDE.md records.
  d <- rbind(mk_pair(), data.table::data.table(
    election = "e2", seat = "A", party = "GRN", surname = "FRESH",
    given = "Lee", pcv = 5, votes = 500, tot = 7000, name = NA_character_))
  r <- returning_vote_fraction("e1", "e2", d)
  expect_true(nrow(r[seat == "A" & party == "GRN"]) == 0 ||
                is.na(r[seat == "A" & party == "GRN"]$ret_frac))
})

test_that("split_dev_slope reduces EXACTLY to dev_slope at both extremes", {
  # This is the property that makes the arm safe: a class whose vote is all
  # returning, or all departed, must be untouched relative to the shipped
  # model. Only genuinely mixed classes move.
  x <- c(30, 12, 5, 0); lp <- 8; ln <- 11
  expect_equal(split_dev_slope(x, rep(1, 4), lp, ln, 0.9, 0.5),
               dev_slope(x, lp, ln, 0.9))
  expect_equal(split_dev_slope(x, rep(0, 4), lp, ln, 0.9, 0.5),
               dev_slope(x, lp, ln, 0.5))
})

test_that("split_dev_slope blends, floors at zero, and handles NA fractions", {
  x <- c(30, 2)
  v <- split_dev_slope(x, c(0.5, 0.5), 8, 11, 0.9, 0.5)
  # halfway between the two single-slope answers, by construction
  expect_equal(v, (dev_slope(x, 8, 11, 0.9) + dev_slope(x, 8, 11, 0.5)) / 2)
  expect_true(all(split_dev_slope(c(0, 0), c(0, 0), 40, 0, 1, 1) >= 0))
  # NA fraction falls back rather than producing NA shares
  expect_false(any(is.na(split_dev_slope(x, c(NA_real_, 0.5), 8, 11, 0.9, 0.5))))
})

test_that("split_dev_slope rejects a mismatched ret_frac length", {
  expect_error(split_dev_slope(c(1, 2, 3), c(1, 1), 8, 11, 0.9, 0.5),
               "ret_frac must match x")
})

test_that("fit_split_slopes excludes the target election from its own fit", {
  # Two pairs with deliberately opposite structure; fitting with e2 as target
  # must not see e2's rows.
  d <- rbind(
    data.table::data.table(
      election = c("e1","e1","e2","e2"), seat = "A", party = "IND",
      surname = c("X","Y","X","Z"), given = c("a","b","a","c"),
      pcv = c(20, 20, 30, 5), votes = c(20,20,30,5)*100, tot = 10000,
      name = NA_character_),
    data.table::data.table(
      election = c("e3","e3","e4","e4"), seat = "B", party = "IND",
      surname = c("P","Q","P","R"), given = c("d","e","d","f"),
      pcv = c(20, 20, 10, 5), votes = c(20,20,10,5)*100, tot = 10000,
      name = NA_character_))
  prs <- list(list(election = "e2", prev = "e1"), list(election = "e4", prev = "e3"))
  full <- fit_split_slopes("zzz", corpus = d, pairs = prs, min_n = 1L)
  held <- fit_split_slopes("e4",  corpus = d, pairs = prs, min_n = 1L)
  expect_true(held$n < full$n)
})

test_that("fit_split_slopes returns NULL slopes below min_n rather than a fitted number", {
  d <- data.table::data.table(
    election = c("e1","e2"), seat = "A", party = "IND",
    surname = c("X","X"), given = c("a","a"), pcv = c(20, 15),
    votes = c(2000, 1500), tot = 10000, name = NA_character_)
  r <- fit_split_slopes("zzz", corpus = d,
                        pairs = list(list(election = "e2", prev = "e1")),
                        min_n = 500L)
  expect_null(r$s_ret)
  expect_null(r$s_dep)
})

test_that("split_slope_context is NULL unless explicitly enabled", {
  expect_null(split_slope_context("e1", "e2", corpus = mk_pair(), enabled = FALSE))
})
