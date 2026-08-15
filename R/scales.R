# Model scales -----------------------------------------------------------
#
# Vote shares are bounded in [0, 100] and their sampling noise depends on the
# share itself, so a Gaussian random walk in raw percentage points is wrong in
# three ways: it can wander outside the simplex, it forces one noise level onto
# a 3% party and a 40% party, and it measures movement additively when minor
# parties actually move multiplicatively (ONP going 2% -> 26% is a 13x change,
# not a "24 point" change like a major moving 30% -> 54% would be).
#
# The fix is to fit the same linear-Gaussian machinery to logit-transformed
# poll shares. Because the transform applies to the DATA, every downstream
# solve is unchanged; only the prior translation and the back-transform are
# new. House effects then become log-odds ratios, i.e. a pollster who runs the
# Greens high runs them proportionally high rather than by a fixed number of
# points, which is the more plausible model of a methodological bias.

#' Smallest and largest share (percent) representable on the logit scale
#' @keywords internal
SHARE_CLAMP <- c(0.25, 99.75)

#' Transform poll shares (percent) to the model scale
#'
#' @param y Shares in percent.
#' @param scale "logit" or "points".
#' @return List: `z` (model scale), `n_clamped`.
#' @keywords internal
to_link <- function(y, scale = c("logit", "points")) {
  scale <- match.arg(scale)
  if (scale == "points") return(list(z = y, n_clamped = 0L))
  yc <- pmin(pmax(y, SHARE_CLAMP[1]), SHARE_CLAMP[2])
  q <- yc / 100
  list(z = log(q / (1 - q)), n_clamped = sum(yc != y, na.rm = TRUE))
}

#' Back-transform from the model scale to shares (percent)
#' @keywords internal
from_link <- function(z, scale = c("logit", "points")) {
  scale <- match.arg(scale)
  if (scale == "points") return(z)
  100 / (1 + exp(-z))
}

#' Log Jacobian |dz/dy| of the transform, evaluated at the observed shares
#'
#' Needed to compare marginal likelihoods ACROSS scales: the evidence returned
#' by a fit is the density of the transformed data, so comparing a logit-scale
#' logml with a points-scale one without this term compares densities in
#' different units and is meaningless. Adding it puts both in the units of the
#' original percentages, where they are directly comparable.
#'
#' @keywords internal
log_jacobian <- function(y, scale = c("logit", "points")) {
  scale <- match.arg(scale)
  if (scale == "points") return(0)
  yc <- pmin(pmax(y, SHARE_CLAMP[1]), SHARE_CLAMP[2])
  q <- yc / 100
  sum(-log(100) - log(q) - log(1 - q))
}

#' Convert an sd in percentage points to the model scale (delta method)
#'
#' @param sd_pts Standard deviation in percentage points.
#' @param p Share (percent) at which to linearise.
#' @keywords internal
sd_to_link <- function(sd_pts, p, scale = c("logit", "points")) {
  scale <- match.arg(scale)
  if (scale == "points") return(sd_pts)
  q <- min(max(p, SHARE_CLAMP[1]), SHARE_CLAMP[2]) / 100
  sd_pts / (100 * q * (1 - q))
}

#' Convert an sd on the model scale back to percentage points (delta method)
#' @keywords internal
sd_from_link <- function(sd_link, p, scale = c("logit", "points")) {
  scale <- match.arg(scale)
  if (scale == "points") return(sd_link)
  q <- pmin(pmax(p, SHARE_CLAMP[1]), SHARE_CLAMP[2]) / 100
  sd_link * 100 * q * (1 - q)
}

#' Parties whose fitted band leaves the valid vote-share range
#'
#' A structural validity check, not a diagnostic: a fit whose 95% band includes
#' a negative vote share is invalid whatever its likelihood says, so this
#' overrides evidence-based scale selection. Only the points scale can fail it
#' — the logit scale cannot leave (0, 100) by construction.
#'
#' Both real failures found so far were small parties moving a long way on thin
#' data (NSW SFF 2023, NSW ONP 2027, the latter reporting a 5-point-wide band
#' from 8 polls spanning 4-30%), where the points fit was not merely invalid
#' but badly overconfident.
#'
#' @param fits Named list from [fit_cycle_trends()].
#' @return Character vector of offending party names (empty if all valid).
#' @export
scale_breaches <- function(fits) {
  bad <- vapply(fits, function(f)
    any(f$trend$lo95 <= 0 | f$trend$hi95 >= 100 | !is.finite(f$trend$mean)),
    logical(1))
  names(fits)[bad]
}

#' Binomial sampling sd on the model scale
#'
#' The floor any honest poll must exceed: no design can be quieter than pure
#' random sampling. On the logit scale this is `1 / sqrt(n q (1-q))`, which
#' rises as the share falls — the opposite of the points scale, and a useful
#' sanity property when checking estimated noise.
#'
#' @param p Share in percent. @param n Sample size.
#' @keywords internal
binomial_sd_link <- function(p, n, scale = c("logit", "points")) {
  scale <- match.arg(scale)
  q <- min(max(p, SHARE_CLAMP[1]), SHARE_CLAMP[2]) / 100
  if (scale == "points") return(100 * sqrt(q * (1 - q) / n))
  1 / sqrt(n * q * (1 - q))
}
