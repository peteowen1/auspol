# Federal polls' state breakdowns in the state trend (R/trend_fed.R;
# docs/plans/prereg-fed-breakdowns-in-trend-2026-10-26.md). Synthetic data only, so CI (no anchor clone) runs them.

fed_synth <- function(seed = 3) {
  set.seed(seed)
  start <- as.Date("2020-01-01"); T_days <- 600
  lat_a <- 36 + cumsum(rnorm(T_days + 1, 0, 0.08)); lat_l <- 34 + cumsum(rnorm(T_days + 1, 0, 0.08))
  t <- sort(sample(5:T_days, 40)); firm <- sample(c("A", "B", "C"), 40, replace = TRUE)
  polls <- data.table::data.table(date = start + t, firm = firm, tpp_published = NA_real_,
                                  ALP = lat_a[t + 1] + rnorm(40, 0, 1.5), LNP = lat_l[t + 1] + rnorm(40, 0, 1.5))
  polls[, OTH := 100 - ALP - LNP]
  data.table::setattr(polls, "parties", c("ALP", "LNP", "OTH"))
  data.table::setattr(polls, "region", "tst")
  cycles <- data.table::data.table(region = "tst", year = 2022L, start = start, end = start + T_days + 30)
  flows <- data.table::data.table(party = "OTH", flow_alp = 50, exhaust = 0)
  # breakdowns: 4 points BELOW the state level for Labor (the offset), 2 firms, one federal term
  ft <- sort(sample(20:(T_days - 10), 30))
  fed <- data.table::data.table(start = start + ft - 3L, end = start + ft, canon = sample(c("f1", "f2"), 30, replace = TRUE),
                                term = "fed2019", ALP = lat_a[ft + 1] - 4 + rnorm(30, 0, 2), LNP = lat_l[ft + 1] + rnorm(30, 0, 2),
                                GRN = NA_real_, ONP = 10, vmult = 1 / 0.15)
  data.table::setattr(fed, "prior_sd", 10)
  list(polls = polls, cycles = cycles, flows = flows, fed = fed, as_at = start + T_days, priors = c(ALP = 36, LNP = 34, OTH = 30))
}

test_that("the arm is off by default and fed = NULL is the call without it (R = 0 identity)", {
  withr::local_envvar(AUSPOL_TREND_FED_R = NA)
  expect_identical(trend_fed_config()$r, 0)
  expect_null(trend_fed_for("vic", as.Date("2022-11-01"), as.Date("2018-11-24")))
  expect_null(trend_fed_for_cycle("vic", 2022, as.Date("2022-11-01")))
  s <- fed_synth()
  a <- trend_as_at(s$polls, 2022, s$cycles, s$as_at, s$priors, s$flows, with_series = TRUE)
  b <- trend_as_at(s$polls, 2022, s$cycles, s$as_at, s$priors, s$flows, with_series = TRUE, fed = NULL)
  expect_identical(a, b)
  # and fit_trend() with the new arguments unset is the old fit, bit for bit
  cp <- cycle_polls(s$polls, 2022, s$cycles)
  expect_identical(fit_trend(cp, "ALP", prior_result = 36), fit_trend(cp, "ALP", prior_result = 36, fed_obs = NULL, t_end = NULL))
})

test_that("a federal target never gets breakdowns, even with the arm on", {
  withr::local_envvar(AUSPOL_TREND_FED_R = "0.15")
  expect_null(trend_fed_for("fed", as.Date("2022-05-01"), as.Date("2019-05-18")))
})

test_that("a breakdown whose fieldwork had not ended before the as-at date trips the assertion", {
  s <- fed_synth()
  late <- data.table::copy(s$fed)
  late$end[nrow(late)] <- s$as_at          # ends ON the as-at date: still in the field
  data.table::setattr(late, "prior_sd", 10)
  expect_error(trend_as_at(s$polls, 2022, s$cycles, s$as_at, s$priors, s$flows, fed = late), "FTR0!")
  early <- data.table::copy(s$fed); early$start[1] <- s$cycles$start - 1
  data.table::setattr(early, "prior_sd", 10)
  expect_error(trend_as_at(s$polls, 2022, s$cycles, s$as_at, s$priors, s$flows, fed = early), "FTR0!")
  # the clean table runs and admits every row
  ok <- trend_as_at(s$polls, 2022, s$cycles, s$as_at, s$priors, s$flows, fed = s$fed)
  expect_equal(ok$n_fed, 2L * nrow(s$fed))   # ALP and LNP rows (ONP is not a fitted class)
})

test_that("federal house effects take zero weight in the sum-to-zero, and the offset holds the level", {
  s <- fed_synth()
  cp <- cycle_polls(s$polls, 2022, s$cycles)
  data.table::setattr(cp, "cycle_end", s$as_at)
  prep0 <- prep_trend_obs(cp, "ALP", prior_result = 36)
  fo <- s$fed[, list(start, end, firm = canon, term, y = ALP, vmult)]
  data.table::setattr(fo, "prior_sd", 10)
  prep1 <- prep_add_fed(prep0, fo, t_end = s$as_at - 1)
  sig <- default_sigmas("logit")
  an <- trend_anchor(prep0, 36)
  ps1 <- trend_prior_system(prep1, sig[["sigma_rw"]], sd_to_link(3, prep0$p_ref), an, sd_to_link(1.5, prep0$p_ref))
  Js <- prep1$J_state
  expect_true(all(ps1$szc_w[-seq_len(Js)] == 0))
  expect_equal(ps1$szc_w[seq_len(Js)], prep0$obs[, .N, by = j][order(j), N] / nrow(prep0$obs))
  # the state block of the prior is exactly the no-breakdown prior
  prep0x <- prep_add_fed(prep0, NULL, t_end = s$as_at - 1)    # same walk length, no breakdowns
  expect_null(prep0x$fed)
  ps0 <- trend_prior_system(prep0x, sig[["sigma_rw"]], sd_to_link(3, prep0$p_ref), an, sd_to_link(1.5, prep0$p_ref))
  n0 <- prep0x$T_ + prep0x$J
  expect_equal(as.matrix(ps1$P[seq_len(n0), seq_len(n0)]), as.matrix(ps0$P))
  # moving every breakdown 6 points barely moves the trend: the offset absorbs a level difference
  base <- trend_as_at(s$polls, 2022, s$cycles, s$as_at, s$priors, s$flows, fed = s$fed)
  shifted <- data.table::copy(s$fed); shifted$ALP <- shifted$ALP - 6
  data.table::setattr(shifted, "prior_sd", 10)
  sh <- trend_as_at(s$polls, 2022, s$cycles, s$as_at, s$priors, s$flows, fed = shifted)
  expect_lt(abs(sh$fp[["ALP"]] - base$fp[["ALP"]]), 0.3)
  # ...while a tight prior (federal equals state) lets the shift drag the level
  tight <- data.table::copy(shifted); data.table::setattr(tight, "prior_sd", 0.5); tight$vmult <- 1
  ti <- trend_as_at(s$polls, 2022, s$cycles, s$as_at, s$priors, s$flows, fed = tight)
  expect_gt(abs(ti$fp[["ALP"]] - base$fp[["ALP"]]), 2)
  # the fitted offset recovers the 4-point gap (ALP breakdowns ~4 below the state level)
  fe <- base$fed_effects[base$fed_effects$party == "ALP"]
  expect_true(all(fe$offset_pts < -2 & fe$offset_pts > -6))
  expect_true(all(is.finite(fe$sd_pts) & fe$sd_pts > 0))
})

test_that("class gating: no class created, Coalition left out where Liberal and National fit separately", {
  s <- fed_synth()
  cp <- cycle_polls(s$polls, 2022, s$cycles)
  g <- .trend_fed_gate(s$fed, cp, c("ALP", "LNP", "OTH"), s$as_at, verbose = FALSE)
  expect_setequal(names(g$obs), c("ALP", "LNP"))          # ONP has values but the state polls do not fit it
  g2 <- .trend_fed_gate(s$fed, cp, c("ALP", "LNP", "NAT", "OTH"), s$as_at, verbose = FALSE)
  expect_setequal(names(g2$obs), "ALP")
  expect_match(g2$dropped, "LNP")
  # a thin cycle stays NULL: breakdowns do not count toward min_polls
  thin <- s$polls[1:6]
  for (a in c("parties", "region")) data.table::setattr(thin, a, attr(s$polls, a))
  expect_null(trend_as_at(thin, 2022, s$cycles, s$as_at, s$priors, s$flows, fed = s$fed))
})

test_that("a breakdown observes the mean of its fieldwork days (1/L spreading)", {
  s <- fed_synth()
  cp <- cycle_polls(s$polls, 2022, s$cycles)
  data.table::setattr(cp, "cycle_end", s$as_at)
  prep0 <- prep_trend_obs(cp, "ALP", prior_result = 36)
  fo <- data.table::data.table(start = as.Date(c("2020-06-01", "2020-09-10")), end = as.Date(c("2020-06-10", "2020-09-10")),
                               firm = "f1", term = "fed2019", y = c(30, 31), vmult = 1)
  data.table::setattr(fo, "prior_sd", 10)
  p1 <- prep_add_fed(prep0, fo, t_end = NULL, min_firm_polls = 1)
  H <- as.matrix(trend_obs_matrix(p1))
  n <- nrow(prep0$obs)
  r1 <- H[n + 1, seq_len(p1$T_)]
  expect_equal(sum(r1 > 0), 10L); expect_equal(unique(r1[r1 > 0]), 0.1); expect_equal(sum(r1), 1)
  expect_equal(which(r1 > 0), as.integer(fo$start[1] - prep0$start) + 1:10)
  r2 <- H[n + 2, seq_len(p1$T_)]
  expect_equal(which(r2 > 0), as.integer(fo$end[2] - prep0$start) + 1L); expect_equal(sum(r2), 1)
  # each row loads its own federal house effect, and the state rows are unchanged
  expect_equal(unname(rowSums(H[n + 1:2, p1$T_ + p1$J_state + seq_len(p1$fed$J), drop = FALSE])), c(1, 1))
  H0 <- as.matrix(trend_obs_matrix(prep0))
  expect_equal(H[seq_len(n), seq_len(ncol(H0))], H0)
})

test_that("the walk extension keeps today's folding: only parties that reach the last poll day move, together", {
  s <- fed_synth()
  cp <- cycle_polls(s$polls, 2022, s$cycles)
  D <- max(cp$date)
  cp$LNP[cp$date > D - 60] <- NA                    # LNP's own series now ends ~2 months before the last poll
  late <- data.table::copy(s$fed)
  late$end[nrow(late)] <- D + 5; late$start[nrow(late)] <- D + 2
  data.table::setattr(late, "prior_sd", 10)
  g <- .trend_fed_gate(late, cp, c("ALP", "LNP", "OTH"), D + 10, verbose = FALSE)
  expect_equal(g$t_end$ALP, D + 5); expect_equal(g$t_end$OTH, D + 5)   # the parties on the last day move together
  expect_null(g$t_end$LNP)                                             # the short party keeps its own end
  expect_true(all(g$obs$LNP$end <= max(cp$date[!is.na(cp$LNP)])))     # and loses breakdowns past it
  expect_true(any(g$obs$ALP$end == D + 5))
})
