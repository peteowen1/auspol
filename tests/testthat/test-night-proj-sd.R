# Opt-in fitted projection sd (booth_projection_sd(method = "fitted"), scripts/fit_night_projection_sd.R). Synthetic booths.

pj_booths <- function(alp, lnp, ind, booths) {
  data.table::rbindlist(lapply(seq_along(booths), function(i) data.table::data.table(
    district = "Seat A", booth = booths[i], booth_type = "ordinary",
    party = c("Australian Labor Party", "Liberal", "Independent"), votes = c(alp[i], lnp[i], ind[i]))))
}

test_that("the default projection sd is the rehearsal table, unchanged", {
  x <- c(0, 0.003, 0.05, 0.086, 0.224, 0.346, 0.95, 1)
  expect_equal(booth_projection_sd(x), c(3.5, 3.5, 3.5, 2.63, 1.93, 1.77, 0.26, 0.26))
  expect_identical(booth_projection_sd(x), booth_projection_sd(x, method = "old"))
  expect_error(booth_projection_sd(0.1, method = "fitted"), "BPS1!")
})

test_that("the fitted curve is finite, positive and falls monotonically with the count, for every group and share", {
  cs <- c(0, 0.0005, 0.001, 0.003, 0.005, 0.01, 0.02, 0.05, 0.1, 0.25, 0.5, 0.9, 1)
  for (cl in c("ALP", "LNP", "GRN", "IND", "OTH")) for (p in c(2, 10, 35, 60)) {
    s <- booth_projection_sd(cs, method = "fitted", share = p, cls = cl)
    expect_true(all(is.finite(s) & s > 0))
    expect_true(all(diff(s) <= 1e-12), info = paste(cl, p))
  }
})

test_that("night_booth_update(): the default is byte-identical to proj_sd = \"old\", and \"fitted\" reaches the update", {
  b <- paste0("B", 1:40)
  ref  <- pj_booths(rep(40, 40), rep(45, 40), rep(15, 40), b)
  live <- pj_booths(rep(38, 40), rep(32, 40), rep(30, 40), b)
  sh <- matrix(c(40, 45, 15), 1, dimnames = list("Seat A", c("ALP", "LNP", "IND")))
  psd <- matrix(4, 1, 3, dimnames = dimnames(sh))
  rep_units <- data.table::data.table(district = "Seat A", unit = "B1")          # one booth of forty in
  u0 <- night_booth_update(sh, psd, 1, live, ref, reported = rep_units, total = "table")
  uo <- night_booth_update(sh, psd, 1, live, ref, reported = rep_units, total = "table", proj_sd = "old")
  expect_identical(u0, uo)
  uf <- night_booth_update(sh, psd, 1, live, ref, reported = rep_units, total = "table", proj_sd = "fitted")
  expect_false(isTRUE(all.equal(u0$shares, uf$shares)))
  # keep_proj adds only proj_detail, and records the sd each mode used
  uk <- night_booth_update(sh, psd, 1, live, ref, reported = rep_units, total = "table", keep_proj = TRUE)
  expect_identical(uk[names(u0)], u0)
  expect_setequal(setdiff(names(uk), names(u0)), "proj_detail")
  expect_equal(uk$proj_detail$sd_proj, rep(booth_projection_sd(0.025), 3))
  expect_error(night_booth_update(sh, psd, 1, live, ref, reported = rep_units, proj_sd = "new"))
})

test_that("night_cycle's proj_sd setting parses strictly", {
  expect_identical(.night_proj_sd_cfg(NULL), "old")
  expect_identical(.night_proj_sd_cfg("old"), "old")
  expect_identical(.night_proj_sd_cfg("fitted"), "fitted")
  expect_error(.night_proj_sd_cfg("on"), "NW26!")
})
