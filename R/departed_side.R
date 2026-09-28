#' Which side of a seat lost its sitting member
#'
#' Adds `own_departed_i` (1 on the incumbent major's row when its candidate is
#' not the sitting member) and `opp_departed_i` (1 on the OTHER major's row in
#' such a seat) to a feature table. `retirement_i` is a seat flag, identical on
#' both majors' rows, so a tree has to infer which side lost its member; and
#' the seat file's `retirement` column is hardcoded 0 on 11 of 23 training
#' pairs, while `same_mp_i` comes from the candidate lists and is reliable
#' everywhere. docs/plans/prereg-departed-member-sides-2026-09-28.md.
#'
#' Only under `AUSPOL_XGB_DEPARTED_SIDE=1`; otherwise the table is returned
#' unchanged. One helper for `fit_xgb_primary_v6.R`, `_v6_final.R` and
#' [xgb_primary_predict_live()], so the three cannot drift.
#'
#' @param dt data.table with `party`, `same_mp_i`, `is_incumbent_party_i` and
#'   the seat keys.
#' @param keys Columns identifying one contest (e.g. `c("pair", "seat")`).
#' @return `dt`, with the two columns added by reference when on.
#' @export
add_departed_side <- function(dt, keys) {
  if (!identical(Sys.getenv("AUSPOL_XGB_DEPARTED_SIDE", "0"), "1")) return(dt)
  majors <- c("ALP", "LNP")
  own <- dt$party %in% majors & dt$is_incumbent_party_i %in% 1L & dt$same_mp_i %in% 0L
  dt[, own_departed_i := as.integer(own)]
  seat_dep <- dt[, .(seat_departed = any(own_departed_i == 1L)), by = keys]
  tmp <- merge(dt[, c(keys, "party", "is_incumbent_party_i"), with = FALSE][, .row := .I],
               seat_dep, by = keys, all.x = TRUE)[order(.row)]
  opp <- tmp$seat_departed %in% TRUE & dt$party %in% majors & !(dt$is_incumbent_party_i %in% 1L)
  dt[, opp_departed_i := as.integer(opp)]
  cat(sprintf("DS1  departed-member sides: own %d rows, opposing %d rows (of %d)\n",
              sum(dt$own_departed_i), sum(dt$opp_departed_i), nrow(dt)))
  dt
}
