# Lane D (docs/plans/prereg-night-lane-d-2026-11-28.md): vote-type uncertainty until the type reports (D1) and a
# fat-tailed prior-projection combine (D2). Synthetic booths; no anchor data.

ld_seat <- function(lnp_share, size, types, units) {
  data.table::rbindlist(lapply(seq_along(units), function(i) data.table::data.table(
    unit = units[i], booth_type = types[i], cls = c("LNP", "ALP"), v = round(size[i] * c(lnp_share[i], 1 - lnp_share[i])))))
}
ty <- c("ordinary", "ordinary", "early", "postal"); un <- c("B1", "B2", "early", "postal")

test_that("D1 off is identical; on it adds variance for uncounted types only, zero once every type has reported", {
  ref <- ld_seat(c(0.5, 0.5, 0.5, 0.5), c(1000, 1000, 3000, 500), ty, un)
  live <- ld_seat(c(0.55, 0.55, 0.60, 0.50), c(1000, 1000, 3000, 500), ty, un)
  p0 <- project_seat_from_booths(live, ref, c("B1", "B2"))
  expect_identical(project_seat_from_booths(live, ref, c("B1", "B2"), type_sd = NULL), p0)
  k <- c(early = 8, postal = 10)
  p1 <- project_seat_from_booths(live, ref, c("B1", "B2"), type_sd = k)
  expect_equal(p1$projected, p0$projected)                         # adds a column, moves nothing
  # by hand: early 3000 and postal 500 of a 5500-vote seat (growth 1), p = projected share
  pr <- p0$projected / sum(p0$projected)
  want <- (8^2 * (3000 / 5500)^2 + 10^2 * (500 / 5500)^2) * pr * (1 - pr)
  expect_equal(p1$type_var, want, tolerance = 1e-6)
  # the early block reported: only postal remains
  p2 <- project_seat_from_booths(live, ref, c("B1", "B2", "early"), type_sd = k)
  expect_equal(p2$type_var, 10^2 * (500 / 5500)^2 * pr * (1 - pr), tolerance = 0.02)
  expect_true(all(p2$type_var < p1$type_var))
  # every unit reported: zero (and the early-return path carries the column)
  p3 <- project_seat_from_booths(live, ref, un, type_sd = k)
  expect_equal(p3$type_var, c(0, 0))
  # only ordinary booths still to come: zero
  p4 <- project_seat_from_booths(live, ref, c("B1", "early", "postal"), type_sd = k)
  expect_equal(p4$type_var, c(0, 0))
})

test_that("D1: a partly counted type shrinks with its counted share", {
  # two early units: one counted, one not (a type with counted units uses its own swing, so the term is scaled down)
  t2 <- c("ordinary", "early", "early"); u2 <- c("B1", "E1", "E2")
  ref <- ld_seat(c(0.5, 0.5, 0.5), c(1000, 1000, 1000), t2, u2); live <- ld_seat(c(0.55, 0.6, 0.6), c(1000, 1000, 1000), t2, u2)
  a <- project_seat_from_booths(live, ref, "B1", type_sd = c(early = 8))
  b <- project_seat_from_booths(live, ref, c("B1", "E1"), type_sd = c(early = 8))
  pr_b <- b$projected / sum(b$projected)
  expect_equal(b$type_var, 64 * (1000 / 3000)^2 * 0.5 * pr_b * (1 - pr_b), tolerance = 1e-6)
  expect_true(all(b$type_var < a$type_var))
})

test_that("D2 reduces to the normal combine as df grows, and leaves an agreeing projection's mean at the prior", {
  n <- combine_prior_projection(48, 52, 3, 2)
  t_inf <- combine_prior_projection_t(48, 52, 3, 2, Inf)
  expect_equal(t_inf$mean, n$mean); expect_equal(t_inf$sd, n$sd)
  t_big <- combine_prior_projection_t(48, 52, 3, 2, 1e6, k = 200)
  expect_equal(t_big$mean, n$mean, tolerance = 1e-3); expect_equal(t_big$sd, n$sd, tolerance = 1e-2)
  agree <- combine_prior_projection_t(50, 50, 3, 2, 4.76)
  expect_equal(agree$mean, 50)
  # a projection far from the prior moves the posterior LESS than a normal would (fat tails down-weight it)
  far_n <- combine_prior_projection(40, 60, 3, 2); far_t <- combine_prior_projection_t(40, 60, 3, 2, 4.76)
  expect_lt(far_t$mean, far_n$mean)
})

test_that("night_booth_update: lane D switches off are identical; on they widen / change the update; args parse", {
  mk <- function(alp, lnp, d, bt = "ordinary", b = paste0("B", seq_along(alp))) data.table::rbindlist(lapply(seq_along(alp), function(i) data.table::data.table(
    district = d, booth = b[i], booth_type = bt[pmin(i, length(bt))], party = c("Australian Labor Party", "Liberal"), votes = c(alp[i], lnp[i]))))
  bt <- c("ordinary", "ordinary", "ordinary", "early"); bb <- c("B1", "B2", "B3", "early")
  ref <- rbind(mk(c(200, 400, 600, 3000), c(800, 600, 400, 3000), "Seat A", bt, bb), mk(c(300, 500, 700, 2000), c(700, 500, 300, 2000), "Seat B", bt, bb))
  live <- rbind(mk(c(300, 450, 600, 3300), c(700, 550, 400, 2700), "Seat A", bt, bb), mk(c(400, 550, 700, 2100), c(600, 450, 300, 1900), "Seat B", bt, bb))
  sh <- matrix(c(50, 50, 50, 50), 2, dimnames = list(c("Seat A", "Seat B"), c("ALP", "LNP"))); psd <- matrix(4, 2, 2, dimnames = dimnames(sh))
  rp <- data.table::data.table(district = c("Seat A", "Seat A", "Seat B", "Seat B"), unit = c("B1", "B2", "B1", "B2"))
  u0 <- night_booth_update(sh, psd, 1, live, ref, reported = rp)
  expect_identical(night_booth_update(sh, psd, 1, live, ref, reported = rp, type_sd = NULL, proj_tails = "normal"), u0)
  expect_identical(night_booth_update(sh, psd, 1, live, ref, reported = rp, type_sd = "off"), u0)
  u1 <- night_booth_update(sh, psd, 1, live, ref, reported = rp, type_sd = "on")
  expect_true(all(u1$sd > u0$sd))                                  # the uncounted early block widens the posterior
  u2 <- night_booth_update(sh, psd, 1, live, ref, reported = rp, proj_tails = "t")
  expect_false(isTRUE(all.equal(u2$shares, u0$shares)))
  # every unit reported: D1 adds nothing
  rp_all <- data.table::data.table(district = rep(c("Seat A", "Seat B"), each = 4), unit = rep(bb, 2))
  expect_equal(night_booth_update(sh, psd, 1, live, ref, reported = rp_all, type_sd = "on")$sd,
               night_booth_update(sh, psd, 1, live, ref, reported = rp_all)$sd)
  expect_null(night_lane_a_args(type_sd = "off", proj_tails = "normal"))
  expect_identical(night_lane_a_args(type_sd = "on", proj_tails = "t"), list(type_sd = "on", proj_tails = "t"))
  expect_error(night_lane_a_args(proj_tails = "cauchy"), "NX30")
  expect_error(night_lane_a_args(type_sd = "big"), "NX31")
  expect_equal(.night_type_sd_k("3")[["early"]], 3)
})
