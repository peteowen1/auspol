# Election-night replay update (R/night_update.R, issue #153). Synthetic booths; no anchor data.

nu_booths <- function(alp, lnp, booths = c("B1", "B2", "B3"), district = "Seat A") {
  data.table::rbindlist(lapply(seq_along(booths), function(i) data.table::data.table(
    district = district, booth = booths[i], booth_type = "ordinary",
    party = c("Australian Labor Party", "Liberal"), votes = c(alp[i], lnp[i]))))
}

test_that("the switch parses strictly and is off when unset", {
  withr::local_envvar(AUSPOL_NIGHT_REPLAY_FRAC = NA)
  expect_true(is.na(night_replay_frac()))
  withr::local_envvar(AUSPOL_NIGHT_REPLAY_FRAC = "0.5")
  expect_identical(night_replay_frac(), 0.5)
  for (bad in c("-0.1", "1.5", "half")) {
    withr::local_envvar(AUSPOL_NIGHT_REPLAY_FRAC = bad)
    expect_error(night_replay_frac(), "must be a number from 0 to 1")
  }
})

test_that("the prior sd matches the simulator's level formula and honours the override", {
  sh <- matrix(c(50, 30, 20), 1, dimnames = list("Seat A", c("ALP", "LNP", "GRN")))
  sd <- night_prior_sd(sh, c(1, 10), c(GRN = 2))
  expect_equal(unname(sd[1, "ALP"]), 1 + 10 * sqrt(0.5 * 0.5))
  expect_equal(unname(sd[1, "GRN"]), 1 + 10 * 2 * sqrt(0.2 * 0.8))
  ov <- matrix(c(NA, 7, NA), 1, dimnames = dimnames(sh))
  expect_equal(unname(night_prior_sd(sh, c(1, 10), NULL, ov)[1, ]), c(1 + 10 * 0.5, 7, 1 + 10 * sqrt(0.16)))
  expect_error(night_prior_sd(sh, NULL), "needs level_sd")
})

test_that("nothing counted leaves the prior untouched; everything counted lands on the final count", {
  ref  <- nu_booths(c(50, 60, 40), c(50, 40, 60))
  live <- nu_booths(c(60, 70, 50), c(40, 30, 50))          # a uniform 10-point swing to ALP
  sh <- matrix(c(52, 48), 1, dimnames = list("Seat A", c("ALP", "LNP")))
  psd <- matrix(4, 1, 2, dimnames = dimnames(sh))
  u0 <- night_booth_update(sh, psd, 0, live, ref)
  expect_identical(u0$shares, sh); expect_identical(u0$sd, psd); expect_identical(u0$n_updated, 0L)
  u1 <- night_booth_update(sh, psd, 1, live, ref)
  expect_equal(unname(u1$shares[1, "ALP"]), 60, tolerance = 0.5)   # final ALP share is 180/300
  expect_true(all(u1$sd < psd)); expect_equal(unname(u1$counted["Seat A"]), 1)
  expect_gt(u1$resolved, 0.9)
  expect_equal(sum(u1$shares[1, ]), 100)
})

test_that("a seat with no booth data keeps its prior, and the replay leaves the caller's random stream alone", {
  ref  <- nu_booths(c(50, 60, 40), c(50, 40, 60))
  live <- nu_booths(c(60, 70, 50), c(40, 30, 50))
  sh <- matrix(c(52, 48, 45, 55), 2, byrow = TRUE, dimnames = list(c("Seat A", "Seat Z"), c("ALP", "LNP")))
  psd <- matrix(4, 2, 2, dimnames = dimnames(sh))
  set.seed(7); before <- .Random.seed
  u <- night_booth_update(sh, psd, 0.5, live, ref)
  expect_identical(.Random.seed, before)
  expect_identical(u$shares["Seat Z", ], sh["Seat Z", ])
})

test_that("statewide draws shrink around their own centre", {
  d <- matrix(c(40, 44, 36, 30, 28, 32), 3, dimnames = list(NULL, c("ALP", "LNP")))
  s <- night_shrink_draws(d, 0.5)
  expect_equal(colMeans(s), colMeans(d))
  expect_equal(apply(s, 2, sd), apply(d, 2, sd) * 0.5)
  expect_identical(night_shrink_draws(d, 1), d)
  expect_null(night_shrink_draws(NULL, 0.5))
})

nu_tcp <- function(a_votes, b_votes, booths = c("B1", "B2", "B3"), district = "Seat A") {
  data.table::rbindlist(lapply(seq_along(booths), function(i) data.table::data.table(
    district = district, booth = booths[i], vote_type = "ordinary",
    party_raw = c("Australian Labor Party", "Liberal"), votes = c(a_votes[i], b_votes[i]))))
}

test_that("the 2CP observation measures the preference flow, not the raw share of early booths", {
  # first preferences: ALP 40, LNP 40, GRN 20 in every booth; 3/4 of the Greens' votes flow to Labor
  fp <- data.table::rbindlist(lapply(c("B1", "B2", "B3"), function(b) data.table::data.table(
    district = "Seat A", booth = b, booth_type = "ordinary",
    party = c("Australian Labor Party", "Liberal", "Australian Greens"), votes = c(40, 40, 20))))
  tcp <- nu_tcp(c(55, 55, 55), c(45, 45, 45))
  post <- matrix(c(30, 50, 20), 1, dimnames = list("Seat A", c("ALP", "LNP", "GRN")))
  o <- night_tcp_obs(tcp, fp, list(`Seat A` = c("B1", "B2")), post)
  expect_equal(o$flow, 0.75)
  expect_equal(o$share_a, (30 + 0.75 * 20) / 100)                 # flow applied to the UPDATED primaries
  expect_equal(nrow(night_tcp_obs(tcp, fp, list(`Seat A` = character()), post)), 0L)
})

nu_sim <- function(winner, runner, share) {
  n <- length(winner)
  list(tcp_winner = matrix(winner, n, 1, dimnames = list(NULL, "Seat A")),
       tcp_runnerup = matrix(runner, n, 1, dimnames = list(NULL, "Seat A")),
       tcp_share = matrix(share, n, 1, dimnames = list(NULL, "Seat A")),
       totals = matrix(c(as.integer(winner == "ALP"), as.integer(winner == "LNP"), integer(n)), n, 3,
                       dimnames = list(NULL, c("ALP", "LNP", "GRN"))),
       win_prob = data.frame(seat = "Seat A", party = c("ALP", "LNP"),
                             prob = c(mean(winner == "ALP"), mean(winner == "LNP")), stringsAsFactors = FALSE))
}

test_that("a counted flow moves the draws, winners, totals and probabilities together", {
  set.seed(1)
  sh <- 0.5 + stats::rnorm(200, 0, 0.02)                           # ALP's share of ALP v LNP
  sim <- nu_sim(ifelse(sh > 0.5, "ALP", "LNP"), ifelse(sh > 0.5, "LNP", "ALP"), pmax(sh, 1 - sh))
  obs <- data.table::data.table(seat = "Seat A", a = "ALP", b = "LNP", flow = 0.9, flow_se = 0.01,
                                fp_a = 40, fp_b = 40, share_a = 0.58, votes = 100)
  out <- night_apply_tcp(sim, obs)
  wp <- out$win_prob
  expect_gt(wp$prob[wp$party == "ALP"], 0.95)                      # strong flow to Labor decides it
  expect_equal(sum(out$totals[, "ALP"]) / 200, wp$prob[wp$party == "ALP"])
  expect_true(all(rowSums(out$totals) == 1L))
  expect_false(attr(out, "night_tcp")$flag)
})

test_that("a VEC pair the model rarely produces is ignored and flagged", {
  sim <- nu_sim(rep("ALP", 100), rep("GRN", 100), rep(0.6, 100))
  obs <- data.table::data.table(seat = "Seat A", a = "ALP", b = "LNP", flow = 0.9, flow_se = 0.01,
                                fp_a = 40, fp_b = 40, share_a = 0.58, votes = 100)
  out <- night_apply_tcp(sim, obs)
  expect_true(attr(out, "night_tcp")$flag)
  expect_identical(out$tcp_winner, sim$tcp_winner)
})

test_that("two counted booths cannot pin the flow down (review of #161)", {
  fp <- data.table::rbindlist(lapply(c("B1", "B2", "B3"), function(b) data.table::data.table(
    district = "Seat A", booth = b, booth_type = "ordinary",
    party = c("Australian Labor Party", "Liberal", "Australian Greens"), votes = c(40, 40, 20))))
  tcp <- nu_tcp(c(55, 55, 55), c(45, 45, 45))
  post <- matrix(c(30, 50, 20), 1, dimnames = list("Seat A", c("ALP", "LNP", "GRN")))
  expect_equal(night_tcp_obs(tcp, fp, list(`Seat A` = c("B1", "B2")), post)$flow_se, 0.25)
  expect_equal(night_tcp_obs(tcp, fp, list(`Seat A` = c("B1", "B2", "B3")), post)$flow_se, 0.02)  # equal flows: the floor
})

test_that("the vote-type gap is off by default and, on, moves an uncounted early unit by the pooled gap", {
  live <- data.table::rbindlist(list(
    data.table::data.table(district = "Seat A", booth = c("B1", "B2", "E"), booth_type = c("ordinary", "ordinary", "early"),
                           party = "Australian Labor Party", votes = c(60, 60, 70)),
    data.table::data.table(district = "Seat A", booth = c("B1", "B2", "E"), booth_type = c("ordinary", "ordinary", "early"),
                           party = "Liberal", votes = c(40, 40, 30))))
  ref <- data.table::copy(live); ref[party == "Australian Labor Party", votes := 50]; ref[party == "Liberal", votes := 50]
  ld <- live[, list(v = sum(votes)), by = list(unit = booth, booth_type, cls = classify_party(party))]
  rd <- ref[, list(v = sum(votes)), by = list(unit = booth, booth_type, cls = classify_party(party))]
  p0 <- project_seat_from_booths(ld, rd, c("B1", "B2"))
  pN <- project_seat_from_booths(ld, rd, c("B1", "B2"), type_gap = NULL)
  expect_identical(p0, pN)
  tg <- data.table::data.table(booth_type = "early", cls = c("ALP", "LNP"), gap = c(0.05, -0.05))
  pg <- project_seat_from_booths(ld, rd, c("B1", "B2"), type_gap = tg)
  expect_equal(pg$projected[pg$cls == "ALP"] - p0$projected[p0$cls == "ALP"], 0.05 * 100, tolerance = 1e-6)
  expect_false(anyNA(pg$projected))
})

test_that("interleaved early order still covers every unit, and 'last' is the default", {
  Lc <- data.table::data.table(district = "A", unit = c("B1", "B2", "early", "postal"),
                               booth_type = c("ordinary", "ordinary", "early", "postal"), cls = "ALP", v = c(10, 20, 30, 5))
  a <- auspol:::.night_order(Lc, 1L); b <- auspol:::.night_order(Lc, 1L, "interleaved")
  expect_identical(a, auspol:::.night_order(Lc, 1L, "last"))
  expect_setequal(b$unit, Lc$unit)
  expect_true(b$pos[b$unit == "early"] < 1)
})
