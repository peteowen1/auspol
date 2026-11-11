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

test_that("partial early in expected mode sums to the expected total, and an all-counted seat reports what is outstanding", {
  ref  <- dt(unit = c("A", "A", "B", "B", "early", "early"), booth_type = c("ordinary", "ordinary", "ordinary", "ordinary", "early", "early"),
             cls = c("ALP", "LNP", "ALP", "LNP", "ALP", "LNP"), v = c(500, 500, 500, 500, 600, 400))
  live <- dt(unit = c("A", "A", "B", "B", "early", "early"), booth_type = c("ordinary", "ordinary", "ordinary", "ordinary", "early", "early"),
             cls = c("ALP", "LNP", "ALP", "LNP", "ALP", "LNP"), v = c(450, 550, 0, 0, 250, 250))
  p <- project_seat_from_booths(live, ref, c("A", "early"), total = "expected", expected_total = 3000, early_frac = 0.5)
  expect_equal(sum(p$projected), 3000)                               # review 2026-10-30: was 3,500 (remainder counted twice)
  expect_equal(p$counted_share[1], 1500 / 3000)
  q <- project_seat_from_booths(live[unit != "B"], ref, c("A", "early"), early_frac = 0.5)   # every unit reported, early half in
  expect_equal(q$counted_share[1], 1500 / 2000)                      # not 1: half the early vote is outstanding
})

test_that("night_booth_update() carries the lean onto this year's units (the merge with the booth match)", {
  ref  <- dt(district = "S", booth = c("Moe", "Moe", "Trar", "Trar"), booth_type = "ordinary", party = c("Australian Labor Party", "Liberal"), votes = c(600, 400, 500, 500))
  live <- dt(district = "S", booth = rep(c("Moe", "Trar"), each = 3), booth_type = "ordinary",
             party = rep(c("Australian Labor Party", "Liberal", "Pauline Hanson's One Nation"), 2), votes = c(300, 260, 440, 450, 450, 100))
  sh <- matrix(c(40, 40, 20), 1, dimnames = list("S", c("ALP", "LNP", "ONP"))); sd <- sh * 0 + 50
  rep_units <- dt(district = "S", unit = "Moe")
  u0 <- night_booth_update(sh, sd, 1, live, ref, reported = rep_units)
  lean <- dt(district = "S", unit = c("Moe", "Trar"), cls = "ONP", share = c(0.40, 0.10))
  u1 <- night_booth_update(sh, sd, 1, live, ref, reported = rep_units, lean = lean)
  expect_lt(u1$shares["S", "ONP"], u0$shares["S", "ONP"])             # Trar projected at 10% + swing, not Moe's 44%
  wrong <- data.table::copy(lean)[, district := "Elsewhere"]
  expect_identical(night_booth_update(sh, sd, 1, live, ref, reported = rep_units, lean = wrong)$shares, u0$shares)
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

test_that("cand_ref: a returning candidate who changed party takes their own previous votes as the reference", {
  # Mirani 2024 in miniature: Smith stood as One Nation last time (40% in the booth, 10% on postals) and now stands
  # for Katter's party (OTH_RIGHT, which had no votes here last time). The booth is counted, the postals are not.
  ref  <- dt(district = "S", booth = c("A", "A", "P", "P"), booth_type = c("ordinary", "ordinary", "postal", "postal"),
             candidate = c("SMITH, Jo", "JONES, Al", "SMITH, Jo", "JONES, Al"),
             party = c("Pauline Hanson's One Nation", "Australian Labor Party"), votes = c(400, 600, 100, 900))
  live <- dt(district = "S", booth = c("A", "A", "P", "P"), booth_type = c("ordinary", "ordinary", "postal", "postal"),
             candidate = c("SMITH, Jo", "JONES, Al", "SMITH, Jo", "JONES, Al"),
             party = c("Katter's Australian Party", "Australian Labor Party"), votes = c(500, 500, 0, 0))
  sh <- matrix(c(50, 50), 1, dimnames = list("S", c("ALP", "OTH_RIGHT"))); sd <- sh * 0 + 50
  rep_units <- dt(district = "S", unit = "A")
  u0 <- night_booth_update(sh, sd, 1, live, ref, reported = rep_units)
  expect_identical(night_booth_update(sh, sd, 1, live, ref, reported = rep_units, cand_ref = FALSE)$shares, u0$shares)
  u1 <- night_booth_update(sh, sd, 1, live, ref, reported = rep_units, cand_ref = TRUE)
  expect_equal(u1$n_cand_ref, 1L)
  expect_true(is.na(u0$n_cand_ref))
  # off: no OTH_RIGHT reference, so the postals carry the booth's 50%; on: Smith's own 10% postal share + 10 swing
  expect_lt(u1$shares["S", "OTH_RIGHT"], u0$shares["S", "OTH_RIGHT"])
  # a candidate in the same class both times is not relabelled
  live2 <- data.table::copy(live)[candidate == "SMITH, Jo", party := "Pauline Hanson's One Nation"]
  sh2 <- matrix(c(50, 50), 1, dimnames = list("S", c("ALP", "ONP")))
  expect_identical(night_booth_update(sh2, sd, 1, live2, ref, reported = rep_units, cand_ref = TRUE)$shares,
                   night_booth_update(sh2, sd, 1, live2, ref, reported = rep_units)$shares)
  expect_error(night_booth_update(sh, sd, 1, live[, candidate := NULL], ref, reported = rep_units, cand_ref = TRUE), "NX15!")
  expect_error(night_booth_update(sh, sd, 1, live, ref, reported = rep_units, cand_ref = NA), "NX15!")
})

test_that("cand_ref = 'copy' keeps the old class's history (Monash 2025 in miniature) and the unit totals", {
  # Broad was the Liberal last time (60% everywhere); now he is an independent and a new Liberal, Aldred, stands.
  ref  <- dt(district = "S", booth = c("A", "A", "P", "P"), booth_type = c("ordinary", "ordinary", "postal", "postal"),
             candidate = c("BROAD, Russ", "JONES, Al", "BROAD, Russ", "JONES, Al"),
             party = c("Liberal", "Australian Labor Party"), votes = c(600, 400, 700, 300))
  live <- dt(district = "S", booth = rep(c("A", "P"), each = 3), booth_type = rep(c("ordinary", "postal"), each = 3),
             candidate = rep(c("BROAD, Russ", "JONES, Al", "ALDRED, Mary"), 2),
             party = rep(c("", "Australian Labor Party", "Liberal"), 2), votes = c(300, 350, 350, 0, 0, 0))
  sh <- matrix(c(33, 33, 34), 1, dimnames = list("S", c("IND", "ALP", "LNP"))); sd <- sh * 0 + 50
  rep_units <- dt(district = "S", unit = "A")
  off  <- night_booth_update(sh, sd, 1, live, ref, reported = rep_units)
  mv   <- night_booth_update(sh, sd, 1, live, ref, reported = rep_units, cand_ref = "move")
  cpy  <- night_booth_update(sh, sd, 1, live, ref, reported = rep_units, cand_ref = "copy")
  expect_identical(night_booth_update(sh, sd, 1, live, ref, reported = rep_units, cand_ref = TRUE)$shares, mv$shares)
  expect_equal(cpy$n_cand_ref, 1L)
  # move strips the Liberal class of its history; copy keeps it, so the new Liberal is projected higher than under move
  expect_gt(cpy$shares["S", "LNP"], mv$shares["S", "LNP"])
  expect_false(identical(cpy$shares, off$shares))
  expect_error(night_booth_update(sh, sd, 1, live, ref, reported = rep_units, cand_ref = "both"), "NX15!")
})
