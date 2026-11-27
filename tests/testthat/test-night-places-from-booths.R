# night_places_from_booths(): a replay's polling list from the replayed election's own ordinary booths (the 2022 set-up
# list has no Classification, so it made no placeholders and uncounted ordinary booths were never projected).

test_that("ordinary booths become voting centres keyed to the snapshot's district ids", {
  B <- data.table::data.table(district = c("Mildura", "Mildura", "Mildura", "Mildura", "Bass"),
                              booth = c("Wemen", "Beulah", "Beulah", "Mildura EVC", "Bass Hall"),
                              booth_type = c("ordinary", "ordinary", "ordinary", "early", "ordinary"))
  C <- data.table::data.table(district_id = c(15928L, 100L), district = c("Mildura District", "Other District"))
  P <- night_places_from_booths(B, C)
  expect_identical(sort(P$booth), c("Beulah", "Wemen"))               # unique, ordinary only, Bass has no contest
  expect_true(all(P$booth_class == "VotingCentre")); expect_true(all(P$district_id == "15928"))
  expect_identical(names(P), c("district_id", "district", "booth_id", "booth", "booth_class"))
  expect_error(night_places_from_booths(B[district == "Bass"], C), "NW31")
})
