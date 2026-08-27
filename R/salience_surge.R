#' Ridge-penalised logistic regression, base R only
#'
#' Mirrors [ridge_loo()]'s existing pattern in `R/fundamentals.R` -- fold-local
#' standardisation, an explicit lambda grid, unpenalised intercept -- extended
#' from linear to logistic via IRLS since the outcome here is binary
#' (a candidate winning). Built for [surge_hazard_for()], where a plain
#' `glm()` quasi-separated on only 8-10 positive cases across ~1000 governed
#' candidates.
#'
#' @param X Numeric matrix of predictors, no intercept column.
#' @param y Numeric 0/1 outcome vector.
#' @param lambda L2 penalty strength.
#' @param max_iter,tol IRLS iteration controls.
#' @return Numeric coefficient vector, intercept first.
#' @keywords internal
ridge_logistic <- function(X, y, lambda, max_iter = 100, tol = 1e-8) {
  n <- nrow(X); p <- ncol(X)
  Xd <- cbind(1, X)
  beta <- c(stats::qlogis(pmin(pmax(mean(y), 0.01), 0.99)), rep(0, p))
  pen <- diag(c(0, rep(lambda, p)))
  for (i in seq_len(max_iter)) {
    eta <- as.vector(Xd %*% beta)
    mu <- stats::plogis(eta)
    w <- pmax(mu * (1 - mu), 1e-6)
    z <- eta + (y - mu) / w
    WX <- Xd * w
    H <- crossprod(WX, Xd) + pen
    b_new <- tryCatch(solve(H, crossprod(WX, z)), error = function(e) NULL)
    if (is.null(b_new)) return(beta)
    if (max(abs(b_new - beta)) < tol) return(as.vector(b_new))
    beta <- as.vector(b_new)
  }
  beta
}

#' @keywords internal
predict_ridge <- function(beta, X, center, scale) {
  Xs <- sweep(sweep(X, 2, center, "-"), 2, scale, "/")
  stats::plogis(as.vector(cbind(1, Xs) %*% beta))
}

#' @keywords internal
.surge_build_X <- function(d, party_levels) {
  pm <- stats::model.matrix(~ party - 1,
                            data = data.frame(party = factor(d$party, levels = party_levels)))
  colnames(pm) <- paste0("party_", party_levels)
  cbind(jump_pctile = d$jump_pctile, prev_party = d$prev_party, prev_ind = d$prev_ind, pm)
}

#' The governed-population training set for the surge hazard, across elections
#'
#' One row per governed candidate (see [governed_population()]) across the
#' supplied election pairs, with the two extra features the surge hazard
#' regresses on: `jump_pctile` (jump, percentile-ranked WITHIN each election --
#' raw jump is not comparable across elections, since each Trends batch chain
#' anchors on a different first query) and `prev_ind` (the seat's total prior
#' IND vote, separate from `prev_party`).
#'
#' @param pairs A list of `list(election=, prev=, region=)`.
#' @return A `data.table`, one row per governed candidate.
#' @export
surge_training_population <- function(pairs) {
  cand_path <- file.path("output", "candidacies.csv")
  if (!file.exists(cand_path)) stop("needs output/candidacies.csv", call. = FALSE)
  C <- data.table::fread(cand_path, showProgress = FALSE)
  prev_ind_for <- function(prev_election) {
    C[C$election == prev_election & C$party == "IND",
      .(prev_ind = sum(pcv, na.rm = TRUE)), by = seat]
  }
  build_one <- function(p) {
    G <- governed_population(p$election, p$prev, p$region)
    if (is.null(G)) return(NULL)
    G <- G[G$governed == TRUE]
    if (!nrow(G)) return(NULL)
    pi <- prev_ind_for(p$prev)
    G <- merge(G, pi, by = "seat", all.x = TRUE)
    G[is.na(G$prev_ind), prev_ind := 0]
    G[, jump_pctile := rank(jump, ties.method = "average") / .N]
    G[, pair := p$election]
    G[, .(pair, seat, party, keyword, elected, pcv, jump, jump_pctile, prev_party, prev_ind)]
  }
  data.table::rbindlist(lapply(pairs, build_one), fill = TRUE)
}

#' Per-seat surge hazard for one target election, fit on every OTHER election
#'
#' Extends the existing `surge_h` mechanism in [simulate_seat_contests()] --
#' already fat-tail, not a point-estimate shift -- with a properly featured,
#' governed-population-gated model instead of the single-feature, ungated,
#' stale-instrument fit in `scripts/fit_salience_hazard.R`. See
#' `docs/plans/prereg-salience-surge-v2.md` for why this form and not a direct
#' vote-share regression (REFUSED 2026-08-26,
#' `docs/reviews/salience-regression-refused-2026-08-26.md` -- a linear jump
#' term applied to every non-major candidate cannot tell "loud because
#' emerging" from "loud because famous incumbent", and gating to the governed
#' population excludes that failure mode by construction).
#'
#' The lambda (L2 penalty) is picked by nested leave-one-election-out **within
#' the training pairs only** -- the target election never informs its own
#' penalty, let alone its own fit.
#'
#' @param target_election,target_prev,target_region The election to score.
#' @param train_pairs Other elections to fit on -- must NOT include the
#'   target, or the target leaks into its own training data.
#' @param lambda_grid Candidate L2 penalties.
#' @return A list: `seat_hazard` (`data.table` of `seat`, `surge_h`, party
#'   collapsed -- for the stochastic hazard in [simulate_seat_contests()]),
#'   `seat_party_hazard` (`data.table` of `seat`, `party`, `p_hat` -- for
#'   [surge_blend_estimate()]'s point-estimate shift, which needs to land on
#'   the right column), `surge_mu`, `surge_sd` (pooled from training-pair
#'   governed winners' actual `pcv`), `lambda`, `n_train_winners`. `NULL` if
#'   there is no training population to fit on.
#' @export
surge_hazard_for <- function(target_election, target_prev, target_region,
                             train_pairs, lambda_grid = c(0.5, 1, 2, 5, 10, 20, 50)) {
  is_target <- vapply(train_pairs, function(p) identical(p$election, target_election), TRUE)
  if (any(is_target)) {
    stop("train_pairs includes the target election (", target_election,
         ") -- this would leak the target into its own fit", call. = FALSE)
  }
  TRAIN <- surge_training_population(train_pairs)
  if (is.null(TRAIN) || !nrow(TRAIN)) return(NULL)
  target <- surge_training_population(list(list(
    election = target_election, prev = target_prev, region = target_region)))
  if (is.null(target) || !nrow(target)) return(NULL)

  party_levels <- sort(unique(c(TRAIN$party, target$party)))
  fit_one <- function(d, lambda) {
    X <- .surge_build_X(d, party_levels)
    center <- colMeans(X); scale <- apply(X, 2, stats::sd); scale[scale == 0] <- 1
    Xs <- sweep(sweep(X, 2, center, "-"), 2, scale, "/")
    list(beta = ridge_logistic(Xs, d$elected, lambda), center = center, scale = scale)
  }
  train_election_ids <- unique(TRAIN$pair)
  pick_lambda <- function() {
    if (length(train_election_ids) < 2L) return(lambda_grid[1])
    scores <- sapply(lambda_grid, function(lam) {
      inner <- sapply(train_election_ids, function(held) {
        tr <- TRAIN[TRAIN$pair != held]
        te <- TRAIN[TRAIN$pair == held]
        if (!nrow(tr) || !nrow(te)) return(NA_real_)
        f <- fit_one(tr, lam)
        p_hat <- predict_ridge(f$beta, .surge_build_X(te, party_levels), f$center, f$scale)
        eps <- 1e-6
        -mean(te$elected * log(pmax(p_hat, eps)) + (1 - te$elected) * log(pmax(1 - p_hat, eps)))
      })
      mean(inner, na.rm = TRUE)
    })
    lambda_grid[which.min(scores)]
  }
  lambda <- pick_lambda()
  fit <- fit_one(TRAIN, lambda)
  target$p_hat <- predict_ridge(fit$beta, .surge_build_X(target, party_levels), fit$center, fit$scale)

  # SEAT-LEVEL (party collapsed) for the stochastic surge_h hazard in
  # simulate_seat_contests() -- when that hazard fires, the mechanism itself
  # picks the strongest eligible candidate in the draw, so collapsing party
  # here is fine.
  seat_hazard <- target[, .(surge_h = max(p_hat)), by = seat]
  # SEAT x PARTY, kept separate for the POINT-ESTIMATE blend below: a
  # deterministic shift has to land on the right party's column, and a seat
  # can have governed candidates in more than one class (e.g. IND and GRN).
  seat_party_hazard <- target[, .(p_hat = max(p_hat)), by = .(seat, party)]
  winners <- TRAIN[TRAIN$elected == TRUE]
  list(seat_hazard = seat_hazard,
      seat_party_hazard = seat_party_hazard,
      surge_mu = if (nrow(winners) >= 3) mean(winners$pcv) else 15.6,
      surge_sd = if (nrow(winners) >= 3) stats::sd(winners$pcv) else 6.1,
      lambda = lambda, n_train_winners = nrow(winners))
}

#' Blend a uniform-swing point estimate toward the surge magnitude
#'
#' `surge_hazard_for()` widens the SIMULATED tail via `surge_h`, but the
#' deterministic point estimate that feeds it (`dev_slope()`'s output) is
#' otherwise blind to salience entirely -- correlation(jump, projected share)
#' measured at 0.050 on fed2022, essentially zero. Governed winners with real
#' salience were projected at 7-37% of their actual result (Zoe Daniel: 3.2%
#' projected vs 34.5% actual). This closes that gap directly: a probability-
#' weighted blend between the uniform-swing estimate and the fitted surge
#' size, using the SAME `p_hat` already fitted for the hazard -- no second
#' model, no new failure surface. At `p_hat` near 0 (the overwhelming
#' majority of governed candidates -- no-hopers), the estimate is
#' unchanged. At `p_hat` near 1, it moves toward `surge_mu`.
#'
#' @param uniform_share Numeric vector: the pre-blend point estimate.
#' @param p_hat Numeric vector, same length: this seat/party's fitted hazard.
#' @param surge_mu Target magnitude to blend toward.
#' @return Numeric vector, same length as `uniform_share`.
#' @export
surge_blend_estimate <- function(uniform_share, p_hat, surge_mu) {
  if (length(uniform_share) != length(p_hat)) {
    stop("uniform_share and p_hat must be the same length: ",
         length(uniform_share), " vs ", length(p_hat), call. = FALSE)
  }
  p_hat[!is.finite(p_hat)] <- 0
  (1 - p_hat) * uniform_share + p_hat * surge_mu
}
