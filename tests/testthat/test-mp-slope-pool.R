# AUSPOL_MP_SLOPE_POOL: partially pooled sitting-member slopes, one rule for the
# live forecast and every harness. docs/plans/prereg-mp-slope-pool-2026-10-25.md.

# ---- mp_slope_pool() -------------------------------------------------------

mk_rows <- function(party, x, slope, noise) data.frame(party = party, dev_prev = x, dev_now = slope * x + noise)

pool_fixture <- function() {
  rbind(
    mk_rows("IND", c(5, 10, 15, 20, 25, 30, -5, -10), 0.9, c(1, -1, 2, -2, 1, -1, 0.5, -0.5)),
    mk_rows("OTH_RIGHT", c(8, 12, -6), 1.3, c(1.5, -1, 0.5)),
    mk_rows("ONP", 6, 0.4, 0.3),
    mk_rows("GRN", c(4, 9, 14, -3, -8), 1.05, c(0.4, -0.6, 0.2, -0.1, 0.3))
  )
}

test_that("mp_slope_pool() matches the formula computed independently with lm()", {
  r <- pool_fixture(); cls <- c("IND", "OTH_RIGHT", "ONP", "GRN", "OTH"); mu <- 0.95
  out <- mp_slope_pool(r, cls, mu)
  expect_identical(out$party, cls)
  fits <- lapply(cls[1:4], function(cl) stats::lm(dev_now ~ 0 + dev_prev, data = r[r$party == cl, ]))
  est <- vapply(fits, function(f) unname(stats::coef(f)), numeric(1))
  rss <- vapply(fits, function(f) sum(stats::residuals(f)^2), numeric(1))
  sxx <- vapply(cls[1:4], function(cl) sum(r$dev_prev[r$party == cl]^2), numeric(1))
  sigma2 <- sum(rss) / (nrow(r) - 4)
  se <- sqrt(sigma2 / sxx)
  v <- 1 / se^2; mf <- sum(v * est) / sum(v)
  tau2 <- max(0, (sum(v * (est - mf)^2) - 3) / (sum(v) - sum(v^2) / sum(v)))
  expect_gt(tau2, 0)                                   # the fixture has real between-class spread
  w <- tau2 / (tau2 + se^2)
  expect_equal(out$est[1:4], unname(est), tolerance = 1e-12)
  expect_equal(out$se[1:4], unname(se), tolerance = 1e-12)
  expect_equal(out$tau2[1], tau2, tolerance = 1e-12)
  expect_equal(out$member[1:4], unname(mu + w * (est - mu)), tolerance = 1e-12)
  # a class with no member rows gets the pooled slope exactly, weight 0
  expect_identical(out$member[5], mu); expect_identical(out$w[5], 0); expect_identical(out$n_member[5], 0L)
})

test_that("no cliff: a one-row class is kept and shrunk, harder than a well-measured one", {
  out <- mp_slope_pool(pool_fixture(), c("IND", "ONP"), 0.95)
  onp <- out[out$party == "ONP", ]; ind <- out[out$party == "IND", ]
  expect_identical(onp$n_member, 1L)
  expect_true(is.finite(onp$member))
  expect_gt(onp$w, 0); expect_lt(onp$w, ind$w)        # graceful: thin -> toward mu, never dropped
  expect_true(onp$member > min(onp$est, 0.95) && onp$member < max(onp$est, 0.95))
})

test_that("identical class slopes give tau^2 = 0 and every class the pooled slope", {
  r <- rbind(mk_rows("IND", c(5, 10, 15), 0.9, c(1, -1, 0)), mk_rows("OTH_RIGHT", c(5, 10, 15), 0.9, c(1, -1, 0)))
  out <- mp_slope_pool(r, c("IND", "OTH_RIGHT"), 0.93)
  expect_identical(out$tau2, c(0, 0)); expect_identical(out$member, c(0.93, 0.93))
})

test_that("fewer than two classes with data: tau^2 cannot be estimated, so mu", {
  out <- mp_slope_pool(mk_rows("IND", c(5, 10), 0.5, c(0.2, -0.1)), c("IND", "ONP"), 1)
  expect_identical(out$member, c(1, 1))
  out0 <- mp_slope_pool(data.frame(party = character(), dev_prev = numeric(), dev_now = numeric()), "IND", 1)
  expect_identical(out0$member, 1)
})

test_that("a broken input fails loudly instead of pooling around it", {
  r <- pool_fixture(); r$dev_now[2] <- NA
  expect_error(mp_slope_pool(r, c("IND", "GRN"), 0.95), "non-finite")
  expect_error(mp_slope_pool(pool_fixture()[, c("party", "dev_prev")], "IND", 0.95), "lack dev_now")
  expect_error(mp_slope_pool(pool_fixture(), "IND", NA_real_))
})

# ---- the switch in the eight entry points -----------------------------------
# Each script's MP-tier block is cut out of the real file and run on a small
# fixture. "0" (and unset) must give exactly the rule each place had before the
# switch existed; "1" must give the pooled table's values for the target.

mp_fixture_dir <- function() {
  d <- file.path(tempfile("mppool"), "output"); dir.create(d, recursive = TRUE)
  data.table::fwrite(data.table::data.table(
    party = c("IND", "GRN", "OTH_RIGHT", "ONP"), n_member = c(84L, 22L, 7L, 1L), n_also = 1L,
    member = c(0.9391, 1.0417, 0.9605, NA), also_ran = 0.5, shipped = NA), file.path(d, "mp-slope-by-class.csv"))
  data.table::fwrite(data.table::data.table(
    target = rep(c("fed2022", "fed2025"), each = 4), party = rep(c("GRN", "IND", "ONP", "OTH_RIGHT"), 2),
    n_member = 1L, member = c(1.01, 0.93, 0.97, 0.96, 1.04, 0.9484, 0.9691, 0.9624), also_ran = 0.5),
    file.path(d, "mp-slope-by-target.csv"))
  data.table::fwrite(data.table::data.table(
    target = rep(c("fed2025", "vic2026"), each = 4), party = rep(c("GRN", "IND", "ONP", "OTH_RIGHT"), 2),
    n_member = c(18L, 70L, 1L, 15L, 22L, 84L, 1L, 16L), est = 0.9, se = 0.05, mu = 0.95, tau2 = 0.001,
    w = c(0.5, 0.9, 0.1, 0.4, 0.5, 0.9, 0.1, 0.4),
    member = c(1.02, 0.941, 0.952, 0.958, 1.03, 0.942, 0.951, 0.957)), file.path(d, "mp-slope-pooled.csv"))
  d
}

mp_block <- function(file) {
  l <- readLines(file, warn = FALSE)
  s <- grep("^\\s*\\.MP_SLOPE <- NULL", l)[1]
  e <- s + grep("^\\s*cat\\(sprintf\\(\"B[A-Za-z0-9]+\\s+MP tier|^# FITTED, as every harness does", l[-seq_len(s)])[1] - 1L
  stopifnot(is.finite(s), is.finite(e), e > s)
  l[s:e]
}

# eval() of this repo's own script text (a slice of scripts/*.R), never of outside input: the point is to run
# the shipped lines themselves rather than a copy of them that could drift.
run_mp_block <- function(file, dir, target, env_pool) {
  code <- gsub("output/", paste0(normalizePath(dir, winslash = "/"), "/"), mp_block(file), fixed = TRUE)
  env <- new.env(parent = globalenv())
  for (v in c("eb", "TGT", "el_to", ".eb")) assign(v, target, envir = env)
  assign("fread", data.table::fread, envir = env)
  withr::local_envvar(c(AUSPOL_MP_SLOPE = "1", AUSPOL_MP_SLOPE_FILE = NA, AUSPOL_MP_SLOPE_GRN = NA,
                        AUSPOL_MP_SLOPE_POOL = env_pool))
  utils::capture.output(eval(parse(text = code), envir = env))
  get(".MP_SLOPE", envir = env)
}

ENTRY <- c(paste0("backtest_candidate_", c("fed", "nsw", "nt", "qld", "sa", "vic", "wa"), ".R"), "fit_seats_full.R")

test_that("AUSPOL_MP_SLOPE_POOL=0 (and unset) is today's rule in every entry point; 1 reads the pooled table", {
  sd <- testthat::test_path("..", "..", "scripts")
  skip_if_not(dir.exists(sd), "scripts/ not shipped in the check build")
  d <- mp_fixture_dir()
  for (f in ENTRY) {
    live <- f == "fit_seats_full.R"
    tg <- if (live) "vic2026" else "fed2025"
    # what each place did before the switch: live = by-class, n_member >= 8, not GRN; harness = target row, not GRN
    legacy <- if (live) c(IND = 0.9391) else c(IND = 0.9484, ONP = 0.9691, OTH_RIGHT = 0.9624)
    pooled <- if (live) c(IND = 0.942, ONP = 0.951, OTH_RIGHT = 0.957) else c(IND = 0.941, ONP = 0.952, OTH_RIGHT = 0.958)
    p <- file.path(sd, f)
    expect_equal(run_mp_block(p, d, tg, "0"), legacy, tolerance = 1e-12, label = paste(f, "POOL=0"))
    expect_equal(run_mp_block(p, d, tg, NA), legacy, tolerance = 1e-12, label = paste(f, "POOL unset"))
    expect_equal(run_mp_block(p, d, tg, "1"), pooled, tolerance = 1e-12, label = paste(f, "POOL=1"))
    expect_error(run_mp_block(p, d, tg, "yes"), "must be \"0\" or \"1\"", label = paste(f, "bad value"))
  }
  # the live floor is the cliff the switch removes: OTH_RIGHT at n = 7 is dropped under "0", kept under "1"
  expect_false("OTH_RIGHT" %in% names(run_mp_block(file.path(sd, "fit_seats_full.R"), d, "vic2026", "0")))
  # "1" with the pooled table missing stops rather than quietly reading the old one
  file.remove(file.path(d, "mp-slope-pooled.csv"))
  for (f in ENTRY) expect_error(run_mp_block(file.path(sd, f), d, if (f == "fit_seats_full.R") "vic2026" else "fed2025", "1"),
                                "mp-slope-pooled.csv", label = f)
})
