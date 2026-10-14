# Jurisdiction-level partial pooling (AUSPOL_POOL_BY_JURISDICTION, default "0" = OFF).
#
# WHY. On 2026-10-13 the backtest grew from 23 to 35 elections. Fits that take ONE
# median over every individual case across jurisdictions now let whichever
# jurisdiction contributes the most cases set the number for all the others. The
# measured instance: the sitting-member defector carry (fit_defector_discount()).
# Before the Northern Territory there were 4 state cases; NT added 5, the median
# moved 0.274 -> 0.439 and wa2017's seat log loss went 0.4057 -> 0.4640 (Hillarys:
# Rob Johnson IND predicted 19.9 -> 28.7, actual 20.1). An NT seat has ~5,000
# voters, where a personal vote plausibly carries further than in a WA seat.
#
# WHAT. pool_by_group() treats each jurisdiction as one draw from a common
# distribution (a random-effects / partial-pooling model):
#   1. each group's centre est_g is the MEDIAN of its cases, with standard error
#      se_g = 1.2533 * s_g / sqrt(n_g). s_g is the group's own spread around its
#      median MODERATED toward the pooled within-group spread s (every case's
#      distance from its own group's median, on N - G degrees of freedom) with
#      prior_df = 3 pseudo-degrees of freedom: s_g^2 = (SS_g + 3 s^2) / (n_g - 1 + 3).
#      So a one-case group still has a finite, honest se (the pooled one), a
#      tight three-case group cannot claim to be precise by luck, and a large
#      tight group (federal defectors, sd 0.07 against the Territory's 0.31) is
#      not buried in another group's noise. 1.2533 = sqrt(pi/2), the
#      large-sample efficiency loss of a median against a mean.
#   2. tau^2, the between-group variance, by the DerSimonian-Laird method of
#      moments: (Q - (k - 1)) / (sum w - sum w^2 / sum w), w = 1/se_g^2, floored at
#      0. That is the spread of the group centres NET of the spread their own
#      noise would produce.
#   3. the national centre mu is the precision-weighted mean of the GROUP
#      estimates, weights 1/(se_g^2 + tau^2). When groups genuinely differ (tau^2
#      large) every group counts about once whatever its case count; when they do
#      not (tau^2 = 0) a case is a case and the weights follow n.
#   4. the target's own group is shrunk toward mu: mu + w (est_g - mu),
#      w = tau^2 / (tau^2 + se_g^2). A target jurisdiction with no cases gets mu.
#
# Median on the raw scale, not a mean on a transformed one: the callers already
# report medians, so "0" and "1" differ only in how cases are pooled, not in the
# statistic. No electorate-size covariate: with at most nine groups, mostly 1-9
# cases each, and electorate size almost constant within a jurisdiction (NT is
# the only small-electorate one), a slope on log size cannot be told apart from
# the NT group effect this already estimates. Not built; say so if asked.

#' Jurisdiction of an election label
#'
#' `"wa2017"` -> `"wa"`, `"fed2025"` -> `"fed"`: the label with its trailing
#' year removed, lower-cased.
#'
#' @param election Character vector of election labels.
#' @return Character vector of jurisdiction codes (`fed`, `nsw`, `vic`, `qld`,
#'   `sa`, `wa`, `nt`, `tas`, `act`).
#' @export
jurisdiction_of <- function(election) {
  tolower(sub("[0-9]+$", "", as.character(election)))
}

#' Is jurisdiction-level pooling switched on?
#'
#' Reads `AUSPOL_POOL_BY_JURISDICTION` (default `"0"`).
#' @return `TRUE` when the switch is `"1"`.
#' @export
pool_by_jurisdiction_on <- function() {
  identical(Sys.getenv("AUSPOL_POOL_BY_JURISDICTION", "0"), "1")
}

#' Partially pool case-level estimates by group (jurisdiction)
#'
#' Each group's median is shrunk toward the precision-weighted mean of the group
#' medians, by how precisely that group's median is measured against how much the
#' groups genuinely differ. See the header of `R/pool_hierarchical.R` for the
#' method and why it exists.
#'
#' @param est_cases Numeric vector, one value per case.
#' @param group Character vector, the group (jurisdiction) of each case.
#' @param target_group The group whose estimate is wanted.
#' @param min_cases Fewer finite cases than this in total: `estimate` is `NA`.
#' @param prior_df Pseudo-degrees of freedom with which each group's own spread
#'   is moderated toward the pooled within-group spread (`POOL_PRIOR_DF`, 3:
#'   the same three pseudo-cases `.DEFSTATE_K` uses). `Inf` = one common spread.
#' @return A list: `estimate` (for `target_group`), `mu`, `tau2`, `s_within`,
#'   `groups` (a data.table: group, n, est, se, w, shrunk), `target_group`,
#'   `n_target`, `n` (cases used).
#' @export
pool_by_group <- function(est_cases, group, target_group, min_cases = 1L, prior_df = 3) {
  if (length(est_cases) != length(group))
    stop("pool_by_group(): est_cases and group differ in length", call. = FALSE)
  keep <- is.finite(est_cases) & !is.na(group) & nzchar(group)
  x <- as.numeric(est_cases[keep]); g <- as.character(group[keep])
  tgt <- as.character(target_group)
  empty <- data.table::data.table(group = character(), n = integer(), est = numeric(),
                                  se = numeric(), w = numeric(), shrunk = numeric())
  if (length(x) < max(1L, min_cases))
    return(list(estimate = NA_real_, mu = NA_real_, tau2 = NA_real_, s_within = NA_real_,
                groups = empty, target_group = tgt, n_target = 0L, n = length(x)))
  ug <- sort(unique(g))
  n_g <- vapply(ug, function(k) sum(g == k), integer(1))
  est_g <- vapply(ug, function(k) stats::median(x[g == k]), numeric(1))
  # pooled within-group spread around each group's own median
  resid <- x - est_g[match(g, ug)]
  N <- length(x); G <- length(ug)
  s <- if (N > G) sqrt(sum(resid^2) / (N - G)) else if (N > 1L) stats::sd(x) else NA_real_
  if (!is.finite(s) || s <= 0) {
    # every group's cases identical (or a single case): no measurable noise. Fall
    # back to the overall spread; with none at all, the groups are taken as exact.
    s <- if (N > 1L && stats::sd(x) > 0) stats::sd(x) else 0
  }
  # Each group's own spread, moderated toward the pooled one with `prior_df`
  # pseudo-degrees of freedom: a one-case group gets the pooled spread, a large
  # group mostly its own. Groups are NOT equally noisy (federal defector ratios
  # sd 0.07, Northern Territory 0.31), and one pooled spread would bury a tight,
  # genuinely different group in the noise of a loose one.
  ss_g <- vapply(ug, function(k) sum(resid[g == k]^2), numeric(1))
  df_g <- n_g - 1L
  v_g <- if (is.infinite(prior_df)) rep(s^2, G)
         else if (prior_df <= 0) ifelse(df_g > 0, ss_g / pmax(df_g, 1L), s^2)
         else (ss_g + prior_df * s^2) / (df_g + prior_df)
  se_g <- 1.2533 * sqrt(v_g) / sqrt(n_g)
  if (G >= 2L && all(se_g > 0)) {
    wf <- 1 / se_g^2
    ybar <- sum(wf * est_g) / sum(wf)
    Q <- sum(wf * (est_g - ybar)^2)
    denom <- sum(wf) - sum(wf^2) / sum(wf)
    tau2 <- if (denom > 0) max(0, (Q - (G - 1)) / denom) else 0
  } else {
    tau2 <- 0
  }
  wr <- if (all(se_g^2 + tau2 > 0)) 1 / (se_g^2 + tau2) else rep(1, G)
  mu <- sum(wr * est_g) / sum(wr)
  w <- ifelse(tau2 + se_g^2 > 0, tau2 / (tau2 + se_g^2), 1)
  shrunk <- mu + w * (est_g - mu)
  groups <- data.table::data.table(group = ug, n = unname(n_g), est = unname(est_g),
                                   se = unname(se_g), w = unname(w), shrunk = unname(shrunk))
  hit <- match(tgt, ug)
  list(estimate = if (is.na(hit)) mu else unname(shrunk[hit]), mu = mu, tau2 = tau2, s_within = s,
       groups = groups, target_group = tgt,
       n_target = if (is.na(hit)) 0L else unname(n_g[hit]), n = N)
}

#' One-line description of a pool_by_group() result, for logs
#' @param p A [pool_by_group()] result.
#' @return A character string.
#' @noRd
.pool_summary <- function(p) {
  if (!nrow(p$groups)) return("no cases")
  sprintf("target %s (n=%d) -> %.3f | mu %.3f, tau2 %.4f, s %.3f | %s",
          p$target_group, p$n_target, p$estimate, p$mu, p$tau2, p$s_within,
          paste(sprintf("%s n=%d med %.3f w %.2f", p$groups$group, p$groups$n,
                        p$groups$est, p$groups$w), collapse = "; "))
}
