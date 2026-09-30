test_that("two-party seat polls are Labor's share, whichever side the poll reports", {
  f <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")
  skip_if_not(file.exists(f), "no seat-poll file")
  tp <- seat_poll_tpp("nsw2023")
  # Parramatta 2023, RedBridge: Coalition 46 -> Labor 54.
  expect_equal(tp$tpp_poll[tp$seat == "Parramatta"], 54)
  expect_true(all(tp$tpp_poll > 30 & tp$tpp_poll < 70))
})

test_that("joint weights learn only from elections before the target", {
  skip_if(is.null(current_seat_predictions()), "no rebuild outputs")
  # fed2016 has two-party-only polls and nothing earlier with polls: no cells
  # can come from fed2016 itself when it is the target.
  w16 <- seat_poll_weights_joint("fed2016")
  expect_equal(w16$n, 0L)
  w19 <- seat_poll_weights_joint("fed2019")
  expect_equal(w19$k, 1L)   # fed2016 only
  expect_gte(w19$w2, 0); expect_lte(w19$w2, 1)
})
