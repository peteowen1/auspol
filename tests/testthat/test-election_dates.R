test_that("every election in the corpus pair list has a polling day", {
  pairs <- all_election_pairs()
  labels <- unique(unlist(lapply(pairs, function(p) c(p$election, p$prev))))
  d <- election_dates(labels)
  expect_true(all(!is.na(d)))
  expect_equal(names(d), labels)
})

test_that("polling days are strictly increasing within each region", {
  d <- election_dates()
  region <- sub("[0-9]+$", "", names(d))
  for (r in unique(region)) {
    dr <- d[region == r]
    dr <- dr[order(as.integer(sub("^[a-z]+", "", names(dr))))]
    expect_true(all(diff(dr) > 0), info = r)
  }
})

test_that("an unknown label is an error, not NA -- a missing date would let a model train on the future", {
  expect_error(election_dates("fed1901"), "no polling day")
  expect_error(election_dates(c("fed2022", "nope")), "nope")
})

test_that("a known date is what the harnesses have always used", {
  expect_equal(unname(election_dates("fed2022")), as.Date("2022-05-21"))
  expect_equal(unname(election_dates("sa2026")), as.Date("2026-03-21"))
  expect_equal(unname(election_dates("wa2001")), as.Date("2001-02-10"))
})
