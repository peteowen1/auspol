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
#' @return data.table `cls, projected, counted_share`, or `NULL` if no
#'   counted unit has a reference (nothing to measure a swing on).
#' @export
project_seat_from_booths <- function(live, ref, counted_units) {
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
  counted_share <- sum(live[unit %in% counted_units]$v) / sum(live$v)
  unc <- units[counted == FALSE]
  if (!nrow(unc)) return(live[, .(projected = sum(v)), by = cls][, counted_share := 1][])
  grid <- data.table::CJ(unit = unc$unit, cls = classes); grid <- merge(grid, unc, by = "unit")
  grid <- merge(grid, ref[, .(unit, cls, rv = v)], by = c("unit", "cls"), all.x = TRUE)
  grid <- merge(grid, ref_tot, by = "unit", all.x = TRUE)
  grid <- merge(grid, sw_t, by = c("booth_type", "cls"), all.x = TRUE); grid <- merge(grid, sw_a, by = "cls", all.x = TRUE)
  grid[is.na(sw), sw := sw_all]; grid[is.na(sw), sw := 0]; grid[is.na(rv), rv := 0]
  has_ref <- grid$unit %in% ref_tot$unit
  mean_unit <- mean(ref_tot$rt)
  grid[, size := data.table::fifelse(has_ref, rt * growth, mean_unit * growth)]
  cs_seat <- live[unit %in% counted_units, .(sh = sum(v)), by = cls][, sh := sh / sum(sh)]
  grid <- merge(grid, cs_seat, by = "cls", all.x = TRUE); grid[is.na(sh), sh := 0]
  ref_cls <- unique(ref$cls)
  grid[, proj := data.table::fifelse(has_ref & cls %in% ref_cls, pmax(0, (rv / pmax(rt, 1) + sw) * size), sh * size)]
  out <- rbind(live[unit %in% counted_units, .(v), by = cls], grid[, .(v = proj), by = cls])[, .(projected = sum(v)), by = cls]
  out[, counted_share := counted_share][]
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
#' @param counted_share share of ALL the seat's votes counted, 0 to 1.
#' @param table data.frame `share, sd` to interpolate; the rehearsal-1 table
#'   by default.
#' @return sd in share points.
#' @export
booth_projection_sd <- function(counted_share,
                                table = data.frame(share = c(0.00, 0.05, 0.086, 0.224, 0.346, 0.95, 1.00),
                                                   sd    = c(3.5, 3.5, 2.63, 1.93, 1.77, 0.26, 0.26))) {
  stats::approx(table$share, table$sd, xout = pmin(pmax(counted_share, 0), 1), rule = 2)$y
}
