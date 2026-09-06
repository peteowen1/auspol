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

#' Reference sample size for the binomial noise floor
#'
#' "A poll cannot be less variable than random sampling makes it" underpins two
#' things: the `H1`/`L4b` checks that halt the pipeline, and the *Variability*
#' column the page publishes against named polling companies. Both need an
#' assumed sample size, because the source poll files carry no sample-size
#' column and there is nothing to estimate one from.
#'
#' They used to disagree -- 2500 in the fit scripts, 1500 in the scorecard --
#' and each was defensible alone. Two values for one physical quantity is not:
#' a reader comparing the published Variability figure against the pipeline's
#' herding check would get different answers about the same firm.
#'
#' Unified on the LARGER, which is deliberately the conservative direction. A
#' bigger assumed sample means a smaller binomial sd, a weaker floor, and so
#' fewer firms flagged as less variable than sampling allows. That claim is an
#' accusation of herding against a named company, and the asymmetry matters:
#' failing to flag a herder costs us a note in a table, wrongly flagging an
#' honest pollster costs them.
#'
#' @keywords internal
BINOMIAL_REF_N <- 2500

#' Sensitive reference sample size, for reporting rather than halting
#'
#' The fit scripts deliberately carry a second, smaller reference alongside
#' [BINOMIAL_REF_N], and on inspection that is a design rather than the
#' accident it first looked like. A smaller assumed sample means a higher
#' floor and a more sensitive test, which is right for a diagnostic that
#' PRINTS a herding signal and wrong for one that HALTS the pipeline.
#'
#' So: `BINOMIAL_REF_N` for anything that stops a run or makes a published
#' claim about a named firm, this for anything that merely says "look here".
#' Two values, deliberately, each with its job written down -- as opposed to
#' two values because two files were edited on different days.
#'
#' @keywords internal
BINOMIAL_SENSITIVE_N <- 1500

#' Minimum polls in a cycle before a party is fitted at all
#'
#' This decides which parties EXIST in the forecast -- a party under the
#' floor is not fitted, its vote stays inside `OTH`, and `unfold_others()`
#' cannot run on it. It is not an input-sanity guard, which is how it was
#' filed until 2026-08-19 and why nobody looked at it.
#'
#' **8. Tried at 15 and reverted, both 2026-08-24** -- see
#' `docs/plans/prereg-inclusion-floor-15-adoption.md`. 15 beats 8 by 0.061
#' MAE, three times the adoption bar, monotonic across the whole grid -- but
#' drops One Nation from the NSW 2027 cycle (21.0% on 8 polls), folding a
#' party polling in the twenties into `OTH` where it cannot be told apart
#' from the rest. Adopted first with that cost disclosed and accepted
#' (Victoria 2026, the only forecast this repo publishes, is unaffected), then
#' reverted on Pete's re-examination: a live-cycle party going invisible is
#' not acceptable even in an unpublished cycle, whatever the historical MAE
#' says. `scripts/test_inclusion_floor.R`'s anchor check (`IF6`) is what
#' caught this the first time (2026-08-19, informally) and would catch it
#' again for any future floor experiment.
#'
#' Applies to the state scripts (`fit_vic.R`, `fit_nsw.R`) only. Federal's
#' separate, denser-polling floor (25) is untouched and untested by this.
#'
#' @keywords internal
PARTY_INCLUSION_FLOOR <- 8L

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
  bad <- vapply(fits, function(f) {
    # A fit made with want_var = FALSE has NA bands. `NA <= 0` is NA, so the
    # whole expression collapses to NA, `any()` returns NA, and
    # `names(fits)[NA]` yields NA_character_ -- a length-1 vector, so the
    # caller's `if (!length(breach))` short-circuit does NOT fire and it goes
    # on to "fix" a party called NA. The guard would be silently disabled by
    # an optimisation made elsewhere, which is precisely the failure this
    # function exists to prevent in the fits it inspects.
    if (anyNA(f$trend$lo95) || anyNA(f$trend$hi95)) {
      stop("scale_breaches() needs credible bands, and this fit has none ",
           "(fitted with want_var = FALSE). Refit with want_var = TRUE, or ",
           "do not run this guard on that fit.", call. = FALSE)
    }
    any(f$trend$lo95 <= 0 | f$trend$hi95 >= 100 | !is.finite(f$trend$mean))
  }, logical(1))
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
