#' How much to shrink the unpolled "others" bucket, fitted on earlier elections
#'
#' Polls overstate the classes they do not track (the bucket of OTH plus every
#' class folded into it): too big in 17 of 22 past elections, by about 2
#' points. This fits a multiplicative correction `k` from elections held
#' STRICTLY BEFORE `before`, so a backtest never learns from its own or a
#' later result.
#'
#' On log ratios `r = log(actual / forecast)`, `k = exp(w * mean(r))` with
#' `w = m^2 / (m^2 + se^2)`: the mean is kept in proportion to how clearly it
#' stands out from its own noise, so a bias that is not yet distinguishable
#' from zero is barely applied. Fewer than two earlier elections give `k = 1`.
#' docs/plans/prereg-others-bucket-size-2026-09-27.md.
#'
#' @param before Date; only elections dated before it are used.
#' @param hist data.table with `pair`, `date`, `bucket_fc`, `bucket_act`, as
#'   written by `scripts/build_others_bucket_history.R`. Read from
#'   `output/others-bucket-history.csv` when NULL.
#' @return list: `k`, `n`, `m` (mean log ratio), `se`, `w`, `pairs` used.
#' @export
others_bucket_scale <- function(before, hist = NULL) {
  before <- as.Date(before)
  if (!is.finite(before)) stop("others_bucket_scale(): `before` must be a date.")
  if (is.null(hist)) {
    f <- out_path("others-bucket-history.csv")
    if (!file.exists(f)) {
      stop("output/others-bucket-history.csv is missing. Build it with ",
           "scripts/build_others_bucket_history.R from an audit run with ",
           "AUSPOL_OTHERS_SCALE off.")
    }
    hist <- data.table::fread(f, showProgress = FALSE)
  }
  d_hist <- as.Date(hist$date)
  if (anyNA(d_hist)) stop("others bucket history has an undated row; it cannot be ordered.")
  use <- which(d_hist < before)
  r <- log(hist$bucket_act[use] / hist$bucket_fc[use])
  r <- r[is.finite(r)]
  n <- length(r)
  if (n < 2L) {
    return(list(k = 1, n = n, m = NA_real_, se = NA_real_, w = 0,
                pairs = hist$pair[use]))
  }
  m <- mean(r)
  se <- stats::sd(r) / sqrt(n)
  w <- if (isTRUE(m^2 + se^2 > 0)) m^2 / (m^2 + se^2) else 0
  list(k = exp(w * m), n = n, m = m, se = se, w = w, pairs = hist$pair[use])
}

#' Scale the others bucket in a matrix of statewide draws
#'
#' Multiplies the bucket columns by `k` in every draw and returns the share
#' removed (or added) to the remaining columns in proportion to their own
#' draw, so each row still sums to what it did.
#'
#' @param draws Matrix of first-preference draws, one column per class.
#' @param bucket Column names forming the bucket.
#' @param k Multiplier from [others_bucket_scale()].
#' @return The adjusted matrix.
#' @export
others_bucket_apply <- function(draws, bucket, k) {
  bucket <- intersect(bucket, colnames(draws))
  rest <- setdiff(colnames(draws), bucket)
  if (!length(bucket) || !length(rest) || isTRUE(all.equal(k, 1))) return(draws)
  tot <- rowSums(draws)
  b_old <- rowSums(draws[, bucket, drop = FALSE])
  r_old <- tot - b_old
  draws[, bucket] <- draws[, bucket, drop = FALSE] * k
  # what the rest must hold so the row total is unchanged
  draws[, rest] <- draws[, rest, drop = FALSE] * ((tot - b_old * k) / r_old)
  draws
}
