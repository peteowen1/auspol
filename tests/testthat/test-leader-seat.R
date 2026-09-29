test_that("leaders carry the right seat, class and role", {
  f <- file.path(pkg_root(), "external", "reference", "leaders", "leaders.csv")
  skip_if_not(file.exists(f), "no leaders file")
  ls <- leader_seats()
  k <- ls[ls$pair == "nsw2023"]
  expect_equal(k$role[k$seat == "Kogarah"], "opp")
  expect_equal(k$party[k$seat == "Kogarah"], "ALP")
  expect_equal(k$role[k$seat == "Epping"], "gov")
  # Liberals for Forests (wa2001, Janet Woollard) is not the Liberal Party.
  expect_false(any(ls$pair == "wa2001" & ls$seat == "Alfred Cove" & ls$party == "LNP"))
  expect_equal(anyDuplicated(ls[, c("pair", "seat", "party")]), 0L)
})

test_that("the bonus lands on the leader's class and keeps the seat total", {
  skip_if_not(file.exists(out_path("forecasts.csv")), "no forecasts table")
  sh <- matrix(c(48, 38, 8, 6, 30, 50, 12, 8), nrow = 2, byrow = TRUE,
               dimnames = list(c("Kogarah", "Epping"), c("ALP", "LNP", "GRN", "OTH")))
  off <- withr::with_envvar(c(AUSPOL_LEADER_SEAT = "0"), leader_seat_apply(sh, "nsw2023"))
  expect_identical(off, sh)
  on <- withr::with_envvar(c(AUSPOL_LEADER_SEAT = "1"), leader_seat_apply(sh, "nsw2023"))
  expect_gt(on["Kogarah", "ALP"], sh["Kogarah", "ALP"])
  expect_gt(on["Epping", "LNP"], sh["Epping", "LNP"])
  expect_equal(unname(rowSums(on)), unname(rowSums(sh)))
  # The bonus must come only from earlier elections: nsw2023's own leaders
  # cannot be in its training set.
  b <- leader_seat_bonus("nsw2023")
  expect_lt(attr(b, "pooled")$n, nrow(leader_seats()[elections_before(leader_seats()$pair, "nsw2024")]))
})
