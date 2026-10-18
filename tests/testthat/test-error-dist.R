# Empirical error distribution (AUSPOL_ERROR_DIST). docs/plans/prereg-error-distribution-2026-10-17.md

ed_fm <- function() {
  build_flow_matrix(data.table::data.table(
    election = "x", seat = rep(c("a", "b", "c"), each = 2), round = 1L,
    from = c("GRN", "GRN", "IND", "IND", "LNP", "LNP"),
    to = c("ALP", "LNP", "ALP", "LNP", "ALP", "GRN"),
    votes = c(800, 200, 400, 600, 900, 100)), min_n = 1L)
}
ed_sh <- function() matrix(c(38, 40, 20, 2,  45, 35, 15, 5,  30, 30, 15, 25), nrow = 3, byrow = TRUE,
                           dimnames = list(c("s1", "s2", "s3"), c("ALP", "LNP", "GRN", "IND")))
# a right-skewed shape for IND, a bell-like one for the rest (any nondecreasing rows will do)
ed_q <- function() {
  u <- seq(0, 1, by = 0.005)
  bell <- stats::qnorm(pmin(pmax(u, 0.001), 0.999))
  skew <- stats::qexp(pmin(u, 0.999)) - 1
  m <- rbind(ALP = bell, LNP = bell, GRN = bell, IND = skew)
  m
}

test_that("the compiled core is byte-identical to the R engine with the empirical errors on", {
  args <- list(ed_sh(), ed_fm(), party_sd = c(ALP = 2, LNP = 2, GRN = 1.5, IND = 1), seat_sd = 3,
               level_sd = c(1.1, 8.67), n_sims = 300, seed = 5,
               shrink = c(s1 = 0.05, s2 = 0.3, s3 = 0.2), surge_h = c(0.3, 0.1, 0.5),
               surge_mu = 30, surge_sd = 8, flow_sd = 3, fallback_smooth = 0.3, smooth = 0.1,
               error_q = ed_q())
  strip <- function(x) { x$engine <- NULL; x }
  r <- do.call(simulate_seat_contests, c(args, list(engine = "r")))
  cc <- do.call(simulate_seat_contests, c(args, list(engine = "cpp")))
  expect_identical(strip(cc), strip(r))
  expect_true(r$error_dist)
  # and it changes the run (it is not silently rnorm)
  a <- do.call(simulate_seat_contests, c(args[names(args) != "error_q"], list(engine = "cpp")))
  expect_false(identical(a$tcp_share, cc$tcp_share))
  expect_false(a$error_dist)
})

test_that("a skewed distribution moves the class's median, not its mean, as drawn", {
  q <- ed_q()
  u <- (seq_len(20000) - 0.5) / 20000
  Q <- ncol(q); pos <- u * (Q - 1); i0 <- floor(pos); fr <- pos - i0
  z <- q["IND", i0 + 1] + fr * (q["IND", pmin(i0 + 2, Q)] - q["IND", i0 + 1])
  expect_lt(stats::median(z), -0.2)
  expect_lt(abs(mean(z)), 0.05)
})

test_that("malformed error_q is refused, not ignored", {
  sim <- function(q) simulate_seat_contests(ed_sh(), ed_fm(), party_sd = c(ALP = 1, LNP = 1, GRN = 1, IND = 1),
                                            level_sd = c(1.1, 8.67), n_sims = 10, seed = 1, error_q = q)
  expect_error(sim(ed_q()[1:3, ]), "one row per class")
  q <- ed_q(); rownames(q) <- c("LNP", "ALP", "GRN", "IND")
  expect_error(sim(q), "row names")
  q <- ed_q(); q["IND", 10] <- 99
  expect_error(sim(q), "nondecreasing")
  q <- ed_q(); q[1, 1] <- NA
  expect_error(sim(q), "finite")
})

test_that("error_dist_args: off returns NULL; on reads the target's rows in class order and refuses a missing class", {
  r <- withr::local_tempdir()
  writeLines("Package: x", file.path(r, "DESCRIPTION"))
  dir.create(file.path(r, "output"))
  withr::local_options(auspol.root = r)
  withr::local_envvar(AUSPOL_ERROR_DIST = "0")
  expect_null(error_dist_args("vic2026", c("ALP", "LNP")))
  q <- ed_q()
  tab <- data.table::data.table(target = "vic2026", class = rownames(q), n = 100L, w = 0.3, n_pairs = 10L)
  qt <- data.table::as.data.table(q); data.table::setnames(qt, sprintf("q%03d", seq_len(ncol(q)) - 1L))
  data.table::fwrite(cbind(tab, qt), file.path(r, "output", "error-quantiles.csv"))
  withr::local_envvar(AUSPOL_ERROR_DIST = "1")
  m <- error_dist_args("vic2026", c("IND", "ALP"))
  expect_equal(rownames(m), c("IND", "ALP"))
  expect_equal(unname(m["IND", ]), unname(q["IND", ]))
  expect_null(error_dist_args("wa2001", c("ALP")))                    # no row: rnorm as shipped
  expect_error(error_dist_args("vic2026", c("ALP", "ONP")), "no vic2026 row for: ONP")
  withr::local_envvar(AUSPOL_ERROR_DIST = "yes")
  expect_error(error_dist_args("vic2026", "ALP"), "must be")
})
