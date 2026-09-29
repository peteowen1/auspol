#' Sitting-member group of a major-party row
#'
#' `"inc_stays"`: the party that holds the seat, its sitting member standing
#' again; `"inc_gone"`: that party, member gone; `"ch_gone"`: the other major in
#' a seat whose member is gone; `NA` otherwise (minor parties, the challenger
#' where the member stands, rows with no incumbency information).
#' docs/plans/prereg-sitting-member-baseline-2026-09-28.md.
#'
#' @param dt data.table with `party`, `is_incumbent_party_i`, `same_mp_i`.
#' @param keys Columns identifying one contest.
#' @return Character vector, one per row.
#' @export
sitting_member_group <- function(dt, keys) {
  maj <- dt$party %in% c("ALP", "LNP")
  inc <- maj & dt$is_incumbent_party_i %in% 1L
  gone_row <- inc & dt$same_mp_i %in% 0L
  seat_gone <- stats::ave(as.integer(gone_row), do.call(paste, c(dt[, keys, with = FALSE], sep = "|")), FUN = max) == 1L
  out <- rep(NA_character_, nrow(dt))
  out[inc & dt$same_mp_i %in% 1L] <- "inc_stays"
  out[gone_row] <- "inc_gone"
  out[maj & !inc & seat_gone & !is.na(dt$is_incumbent_party_i)] <- "ch_gone"
  out
}

#' Time-forward sitting-member shifts for one target election
#'
#' Mean residual (`actual - base_pred`) per group over elections dated before
#' `target_election`, shrunk toward 0 by its precision measured across
#' elections (seats in one election share a swing):
#' `shift = m * m^2 / (m^2 + se^2)`, `se = sd(per-election means) / sqrt(k)`.
#' Fewer than 3 earlier elections in a group gives 0.
#'
#' @param tab data.table with `pair`, `group`, `resid`.
#' @param target_election Label of the election being forecast.
#' @return data.table: `group`, `shift`, `m`, `se`, `k` (elections), `n` (rows).
#' @export
fit_sitting_member_shift <- function(tab, target_election) {
  h <- tab[!is.na(tab$group) & elections_before(tab$pair, target_election)]
  groups <- c("inc_stays", "inc_gone", "ch_gone")
  data.table::rbindlist(lapply(groups, function(g) {
    e <- h[h$group == g, list(em = mean(resid)), by = "pair"]
    k <- nrow(e); n <- sum(h$group == g)
    if (k < 3L) return(data.table::data.table(group = g, shift = 0, m = NA_real_, se = NA_real_, k = k, n = n))
    m <- mean(e$em); se <- stats::sd(e$em) / sqrt(k)
    shift <- if (isTRUE(m^2 + se^2 > 0)) m * m^2 / (m^2 + se^2) else 0
    data.table::data.table(group = g, shift = shift, m = m, se = se, k = k, n = n)
  }))
}
