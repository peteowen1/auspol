# A Liberal and a National in one seat, counted as two candidates.
# docs/plans/prereg-lib-nat-two-candidates-2026-10-16.md

split_fm <- function() {
  build_flow_matrix(data.table::data.table(
    election = "x", seat = rep(c("a", "b", "c", "d"), each = 2), round = 1L,
    from = c("GRN", "GRN", "GRN", "GRN", "LNP", "LNP", "IND", "IND"),
    to = c("ALP", "LNP", "ALP", "LNP", "ALP", "GRN", "ALP", "LNP"),
    votes = c(800, 200, 780, 220, 900, 100, 400, 600)), min_n = 1L)
}

test_that("a split Coalition vote can lose a seat the combined vote wins (Albany 2013)", {
  sh <- matrix(c(39.3, 49.5, 11.2), nrow = 1, dimnames = list("Albany", c("ALP", "LNP", "GRN")))
  a <- simulate_seat_contests(sh, split_fm(), party_sd = c(ALP = 0, LNP = 0, GRN = 0),
                              seat_sd = 0.5, n_sims = 400, seed = 1)
  s <- simulate_seat_contests(sh, split_fm(), party_sd = c(ALP = 0, LNP = 0, GRN = 0),
                              seat_sd = 0.5, n_sims = 400, seed = 1,
                              coalition_split = list(r = c(Albany = 0.4), sd = c(Albany = 0.03), f = 0.712))
  pa <- sum(a$win_prob$prob[a$win_prob$party == "LNP"])
  ps <- sum(s$win_prob$prob[s$win_prob$party == "LNP"])
  expect_gt(pa, 0.95)
  expect_lt(ps, 0.05)
  expect_equal(s$coalition_split$n_seats, 1L)
  expect_false("LNP2" %in% colnames(s$totals))
})

test_that("f = 1 with a tiny junior is the one-candidate count", {
  sh <- matrix(c(39.3, 49.5, 11.2), nrow = 1, dimnames = list("x", c("ALP", "LNP", "GRN")))
  s <- simulate_seat_contests(sh, split_fm(), party_sd = c(ALP = 0, LNP = 0, GRN = 0),
                              seat_sd = 0.5, n_sims = 200, seed = 2,
                              coalition_split = list(r = c(x = 0.02), sd = c(x = 0), f = 1))
  expect_equal(sum(s$win_prob$prob[s$win_prob$party == "LNP"]), 1)
})

test_that("seats without a split are byte-identical with the split on (no flow noise)", {
  sh <- matrix(c(38, 40, 20, 2,  45, 35, 15, 5,  30, 45, 15, 10,  30, 30, 25, 15), nrow = 4, byrow = TRUE,
               dimnames = list(c("s1", "s2", "s3", "s4"), c("ALP", "LNP", "GRN", "IND")))
  args <- list(sh, split_fm(), party_sd = c(ALP = 2, LNP = 2, GRN = 1.5, IND = 1), seat_sd = 3,
               level_sd = c(1.1, 8.67), n_sims = 300, seed = 11,
               shrink = c(s1 = 0.05, s2 = 0.01, s3 = 0.2, s4 = 0.1), surge_h = c(0.3, 0.1, 0.5, 0.2),
               surge_mu = 30, surge_sd = 8, fallback_smooth = 0.3, smooth = 0.1)
  cs <- list(r = c(s1 = NA, s2 = 0.3, s3 = 0.45, s4 = NA), sd = c(s1 = NA, s2 = 0.1, s3 = 0.05, s4 = NA), f = 0.7)
  for (eng in c("cpp", "r")) {
    a <- do.call(simulate_seat_contests, c(args, list(engine = eng)))
    s <- do.call(simulate_seat_contests, c(args, list(engine = eng, coalition_split = cs)))
    keep <- c("s1", "s4")
    expect_identical(a$tcp_winner[, keep], s$tcp_winner[, keep])
    expect_identical(a$tcp_share[, keep], s$tcp_share[, keep])
    wa <- a$win_prob[a$win_prob$seat %in% keep, ]; ws <- s$win_prob[s$win_prob$seat %in% keep, ]
    rownames(wa) <- NULL; rownames(ws) <- NULL
    expect_identical(wa, ws)
    # ...and the split seats did move.
    expect_false(identical(a$tcp_share[, "s3"], s$tcp_share[, "s3"]))
  }
})

test_that("the compiled core is byte-identical to the R engine with the split on", {
  sh <- matrix(c(38, 40, 20, 2,  45, 35, 15, 5,  30, 45, 15, 10), nrow = 3, byrow = TRUE,
               dimnames = list(c("s1", "s2", "s3"), c("ALP", "LNP", "GRN", "IND")))
  args <- list(sh, split_fm(), party_sd = c(ALP = 2, LNP = 2, GRN = 1.5, IND = 1), seat_sd = 3,
               level_sd = c(1.1, 8.67), n_sims = 300, seed = 5,
               shrink = c(s1 = 0.05, s2 = 0.3, s3 = 0.2), surge_h = c(0.3, 0.1, 0.5),
               surge_mu = 30, surge_sd = 8, flow_sd = 3, fallback_smooth = 0.3, smooth = 0.1,
               coalition_split = list(r = c(s1 = 0.2, s2 = NA, s3 = 0.45), sd = c(s1 = 0.1, s2 = NA, s3 = 0.15), f = 0.7))
  strip <- function(x) { x$engine <- NULL; x }
  r <- do.call(simulate_seat_contests, c(args, list(engine = "r")))
  cc <- do.call(simulate_seat_contests, c(args, list(engine = "cpp")))
  expect_identical(strip(cc), strip(r))
  expect_equal(r$coalition_split$n_seats, 2L)
})

test_that("malformed coalition_split is refused, not ignored", {
  sh <- matrix(c(40, 60), nrow = 1, dimnames = list("x", c("ALP", "LNP")))
  sim <- function(cs) simulate_seat_contests(sh, split_fm(), party_sd = c(ALP = 0, LNP = 0),
                                             n_sims = 10, seed = 1, coalition_split = cs)
  expect_error(sim(list(r = c(x = 0.3), sd = c(x = 0.1))), "r, sd and f")
  expect_error(sim(list(r = c(y = 0.3), sd = c(y = 0.1), f = 0.7)), "no entry")
  expect_error(sim(list(r = c(x = 1.2), sd = c(x = 0.1), f = 0.7)), "\\(0, 1\\)")
  expect_error(sim(list(r = c(x = 0.3), sd = c(x = 0.1), f = 1.5)), "\\[0, 1\\]")
  sh2 <- matrix(c(40, 60), nrow = 1, dimnames = list("x", c("ALP", "NAT")))
  expect_error(simulate_seat_contests(sh2, split_fm(), party_sd = c(ALP = 0, NAT = 0), n_sims = 10,
                                      coalition_split = list(r = c(x = 0.3), sd = c(x = 0.1), f = 0.7)),
               "LNP share column")
})

test_that("coalition_side reads the raw labels", {
  expect_equal(coalition_side(c("Liberal", "The Nationals", "NAT", "Liberal National Party of Queensland",
                                "Country Liberals", "LIB", "National Party of Australia - NSW",
                                "Liberal Democrats", "NP")),
               c("LIB", "NAT", "NAT", NA, NA, "LIB", "NAT", NA, "NAT"))
})

test_that("coalition_split_fit uses only earlier years", {
  mk <- function(el, seat, lib, nat) data.table::data.table(
    election = el, seat = seat, party = "LNP", party_raw = c("Liberal", "The Nationals"),
    name = paste(seat, c("Lib", "Nat")), pcv = c(lib, nat), votes = 1000 * c(lib, nat),
    elected = c(lib > nat, nat > lib))
  seats <- c("A", "B", "C", "D")
  cand <- data.table::rbindlist(c(
    Map(mk, "wa2005", seats, c(30, 25, 35, 20), c(10, 20, 3, 25)),
    Map(mk, "wa2008", seats, c(32, 20, 36, 18), c(12, 22, 2, 28)),
    list(mk("wa2013", "A", 5, 45))))   # the target's own votes must not be read
  tx <- data.table::data.table(election = c("wa2008", "wa2008", "wa2013", "wa2013"), seat = "A", round = 1L,
                               from = "LNP", to = c("LNP", "ALP", "LNP", "ALP"), votes = c(70, 30, 10, 90))
  fit <- coalition_split_fit("wa2013", cand = cand, transfers = tx)
  expect_equal(as.numeric(fit$f), 0.7)   # "state" (the shipped default) carries raw/n/w attributes
  expect_equal(fit$n_hist, 8L)
  expect_equal(fit$seats$seat, "A")
  expect_true(fit$seats$has_prev)
  expect_true(fit$seats$r > 0 && fit$seats$r < 0.5)
  # the target's own votes do not move the prediction
  cand2 <- data.table::copy(cand); cand2[cand2$election == "wa2013", "pcv" := c(40, 2)]
  expect_identical(coalition_split_fit("wa2013", cand = cand2, transfers = tx)$seats,
                   fit$seats)
  # with nothing earlier, nothing is applied
  expect_true(is.na(coalition_split_fit("wa2005", cand = cand, transfers = tx)$f))
  # the fit runs inside the simulator call, after its seed: it must draw nothing
  set.seed(9); before <- .Random.seed
  coalition_split_fit("wa2013", cand = cand, transfers = tx)
  expect_identical(.Random.seed, before)
})

test_that("coalition_f shrinks a jurisdiction's rate toward the pooled one", {
  ev <- data.table::data.table(election = rep(c("vic2010", "wa2013", "fed2016"), c(20, 40, 40)),
                               tot = 100, to_lnp = c(rep(85, 20), rep(65, 40), rep(70, 40)) + rep(c(-5, 5), 50))
  fp <- coalition_f(ev, "vic", "pooled")
  expect_equal(fp, sum(ev$to_lnp) / sum(ev$tot))
  fv <- coalition_f(ev, "vic", "state")
  expect_true(fv > fp && fv < 0.85)                  # between pooled and its own rate
  expect_equal(attr(fv, "raw"), 0.85)
  expect_equal(as.numeric(coalition_f(ev, "sa", "state")), fp)   # no earlier exclusion: pooled
  # identical rates everywhere: nothing to shrink toward, weight 0
  ev2 <- data.table::data.table(election = rep(c("vic2010", "wa2013"), each = 10), tot = 100, to_lnp = 70 + rep(c(-5, 5), 10))
  expect_equal(attr(coalition_f(ev2, "vic", "state"), "w"), 0)
  expect_error(coalition_f(ev, "vic", "bogus"))
})
