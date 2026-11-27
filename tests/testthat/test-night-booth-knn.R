# Lane F: the per-booth best guess, project_seat_from_booths(booth_knn = list(h, k, size_w, types)).
# Synthetic seats, no data files. Expected values come from an independent by-hand version of the formula in
# docs/plans/prereg-night-booth-guess-2026-11-28.md (LNP class only), not from the package code.

mk_seat <- function(shares_by_unit) {
  data.table::rbindlist(lapply(names(shares_by_unit), function(u) {
    x <- shares_by_unit[[u]]
    data.table::data.table(unit = u, booth_type = x[[1]], cls = c("ALP", "LNP", "GRN"), v = as.numeric(x[-1]))
  }))
}

# Town booths: 1000 votes, LNP 30% in the reference, +8 points live. Country booths: 300 votes, LNP 70%, -15 points live.
# An uncounted unit's live rows are its reference rows (their values are never read).
bk_ref <- list(T1 = list("ordinary", 700, 300, 0), T2 = list("ordinary", 700, 300, 0), T3 = list("ordinary", 700, 300, 0),
               C1 = list("ordinary", 90, 210, 0), C2 = list("ordinary", 90, 210, 0), C3 = list("ordinary", 90, 210, 0))
bk_live <- bk_ref
for (u in c("T1", "T2")) bk_live[[u]] <- list("ordinary", 620, 380, 0)
for (u in c("C1", "C2")) bk_live[[u]] <- list("ordinary", 135, 165, 0)
bk_cnt <- c("T1", "T2", "C1", "C2")
bk_cfg <- function(h = 10, k = 1, size_w = 10, types = FALSE) list(h = h, k = k, size_w = size_w, types = types)
lnp <- function(p) p[p$cls == "LNP"]$projected

# By-hand lane F, LNP class. `nm` = ordinary units in the seat, `cnt` = those counted. Returns the base swing, the guessed
# swing of each uncounted ordinary booth, and the reference-vote-weighted swing over all ordinary booths (counted own,
# uncounted guessed).
hand_knn <- function(nm, cnt, h, k, size_w, ref = bk_ref, live = bk_live) {
  RT <- vapply(nm, function(u) sum(unlist(ref[[u]][-1])), 0); LT <- vapply(nm, function(u) sum(unlist(live[[u]][-1])), 0)
  X <- t(vapply(nm, function(u) unlist(ref[[u]][-1]) / sum(unlist(ref[[u]][-1])), numeric(3)))
  rl <- vapply(nm, function(u) ref[[u]][[3]], 0); ll <- vapply(nm, function(u) live[[u]][[3]], 0)
  names(rl) <- names(ll) <- nm
  y <- ll / LT - rl / RT
  base <- sum(ll[cnt]) / sum(LT[cnt]) - sum(rl[cnt]) / sum(RT[cnt])
  med <- median(RT)
  unc <- setdiff(nm, cnt)
  G <- vapply(unc, function(u) {
    d2 <- vapply(cnt, function(j) sum((100 * (X[u, ] - X[j, ]))^2) + (size_w * (log(RT[u]) - log(RT[j])))^2, 0)
    w <- LT[cnt] / med * exp(-d2 / (2 * h^2))
    base + sum(w * (y[cnt] - base)) / (sum(w) + k)
  }, 0)
  S <- y; S[cnt] <- y[cnt]; S[unc] <- G
  list(base = base, G = G, ow = sum(S * RT) / sum(RT))
}

test_that("booth_knn = NULL is byte-identical to omitting it, and a real config changes the answer", {
  nm <- c(bk_cnt, "T3", "C3")
  live <- mk_seat(bk_live[nm]); ref <- mk_seat(bk_ref[nm])
  p0 <- project_seat_from_booths(live, ref, bk_cnt)
  expect_identical(project_seat_from_booths(live, ref, bk_cnt, booth_knn = NULL), p0)
  p1 <- project_seat_from_booths(live, ref, bk_cnt, booth_knn = bk_cfg())
  expect_false(isTRUE(all.equal(lnp(p1), lnp(p0), tolerance = 1e-6)))
})

test_that("uncounted town and country booths each take their own cluster's swing, as the formula says", {
  for (g in c("T3", "C3")) {
    nm <- c(bk_cnt, g)
    live <- mk_seat(bk_live[nm]); ref <- mk_seat(bk_ref[nm])
    cfg <- bk_cfg(h = 10, k = 1, size_w = 10, types = FALSE)
    hk <- hand_knn(nm, bk_cnt, 10, 1, 10)
    size <- sum(unlist(bk_ref[[g]][-1])); ref_sh <- bk_ref[[g]][[3]] / size
    counted_lnp <- sum(vapply(bk_cnt, function(u) bk_live[[u]][[3]], 0))
    got <- lnp(project_seat_from_booths(live, ref, bk_cnt, booth_knn = cfg)) - counted_lnp
    expect_equal(got, (ref_sh + hk$G[[g]]) * size, tolerance = 1e-6, info = g)
    pooled <- lnp(project_seat_from_booths(live, ref, bk_cnt)) - counted_lnp
    expect_equal(pooled, (ref_sh + hk$base) * size, tolerance = 1e-6, info = g)
    if (g == "T3") {
      expect_gt(hk$G[[g]], hk$base + 0.01)      # pulled towards the town swing (+8), above the pooled swing
      expect_gt(got, pooled + 5)
    } else {
      expect_lt(hk$G[[g]], hk$base - 0.01)      # pulled towards the country swing (-15), below the pooled swing
      expect_lt(got, pooled - 3)
    }
  }
  # k = 0 and a tight bandwidth: the guess sits on the cluster's own swing (+8 for the town booth, -15 for the country one)
  nm <- c(bk_cnt, "T3"); live <- mk_seat(bk_live[nm]); ref <- mk_seat(bk_ref[nm])
  got <- lnp(project_seat_from_booths(live, ref, bk_cnt, booth_knn = bk_cfg(k = 0))) - 1090
  expect_equal(got, (0.30 + 0.08) * 1000, tolerance = 1e-6)
  nm <- c(bk_cnt, "C3"); live <- mk_seat(bk_live[nm]); ref <- mk_seat(bk_ref[nm])
  got <- lnp(project_seat_from_booths(live, ref, bk_cnt, booth_knn = bk_cfg(k = 0))) - 1090
  expect_equal(got, (0.70 - 0.15) * 300, tolerance = 1e-6)
})

test_that("a booth with no similar counted booth keeps the pooled swing", {
  ref_l <- c(bk_ref, list(F = list("ordinary", 50, 950, 0))); live_l <- c(bk_live, list(F = list("ordinary", 50, 950, 0)))
  nm <- c(bk_cnt, "F"); live <- mk_seat(live_l[nm]); ref <- mk_seat(ref_l[nm])
  hk <- hand_knn(nm, bk_cnt, 3, 1, 10, ref = ref_l, live = live_l)
  got <- lnp(project_seat_from_booths(live, ref, bk_cnt, booth_knn = bk_cfg(h = 3))) - 1090
  expect_equal(hk$G[["F"]], hk$base, tolerance = 1e-9)   # the by-hand weights vanish
  expect_equal(got, (0.95 + hk$base) * 1000, tolerance = 1e-6)
  pooled <- lnp(project_seat_from_booths(live, ref, bk_cnt)) - 1090
  expect_equal(got, pooled, tolerance = 1e-6)
})

test_that("types = TRUE gives an uncounted early unit the weighted swing of all ordinary booths; FALSE keeps the all-types swing", {
  nm <- c(bk_cnt, "T3", "C3")
  early <- list(early = list("early", 1200, 800, 0))
  live_w <- mk_seat(c(bk_live[nm], early)); ref_w <- mk_seat(c(bk_ref[nm], early))
  live_o <- mk_seat(bk_live[nm]); ref_o <- mk_seat(bk_ref[nm])
  hk <- hand_knn(nm, bk_cnt, 10, 1, 10)
  early_proj <- function(types) {
    cfg <- bk_cfg(types = types)
    lnp(project_seat_from_booths(live_w, ref_w, bk_cnt, booth_knn = cfg)) - lnp(project_seat_from_booths(live_o, ref_o, bk_cnt, booth_knn = cfg))
  }
  expect_equal(early_proj(TRUE), (0.4 + hk$ow) * 2000, tolerance = 1e-6)
  expect_equal(early_proj(FALSE), (0.4 + hk$base) * 2000, tolerance = 1e-6)
  expect_gt(abs(hk$ow - hk$base), 0.003)   # the two rules must differ for this check to bite
})

test_that("a counted early unit keeps its own early swing under types = TRUE", {
  nm <- c(bk_cnt, "T3", "C3")
  e1r <- list(early = list("early", 1200, 800, 0)); e1l <- list(early = list("early", 1000, 1000, 0))   # counted, LNP +10 points
  e2 <- list(early2 = list("early", 600, 400, 0))                                                        # uncounted, same type
  cnt <- c(bk_cnt, "early")
  live_w <- mk_seat(c(bk_live[nm], e1l, e2)); ref_w <- mk_seat(c(bk_ref[nm], e1r, e2))
  live_o <- mk_seat(c(bk_live[nm], e1l)); ref_o <- mk_seat(c(bk_ref[nm], e1r))
  cfg <- bk_cfg(types = TRUE)
  got <- lnp(project_seat_from_booths(live_w, ref_w, cnt, booth_knn = cfg)) - lnp(project_seat_from_booths(live_o, ref_o, cnt, booth_knn = cfg))
  expect_equal(got, (0.40 + 0.10) * 1000, tolerance = 1e-6)
})

test_that("bad configs and flags raise NX32", {
  nm <- c(bk_cnt, "T3"); live <- mk_seat(bk_live[nm]); ref <- mk_seat(bk_ref[nm])
  expect_error(project_seat_from_booths(live, ref, bk_cnt, booth_knn = bk_cfg(), booth_reg = list(k = 1, pool = NULL)), "NX32")
  bad <- list(list(h = 10, k = 1, size_w = 10), bk_cfg(h = 0), bk_cfg(k = -1), bk_cfg(size_w = -1), bk_cfg(types = 1),
              bk_cfg(types = NA), bk_cfg(h = c(1, 2)), "10,1,10,1", bk_cfg(h = Inf))
  for (b in bad) expect_error(project_seat_from_booths(live, ref, bk_cnt, booth_knn = b), "NX32")
  expect_error(.night_booth_knn_cfg("10,1,10"), "NX32")
  expect_error(.night_booth_knn_cfg("0,1,10,1"), "NX32")
  expect_error(.night_booth_knn_cfg("10,1,10,2"), "NX32")
  expect_equal(night_lane_a_args(booth_knn = "10,1,10,1")$booth_knn, list(h = 10, k = 1, size_w = 10, types = TRUE))
  expect_equal(night_lane_a_args(booth_knn = "10,1,10,0")$booth_knn$types, FALSE)
  expect_null(night_lane_a_args(booth_knn = "off"))
})
