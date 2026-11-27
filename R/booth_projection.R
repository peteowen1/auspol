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
#'   `[-1, 1]`. A booth strong for a class last time does not get the same swing as a weak one. `booth_reg$all = TRUE`
#'   applies the same offset to every uncounted unit with a reference (early, postal), not only ordinary booths.
#' @param type_pool_k Lane A2. `NULL` (default) is byte-identical. A number `k >= 0`: each booth type's swing is its own
#'   counted swing partial-pooled toward a pooled estimate, `w = m / (m + k)` with `m` its counted votes in units of the
#'   seat's median ordinary booth; the pooled estimate is the seat's ordinary-equivalent swing (every counted type's
#'   swing minus its `type_gap`, weighted by counted votes) plus the type's own `type_gap` (0 without one). So a seat
#'   with only its early vote in projects its ordinary booths at the early swing minus the early gap, not at the raw early swing.
#' @param diag `TRUE` adds columns `n_ord` (counted ordinary booths with a reference), `rep_dist` (reference-share
#'   distance, points, between the uncounted units and the counted ones, size-weighted), `swing_sd` (spread, points, of
#'   the counted ordinary booths' swings) and `unc_frac` (projected share of the seat's votes still to come). `FALSE`
#'   (default) returns the columns as before.
#' @param type_sd Lane D1 (`docs/plans/prereg-night-lane-d-2026-11-28.md`). `NULL` (default) is byte-identical. A named
#'   numeric `k` by booth type (e.g. `c(early = 8.16, postal = 9.86)`): adds a column `type_var` (points^2), the variance
#'   of the projection from not knowing how each uncounted non-ordinary unit will swing against the seat's ordinary
#'   booths, `sum_u (size_u / T)^2 * k_t^2 * p (1 - p) * (1 - c_t)`: `size_u` the unit's projected votes, `T` the seat's
#'   projected total, `p` the class's projected share (fraction), `c_t` the counted share of that type in the seat
#'   (counted votes of the type over counted plus projected uncounted). Zero once every unit of every type has reported.
#' @param booth_knn Lane F, the per-booth best guess (`docs/plans/prereg-night-booth-guess-2026-11-28.md`). `NULL`
#'   (default) is byte-identical. A list `list(h, k, size_w, types)`: each uncounted ORDINARY booth with a reference gets
#'   its own swing per class, `base + sum_j w_j (y_j - base) / (sum_j w_j + k)`, over the counted ordinary booths `j` with
#'   a reference, `y_j` booth j's own swing, `base` the unchanged ordinary swing, `w_j = (votes_j / median booth) *
#'   exp(-d^2 / (2 h^2))`, `d^2` the squared distance (points) between the two booths' reference shares over every
#'   reference class plus `(size_w * log ratio of reference votes)^2`. `types = TRUE`: an uncounted non-ordinary unit
#'   whose type has no counted unit takes the reference-vote-weighted swing of ALL the seat's ordinary booths (counted:
#'   own; uncounted: guessed) in place of the all-types counted swing, keeping its type gap. Not with `booth_reg`.
#' @return data.table `cls, projected, counted_share`, or `NULL` if no
#'   counted unit has a reference (nothing to measure a swing on).
#' @export
project_seat_from_booths <- function(live, ref, counted_units, type_gap = NULL, total = c("table", "projected", "expected"), expected_total = NA_real_,
                                     lean = NULL, early_frac = NA_real_, booth_reg = NULL, type_pool_k = NULL, diag = FALSE, type_sd = NULL,
                                     booth_knn = NULL) {
  if (!is.null(type_sd)) stopifnot(is.numeric(type_sd), length(names(type_sd)) == length(type_sd), all(is.finite(type_sd)), all(type_sd >= 0))
  if (!is.null(booth_knn)) {
    if (!is.null(booth_reg)) stop("NX32! booth_knn and booth_reg cannot both be on", call. = FALSE)
    ok_bk <- is.list(booth_knn) && all(c("h", "k", "size_w", "types") %in% names(booth_knn)) &&
      all(vapply(booth_knn[c("h", "k", "size_w")], function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0, logical(1))) &&
      booth_knn$h > 0 && is.logical(booth_knn$types) && length(booth_knn$types) == 1L && !is.na(booth_knn$types)
    if (!ok_bk) stop("NX32! booth_knn must be list(h > 0, k >= 0, size_w >= 0, types TRUE/FALSE)", call. = FALSE)
  }
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
    if (isTRUE(diag)) out0[, `:=`(n_ord = 0L, swing_sd = 0, rep_dist = 0, unc_frac = 1 - cs_all)]
    if (!is.null(type_sd)) out0 <- .lane_d_type_var(out0, NULL, er, live, counted_units, type_sd)
    return(out0[])
  }
  grid <- data.table::CJ(unit = unc$unit, cls = classes); grid <- merge(grid, unc, by = "unit")
  grid <- merge(grid, ref[, .(unit, cls, rv = v)], by = c("unit", "cls"), all.x = TRUE)
  grid <- merge(grid, ref_tot, by = "unit", all.x = TRUE)
  grid <- merge(grid, sw_t, by = c("booth_type", "cls"), all.x = TRUE); grid <- merge(grid, sw_a, by = "cls", all.x = TRUE)
  if (!is.null(booth_knn)) grid[, .bk_untyped := is.na(sw)]   # this unit's type has no counted unit (lane F, types = TRUE)
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
    # booth size from the REFERENCE totals: a live feed's uncounted units hold nothing (a replay's hold the final result)
    ord_tot <- ref_tot$rt[ref_tot$unit %in% units$unit[units$booth_type == "ordinary"]]
    med_booth <- if (length(ord_tot) && isTRUE(stats::median(ord_tot) > 0)) stats::median(ord_tot) else max(1, stats::median(ref_tot$rt))
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
  SLOPE <- data.table::data.table(cls = character(0), n_ord = integer(0), xm = numeric(0), b_loc = numeric(0), swing_sd = numeric(0))
  MO <- if (!is.null(booth_reg) || isTRUE(diag)) mc[mc$booth_type == "ordinary" & mc$lt > 0] else mc[0]   # nothing runs with every switch off
  if (nrow(MO)) {
    MO[, `:=`(x = rv / pmax(rt, 1), y = v / pmax(lt, 1) - rv / pmax(rt, 1))]
    SLOPE <- MO[, {
      xm <- sum(lt * x) / sum(lt); ym <- sum(lt * y) / sum(lt); vx <- sum(lt * (x - xm)^2) / sum(lt)
      list(n_ord = .N, xm = xm, b_loc = if (isTRUE(.N >= 2 && vx > 1e-8)) sum(lt * (x - xm) * (y - ym)) / sum(lt) / vx else NA_real_,
           swing_sd = 100 * sqrt(sum(lt * (y - ym)^2) / sum(lt)))
    }, by = "cls"]
  }
  if (!is.null(booth_reg)) {
    k1 <- booth_reg$k; stopifnot(is.numeric(k1), length(k1) == 1L, k1 >= 0)
    SL <- data.table::copy(SLOPE); SL[, b_pool := 0]
    if (!is.null(booth_reg$pool) && nrow(booth_reg$pool)) SL[data.table::as.data.table(booth_reg$pool), on = "cls", b_pool := i.beta]
    SL[is.na(b_pool), b_pool := 0]
    SL[, w1 := ifelse(is.na(b_loc), 0, n_ord / (n_ord + k1))]
    SL[, beta := pmin(1, pmax(-1, w1 * ifelse(is.na(b_loc), 0, b_loc) + (1 - w1) * b_pool))]
    grid[, `:=`(a1_beta = NA_real_, a1_xm = NA_real_)]
    grid[SL, on = "cls", `:=`(a1_beta = i.beta, a1_xm = i.xm)]
    # booth_reg$all = TRUE (prereg addition A1b): the same offset on every uncounted unit with a reference (early, postal...)
    hit1 <- (isTRUE(booth_reg$all) | grid$booth_type == "ordinary") & grid$unit %in% ref_tot$unit & !is.na(grid$a1_beta)
    grid[hit1, sw := sw + a1_beta * (rv / pmax(rt, 1) - a1_xm)]
    grid[, c("a1_beta", "a1_xm") := NULL]
  }
  if (!is.null(booth_knn)) grid <- .booth_knn_swing(grid, live, ref, ref_tot, live_tot, units, counted_units, booth_knn)
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
  if (!is.null(type_sd)) out <- .lane_d_type_var(out, unique(grid[, .(unit, booth_type, size)]), er, live, counted_units, type_sd)
  out[]
}

# Lane F (project_seat_from_booths(booth_knn = ...)): the per-booth best guess. `grid` is the uncounted unit x class grid
# with `sw` (fraction) already set by the unchanged rules and `.bk_untyped`; returns it with `sw` replaced on (a) uncounted
# ordinary booths with a reference and (b) with types = TRUE, uncounted non-ordinary units whose type had no counted unit.
.booth_knn_swing <- function(grid, live, ref, ref_tot, live_tot, units, counted_units, bk) {
  ord <- units$unit[units$booth_type == "ordinary"]
  rcls <- setdiff(unique(ref$cls), "_COPYADJ")
  RS <- ref[ref$cls %in% rcls & ref$unit %in% ord, list(v = sum(v)), by = c("unit", "cls")]
  if (!nrow(RS)) { grid[, .bk_untyped := NULL]; return(grid) }
  RS[ref_tot, on = "unit", rt := i.rt]; RS[, s := v / pmax(rt, 1)]
  X <- data.table::dcast(RS, unit ~ cls, value.var = "s", fill = 0)
  RT <- stats::setNames(ref_tot$rt, ref_tot$unit); LT <- stats::setNames(live_tot$lt, live_tot$unit)
  ycls <- intersect(unique(live$cls), rcls)   # classes with a reference swing (others take the counted share anyway)
  cu <- X$unit[X$unit %in% counted_units & X$unit %in% names(LT)]; cu <- cu[LT[cu] > 0]
  uu <- intersect(X$unit[!X$unit %in% counted_units], grid$unit[grid$booth_type == "ordinary"])
  if (!length(cu) || !length(ycls)) { grid[, .bk_untyped := NULL]; return(grid) }
  xm <- as.matrix(X[, -1, with = FALSE]); rownames(xm) <- X$unit
  # counted booths' own swings, units x classes (a class absent at a booth this year had share 0 there)
  LS <- live[live$unit %in% cu & live$cls %in% ycls, list(v = sum(v)), by = c("unit", "cls")]
  Y <- matrix(0, length(cu), length(ycls), dimnames = list(cu, ycls))
  if (nrow(LS)) Y[cbind(match(LS$unit, cu), match(LS$cls, ycls))] <- LS$v / LT[LS$unit]
  RX <- matrix(0, length(cu), length(ycls), dimnames = list(cu, ycls)); ic <- intersect(ycls, colnames(xm)); RX[, ic] <- xm[cu, ic, drop = FALSE]
  Y <- Y - RX
  # base: the unchanged ordinary swing per class, as the grid holds it (one value per class on ordinary rows)
  bt <- grid[grid$booth_type == "ordinary" & grid$cls %in% ycls, list(b = sw[1]), by = "cls"]
  base <- stats::setNames(rep(0, length(ycls)), ycls); base[bt$cls] <- bt$b
  if (!nrow(bt)) {   # no uncounted ordinary booth: the all-types swing is the base for the types step
    sa <- grid[grid$cls %in% ycls, list(b = sw_all[1]), by = "cls"]; base[sa$cls] <- sa$b }
  med <- stats::median(RT[X$unit]); if (!isTRUE(med > 0)) med <- 1
  G <- NULL
  if (length(uu)) {
    D2 <- matrix(0, length(uu), length(cu))
    for (c0 in colnames(xm)) D2 <- D2 + outer(100 * xm[uu, c0], 100 * xm[cu, c0], "-")^2
    D2 <- D2 + outer(bk$size_w * log(pmax(RT[uu], 1)), bk$size_w * log(pmax(RT[cu], 1)), "-")^2
    W <- exp(-D2 / (2 * bk$h^2)) * matrix(LT[cu] / med, length(uu), length(cu), byrow = TRUE)
    dev <- sweep(Y, 2L, base[ycls])
    G <- sweep((W %*% dev) / (rowSums(W) + bk$k), 2L, base[ycls], "+"); rownames(G) <- uu
    hit <- grid$booth_type == "ordinary" & grid$unit %in% uu & grid$cls %in% ycls
    data.table::set(grid, which(hit), "sw", G[cbind(match(grid$unit[hit], uu), match(grid$cls[hit], ycls))])
  }
  if (isTRUE(bk$types)) {
    # every ordinary booth with a reference: counted at its own swing, uncounted at its guess (or the base), by reference votes
    allu <- c(cu, setdiff(X$unit, cu)); S <- matrix(rep(base[ycls], each = length(allu)), length(allu), dimnames = list(allu, ycls))
    S[cu, ] <- Y; if (!is.null(G)) S[rownames(G), ] <- G
    ow <- colSums(S * RT[allu]) / sum(RT[allu])
    hit <- grid$booth_type != "ordinary" & grid$.bk_untyped & grid$cls %in% ycls & !is.na(grid$sw_all)
    if (any(hit)) data.table::set(grid, which(hit), "sw", grid$sw[hit] - grid$sw_all[hit] + ow[grid$cls[hit]])
  }
  grid[, .bk_untyped := NULL]
  grid
}

# Lane D1 (project_seat_from_booths(type_sd = k)): variance (points^2) per class from the uncounted non-ordinary units'
# unknown swing against the ordinary booths. `unc` = the uncounted units' `unit, booth_type, size` (NULL: none); `er` the
# projected remainder of a partly counted early unit (its own early swing is measured, so it counts as early with c_t > 0).
.lane_d_type_var <- function(out, unc, er, live, counted_units, type_sd) {
  T0 <- max(sum(out$projected), 1e-9)
  U <- if (is.null(unc)) data.table::data.table(unit = character(0), booth_type = character(0), size = numeric(0)) else
    data.table::as.data.table(unc)[, list(unit, booth_type, size)]
  if (!is.null(er) && nrow(er)) U <- rbind(U, data.table::data.table(unit = "early_rest", booth_type = "early", size = sum(er$v)))
  U <- U[U$booth_type != "ordinary" & U$booth_type %in% names(type_sd) & U$size > 0]
  if (!nrow(U)) { out[, type_var := 0]; return(out) }
  cnt <- live[live$unit %in% counted_units, list(cv = sum(v)), by = "booth_type"]
  ut <- U[, list(uv = sum(size), s2 = sum((size / T0)^2)), by = "booth_type"]
  ut[, cv := 0]; ut[cnt, on = "booth_type", cv := i.cv]
  ut[, w := unname(type_sd[ut$booth_type])^2 * ut$s2 * (1 - ut$cv / (ut$cv + ut$uv))]
  p <- pmin(pmax(out$projected / T0, 0), 1)
  out[, type_var := sum(ut$w) * p * (1 - p)]
  out
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

#' Combine the prior with a fat-tailed (Student-t) projection
#'
#' Ported from lane C (branch `night-lane-c`, fffbf957) for lane D2 (`docs/plans/prereg-night-lane-d-2026-11-28.md`):
#' the projection error is `scale * t_df` instead of normal, so a projection far from the prior is down-weighted
#' rather than trusted. Computed exactly as a scale mixture: `t_df = N(0, scale^2 / w)` with `w ~ Gamma(df/2, rate df/2)`
#' on `k` equal-probability quantile nodes. Given `w` the posterior is the normal-normal one; each node is weighted by
#' the marginal density of the projection, `N(proj; prior, sd_prior^2 + scale^2 / w)`. The result is the mixture's mean
#' and sd. Vectorised over cells. When `proj == prior` the mean is exactly the prior; with `df = Inf` the result is
#' [combine_prior_projection()]'s.
#'
#' @param prior,proj numeric shares (points), same length (or recycled).
#' @param sd_prior prior sd (points).
#' @param scale the t scale of the projection error (points).
#' @param df degrees of freedom (`Inf` gives the normal result).
#' @param k number of mixture nodes.
#' @return list(mean, sd, w_mean): posterior mean and sd, and the posterior mean of the precision multiplier `w`.
#' @export
combine_prior_projection_t <- function(prior, proj, sd_prior, scale, df, k = 32L) {
  n <- max(length(prior), length(proj), length(sd_prior), length(scale))
  prior <- rep_len(prior, n); proj <- rep_len(proj, n); sd_prior <- rep_len(sd_prior, n); scale <- rep_len(scale, n)
  if (!is.finite(df)) {
    cm <- combine_prior_projection(prior, proj, sd_prior, scale)
    return(list(mean = cm$mean, sd = cm$sd, w_mean = rep(1, n)))
  }
  stopifnot(length(df) == 1L, df > 0, k >= 2)
  w <- stats::qgamma((seq_len(k) - 0.5) / k, shape = df / 2, rate = df / 2)
  vp <- sd_prior^2
  vq <- outer(scale^2, 1 / w)                     # n x k projection variances
  tot <- vp + vq
  d <- proj - prior
  lw <- -0.5 * log(tot) - 0.5 * d^2 / tot         # log N(proj; prior, tot), up to a constant
  lw <- lw - apply(lw, 1L, max)
  pw <- exp(lw); pw <- pw / rowSums(pw)
  mk <- prior + vp * d / tot                      # node posterior means (recycles prior, vp, d by row)
  vk <- vp * vq / tot                             # node posterior variances
  m <- rowSums(pw * mk)
  v <- rowSums(pw * (vk + mk^2)) - m^2
  list(mean = m, sd = sqrt(pmax(v, 0)), w_mean = as.numeric(pw %*% w))
}

# Lane D2: degrees of freedom of the projection error, lane C's fit (fffbf957, .booth_proj_units_fit$df, Student-t
# likelihood over the three replayed nights' projections). With `proj_tails = "t"` the current projection sd is turned
# into a t scale with the SAME variance, sd * sqrt((df - 2) / df): same spread, fatter tails. Inventoried in docs/CONSTANTS.md.
.NIGHT_T_DF <- 4.755439

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
