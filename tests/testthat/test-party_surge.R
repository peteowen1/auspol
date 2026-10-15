mk <- function() data.table::data.table(
  region = "xx",
  year = c(rep(2020L, 4), rep(2024L, 4)),
  seat = c("A", "A", "B", "B", "A", "A", "B", "B"),
  party = c("ALP", "ONP", "ALP", "ONP", "ALP", "ONP", "ALP", "ONP"),
  votes = c(90, 10, 90, 10,  60, 40, 60, 40))

test_that("a statewide swing is measured in points, both directions", {
  s <- party_swing("xx", 2020L, 2024L, mk())
  expect_equal(s[party == "ONP"]$swing, 30)
  expect_equal(s[party == "ALP"]$swing, -30)
})

test_that("a surging class is flagged and a stable one is not", {
  d <- mk()
  d[year == 2024L & party == "ONP", votes := 12]
  d[year == 2024L & party == "ALP", votes := 88]
  expect_length(surging_parties("xx", 2020L, 2024L, threshold = 5, corpus = d), 0L)
  expect_true("ONP" %in% surging_parties("xx", 2020L, 2024L, threshold = 1, corpus = d))
})

test_that("a class absent at one election reads as zero, not NA", {
  # One Nation contested 19 of 47 South Australian seats in 2022 and all 47 in
  # 2026. A party that did not stand has a share of zero, not a missing value.
  d <- mk()[!(year == 2020L & party == "ONP")]
  s <- party_swing("xx", 2020L, 2024L, d)
  expect_equal(s[party == "ONP"]$prev, 0)
  expect_gt(s[party == "ONP"]$swing, 0)
})

test_that("an unknown election is an error rather than an empty answer", {
  expect_error(party_swing("xx", 1999L, 2024L, mk()), "no rows for")
})

test_that("the region argument filters, and is not shadowed by the region column", {
  # Seventh instance of the data.table NSE trap: `region` was both the
  # argument and a column, and inside C[...] the bare symbol bound to the
  # column, so the filter was always TRUE and every region was pooled. A
  # region that does not exist must be an error, and a region that does must
  # see only its own votes.
  d <- rbind(mk(), mk()[, region := "yy"][, votes := c(50, 50, 50, 50, 50, 50, 50, 50)])
  expect_error(party_swing("zz", 2020L, 2024L, d), "no rows for zz2020")
  s <- party_swing("xx", 2020L, 2024L, d)
  expect_equal(s[party == "ONP"]$swing, 30)
  s2 <- party_swing("yy", 2020L, 2024L, d)
  expect_equal(s2[party == "ONP"]$swing, 0)
})

test_that("AUSPOL_SURGE_SOURCE: actual counts a collapse, forecast counts only forecast rises, none is empty", {
  d <- mk()   # actual: ONP 10 -> 40 (+30), ALP 90 -> 60 (-30)
  lv <- data.table::data.table(pair = "xx2024", party = c("ALP", "ONP"),
                               level_pred = c(88, 12))   # forecast: neither moves 5
  # the leaking rule flags both, the fall included
  expect_setequal(surging_parties("xx", 2020L, 2024L, corpus = d, source = "actual"),
                  c("ALP", "ONP"))
  # forecast ignores the actual result entirely
  expect_length(surging_parties("xx", 2020L, 2024L, corpus = d, source = "forecast",
                                levels = lv), 0L)
  lv2 <- data.table::data.table(pair = "xx2024", party = c("ALP", "ONP"),
                                level_pred = c(70, 25))  # ALP -20 forecast, ONP +15
  expect_identical(surging_parties("xx", 2020L, 2024L, corpus = d, source = "forecast",
                                   levels = lv2), "ONP")
  # a class with no forecast row is not surging
  expect_length(surging_parties("xx", 2020L, 2024L, corpus = d, source = "forecast",
                                levels = lv2[party == "ALP"]), 0L)
  expect_length(surging_parties("xx", 2020L, 2024L, corpus = d, source = "none"), 0L)
})

test_that("AUSPOL_SURGE_SOURCE refuses a missing target and an unknown value", {
  lv <- data.table::data.table(pair = "xx2028", party = "ONP", level_pred = 30)
  expect_error(surging_parties("xx", 2020L, 2024L, corpus = mk(), source = "forecast",
                               levels = lv), "no level_pred rows for xx2024")
  expect_error(surging_parties("xx", 2020L, 2024L, corpus = mk(), source = "polls"),
               "must be")
})

test_that("forecast mode never reads the target election's rows", {
  d <- mk()[year == 2020L]   # the live case: the target has no votes at all
  lv <- data.table::data.table(pair = "xx2024", party = c("ALP", "ONP", "NEW"),
                               level_pred = c(70, 22, 8))
  # ONP 10 -> 22 rises; ALP 90 -> 70 falls; NEW never stood before, starts at 0
  expect_setequal(surging_parties("xx", 2020L, 2024L, corpus = d, source = "forecast",
                                  levels = lv), c("ONP", "NEW"))
  # identical answer whatever the target's actual result was
  expect_setequal(surging_parties("xx", 2020L, 2024L, corpus = mk(), source = "forecast",
                                  levels = lv), c("ONP", "NEW"))
})

test_that("an election not yet held has no swing: NA votes are an error, never a collapse", {
  # the live shape: nominations in, every vote NA (vic2026, nsw2027 in the corpus)
  d <- mk(); d[year == 2024L, votes := NA_real_]
  expect_error(party_swing("xx", 2020L, 2024L, d), "4 of 4 rows for xx2024 have no votes")
  # before 2026-10-15 this returned ALP and ONP as "surging" (both fell to zero)
  expect_error(surging_parties("xx", 2020L, 2024L, corpus = d, source = "actual"), "no votes")
  # one missing vote in a held election is refused too, not read as zero
  d2 <- mk(); d2[year == 2024L & seat == "B" & party == "ONP", votes := NA_real_]
  expect_error(party_swing("xx", 2020L, 2024L, d2), "1 of 4 rows")
  # forecast mode never reads the target's votes, so it still answers
  lv <- surge_levels_live("xx2024", c(ALP = 70, ONP = 30))
  expect_equal(surging_parties("xx", 2020L, 2024L, corpus = d, source = "forecast", levels = lv), "ONP")
})

test_that("surge_levels_live() takes points and refuses proportions or unnamed shares", {
  lv <- surge_levels_live("vic2026", c(ALP = 24.6, LNP = 28.9, ONP = 21.5, GRN = 13.6, OTH = 11.4))
  expect_equal(names(lv), c("pair", "party", "level_pred"))
  expect_true(all(lv$pair == "vic2026"))
  expect_equal(lv[party == "ONP"]$level_pred, 21.5)
  expect_error(surge_levels_live("vic2026", c(ALP = 0.5, ONP = 0.5)), "not percentage points")
  expect_error(surge_levels_live("vic2026", c(50, 50)), "class names")
  expect_error(surge_levels_live("vic2026", c(ALP = 50, ALP = 50)), "class names")
  expect_error(surge_levels_live("vic2026", c(ALP = NA, ONP = 100)), "non-finite")
})
