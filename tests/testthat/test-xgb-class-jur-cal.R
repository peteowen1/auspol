# AUSPOL_XGB_CLASS_JUR_CAL: time-forward per-(jurisdiction, class) shift, partially pooled.
# Synthetic as-at predictions: 2 seats per election, classes ALP/IND; every seat sums to 100.
mk_pred <- function(pair, res_ind) {
  # xgb says IND 10 / ALP 90; actual IND = 10 + res_ind, ALP = 90 - res_ind
  data.table::data.table(pair = pair, seat = rep(c("S1", "S2"), each = 2), party = rep(c("ALP", "IND"), 2),
                         xgb_pred = rep(c(90, 10), 2),
                         actual_share = rep(c(90 - res_ind, 10 + res_ind), 2))
}

test_that("history uses only elections dated strictly before the target (time-forward)", {
  P <- data.table::rbindlist(list(mk_pred("vic2014", 1), mk_pred("vic2018", 1), mk_pred("vic2022", 50)))
  H <- xcj_history(P)
  f <- xcj_fit(H, "vic2022")
  expect_equal(f$k[f$party == "IND"], 2L)            # vic2022's own residual (50) is not in its fit
  expect_lt(abs(f$mu[f$party == "IND"]), 2)
  # a target dated before every election in the table has nothing to learn from
  f0 <- xcj_fit(H, "vic2010")
  expect_true(all(f0$shift == 0))
})

test_that("tau^2 = 0 (no between-jurisdiction signal) gives no shift", {
  # residuals of +-1 alternating within every jurisdiction and mean zero: mu_j = 0 everywhere
  P <- data.table::rbindlist(list(
    mk_pred("vic2014", 1), mk_pred("vic2018", -1), mk_pred("nsw2015", 1), mk_pred("nsw2019", -1),
    mk_pred("qld2017", 1), mk_pred("qld2020", -1), mk_pred("vic2022", 0)))
  f <- xcj_fit(xcj_history(P), "vic2022")
  expect_true(all(f$tau2[is.finite(f$tau2)] == 0))
  expect_true(all(f$shift == 0))
})

test_that("a real, consistent jurisdiction lean is shrunk but not removed; w = tau2 / (tau2 + se2)", {
  P <- data.table::rbindlist(list(
    mk_pred("vic2014", -3), mk_pred("vic2018", -3.2), mk_pred("nsw2015", 0.1), mk_pred("nsw2019", -0.1),
    mk_pred("qld2017", 0.05), mk_pred("qld2020", -0.05), mk_pred("vic2022", 0)))
  f <- xcj_fit(xcj_history(P), "vic2022")[party == "IND"]
  expect_equal(f$k, 2L)
  expect_equal(f$w, f$tau2 / (f$tau2 + f$se^2))
  expect_lt(f$shift, 0)                              # IND was over-called: shift is negative
  expect_gt(f$shift, f$mu)                           # shrunk toward 0
})

test_that("a jurisdiction with no earlier election gets no shift", {
  P <- data.table::rbindlist(list(mk_pred("vic2014", -3), mk_pred("vic2018", -3), mk_pred("nsw2015", 1), mk_pred("nsw2019", 1)))
  f <- xcj_fit(xcj_history(P), "qld2020")
  expect_true(all(f$shift == 0))
})

test_that("seat totals are preserved and shares never go below 0 (matrix and long)", {
  fit <- data.table::data.table(party = c("ALP", "IND"), shift = c(5, -30))
  sh <- matrix(c(90, 10, 60, 40), nrow = 2, byrow = TRUE, dimnames = list(c("S1", "S2"), c("ALP", "IND")))
  out <- xcj_shift_matrix(sh, fit)
  expect_equal(unname(rowSums(out)), c(100, 100))
  expect_true(all(out >= 0))
  expect_equal(unname(out["S1", "IND"]), 0)           # floored, then rescaled to 100
  # raw (non-100) totals keep their own total in the long form
  x <- c(80, 10, 50, 40); seat <- c("S1", "S1", "S2", "S2"); party <- c("ALP", "IND", "ALP", "IND")
  y <- xcj_shift_long(x, seat, party, fit)
  expect_equal(tapply(y, seat, sum)[["S1"]], 90)
  expect_equal(tapply(y, seat, sum)[["S2"]], 90)
  expect_true(all(y >= 0))
  # held cells (an unnominated class kept at 0) stay put
  z <- xcj_shift_long(c(90, 0, 60, 40), seat, party, data.table::data.table(party = c("ALP", "IND"), shift = c(-5, 5)),
                      hold = c(FALSE, TRUE, FALSE, FALSE))
  expect_equal(z[2], 0)
  expect_equal(tapply(z, seat, sum)[["S1"]], 90)
})

test_that("switch off (the default) returns inputs untouched", {
  withr::local_envvar(AUSPOL_XGB_CLASS_JUR_CAL = NA)
  P <- data.table::rbindlist(list(mk_pred("vic2014", -3), mk_pred("vic2018", -3), mk_pred("vic2022", 0)))
  expect_false(xcj_enabled())
  expect_identical(xcj_apply_asat(P), P)
  withr::local_envvar(AUSPOL_XGB_CLASS_JUR_CAL = "0")
  expect_identical(xcj_apply_asat(P), P)
})

test_that("switch on corrects each target from its own earlier history only", {
  withr::local_envvar(AUSPOL_XGB_CLASS_JUR_CAL = "1")
  P <- data.table::rbindlist(list(
    mk_pred("vic2014", -3), mk_pred("vic2018", -3.2), mk_pred("nsw2015", 0.1), mk_pred("nsw2019", -0.1),
    mk_pred("qld2017", 0.05), mk_pred("qld2020", -0.05), mk_pred("vic2022", -3)))
  out <- utils::capture.output(Q <- xcj_apply_asat(P))
  expect_true(any(grepl("^XCJ1", out)))
  expect_equal(Q[pair == "vic2014"]$xgb_pred, P[pair == "vic2014"]$xgb_pred)   # earliest: nothing before it
  expect_lt(Q[pair == "vic2022" & party == "IND"]$xgb_pred[1], 10)
  expect_equal(Q[pair == "vic2022", sum(xgb_pred), by = seat]$V1, c(100, 100))
})
