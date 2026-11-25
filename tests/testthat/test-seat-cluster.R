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
  withr::with_envvar(c(AUSPOL_SEAT_CLUSTER_COR = "0"),
    expect_identical(seat_cluster_setup("vic2022", f$sh), list(seat_cluster = NULL, cluster_rho = NULL)))  # switch off
  withr::with_envvar(c(AUSPOL_SEAT_CLUSTER_COR = NA), expect_identical(seat_cluster_mode(), "both"))  # unset = published
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

# ---- several factors (AUSPOL_SEAT_CLUSTER_COR=both) and seat types (=type);
#      plans/prereg-seat-type-cor-2026-11-25.md --------------------------------------------
clu2 <- function(f) cbind(region = f$cl, type = c(1L, 2L, 1L, 2L, NA, 1L))

test_that("two factors: zero rho or no seat in any cluster is the old run byte for byte; the mode switch is validated", {
  f <- clu_fixture()
  run <- function(...) simulate_seat_contests(f$sh, f$fm, party_sd = c(ALP = 2, LNP = 2, GRN = 1),
                                              level_sd = c(1.1, 8.67), n_sims = 400, seed = 5, ...)
  base <- run()
  expect_identical(run(seat_cluster = clu2(f), cluster_rho = list(c(ALP = 0), c(LNP = 0, GRN = 0))), base)
  expect_identical(run(seat_cluster = matrix(NA_integer_, 6, 2), cluster_rho = list(c(ALP = 0.3), c(ALP = 0.3))), base)
  on <- run(seat_cluster = clu2(f), cluster_rho = list(c(ALP = 0.3), c(ALP = 0.3, LNP = 0.2)))
  expect_false(identical(on$totals, base$totals))
  withr::with_envvar(c(AUSPOL_SEAT_CLUSTER_COR = "0"),
    expect_identical(seat_cluster_setup("vic2022", f$sh), list(seat_cluster = NULL, cluster_rho = NULL)))
  withr::with_envvar(c(AUSPOL_SEAT_CLUSTER_COR = "types"), expect_error(seat_cluster_mode(), "must be"))
  for (v in c("1", "type", "both")) withr::with_envvar(c(AUSPOL_SEAT_CLUSTER_COR = v), expect_true(seat_cluster_on()))
})

test_that("a one-column factor matrix is the one-factor run (same stream), and compiled = R loop with two", {
  f <- clu_fixture()
  args <- list(f$sh, f$fm, party_sd = c(ALP = 2, LNP = 2, GRN = 1), level_sd = c(1.1, 8.67), n_sims = 300,
               seed = 9, keep_fp = TRUE)
  one <- do.call(simulate_seat_contests, c(args, list(seat_cluster = f$cl, cluster_rho = c(ALP = 0.3, LNP = 0.5))))
  mat <- do.call(simulate_seat_contests, c(args, list(seat_cluster = matrix(f$cl, ncol = 1), cluster_rho = list(c(ALP = 0.3, LNP = 0.5)))))
  expect_equal(mat$fp_draws, one$fp_draws, tolerance = 1e-12)
  a2 <- c(args, list(shrink = 0.02, flow_sd = 2, seat_cluster = clu2(f),
                     cluster_rho = list(c(ALP = 0.3, LNP = 0.2), c(ALP = 0.2, GRN = 0.4))))
  r <- do.call(simulate_seat_contests, c(a2, list(engine = "r")))
  cc <- do.call(simulate_seat_contests, c(a2, list(engine = "cpp")))
  expect_identical(cc$engine, "cpp")
  expect_identical(strip_engine(cc), strip_engine(r))
})

test_that("two factors keep every cell's sd, couple seats sharing either factor, and refuse a sum >= 1", {
  f <- clu_fixture()
  N <- 20000
  run <- function(on) simulate_seat_contests(f$sh, f$fm, party_sd = c(ALP = 0, LNP = 0, GRN = 0),
    level_sd = c(1.1, 8.67), n_sims = N, seed = 21, keep_fp = TRUE,
    seat_cluster = if (on) clu2(f) else NULL,
    cluster_rho = if (on) list(c(ALP = 0.35, LNP = 0.35, GRN = 0.35), c(ALP = 0.35, LNP = 0.35, GRN = 0.35)) else NULL)
  off <- run(FALSE); on <- run(TRUE)
  sdr <- apply(on$fp_draws, c(2, 3), stats::sd) / apply(off$fp_draws, c(2, 3), stats::sd)
  expect_true(all(abs(sdr - 1) < 0.04), info = paste(round(sdr, 3), collapse = " "))
  cr <- function(i, j) stats::cor(on$fp_draws[, i, 1], on$fp_draws[, j, 1])
  # region: 1,2,3 = 1; 4,5 = 2; 6 none. type: 1,3,6 = 1; 2,4 = 2; 5 none
  expect_gt(cr(1, 3), 0.55)             # both factors shared: ~0.70
  expect_gt(cr(1, 2), 0.25); expect_lt(cr(1, 2), 0.45)   # region only: ~0.35
  expect_gt(cr(1, 6), 0.25); expect_lt(cr(1, 6), 0.45)   # type only: ~0.35
  expect_lt(abs(cr(1, 5)), 0.03)        # neither
  run_bad <- function() simulate_seat_contests(f$sh, f$fm, party_sd = c(ALP = 2, LNP = 2, GRN = 1),
    level_sd = c(1.1, 8.67), n_sims = 50, seed = 1, seat_cluster = clu2(f), cluster_rho = list(c(ALP = 0.6), c(ALP = 0.5)))
  expect_error(run_bad(), "summed over factors")
  expect_error(simulate_seat_contests(f$sh, f$fm, party_sd = c(ALP = 2, LNP = 2, GRN = 1), level_sd = c(1.1, 8.67),
    n_sims = 50, seat_cluster = clu2(f), cluster_rho = list(c(ALP = 0.2))), "same length")
})

test_that("seat types come from shares and census only, a seat without census is typed on shares, bad input stops", {
  set.seed(3)
  sh <- rbind(matrix(c(50, 35, 15), 11, 3, byrow = TRUE), matrix(c(30, 55, 15), 11, 3, byrow = TRUE)) + rnorm(66, 0, 1)
  seats <- paste0("Seat ", LETTERS[1:22]); colnames(sh) <- c("ALP", "LNP", "GRN")
  cen <- data.frame(pair = "vic2099", seat = seats, yr12_pct = c(rep(70, 11), rep(40, 11)) + rnorm(22),
                    born_aus_pct = 60 + rnorm(22), indig_pct = 1, over55_pct = 30 + rnorm(22), under35_pct = 35 + rnorm(22),
                    lang_other_pct = 20 + rnorm(22), edu_25plus_pct = 30 + rnorm(22))
  cen[3, -(1:2)] <- NA
  id <- seat_cluster_type_map("vic2099", seats, sh, census = cen, quiet = TRUE)
  expect_length(attr(id, "labels"), 2L)                          # k = round(22 / 11)
  expect_identical(attr(id, "n_census"), 21L)
  expect_identical(length(unique(id[1:11])), 1L); expect_identical(length(unique(id[12:22])), 1L)
  expect_false(id[1] == id[12])
  id0 <- seat_cluster_type_map("vic2099", seats, sh, census = FALSE, quiet = TRUE)
  expect_identical(as.integer(id0), as.integer(id))             # shares alone separate them too
  expect_error(seat_cluster_type_map("vic2099", seats, sh, census = cen[, 1:4], quiet = TRUE), "lacks")
  seed_before <- .Random.seed
  seat_cluster_type_map("vic2099", seats, sh, census = cen, quiet = TRUE)
  expect_identical(.Random.seed, seed_before)                    # the caller's stream is untouched
})

test_that("without the vintage census file, the plain one stands in only for an election after every row's census", {
  d <- tempfile(); dir.create(file.path(d, "output"), recursive = TRUE)
  ce <- data.frame(pair = c("vic2099", "vic2099", "qld2017"), seat = c("A", "B", "A"), vintage = c(2021L, 2021L, 2021L),
                   yr12_pct = 1, born_aus_pct = 1, indig_pct = 1, over55_pct = 1, under35_pct = 1, lang_other_pct = 1,
                   edu_25plus_pct = 1)
  expect_error(seat_cluster_census("vic2099", d), "neither")
  utils::write.csv(ce, file.path(d, "output", "census-features.csv"), row.names = FALSE)
  expect_output(got <- seat_cluster_census("vic2099", d), "SCT2 vic2099")
  expect_identical(nrow(got), 3L)
  expect_error(seat_cluster_census("qld2017", d), "SCT2!")       # a 2021 census for a 2017 election: refused
  expect_error(seat_cluster_census("vic2050", d), "SCT2!")       # no rows for the election: refused
  utils::write.csv(ce[1, ], file.path(d, "output", "census-features-vintage.csv"), row.names = FALSE)
  expect_identical(nrow(seat_cluster_census("qld2017", d)), 1L)  # the vintage file, when present, is read as before
})
