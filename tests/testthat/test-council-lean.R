# Upper-house booth lean for a party new to a seat (night_council_lean(), project_seat_from_booths(lean =)).
dt <- data.table::data.table

test_that("night_council_lean: shares per voting centre over all parties, named parties kept, units named as the lower house", {
  cf <- dt(district = "Morwell District", vc_name = c("Moe", "Moe", "Moe", "Moe", "Traralgon", "Traralgon", "x"),
           vote_type = c("ordinary", "ordinary", "ordinary", "ordinary", "ordinary", "ordinary", "postal"),
           block_kind = c(rep("voting_centre", 6), "voting_centre"),
           row_kind = c("group", "group", "group", "ungrouped", "group", "group", "group"),
           group_name = c("Pauline Hanson's One Nation", "Australian Labor Party", "Liberal Democrats", "", "Pauline Hanson's One Nation", "Australian Labor Party", "Australian Labor Party"),
           total = c(40, 30, 20, 10, 10, 90, 50))
  ln <- night_council_lean(cf)
  expect_setequal(unique(ln$cls), c("ONP", "ALP"))                  # pooled classes (OTH_RIGHT, IND) left out by default
  expect_equal(ln[unit == "Moe" & cls == "ONP"]$share, 0.40)        # over all 100 votes at Moe, the dropped classes included
  expect_equal(ln[unit == "Traralgon" & cls == "ONP"]$share, 0.10)
  expect_identical(unique(ln$district), "Morwell")                  # " District" stripped
  expect_true("postal" %in% ln$unit)                                # non-ordinary votes keyed by vote type
  expect_error(night_council_lean(cf[, !"total"]), "lacks")
})

test_that("a partly counted early unit: remainder projected from the early block plus its swing; NA changes nothing", {
  ref  <- dt(unit = c("A", "A", "early", "early"), booth_type = c("ordinary", "ordinary", "early", "early"),
             cls = c("ALP", "LNP", "ALP", "LNP"), v = c(500, 500, 600, 400))
  # tonight: booth A in full, and half the early vote in (500 of an expected 1,000), early ALP 50% vs 60% last time
  live <- dt(unit = c("A", "A", "early", "early"), booth_type = c("ordinary", "ordinary", "early", "early"),
             cls = c("ALP", "LNP", "ALP", "LNP"), v = c(450, 550, 250, 250))
  p0 <- project_seat_from_booths(live, ref, c("A", "early"))
  expect_identical(project_seat_from_booths(live, ref, c("A", "early"), early_frac = NA), p0)
  expect_identical(project_seat_from_booths(live, ref, c("A", "early"), early_frac = 1), p0)
  p <- project_seat_from_booths(live, ref, c("A", "early"), early_frac = 0.5)
  # remainder 500 votes at the 2022 early mix (60/40) plus the early swing (-10 ALP, +10 LNP) = 50/50
  expect_equal(sum(p$projected), sum(p0$projected) + 500)
  expect_equal(p[cls == "ALP"]$projected, 450 + 250 + 250)
  expect_equal(night_early_frac(dt(district = "S", booth_type = c("early", "ordinary"), votes = c(300, 700)),
                                c(S = 2000), dt(district = "S", booth_type = c("early", "ordinary", "postal"), votes = c(600, 300, 100))),
               c(S = 300 / (2000 * 0.6)))
})

test_that("a party new to the seat is projected from booth lean plus its counted swing; NULL changes nothing", {
  # last time: ALP and LNP only, two booths of 1,000. Tonight One Nation stands; Moe (an ONP-leaning booth) is counted.
  ref  <- dt(unit = c("Moe", "Moe", "Traralgon", "Traralgon"), booth_type = "ordinary", cls = c("ALP", "LNP", "ALP", "LNP"), v = c(600, 400, 500, 500))
  live <- dt(unit = c("Moe", "Moe", "Moe", "Traralgon", "Traralgon", "Traralgon"), booth_type = "ordinary",
             cls = c("ALP", "LNP", "ONP", "ALP", "LNP", "ONP"), v = c(300, 260, 440, 450, 450, 100))
  lean <- dt(unit = c("Moe", "Traralgon"), cls = "ONP", share = c(0.40, 0.10))
  p0 <- project_seat_from_booths(live, ref, "Moe")
  p1 <- project_seat_from_booths(live, ref, "Moe", lean = lean)
  expect_identical(project_seat_from_booths(live, ref, "Moe", lean = NULL), p0)
  onp <- function(p) p[cls == "ONP"]$projected
  # today: Traralgon takes Moe's counted 44% (440 + 0.44 x 1000); with the lean: its own 10% plus Moe's +4 swing
  expect_equal(onp(p0), 440 + 0.44 * 1000)
  expect_equal(onp(p1), 440 + (0.10 + 0.04) * 1000)
  expect_identical(p1[cls != "ONP"], p0[cls != "ONP"])              # every other party untouched
  # a class WITH last-time votes ignores the lean entirely
  expect_identical(project_seat_from_booths(live, ref, "Moe", lean = dt(unit = "Traralgon", cls = "ALP", share = 0.9)), p0)
})
