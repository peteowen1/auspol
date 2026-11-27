#' Match one election's booth units to a reference election's
#'
#' A unit is an ordinary voting centre (keyed by name) or a declaration vote
#' type (`early`, `postal`, `absent`, `provisional`, `marked_as_voted`).
#' Matched in-district by name first, then, for ordinary booths only, by a
#' name that is unique statewide in the reference (booths keep their names
#' across a redistribution). Everything else is unmatched and projected from
#' the seat's counted share at apply time.
#'
#' @param live,ref data.tables with `district, unit, booth_type` (any other
#'   columns ignored). `live` is the election being counted, `ref` the one
#'   the swing is measured against.
#' @return data.table `district, unit, booth_type, ref_district, ref_unit`,
#'   one row per matched live unit.
#' @export
match_booth_units <- function(live, ref) {
  Lu <- unique(data.table::as.data.table(live)[, c("district", "unit", "booth_type"), with = FALSE])
  Ru <- unique(data.table::as.data.table(ref)[, c("district", "unit", "booth_type"), with = FALSE])
  m1 <- merge(Lu, Ru[, .(district, unit, ref_district = district, ref_unit = unit)], by = c("district", "unit"))
  Ro <- Ru[Ru$booth_type == "ordinary"]; Ro[, .n := .N, by = unit]
  uniq <- Ro[.n == 1, .(unit, ref_district2 = district, ref_unit2 = unit)]
  rest <- Lu[!m1, on = c("district", "unit")][booth_type == "ordinary"]
  m2 <- merge(rest, uniq, by = "unit")[, .(district, unit, booth_type, ref_district = ref_district2, ref_unit = ref_unit2)]
  rbind(m1[, .(district, unit, booth_type, ref_district, ref_unit)], m2)
}

#' Project a seat's final first preferences from the booths counted so far
#'
#' `projected_final = counted votes + uncounted units projected from their
#' reference result shifted by the seat's counted swing`, where the swing
#' for a class is the share-point change on matched counted units, pooled
#' by booth type when that type has counted units and over all types
#' otherwise. Uncounted units with no reference, and classes with no
#' reference presence in the seat, take the seat's counted share.
#'
#' @param live data.table of ONE seat: `unit, booth_type, cls, v` (votes so
#'   far for counted units; the full result in a replay).
#' @param ref data.table of the same seat's matched reference rows, keyed to
#'   the LIVE unit names: `unit, booth_type, cls, v`.
#' @param counted_units character vector of live units already reported.
#' @param type_gap Optional data.table `booth_type, cls, gap`: for a booth type with NO counted
#'   unit in this seat, its swing is the seat's all-types swing PLUS this gap (the type's swing
#'   relative to ordinary booths, measured in other seats and shrunk; issue #160). `NULL` (the
#'   default) is byte-identical to the previous behaviour.
#' @param total `"table"` (default): counted share is counted votes over the votes in `live`. `"projected"`: over
#'   counted votes plus the projected size of the uncounted units (a live feed has no final total). `"expected"`: over
#'   `expected_total` (enrolment x turnout), and the uncounted units' projected sizes are rescaled to sum to what is
#'   left of it (`expected_total` minus counted, floored at 0); with `expected_total` NA or not positive it behaves as `"projected"`.
#' @param expected_total Expected final votes of the seat, for `total = "expected"`.
#' @param lean Optional data.table `unit, cls, share` for ONE seat, keyed to the live unit names: each class's share
#'   (0-1) at each unit in another count of the reference election ([night_council_lean()], the upper house). Used
#'   only for a class with NO reference votes in the seat: its swing is measured on the counted units that have a
#'   lean (counted share minus lean share, weighted by this year's unit totals), and each uncounted unit with a lean
#'   is projected at its lean share plus that swing, instead of the seat's counted share. `NULL` (the default) is
#'   byte-identical to the previous behaviour.
#' @param early_frac Optional share (0-1) of the seat's early vote counted so far ([night_early_frac()]). The early
#'   unit is ONE unit per district and counts as reported once any early voting centre has reported; with
#'   `early_frac` below 1 the unreported remainder (counted early votes x (1 - f) / f) is projected from the
#'   reference early block's shares plus the early swing, instead of being left out. `NA` (the default) is
#'   byte-identical to the previous behaviour.
#' @param booth_reg Lane A1 (`docs/plans/prereg-night-lane-a-2026-11-27.md`). `NULL` (default) is byte-identical. A list
#'   `list(k = <booths>, pool = data.table(cls, beta))`: each uncounted ORDINARY booth's swing is the seat's ordinary swing
#'   plus `beta * (its reference share - the counted booths' reference share)`, where `beta` is the slope of counted
#'   ordinary booths' swing on their reference share (weighted by this year's booth totals), partial-pooled toward the
#'   cross-seat slope `pool$beta` (0 if absent) by `n / (n + k)`, `n` the seat's counted ordinary booths. Clipped to
#'   `[-1, 1]`. A booth strong for a class last time does not get the same swing as a weak one.
#' @param type_pool_k Lane A2. `NULL` (default) is byte-identical. A number `k >= 0`: each booth type's swing is its own
#'   counted swing partial-pooled toward a pooled estimate, `w = m / (m + k)` with `m` its counted votes in units of the
#'   seat's median ordinary booth; the pooled estimate is the seat's ordinary-equivalent swing (every counted type's
#'   swing minus its `type_gap`, weighted by counted votes) plus the type's own `type_gap` (0 without one). So a seat
#'   with only its early vote in projects its ordinary booths at the early swing minus the early gap, not at the raw early swing.
#' @param diag `TRUE` adds columns `n_ord` (counted ordinary booths with a reference), `rep_dist` (reference-share
#'   distance, points, between the uncounted units and the counted ones, size-weighted), `swing_sd` (spread, points, of
#'   the counted ordinary booths' swings) and `unc_frac` (projected share of the seat's votes still to come). `FALSE`
#'   (default) returns the columns as before.
#' @return data.table `cls, projected, counted_share`, or `NULL` if no
#'   counted unit has a reference (nothing to measure a swing on).
#' @export
project_seat_from_booths <- function(live, ref, counted_units, type_gap = NULL, total = c("table", "projected", "expected"), expected_total = NA_real_,
                                     lean = NULL, early_frac = NA_real_, booth_reg = NULL, type_pool_k = NULL, diag = FALSE) {
  total <- match.arg(total)
  live <- data.table::as.data.table(live); ref <- data.table::as.data.table(ref)
  classes <- unique(live$cls)
  units <- unique(live[, .(unit, booth_type)])
  units[, counted := unit %in% counted_units]
  ref_tot <- ref[, .(rt = sum(v)), by = unit]
  live_tot <- live[, .(lt = sum(v)), by = unit]
  mc <- merge(live[unit %in% counted_units], ref[, .(unit, cls, rv = v)], by = c("unit", "cls"))
  if (!nrow(mc)) return(NULL)
  mc <- merge(mc, ref_tot, by = "unit"); mc <- merge(mc, live_tot, by = "unit")
  sw_t <- mc[, .(sw = sum(v) / sum(lt) - sum(rv) / sum(rt)), by = .(booth_type, cls)]
  sw_a <- mc[, .(sw_all = sum(v) / sum(lt) - sum(rv) / sum(rt)), by = cls]
  growth <- sum(mc[, .(lt = lt[1]), by = unit]$lt) / sum(mc[, .(rt = rt[1]), by = unit]$rt)
  # PARTLY COUNTED EARLY UNIT (early_frac < 1): the early voting centres still to report, projected from the reference
  # early block plus the early swing; and the growth rate counts the early unit at its full expected size, so a
  # half-reported early unit does not shrink every uncounted booth.
  er <- NULL
  f_e <- suppressWarnings(as.numeric(early_frac)[1])
  if (isTRUE(is.finite(f_e) && f_e > 0 && f_e < 1) && "early" %in% counted_units && "early" %in% ref$unit) {
    ce <- live[live$unit == "early"]; cev <- sum(ce$v)
    re <- ref[ref$unit == "early"]; ret <- sum(re$v)
    rest <- cev * (1 - f_e) / f_e
    if (rest > 0 && ret > 0 && cev > 0) {
      base_e <- stats::setNames(re$v / ret, re$cls)
      swe_t <- sw_t[sw_t$booth_type == "early"]; swe <- stats::setNames(swe_t$sw, swe_t$cls)
      ce_sh <- stats::setNames(ce$v / cev, ce$cls)
      sh_e <- vapply(classes, function(c0) {
        if (c0 %in% names(base_e)) max(0, base_e[[c0]] + (if (c0 %in% names(swe)) swe[[c0]] else 0))
        else if (c0 %in% names(ce_sh)) ce_sh[[c0]] else 0
      }, numeric(1))
      if (sum(sh_e) > 0) er <- data.table::data.table(cls = classes, v = rest * sh_e / sum(sh_e))
      ut <- mc[, .(lt = lt[1], rt = rt[1]), by = unit]
      growth <- (sum(ut$lt) + rest * ("early" %in% ut$unit)) / sum(ut$rt)
    }
  }
  counted_share <- sum(live[unit %in% counted_units]$v) / sum(live$v)
  unc <- units[counted == FALSE]
  if (!nrow(unc)) {
    out0 <- live[, .(projected = sum(v)), by = cls]
    if (!is.null(er)) out0 <- rbind(out0[, .(cls, v = projected)], er)[, .(projected = sum(v)), by = cls]
    cs_all <- if (is.null(er)) 1 else { cv_all <- sum(live[unit %in% counted_units]$v)
      if (total == "expected" && is.finite(expected_total) && expected_total > 0) min(1, cv_all / expected_total) else cv_all / (cv_all + sum(er$v)) }
    out0[, counted_share := cs_all]
    if (isTRUE(diag)) out0[, `:=`(n_ord = NA_integer_, swing_sd = NA_real_, rep_dist = 0, unc_frac = 1 - cs_all)]
    return(out0[])
  }
  grid <- data.table::CJ(unit = unc$unit, cls = classes); grid <- merge(grid, unc, by = "unit")
  grid <- merge(grid, ref[, .(unit, cls, rv = v)], by = c("unit", "cls"), all.x = TRUE)
  grid <- merge(grid, ref_tot, by = "unit", all.x = TRUE)
  grid <- merge(grid, sw_t, by = c("booth_type", "cls"), all.x = TRUE); grid <- merge(grid, sw_a, by = "cls", all.x = TRUE)
  if (!is.null(type_gap) && nrow(type_gap)) {
    # An update join, NOT merge(): merge() re-sorts the rows by its keys, and `has_ref` below is a
    # vector aligned to grid's row order across the later merge by `cls` -- re-sorting by booth type
    # here misaligned it and returned NA projections for 28 of 88 seats (found on the first replay).
    tg <- data.table::as.data.table(type_gap)
    grid[, gap := NA_real_]
    grid[tg, on = c("booth_type", "cls"), gap := i.gap]
    grid[is.na(sw) & !is.na(gap), sw := sw_all + gap]
    grid[, gap := NULL]
  }
  grid[is.na(sw), sw := sw_all]; grid[is.na(sw), sw := 0]; grid[is.na(rv), rv := 0]
  # LANE A2: each type's swing partial-pooled toward the seat's ordinary-equivalent swing plus the type's pooled gap.
  if (!is.null(type_pool_k)) {
    stopifnot(is.numeric(type_pool_k), length(type_pool_k) == 1L, type_pool_k >= 0)
    GP <- if (!is.null(type_gap) && nrow(type_gap)) data.table::as.data.table(type_gap)[, list(booth_type, cls, g = gap)] else
      data.table::data.table(booth_type = character(0), cls = character(0), g = numeric(0))
    ord_tot <- live_tot$lt[live_tot$unit %in% units$unit[units$booth_type == "ordinary"]]
    med_booth <- if (length(ord_tot) && stats::median(ord_tot) > 0) stats::median(ord_tot) else max(1, stats::median(live_tot$lt))
    STY <- mc[, list(sw_own = sum(v) / sum(lt) - sum(rv) / sum(rt), wl = sum(lt)), by = c("booth_type", "cls")]
    STY[GP, on = c("booth_type", "cls"), g := i.g]
    if (!"g" %in% names(STY)) STY[, g := NA_real_]
    STY[is.na(g) | STY$booth_type == "ordinary", g := 0]
    BASE <- STY[, list(b0 = sum((sw_own - g) * wl) / sum(wl)), by = "cls"]
    grid[, `:=`(a2_g = NA_real_, a2_own = NA_real_, a2_m = 0, a2_b = NA_real_)]
    grid[GP, on = c("booth_type", "cls"), a2_g := i.g]
    grid[grid$booth_type == "ordinary" | is.na(a2_g), a2_g := 0]
    grid[STY, on = c("booth_type", "cls"), `:=`(a2_own = i.sw_own, a2_m = i.wl / med_booth)]
    grid[BASE, on = "cls", a2_b := i.b0]
    hit2 <- !is.na(grid$a2_b)
    w2 <- grid$a2_m / (grid$a2_m + type_pool_k); w2[is.na(grid$a2_own)] <- 0
    own2 <- grid$a2_own; own2[is.na(own2)] <- 0
    new2 <- w2 * own2 + (1 - w2) * (grid$a2_b + grid$a2_g)
    if (any(hit2)) data.table::set(grid, which(hit2), "sw", new2[hit2])
    grid[, c("a2_g", "a2_own", "a2_m", "a2_b") := NULL]
  }
  # LANE A1 (and the diag columns): booth-level swing on the booth's own reference share.
  MO <- mc[mc$booth_type == "ordinary"]
  if (nrow(MO)) {
    MO[, `:=`(x = rv / pmax(rt, 1), y = v / pmax(lt, 1) - rv / pmax(rt, 1))]
    SLOPE <- MO[, {
      xm <- sum(lt * x) / sum(lt); ym <- sum(lt * y) / sum(lt); vx <- sum(lt * (x - xm)^2) / sum(lt)
      list(n_ord = .N, xm = xm, b_loc = if (.N >= 2 && vx > 1e-8) sum(lt * (x - xm) * (y - ym)) / sum(lt) / vx else NA_real_,
           swing_sd = 100 * sqrt(sum(lt * (y - ym)^2) / sum(lt)))
    }, by = "cls"]
  } else SLOPE <- data.table::data.table(cls = character(0), n_ord = integer(0), xm = numeric(0), b_loc = numeric(0), swing_sd = numeric(0))
  if (!is.null(booth_reg)) {
    k1 <- booth_reg$k; stopifnot(is.numeric(k1), length(k1) == 1L, k1 >= 0)
    SL <- data.table::copy(SLOPE); SL[, b_pool := 0]
    if (!is.null(booth_reg$pool) && nrow(booth_reg$pool)) SL[data.table::as.data.table(booth_reg$pool), on = "cls", b_pool := i.beta]
    SL[is.na(b_pool), b_pool := 0]
    SL[, w1 := ifelse(is.na(b_loc), 0, n_ord / (n_ord + k1))]
    SL[, beta := pmin(1, pmax(-1, w1 * ifelse(is.na(b_loc), 0, b_loc) + (1 - w1) * b_pool))]
    grid[, `:=`(a1_beta = NA_real_, a1_xm = NA_real_)]
    grid[SL, on = "cls", `:=`(a1_beta = i.beta, a1_xm = i.xm)]
    hit1 <- grid$booth_type == "ordinary" & grid$unit %in% ref_tot$unit & !is.na(grid$a1_beta)
    grid[hit1, sw := sw + a1_beta * (rv / pmax(rt, 1) - a1_xm)]
    grid[, c("a1_beta", "a1_xm") := NULL]
  }
  has_ref <- grid$unit %in% ref_tot$unit
  mean_unit <- mean(ref_tot$rt)
  grid[, size := data.table::fifelse(has_ref, rt * growth, mean_unit * growth)]
  use_exp <- total == "expected" && is.finite(expected_total) && expected_total > 0
  if (use_exp) {
    cv0 <- sum(live[unit %in% counted_units]$v)
    left <- max(expected_total - cv0 - (if (is.null(er)) 0 else sum(er$v)), 0)   # the early remainder is already inside expected_total
    tot_sz <- sum(unique(grid[, .(unit, size)])$size)
    if (tot_sz > 0) grid[, size := size * left / tot_sz]
  }
  cs_seat <- live[unit %in% counted_units, .(sh = sum(v)), by = cls][, sh := sh / sum(sh)]
  grid <- merge(grid, cs_seat, by = "cls", all.x = TRUE); grid[is.na(sh), sh := 0]
  ref_cls <- unique(ref$cls)
  grid[, proj := data.table::fifelse(has_ref & cls %in% ref_cls, pmax(0, (rv / pmax(rt, 1) + sw) * size), sh * size)]
  # A class new to the seat, with a lean from another count of the reference election (night_council_lean()):
  # swing on the counted units that have a lean, applied to each uncounted unit's own lean share.
  if (!is.null(lean) && nrow(lean)) {
    ln <- data.table::as.data.table(lean)
    lean_units <- unique(ln$unit)
    lt_of <- stats::setNames(live_tot$lt, live_tot$unit)
    for (c0 in intersect(setdiff(classes, ref_cls), unique(ln$cls))) {
      cu <- intersect(counted_units, lean_units); cu <- cu[cu %in% names(lt_of)]
      if (!length(cu)) next
      lc <- ln[ln$cls == c0]
      sh_u <- stats::setNames(lc$share, lc$unit)
      lean_cu <- unname(sh_u[cu]); lean_cu[is.na(lean_cu)] <- 0
      lt_cu <- unname(lt_of[cu])
      live_c <- live[live$cls == c0 & live$unit %in% cu]
      sw_c <- sum(live_c$v) / sum(lt_cu) - sum(lean_cu * lt_cu) / sum(lt_cu)
      hit <- grid$cls == c0 & grid$unit %in% lean_units
      if (!any(hit)) next
      lean_g <- unname(sh_u[grid$unit[hit]]); lean_g[is.na(lean_g)] <- 0
      grid[hit, proj := pmax(0, (lean_g + sw_c) * size)]
    }
  }
  out <- rbind(live[unit %in% counted_units, .(v), by = cls], grid[, .(v = proj), by = cls], er)[, .(projected = sum(v)), by = cls]
  if (use_exp) {
    counted_share <- min(1, sum(live[unit %in% counted_units]$v) / expected_total)
  } else if (total != "table") {
    cv <- sum(live[unit %in% counted_units]$v)
    counted_share <- cv / (cv + sum(unique(grid[, .(unit, size)])$size) + (if (is.null(er)) 0 else sum(er$v)))
  }
  out[, counted_share := counted_share]
  if (isTRUE(diag)) {
    XC <- mc[, list(xc = sum(rv) / sum(rt)), by = "cls"]
    GU <- grid[has_ref & grid$cls %in% ref_cls, list(xu = sum(size * rv / pmax(rt, 1)) / max(sum(size), 1e-9)), by = "cls"]
    RD <- merge(XC, GU, by = "cls")[, list(cls, rep_dist = 100 * abs(xu - xc))]
    unc_v <- sum(unique(grid[, .(unit, size)])$size) + (if (is.null(er)) 0 else sum(er$v))
    out <- .lane_a_diag(out, SLOPE, RD, unc_v / max(sum(out$projected), 1e-9))
  }
  out[]
}

# Lane A diag columns (project_seat_from_booths(diag = TRUE)): one value per class, 0 / NA where not measurable.
.lane_a_diag <- function(out, SLOPE, RD, unc_frac) {
  out <- merge(out, SLOPE[, list(cls, n_ord, swing_sd)], by = "cls", all.x = TRUE, sort = FALSE)
  out <- merge(out, RD, by = "cls", all.x = TRUE, sort = FALSE)
  out[is.na(n_ord), n_ord := 0L]; out[is.na(rep_dist), rep_dist := 0]
  out[, unc_frac := unc_frac][]
}

#' Combine the afternoon prior with the night's projection
#'
#' Precision-weighted: `post = (prior/sd_p^2 + proj/sd_q^2) / (1/sd_p^2 + 1/sd_q^2)`.
#' The projection's sd is a function of the counted share, calibrated on a
#' replay ([booth_projection_sd()]); the prior's is the forecast's own seat
#' primary sd (the backtest residual sd by class when rehearsing).
#'
#' @param prior,proj numeric shares (points) for the same classes.
#' @param sd_prior,sd_proj their standard deviations (points).
#' @return list(mean, sd) of the posterior.
#' @export
combine_prior_projection <- function(prior, proj, sd_prior, sd_proj) {
  wp <- 1 / sd_prior^2; wq <- 1 / sd_proj^2
  list(mean = (prior * wp + proj * wq) / (wp + wq), sd = sqrt(1 / (wp + wq)))
}

#' Projection sd as a function of the counted share
#'
#' Calibrated on dress rehearsal 1 (2018 -> 2022, no prior): the RMSE of
#' the projected major-party share was 2.63 at 8.6% of all votes counted,
#' 1.93 at 22%, 1.77 at 35%, 0.26 at 95%. The curve is not `1/sqrt(n)`
#' shaped (early votes arrive as one lump), so it is interpolated through
#' those points, held at 3.5 below 5% counted and at 0.26 above 95%.
#' A replay re-fits this; it is a rehearsal constant, not a law.
#'
#' `method = "fitted"` (opt-in; `--proj-sd=fitted` on the night scripts) replaces the table with a smooth curve
#' fitted by `scripts/fit_night_projection_sd.R` on the three real replayed nights (vic2022, fed2022, fed2025), per
#' class group (`.booth_proj_sd_fit`): `sd^2 = a + (b + c p (1 - p)) / max(counted_share, floor)`, `p` the projected
#' share as a fraction. With `a, b, c >= 0` it falls monotonically with the count and has no cliff.
#'
#' @param counted_share share of ALL the seat's votes counted, 0 to 1.
#' @param table data.frame `share, sd` to interpolate; the rehearsal-1 table
#'   by default.
#' @param method `"old"` (default, the table above, unchanged) or `"fitted"`.
#' @param share,cls For `"fitted"`: the projected share (points) and class of each cell (recycled against
#'   `counted_share`). A class in `.booth_proj_sd_fit$major` uses the major-party curve, every other the other one.
#' @return sd in share points.
#' @export
booth_projection_sd <- function(counted_share,
                                table = data.frame(share = c(0.00, 0.05, 0.086, 0.224, 0.346, 0.95, 1.00),
                                                   sd    = c(3.5, 3.5, 2.63, 1.93, 1.77, 0.26, 0.26)),
                                method = c("old", "fitted", "max"), share = NULL, cls = NULL) {
  method <- match.arg(method)
  old <- function(x) stats::approx(table$share, table$sd, xout = pmin(pmax(x, 0), 1), rule = 2)$y
  if (method == "old") return(old(counted_share))
  if (is.null(share) || is.null(cls)) stop("BPS1! booth_projection_sd(method = \"fitted\"/\"max\") needs share and cls", call. = FALSE)
  if (method == "max") {   # the larger of the two: widens only where the table is too narrow (the first ~2% counted)
    n <- max(length(counted_share), length(share), length(cls))
    return(pmax(rep_len(old(counted_share), n), booth_projection_sd(counted_share, table, "fitted", share, cls)))
  }
  f <- .booth_proj_sd_fit
  n <- max(length(counted_share), length(share), length(cls))
  cs <- rep_len(pmin(pmax(counted_share, 0), 1), n); p <- rep_len(pmin(pmax(share / 100, 0), 1), n)
  g <- ifelse(rep_len(cls, n) %in% f$major, "major", "other")
  k <- f$coef[g, , drop = FALSE]
  sqrt(k[, "a"] + (k[, "b"] + k[, "c"] * p * (1 - p)) / pmax(cs, f$floor))
}

# Fitted projection-sd constants (method = "fitted"): scripts/fit_night_projection_sd.R, Gaussian likelihood over every
# (night, snapshot, seat, class) projection of the vic2022, fed2022 and fed2025 replays (total = "expected", cand_ref "copy").
# Inventoried in docs/CONSTANTS.md. Refit with that script; do not hand-tune.
.booth_proj_sd_fit <- list(
  major = c("ALP", "LNP"),
  floor = 0.002,
  # fitted 27 Nov 2026 on snapshots to 9pm (16,546 projections: fed2022 7,878, fed2025 7,375, vic2022 1,293)
  coef = rbind(major = c(a = 1.5023, b = 0.06082, c = 0.6140),
               other = c(a = 0.4822, b = 0.04474, c = 1.5480)))
