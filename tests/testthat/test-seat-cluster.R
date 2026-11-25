# SEAT CLUSTER FACTOR (AUSPOL_SEAT_CLUSTER_COR, R/seat_cluster.R). Synthetic seats only, no
# external/ files: the clusters are passed in directly.

clu_fixture <- function() {
  sh <- matrix(c(45, 45, 10,  50, 42, 8,  40, 48, 12,
                 47, 43, 10,  44, 46, 10, 52, 40, 8), nrow = 6, byrow = TRUE,
               dimnames = list(paste0("s", 1:6), c("ALP", "LNP", "GRN")))
  fm <- build_flow_matrix(data.table::data.table(
    election = "x", seat = rep(c("a", "b", "c"), each = 2), round = 1L,
    from = "GRN", to = rep(c("ALP", "LNP"), 3),
    votes = c(900, 100, 850, 150, 800, 200)), min_n = 2L)
  list(sh = sh, fm = fm, cl = c(1L, 1L, 1L, 2L, 2L, NA))
}
strip_engine <- function(x) { x$engine <- NULL; x }

test_that("the switch off (NULL, all-zero rho, or no seat in a cluster) is the old run byte for byte", {
  f <- clu_fixture()
  run <- function(...) simulate_seat_contests(f$sh, f$fm, party_sd = c(ALP = 2, LNP = 2, GRN = 1),
                                              level_sd = c(1.1, 8.67), n_sims = 400, seed = 5, ...)
  base <- run()
  expect_identical(run(seat_cluster = NULL, cluster_rho = NULL), base)
  expect_identical(run(seat_cluster = f$cl, cluster_rho = c(ALP = 0, LNP = 0, GRN = 0)), base)
  expect_identical(run(seat_cluster = rep(NA_integer_, 6), cluster_rho = c(ALP = 0.4)), base)
  on <- run(seat_cluster = f$cl, cluster_rho = c(ALP = 0.4, LNP = 0.4))
  expect_false(identical(on$totals, base$totals))          # the mechanism actually ran
  expect_identical(seat_cluster_setup("vic2022", f$sh), list(seat_cluster = NULL, cluster_rho = NULL))  # switch unset
})

test_that("the compiled core and the R loop agree byte for byte with the cluster term on", {
  f <- clu_fixture()
  args <- list(f$sh, f$fm, party_sd = c(ALP = 2, LNP = 2, GRN = 1), level_sd = c(1.1, 8.67), n_sims = 300,
               seed = 9, shrink = 0.02, flow_sd = 2, seat_cluster = f$cl, cluster_rho = c(ALP = 0.3, LNP = 0.5, GRN = 0.2))
  r <- do.call(simulate_seat_contests, c(args, list(engine = "r")))
  cc <- do.call(simulate_seat_contests, c(args, list(engine = "cpp")))
  expect_identical(cc$engine, "cpp")
  expect_identical(strip_engine(cc), strip_engine(r))
})

test_that("the split preserves every cell's sd, couples seats in a cluster only, and the check can fail", {
  f <- clu_fixture()
  N <- 20000
  run <- function(rho, sdo = NULL) simulate_seat_contests(f$sh, f$fm, party_sd = c(ALP = 0, LNP = 0, GRN = 0),
    level_sd = c(1.1, 8.67), sd_override = sdo, n_sims = N, seed = 21, keep_fp = TRUE,
    seat_cluster = if (rho > 0) f$cl else NULL, cluster_rho = if (rho > 0) c(ALP = rho, LNP = rho, GRN = rho) else NULL)
  off <- run(0); on <- run(0.5)
  sdr <- apply(on$fp_draws, c(2, 3), stats::sd) / apply(off$fp_draws, c(2, 3), stats::sd)
  # each (seat, class) marginal sd unchanged: MC error of an sd ratio at N = 20,000 is ~1%
  expect_true(all(abs(sdr - 1) < 0.04), info = paste(round(sdr, 3), collapse = " "))
  # seats 1-3 share cluster 1, seat 4 is cluster 2, seat 6 has none
  cr <- function(x, i, j) stats::cor(x$fp_draws[, i, 1], x$fp_draws[, j, 1])
  expect_lt(abs(cr(off, 1, 2)), 0.03)
  expect_gt(cr(on, 1, 2), 0.25)                 # same cluster: correlated
  expect_lt(abs(cr(on, 1, 4)), 0.03)            # different clusters: not
  expect_lt(abs(cr(on, 1, 6)), 0.03)            # no cluster: not
  # seat totals spread out
  expect_gt(stats::sd(on$totals[, "ALP"]), 1.08 * stats::sd(off$totals[, "ALP"]))
  # and the marginal check above is a real check: a variance-ADDING version (each cell's sd
  # times sqrt(1 + rho), what forgetting to shrink the own part would do) fails it
  pp <- f$sh / 100; lsd <- 1.1 + 8.67 * sqrt(pp * (1 - pp))
  bad <- run(0, sdo = lsd * sqrt(1.5))
  sdr_bad <- apply(bad$fp_draws, c(2, 3), stats::sd) / apply(off$fp_draws, c(2, 3), stats::sd)
  expect_false(all(abs(sdr_bad - 1) < 0.04))
})

test_that("bad cluster input is refused, not ignored", {
  f <- clu_fixture()
  run <- function(...) simulate_seat_contests(f$sh, f$fm, party_sd = c(ALP = 2, LNP = 2, GRN = 1),
                                              level_sd = c(1.1, 8.67), n_sims = 50, seed = 1, ...)
  expect_error(run(seat_cluster = f$cl), "go together")
  expect_error(run(seat_cluster = f$cl[1:3], cluster_rho = c(ALP = 0.2)), "one entry per seat")
  expect_error(run(seat_cluster = f$cl, cluster_rho = c(ONP = 0.2)), "not a column")
  expect_error(run(seat_cluster = f$cl, cluster_rho = c(ALP = 1)), "\\[0, 1\\)")
  expect_error(simulate_seat_contests(f$sh, f$fm, party_sd = c(ALP = 2, LNP = 2, GRN = 1), n_sims = 50,
                                      seat_cluster = f$cl, cluster_rho = c(ALP = 0.2)), "needs level_sd")
})

test_that("the intraclass correlation estimator recovers a known value and the rho pool is time-forward", {
  set.seed(4)
  g <- rep(1:300, each = 8)
  y <- rnorm(300, 0, sqrt(0.3))[g] + rnorm(2400, 0, sqrt(0.7))
  expect_equal(seat_cluster_icc1(y, g), 0.3, tolerance = 0.15)   # SE ~0.03 at 300 clusters
  expect_lt(abs(seat_cluster_icc1(rnorm(2400), g)), 0.06)
  tab <- data.frame(election = c("vic2010", "vic2010", "vic2014", "vic2014", "fed2010", "vic2022"),
                    party = c("ALP", "LNP", "ALP", "LNP", "ALP", "ALP"),
                    icc = c(0.2, 0.1, 0.3, 0.2, 0.9, 0.95), n_cells = 80, n_clusters = 8, scheme = "x")
  r <- seat_cluster_rho("vic2018", tab = tab, quiet = TRUE)
  expect_identical(attr(r, "n_elections"), 2L)       # vic2010, vic2014: not fed2010, not vic2022
  expect_true(all(r >= 0 & r <= 0.35))
  expect_identical(attr(seat_cluster_rho("vic2010", tab = tab, quiet = TRUE), "n_elections"), 0L)
  expect_true(all(seat_cluster_rho("vic2010", tab = tab, quiet = TRUE) == 0))
})
