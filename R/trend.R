# Internal machinery -----------------------------------------------------

#' Prepare one party's observations for a cycle
#'
#' Shared by [fit_trend()] and [estimate_trend_sigmas()] so the (identical)
#' data prep is done once per optimisation, not once per objective evaluation.
#'
#' @keywords internal
prep_trend_obs <- function(polls, party, min_firm_polls = 3) {
  obs <- polls[!is.na(polls[[party]]), c("date", "firm", party), with = FALSE]
  data.table::setnames(obs, party, "y")
  if (nrow(obs) < 5) stop("Only ", nrow(obs), " polls with ", party, " FP - not enough")

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

  list(obs = obs, T_ = T_, J = length(firms), days = days, firms = firms,
       start = start, end = end,
       cycle_year = attr(polls, "cycle_year"))
}

#' Day-0 anchor rule (previous election result, or loosely the first poll)
#' @keywords internal
trend_anchor <- function(prep, prior_result) {
  if (is.na(prior_result)) {
    list(val = prep$obs$y[which.min(prep$obs$t)], sd = 10)
  } else {
    list(val = prior_result, sd = 5)
  }
}

#' Prior precision matrix P and linear term b0 (everything except the polls)
#'
#' Random walk + day-0 anchor + house-effect priors + soft poll-count-weighted
#' sum-to-zero constraint on house effects. P is positive definite (the walk
#' alone is rank T-1; the anchor pins the level, the priors pin the houses).
#'
#' @keywords internal
trend_prior_system <- function(prep, sigma_rw, sigma_house, anchor) {
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
  w_szc <- 1 / 0.3^2
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
#' @param want_var If FALSE, skip the posterior-variance solve (the expensive
#'   part) — used inside the hyperparameter optimiser.
#' @keywords internal
trend_solve <- function(prep, sigma_obs, sigma_rw, sigma_house, anchor,
                        firm_factors = NULL, want_var = TRUE) {
  prior <- trend_prior_system(prep, sigma_rw, sigma_house, anchor)
  H <- trend_obs_matrix(prep)
  y <- prep$obs$y
  n <- length(y)
  w <- 1 / (sigma_obs * obs_noise_factors(prep, firm_factors))^2

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
  list(theta = theta, sds = sds, logml = logml)
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
#' @param polls A cycle's polls from [cycle_polls()].
#' @param party Column name, e.g. "ALP".
#' @param prior_result Previous-election vote share for day-0 anchor (percent).
#'   `NA` means anchor loosely to the first poll.
#' @param sigma_obs Poll noise sd in points (sampling + design effects).
#'   Estimate it with [estimate_trend_sigmas()] rather than guessing.
#' @param sigma_rw Daily random-walk sd in points. Ditto.
#' @param sigma_house House-effect prior sd in points.
#' @param min_firm_polls Firms with fewer polls than this share one pooled
#'   "(other firms)" house effect.
#' @param firm_factors Named vector of per-firm noise sd multipliers from
#'   [estimate_firm_factors()]; unnamed firms get 1.
#' @return List: `trend` (data.table date/mean/sd/lo95/hi95), `house_effects`
#'   (firm/effect/sd/n_polls), `residuals` (per poll), `meta` (includes
#'   `logml`, the exact log marginal likelihood).
#' @export
fit_trend <- function(polls, party,
                      prior_result = NA_real_,
                      sigma_obs = 1.7,
                      sigma_rw = 0.10,
                      sigma_house = 3,
                      min_firm_polls = 3,
                      firm_factors = NULL) {
  prep <- prep_trend_obs(polls, party, min_firm_polls)
  anchor <- trend_anchor(prep, prior_result)
  sol <- trend_solve(prep, sigma_obs, sigma_rw, sigma_house, anchor,
                     firm_factors = firm_factors, want_var = TRUE)

  T_ <- prep$T_
  trend <- data.table::data.table(
    date = prep$start + prep$days,
    mean = sol$theta[seq_len(T_)],
    sd = sol$sds[seq_len(T_)]
  )
  trend[, `:=`(lo95 = mean - 1.96 * sd, hi95 = mean + 1.96 * sd)]

  hj <- T_ + seq_len(prep$J)
  house <- data.table::data.table(
    firm = prep$firms,
    effect = sol$theta[hj],
    sd = sol$sds[hj],
    n_polls = prep$obs[, .N, by = j][order(j), N]
  )

  obs <- prep$obs
  residuals <- data.table::data.table(
    date = obs$date, firm = obs$firm, y = obs$y,
    fitted = sol$theta[obs$t] + sol$theta[T_ + obs$j]
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
      sigma_obs = sigma_obs, sigma_rw = sigma_rw,
      prior_result = prior_result,
      logml = sol$logml
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

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a
