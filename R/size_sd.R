# Seat-size spread (AUSPOL_SIZE_SD, default "0" = off). 2026-10-14: the published path's share errors are
# about twice the simulation's own per-cell sd in seats under 15,000 formal votes and about right above
# 40,000 (scripts/diag_spread_by_size.R), so small-seat favourites are called far too confidently (NT:
# favourites stated 0.945 won 8 of 19). The widening factor is fitted time-forward per target by
# scripts/fit_spread_by_size.R into output/spread-by-size.csv, and only ever widens (factor >= 1, merged
# into the sd override with combine_sd_override()'s pmax).

#' @noRd
size_sd_on <- function() identical(Sys.getenv("AUSPOL_SIZE_SD", "0"), "1")

#' Widen the per-cell sd of small seats (AUSPOL_SIZE_SD)
#'
#' Builds the level-sd matrix (`a + b * level_mult * sqrt(p(1-p))`) times each seat's size factor from
#' `output/spread-by-size.csv`, and merges it into `sd_override` with [combine_sd_override()]. A seat's size
#' is its formal votes at the PREVIOUS election (known before polling day); a seat with no match there is
#' left unchanged and counted in the log. With the switch off, or no `level_sd`, `sd_override` is returned
#' unchanged.
#'
#' @param sd_override The caller's sd override matrix, or `NULL`.
#' @param shares Seats x classes predicted shares (percent).
#' @param target Target election label, e.g. `"nt2016"`.
#' @param level_sd `c(a, b)` as passed to [simulate_seat_contests()].
#' @param level_mult Per-class multiplier as passed to [simulate_seat_contests()], or `NULL`.
#' @param prev Previous election label; `NULL` looks it up in [all_election_pairs()].
#' @return The merged sd override (or `sd_override` unchanged).
#' @export
size_sd_apply <- function(sd_override, shares, target, level_sd, level_mult = NULL, prev = NULL) {
  if (!size_sd_on() || is.null(level_sd)) return(sd_override)
  f <- file.path(out_path(), "spread-by-size.csv")
  if (!file.exists(f)) stop("AUSPOL_SIZE_SD=1 but output/spread-by-size.csv is missing -- run scripts/fit_spread_by_size.R")
  tab <- data.table::fread(f, showProgress = FALSE)
  # the argument is copied to a different name: inside tab[...] a bare `target` binds to tab's own column
  # (the data.table NSE trap; this line hit it on its first screen, 2026-10-14)
  tgt_label <- target
  row <- tab[tab$target %in% tgt_label]
  if (nrow(row) != 1L) stop("AUSPOL_SIZE_SD=1 but output/spread-by-size.csv has no row for ", target)
  if (is.null(prev)) {
    pr <- Filter(function(p) identical(p$election, target), all_election_pairs())
    prev <- if (length(pr)) pr[[1]]$prev else NA_character_
  }
  C <- data.table::fread(file.path(out_path(), "candidacies.csv"), showProgress = FALSE)
  prev_label <- prev
  fm <- C[C$election %in% prev_label, list(formal = sum(as.numeric(votes), na.rm = TRUE)), by = list(s = normalise_seat(seat))]
  rn <- seat_rename_map()
  fm2 <- fm[fm$s %in% names(rn)]
  if (nrow(fm2)) fm <- rbind(fm, data.table::data.table(s = unname(rn[fm2$s]), formal = fm2$formal))
  fm <- unique(fm, by = "s")
  seats <- normalise_seat(rownames(shares))
  formal <- fm$formal[match(seats, fm$s)]
  fac <- ifelse(is.finite(formal) & formal > 0,
                pmax(1, exp(row$w * row$slope * (log(formal) - log(row$f_median)))), 1)
  K <- ncol(shares)
  lm_vec <- rep(1, K)
  if (!is.null(level_mult)) { hit <- match(names(level_mult), colnames(shares)); lm_vec[hit[!is.na(hit)]] <- as.numeric(level_mult)[!is.na(hit)] }
  ppm <- pmin(pmax(unname(as.matrix(shares)), 0), 100) / 100
  base <- level_sd[1L] + level_sd[2L] * matrix(lm_vec, nrow(ppm), K, byrow = TRUE) * sqrt(ppm * (1 - ppm))
  out <- matrix(base * fac, nrow(ppm), K, dimnames = dimnames(shares))
  out[fac <= 1, ] <- NA_real_
  cat(sprintf("SZD1 %s: seat-size spread from %s formal votes (slope %.3f x w %.2f, median %.0f): %d of %d seats widened, factor %.2f-%.2f; %d seat(s) with no %s match left unchanged\n",
              target, prev, row$slope, row$w, row$f_median, sum(fac > 1), length(fac),
              if (any(fac > 1)) min(fac[fac > 1]) else 1, max(fac), sum(!is.finite(formal)), prev))
  combine_sd_override(sd_override, out)
}
