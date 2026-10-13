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

test_that("nsw2015 is a pair on nsw2011 with a redistribution notional entry", {
  # nsw2015 added 2026-10-13: a pair whose previous election has a date and whose prior is the booth
  # notional (without the STATE_REDISTRIBUTIONS entry the harness would swing the old 2011 boundaries).
  p <- Filter(function(p) p$election == "nsw2015", all_election_pairs())
  expect_length(p, 1L)
  expect_equal(p[[1]]$prev, "nsw2011")
  expect_equal(unname(election_dates("nsw2011")), as.Date("2011-03-26"))
  expect_true("nsw2015" %in% names(STATE_REDISTRIBUTIONS))
})
