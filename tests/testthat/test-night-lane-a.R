# Lane A projection switches (docs/plans/prereg-night-lane-a-2026-11-27.md): booth-level swing (A1), vote-type pooling
# (A2), representativeness sd. Synthetic booths; no anchor data.

la_seat <- function(lnp_share, size, types = rep("ordinary", length(lnp_share)), units = NULL) {
  if (is.null(units)) units <- paste0("B", seq_along(lnp_share))
  data.table::rbindlist(lapply(seq_along(units), function(i) data.table::data.table(
    unit = units[i], booth_type = types[i], cls = c("LNP", "ALP"), v = round(size[i] * c(lnp_share[i], 1 - lnp_share[i])))))
}

test_that("every lane A switch off is identical to the old call", {
  x <- c(0.2, 0.4, 0.6, 0.8); ref <- la_seat(x, rep(1000, 4)); live <- la_seat(x + 0.05, rep(1000, 4))
  p0 <- project_seat_from_booths(live, ref, c("B1", "B2"))
  expect_identical(project_seat_from_booths(live, ref, c("B1", "B2"), booth_reg = NULL, type_pool_k = NULL, diag = FALSE), p0)
  expect_identical(names(p0), c("cls", "projected", "counted_share"))
  pd <- project_seat_from_booths(live, ref, c("B1", "B2"), diag = TRUE)
  expect_equal(pd[order(cls)]$projected, p0[order(cls)]$projected)   # diag adds columns, changes nothing
  expect_true(all(c("n_ord", "swing_sd", "rep_dist", "unc_frac") %in% names(pd)))
})

test_that("A1 recovers a swing that depends on the booth's own reference share", {
  x <- c(0.2, 0.4, 0.6, 0.8); ref <- la_seat(x, rep(1000, 4))
  y <- x + 0.05 - 0.5 * (x - 0.5)                              # strong booths swing against, weak booths towards
  live <- la_seat(y, rep(1000, 4))
  truth <- sum(live[cls == "LNP"]$v)
  p_base <- project_seat_from_booths(live, ref, c("B1", "B2"))
  p_a1 <- project_seat_from_booths(live, ref, c("B1", "B2"), booth_reg = list(k = 0))
  e_base <- abs(p_base[cls == "LNP"]$projected - truth); e_a1 <- abs(p_a1[cls == "LNP"]$projected - truth)
  expect_gt(e_base, 100)                                       # uniform swing gets it wrong (the broken input)
  expect_lt(e_a1, 5)                                           # the booth slope gets it right
  # k large with no pooled slope shrinks back to uniform swing
  p_k <- project_seat_from_booths(live, ref, c("B1", "B2"), booth_reg = list(k = 1e9))
  expect_equal(p_k$projected, p_base$projected, tolerance = 1e-6)
  # a pooled slope from other seats is used when the seat's own slope is unmeasurable (one booth counted)
  p_pool <- project_seat_from_booths(live, ref, "B1", booth_reg = list(k = 5, pool = data.table::data.table(cls = c("LNP", "ALP"), beta = c(-0.5, -0.5))))
  p_one <- project_seat_from_booths(live, ref, "B1")
  expect_lt(abs(p_pool[cls == "LNP"]$projected - truth), abs(p_one[cls == "LNP"]$projected - truth))
})

test_that("A2 projects ordinary booths at the early swing minus the early gap", {
  ref <- la_seat(c(0.5, 0.5, 0.5), c(1000, 1000, 3000), types = c("ordinary", "ordinary", "early"), units = c("B1", "B2", "early"))
  live <- la_seat(c(0.55, 0.55, 0.60), c(1000, 1000, 3000), types = c("ordinary", "ordinary", "early"), units = c("B1", "B2", "early"))
  gap <- data.table::data.table(booth_type = "early", cls = c("LNP", "ALP"), gap = c(0.05, -0.05))
  truth <- sum(live[cls == "LNP"]$v)
  p_base <- project_seat_from_booths(live, ref, "early", type_gap = gap)
  p_a2 <- project_seat_from_booths(live, ref, "early", type_gap = gap, type_pool_k = 0)
  expect_gt(abs(p_base[cls == "LNP"]$projected - truth), 50)     # base: ordinary booths take the raw early swing
  expect_lt(abs(p_a2[cls == "LNP"]$projected - truth), 2)
  # with ordinary booths counted too and k = 0, a type's own swing wins (pooling never overrides a measured type)
  p_own <- project_seat_from_booths(live, ref, c("B1", "early"), type_gap = gap, type_pool_k = 0)
  expect_lt(abs(p_own[cls == "LNP"]$projected - truth), 2)
})

test_that("night_booth_update: the lane A switches off are identical, on they reach proj_detail", {
  mk <- function(alp, lnp, d) data.table::rbindlist(lapply(seq_along(alp), function(i) data.table::data.table(
    district = d, booth = paste0("B", i), booth_type = "ordinary", party = c("Australian Labor Party", "Liberal"), votes = c(alp[i], lnp[i]))))
  ref <- rbind(mk(c(200, 400, 600, 800), c(800, 600, 400, 200), "Seat A"), mk(c(300, 500, 700), c(700, 500, 300), "Seat B"))
  live <- rbind(mk(c(300, 450, 600, 750), c(700, 550, 400, 250), "Seat A"), mk(c(400, 550, 700), c(600, 450, 300), "Seat B"))
  sh <- matrix(c(50, 50, 50, 50), 2, dimnames = list(c("Seat A", "Seat B"), c("ALP", "LNP"))); psd <- matrix(4, 2, 2, dimnames = dimnames(sh))
  rp <- data.table::data.table(district = c("Seat A", "Seat A", "Seat B", "Seat B"), unit = c("B1", "B2", "B1", "B2"))
  u0 <- night_booth_update(sh, psd, 1, live, ref, reported = rp)
  expect_identical(night_booth_update(sh, psd, 1, live, ref, reported = rp, booth_reg_k = NULL, type_pool_k = NULL, rep_sd = NULL, proj_diag = FALSE), u0)
  u1 <- night_booth_update(sh, psd, 1, live, ref, reported = rp, booth_reg_k = 0, keep_proj = TRUE, proj_diag = TRUE)
  expect_false(isTRUE(all.equal(u1$shares, u0$shares)))
  expect_true(all(c("sd_table", "n_ord", "swing_sd", "rep_dist", "unc_frac") %in% names(u1$proj_detail)))
  expect_true(all(u1$proj_detail$n_ord == 2))
  expect_true(all(u1$proj_detail$rep_dist > 0))
  u2 <- night_booth_update(sh, psd, 1, live, ref, reported = rp, rep_sd = c(1, 1), keep_proj = TRUE)
  expect_true(all(u2$proj_detail$sd_proj > u2$proj_detail$sd_table))
  expect_error(night_booth_update(sh, psd, 1, live, ref, reported = rp, rep_sd = c(-1, 1)))
  expect_identical(.night_booth_slope(live[0], ref[0], list()), NULL)
})

# A fixture with ordinary booths, an early block, a postal block, a pooled type gap, an upper-house lean for a new
# class, and total = "expected": the switches-off output was computed with the pre-lane-A code (403f3f9d) and is
# hard-coded below, so a change to the default path fails here.
la_fixture <- function() {
  ref <- data.table::rbindlist(list(
    la_seat(c(0.30, 0.50, 0.70), c(800, 1200, 600)),
    la_seat(0.45, 3000, "early", "early"), la_seat(0.55, 900, "postal", "postal")))
  live <- data.table::rbindlist(list(
    la_seat(c(0.36, 0.52, 0.66), c(850, 1250, 640)),
    la_seat(0.50, 3600, "early", "early"), la_seat(0.58, 950, "postal", "postal")))
  live <- rbind(live, data.table::data.table(unit = c("B1", "B2", "B3", "early", "postal"), booth_type = c("ordinary", "ordinary", "ordinary", "early", "postal"),
                                             cls = "ONP", v = c(80, 90, 40, 300, 60)))
  gap <- data.table::data.table(booth_type = c("early", "postal"), cls = c("LNP", "LNP"), gap = c(0.03, 0.05))
  lean <- data.table::data.table(unit = c("B1", "B2", "B3", "early", "postal"), cls = "ONP", share = c(0.08, 0.06, 0.05, 0.07, 0.06))
  list(ref = ref, live = live, gap = gap, lean = lean)
}
LA_OLD_PROJ <- c(3554.21806167401, 4018.56299559471, 582.728281938326)   # 403f3f9d, scratch script old_vals.R
LA_OLD_CS <- 0.28375

test_that("switches off reproduce the pre-lane-A code on a fixture with every existing option", {
  f <- la_fixture()
  p <- project_seat_from_booths(f$live, f$ref, c("B1", "B2"), type_gap = f$gap, total = "expected", expected_total = 8000, lean = f$lean)
  p <- p[order(cls)]
  expect_identical(p$cls, c("ALP", "LNP", "ONP"))
  expect_equal(p$projected, LA_OLD_PROJ, tolerance = 1e-12)
  expect_equal(p$counted_share[1], LA_OLD_CS, tolerance = 1e-12)
})

test_that("rep_sd is finite on a fully counted seat; the flag parser is strict", {
  f <- la_fixture()
  pd <- project_seat_from_booths(f$live, f$ref, unique(f$live$unit), diag = TRUE)
  expect_true(all(pd$n_ord == 0L) && all(is.finite(pd$swing_sd)))
  expect_null(night_lane_a_args())
  expect_identical(night_lane_a_args("5", "1", "3", "0.1,0.2"), list(booth_reg_k = 5, booth_reg_all = TRUE, type_pool_k = 3, rep_sd = c(0.1, 0.2)))
  expect_error(night_lane_a_args(rep_sd = "0.1"), "NX30")
  expect_error(night_lane_a_args(booth_reg_all = "1"), "NX30")
  expect_error(night_lane_a_args(type_pool = "-1"), "NX30")
})
