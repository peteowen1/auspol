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

test_that("fit_conditional_slopes keeps the shipped constant for a too-thin cell", {
  # A cell with a handful of seats must NOT be fitted -- fitting a slope on a
  # few observations is how this repo has produced confident wrong numbers.
  d <- data.table::data.table(
    election = c("e1","e2"), seat = c("A","A"), party = "IND",
    surname = c("X","X"), given = c("a","a"), pcv = c(20, 15),
    votes = c(2000, 1500), tot = 10000, name = NA_character_)
  r <- fit_conditional_slopes("zzz", corpus = d,
                              pairs = list(list(election = "e2", prev = "e1")),
                              min_n = 40L)
  expect_equal(unname(r$same[["IND"]]), 0.907)   # untouched shipped value
  expect_equal(unname(r$new[["IND"]]),  0.326)
})

test_that("fit_conditional_slopes excludes the target election", {
  mk <- function(el_prev, el_now, seats) data.table::rbindlist(lapply(seats, function(s)
    data.table::data.table(
      election = c(el_prev, el_now), seat = s, party = "IND",
      surname = c("X","X"), given = c("a","a"),
      pcv = c(20, 10), votes = c(2000, 1000), tot = 10000, name = NA_character_)))
  d <- rbind(mk("e1","e2", paste0("S", 1:60)), mk("e3","e4", paste0("T", 1:60)))
  prs <- list(list(election = "e2", prev = "e1"), list(election = "e4", prev = "e3"))
  both <- fit_conditional_slopes("zzz", corpus = d, pairs = prs, min_n = 5L)
  held <- fit_conditional_slopes("e4",  corpus = d, pairs = prs, min_n = 5L)
  n_both <- sum(both$n[party == "IND"]$n); n_held <- sum(held$n[party == "IND"]$n)
  expect_true(n_held < n_both)
})

test_that("fit_dispersion_slopes keeps the shipped constant when data is too thin", {
  d <- data.table::data.table(
    election = c("e1","e2"), seat = c("A","A"), party = "IND",
    surname = c("X","X"), given = c("a","a"), pcv = c(20, 15),
    votes = c(2000, 1500), tot = 10000, name = NA_character_)
  r <- fit_dispersion_slopes("zzz", corpus = d,
                              pairs = list(list(election = "e2", prev = "e1")),
                              min_pairs = 6L)
  expect_equal(unname(r$new[["IND"]]), 0.326)   # untouched shipped value
  expect_equal(unname(r$same[["IND"]]), 0.907)  # same tier never moves
})

test_that("fit_dispersion_slopes returns the shipped constants for every class with an empty corpus", {
  r <- fit_dispersion_slopes("zzz", corpus = data.table::data.table(
    election = character(0), seat = character(0), party = character(0),
    surname = character(0), given = character(0), pcv = numeric(0),
    votes = numeric(0), tot = numeric(0), name = character(0)),
    pairs = list())
  expect_equal(r$new, c(IND = 0.326, OTH_RIGHT = 0.325, GRN = 0.880, ONP = 0.545))
})

test_that("fit_dispersion_slopes excludes the target election from its own fit", {
  # 7 synthetic pairs of NEW IND candidates (different surname each election,
  # so every seat is "new"-tier), with a deliberate dev_after = 2*dev_before
  # relationship built in via seats at different levels away from the mean.
  # min_pairs=6 needs >=6 OTHER pairs, so this needs a target pair PLUS 6.
  mk_pair_wide <- function(el_prev, el_now, n_seats, base_shift) {
    set.seed(which(LETTERS == substr(el_now, nchar(el_now), nchar(el_now))) + 1)
    dev_prev <- seq(-5, 5, length.out = n_seats)
    dev_now  <- 2 * dev_prev + stats::rnorm(n_seats, sd = 0.2)
    data.table::rbindlist(lapply(seq_len(n_seats), function(i) rbind(
      data.table::data.table(election = el_prev, seat = paste0("S", i), party = "IND",
        surname = paste0("OLD", i), given = "a", pcv = 10 + dev_prev[i],
        votes = (10 + dev_prev[i]) * 100, tot = 10000, name = NA_character_),
      data.table::data.table(election = el_now, seat = paste0("S", i), party = "IND",
        surname = paste0("NEW", i), given = "b",
        pcv = pmax(0.1, 10 + base_shift + dev_now[i]),
        votes = pmax(0.1, 10 + base_shift + dev_now[i]) * 100, tot = 10000,
        name = NA_character_))))
  }
  letters7 <- LETTERS[1:8]
  d <- data.table::rbindlist(lapply(1:7, function(i)
    mk_pair_wide(paste0("p", letters7[i]), paste0("p", letters7[i+1]), 20, i)))
  prs <- lapply(1:7, function(i) list(election = paste0("p", letters7[i+1]), prev = paste0("p", letters7[i])))
  target <- paste0("p", letters7[8])
  full <- fit_dispersion_slopes("zzz",   corpus = d, pairs = prs, min_pairs = 5L, classes = "IND")
  held <- fit_dispersion_slopes(target, corpus = d, pairs = prs, min_pairs = 5L, classes = "IND")
  # the built-in relationship (dev_after ~ 2*dev_before) should pull the
  # fitted slope well above the shipped 0.326 flat constant
  expect_gt(unname(held$new[["IND"]]), 0.6)
  expect_true(nrow(held$n[held$n$class == "IND", ]) > 0)
})

test_that("fit_dispersion_slopes defaults to GRN/ONP only -- IND and OTH_RIGHT are not parties", {
  # IND is a different person every election by definition, and OTH_RIGHT is
  # a residual bucket classify_party() files a dozen-plus unrelated
  # minor-right parties into (R/parties.R) -- neither has the brand
  # continuity the corr x sd-ratio mechanism assumes. Refused on real data
  # 2026-09-09 when applied to IND (fed2013 got worse, not better); the fix
  # is scope, not a validation gap.
  #
  # Build IND *and* GRN with the identical strong synthetic relationship
  # (dev_after ~= 2*dev_before), enough data for either to fit if it were in
  # scope. Only GRN should move.
  mk_pair_wide2 <- function(el_prev, el_now, cls, n_seats, base_shift, seed) {
    set.seed(seed)
    dev_prev <- seq(-5, 5, length.out = n_seats)
    dev_now  <- 2 * dev_prev + stats::rnorm(n_seats, sd = 0.2)
    data.table::rbindlist(lapply(seq_len(n_seats), function(i) rbind(
      data.table::data.table(election = el_prev, seat = paste0("S", i), party = cls,
        surname = paste0("OLD", i), given = "a", pcv = 10 + dev_prev[i],
        votes = (10 + dev_prev[i]) * 100, tot = 10000, name = NA_character_),
      data.table::data.table(election = el_now, seat = paste0("S", i), party = cls,
        surname = paste0("NEW", i), given = "b",
        pcv = pmax(0.1, 10 + base_shift + dev_now[i]),
        votes = pmax(0.1, 10 + base_shift + dev_now[i]) * 100, tot = 10000,
        name = NA_character_))))
  }
  letters8 <- LETTERS[1:8]
  d <- data.table::rbindlist(lapply(1:7, function(i) rbind(
    mk_pair_wide2(paste0("p", letters8[i]), paste0("p", letters8[i+1]), "IND", 20, i, i),
    mk_pair_wide2(paste0("p", letters8[i]), paste0("p", letters8[i+1]), "GRN", 20, i, i + 100))))
  prs <- lapply(1:7, function(i) list(election = paste0("p", letters8[i+1]), prev = paste0("p", letters8[i])))
  target <- paste0("p", letters8[8])
  r <- fit_dispersion_slopes(target, corpus = d, pairs = prs, min_pairs = 5L)
  expect_equal(unname(r$new[["IND"]]), 0.326)   # NOT fitted by default -- shipped, untouched
  # IS fitted -- moved measurably off the shipped 0.880, in either direction
  expect_true(abs(unname(r$new[["GRN"]]) - 0.880) > 0.1)
})
