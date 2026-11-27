# Lane B night switches (R/night_flow.R; docs/plans/prereg-night-lane-b-2026-11-27.md). Synthetic inputs only.

lb_sim <- function(seats, winner, runner, share, parties = c("ALP", "LNP", "GRN", "IND")) {
  n <- length(winner); k <- length(seats)
  W <- matrix(winner, n, k, dimnames = list(NULL, seats)); R <- matrix(runner, n, k, dimnames = list(NULL, seats))
  S <- matrix(share, n, k, dimnames = list(NULL, seats))
  tot <- matrix(0L, n, length(parties), dimnames = list(NULL, parties))
  for (j in seq_len(k)) for (p in parties) tot[, p] <- tot[, p] + as.integer(W[, j] == p)
  wp <- do.call(rbind, lapply(seats, function(s) { t <- table(W[, s]) / n; data.frame(seat = s, party = names(t), prob = as.numeric(t), stringsAsFactors = FALSE) }))
  list(tcp_winner = W, tcp_runnerup = R, tcp_share = S, totals = tot, win_prob = wp)
}

lb_fp <- function(junior = TRUE) {
  data.table::rbindlist(lapply(c("B1", "B2", "B3"), function(b) data.table::data.table(
    district = "Mildura", booth = b, booth_type = "ordinary",
    party = c("Independent", "Independent", "National Party", "Australian Labor Party"),
    candidate = c("CUPPER", if (junior) "MILNE" else "CUPPER", "BENHAM", "ZIG"), votes = c(40, 10, 40, 10))))
}
lb_tcp <- function() data.table::rbindlist(lapply(c("B1", "B2", "B3"), function(b) data.table::data.table(
  district = "Mildura", booth = b, vote_type = "ordinary", party_raw = c("Independent", "National Party"), votes = c(48, 52))))
lb_post <- matrix(c(10, 40, 0, 50), 1, dimnames = list("Mildura", c("ALP", "LNP", "GRN", "IND")))

test_that("cand_level (B1) moves the junior's votes into the flow; off and no-junior cases are the class count", {
  u <- list(Mildura = c("B1", "B2", "B3"))
  o0 <- night_tcp_obs(lb_tcp(), lb_fp(), u, lb_post)
  expect_identical(o0, night_tcp_obs(lb_tcp(), lb_fp(), u, lb_post, cand_level = FALSE, by_type = NULL))
  o1 <- night_tcp_obs(lb_tcp(), lb_fp(), u, lb_post, cand_level = TRUE)
  # class level: IND 50 of 100, 2CP IND 48 -> flow clamped at 0; candidate level: Cupper 40, others 20, flow 8/20
  expect_equal(o0$flow, 0)
  expect_equal(o1$a, "IND"); expect_equal(o1$flow, 0.4)
  expect_equal(o1$fp_a, 50 * 40 / 50)
  expect_equal(o1$share_a, (40 + 0.4 * (100 - 40 - 40)) / 100)
  # one candidate per class: identical numbers
  expect_equal(night_tcp_obs(lb_tcp(), lb_fp(FALSE), u, lb_post, cand_level = TRUE)$flow,
               night_tcp_obs(lb_tcp(), lb_fp(FALSE), u, lb_post)$flow)
})

test_that("night_same_class_shift moves unsplit juniors by (1 - g) and leaves split or junior-free seats alone", {
  set.seed(3)
  sh <- 0.5 + stats::rnorm(400, 0.04, 0.03)                    # IND's share of IND v LNP
  sim <- lb_sim("Mildura", ifelse(sh > 0.5, "IND", "LNP"), ifelse(sh > 0.5, "LNP", "IND"), pmax(sh, 1 - sh))
  cv <- .night_cand_votes(lb_fp(), list(Mildura = c("B1", "B2", "B3")), "Mildura")
  expect_equal(cv$jun2[cv$cls == "IND"], 30)
  fi <- lb_fp(); fi$votes <- as.integer(fi$votes)            # integer votes (the federal booth tables) must not stop it
  expect_equal(.night_cand_votes(fi, list(Mildura = c("B1", "B2", "B3")), "Mildura")$jun2, cv$jun2)
  out <- night_same_class_shift(sim, cv, lb_post, c(IND = 0.3, LNP = 0.7), cs0 = list(r = c(Mildura = 0.27)))
  d <- attr(out, "same_class")
  expect_equal(d$unsplit, 30 / 150); expect_equal(d$shift, 0.5 * 0.2 * 0.7)
  pa0 <- ifelse(sim$tcp_winner == "IND", sim$tcp_share, 1 - sim$tcp_share)
  pa1 <- ifelse(out$tcp_winner == "IND", out$tcp_share, 1 - out$tcp_share)
  expect_equal(as.vector(pa1), pmax(0, as.vector(pa0) - 0.07))
  expect_lt(out$win_prob$prob[out$win_prob$party == "IND"], sim$win_prob$prob[sim$win_prob$party == "IND"])
  expect_equal(sum(out$win_prob$prob), 1)
  expect_true(all(rowSums(out$totals) == 1L))
  # the simulator split this class (no Coalition split, night split on IND): only a third candidate would move
  ncs <- list(cls = c(Mildura = "IND"))
  out2 <- night_same_class_shift(sim, cv, lb_post, c(IND = 0.3), cs0 = NULL, ncs = ncs)
  expect_identical(out2$tcp_share, sim$tcp_share)
  cv1 <- .night_cand_votes(lb_fp(FALSE), list(Mildura = c("B1", "B2", "B3")), "Mildura")
  expect_identical(night_same_class_shift(sim, cv1, lb_post, c(IND = 0.3))$tcp_share, sim$tcp_share)
})

test_that("night_flow_pool shifts a seat by its pair type's counted error, not its own, and nothing when there is none", {
  set.seed(5)
  seats <- c("S1", "S2", "S3", "S4")
  sh <- 0.5 + stats::rnorm(300, 0.03, 0.02)                    # ALP's share of ALP v GRN, flow ~ (sh - 0.3) / 0.4
  sim <- lb_sim(seats, ifelse(sh > 0.5, "ALP", "GRN"), ifelse(sh > 0.5, "GRN", "ALP"), pmax(sh, 1 - sh))
  post <- matrix(rep(c(30, 0, 30, 0), each = 4), 4, dimnames = list(seats, c("ALP", "LNP", "GRN", "IND")))
  fm <- stats::median((sh - 0.3) / 0.4)
  obs <- data.table::data.table(seat = c("S1", "S2", "S3"), a = "ALP", b = "GRN", flow = fm + c(0.15, 0.17, 0.13),
                                flow_se = 0.02, fp_a = 30, fp_b = 30)
  out <- night_flow_pool(sim, obs, post)
  fp <- attr(out, "flow_pool")
  expect_gt(attr(fp, "hyper")[["sigma"]], 0)
  mu4 <- fp$mu[fp$seat == "S4"]                                 # uncounted: all three seats' error
  expect_gt(mu4, 0.12); expect_lt(mu4, 0.16)
  expect_false(fp$own_count[fp$seat == "S4"]); expect_true(fp$own_count[fp$seat == "S1"])
  pa0 <- ifelse(sim$tcp_winner[, "S4"] == "ALP", sim$tcp_share[, "S4"], 1 - sim$tcp_share[, "S4"])
  pa1 <- ifelse(out$tcp_winner[, "S4"] == "ALP", out$tcp_share[, "S4"], 1 - out$tcp_share[, "S4"])
  expect_equal(pa1, pmin(1, pa0 + mu4 * 0.4))
  # counts that agree with the draws: no common error, nothing moves
  obs0 <- data.table::copy(obs); obs0$flow <- fm + c(0.01, -0.01, 0)
  out0 <- night_flow_pool(sim, obs0, post)
  expect_identical(out0$tcp_share, sim$tcp_share)
  expect_equal(attr(attr(out0, "flow_pool"), "hyper")[["sigma"]], 0)
})

test_that("by_type (B3) with ordinary booths only keeps the ordinary flow, and mixes in a counted postal gap", {
  u <- list(Mildura = c("B1", "B2", "B3"))
  ref <- data.table::data.table(district = "Mildura", booth_type = c("ordinary", "ordinary", "ordinary", "postal", "postal", "postal"),
                                party = rep(c("Independent", "National Party", "Australian Labor Party"), 2), votes = c(40, 40, 20, 40, 40, 20))
  fp2 <- data.table::rbindlist(lapply(c("B1", "B2", "B3"), function(b) data.table::data.table(district = "Mildura", booth = b,
    booth_type = "ordinary", party = c("Independent", "National Party", "Australian Labor Party"), candidate = c("CUPPER", "BENHAM", "ZIG"), votes = c(40, 40, 20))))
  o0 <- night_tcp_obs(lb_tcp(), fp2, u, lb_post)
  o1 <- night_tcp_obs(lb_tcp(), fp2, u, lb_post, by_type = ref)
  expect_equal(o0$flow, 0.4)
  expect_true(o1$type_mix); expect_equal(o1$flow, o0$flow)
  # a postal unit whose others go 0.2 to IND (ordinary: (48 - 40) / 20 = 0.4); one seat, so no spread to pool: gap taken whole
  fpp <- rbind(fp2, data.table::data.table(district = "Mildura", booth = "Postal", booth_type = "postal",
               party = c("Independent", "National Party", "Australian Labor Party"), candidate = c("CUPPER", "BENHAM", "ZIG"), votes = c(40, 40, 20)))
  tcpp <- rbind(lb_tcp(), data.table::data.table(district = "Mildura", booth = "Postal", vote_type = "postal", party_raw = c("Independent", "National Party"), votes = c(44, 56)))
  o2 <- night_tcp_obs(tcpp, fpp, list(Mildura = c("B1", "B2", "B3", "postal")), lb_post, by_type = ref)
  expect_equal(o2$flow, 0.5 * 0.4 + 0.5 * 0.2)
  expect_equal(o2$flow_class_mix, (3 * 8 + 4) / (3 * 20 + 20))
})

test_that("lane B cfg values: off by default, on, and a bad value stops", {
  expect_false(.night_lane_b_cfg(NULL, "flow_pool")); expect_false(.night_lane_b_cfg("off", "tcp_by_type"))
  expect_true(.night_lane_b_cfg("on", "flow_pool"))
  expect_error(.night_lane_b_cfg("yes", "flow_pool"), "NSC3!")
  local_mocked_bindings(night_same_class_params = function(target_election, ...) c(IND = 0.3))
  ca <- new.env()
  expect_equal(suppressMessages(.night_lane_b_cfg("on", "same_class", "vic2026", ca)), c(IND = 0.3))
  expect_true(exists("same_class_vic2026", envir = ca))
})

test_that("the live night defaults B1c (tcp_cand) on, and 'off' turns it off", {
  expect_true(.NIGHT_TCP_CAND)
  expect_true(.night_tcp_cand_cfg(NULL))
  expect_true(.night_tcp_cand_cfg("on"))
  expect_false(.night_tcp_cand_cfg("off"))
  expect_false(.night_tcp_cand_cfg(FALSE))
  expect_error(.night_tcp_cand_cfg("yes"), "NSC3!")
})

test_that("night_same_class_params is time-forward: target-year events never enter", {
  tx <- data.table::data.table(election = c("vic2018", "vic2018", "vic2022", "vic2022"), seat = "X", round = 1L,
                               from = "IND", to = c("IND", "LNP", "IND", "LNP"), votes = c(30, 70, 90, 10))
  g <- night_same_class_params("vic2022", transfers = tx, classes = "IND")
  # one-step f 0.3 -> prior 0.65; one final-pair event at 0.3, shrunk with 10 pseudo-events
  expect_equal(unname(g[["IND"]]), (0.3 + 10 * 0.65) / 11)
  expect_error(night_same_class_params("vic2018", transfers = tx, classes = "IND"), "NSC1!")
})
