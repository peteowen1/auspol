test_that("seat_swing_port_apply is a no-op unless AUSPOL_SEAT_SWING_PORT=2", {
  m <- matrix(c(40, 35, 25, 30, 45, 25), nrow = 2, byrow = TRUE,
              dimnames = list(c("A", "B"), c("ALP", "LNP", "OTH")))
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "0")
  expect_identical(seat_swing_port_apply(m, "vic2022"), m)
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "1")
  expect_identical(seat_swing_port_apply(m, "vic2022"), m)
})

test_that("the port coefficient learns only from earlier state cycles", {
  skip_if_not(file.exists(out_path("seat-tpp-estimates.csv")), "no seat TPP estimates")
  skip_if_not(file.exists(file.path(election_data_path(), "fed-swing-transposed.csv")),
              "no transposed federal swing")
  # Nothing precedes vic2018 in the transposed file except sa2018, which has
  # no sa2014 baseline: no cycles, coefficient exactly 0.
  expect_equal(seat_swing_port_coef("vic2018")$coef, 0)
  tf <- seat_swing_port_coef("vic2022")
  # Proven to bite: with time-forward fits off, later cycles leak in.
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "0")
  leaky <- seat_swing_port_coef("vic2022")
  expect_lt(tf$k, leaky$k)
  expect_true(tf$coef >= 0 && tf$coef < 1)
})

test_that("the port reads its shipped table when the sources are absent (the CI runner)", {
  skip_if_not(file.exists(out_path("seat-tpp-estimates.csv")), "no seat TPP estimates")
  skip_if_not(file.exists(file.path(election_data_path(), "fed-swing-transposed.csv")),
              "no transposed federal swing")
  cache <- out_path("seat-swing-port-vic2026.csv")
  had <- file.exists(cache)
  if (had) { bak <- tempfile(); file.copy(cache, bak) }
  on.exit(if (had) file.copy(bak, cache, overwrite = TRUE) else unlink(cache), add = TRUE)
  src <- seat_swing_port_table("vic2026", write = TRUE)
  withr::local_options(auspol.elections_dir = tempfile("no-elections"))
  shipped <- seat_swing_port_table("vic2026")
  expect_equal(attr(shipped, "coef")$coef, attr(src, "coef")$coef)
  expect_equal(shipped$fed_swing, src$fed_swing)
  unlink(cache)
  expect_error(seat_swing_port_table("vic2026"), "neither the sources")
})

# ---- WA pooling and the no-cliff rule (AUSPOL_SEAT_SWING_PORT_WA / _NOCLIFF) ----
# A synthetic world, so these run on CI (no anchor data): vic2014/18/22 state
# results and vic2018/22 transposed federal swings, plus wa2008/13/17 and wa2013/17.
# The state swing is 0.5 x the federal deviation plus noise, so b is about 0.5.
local_port_fixture <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(root, "output")); dir.create(file.path(root, "elections"))
  writeLines("Package: fixture", file.path(root, "DESCRIPTION"))
  withr::local_options(auspol.root = root, auspol.elections_dir = file.path(root, "elections"), .local_envir = env)
  set.seed(7)
  seats <- sprintf("seat%02d", 1:30)
  mk_fs <- function(rg, cy) data.table::data.table(seat = seats, fed_swing = stats::rnorm(30, 2, 3), region = rg, cycle = cy)
  fs_main <- rbind(mk_fs("vic", 2018), mk_fs("vic", 2022))
  fs_wa <- rbind(mk_fs("wa", 2013), mk_fs("wa", 2017))
  tpp <- data.table::rbindlist(lapply(c("vic2014", "vic2018", "vic2022", "wa2008", "wa2013", "wa2017"),
                                      function(e) data.table::data.table(s = seats, tpp = 50, election = e)))
  # tpp of a cycle = previous tpp + 0.5 x its federal deviation + noise
  for (z in list(list("vic2018", "vic2014", fs_main), list("vic2022", "vic2018", fs_main),
                 list("wa2013", "wa2008", fs_wa), list("wa2017", "wa2013", fs_wa))) {
    f <- z[[3]][paste0(z[[3]]$region, z[[3]]$cycle) == z[[1]]]
    prev <- tpp$tpp[tpp$election == z[[2]]]
    tpp$tpp[tpp$election == z[[1]]] <- prev + 0.5 * (f$fed_swing - mean(f$fed_swing)) + stats::rnorm(30, 0, 2)
  }
  data.table::fwrite(tpp, file.path(root, "output", "seat-tpp-estimates.csv"))
  data.table::fwrite(fs_main, file.path(root, "elections", "fed-swing-transposed.csv"))
  data.table::fwrite(fs_wa, file.path(root, "elections", "fed-swing-transposed-wa.csv"))
  invisible(root)
}

test_that("NOCLIFF off leaves a thin fit at 0; on, it is shrunk by an error doubled, not cut off", {
  local_port_fixture()
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_NOCLIFF = "0", AUSPOL_SEAT_SWING_PORT_WA = "0")
  off <- seat_swing_port_coef("vic2022")           # one earlier cycle (vic2018)
  expect_equal(off$k, 1L); expect_equal(off$coef, 0); expect_true(is.na(off$b))
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_NOCLIFF = "1")
  on <- seat_swing_port_coef("vic2022")
  expect_gt(on$b, 0.2)                              # the planted 0.5 is recovered, loosely
  expect_gt(on$coef, 0); expect_lt(on$coef, on$b)   # shrunk toward 0, never past it
  expect_equal(on$coef, on$b * on$b^2 / (on$b^2 + on$se^2))
  # Proven to bite: the inflation is what makes the weight smaller than the plain one.
  plain_se <- on$se / SEAT_SWING_NOCLIFF_SE_INFLATE
  expect_lt(on$coef, on$b * on$b^2 / (on$b^2 + plain_se^2))
  # No earlier cycle at all is still 0: shrinkage needs something to shrink.
  expect_equal(seat_swing_port_coef("vic2018")$coef, 0)
})

test_that("WA cycles pool into other targets only at mode 1, and into WA targets at mode 2", {
  local_port_fixture()
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_NOCLIFF = "1")
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_WA = "0")
  base_vic <- seat_swing_port_coef("vic2022"); base_wa <- seat_swing_port_coef("wa2017")
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_WA = "2")
  expect_identical(seat_swing_port_coef("vic2022"), base_vic)   # untouched
  wa_own <- seat_swing_port_coef("wa2017")
  expect_gt(wa_own$k, base_wa$k)
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_WA = "1")
  expect_identical(seat_swing_port_coef("wa2017"), wa_own)
  # A missing WA file is an error, never a silent fall back to the old fit.
  withr::local_envvar(AUSPOL_SEAT_SWING_WA_FILE = file.path(tempdir(), "no-such-wa-file.csv"))
  expect_error(seat_swing_port_coef("vic2022"), "does not exist")
})

test_that("seat_swing_port_apply for a WA target needs AUSPOL_SEAT_SWING_PORT_WA, not AUSPOL_SEAT_SWING_PORT", {
  local_port_fixture()
  m <- matrix(rep(c(40, 35, 25), 30), nrow = 30, byrow = TRUE,
              dimnames = list(sprintf("seat%02d", 1:30), c("ALP", "LNP", "OTH")))
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "2", AUSPOL_SEAT_SWING_PORT_NOCLIFF = "1",
                      AUSPOL_SEAT_SWING_PORT_WA = "0")
  expect_identical(seat_swing_port_apply(m, "wa2017"), m)       # shipped port on, WA off: no-op
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "0", AUSPOL_SEAT_SWING_PORT_WA = "2")
  out <- utils::capture.output(adj <- seat_swing_port_apply(m, "wa2017"))
  expect_false(isTRUE(all.equal(adj, m)))
  expect_equal(unname(rowSums(adj)), rep(100, 30))
  # Victoria ignores the WA switch.
  expect_identical(seat_swing_port_apply(m, "vic2022"), m)
})

# ---- mode 3: each state partially pooled toward the all-state coefficient ----
mk_rows <- function(spec, seed = 3) {
  # spec: region = c(b, noise sd, cycles); 40 seats per cycle
  set.seed(seed)
  data.table::rbindlist(lapply(names(spec), function(rg) data.table::rbindlist(lapply(seq_len(spec[[rg]][3]), function(i) {
    dev <- stats::rnorm(40, 0, 3)
    data.table::data.table(region = rg, pair = paste0(rg, i), dev = dev,
                           yy = spec[[rg]][1] * dev + stats::rnorm(40, 0, spec[[rg]][2]))
  }))))
}
pooled <- function(r) {
  b <- sum(r$dev * r$yy) / sum(r$dev^2); e <- r$yy - b * r$dev; g <- length(unique(r$pair))
  c(b = b, se2 = max(sum(tapply(r$dev * e, r$pair, sum)^2) / sum(r$dev^2)^2 * g / (g - 1),
                     sum(e^2) / (nrow(r) - 1) / sum(r$dev^2)))
}

test_that("mode 3: a precise own estimate barely moves, a noisy one moves toward the pooled fit", {
  r <- mk_rows(list(a = c(0.2, 0.3, 6), b = c(0.5, 0.3, 6), c = c(0.8, 0.3, 6), d = c(0.9, 3, 1)))
  p <- pooled(r)
  precise <- seat_swing_port_state_shrunk(r, "b", p[["b"]], p[["se2"]], 21L)
  noisy <- seat_swing_port_state_shrunk(r, "d", p[["b"]], p[["se2"]], 21L)
  expect_gt(precise$tau2, 0)
  expect_gt(precise$w, 0.9)
  expect_lt(abs(precise$b - precise$b_own), 0.1 * abs(precise$b_own - p[["b"]]) + 0.02)
  expect_lt(noisy$w, 0.5)
  expect_lt(abs(noisy$b - p[["b"]]), abs(noisy$b_own - p[["b"]]))   # moved toward mu
  expect_true(noisy$coef >= 0 && noisy$coef < noisy$b)               # still shrunk toward 0
})

test_that("mode 3: zero between-state variance gives every state the pooled coefficient", {
  # Three states with IDENTICAL data, so their own coefficients are exactly equal.
  r1 <- mk_rows(list(a = c(0.4, 3, 4)))
  r <- data.table::rbindlist(lapply(c("a", "b", "c"), function(s) data.table::copy(r1)[, `:=`(region = s, pair = paste0(s, pair))]))
  p <- pooled(r)
  for (s in c("a", "b", "c")) {
    z <- seat_swing_port_state_shrunk(r, s, p[["b"]], p[["se2"]], 12L)
    expect_equal(z$tau2, 0); expect_equal(z$w, 0); expect_equal(z$b, p[["b"]])
  }
  # A state with no earlier cycles of its own also gets mu.
  z <- seat_swing_port_state_shrunk(r, "zzz", p[["b"]], p[["se2"]], 12L)
  expect_equal(z$b, p[["b"]]); expect_true(is.na(z$b_own))
})

test_that("mode 3 through seat_swing_port_coef: pools WA like mode 1, and off at 0", {
  local_port_fixture()
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_NOCLIFF = "1", AUSPOL_SEAT_SWING_PORT_WA = "1")
  m1 <- seat_swing_port_coef("wa2017")
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_WA = "3")
  m3 <- seat_swing_port_coef("wa2017")
  expect_equal(m3$k, m1$k); expect_true(all(c("b_own", "mu", "tau2", "w") %in% names(m3)))
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_WA = "0")
  expect_false("tau2" %in% names(seat_swing_port_coef("wa2017")))
})
