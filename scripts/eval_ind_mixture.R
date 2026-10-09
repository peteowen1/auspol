# Two-part mixture for a non-sitting independent's vote, fitted by EM, time-forward.
#   typical: log1p(share) ~ N(X b, s1)          (most candidates)
#   surge  : share ~ N(m2, s2), with prob pi(X) = logistic(X g)
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
FT <- .it_features()
D <- FT[.it_scope(FT)]; D[, actual := as.numeric(actual_share)]; D <- D[is.finite(actual)]
X_all <- .it_design(D)
X_all <- cbind(X_all, own_prev_lin = suppressWarnings(as.numeric(D$own_prev_pcv)) / 10)
X_all[!is.finite(X_all)] <- 0

fit_mix <- function(X, y, iters = 200) {
  ly <- log1p(pmax(y, 0)); n <- length(y)
  r <- as.numeric(y > stats::quantile(y, 0.85))           # start: top 15% are "surge"
  for (it in seq_len(iters)) {
    w1 <- 1 - r
    b <- stats::lm.wfit(X, ly, w1 + 1e-6)$coefficients; b[is.na(b)] <- 0
    s1 <- sqrt(sum(w1 * (ly - X %*% b)^2) / sum(w1))
    m2 <- sum(r * y) / sum(r); s2 <- sqrt(sum(r * (y - m2)^2) / sum(r))
    g <- if (exists("g_prev")) g_prev else rep(0, ncol(X))
    pen <- c(0, rep(1 / 1.5^2, ncol(X) - 1))
    for (k in 1:25) { eta <- as.numeric(X %*% g); mu <- 1 / (1 + exp(-eta)); W <- pmax(mu * (1 - mu), 1e-6)
      H <- crossprod(X, W * X) + diag(pen, ncol(X)); gr <- crossprod(X, r - mu) - pen * g
      step <- as.numeric(solve(H, gr)); g <- g + step; if (max(abs(step)) < 1e-8) break }
    g_prev <- g
    p <- 1 / (1 + exp(-as.numeric(X %*% g)))
    # densities on the share scale (typical: lognormal-on-(1+y) Jacobian 1/(1+y))
    f1 <- stats::dnorm(ly, as.numeric(X %*% b), s1) / (1 + y)
    f2 <- stats::dnorm(y, m2, s2)
    r_new <- p * f2 / (p * f2 + (1 - p) * f1)
    if (max(abs(r_new - r)) < 1e-6) { r <- r_new; break }
    r <- r_new
  }
  rm(g_prev); list(b = b, s1 = s1, m2 = m2, s2 = s2, g = g, iters = it)
}

targets <- sort(unique(D$pair)); out <- list()
for (tg in targets) {
  tr <- D$pair %in% targets[elections_before(targets, tg)]; te <- D$pair == tg
  if (sum(tr) < 150 || !any(te)) next
  Xt <- X_all[tr, , drop = FALSE]; keep <- colSums(abs(Xt)) > 0
  f <- fit_mix(Xt[, keep, drop = FALSE], D$actual[tr])
  Xe <- X_all[te, keep, drop = FALSE]
  typ <- exp(as.numeric(Xe %*% f$b)) - 1
  pi_ <- 1 / (1 + exp(-as.numeric(Xe %*% f$g)))
  out[[tg]] <- data.table(pair = tg, seat = D$seat[te], actual = D$actual[te], typical = pmax(typ, 0), pi = pi_,
                          surge_mean = f$m2, surge_sd = f$s2, mean_pred = (1 - pi_) * pmax(typ, 0) + pi_ * f$m2,
                          p15 = (1 - pi_) * stats::pnorm(log1p(15), as.numeric(Xe %*% f$b), f$s1, lower.tail = FALSE) +
                                pi_ * stats::pnorm(15, f$m2, f$s2, lower.tail = FALSE))
  if (tg %in% c("vic2018", "vic2022")) {
    cat(sprintf("%s fit: %d cells, %d iterations | typical sd (log) %.2f | surge %.1f +/- %.1f\n", tg, sum(tr), f$iters, f$s1, f$m2, f$s2))
    cat("  surge-probability coefs:", paste(sprintf("%s %.2f", names(f$g), f$g), collapse = ", "), "\n")
  }
}
O <- rbindlist(out)
fwrite(O, "output/ind-mixture-eval.csv")
cat("\nCalibration of the surge probability (all targets): predicted vs share of candidates who actually got 15+\n")
O[, band := cut(p15, c(0, .02, .05, .1, .2, .4, .7, 1), include.lowest = TRUE)]
print(O[, .(cells = .N, predicted = round(mean(p15), 3), actual_15plus = round(mean(actual >= 15), 3)), by = band][order(band)])
cat(sprintf("Brier score for 15+: model %.4f vs base rate %.4f (lower is better)
", mean((O$p15 - (O$actual >= 15))^2), mean((mean(O$actual >= 15) - (O$actual >= 15))^2)))
cat("\nExamples:\n")
print(O[seat %in% c("Bass", "Hawthorn", "Brunswick", "Benambra", "Pascoe Vale", "Werribee", "Goldstein", "Warringah", "Kooyong", "Melton", "Sandringham")
        & pair %in% c("vic2018", "vic2022", "fed2019", "fed2022")][
  , .(pair, seat, actual = round(actual, 1), typical = round(typical, 1), surge_chance = round(pi, 2),
      surge_size = round(surge_mean, 1), mean = round(mean_pred, 1))][order(pair, seat)])
