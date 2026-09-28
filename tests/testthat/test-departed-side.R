test_that("add_departed_side marks the incumbent's own and the opposing major's rows", {
  withr::local_envvar(AUSPOL_XGB_DEPARTED_SIDE = "1")
  d <- data.table::data.table(pair = "x", seat = c("A", "A", "A", "B", "B"),
                              party = c("LNP", "ALP", "GRN", "LNP", "ALP"),
                              same_mp_i = c(0L, 0L, 0L, 1L, 0L),
                              is_incumbent_party_i = c(1L, 0L, 0L, 1L, 0L))
  invisible(capture.output(add_departed_side(d, c("pair", "seat"))))
  # seat A: the Liberal member is gone -> LNP own, ALP opposing, Greens neither
  # seat B: the member stands again -> nobody
  expect_identical(d$own_departed_i, c(1L, 0L, 0L, 0L, 0L))
  expect_identical(d$opp_departed_i, c(0L, 1L, 0L, 0L, 0L))
})

test_that("add_departed_side is a no-op when the switch is off", {
  withr::local_envvar(AUSPOL_XGB_DEPARTED_SIDE = "0")
  d <- data.table::data.table(pair = "x", seat = "A", party = "LNP", same_mp_i = 0L, is_incumbent_party_i = 1L)
  add_departed_side(d, c("pair", "seat"))
  expect_false("own_departed_i" %in% names(d))
})
