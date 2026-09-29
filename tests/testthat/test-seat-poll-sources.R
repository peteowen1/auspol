test_that("public-only seat polls drop sponsored and non-allowlisted direct polls, and 'all' is unchanged", {
  f <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")
  skip_if_not(file.exists(f), "no seat-poll file")
  all_ <- withr::with_envvar(c(AUSPOL_SEAT_POLL_SOURCES = "all"), seat_poll_shares("fed2025", by_type = TRUE))
  dflt <- withr::with_envvar(c(AUSPOL_SEAT_POLL_SOURCES = NA), seat_poll_shares("fed2025", by_type = TRUE))
  expect_identical(all_, dflt)
  pub <- withr::with_envvar(c(AUSPOL_SEAT_POLL_SOURCES = "public"), seat_poll_shares("fed2025", by_type = TRUE))
  expect_lt(sum(pub$n_polls), sum(all_$n_polls))
  # McMahon's only direct poll is Compass (not allowlisted); Bullwinkel's are
  # sponsored (JWS for Australian Energy Producers, Unnamed for the Nationals)
  # or YouGov (kept).
  expect_false(any(pub$seat == "McMahon" & pub$type == "direct"))
  expect_true(any(all_$seat == "McMahon" & all_$type == "direct"))
  expect_true(any(pub$seat == "McMahon" & pub$type == "mrp"))
  expect_error(withr::with_envvar(c(AUSPOL_SEAT_POLL_SOURCES = "pub"), seat_poll_shares("fed2025")))
})
