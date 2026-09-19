# Election-night booth projection: matching, projection, prior combination.
# Synthetic seats, no data files.

mk_seat <- function(shares_by_unit) {
  # shares_by_unit: list(unit = c(booth_type, ALP, LNP, GRN)) with votes
  data.table::rbindlist(lapply(names(shares_by_unit), function(u) {
    x <- shares_by_unit[[u]]
    data.table::data.table(unit = u, booth_type = x[[1]], cls = c("ALP", "LNP", "GRN"), v = as.numeric(x[-1]))
  }))
}

test_that("projection with the live result as its own reference is exact at any counted set", {
  live <- mk_seat(list(A = list("ordinary", 400, 350, 100), B = list("ordinary", 200, 300, 50),
                       early = list("early", 900, 800, 200), postal = list("postal", 100, 150, 20)))
  final <- live[, .(final = sum(v)), by = cls]
  for (counted in list("A", c("A", "B"), c("A", "early"), c("A", "B", "early", "postal"))) {
    p <- project_seat_from_booths(live, live, counted)
    m <- merge(p, final, by = "cls")
    expect_equal(m$projected, m$final, tolerance = 1e-9, info = paste(counted, collapse = ","))
  }
})

test_that("a uniform swing on counted booths is carried to the uncounted ones", {
  ref  <- mk_seat(list(A = list("ordinary", 400, 400, 200), B = list("ordinary", 400, 400, 200), C = list("ordinary", 400, 400, 200)))
  # live: ALP +10 points everywhere, LNP -10, same turnout
  live <- mk_seat(list(A = list("ordinary", 500, 300, 200), B = list("ordinary", 500, 300, 200), C = list("ordinary", 500, 300, 200)))
  p <- project_seat_from_booths(live, ref, "A")
  expect_equal(p[cls == "ALP"]$projected, 1500, tolerance = 1e-9)
  expect_equal(p[cls == "LNP"]$projected, 900, tolerance = 1e-9)
  expect_equal(p$counted_share[1], 1 / 3)
})

test_that("a class absent from the reference takes the seat's counted share; no counted reference returns NULL", {
  ref  <- mk_seat(list(A = list("ordinary", 500, 500, 0), B = list("ordinary", 500, 500, 0)))
  ref <- ref[cls != "GRN"]
  live <- mk_seat(list(A = list("ordinary", 400, 400, 200), B = list("ordinary", 400, 400, 200)))
  p <- project_seat_from_booths(live, ref, "A")
  expect_equal(p[cls == "GRN"]$projected, 200 + 0.2 * 1000, tolerance = 1e-9)   # counted 200 + share 0.2 of B's 1000
  expect_null(project_seat_from_booths(live, ref[0], "A"))
})

test_that("match_booth_units matches in-district first and by unique statewide name second", {
  live <- data.table::data.table(district = c("X", "X", "Y"), unit = c("Town Hall", "Riverside", "Hillside"), booth_type = "ordinary")
  ref  <- data.table::data.table(district = c("X", "Z", "Z", "W"), unit = c("Town Hall", "Riverside", "Hillside", "Hillside"), booth_type = "ordinary")
  m <- match_booth_units(live, ref)
  expect_equal(m[unit == "Town Hall"]$ref_district, "X")
  expect_equal(m[unit == "Riverside"]$ref_district, "Z")      # unique statewide, across the redistribution
  expect_false("Hillside" %in% m$unit)                         # two reference districts have one: ambiguous, unmatched
})

test_that("combine_prior_projection weights by precision and booth_projection_sd falls with the count", {
  cp <- combine_prior_projection(prior = 30, proj = 40, sd_prior = 4, sd_proj = 4)
  expect_equal(cp$mean, 35)
  cp2 <- combine_prior_projection(30, 40, sd_prior = 4, sd_proj = 1)
  expect_gt(cp2$mean, 39)
  expect_lt(cp2$sd, 1)
  s <- booth_projection_sd(c(0, 0.086, 0.5, 1))
  expect_true(all(diff(s) <= 0))
  expect_equal(s[2], 2.63)
})
