# AUSPOL_IND_MIXTURE: a non-sitting independent's vote as a two-part mixture.
#
# Pete, 2026-10-09: point-estimate fixes failed three ways (typical-vote arms,
# a dedicated 41-input model tying the current xgb stage), because a Yildiz
# (32.9) and a Helou (1.6) look alike beforehand. So model the SHAPE: most
# independents get about their typical vote for their signals, a few surge.
#   typical : log1p(share) ~ N(X b, s1)
#   surge   : share ~ N(m2, s2) with probability pi = logistic(X g)
# fitted by EM on earlier elections only. The cell's share becomes the
# typical value; the seat's existing surge mechanism (simulate_seat_contests:
# surge_h, surge_mu, surge_sd, surge_party) carries the surge with chance pi
# and gain m2 - typical, recipient IND. Offline check: P(15+) Brier 0.0975 vs
# 0.1226 for a flat rate (scripts/eval_ind_mixture.R).
# docs/plans/prereg-ind-typical-2026-10-09.md, Amendment 1.

IND_MIX_PRIOR_SD <- 1.5   # prior sd of every surge-chance log-odds coefficient (not the intercept)

#' The validated `AUSPOL_IND_MIXTURE` switch
#' @return `"0"` (off, shipped) or `"1"`.
#' @export
ind_mixture_mode <- function() {
  m <- Sys.getenv("AUSPOL_IND_MIXTURE", "0")
  if (!nzchar(m)) m <- "0"
  if (!m %in% c("0", "1")) stop("AUSPOL_IND_MIXTURE must be \"0\" or \"1\"; got \"", m, "\"", call. = FALSE)
  if (m == "1" && identical(new_ind_mode(), "1"))
    stop("AUSPOL_IND_MIXTURE=1 replaces AUSPOL_NEW_IND_SHRINK; set AUSPOL_NEW_IND_SHRINK=0 with it", call. = FALSE)
  if (m == "1" && !identical(ind_typical_mode(), "0"))
    stop("AUSPOL_IND_MIXTURE=1 and AUSPOL_IND_TYPICAL both set the independent share; use one", call. = FALSE)
  m
}

.im_design <- function(d) {
  X <- .it_design(d)
  # A returning candidate's previous vote also enters linearly, so what they
  # keep can rise with its size (Benambra 2022: Hawkins 29.2 -> 31.7).
  op <- suppressWarnings(as.numeric(d$own_prev_pcv)); op[!is.finite(op)] <- 0
  cbind(X, own_prev_lin = op / 10)
}

.im_cache <- new.env(parent = emptyenv())

#' Fit the independent mixture, time-forward
#'
#' EM on every in-scope independent cell (nominated, not a sitting independent
#' standing again; `.it_scope()`) of elections strictly before `target`. The
#' surge-chance logistic is a penalised fit (prior sd `IND_MIX_PRIOR_SD` on
#' each non-intercept coefficient), so no one signal claims certainty from a
#' handful of cases. Cached per target per process.
#' @param target Election label.
#' @param features Optional pre-read feature table.
#' @return list `b`, `s1`, `m2`, `s2`, `g`, `cols`, `n`, `iters`, or `NULL` with
#'   fewer than 150 training cells.
#' @export
ind_mixture_fit <- function(target, features = NULL) {
  if (!is.null(.im_cache[[target]])) return(.im_cache[[target]])
  FT <- .it_features(features)
  pairs <- unique(FT$pair); pairs <- pairs[elections_before(pairs, target)]
  tr <- FT[FT$pair %in% pairs & .it_scope(FT), ]
  y <- suppressWarnings(as.numeric(tr$actual_share)); ok <- is.finite(y)
  tr <- tr[ok, ]; y <- y[ok]
  if (length(y) < 150L) return(NULL)
  X <- .im_design(tr); keep <- colSums(abs(X)) > 0; X <- X[, keep, drop = FALSE]
  ly <- log1p(pmax(y, 0))
  r <- as.numeric(y > stats::quantile(y, 0.85))
  g <- rep(0, ncol(X)); pen <- c(0, rep(1 / IND_MIX_PRIOR_SD^2, ncol(X) - 1))
  for (it in seq_len(300)) {
    w1 <- 1 - r
    b <- stats::lm.wfit(X, ly, w1 + 1e-6)$coefficients; b[is.na(b)] <- 0
    s1 <- sqrt(sum(w1 * (ly - X %*% b)^2) / sum(w1))
    m2 <- sum(r * y) / sum(r); s2 <- sqrt(sum(r * (y - m2)^2) / sum(r))
    for (k in 1:25) {
      mu <- 1 / (1 + exp(-as.numeric(X %*% g))); W <- pmax(mu * (1 - mu), 1e-6)
      step <- as.numeric(solve(crossprod(X, W * X) + diag(pen, ncol(X)), crossprod(X, r - mu) - pen * g))
      g <- g + step; if (max(abs(step)) < 1e-8) break
    }
    p <- 1 / (1 + exp(-as.numeric(X %*% g)))
    f1 <- stats::dnorm(ly, as.numeric(X %*% b), s1) / (1 + y)
    f2 <- stats::dnorm(y, m2, s2)
    r_new <- p * f2 / (p * f2 + (1 - p) * f1)
    r_new[!is.finite(r_new)] <- 0
    if (max(abs(r_new - r)) < 1e-6) { r <- r_new; break }
    r <- r_new
  }
  out <- list(b = b, s1 = s1, m2 = m2, s2 = s2, g = g, cols = colnames(X), n = length(y), iters = it)
  .im_cache[[target]] <- out
  out
}

#' The target's in-scope independent cells, with typical value and surge terms
#' @param target Election label.
#' @param features Optional pre-read feature table.
#' @return data.table `skey`, `typical`, `pi`, `gain`, `surge_sd`, or `NULL`.
#' @export
ind_mixture_cells <- function(target, features = NULL) {
  fit <- ind_mixture_fit(target, features)
  if (is.null(fit)) return(NULL)
  FT <- .it_features(features)
  d <- FT[FT$pair == target & .it_scope(FT), ]
  if (!nrow(d)) return(NULL)
  X <- .im_design(d)[, fit$cols, drop = FALSE]
  typ <- pmax(exp(as.numeric(X %*% fit$b)) - 1, 0)
  pi_ <- 1 / (1 + exp(-as.numeric(X %*% fit$g)))
  data.table::data.table(skey = normalise_seat(d$seat), typical = typ, pi = pi_,
                         gain = pmax(fit$m2 - typ, 0), surge_sd = fit$s2)
}

#' Set in-scope independent shares to their typical value
#'
#' No-op unless `AUSPOL_IND_MIXTURE=1`. Called right after the xgb override in
#' every harness (the seat-poll blend still pulls on the result). The
#' difference is shared among the seat's other classes in proportion.
#' @param shares Seats x classes matrix.
#' @param target Election label.
#' @param code Log prefix.
#' @param features Optional pre-read feature table.
#' @return `shares`.
#' @export
ind_mixture_apply <- function(shares, target, code = "IM1", features = NULL) {
  if (!identical(ind_mixture_mode(), "1") || !"IND" %in% colnames(shares)) return(shares)
  cl <- ind_mixture_cells(target, features)
  if (is.null(cl)) { cat(sprintf("%s! %s: fewer than 150 earlier independent cells; shares unchanged\n", code, target)); return(shares) }
  ci <- match("IND", colnames(shares)); ri <- match(cl$skey, normalise_seat(rownames(shares)))
  out <- shares; n <- 0L; moved <- 0
  for (k in which(!is.na(ri))) {
    i <- ri[k]; old <- shares[i, ci]; tot <- sum(shares[i, ])
    if (old <= 0 || tot - old <= 0) next
    new <- min(cl$typical[k], tot)
    out[i, ] <- shares[i, ] * (tot - new) / (tot - old); out[i, ci] <- new
    n <- n + 1L; moved <- moved + new - old
  }
  f <- ind_mixture_fit(target, features)
  cat(sprintf("%s  independent mixture for %s: %d cell(s) set to typical, mean change %+.2f; fit %d cells, surge %.1f +/- %.1f, surge chance median %.2f (range %.2f-%.2f)\n",
              code, target, n, if (n) moved / n else 0, f$n, f$m2, f$s2,
              stats::median(cl$pi), min(cl$pi), max(cl$pi)))
  out
}

#' The seat surge settings with the independent mixture's surge in it
#'
#' No-op (inputs returned unchanged) unless `AUSPOL_IND_MIXTURE=1`. For each
#' in-scope independent seat: `surge_h` = the mixture's surge chance, recipient
#' `IND`, gain `m2 - typical`, sd `s2`. Other seats keep what they had.
#' @param target Election label.
#' @param seats Seat names, in the simulation's seat order.
#' @param surge_h,surge_mu,surge_sd Current values (length 1 or one per seat).
#' @param surge_party Current recipient vector or `NULL`.
#' @param code Log prefix.
#' @param features Optional pre-read feature table.
#' @return list `surge_h`, `surge_mu`, `surge_sd`, `surge_party`.
#' @export
ind_mixture_surge <- function(target, seats, surge_h, surge_mu, surge_sd, surge_party, code = "IM2", features = NULL) {
  same <- list(surge_h = surge_h, surge_mu = surge_mu, surge_sd = surge_sd, surge_party = surge_party)
  if (!identical(ind_mixture_mode(), "1")) return(same)
  cl <- ind_mixture_cells(target, features)
  if (is.null(cl)) return(same)
  n <- length(seats); ext <- function(v) if (length(v) == 1L) rep(v, n) else v
  sh <- ext(as.numeric(surge_h)); mu <- ext(as.numeric(surge_mu)); sd <- ext(as.numeric(surge_sd))
  sp <- if (is.null(surge_party)) rep(NA_character_, n) else ext(as.character(surge_party))
  if (!is.null(names(surge_h)) && length(surge_h) == n) names(sh) <- names(surge_h)
  ri <- match(cl$skey, normalise_seat(seats)); k <- which(!is.na(ri))
  sh[ri[k]] <- cl$pi[k]; mu[ri[k]] <- cl$gain[k]; sd[ri[k]] <- cl$surge_sd[k]; sp[ri[k]] <- "IND"
  cat(sprintf("%s  independent mixture surge for %s: %d seat(s) take the mixture's surge (chance mean %.3f)\n",
              code, target, length(k), if (length(k)) mean(cl$pi[k]) else NA_real_))
  list(surge_h = sh, surge_mu = mu, surge_sd = sd, surge_party = sp)
}
