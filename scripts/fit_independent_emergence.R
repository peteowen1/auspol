# How large an independent vote should we allow for in a seat that has none?
#
# Against docs/plans/prereg-independent-emergence.md, committed before this ran.
# The four features, the structure, the decision rule and refusals E1-E5 are
# there and are NOT restated here.
#
# NOTHING NUMERIC IS BORROWED. The idea -- that an independent can appear where
# none stood, and that the vote when it happens is heavy-tailed -- is taken from
# the model this repo is anchored on. Every coefficient, scale and tail weight
# below is fitted on our own data with our own features. No threshold from
# anywhere else is used, because there is no threshold: the independent vote
# share is modelled directly as a continuous outcome.
#
# Emits IE* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()

share_of <- function(d) {
  w <- d[, .(v = sum(votes)), by = .(seat, party)]
  w[, pct := 100 * v / sum(v), by = seat]
  w[, .(seat, party, pct)]
}
f19 <- share_of(fread(file.path(P, "nswec-2019-nsw-firstprefs.csv")))
f23 <- share_of(fread(file.path(P, "nswec-2023-nsw-firstprefs.csv")))

wide <- function(x, suffix) {
  a <- dcast(x, seat ~ party, value.var = "pct", fill = 0)
  setnames(a, setdiff(names(a), "seat"), paste0(setdiff(names(a), "seat"), suffix))
  a
}
d <- merge(wide(f19, "_prev"), wide(f23, "_now"), by = "seat")
seats <- as.data.table(load_seats(2023, "nsw"))[, .(seat, margin, incumbent)]
d <- merge(d, seats, by = "seat")

# ---- the four pre-registered features --------------------------------------
d[, nonmajor_prev := IND_prev + OTH_prev + OTH_RIGHT_prev]
d[, ind_prev      := IND_prev]
d[, abs_margin    := abs(margin)]
d[, coalition_held := as.integer(incumbent %in% c("LNP", "LIB", "NAT"))]
d[, ind_now       := IND_now]

cat(sprintf("\nIE1  %d NSW seats with both elections\n", nrow(d)))
cat(sprintf("IE1  independent share now: mean %.2f, median %.2f, max %.2f; zero in %d seats\n",
            mean(d$ind_now), stats::median(d$ind_now), max(d$ind_now),
            sum(d$ind_now < 0.5)))
cat(sprintf("IE1  previous non-major vote: mean %.2f, range %.1f-%.1f\n",
            mean(d$nonmajor_prev), min(d$nonmajor_prev), max(d$nonmajor_prev)))

# ---- structure --------------------------------------------------------------
# The outcome is heavily zero-inflated and right-skewed: most seats have almost
# no independent vote and a few have a great deal. Modelled on a log1p scale so
# the fit is not dominated by the handful of very large values, with the SPREAD
# allowed to grow with the same features as the location -- that growth is what
# creates the possibility of a large independent vote in a seat that has none.
FEAT <- c("nonmajor_prev", "ind_prev", "abs_margin", "coalition_held")
FORM_MU <- stats::as.formula(paste("y ~", paste(FEAT, collapse = " + ")))
d[, y := log1p(ind_now)]

# Tail weight is ESTIMATED, not assumed: a Student-t scale model is fitted by
# maximum likelihood over (location coefficients, log-spread coefficients, df),
# and its df is what says how heavy the tail is.
fit_model <- function(train) {
  X <- stats::model.matrix(FORM_MU, data = train)
  yv <- train$y
  k <- ncol(X)
  nll <- function(par) {
    b <- par[1:k]; g <- par[(k + 1):(2 * k)]
    nu <- exp(par[2 * k + 1]) + 2.01
    mu <- as.vector(X %*% b)
    s <- exp(pmin(as.vector(X %*% g), 5))
    if (any(!is.finite(s)) || any(s <= 0)) return(1e10)
    -sum(stats::dt((yv - mu) / s, df = nu, log = TRUE) - log(s))
  }
  st <- c(stats::coef(stats::lm(FORM_MU, data = train)), rep(0, k), log(5))
  st[is.na(st)] <- 0
  o <- stats::optim(st, nll, method = "BFGS",
                    control = list(maxit = 2000, reltol = 1e-10))
  list(b = o$par[1:k], g = o$par[(k + 1):(2 * k)],
       nu = exp(o$par[2 * k + 1]) + 2.01, conv = o$convergence, X = X)
}

full <- fit_model(d)
Xf <- stats::model.matrix(FORM_MU, data = d)
nm <- colnames(Xf)
cat(sprintf("\nIE2  fitted on all %d seats (for reporting only; scoring is leave-one-out)\n", nrow(d)))
print(data.table(term = nm,
                 location = round(full$b, 4),
                 log_spread = round(full$g, 4)))
cat(sprintf("IE2  estimated degrees of freedom: %.1f  (low = heavy tail; >30 is effectively normal)\n",
            full$nu))
cat(sprintf("IE2  convergence code %d (0 = converged)\n", full$conv))

# ---- leave-one-seat-out predictive distribution ----------------------------
# Each seat's distribution comes from a model that never saw that seat.
loo <- rbindlist(lapply(seq_len(nrow(d)), function(i) {
  m <- fit_model(d[-i])
  xi <- Xf[i, , drop = FALSE]
  mu <- as.vector(xi %*% m$b); s <- exp(min(as.vector(xi %*% m$g), 5))
  data.table(seat = d$seat[i], mu = mu, s = s, nu = m$nu,
             y = d$y[i], ind_now = d$ind_now[i])
}))
loo[, z := (y - mu) / s]
cat(sprintf("\nIE3  leave-one-out: mean |z| %.2f, and %.1f%% of seats fall outside +/-2 sd\n",
            mean(abs(loo$z)), 100 * mean(abs(loo$z) > 2)))
# Calibration of the predictive distribution itself: the PIT should be uniform.
loo[, pit := stats::pt(z, df = nu)]
cat(sprintf("IE3  PIT mean %.3f (0.500 if calibrated), sd %.3f (0.289 if calibrated)\n",
            mean(loo$pit), stats::sd(loo$pit)))
cat(sprintf("IE3  Kolmogorov-Smirnov against uniform: p = %.3f (high = calibrated)\n",
            suppressWarnings(stats::ks.test(loo$pit, "punif")$p.value)))

# What the model says about a seat with NO independent history -- the case the
# published model currently assigns probability zero.
q <- c(0.5, 0.75, 0.9, 0.95, 0.99)
cat("\nIE4  implied independent vote for a seat with no independent last time\n")
for (nmv in c(3, 8, 15, 25)) {
  nd <- data.table(nonmajor_prev = nmv, ind_prev = 0, abs_margin = 10,
                   coalition_held = 1L, y = 0)
  xi <- stats::model.matrix(FORM_MU, data = nd)
  mu <- as.vector(xi %*% full$b); s <- exp(min(as.vector(xi %*% full$g), 5))
  vals <- expm1(mu + s * stats::qt(q, df = full$nu))
  cat(sprintf("     previous non-major %2d%%:  median %4.1f%%  p75 %4.1f%%  p90 %5.1f%%  p95 %5.1f%%  p99 %5.1f%%\n",
              nmv, vals[1], vals[2], vals[3], vals[4], vals[5]))
}

fwrite(loo, file.path("output", "independent-emergence-loo.csv"))
saveRDS(list(b = full$b, g = full$g, nu = full$nu, terms = nm, form = FORM_MU),
        "output/independent-emergence-fit.rds")
cat("\nIE5  wrote output/independent-emergence-loo.csv and -fit.rds\n")
