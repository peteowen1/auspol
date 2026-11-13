# Arm PPC (R/paid_poll.R; plans/prereg-paid-poll-correction-2026-11-13.md). Synthetic polls only: no anchor data.

test_that("sponsor sides come from sponsor_side.csv, first match wins, unmatched is UNKNOWN", {
  s <- paid_poll_side(c("Victorian Greens", "The Australia Institute", "Liberal Party", "Minerals Council of Australia",
                        "Climate 200", "Somebody New", ""))
  expect_identical(s, c("GRN", "ALP+GRN", "LNP", "LNP", "IND", "UNKNOWN", NA))
})

ppc_dv <- function(lean_lnp, sd_paid, n_paid = 30, seed = 1) {
  set.seed(seed)
  pr <- c("ALP", "LNP", "GRN", "ONP", "OTH")
  ind <- data.table::data.table(i = rep(1:400, each = 5), party = rep(pr, 400), value = 20, ref = 20, n_ref = 5,
                                date = as.Date("2026-01-01"), firm = "Indep", paid = FALSE, side = NA_character_)
  ind[, d := stats::rnorm(.N, 0, 2)]
  pd <- data.table::data.table(i = rep(1000 + seq_len(n_paid), each = 5), party = rep(pr, n_paid), value = 20, ref = 20,
                               n_ref = 5, date = as.Date("2026-06-01"), firm = "Paid", paid = TRUE, side = "LNP")
  pd[, d := stats::rnorm(.N, 0, sd_paid) + ifelse(party == "LNP", lean_lnp, -lean_lnp / 4)]
  data.table::rbindlist(list(ind, pd))
}

test_that("a real lean toward the sponsor is found and kept; none is invented", {
  f1 <- paid_poll_fit(ppc_dv(lean_lnp = 4, sd_paid = 2))
  expect_gt(f1$lean$shrunk[f1$lean$side == "LNP"], 2.5)
  f0 <- paid_poll_fit(ppc_dv(lean_lnp = 0, sd_paid = 2))
  # no lean: what survives shrinkage is within 2 SE of zero (a tolerance in SE, not points: CLAUDE.md)
  expect_lt(abs(f0$lean$shrunk[f0$lean$side == "LNP"]), 2 * f0$lean$se[f0$lean$side == "LNP"])
  expect_lt(abs(f0$lean$shrunk[f0$lean$side == "LNP"]), abs(f0$lean$m[f0$lean$side == "LNP"]))   # pulled toward 0
  expect_lt(f0$factor, 1.15)
})

test_that("paid polls noisier than independent ones get a noise factor above 1", {
  f <- paid_poll_fit(ppc_dv(lean_lnp = 0, sd_paid = 5))
  expect_gt(f$factor, 1.5)
})

test_that("apply moves the side's share to the other parties, keeps the total and relabels the firm", {
  polls <- data.table::data.table(date = as.Date(c("2026-10-01", "2026-10-05", "2026-12-01")), firm = c("A", "B", "C"),
                                  ALP = c(25, 24, 25), LNP = c(32, 31, 32), GRN = c(15, 14, 15), ONP = c(14, 21, 14),
                                  OTH = c(14, 10, 14))
  fit <- list(lean = data.table::data.table(side = "GRN", n = 1L, m = 2, se = 1, w = 1, shrunk = 1.5), factor = 1.25)
  ap <- paid_poll_apply(polls, c("party", "media", "party"), c("Victorian Greens", "", "Victorian Greens"), fit,
                        as.Date("2026-11-13"))
  p <- ap$polls
  expect_equal(p$GRN[1], 13.5)
  expect_equal(sum(unlist(p[1, c("ALP", "LNP", "GRN", "ONP", "OTH")])), 100)
  expect_identical(p$firm, c("A [paid]", "B", "C"))           # the poll after the cutoff is left alone
  expect_identical(unlist(p[2, -1:-2]), unlist(polls[2, -1:-2]))
  expect_identical(ap$firm_factors, c("A [paid]" = 1.25))
})

test_that("the switch accepts only 0 or 1", {
  withr::local_envvar(AUSPOL_PAID_POLL_CORRECT = "2")
  expect_error(paid_poll_mode(), "must be")
})
