# Seat-size spread (AUSPOL_SIZE_SD, default "1" = shipped 2026-10-14; "0" = off). 2026-10-14: the published path's share errors are
# about twice the simulation's own per-cell sd in seats under 15,000 formal votes and about right above
# 40,000 (scripts/diag_spread_by_size.R), so small-seat favourites are called far too confidently (NT:
# favourites stated 0.945 won 8 of 19). The widening factor is fitted time-forward per target by
# scripts/fit_spread_by_size.R into output/spread-by-size.csv, and only ever widens (factor >= 1, merged
# into the sd override with combine_sd_override()'s pmax).
#
# Seat-composition spread (AUSPOL_COMPOSITION_SD, default "0" = off; prereg-composition-spread-2026-10-17.md).
# A candidate's personal vote does not behave like a party vote: share errors grow with the seat's predicted
# independent share in every size band, on every class's cells. Fitted time-forward per target and class by
# scripts/fit_spread_by_composition.R into output/spread-by-composition.csv; a seat's factor is
# max(1, exp(sum_c w_c b_c s_c / 2)) on the classes' predicted shares (per 10 points), and it MULTIPLIES the
# size factor (the fit controls for size, so the two do not double-count).

#' @noRd
size_sd_on <- function() identical(Sys.getenv("AUSPOL_SIZE_SD", "1"), "1")

#' @noRd
composition_sd_on <- function() identical(Sys.getenv("AUSPOL_COMPOSITION_SD", "0"), "1")

#' The non-major classes the seat-composition spread is fitted on
#'
#' The majors (`ALP`, `LNP`) are the reference; every other class gets its own coefficient, and the data
#' decide which ones widen (see `scripts/fit_spread_by_composition.R`).
#' @return Character vector of class names.
#' @export
composition_sd_classes <- function() c("GRN", "IND", "ONP", "OTH", "OTH_RIGHT")

#' The seat-composition widening factor (AUSPOL_COMPOSITION_SD)
#'
#' @param shares Seats x classes predicted shares (percent).
#' @param coef A table with `class`, `b`, `w` for one target (from `output/spread-by-composition.csv`).
#' @return One factor per seat, `>= 1`.
#' @export
composition_sd_factor <- function(shares, coef) {
  z <- numeric(nrow(shares))
  for (k in intersect(coef$class, colnames(shares))) {
    i <- match(k, coef$class)
    bw <- coef$b[i] * coef$w[i]
    if (is.finite(bw) && bw != 0) z <- z + bw * pmax(as.numeric(shares[, k]), 0) / 10
  }
  pmax(1, exp(z / 2))
}

#' Widen the per-cell sd of small seats (AUSPOL_SIZE_SD) and of personal-vote seats (AUSPOL_COMPOSITION_SD)
#'
#' Builds the level-sd matrix (`a + b * level_mult * sqrt(p(1-p))`) times each seat's factor, and merges it
#' into `sd_override` with [combine_sd_override()]. The factor is the size factor from
#' `output/spread-by-size.csv` (a seat's size is its formal votes at the PREVIOUS election, known before
#' polling day; a seat with no match there gets 1, counted in the log) times the composition factor from
#' `output/spread-by-composition.csv` ([composition_sd_factor()] on the predicted shares). Either switch can
#' be off on its own. With both off, or no `level_sd`, `sd_override` is returned unchanged.
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
  if (is.null(level_sd) || (!size_sd_on() && !composition_sd_on())) return(sd_override)
  # the argument is copied to a different name: inside tab[...] a bare `target` binds to tab's own column
  # (the data.table NSE trap; this line hit it on its first screen, 2026-10-14)
  tgt_label <- target
  fac <- rep(1, nrow(shares))
  # `build`: whether an override matrix is returned at all. A FITTED size table always built one (all NA when
  # no seat widened) and an unfitted one returned sd_override as is; kept exactly, so the composition switch off
  # is byte-identical to the size spread alone (checked on nt2016, fed2022, wa2001, vic2022, sa2026, 2026-10-17).
  build <- FALSE
  if (size_sd_on()) {
    sf <- .size_factor(shares, target, tgt_label, prev)
    if (!is.null(sf)) { fac <- fac * sf; build <- TRUE }
  }
  if (composition_sd_on()) {
    f <- file.path(out_path(), "spread-by-composition.csv")
    if (!file.exists(f)) stop("AUSPOL_COMPOSITION_SD=1 but output/spread-by-composition.csv is missing -- run scripts/fit_spread_by_composition.R")
    tab <- data.table::fread(f, showProgress = FALSE)
    co <- tab[tab$target %in% tgt_label]
    if (!nrow(co)) stop("AUSPOL_COMPOSITION_SD=1 but output/spread-by-composition.csv has no rows for ", target)
    cf <- composition_sd_factor(shares, co)
    cat(sprintf("CMP1 %s: composition spread (%d earlier elections; %s): %d of %d seats widened, factor %.2f-%.2f\n",
                target, as.integer(co$n_pairs[1]),
                paste(sprintf("%s %.3f x w %.2f", co$class, co$b, co$w), collapse = ", "),
                sum(cf > 1), length(cf), if (any(cf > 1)) min(cf[cf > 1]) else 1, max(cf)))
    fac <- fac * cf
    if (any(cf > 1)) build <- TRUE
  }
  if (!build) return(sd_override)
  K <- ncol(shares)
  lm_vec <- rep(1, K)
  if (!is.null(level_mult)) { hit <- match(names(level_mult), colnames(shares)); lm_vec[hit[!is.na(hit)]] <- as.numeric(level_mult)[!is.na(hit)] }
  ppm <- pmin(pmax(unname(as.matrix(shares)), 0), 100) / 100
  base <- level_sd[1L] + level_sd[2L] * matrix(lm_vec, nrow(ppm), K, byrow = TRUE) * sqrt(ppm * (1 - ppm))
  out <- matrix(base * fac, nrow(ppm), K, dimnames = dimnames(shares))
  out[fac <= 1, ] <- NA_real_
  combine_sd_override(sd_override, out)
}

# The seat-size factor per seat (1 where unmatched), or NULL when no slope is fitted. Prints SZD1.
.size_factor <- function(shares, target, tgt_label, prev) {
  f <- file.path(out_path(), "spread-by-size.csv")
  if (!file.exists(f)) stop("AUSPOL_SIZE_SD=1 but output/spread-by-size.csv is missing -- run scripts/fit_spread_by_size.R")
  tab <- data.table::fread(f, showProgress = FALSE)
  row <- tab[tab$target %in% tgt_label]
  if (nrow(row) != 1L) stop("AUSPOL_SIZE_SD=1 but output/spread-by-size.csv has no row for ", target)
  # no earlier elections to fit on (wa2001, wa2005, fed2007): slope 0 and no median size, so nothing widens
  if (!is.finite(row$slope) || row$slope == 0 || !is.finite(row$w) || row$w == 0 || !is.finite(row$f_median)) {
    cat(sprintf("SZD1 %s: no seat-size slope fitted (%d earlier elections); spread unchanged\n", target, as.integer(row$n_pairs)))
    return(NULL)
  }
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
  cat(sprintf("SZD1 %s: seat-size spread from %s formal votes (slope %.3f x w %.2f, median %.0f): %d of %d seats widened, factor %.2f-%.2f; %d seat(s) with no %s match left unchanged\n",
              target, prev, row$slope, row$w, row$f_median, sum(fac > 1), length(fac),
              if (any(fac > 1)) min(fac[fac > 1]) else 1, max(fac), sum(!is.finite(formal)), prev))
  fac
}
