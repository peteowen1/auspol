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
