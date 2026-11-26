test_that("AUSPOL_ONP_FLOW_CAL=0 returns the override unchanged", {
  ov <- list(list(`ALP|LNP+ONP` = c(LNP = 53, ONP = 47)))
  withr::with_envvar(c(AUSPOL_ONP_FLOW_CAL = "0"), expect_identical(onp_flow_cal(ov, NULL, "vic2026"), ov))
  withr::with_envvar(c(AUSPOL_ONP_FLOW_CAL = "2"), expect_error(onp_flow_cal(ov, NULL, "vic2026"), "must be"))
})

test_that("onp_pair_rates measures the X v One Nation split from earlier exclusions only as given", {
  H <- data.table::data.table(
    election = c("e1", "e1", "e1", "e2", "e2"), event_id = c(1, 1, 2, 3, 3),
    from = c("ALP", "ALP", "GRN", "ALP", "ALP"), surv = c("LNP+ONP", "LNP+ONP", "ALP+LNP+ONP", "LNP+ONP", "LNP+ONP"),
    to = c("LNP", "ONP", "ALP", "LNP", "ONP"), votes = c(60, 40, 100, 80, 20))
  d <- as.Date(c(e1 = "2020-01-01", e2 = "2024-01-01"))
  r <- onp_pair_rates(H, as.Date("2026-01-01"), 0, d)
  a <- r[r$from == "ALP" & r$x == "LNP"]
  expect_equal(a$r_hist, mean(c(0.6, 0.8)))   # equal weight per election at hl = 0
  expect_equal(a$n_elec, 2L)
  # the Greens exclusion went all to Labor: a Labor v ONP rate of 1, and no LNP v ONP rate (neither got a vote)
  expect_equal(r$r_hist[r$from == "GRN" & r$x == "ALP"], 1)
  expect_equal(nrow(r[r$from == "GRN" & r$x == "LNP"]), 0L)
})

test_that("onp_flow_cal_apply shrinks the pairwise split and leaves other survivors alone", {
  rates <- data.table::data.table(from = c("ALP", "GRN", "GRN"), x = c("LNP", "LNP", "ALP"),
                                  r_hist = c(0.65, 0.55, 0.85), n_elec = c(3L, 3L, 3L), n_excl = 10L,
                                  r_min = 0.5, r_max = 0.9)
  ov <- list(list(`ALP|LNP+ONP` = c(LNP = 50, ONP = 50),
                  `GRN|ALP+LNP+ONP` = c(ALP = 50, LNP = 20, ONP = 30),
                  `LNP|ALP+GRN` = c(ALP = 30, GRN = 70)), NULL)
  out <- utils::capture.output(o <- onp_flow_cal_apply(ov, rates, k = 3, target_election = "t"))
  v <- o[[1]][["ALP|LNP+ONP"]]
  expect_equal(unname(v[["LNP"]] / sum(v)), 0.5 + 0.5 * (0.65 - 0.5))   # w = 3 / (3 + 3)
  expect_equal(sum(v), 100)
  g <- o[[1]][["GRN|ALP+LNP+ONP"]]
  expect_equal(sum(g), 100)
  expect_equal(unname(g[["LNP"]] / (g[["LNP"]] + g[["ONP"]])), 0.4 + 0.5 * (0.55 - 0.4))
  expect_equal(unname(g[["ALP"]] / (g[["ALP"]] + g[["ONP"]])), 0.625 + 0.5 * (0.85 - 0.625))
  expect_identical(o[[1]][["LNP|ALP+GRN"]], ov[[1]][["LNP|ALP+GRN"]])
  expect_null(o[[2]])
  expect_true(any(grepl("^ONC1 ", out)))
  # k = 0 takes the history rate outright
  utils::capture.output(o0 <- onp_flow_cal_apply(ov, rates, k = 0, target_election = "t"))
  expect_equal(unname(o0[[1]][["ALP|LNP+ONP"]][["LNP"]]), 65)
})
