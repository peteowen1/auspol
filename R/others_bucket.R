#' How much to shrink the unpolled "others" bucket, fitted on earlier elections
#'
#' Polls overstate the classes they do not track (the bucket of OTH plus every
#' class folded into it): too big in 17 of 22 past elections, by about 2
#' points. This fits a multiplicative correction `k` from elections held
#' STRICTLY BEFORE `before`, so a backtest never learns from its own or a
#' later result.
#'
#' On log ratios, log(actual / forecast), `k = exp(w * m)` where `m` is their
#' mean and `w = m^2 / (m^2 + se^2)`: the mean is kept in proportion to how clearly it
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

#' The others-bucket scale fitted PER JURISDICTION, partially pooled
#'
#' The all-jurisdiction fit ([others_bucket_scale()]) was refused 2026-09-28
#' partly because the poll overstatement of the unpolled bucket is not the
#' same everywhere: the two majors' summed first-preference miss is about
#' +4.4 points in Victoria and +4.6 in Queensland, about 0 federally and
#' negative in NSW and SA (docs/reviews/major-party-error-2026-10-06.md,
#' pattern 2). A pooled bias averages to nearly nothing.
#'
#' Time-forward throughout: only elections dated strictly before `before`
#' are used, for the jurisdiction's own mean, for the between-jurisdiction
#' variance and for the pooled prior. On log ratios `r = log(actual /
#' forecast)` of the bucket:
#'
#' * prior `mu0` is the correction the pooled fit applies (`w0 * m0`, so a
#'   jurisdiction with no history gets exactly the pooled `k`);
#' * the jurisdiction mean `m_j` has `se_j^2 = sigma^2 / n_j`, with `sigma^2`
#'   the within-jurisdiction variance of `r` over all earlier elections
#'   (the overall variance when every jurisdiction has only one);
#' * `tau^2` is the between-jurisdiction variance of the means, method of
#'   moments, floored at 0 (0 when fewer than two jurisdictions have history);
#' * `w = tau^2 / (tau^2 + se_j^2)` and `log k = mu0 + w * (m_j - mu0)`.
#'
#' No minimum-n cliff: with no earlier election of the jurisdiction `w = 0`
#' and `k` is the pooled value; with one the weight is whatever `tau^2` and
#' `sigma^2` allow.
#'
#' @param before Date; only elections dated before it are used.
#' @param region Jurisdiction code of the target, e.g. `"vic"`.
#' @param hist As in [others_bucket_scale()].
#' @return list: `k` (final multiplier), `k_pooled`, `region`, `n_jur`,
#'   `m_jur`, `se_jur`, `tau2`, `sigma2`, `w`, `n` (all earlier elections),
#'   `pairs` (earlier elections of this jurisdiction used).
#' @export
others_bucket_scale_jur <- function(before, region, hist = NULL) {
  before <- as.Date(before)
  if (!is.finite(before)) stop("others_bucket_scale_jur(): `before` must be a date.")
  if (!is.character(region) || length(region) != 1L || is.na(region) || !nzchar(region)) {
    stop("others_bucket_scale_jur(): `region` must be one jurisdiction code.")
  }
  if (is.null(hist)) {
    f <- out_path("others-bucket-history.csv")
    if (!file.exists(f)) {
      stop("output/others-bucket-history.csv is missing. Build it with ",
           "scripts/build_others_bucket_history.R from an audit run with ",
           "AUSPOL_OTHERS_SCALE off.")
    }
    hist <- data.table::fread(f, showProgress = FALSE)
  }
  pooled <- others_bucket_scale(before, hist)
  mu0 <- if (pooled$n >= 2L && is.finite(pooled$m)) pooled$w * pooled$m else 0
  use <- which(as.Date(hist$date) < before)
  r_all <- log(hist$bucket_act[use] / hist$bucket_fc[use])
  reg_all <- sub("[0-9]+$", "", hist$pair[use])
  pairs_all <- hist$pair[use]
  ok <- is.finite(r_all)
  r_all <- r_all[ok]; reg_all <- reg_all[ok]; pairs_all <- pairs_all[ok]
  in_j <- reg_all == region
  n_j <- sum(in_j)
  out <- list(k = pooled$k, k_pooled = pooled$k, region = region, n_jur = n_j,
              m_jur = NA_real_, se_jur = NA_real_, tau2 = 0, sigma2 = NA_real_,
              w = 0, n = length(r_all), pairs = pairs_all[in_j])
  if (n_j == 0L) return(out)

  # per-jurisdiction means and the within variance, all from earlier elections
  by_j <- split(r_all, reg_all)
  jm <- vapply(by_j, mean, numeric(1))
  jn <- vapply(by_j, length, numeric(1))
  ss <- sum(vapply(by_j, function(v) sum((v - mean(v))^2), numeric(1)))
  df <- length(r_all) - length(by_j)
  sigma2 <- if (df >= 1L) ss / df else if (length(r_all) >= 2L) stats::var(r_all) else NA_real_
  if (!is.finite(sigma2)) return(out)   # one earlier election in total: no noise estimate
  m_j <- unname(jm[region]); se2 <- sigma2 / n_j
  tau2 <- if (length(jm) >= 2L) max(0, stats::var(jm) - mean(sigma2 / jn)) else 0
  w <- if (tau2 + se2 > 0) tau2 / (tau2 + se2) else 0
  out$m_jur <- m_j; out$se_jur <- sqrt(se2); out$tau2 <- tau2; out$sigma2 <- sigma2
  out$w <- w
  out$k <- exp(mu0 + w * (m_j - mu0))
  out
}
