# Arm SPL (R/seat_paid_lean.R; plans/prereg-seat-paid-lean-2026-11-14.md). Synthetic polls only.

spl_raw <- function() {
  row <- function(pid, seat, group, sponsor, fp) data.table::data.table(poll_id = pid, seat = seat, group = group,
    sponsor = sponsor, class = names(fp), fp = unname(fp))
  data.table::rbindlist(list(
    row("p1", "A", "direct_stake", "Advance", c(ALP = 30, LNP = 50, GRN = 10, OTH = 10)),       # LNP 50 vs 40
    row("p2", "B", "direct_stake", "Climate 200", c(LNP = 40)),                                 # no IND figure, no tcp
    row("i1", "A", "direct_indep", NA, c(ALP = 34, LNP = 42, GRN = 12, OTH = 12)),
    row("i2", "B", "direct_indep", NA, c(ALP = 30, LNP = 44, GRN = 14, OTH = 12))))
}
# sides passed in: R CMD check's package copy has no external/sponsor_side.csv (memory: repo-file tests)
SPL_SIDES <- c(p1 = "LNP", p2 = "IND")
spl_act <- data.table::data.table(seat = rep(c("A", "B"), each = 4), party = rep(c("ALP", "LNP", "GRN", "OTH"), 2),
                                  share = c(35, 40, 12, 13, 31, 42, 14, 13))

test_that("a paid poll's side gap is measured against the result, net of the independent polls' shrunk mean", {
  m <- seat_paid_lean_measure(spl_raw(), spl_act, sides = SPL_SIDES)
  expect_identical(m$poll_id, "p1")                      # the Climate 200 poll has no IND figure and no tcp: not measured
  expect_equal(m$gap, 10)
  # independent LNP gaps +2 and +2: mean 2, shrunk by 2/(2+3)
  expect_equal(m$base, 2 * 2 / 5)
  expect_equal(m$net, 10 - 0.8)
  expect_equal(attr(m, "ind_df"), 1L)
})

test_that("the two-candidate figure is used when the primaries are incomplete and the pair is the final pair", {
  tcp <- data.table::data.table(seat = c("B", "B"), party = c("LNP", "IND"), tshare = c(48, 52))
  tr <- data.table::data.table(poll_id = "p2", pa = "IND", pb = "LNP", tcp_a = 55)
  m <- seat_paid_lean_measure(spl_raw(), spl_act, tcp, tr, sides = SPL_SIDES)
  expect_equal(m$gap[m$poll_id == "p2"], 3)
  expect_identical(m$how[m$poll_id == "p2"], "tcp")
})

test_that("the fit finds a real lean per side, keeps sides apart, and the independent noise prior widens a thin fit", {
  set.seed(3)
  dev <- data.table::data.table(side = rep(c("LNP", "ALP+GRN"), each = 20), cluster = paste0("c", 1:40),
                                net = c(stats::rnorm(20, 4, 4), stats::rnorm(20, 4, 4)))
  f <- seat_paid_lean_fit(dev)
  expect_true(all(f$lean$shrunk > 2.5))
  # a side with no lean of its own is not pulled up by another side's (amendment 3: no pooling across sides)
  dev2 <- data.table::copy(dev); dev2$net[dev2$side == "ALP+GRN"] <- stats::rnorm(20, 0, 4)
  f2 <- seat_paid_lean_fit(dev2)
  expect_lt(abs(f2$lean$shrunk[f2$lean$side == "ALP+GRN"]), 1)
  expect_gt(f2$lean$shrunk[f2$lean$side == "LNP"], 2.5)
  thin <- dev[c(1, 2, 21)]                                # three polls: noise from them alone is not to be trusted
  expect_gt(seat_paid_lean_fit(thin, s2_ind = 100, df_ind = 50)$se_mu, seat_paid_lean_fit(thin)$se_mu)
  expect_identical(seat_paid_lean_fit(dev[0])$mu_s, 0)
})

test_that("apply takes the lean off the side's figures and gives it to the rest; unmeasurable sides are left alone", {
  fit <- list(lean = data.table::data.table(side = "LNP", n = 5L, k = 3L, m = 4, se = 1, w = 1, shrunk = 4), mu_s = 3)
  r <- spl_raw()
  r <- data.table::rbindlist(list(r, data.table::data.table(poll_id = "p3", seat = "A", group = "direct_stake",
                                  sponsor = "Liberals against Nuclear", class = c("ALP", "LNP"), fp = c(40, 60))))
  out <- seat_paid_lean_apply(r, fit, sides = c(SPL_SIDES, p3 = "UNKNOWN"))
  p1 <- out[out$poll_id == "p1"]
  expect_equal(p1$fp[p1$class == "LNP"], 46)
  expect_equal(sum(p1$fp), 100)
  expect_equal(p1$fp[p1$class == "ALP"], 30 + 4 * 30 / 50)
  expect_identical(out$fp[out$poll_id %in% c("p2", "p3")], r$fp[r$poll_id %in% c("p2", "p3")])   # IND w/o IND, UNKNOWN
  expect_identical(out$fp[out$group == "direct_indep"], r$fp[r$group == "direct_indep"])
  expect_identical(attr(out, "moved"), "p1")
  # a poll naming only the sponsor's party (Hawthorn 2026: LNP 41) takes the whole lean off it
  h <- data.table::data.table(poll_id = "h", seat = "H", group = "direct_stake", sponsor = "Liberal Party", class = "LNP", fp = 41)
  expect_equal(seat_paid_lean_apply(h, fit, sides = c(h = "LNP"))$fp, 41 - 4)
  # a partial poll (no GRN) takes the whole lean, not the lean scaled by its 60-point total
  pp <- data.table::data.table(poll_id = "q", seat = "Q", group = "direct_stake", sponsor = "Advance", class = c("LNP", "ALP"), fp = c(40, 20))
  expect_equal(seat_paid_lean_apply(pp, fit, sides = c(q = "LNP"))$fp, c(36, 24))
  # a lean bigger than the side's only figure takes it to zero, never below
  small <- data.table::data.table(poll_id = "s", seat = "S", group = "direct_stake", sponsor = "Advance", class = "LNP", fp = 3)
  expect_equal(seat_paid_lean_apply(small, fit, sides = c(s = "LNP"))$fp, 0)
  # a side listed at 0% is left alone (no 0/0)
  zero <- data.table::data.table(poll_id = "z", seat = "Z", group = "direct_stake", sponsor = "x", class = c("LNP", "ALP"), fp = c(0, 50))
  zo <- seat_paid_lean_apply(zero, fit, sides = c(z = "LNP"))
  expect_identical(zo$fp, c(0, 50)); expect_identical(attr(zo, "moved"), character(0))
  # a known side with no row of its own gets none (amendment 3)
  r2 <- data.table::copy(r); r2$sponsor[r2$poll_id == "p1"] <- "Australia Institute"   # ALP+GRN: no row
  o2 <- seat_paid_lean_apply(r2, fit, sides = c(p1 = "ALP+GRN", p2 = "IND", p3 = "UNKNOWN"))
  expect_identical(o2$fp[o2$poll_id == "p1"], r2$fp[r2$poll_id == "p1"])
})

test_that("sponsor names map to sides through sponsor_side.csv", {
  skip_if_not(file.exists(file.path(pkg_root(), "external", "reference", "polls", "sponsor_side.csv")), "sponsor_side.csv not in this copy")
  r <- spl_raw()
  expect_identical(paid_poll_side(c("Advance", "Climate 200", "Liberal Party", "Australia Institute")),
                   c("LNP", "IND", "LNP", "ALP+GRN"))
  expect_identical(seat_paid_lean_measure(r, spl_act)$side, seat_paid_lean_measure(r, spl_act, sides = SPL_SIDES)$side)
})

test_that("the switch accepts only 0 or 1", {
  withr::local_envvar(AUSPOL_SEAT_POLL_PAID_LEAN = "yes")
  expect_error(.seat_paid_lean_on(), "must be")
})
