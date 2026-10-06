# Breakout mixture (AUSPOL_BREAKOUT_MIX): the simulator's mixture step and the
# time-forward classifier that feeds it. Synthetic data only.

bo_matrix <- function() {
  build_flow_matrix(data.table::data.table(
    election = "x", seat = rep(c("a","b","c"), each = 3), round = 1L,
    from = "IND", to = rep(c("ALP","LNP","GRN"), 3),
    votes = c(400,400,200, 450,350,200, 380,420,200)), min_n = 2L)
}
bo_shares <- function() {
  matrix(c(40, 38, 12, 10,
           35, 42,  8, 15,
           45, 30, 20,  5), nrow = 3, byrow = TRUE,
         dimnames = list(c("s1","s2","s3"), c("ALP","LNP","GRN","IND")))
}
strip_sim <- function(r) r[c("win_prob", "totals", "tcp_winner", "tcp_runnerup", "tcp_share", "fallback_rate")]

test_that("breakout_p NULL and an all-zero matrix are byte-identical to the old run, both engines", {
  sh <- bo_shares()
  for (eng in c("r", "cpp")) {
    a <- list(shares = sh, matrix = bo_matrix(), party_sd = c(ALP = 2, LNP = 2, GRN = 1, IND = 1),
              seat_sd = 3, n_sims = 300, seed = 7, engine = eng, keep_fp = TRUE)
    r0 <- do.call(simulate_seat_contests, a)
    r1 <- do.call(simulate_seat_contests, c(a, list(breakout_p = sh * 0, breakout_q = c(20, 40))))
    r2 <- do.call(simulate_seat_contests, c(a, list(breakout_p = NULL)))
    expect_identical(strip_sim(r0), strip_sim(r1))
    expect_identical(r0$fp_draws, r1$fp_draws)
    expect_identical(strip_sim(r0), strip_sim(r2))
    expect_identical(r1$breakout_draws, 0L)
  }
})

test_that("the compiled core reproduces the R loop with the mixture on", {
  sh <- bo_shares()
  bp <- sh * 0; bp["s1", "IND"] <- 0.3; bp["s2", "GRN"] <- 0.5; bp["s3", "IND"] <- 0.9
  a <- list(shares = sh, matrix = bo_matrix(), party_sd = c(ALP = 2, LNP = 2, GRN = 1, IND = 1),
            seat_sd = 3, n_sims = 400, seed = 11, keep_fp = TRUE, surge_h = 0.1,
            breakout_p = bp, breakout_q = seq(20, 45, length.out = 11))
  rr <- do.call(simulate_seat_contests, c(a, list(engine = "r")))
  rc <- do.call(simulate_seat_contests, c(a, list(engine = "cpp")))
  expect_identical(strip_sim(rr), strip_sim(rc))
  expect_identical(rr$fp_draws, rc$fp_draws)
  expect_identical(rr$breakout_draws, rc$breakout_draws)
  expect_gt(rr$breakout_draws, 0L)
  # and the mixture actually moves something
  r0 <- do.call(simulate_seat_contests, c(a[setdiff(names(a), c("breakout_p", "breakout_q"))], list(engine = "cpp")))
  expect_false(identical(r0$win_prob, rc$win_prob))
})

test_that("a breakout sets the share exactly, keeps the seat total, and leaves p = 0 seats untouched", {
  sh <- bo_shares()
  bp <- sh * 0; bp["s2", "IND"] <- 1
  for (eng in c("r", "cpp")) {
    r <- simulate_seat_contests(sh, bo_matrix(), party_sd = c(ALP = 0, LNP = 0, GRN = 0, IND = 0),
                                seat_sd = 0, n_sims = 20, seed = 3, keep_fp = TRUE, engine = eng,
                                breakout_p = bp, breakout_q = c(30, 30, 30))
    fp <- r$fp_draws
    # every draw sums to 100
    expect_true(all(abs(apply(fp, c(1, 2), sum) - 100) < 1e-9))
    # the broken-out cell is exactly the breakout share: only true if the
    # seat total was preserved when the others were scaled down
    expect_true(all(abs(fp[, "s2", "IND"] - 30) < 1e-9))
    # others keep their relative sizes
    expect_true(all(abs(fp[, "s2", "ALP"] / fp[, "s2", "LNP"] - 35 / 42) < 1e-9))
    # seats with p = 0 are exactly their shares
    expect_true(all(abs(fp[, "s1", ] - matrix(sh["s1", ], 20, 4, byrow = TRUE)) < 1e-9))
    expect_true(all(abs(fp[, "s3", ] - matrix(sh["s3", ], 20, 4, byrow = TRUE)) < 1e-9))
    expect_identical(r$breakout_draws, 20L)
  }
})

test_that("bad breakout inputs are refused, not silently ignored", {
  sh <- bo_shares(); fm <- bo_matrix(); psd <- c(ALP = 0, LNP = 0, GRN = 0, IND = 0)
  bp <- sh * 0; bp["s1", "IND"] <- 0.2
  expect_error(simulate_seat_contests(sh, fm, party_sd = psd, n_sims = 2, breakout_p = bp), "breakout_q")
  expect_error(simulate_seat_contests(sh, fm, party_sd = psd, n_sims = 2, breakout_p = bp * 10,
                                      breakout_q = c(20, 30)), "\\[0, 1\\]")
  bna <- bp; bna[1, 1] <- NA
  expect_error(simulate_seat_contests(sh, fm, party_sd = psd, n_sims = 2, breakout_p = bna,
                                      breakout_q = c(20, 30)), "NA is not 0")
  expect_error(simulate_seat_contests(sh, fm, party_sd = psd, n_sims = 2, breakout_p = bp[, 1:3],
                                      breakout_q = c(20, 30)), "match shares")
  expect_error(simulate_seat_contests(sh, fm, party_sd = psd, n_sims = 2, breakout_p = bp,
                                      breakout_q = c(30, 20)), "non-decreasing")
})

test_that("breakout_mix_args() is inert when the switch is off", {
  withr::local_envvar(AUSPOL_BREAKOUT_MIX = "0")
  # a target with no data anywhere: off must not read anything
  expect_identical(breakout_mix_args("nowhere1999", bo_shares()), list(p = NULL, q = NULL))
  withr::local_envvar(AUSPOL_BREAKOUT_MIX = "yes")
  expect_error(breakout_mix_args("nowhere1999", bo_shares()), "must be")
})

# A synthetic training frame: five federal elections, breakouts driven by the
# model's own prediction and the salience jump.
bo_fake_frame <- function(seed = 1) {
  set.seed(seed)
  els <- c("fed2010", "fed2013", "fed2016", "fed2019", "fed2022")
  rows <- list()
  for (e in els) for (s in sprintf("seat%02d", 1:60)) {
    jmp <- stats::rexp(2)
    xp <- c(stats::runif(1, 1, 25), stats::runif(1, 1, 10))
    act <- pmax(0, xp + 18 * (jmp > 1.5) * stats::rbinom(2, 1, 0.7) + stats::rnorm(2, 0, 2))
    rows[[length(rows) + 1L]] <- data.table::data.table(
      election = e, seat = s, party = c("ALP", "LNP", "IND", "OTH"),
      xgb_pred = c(40, 35, xp), base_pred = c(40, 35, xp), actual_share = c(40, 35, act),
      jump = c(0, 0, jmp), governed = 0L, permit = 1L, sal_present = c(0L, 0L, 1L, 1L),
      own_prev_pcv = NA_real_, seat_prev_pcv = c(40, 35, xp))
  }
  D <- data.table::rbindlist(rows)
  D[, edate := as.Date(unname(election_dates()[election]))]
  D[, named := TRUE]
  D <- auspol:::.bo_add_derived(D, NULL)
  D[, y := as.integer(actual_share >= 20)]
  D
}

test_that("breakout p is a probability and is time-forward: a later election never enters the fit", {
  withr::local_envvar(AUSPOL_BREAKOUT_CACHE_DIR = tempfile("bo-cache-"))
  clear_breakout_cache()
  Fr <- bo_fake_frame()
  invisible(utils::capture.output(p1 <- breakout_p_for("fed2016", frame = Fr, disk = FALSE)))
  expect_true(all(p1$p >= 0 & p1$p <= 1))
  expect_true(all(p1$p <= 0.5))
  expect_identical(attr(p1, "train_elections"), c("fed2010", "fed2013"))
  q1 <- breakout_share_dist("fed2016", frame = Fr)
  expect_identical(attr(q1, "elections"), c("fed2010", "fed2013"))
  # Scramble every LATER election's outcome: p and the breakout distribution
  # for fed2016 must not move.
  Fr2 <- data.table::copy(Fr)
  later <- Fr2$election %in% c("fed2019", "fed2022")
  Fr2$actual_share[later] <- rev(Fr2$actual_share[later]) + 7
  Fr2$y[later] <- 1L - Fr2$y[later]
  clear_breakout_cache()
  invisible(utils::capture.output(p2 <- breakout_p_for("fed2016", frame = Fr2, disk = FALSE)))
  expect_identical(p1$p, p2$p)
  expect_identical(as.numeric(q1), as.numeric(breakout_share_dist("fed2016", frame = Fr2)))
  # ...while changing an EARLIER one does move it (the check can fail)
  Fr3 <- data.table::copy(Fr)
  early <- Fr3$election == "fed2013"
  Fr3$y[early] <- 1L - Fr3$y[early]
  clear_breakout_cache()
  invisible(utils::capture.output(p3 <- breakout_p_for("fed2016", frame = Fr3, disk = FALSE)))
  expect_false(identical(p1$p, p3$p))
})

test_that("breakout_mix_args() puts p only on non-major cells under 15 with a share", {
  withr::local_envvar(AUSPOL_BREAKOUT_CACHE_DIR = tempfile("bo-cache-"))
  clear_breakout_cache()
  Fr <- bo_fake_frame()
  sh <- matrix(c(40, 35, 12, 13,
                 40, 35, 25,  0,
                 40, 35, 14,  11), nrow = 3, byrow = TRUE,
               dimnames = list(c("seat01", "seat02", "seat03"), c("ALP", "LNP", "IND", "OTH")))
  invisible(utils::capture.output(a <- breakout_mix_args("fed2019", sh, enabled = TRUE, frame = Fr)))
  expect_identical(dim(a$p), dim(sh))
  expect_true(all(a$p[, c("ALP", "LNP")] == 0))
  expect_identical(a$p["seat02", "IND"], 0)   # predicted 25: not a hard row
  expect_identical(a$p["seat02", "OTH"], 0)   # share 0: did not stand
  expect_true(all(a$p >= 0 & a$p <= 1))
  expect_true(all(diff(a$q) >= 0))
})
