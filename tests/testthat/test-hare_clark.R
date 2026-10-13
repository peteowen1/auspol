# Hare-Clark party-seat path (R/hare_clark.R). Synthetic inputs only; no data files.

flat_flows <- function(exh = 0) hc_flows_prior(exh)

test_that("full quotas elect, quota is floor(total / (seats + 1)) + 1", {
  # 600 votes, 5 seats: quota 101. ALP 303 = 3 quotas (+0 left), LNP 202 = 2 quotas.
  w <- hc_party_count(c(303, 202, 95), 5, c("ALP", "LNP", "GRN"), flat_flows())
  expect_equal(w, c(3L, 2L, 0L))
  expect_equal(sum(w), 5L)
})

test_that("the last seat is decided by the transfer from the excluded ticket", {
  # 6000 votes, 5 seats, quota 1001. ALP 2600 (2 quotas, 598 left), LNP 2200 (2, 198 left),
  # GRN 700, OTH 500. One seat left between ALP 598, LNP 198, GRN 700, OTH 500.
  v <- c(2600, 2200, 700, 500); cls <- c("ALP", "LNP", "GRN", "OTH")
  to_lnp <- hc_flows_prior(0); to_lnp[, ] <- 0
  to_lnp[, "LNP"] <- 1; to_lnp["LNP", ] <- 0; to_lnp["LNP", c("ALP", "GRN")] <- 0.5
  w1 <- hc_party_count(v, 5, cls, to_lnp)
  # LNP 198 is excluded first -> ALP 697, GRN 799. OTH 500 next: its only destination (LNP) is gone, so it
  # exhausts. ALP 697 < GRN 799, so ALP is excluded and GRN takes the last seat.
  expect_equal(w1, c(2L, 2L, 1L, 0L))
  # Negative control: send every exclusion to ALP and the last seat must change hands.
  to_alp <- to_lnp; to_alp[, ] <- 0; to_alp[c("LNP", "GRN", "OTH"), "ALP"] <- 1; to_alp["ALP", "GRN"] <- 1
  w2 <- hc_party_count(v, 5, cls, to_alp)
  expect_false(identical(w1, w2))
  expect_equal(w2[1], 3L)
})

test_that("a ticket cannot win more seats than it ran candidates; its excess moves on", {
  # OTH single candidate with 2.5 quotas: wins 1, the rest goes to GRN.
  fl <- hc_flows_prior(0); fl[, ] <- 0
  fl[, "GRN"] <- 1; fl["GRN", "GRN"] <- 0; fl["GRN", "ALP"] <- 1
  w <- hc_party_count(c(250, 200, 150), 5, c("OTH", "ALP", "GRN"), fl, ncand = c(1, 5, 5))
  expect_equal(w[1], 1L)
  expect_equal(sum(w), 5L)
  expect_true(w[3] >= 2L)
})

test_that("leakage moves part of an elected ticket's remainder", {
  v <- c(2600, 2200, 700, 500); cls <- c("ALP", "LNP", "GRN", "OTH")
  fl <- hc_flows_prior(0); fl["ALP", ] <- 0; fl["ALP", "GRN"] <- 1
  w0 <- hc_party_count(v, 5, cls, fl)
  w1 <- hc_party_count(v, 5, cls, fl, leak = c(ALP = 1))
  expect_equal(sum(w0), 5L); expect_equal(sum(w1), 5L)
  expect_error(hc_party_count(v, 5, cls, fl, leak = c(ALP = 2)), "leak")
})

test_that("bad inputs are refused rather than counted", {
  expect_error(hc_party_count(c(1, -1), 5, c("ALP", "LNP"), flat_flows()), "votes")
  expect_error(hc_party_count(c(1, 1), 5, c("ALP", "XYZ"), flat_flows()), "class")
  expect_error(hc_party_count(c(1, 1), 5, "ALP", flat_flows()), "unit_class")
})

test_that("ballot transfer rates are row-normalised and shrink a thin row", {
  rows <- data.frame(c1 = c("ALP", "ALP", "LNP", "GRN", "GRN", "IND"),
                     c2 = c("GRN", "EXH", "EXH", "ALP", "EXH", "LNP"),
                     n = c(800, 200, 1000, 900, 100, 3))
  f <- hc_flows_from_ballots(rows, prior_n = 50)
  expect_equal(unname(rowSums(f)), rep(1, 6), tolerance = 1e-12)
  expect_equal(unname(diag(f[1:3, 1:3])), rep(0, 3))
  # OTH has 3 ballots, all to LNP: shrinkage keeps it well away from 1
  expect_lt(f["OTH", "LNP"], 0.2)
  expect_gt(f["ALP", "GRN"], 0.7)
  # six transfer classes: the independent row is its own, and still shrunk
  f6 <- hc_flows_from_ballots(rows, prior_n = 50, fine = TRUE)
  expect_lt(f6["IND", "LNP"], 0.2)
  expect_equal(hc_flow_class(c("OTH_RIGHT", "ONP", "IND", "OTH", "ALP"), fine = TRUE), c("RGT", "RGT", "IND", "OTH", "ALP"))
  expect_equal(hc_flow_class(c("OTH_RIGHT", "IND", "GRN")), c("OTH", "OTH", "GRN"))
  lk <- hc_leak_from_ballots(data.frame(c1 = c("ALP", "LNP"), n = c(1000, 10), n_leave2 = c(100, 10)), prior_n = 50)
  expect_equal(unname(lk["ALP"]), (100 + 50 * 110 / 1010) / 1050)
  expect_lt(lk[["LNP"]], 0.5)
})

test_that("naive baseline puts its hit rate on last time's count and rescales a bigger electorate", {
  nv <- hc_naive(c(ALP = 2, LNP = 2, GRN = 1, OTH = 0), 5, hit = 0.6)
  sums <- tapply(nv$prob, nv$cls, sum)
  expect_equal(as.vector(sums), rep(1, 4), tolerance = 1e-12)
  expect_equal(nv$prob[nv$cls == "ALP" & nv$seats == 2], 0.6)
  nv7 <- hc_naive(c(ALP = 2, LNP = 2, GRN = 1, OTH = 0), 7, hit = 0.6, prev_total = 5)
  pt <- vapply(c("ALP", "LNP", "GRN", "OTH"), function(k) nv7$seats[nv7$cls == k][which.max(nv7$prob[nv7$cls == k])], 0)
  expect_equal(sum(pt), 7)
})

test_that("log loss floors at 1e-6 and reports the mode", {
  pr <- data.frame(electorate = "A", cls = "ALP", seats = 0:2, prob = c(0, 0.25, 0.75))
  a <- hc_log_loss(pr, data.frame(electorate = "A", cls = "ALP", seats_won = c(0)))
  expect_equal(a$logloss, -log(1e-6))
  b <- hc_log_loss(pr, data.frame(electorate = "A", cls = "ALP", seats_won = 2))
  expect_equal(b$logloss, -log(0.75)); expect_equal(b$mode, 2)
})

mk_units <- function() {
  # two elections of a fictional region, 2 electorates; class shares move by known amounts
  base <- data.frame(region = "tas", electorate = rep(c("A", "B"), each = 4),
                     unit = rep(c("ALP", "LNP", "GRN", "x"), 2), class = rep(c("ALP", "LNP", "GRN", "OTH"), 2),
                     ncand = 5, seats = 5L, seats_won = 1L)
  a <- base; a$year <- 2002L; a$votes <- c(400, 400, 100, 100, 400, 400, 100, 100)
  b <- base; b$year <- 2006L; b$votes <- c(450, 350, 100, 100, 350, 450, 100, 100)
  rbind(a, b)
}

test_that("noise SD is time-forward: nothing earlier gives the prior, a later pair is not seen", {
  u <- mk_units()
  s0 <- hc_noise_sd(u, as.Date("2006-03-18"), prior_sd = 3)      # the 2006 election itself: no pair before it
  expect_equal(as.vector(s0), rep(3, 4))
  s1 <- hc_noise_sd(u, as.Date("2006-03-19"), prior_sd = 3, n0 = 5)
  # deviations: ALP +5/-5 points around a zero statewide swing; LNP the mirror; GRN, OTH 0
  expect_gt(s1[["ALP"]], s1[["GRN"]])
  expect_equal(attr(s1, "n")[["ALP"]], 2L)
})

test_that("statewide fallback announces itself and centres on the previous result", {
  withr::local_options(auspol.anchor_dir = file.path(tempdir(), "no-anchor-hc"))
  prev <- c(ALP = 40, LNP = 40, GRN = 12, OTH = 8)
  out <- NULL
  expect_output(out <- hc_statewide_draws("tas", 2018L, "2018-03-03", prev,
                                          c(ALP = 2, LNP = 2, GRN = 1, OTH = 1), n_sims = 4000L, seed = 1),
                "FALLBACK -- NOT POLLS")
  expect_equal(out$source, "fallback: previous result")
  expect_equal(unname(rowSums(out$draws)), rep(100, 4000), tolerance = 1e-9)
  expect_equal(unname(colMeans(out$draws)), unname(prev), tolerance = 0.3)
})

test_that("simulation returns a proper distribution per electorate and class", {
  target <- data.frame(electorate = "A", unit = c("ALP", "LNP", "GRN", "ind"), cls = c("ALP", "LNP", "GRN", "OTH"),
                       fcls = c("ALP", "LNP", "GRN", "OTH"), ncand = c(5, 5, 5, 1), seats = 5L)
  base <- data.frame(electorate = "A", cls = c("ALP", "LNP", "GRN", "OTH"), share = c(40, 38, 14, 8))
  sd <- matrix(rep(c(40, 38, 14, 8), each = 200), 200, dimnames = list(NULL, c("ALP", "LNP", "GRN", "OTH")))
  pr <- hc_simulate(target, base, data.frame(electorate = "A", unit = "ind", share = 8), sd,
                    c(ALP = 40, LNP = 38, GRN = 14, OTH = 8), c(ALP = 2, LNP = 2, GRN = 1.5, OTH = 1.5),
                    list(p_new = 1.5, sd_log = 0.4), hc_flows_prior(0.2), seed = 3)
  expect_equal(as.vector(tapply(pr$prob, pr$cls, sum)), rep(1, 4), tolerance = 1e-12)
  # 40/38/14/8 of 5 seats: ALP and LNP 2 each most of the time
  expect_gt(pr$prob[pr$cls == "ALP" & pr$seats == 2], 0.5)
})
