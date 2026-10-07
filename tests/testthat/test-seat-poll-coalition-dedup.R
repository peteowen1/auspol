test_that("a Nat figure copied from a merged Lib/Nat cell is dropped, a real one kept", {
  s <- data.table::data.table(
    election = "fed2022", seat = rep(c("Dup", "Real"), c(4, 4)), pollster = "X", date_raw = "d",
    row_type = "poll", party = rep(c("Lib", "Nat", "ALP", "GRN"), 2),
    fp = c(41, 41, 40, 19,   30, 30, 25, 15))
  withr::local_envvar(AUSPOL_SEAT_POLL_COALITION_DEDUP = "0")
  expect_equal(nrow(.seat_poll_coalition_dedup(s)), 8L)
  withr::local_envvar(AUSPOL_SEAT_POLL_COALITION_DEDUP = "1")
  out <- capture.output(r <- .seat_poll_coalition_dedup(s))
  expect_equal(nrow(r), 7L)
  expect_false(any(r$seat == "Dup" & r$party == "Nat"))
  # "Real": Lib 30 + Nat 30 sum to 100 with both, so both stay.
  expect_equal(sum(r$seat == "Real"), 4L)
  expect_match(out, "SPCD", all = FALSE)
})
