# Partially pooled sitting-member slopes (AUSPOL_MP_SLOPE_POOL=1).
#
# docs/plans/prereg-mp-slope-pool-2026-10-25.md. Replaces two different rules
# that disagreed about the same quantity:
#   * the live forecast (scripts/fit_seats_full.R) kept a class's member slope
#     only at n_member >= 8 and used the raw per-class fit above it (a min_n
#     cliff: n = 7 ignored outright, n = 8 believed outright);
#   * the harnesses read output/mp-slope-by-target.csv, where every class is
#     kept and shrunk toward the all-class slope by n / (n + 10).
# Pete, 2026-10-25: shrinkage with no cutoff, the same rule in live and in all
# harnesses. This is that rule, the CLAUDE.md "Fit constants with SHRINKAGE"
# form:
#
#   w_i    = tau^2 / (tau^2 + se_i^2)       tau^2 = between-class variance
#   member = mu + w_i * (est_i - mu)
#
# est_i  slope through the origin of dev_now on dev_prev for class i's member
#        rows: sum(x y) / sum(x^2). Defined from ONE row (no n >= 3 floor).
# se_i   sigma / sqrt(sum(x_i^2)), sigma^2 the residual variance POOLED over
#        classes (each class around its own slope). A class's own residual
#        variance is not used: from two or three rows it can come out near zero
#        and would then claim a precision the class does not have.
# tau^2  DerSimonian-Laird moment estimate over the classes with data,
#        floored at 0. With fewer than two such classes it cannot be estimated
#        and is 0, so every class gets mu.
# mu     supplied by the caller: the all-class member slope on the same rows.
#
# A class with no member rows (or no spread in dev_prev) has w = 0 and gets mu.
# Nothing is dropped for being thin; thin classes degrade toward mu.
#
# Why not pool_by_group() (R/pool_hierarchical.R), which already does
# DerSimonian-Laird partial pooling: it pools the MEDIAN of per-case values, and
# a slope through the origin has no per-case value (dev_now / dev_prev blows up
# wherever a seat sat near the statewide level). The tau^2 estimator and the
# shrink are the same; the per-class estimate and its se are a regression's.
# Its one common within-class sigma is pool_by_group(prior_df = Inf).

#' Partially pool per-class sitting-member slopes toward a common slope
#'
#' @param rows Member rows (one per returning-member seat-class) with columns
#'   `party`, `dev_prev`, `dev_now`. Rows for classes not in `classes` are
#'   ignored.
#' @param classes Classes to return, one row each, in this order.
#' @param mu The slope every class is shrunk toward (the all-class slope on the
#'   same rows).
#' @return A data.table with `party`, `n_member`, `est`, `se`, `mu`, `tau2`,
#'   `w` and `member` (the pooled slope).
#' @noRd
mp_slope_pool <- function(rows, classes, mu) {
  stopifnot(is.character(classes), !anyDuplicated(classes),
            length(mu) == 1L, is.finite(mu))
  rows <- as.data.frame(rows)
  miss <- setdiff(c("party", "dev_prev", "dev_now"), names(rows))
  if (length(miss)) stop("mp_slope_pool(): rows lack ", paste(miss, collapse = ", "), call. = FALSE)
  ok <- rows$party %in% classes & is.finite(rows$dev_prev) & is.finite(rows$dev_now)
  bad <- sum(rows$party %in% classes & !ok)
  if (bad) stop("mp_slope_pool(): ", bad, " member row(s) with a non-finite deviation", call. = FALSE)
  rows <- rows[ok, , drop = FALSE]
  cls_of <- as.character(rows$party)
  n   <- vapply(classes, function(cl) sum(cls_of == cl), integer(1))
  sxx <- vapply(classes, function(cl) sum(rows$dev_prev[cls_of == cl]^2), numeric(1))
  sxy <- vapply(classes, function(cl) sum(rows$dev_prev[cls_of == cl] * rows$dev_now[cls_of == cl]), numeric(1))
  has <- n > 0L & sxx > 0
  est <- ifelse(has, sxy / ifelse(has, sxx, 1), NA_real_)
  rss <- vapply(seq_along(classes), function(i) {
    if (!has[i]) return(0)
    k <- cls_of == classes[i]
    sum((rows$dev_now[k] - est[i] * rows$dev_prev[k])^2)
  }, numeric(1))
  k_obs <- sum(has); df <- sum(n[has]) - k_obs
  sigma2 <- if (df >= 1L) sum(rss[has]) / df else NA_real_
  se <- ifelse(has & is.finite(sigma2), sqrt(sigma2 / ifelse(has, sxx, 1)), NA_real_)
  tau2 <- 0
  if (k_obs >= 2L && is.finite(sigma2) && sigma2 > 0) {
    v  <- 1 / se[has]^2
    mf <- sum(v * est[has]) / sum(v)
    Q  <- sum(v * (est[has] - mf)^2)
    den <- sum(v) - sum(v^2) / sum(v)
    if (den > 0) tau2 <- max(0, (Q - (k_obs - 1L)) / den)
  }
  w <- ifelse(has & is.finite(se) & (tau2 + se^2) > 0, tau2 / (tau2 + se^2), 0)
  member <- ifelse(w > 0, mu + w * (est - mu), mu)
  data.table::data.table(party = classes, n_member = unname(n), est = unname(est),
                         se = unname(se), mu = mu, tau2 = tau2, w = unname(w),
                         member = unname(member))
}
