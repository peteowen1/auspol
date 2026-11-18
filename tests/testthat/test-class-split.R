# Two candidates of one minor class counted separately (AUSPOL_CLASS_SPLIT).
# docs/plans/prereg-class-split-2026-11-06.md

cls_fm <- function() {
  build_flow_matrix(data.table::data.table(
    election = "x", seat = rep(c("a", "b", "c", "d"), each = 2), round = 1L,
    from = c("GRN", "GRN", "GRN", "GRN", "LNP", "LNP", "IND", "IND"),
    to = c("ALP", "LNP", "ALP", "LNP", "ALP", "GRN", "ALP", "LNP"),
    votes = c(800, 200, 780, 220, 900, 100, 400, 600)), min_n = 1L)
}
no_cs <- function(nm) { na <- stats::setNames(rep(NA_real_, length(nm)), nm); list(r = na, sd = na, f = 0) }

test_that("two independents on 19.7 + 14.6 stop beating Labor on 26.6 as one runner (Waite 2022)", {
  sh <- matrix(c(26.6, 25, 34.3, 14.1), nrow = 1, dimnames = list("Waite", c("ALP", "LNP", "IND", "GRN")))
  psd <- c(ALP = 0, LNP = 0, IND = 0, GRN = 0)
  # Greens and Liberal preferences run to the independent, as they did in Waite.
  fm <- build_flow_matrix(data.table::data.table(
    election = "x", seat = "a", round = 1L,
    from = c("GRN", "GRN", "GRN", "LNP", "LNP", "LNP", "IND", "IND", "IND", "ALP", "ALP", "ALP"),
    to = c("ALP", "IND", "LNP", "ALP", "IND", "GRN", "ALP", "LNP", "GRN", "IND", "LNP", "GRN"),
    votes = c(450, 450, 100, 150, 800, 50, 500, 400, 100, 500, 300, 200)), min_n = 1L)
  a <- simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = 0.5, n_sims = 400, seed = 1)
  cs <- c(no_cs("Waite"), list(cls = c(Waite = "IND"), cls_r = c(Waite = 14.6 / 34.3),
                               cls_sd = c(Waite = 0.02), cls_f = c(Waite = 0.3)))
  s <- simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = 0.5, n_sims = 400, seed = 1,
                              coalition_split = cs)
  pa <- sum(a$win_prob$prob[a$win_prob$party == "IND"])
  ps <- sum(s$win_prob$prob[s$win_prob$party == "IND"])
  expect_gt(pa, 0.9)
  expect_lt(ps, pa - 0.3)
  expect_equal(s$class_split$n_seats, 1L)
  expect_null(s$coalition_split)
})

test_that("the class split leaves Coalition seats and unsplit seats byte-identical, in both engines", {
  sh <- matrix(c(38, 40, 20, 2,  45, 35, 15, 5,  30, 30, 15, 25,  30, 30, 25, 15), nrow = 4, byrow = TRUE,
               dimnames = list(c("s1", "s2", "s3", "s4"), c("ALP", "LNP", "GRN", "IND")))
  args <- list(sh, cls_fm(), party_sd = c(ALP = 2, LNP = 2, GRN = 1.5, IND = 1), seat_sd = 3,
               level_sd = c(1.1, 8.67), n_sims = 300, seed = 11,
               shrink = c(s1 = 0.05, s2 = 0.01, s3 = 0.2, s4 = 0.1), surge_h = c(0.3, 0.1, 0.5, 0.2),
               surge_mu = 30, surge_sd = 8, fallback_smooth = 0.3, smooth = 0.1)
  coal <- list(r = c(s1 = NA, s2 = 0.3, s3 = NA, s4 = NA), sd = c(s1 = NA, s2 = 0.1, s3 = NA, s4 = NA), f = 0.7)
  # s2 asks for both: the Coalition split keeps it.
  both <- c(coal, list(cls = c(s1 = NA, s2 = "IND", s3 = "IND", s4 = NA),
                       cls_r = c(s1 = NA, s2 = 0.4, s3 = 0.45, s4 = NA),
                       cls_sd = c(s1 = NA, s2 = 0.1, s3 = 0.1, s4 = NA),
                       cls_f = c(s1 = NA, s2 = 0.3, s3 = 0.3, s4 = NA)))
  for (eng in c("cpp", "r")) {
    a <- do.call(simulate_seat_contests, c(args, list(engine = eng, coalition_split = coal)))
    s <- do.call(simulate_seat_contests, c(args, list(engine = eng, coalition_split = both)))
    keep <- c("s1", "s2", "s4")
    expect_identical(a$tcp_winner[, keep], s$tcp_winner[, keep])
    expect_identical(a$tcp_share[, keep], s$tcp_share[, keep])
    expect_false(identical(a$tcp_share[, "s3"], s$tcp_share[, "s3"]))
    expect_equal(s$class_split$n_seats, 1L)
    expect_equal(s$class_split$skipped_coalition, 1L)
  }
})

test_that("the compiled core is byte-identical to the R engine with the class split on", {
  sh <- matrix(c(38, 40, 10, 12,  45, 35, 15, 5,  30, 30, 15, 25), nrow = 3, byrow = TRUE,
               dimnames = list(c("s1", "s2", "s3"), c("ALP", "LNP", "GRN", "IND")))
  cs <- list(r = c(s1 = 0.2, s2 = NA, s3 = NA), sd = c(s1 = 0.1, s2 = NA, s3 = NA), f = 0.7,
             cls = c(s1 = NA, s2 = "IND", s3 = "IND"), cls_r = c(s1 = NA, s2 = 0.3, s3 = 0.45),
             cls_sd = c(s1 = NA, s2 = 0.1, s3 = 0.15), cls_f = c(s1 = NA, s2 = 0.2, s3 = 0.4))
  args <- list(sh, cls_fm(), party_sd = c(ALP = 2, LNP = 2, GRN = 1.5, IND = 1), seat_sd = 3,
               level_sd = c(1.1, 8.67), n_sims = 300, seed = 5,
               shrink = c(s1 = 0.05, s2 = 0.3, s3 = 0.2), surge_h = c(0.3, 0.1, 0.5),
               surge_mu = 30, surge_sd = 8, flow_sd = 3, fallback_smooth = 0.3, smooth = 0.1,
               coalition_split = cs)
  strip <- function(x) { x$engine <- NULL; x }
  r <- do.call(simulate_seat_contests, c(args, list(engine = "r")))
  cc <- do.call(simulate_seat_contests, c(args, list(engine = "cpp")))
  expect_identical(strip(cc), strip(r))
  expect_equal(r$class_split$n_seats, 2L)
  expect_equal(r$coalition_split$n_seats, 1L)
})

test_that("a class with no column in the simulation is skipped and counted, not split", {
  sh <- matrix(c(40, 40, 20), nrow = 1, dimnames = list("x", c("ALP", "LNP", "IND")))
  cs <- c(no_cs("x"), list(cls = c(x = "OTH_RIGHT"), cls_r = c(x = 0.4), cls_sd = c(x = 0.1), cls_f = c(x = 0.3)))
  s <- simulate_seat_contests(sh, cls_fm(), party_sd = c(ALP = 0, LNP = 0, IND = 0), n_sims = 20, seed = 1,
                              coalition_split = cs)
  expect_equal(s$class_split$n_seats, 0L)
  expect_equal(s$class_split$skipped_no_column, 1L)
})

test_that("malformed class split is refused", {
  sh <- matrix(c(40, 40, 20), nrow = 1, dimnames = list("x", c("ALP", "LNP", "IND")))
  sim <- function(extra) simulate_seat_contests(sh, cls_fm(), party_sd = c(ALP = 0, LNP = 0, IND = 0),
                                                n_sims = 10, seed = 1, coalition_split = c(no_cs("x"), extra))
  expect_error(sim(list(cls = c(x = "IND"), cls_r = c(x = 0.6 + 0.5), cls_sd = c(x = 0.1), cls_f = c(x = 0.3))), "cls_r")
  expect_error(sim(list(cls = c(x = "IND"), cls_r = c(x = 0.4), cls_sd = c(x = 0.1), cls_f = c(x = 2))), "cls_f")
  expect_error(sim(list(cls = c(y = "IND"), cls_r = c(y = 0.4), cls_sd = c(y = 0.1), cls_f = c(y = 0.3))), "no entry")
})

test_that("class_split_fit takes r from the predictions and sd and f from earlier elections only", {
  oof <- data.table::data.table(
    election = c(rep(c("sa2014", "sa2018"), each = 6), rep("sa2022", 2)),
    seat = c(rep(paste0("s", 1:3), each = 2), rep(paste0("s", 1:3), each = 2), "w", "w"),
    cls = "IND",
    share = c(10, 5, 8, 8, 12, 3,  9, 6, 7, 7, 11, 4,  999, 999),
    pred_xgb = c(9, 6, 8, 7, 10, 4,  9, 5, 8, 6, 12, 3,  24.8, 4.3))
  tx <- data.table::data.table(election = c("sa2018", "sa2018", "sa2022"), seat = "s1", round = 1L,
                               from = "IND", to = c("IND", "ALP", "IND"), votes = c(300, 700, 1e6))
  fit <- class_split_fit("sa2022", oof = oof, transfers = tx)
  expect_equal(fit$seats$seat, "w")
  expect_equal(fit$seats$r, 4.3 / (24.8 + 4.3))
  # sa2022's own transfer row (1e6 to IND) and shares (999) are never read.
  expect_equal(unname(fit$f[["IND"]]), 0.3)
  hist_r <- c(6 / 15, 7 / 15, 4 / 14, 5 / 14, 6 / 14, 3 / 15)
  hist_a <- c(5 / 15, 8 / 16, 3 / 15, 6 / 15, 7 / 14, 4 / 15)
  expect_equal(fit$sd, sqrt(mean((hist_a - hist_r)^2)))
})

test_that("points mode sizes the junior as (points + b x class) over the run's own class share", {
  sh <- matrix(c(26.6, 25, 34.3, 14.1), nrow = 1, dimnames = list("Waite", c("ALP", "LNP", "IND", "GRN")))
  psd <- c(ALP = 0, LNP = 0, IND = 0, GRN = 0)
  fm <- cls_fm()
  base <- c(no_cs("Waite"), list(cls = c(Waite = "IND"), cls_sd = c(Waite = 0.02), cls_f = c(Waite = 0.3)))
  frac <- simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = 0.5, n_sims = 300, seed = 3,
                                 coalition_split = c(base, list(cls_r = c(Waite = 0.25))))
  # 5.145 + 0.1 x 34.3 = 8.575 points of 34.3 is the same 0.25
  pts <- simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = 0.5, n_sims = 300, seed = 3,
                                coalition_split = c(base, list(cls_r = c(Waite = NA_real_), cls_pts = c(Waite = 5.145),
                                                               cls_pts_b = c(Waite = 0.1))))
  expect_equal(pts$win_prob, frac$win_prob)
  expect_equal(pts$class_split$n_seats, 1L)
  # with no points the seat is not split at all
  none <- simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = 0.5, n_sims = 300, seed = 3,
                                 coalition_split = c(base, list(cls_r = c(Waite = NA_real_), cls_pts = c(Waite = NA_real_))))
  expect_equal(none$class_split$n_seats, 0L)
  expect_equal(none$win_prob, simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = 0.5, n_sims = 300, seed = 3)$win_prob)
})

test_that("class_split_fit_pts fits on earlier elections only and orders by carried vote", {
  mk <- function(el, yr, seat, nm, sh, cred, prior = NA_real_, oc = 30) data.table::data.table(
    election = el, year = yr, seat = seat, name = nm, cls = "IND", share = sh, cred = cred,
    prior_nonmajor = prior, prior_same_seat = FALSE, n_ind = 2L, our_cls = oc)
  # earlier election: every leader carried exactly half of an earlier vote in ANOTHER seat (carry 0.5); councillor
  # juniors poll about 6, uncredentialed ones about 2, so the credential cells really differ (tau^2 > 0)
  hist <- data.table::rbindlist(lapply(1:12, function(i) rbind(
    mk("x2010", 2010L, paste0("s", i), "A", 20 + i, "prior5", prior = 2 * (20 + i), oc = 25 + i),
    mk("x2010", 2010L, paste0("s", i), "B", if (i %% 2) 6 + (i %% 3) / 3 else 2 + (i %% 3) / 3,
       if (i %% 2) "councillor" else "none", oc = 25 + i))))
  # a LATER election with absurd juniors and an absurd carry (50 from an earlier 1) must not move the x2014 fit
  later <- data.table::rbindlist(lapply(1:12, function(i) rbind(
    mk("x2018", 2018L, paste0("s", i), "A", 50, "prior5", prior = 1), mk("x2018", 2018L, paste0("s", i), "B", 19, "none"))))
  tgt <- rbind(mk("x2014", 2014L, "t", "Known", NA, "prior5", prior = 20), mk("x2014", 2014L, "t", "Coun", NA, "councillor"),
               mk("x2014", 2014L, "t", "New", NA, "none"))
  tx <- data.table::data.table(election = "x2010", seat = "s1", round = 1L, from = "IND", to = c("IND", "ALP"), votes = c(30, 70))
  a <- class_split_fit_pts("x2014", "pts_carry", cand = rbind(hist, tgt), transfers = tx)
  b <- class_split_fit_pts("x2014", "pts_carry", cand = rbind(hist, later, tgt), transfers = tx)
  expect_equal(unname(a$carry), c(0.5, 0.5))          # no same-seat case: "same" takes the pooled 0.5
  expect_equal(a$carry, b$carry)
  expect_equal(a$pts, b$pts)
  expect_equal(a$seats$pts, b$seats$pts)
  expect_gt(unname(a$pts["councillor"]), unname(a$pts["none"]) + 1)
  # Known expects 0.5 x 20 = 10 with no class term and leads; the junior is the councillor (slope b)
  expect_equal(nrow(a$seats), 1L)
  expect_equal(a$seats$pts_b, a$b)
  expect_equal(a$seats$pts, unname(a$pts["councillor"]))
  # under pts_cred the carried vote is ignored: Known is just a prior5 credential
  k <- class_split_fit_pts("x2014", "pts_cred", cand = rbind(hist, tgt), transfers = tx)
  expect_true(all(is.na(k$carry)))
  expect_error(class_split_fit_pts("x2014", "pred", cand = hist), "pts_cred or pts_carry")
})

test_that("points mode counts a class with no column as skipped, as the fraction mode does", {
  sh <- matrix(c(40, 40, 20), nrow = 1, dimnames = list("x", c("ALP", "LNP", "IND")))
  cs <- c(no_cs("x"), list(cls = c(x = "OTH_RIGHT"), cls_r = c(x = NA_real_), cls_sd = c(x = 0.1), cls_f = c(x = 0.3),
                           cls_pts = c(x = 2), cls_pts_b = c(x = 0.1)))
  s <- simulate_seat_contests(sh, cls_fm(), party_sd = c(ALP = 0, LNP = 0, IND = 0), n_sims = 20, seed = 1,
                              coalition_split = cs)
  expect_equal(s$class_split$n_seats, 0L)
  expect_equal(s$class_split$skipped_no_column, 1L)
})

test_that("class_split_args reads a frozen fit with no transfers or candidate files (the daily run's case)", {
  root <- file.path(tempdir(), "cls-frozen"); dir.create(file.path(root, "output"), recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(root, "DESCRIPTION"))
  fz <- data.table::data.table(mode = c("pts_carry", "pts_carry", "pts_cred"), sd_mode = "pooled", seat = c("A", "B", "A"), cls = "IND",
                               r = NA_real_, pts = c(2.6, 1.1, 1.1), pts_b = 0.09, sd = 0.15, f = 0.44, n_cand = 2L,
                               n_hist = 400L, b = 0.09, carry_same = c(0.8, 0.8, NA), carry_other = c(0.58, 0.58, NA),
                               i_none = 1.1, i_MP = 1.6, i_prior5 = 1.8, i_councillor = 2.6)
  data.table::fwrite(fz, file.path(root, "output", "ind-split-fit-x2026.csv"))
  withr::local_options(auspol.root = root)
  withr::local_envvar(AUSPOL_CLASS_SPLIT = "1", AUSPOL_CLASS_SPLIT_MODE = "pts_carry")
  out <- capture.output(a <- class_split_args("x2026", c("A", "B", "C")))
  expect_equal(unname(a$cls_pts[c("A", "B")]), c(2.6, 1.1))   # only the pts_carry rows, not pts_cred's 1.1 for A
  expect_true(is.na(a$cls_pts["C"]))
  expect_true(any(grepl("frozen fit", out)))
  # a frozen fit built for another spread setting is refused, not used
  rm(list = ls(envir = .cls_cache), envir = .cls_cache)
  withr::local_envvar(AUSPOL_CLASS_SPLIT_SD = "by_junior")
  expect_error(class_split_args("x2026", c("A", "B")), "built for spread pooled")
})

test_that("the cred2 gate splits only seats with 2+ credentialed independents, and refuses what it cannot gate", {
  root <- file.path(tempdir(), "cls-gate"); dir.create(file.path(root, "output"), recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(root, "DESCRIPTION"))
  fz <- data.table::data.table(mode = "pts_carry", sd_mode = "pooled", seat = c("A", "B", "C"), cls = "IND",
                               r = NA_real_, pts = c(2.6, 1.1, 4.0), pts_b = 0.09, sd = 0.15, f = 0.44, n_cand = c(3L, 2L, 2L),
                               n_cred = c(2L, 1L, 0L), n_hist = 400L, b = 0.09, carry_same = 0.8, carry_other = 0.58,
                               i_none = 1.1, i_MP = 1.6, i_prior5 = 1.8, i_councillor = 2.6)
  data.table::fwrite(fz, file.path(root, "output", "ind-split-fit-x2026.csv"))
  withr::local_options(auspol.root = root)
  withr::local_envvar(AUSPOL_CLASS_SPLIT = "1", AUSPOL_CLASS_SPLIT_MODE = "pts_carry", AUSPOL_CLASS_SPLIT_SD = "pooled")
  rm(list = ls(envir = .cls_cache), envir = .cls_cache)
  # ungated: all three seats split
  capture.output(a0 <- class_split_args("x2026", c("A", "B", "C")))
  expect_equal(sum(is.finite(a0$cls_pts)), 3L)
  # gated: only A (two credentialed independents); B and C keep one class
  withr::local_envvar(AUSPOL_CLASS_SPLIT_GATE = "cred2")
  out <- capture.output(a <- class_split_args("x2026", c("A", "B", "C")))
  expect_equal(unname(a$cls_pts["A"]), 2.6)
  expect_true(all(is.na(a$cls_pts[c("B", "C")])))
  expect_true(all(is.na(a$cls[c("B", "C")])))
  expect_true(any(grepl("CLS3 .* 1 of 3 seats kept", out)))
  # no seat passes: no split at all
  capture.output(n <- class_split_args("x2026", c("B", "C")))
  expect_null(n)
  # a frozen fit without n_cred cannot be gated: refused, never silently ungated
  data.table::fwrite(fz[, !"n_cred"], file.path(root, "output", "ind-split-fit-x2026.csv"))
  Sys.setFileTime(file.path(root, "output", "ind-split-fit-x2026.csv"), Sys.time() + 5)
  rm(list = ls(envir = .cls_cache), envir = .cls_cache)
  expect_error(class_split_args("x2026", c("A", "B")), "no n_cred column")
  # the fraction mode has no credentials: the gate is refused there
  withr::local_envvar(AUSPOL_CLASS_SPLIT_MODE = "pred")
  expect_error(class_split_gate_check <- class_split_args("x2026", c("A")), "needs a points mode|needs")
  withr::local_envvar(AUSPOL_CLASS_SPLIT_GATE = "bogus")
  expect_error(class_split_gate(), "must be")
})

test_that("class_split_fit_pts counts each seat's credentialed independents", {
  mk <- function(el, yr, seat, nm, sh, cred, oc = 30) data.table::data.table(
    election = el, year = yr, seat = seat, name = nm, cls = "IND", share = sh, cred = cred,
    prior_nonmajor = NA_real_, prior_same_seat = FALSE, n_ind = 2L, our_cls = oc)
  hist <- data.table::rbindlist(lapply(1:12, function(i) rbind(
    mk("x2010", 2010L, paste0("s", i), "A", 20 + i, "MP", oc = 25 + i),
    mk("x2010", 2010L, paste0("s", i), "B", if (i %% 2) 6 else 2, if (i %% 2) "councillor" else "none", oc = 25 + i))))
  tgt <- rbind(mk("x2014", 2014L, "two", "P", NA, "MP"), mk("x2014", 2014L, "two", "Q", NA, "councillor"),
               mk("x2014", 2014L, "two", "R", NA, "none"),
               mk("x2014", 2014L, "one", "S", NA, "MP"), mk("x2014", 2014L, "one", "T", NA, "none"))
  tx <- data.table::data.table(election = "x2010", seat = "s1", round = 1L, from = "IND", to = c("IND", "ALP"), votes = c(30, 70))
  a <- class_split_fit_pts("x2014", "pts_cred", cand = rbind(hist, tgt), transfers = tx)
  expect_equal(a$seats$n_cred[match(c("two", "one"), a$seats$seat)], c(2L, 1L))
})

test_that("by_junior spread is the class-weighted RMSE per junior group, pooled under 5 seats", {
  mk <- function(el, yr, seat, nm, sh, cred, oc) data.table::data.table(
    election = el, year = yr, seat = seat, name = nm, cls = "IND", share = sh, cred = cred,
    prior_nonmajor = NA_real_, prior_same_seat = FALSE, n_ind = 2L, our_cls = oc)
  # 12 seats with an uncredentialed junior, 3 with a councillor junior (under 5: takes the pooled value)
  hist <- data.table::rbindlist(c(
    lapply(1:12, function(i) rbind(mk("x2010", 2010L, paste0("n", i), "A", 20, "none", 10 + 2 * i),
                                   mk("x2010", 2010L, paste0("n", i), "B", 1 + (i %% 4), "none", 10 + 2 * i))),
    lapply(1:3, function(i) rbind(mk("x2010", 2010L, paste0("c", i), "A", 20, "none", 30),
                                  mk("x2010", 2010L, paste0("c", i), "B", 9, "councillor", 30)))))
  tgt <- rbind(mk("x2014", 2014L, "t1", "P", NA, "none", NA), mk("x2014", 2014L, "t1", "Q", NA, "none", NA),
               mk("x2014", 2014L, "t2", "R", NA, "none", NA), mk("x2014", 2014L, "t2", "S", NA, "councillor", NA))
  tx <- data.table::data.table(election = "x2010", seat = "n1", round = 1L, from = "IND", to = c("IND", "ALP"), votes = c(30, 70))
  withr::local_envvar(AUSPOL_CLASS_SPLIT_SD = "pooled")
  p <- class_split_fit_pts("x2014", "pts_cred", cand = rbind(hist, tgt), transfers = tx)
  withr::local_envvar(AUSPOL_CLASS_SPLIT_SD = "by_junior")
  j <- class_split_fit_pts("x2014", "pts_cred", cand = rbind(hist, tgt), transfers = tx)
  # recompute the none group's weighted RMSE by hand from the same fitted points. In the c seats the councillor is
  # EXPECTED to lead, so their junior (by expectation) is the uncredentialed A: all 15 seats are in the none group,
  # the credentialed group is empty and takes the pooled value.
  hn <- hist[, .(r_act = min(share) / sum(share), oc = our_cls[1]), by = seat]
  r_hat <- pmin(pmax((unname(j$pts["none"]) + j$b * hn$oc) / hn$oc, 0.01), 0.5)
  expect_equal(unname(j$sd_junior["none"]), sqrt(sum(hn$oc * (hn$r_act - r_hat)^2) / sum(hn$oc)))
  expect_equal(unname(j$sd_junior["cred"]), p$sd)          # no seats: falls back to pooled
  expect_false(isTRUE(all.equal(unname(j$sd_junior["none"]), p$sd)))
  expect_equal(j$seats$sd[j$seats$seat == "t1"], unname(j$sd_junior["none"]))
})
