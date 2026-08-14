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
#' @param sigma_rw Daily random-walk sd in points.
#' @param sigma_house House-effect prior sd in points.
#' @param min_firm_polls Firms with fewer polls than this share one pooled
#'   "(other firms)" house effect.
#' @return List: `trend` (data.table date/mean/sd/lo95/hi95), `house_effects`
#'   (firm/effect/sd/n_polls), `meta`.
#' @export
fit_trend <- function(polls, party,
                      prior_result = NA_real_,
                      sigma_obs = 1.7,
                      sigma_rw = 0.10,
                      sigma_house = 3,
                      min_firm_polls = 3) {
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
  J <- length(firms)
  obs[, j := match(firm_eff, firms)]

  n_par <- T_ + J
  # Precision-matrix (information filter) formulation:
  #   A theta = b with A = sum of quadratic-form contributions.
  ijx <- list()
  add <- function(i, j, x) ijx[[length(ijx) + 1L]] <<- data.frame(i = i, j = j, x = x)
  b <- numeric(n_par)

  # Observations: y ~ N(x_t + h_j, sigma_obs^2)
  w_obs <- 1 / sigma_obs^2
  add(obs$t, obs$t, rep(w_obs, nrow(obs)))
  add(T_ + obs$j, T_ + obs$j, rep(w_obs, nrow(obs)))
  add(obs$t, T_ + obs$j, rep(w_obs, nrow(obs)))
  add(T_ + obs$j, obs$t, rep(w_obs, nrow(obs)))
  inc <- w_obs * obs$y
  for (k in seq_len(nrow(obs))) {
    b[obs$t[k]] <- b[obs$t[k]] + inc[k]
    b[T_ + obs$j[k]] <- b[T_ + obs$j[k]] + inc[k]
  }

  # Random walk: (x_{t+1} - x_t) ~ N(0, sigma_rw^2)
  w_rw <- 1 / sigma_rw^2
  tt <- seq_len(T_ - 1L)
  add(tt, tt, rep(w_rw, T_ - 1L))
  add(tt + 1L, tt + 1L, rep(w_rw, T_ - 1L))
  add(tt, tt + 1L, rep(-w_rw, T_ - 1L))
  add(tt + 1L, tt, rep(-w_rw, T_ - 1L))

  # Day-0 anchor
  if (is.na(prior_result)) {
    anchor_val <- obs$y[which.min(obs$t)]
    anchor_sd <- 10
  } else {
    anchor_val <- prior_result
    anchor_sd <- 5
  }
  add(1L, 1L, 1 / anchor_sd^2)
  b[1L] <- b[1L] + anchor_val / anchor_sd^2

  # House effect priors + soft weighted sum-to-zero
  hj <- T_ + seq_len(J)
  add(hj, hj, rep(1 / sigma_house^2, J))
  wj <- obs[, .N, by = j][order(j), N] / nrow(obs)
  w_szc <- 1 / 0.3^2
  add(rep(hj, each = J), rep(hj, times = J), as.vector(outer(wj, wj)) * w_szc)

  ijx <- do.call(rbind, ijx)
  A <- Matrix::sparseMatrix(i = ijx$i, j = ijx$j, x = ijx$x, dims = c(n_par, n_par))
  ch <- Matrix::Cholesky(Matrix::forceSymmetric(A), LDL = FALSE)
  theta <- as.numeric(Matrix::solve(ch, b))
  # Posterior sd: diagonal of A^-1 (n_par ~ 1200, full solve is fine)
  Sigma_diag <- Matrix::diag(Matrix::solve(ch, Matrix::Diagonal(n_par)))
  sds <- sqrt(pmax(Sigma_diag, 0))

  trend <- data.table::data.table(
    date = start + days,
    mean = theta[seq_len(T_)],
    sd = sds[seq_len(T_)]
  )
  trend[, `:=`(lo95 = mean - 1.96 * sd, hi95 = mean + 1.96 * sd)]

  house <- data.table::data.table(
    firm = firms,
    effect = theta[hj],
    sd = sds[hj],
    n_polls = obs[, .N, by = j][order(j), N]
  )

  list(
    trend = trend,
    house_effects = house,
    meta = list(
      party = party, n_polls = nrow(obs),
      cycle_year = attr(polls, "cycle_year"),
      cycle_start = start, cycle_end = end,
      sigma_obs = sigma_obs, sigma_rw = sigma_rw,
      prior_result = prior_result
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
