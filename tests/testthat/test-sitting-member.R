test_that("sitting_member_group labels the three groups", {
  d <- data.table::data.table(pair = "x", seat = c("A", "A", "A", "B", "B"),
                              party = c("LNP", "ALP", "GRN", "LNP", "ALP"),
                              is_incumbent_party_i = c(1L, 0L, 0L, 1L, 0L),
                              same_mp_i = c(0L, 0L, 0L, 1L, 0L))
  expect_identical(sitting_member_group(d, c("pair", "seat")),
                   c("inc_gone", "ch_gone", NA, "inc_stays", NA))
})

test_that("fit_sitting_member_shift uses only earlier elections and shrinks noise", {
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "1")
  mk <- function(p, r) data.table::data.table(pair = p, group = "inc_stays", resid = r)
  tab <- rbind(mk("fed2013", c(2, 2.2)), mk("fed2016", c(1.8, 2)), mk("fed2019", c(2.1, 1.9)),
               mk("fed2025", c(40, 40)))                      # a later election with a wild value
  s <- fit_sitting_member_shift(tab, "fed2022")
  expect_equal(s[group == "inc_stays", k], 3L)              # fed2025 is not used
  expect_gt(s[group == "inc_stays", shift], 1.8)             # a consistent signal survives shrinkage
  expect_lt(s[group == "inc_stays", shift], 2.2)
  expect_equal(s[group == "inc_gone", shift], 0)             # no data -> no shift
  noisy <- rbind(mk("fed2013", 5), mk("fed2016", -5), mk("fed2019", 0.5))
  expect_lt(abs(fit_sitting_member_shift(noisy, "fed2022")[group == "inc_stays", shift]), 0.2)
})
