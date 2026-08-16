# Internal machinery -----------------------------------------------------

#' Prepare one party's observations for a cycle
#'
#' Shared by [fit_trend()] and [estimate_trend_sigmas()] so the (identical)
#' data prep is done once per optimisation, not once per objective evaluation.
#' Poll shares are transformed to the model scale here (see [to_link()]), so
#' everything downstream is plain linear-Gaussian algebra on `obs$y`.
#'
#' @keywords internal
prep_trend_obs <- function(polls, party, min_firm_polls = 3,
                           scale = c("logit", "points"), prior_result = NA_real_) {
  scale <- match.arg(scale)
  obs <- polls[!is.na(polls[[party]]), c("date", "firm", party), with = FALSE]
  data.table::setnames(obs, party, "y_pct")
  if (nrow(obs) < 5) stop("Only ", nrow(obs), " polls with ", party, " FP - not enough")

  tr <- to_link(obs$y_pct, scale)
  obs[, y := tr$z]
  if (tr$n_clamped > 0.05 * nrow(obs)) {
    warning(sprintf("%s: %d/%d polls clamped to [%.2f, %.2f]%% before transform",
                    party, tr$n_clamped, nrow(obs), SHARE_CLAMP[1], SHARE_CLAMP[2]))
  }

  start <- attr(polls, "cycle_start")
  end <- attr(polls, "cycle_end")
  days <- as.integer(seq(start, min(end, max(obs$date)), by = "day") - start)
  T_ <- length(days)
  obs[, t := as.integer(date - start) + 1L]

  # Pool rarely-seen firms into one house effect
  firm_counts <- obs[, .N, by = firm]
  small <- firm_counts[N < min_firm_polls, firm]
  obs[, firm_eff := ifelse(firm %in% small, "(other firms)", firm)]
  firms <- sort(unique(obs$firm_eff))
  obs[, j := match(firm_eff, firms)]

  # Reference share for translating point-scale priors onto the model scale.
  #
  # This is the party's OBSERVED level in this cycle, not its previous-election
  # result. The translation divides by p(1-p), so linearising at a stale result
  # can inflate a prior by orders of magnitude: Victorian One Nation polled
  # 0.28% in 2022 and 22% now, and translating "5 points" at 0.28% gives a
  # day-0 prior sd of 17.9 log-odds — no prior at all. The level was then
  # identified only by the soft sum-to-zero, and the 2026 band came out as
  # 3.5%-68.9%. Evaluated at the observed level it is 0.39, which is a prior.
  #
  # Only the WIDTH of the priors uses this; the day-0 anchor VALUE is still
  # the previous result, which is a fact about that election.
  p_ref <- mean(obs$y_pct, na.rm = TRUE)
  if (!is.finite(p_ref) || p_ref <= 0) p_ref <- prior_result
  if (!is.finite(p_ref) || p_ref <= 0) {
    # Reachable: a fringe party reported as 0.0 in every poll, called without a
    # previous-election result. p_ref would stay NA, and since max(NA, 0.25) is
    # NA the clamp inside sd_to_link() does not rescue it — every translated
    # prior becomes NaN, lands in the precision matrix, and surfaces as an
    # opaque Cholesky failure with no hint of the cause. Fail here instead.
    stop(sprintf(
      "%s: cannot set a reference share (mean polled %.3f, prior result %s). Supply prior_result.",
      party, mean(obs$y_pct, na.rm = TRUE),
      if (is.na(prior_result)) "NA" else format(prior_result)))
  }

  list(obs = obs, T_ = T_, J = length(firms), days = days, firms = firms,
       start = start, end = end, scale = scale, p_ref = p_ref,
       n_clamped = tr$n_clamped,
       log_jac = log_jacobian(obs$y_pct, scale),
       cycle_year = attr(polls, "cycle_year"))
}

#' Day-0 anchor rule (previous election result, or loosely the first poll)
#'
#' The prior is specified in percentage points and translated onto the model
#' scale at the party's own reference share, so "5 points of uncertainty about
#' a 35% party" and "5 points about a 4% party" keep their intended (very
#' different) relative strengths.
#'
#' @keywords internal
trend_anchor <- function(prep, prior_result) {
  if (is.na(prior_result)) {
    list(val = prep$obs$y[which.min(prep$obs$t)],
         sd = sd_to_link(10, prep$p_ref, prep$scale))
  } else {
    list(val = to_link(prior_result, prep$scale)$z,
         sd = sd_to_link(5, prep$p_ref, prep$scale))
  }
}

#' Prior precision matrix P and linear term b0 (everything except the polls)
#'
#' Random walk + day-0 anchor + house-effect priors + soft poll-count-weighted
#' sum-to-zero constraint on house effects. P is positive definite (the walk
#' alone is rank T-1; the anchor pins the level, the priors pin the houses).
#'
#' @param sigma_rw,sigma_house,szc_sd All in model-scale units. `szc_sd` is
#'   the tolerance of the sum-to-zero constraint; it must be translated by the
#'   caller like every other prior, or the constraint silently changes strength
#'   with the scale and the house effects stop being centred.
#' @keywords internal
trend_prior_system <- function(prep, sigma_rw, sigma_house, anchor, szc_sd) {
  T_ <- prep$T_; J <- prep$J
  n_par <- T_ + J
  ijx <- list()
  add <- function(i, j, x) ijx[[length(ijx) + 1L]] <<- data.frame(i = i, j = j, x = x)

  # Random walk: (x_{t+1} - x_t) ~ N(0, sigma_rw^2)
  w_rw <- 1 / sigma_rw^2
  tt <- seq_len(T_ - 1L)
  add(tt, tt, rep(w_rw, T_ - 1L))
  add(tt + 1L, tt + 1L, rep(w_rw, T_ - 1L))
  add(tt, tt + 1L, rep(-w_rw, T_ - 1L))
  add(tt + 1L, tt, rep(-w_rw, T_ - 1L))

  # Day-0 anchor
  add(1L, 1L, 1 / anchor$sd^2)
  b0 <- numeric(n_par)
  b0[1L] <- anchor$val / anchor$sd^2

  # House effect priors + soft weighted sum-to-zero
  hj <- T_ + seq_len(J)
  add(hj, hj, rep(1 / sigma_house^2, J))
  wj <- prep$obs[, .N, by = j][order(j), N] / nrow(prep$obs)
  w_szc <- 1 / szc_sd^2
  add(rep(hj, each = J), rep(hj, times = J), as.vector(outer(wj, wj)) * w_szc)

  ijx <- do.call(rbind, ijx)
  P <- Matrix::sparseMatrix(i = ijx$i, j = ijx$j, x = ijx$x, dims = c(n_par, n_par))
  list(P = Matrix::forceSymmetric(P), b0 = b0)
}

#' Sparse observation matrix
#'
#' Row k has a 1 in the latent-day column for that poll's date and a 1 in the
#' house-effect column for its firm.
#'
#' @keywords internal
trend_obs_matrix <- function(prep) {
  n <- nrow(prep$obs)
  Matrix::sparseMatrix(
    i = rep(seq_len(n), 2L),
    j = c(prep$obs$t, prep$T_ + prep$obs$j),
    x = 1,
    dims = c(n, prep$T_ + prep$J)
  )
}

#' Per-observation noise sd multipliers from a named per-firm factor vector
#' @keywords internal
obs_noise_factors <- function(prep, firm_factors) {
  if (is.null(firm_factors)) return(rep(1, nrow(prep$obs)))
  fac <- firm_factors[prep$obs$firm]
  fac[is.na(fac)] <- 1
  as.numeric(fac)
}

#' Posterior solve and exact log marginal likelihood
#'
#' Everything is Gaussian, so both the posterior and the evidence are exact:
#'   log p(y) = 1/2 log|P| - 1/2 log|A| - n/2 log(2 pi) + 1/2 sum(log w)
#'              - 1/2 ( sum(w y^2) + b0' P^-1 b0 - b' A^-1 b )
#' with A = P + H'WH, b = b0 + H'Wy. Two sparse Cholesky factorisations.
#'
#' `logml` is the evidence for the TRANSFORMED data; `logml_y` adds the
#' transform's log Jacobian and is therefore in the units of the original
#' percentages, which is the only version comparable across model scales.
#'
#' @param sigma_obs,sigma_rw In model-scale units (see [to_link()]).
#' @param sigma_house_pts House-effect prior sd in percentage points,
#'   translated onto the model scale at the party's reference share.
#' @param want_var If FALSE, skip the posterior-variance solve (the expensive
#'   part) — used inside the hyperparameter optimiser.
#' @param obs_weight Per-observation precision multipliers, or `NULL` for all
#'   ones. This is the hook the Student-t fit uses: a t likelihood is a scale
#'   mixture of normals, so robustness is obtained by reweighting rather than
#'   by changing the solve (see [fit_trend()]'s `nu`).
#' @keywords internal
trend_solve <- function(prep, sigma_obs, sigma_rw, sigma_house_pts, anchor,
                        firm_factors = NULL, want_var = TRUE,
                        szc_sd_pts = 1.5, obs_weight = NULL) {
  sigma_house <- sd_to_link(sigma_house_pts, prep$p_ref, prep$scale)
  szc_sd <- sd_to_link(szc_sd_pts, prep$p_ref, prep$scale)
  prior <- trend_prior_system(prep, sigma_rw, sigma_house, anchor, szc_sd)
  H <- trend_obs_matrix(prep)
  y <- prep$obs$y
  n <- length(y)
  w <- 1 / (sigma_obs * obs_noise_factors(prep, firm_factors))^2
  if (!is.null(obs_weight)) w <- w * obs_weight

  A <- Matrix::forceSymmetric(prior$P + Matrix::crossprod(H, Matrix::Diagonal(x = w) %*% H))
  b <- prior$b0 + as.numeric(Matrix::crossprod(H, w * y))

  ch <- Matrix::Cholesky(A, LDL = FALSE)
  theta <- as.numeric(Matrix::solve(ch, b))

  logdet_P <- as.numeric(Matrix::determinant(prior$P, logarithm = TRUE)$modulus)
  logdet_A <- as.numeric(Matrix::determinant(A, logarithm = TRUE)$modulus)
  mu0 <- as.numeric(Matrix::solve(prior$P, prior$b0))
  quad <- sum(w * y^2) + sum(prior$b0 * mu0) - sum(b * theta)
  logml <- 0.5 * (logdet_P - logdet_A) + 0.5 * sum(log(w)) -
    0.5 * n * log(2 * pi) - 0.5 * quad

  sds <- NULL
  if (want_var) {
    n_par <- prep$T_ + prep$J
    Sigma_diag <- Matrix::diag(Matrix::solve(ch, Matrix::Diagonal(n_par)))
    sds <- sqrt(pmax(Sigma_diag, 0))
  }
  list(theta = theta, sds = sds, logml = logml,
       logml_y = logml + prep$log_jac)
}

#' Robust weights for a Student-t observation model
#'
#' A t likelihood with `nu` degrees of freedom is a scale mixture of normals:
#' each observation gets its own precision multiplier, and the conditional
#' expectation of that multiplier given the current fit is
#' `(nu + 1) / (nu + z^2)` with `z` the standardised residual. Iterating
#' "solve, reweight, solve" is the EM algorithm for t regression, and it
#' converges in a handful of passes.
#'
#' This is why the model does not need MCMC. Fat tails are the one refinement
#' that genuinely wants a sampler in the anchor's Stan implementation, which
#' takes one to four hours per election; as a reweighting of an exact solve it
#' takes about as long as the Gaussian fit.
#'
#' A poll two standard deviations out keeps most of its weight; one five out
#' is discounted heavily. Crucially the discount depends on the size of the
#' residual, not on disagreeing with other pollsters — the distinction between
#' fat tails and the outlier-penalty rules that manufacture herding.
#'
#' @param z Standardised residuals.
#' @param nu Degrees of freedom; `Inf` returns all ones (Gaussian).
#' @keywords internal
robust_weights <- function(z, nu) {
  if (!is.finite(nu)) return(rep(1, length(z)))
  (nu + 1) / (nu + z^2)
}

#' Default (sigma_obs, sigma_rw) for a model scale
#'
#' The logit defaults are the points defaults translated at a 35% share, so
#' the two scales start from the same implied behaviour for a major party.
#' Scale-dependent defaults matter: passing the points-scale 1.7 as a
#' logit-scale sd would be a noise prior of 1.7 log-odds, which is silently
#' catastrophic rather than obviously wrong.
#'
#' @keywords internal
default_sigmas <- function(scale = c("logit", "points")) {
  scale <- match.arg(scale)
  if (scale == "points") c(sigma_obs = 1.7, sigma_rw = 0.10)
  else c(sigma_obs = sd_to_link(1.7, 35, "logit"),
         sigma_rw = sd_to_link(0.10, 35, "logit"))
}

# Public API --------------------------------------------------------------

#' Fit a poll trend for one party over one election cycle
#'
#' Gaussian-exact version of the Jackman (2005) latent-intention model used by
#' the anchor (AE Forecasts): daily latent vote share follows a Gaussian random
#' walk; each poll observes it with a pollster-specific house effect plus
#' noise. Because every term is Gaussian, the posterior is exact and computed
#' in one sparse linear solve — no MCMC. Stan replaces this later when we add
#' fat tails, campaign-varying walk size, and time-varying house effects.
#'
#' Identification: the latent level and house effects are separated by (a) a
#' prior anchoring day 0 at the previous election result, and (b) a soft
#' poll-count-weighted sum-to-zero constraint on house effects (the standard
#' choice; the anchor model weights by bias-consistency instead, a planned
#' refinement).
#'
#' By default the latent walk runs on the LOGIT of vote share rather than raw
#' percentage points, which keeps the trend inside (0, 100), lets a minor
#' party's noise and movement scale with its own size, and makes house effects
#' proportional rather than additive. Returned trends and bands are always
#' back-transformed to percent, so callers see shares either way. See
#' `R/scales.R` for why.
#'
#' @param polls A cycle's polls from [cycle_polls()].
#' @param party Column name, e.g. "ALP".
#' @param prior_result Previous-election vote share for day-0 anchor (percent).
#'   `NA` means anchor loosely to the first poll.
#' @param scale Model scale: "logit" (default) or "points" (the stage-1
#'   behaviour, kept for comparison and for reproducing older fits).
#' @param sigma_obs Poll noise sd (sampling + design effects) in MODEL-SCALE
#'   units, so its meaning depends on `scale`. Estimate it with
#'   [estimate_trend_sigmas()] rather than guessing; `NULL` takes the
#'   scale-appropriate default from [default_sigmas()].
#' @param sigma_rw Daily random-walk sd, likewise in model-scale units.
#' @param sigma_house_pts House-effect prior sd in percentage points
#'   (translated onto the model scale internally).
#' @param min_firm_polls Firms with fewer polls than this share one pooled
#'   "(other firms)" house effect.
#' @param firm_factors Named vector of per-firm noise sd multipliers from
#'   [estimate_firm_factors()]; unnamed firms get 1.
#' @param szc_sd_pts Strength of the soft sum-to-zero constraint on house
#'   effects, in percentage points. House effects are identified only up to a
#'   constant -- lifting every pollster a point and dropping the latent trend a
#'   point fits identically -- so something must pin the level, and this is it.
#'   It encodes how far the polling industry as a WHOLE may sit from the truth:
#'   small values assert the field is collectively unbiased, large values let it
#'   drift together. Hand-set at 0.3 and never measured; exposed here so it can
#'   be varied and tested at all. Translated to the fitted scale by
#'   [sd_to_link()] -- passing a points value straight through as log-odds is
#'   about 20x too weak, which has happened. See docs/CONSTANTS.md.
#' @param want_var Compute the posterior VARIANCE, and so the credible bands.
#'   `TRUE` for anything that plots or publishes a band. `FALSE` when only the
#'   mean is read -- the backtest refits ~200 times and uses endpoint means
#'   only, and profiling puts `Matrix::solve()` + `diag()` for the variance at
#'   31% of the run. The means are unaffected: it is the same solve either way,
#'   with one extra step skipped.
#' @param nu Degrees of freedom for a Student-t observation model. `Inf`
#'   (the default) is the Gaussian fit and is bit-for-bit unchanged. A finite
#'   value — 4 is the usual choice — lets a rogue poll be discounted by the
#'   likelihood in proportion to how far out it is, rather than by a rule that
#'   penalises polls for disagreeing with their neighbours. Fitted by
#'   iteratively reweighted least squares (see [robust_weights()]), so it
#'   costs a few extra sparse solves rather than an MCMC run.
#'
#'   **The default is Gaussian because `nu = 4` was tested and did not help.**
#'   Across 195 (election, horizon) pairs it scored MAE 2.791 against the
#'   eventual result versus 2.779 for the Gaussian fit — indistinguishable,
#'   and marginally worse (better on 107 of 195, sign test p = 0.197). It does
#'   down-weight plenty: 10% of real polls fall below weight 0.5, far above
#'   the ~1.4% clean Gaussian data would produce. Discounting them simply does
#'   not improve the forecast, which suggests those polls carry signal rather
#'   than error. See docs/NEXT-STEPS.md.
#' @param nu_iter Maximum reweighting passes.
#' @param nu_tol Convergence threshold on the largest weight change.
#' @return List: `trend` (date/mean/sd/lo95/hi95 in percent, plus the
#'   model-scale `mean_link`/`sd_link`), `house_effects` (model-scale `effect`
#'   plus `effect_pts`, its size in points at the party's own level),
#'   `residuals` (model scale), `meta` (includes `logml_y`, the evidence in
#'   the units of the original percentages).
#' @export
fit_trend <- function(polls, party,
                      prior_result = NA_real_,
                      scale = c("logit", "points"),
                      sigma_obs = NULL,
                      sigma_rw = NULL,
                      sigma_house_pts = 3,
                      min_firm_polls = 3,
                      firm_factors = NULL,
                      szc_sd_pts = 1.5, want_var = TRUE,
                      nu = Inf, nu_iter = 25L, nu_tol = 1e-4) {
  scale <- match.arg(scale)
  defs <- default_sigmas(scale)
  if (is.null(sigma_obs)) sigma_obs <- defs[["sigma_obs"]]
  if (is.null(sigma_rw)) sigma_rw <- defs[["sigma_rw"]]

  prep <- prep_trend_obs(polls, party, min_firm_polls, scale, prior_result)
  anchor <- trend_anchor(prep, prior_result)

  # Gaussian pass first; with nu = Inf this is the whole fit and the weights
  # stay exactly one, so the default path is unchanged.
  sol <- trend_solve(prep, sigma_obs, sigma_rw, sigma_house_pts, anchor,
                     firm_factors = firm_factors, want_var = want_var,
                     szc_sd_pts = szc_sd_pts)
  obs_w <- rep(1, nrow(prep$obs))
  nu_iters <- 0L
  if (is.finite(nu)) {
    scale_i <- sigma_obs * obs_noise_factors(prep, firm_factors)
    for (it in seq_len(nu_iter)) {
      nu_iters <- it
      fitted_i <- sol$theta[prep$obs$t] + sol$theta[prep$T_ + prep$obs$j]
      z <- (prep$obs$y - fitted_i) / scale_i
      w_new <- robust_weights(z, nu)
      delta <- max(abs(w_new - obs_w))
      obs_w <- w_new
      sol <- trend_solve(prep, sigma_obs, sigma_rw, sigma_house_pts, anchor,
                         firm_factors = firm_factors, want_var = want_var,
                         szc_sd_pts = szc_sd_pts, obs_weight = obs_w)
      if (delta < nu_tol) break
    }
  }

  T_ <- prep$T_
  mu <- sol$theta[seq_len(T_)]
  # With want_var = FALSE there are no posterior sds, so the bands are NA
  # rather than absent: a caller that plots them gets a visible gap instead of
  # a silently narrow band, and one that only reads `mean` is unaffected.
  # NA_real_ (not 0) because a zero-width band is a confident claim.
  s <- if (is.null(sol$sds)) rep(NA_real_, T_) else sol$sds[seq_len(T_)]
  # The band back-transforms exactly (the link is monotone, so quantiles are
  # preserved) and is asymmetric in percent, correctly so for small shares.
  # `mean` is the back-transformed posterior mean, i.e. strictly the median of
  # the share; the Jensen gap is ~0.002 points at realistic posterior sds, far
  # below anything that matters here.
  trend <- data.table::data.table(
    date = prep$start + prep$days,
    mean = from_link(mu, scale),
    lo95 = from_link(mu - 1.96 * s, scale),
    hi95 = from_link(mu + 1.96 * s, scale),
    mean_link = mu, sd_link = s
  )
  trend[, sd := sd_from_link(sd_link, mean, scale)]
  data.table::setcolorder(trend, c("date", "mean", "sd", "lo95", "hi95"))

  hj <- T_ + seq_len(prep$J)
  obs_t_by_firm <- split(prep$obs$t, prep$obs$j)[as.character(seq_len(prep$J))]
  house <- data.table::data.table(
    firm = prep$firms,
    effect = sol$theta[hj],
    # NULL, not NA, when want_var = FALSE -- and data.table DROPS a column
    # assigned NULL rather than filling it. The sibling trend columns two
    # blocks up are deliberately NA for exactly this reason: a caller reading
    # a missing band should see a gap, not a "column not found" from code that
    # worked yesterday. Same treatment here.
    sd = if (is.null(sol$sds)) NA_real_ else sol$sds[hj],
    n_polls = prep$obs[, .N, by = j][order(j), N]
  )
  # Points-equivalent: the average number of percentage points this firm's
  # polls sit above or below the trend, computed exactly at the levels its own
  # polls were taken at. Deliberately NOT a delta-method conversion at the
  # party's prior result — for a party that has moved a long way since the last
  # election (OTH, 14.7% then vs ~8% now) linearising at the stale level
  # overstates the effect by half again, which is exactly the case the logit
  # scale exists to handle. On the points scale this reduces to `effect`.
  house[, effect_pts := vapply(seq_len(.N), function(k) {
    mu_k <- mu[obs_t_by_firm[[k]]]
    mean(from_link(mu_k + effect[k], scale) - from_link(mu_k, scale))
  }, numeric(1))]

  obs <- prep$obs
  residuals <- data.table::data.table(
    date = obs$date, firm = obs$firm, y = obs$y,
    fitted = sol$theta[obs$t] + sol$theta[T_ + obs$j],
    weight = obs_w
  )
  residuals[, resid := y - fitted]

  list(
    trend = trend,
    house_effects = house,
    residuals = residuals,
    meta = list(
      party = party, n_polls = nrow(obs),
      cycle_year = prep$cycle_year,
      cycle_start = prep$start, cycle_end = prep$end,
      scale = scale, p_ref = prep$p_ref, n_clamped = prep$n_clamped,
      sigma_obs = sigma_obs, sigma_rw = sigma_rw,
      prior_result = prior_result,
      nu = nu, nu_iters = nu_iters,
      n_downweighted = sum(obs_w < 0.5),
      logml = sol$logml, logml_y = sol$logml_y
    )
  )
}

#' Fit trends for all viable parties in a cycle
#'
#' @param polls From [cycle_polls()].
#' @param parties Party columns to fit; default: all with >= 30 polls in cycle.
#' @param priors Named vector of previous-election results (percent).
#' @param overrides Named list of per-party argument lists passed to
#'   [fit_trend()], e.g. `list(ONP = list(sigma_rw = 0.25))` to let a volatile
#'   populist party's latent walk move faster.
#' @param ... Passed to [fit_trend()] for every party.
#' @return Named list of [fit_trend()] results.
#' @export
fit_cycle_trends <- function(polls, parties = NULL, priors = NULL,
                             overrides = list(), ...) {
  all_parties <- attr(polls, "parties")
  if (is.null(parties)) {
    counts <- vapply(all_parties, function(p) sum(!is.na(polls[[p]])), 1L)
    parties <- all_parties[counts >= 30]
  }
  out <- lapply(parties, function(p) {
    args <- c(
      list(polls = polls, party = p, prior_result = priors[p] %||% NA_real_),
      list(...)
    )
    for (nm in names(overrides[[p]])) args[[nm]] <- overrides[[p]][[nm]]
    do.call(fit_trend, args)
  })
  names(out) <- parties
  out
}

#' Fit a cycle, forcing any structurally invalid fit onto the logit scale
#'
#' Wraps [fit_cycle_trends()] with the [scale_breaches()] guard. Evidence
#' chooses the scale per party, but a fit whose 95% band includes a negative
#' vote share is invalid regardless of its likelihood, so it is refitted on the
#' logit scale, which cannot leave (0, 100).
#'
#' Escalation DROPS that party's estimated sigmas as well as its scale: they
#' were estimated in points and are meaningless as log-odds (a `sigma_obs` of
#' 1.9 points is a plausible poll noise; 1.9 log-odds is not), so the refit
#' falls back to [default_sigmas()] for the new scale.
#'
#' @inheritParams fit_cycle_trends
#' @param verbose Report escalations (default TRUE) — a silent scale switch
#'   would hide a real modelling problem.
#' @return As [fit_cycle_trends()], with an `escalated` attribute naming any
#'   parties moved to logit.
#' @export
fit_cycle_trends_guarded <- function(polls, parties = NULL, priors = NULL,
                                     overrides = list(), verbose = TRUE, ...) {
  fits <- fit_cycle_trends(polls, parties, priors, overrides, ...)
  breach <- scale_breaches(fits)
  if (!length(breach)) return(fits)

  if (verbose) {
    message("  L2 escalation to logit (points fit left (0, 100)): ",
            paste(breach, collapse = ", "))
  }
  for (p in breach) {
    keep <- setdiff(names(overrides[[p]]), c("scale", "sigma_obs", "sigma_rw"))
    overrides[[p]] <- c(list(scale = "logit"), overrides[[p]][keep])
  }
  fits <- fit_cycle_trends(polls, parties, priors, overrides, ...)
  still <- scale_breaches(fits)
  if (length(still)) {
    stop("Fitted band still leaves (0, 100) after escalating to logit: ",
         paste(still, collapse = ", "))
  }
  data.table::setattr(fits, "escalated", breach)
  fits
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a
