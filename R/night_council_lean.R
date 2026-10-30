# Booth lean from the upper house, for a party with no lower-house history in a seat (election night).
#
# The night projection measures each party's swing on counted booths against the same booths last time, and
# applies it to the booths still to report from their own last-time share (project_seat_from_booths()). A party
# that did not stand in the seat last time has no last-time share, so it took its counted share unadjusted: a
# strong early booth was read as the seat's level. One Nation stood in very few Victorian districts in 2022 but in
# every upper-house region, so its 2022 upper-house vote at each voting centre says how that booth leans. Used only
# for parties with no lower-house reference in the seat; every other party is untouched.

#' Upper-house booth lean: each party class's share at each voting centre
#'
#' @param council_fp The previous election's upper-house first preferences by voting centre
#'   (`output/council-fp-<year>.csv`, `scripts/fetch_council_results.R`): `district`, `vc_name`, `vote_type`,
#'   `block_kind`, `row_kind`, `group_name`, `total`.
#' @param classes Classes the lean is returned for. Default: the named parties, whose upper-house vote is the same
#'   party as their lower-house vote. Tested on the vic2022 replay with each class made "new" in turn
#'   (`scripts/test_council_lean_replay.R`, 2026-10-30): pooled RMSE of the projected seat share 3.03 -> 2.41 points
#'   against 2.45 with the real lower-house history; better for ALP, LNP and GRN at every fraction, WORSE for the
#'   pooled OTH_RIGHT class (1.02 -> 1.33 at 5% counted), whose parties differ between the houses, so pooled classes
#'   are left out.
#' @return data.table `district, unit, cls, share` (share 0-1 of the centre's formal upper-house vote), with `unit`
#'   named as [night_booth_update()] names lower-house units: the voting centre for ordinary votes, the vote type
#'   otherwise. Ungrouped candidates count as `IND`.
#' @export
night_council_lean <- function(council_fp, classes = c("ALP", "LNP", "GRN", "ONP")) {
  C <- data.table::as.data.table(council_fp)
  need <- c("district", "vc_name", "vote_type", "block_kind", "row_kind", "group_name", "total")
  miss <- setdiff(need, names(C))
  if (length(miss)) stop("night_council_lean(): council table lacks ", paste(miss, collapse = ", "), call. = FALSE)
  C <- C[C$block_kind == "voting_centre" & C$row_kind %in% c("group", "ungrouped")]
  if (!nrow(C)) stop("night_council_lean(): no voting-centre party rows", call. = FALSE)
  cls <- ifelse(C$row_kind == "ungrouped", "IND", classify_party(C$group_name))
  out <- data.table::data.table(district = sub("\\s+District$", "", C$district),
                                unit = ifelse(C$vote_type == "ordinary", C$vc_name, C$vote_type),
                                cls = cls, v = suppressWarnings(as.numeric(C$total)))
  out <- out[is.finite(out$v), list(v = sum(v)), by = c("district", "unit", "cls")]
  out[, share := v / sum(v), by = c("district", "unit")]          # shares over ALL classes, then keep the named ones
  keep <- is.finite(out$share) & out$cls %in% classes
  out[keep, c("district", "unit", "cls", "share"), with = FALSE]
}
