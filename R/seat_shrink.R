#' Per-seat calibration shrink, zero wherever the risk it insures is absent
#'
#' **NOTHING CALLS THIS.** Checked 2026-09-06 across `R/`, `scripts/` and
#' `tests/`: the shipped per-seat path is `AUSPOL_INSURGENCY_SHRINK=1`, which
#' reads a FITTED risk from `output/fed-insurgency-risk.csv` (see
#' `scripts/fit_insurgency_risk.R`) rather than deriving one from the shares.
#' That arm was measured and refused on 2026-09-06. This function is the
#' earlier, share-derived idea; it is kept because it is the natural form for
#' a jurisdiction with no fitted risk file, and it is documented as unused so
#' nobody reads its presence as evidence that it ships.
#'
#' `shrink` exists to absorb ONE failure: a non-major taking a seat the model
#' called safe for a major. A scalar charges every seat for that insurance --
#' `R/seat_sim.R`'s own note records 672 of 886 federal seat-elections whose
#' measured risk is under 1.5% paying the same premium as the seats that
#' actually go wrong. And the premium is not small: a scalar caps every seat at
#' `1 - shrink/2`, so 0.10 meant no seat could be called above 0.95, measured at
#' about 0.006 of mean log loss on the cap alone.
#'
#' This returns a shrink value per seat: `base` in seats where a non-major is
#' actually within reach, and **exactly zero everywhere else**. The default
#' position is no shrink; a seat has to show the risk before it pays for it.
#'
#' @param shares Numeric matrix of projected seat shares, seats in rows, party
#'   classes in columns -- the same matrix passed to
#'   [simulate_seat_contests()].
#' @param base Shrink rate applied to qualifying seats. `0` disables the
#'   mechanism entirely and returns a vector of zeros.
#' @param floor_share Percentage-point threshold. A seat qualifies when its
#'   largest NON-MAJOR class projects at or above this.
#' @param majors Class labels treated as majors.
#' @return Named numeric vector, one entry per row of `shares`, safe to pass
#'   straight to `simulate_seat_contests(shrink = )`.
#' @export
seat_shrink_vector <- function(shares, base, floor_share = 10,
                               majors = c("ALP", "LNP")) {
  if (!is.matrix(shares) || is.null(colnames(shares)))
    stop("shares must be a matrix with party-class column names")
  if (!is.numeric(base) || length(base) != 1L || !is.finite(base) ||
      base < 0 || base >= 1)
    stop("base must be a single number in [0, 1); got ",
         paste(utils::head(base, 5), collapse = ", "))
  if (!is.numeric(floor_share) || length(floor_share) != 1L ||
      !is.finite(floor_share) || floor_share < 0)
    stop("floor_share must be a single non-negative number; got ", floor_share)
  nm <- setdiff(colnames(shares), majors)
  seats <- rownames(shares)
  if (is.null(seats)) seats <- as.character(seq_len(nrow(shares)))
  out <- stats::setNames(rep(0, nrow(shares)), seats)
  if (base == 0 || !length(nm)) return(out)
  # apply(..., max) over a zero-column matrix returns -Inf, and over a ONE-column
  # matrix R drops to a vector and apply() errors -- both handled explicitly
  # rather than left to a guard that cannot fire on the input it exists to catch.
  sub <- shares[, nm, drop = FALSE]
  top_nm <- if (ncol(sub) == 1L) as.numeric(sub[, 1L]) else
    apply(sub, 1L, function(r) if (all(is.na(r))) 0 else max(r, na.rm = TRUE))
  top_nm[!is.finite(top_nm)] <- 0
  out[top_nm >= floor_share] <- base
  out
}
