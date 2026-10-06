# Per-(jurisdiction, party class) correction of the xgb layer's primary shares
#
# `AUSPOL_XGB_CLASS_JUR_CAL` ("0" = off, the default; PREREG PENDING). The xgb
# seat layer over-calls Independents in Victoria (published error -1.56 points a
# seat, SE 0.31, n = 264) and about nothing elsewhere, taking the share from
# Labor (docs/reviews/vic-majors-shortfall-2026-10-06.md). A blunt "rake back to
# base_pred" helps vic2022 and hurts on average, so this learns each
# jurisdiction's own lean per class, time-forward, and shrinks it.
#
# For a target election T in jurisdiction J and class k:
#
# 1. History: every earlier election's AS-AT xgb predictions (the same file
#    `xgb_primary_override()` reads; each is itself time-forward), seat-normalised
#    to 100, with the election's mean signed residual per class
#    (`actual - predicted`, points). Only elections dated STRICTLY before T,
#    in every jurisdiction.
# 2. For jurisdiction j with `k_j` earlier elections: `mu_j` = mean of its election
#    means; the election-to-election variance `sigma2` is pooled over the
#    jurisdictions with two or more elections, so one election gives an SE
#    too: `se_j^2 = sigma2 / k_j` (clustered on the election, not the seat).
# 3. `tau2` = variance of the TRUE jurisdiction means about 0, by method of
#    moments, `max(0, mean(mu_j^2 - sigma2 / k_j))` over jurisdictions with at
#    least one earlier election; floored at 0, so no signal means no correction.
# 4. `w = tau2 / (tau2 + se_J^2)`, `shift = w * mu_J` (shrunk toward 0).
# 5. The shift is added to the class's share in every seat (never below 0), and
#    each seat is rescaled back to its pre-shift total.
#
# A jurisdiction with no earlier election gets no shift. No hard `min_n`.
#
xcj_history <- function(P) {
  P <- data.table::as.data.table(P)[, list(pair, seat, party, xgb_pred, actual_share)]
  P <- P[is.finite(xgb_pred) & is.finite(actual_share)]
  P[, xs := {tot <- sum(xgb_pred); if (tot > 0) 100 * xgb_pred / tot else xgb_pred}, by = list(pair, seat)]
  H <- P[, list(mean_res = mean(actual_share - xs), n_seats = .N), by = list(pair, party)]
  H[, region := sub("[0-9]+$", "", pair)]
  H[, date := as.numeric(election_dates(unique(pair))[pair])]
  H[]
}

xcj_fit <- function(H, target) {
  tdate <- as.numeric(election_dates(target)[[target]])
  treg  <- sub("[0-9]+$", "", target)
  Hf <- H[H$date < tdate]
  out <- lapply(sort(unique(H$party)), function(p) {
    h <- Hf[Hf$party == p]
    z <- list(party = p, k = 0L, mu = NA_real_, se = NA_real_, sigma2 = NA_real_,
              tau2 = NA_real_, w = 0, shift = 0)
    if (!nrow(h)) return(z)
    J <- h[, list(k = .N, mu = mean(mean_res), ss = sum((mean_res - mean(mean_res))^2)), by = region]
    df <- sum(J$k[J$k >= 2] - 1)
    if (df < 1) { z$k <- as.integer(J$k[J$region == treg]); if (!length(z$k)) z$k <- 0L; return(z) }
    sigma2 <- sum(J$ss[J$k >= 2]) / df
    tau2 <- max(0, mean(J$mu^2 - sigma2 / J$k))
    j <- J[J$region == treg]
    if (!nrow(j)) { z$sigma2 <- sigma2; z$tau2 <- tau2; return(z) }
    se2 <- sigma2 / j$k
    w <- if (tau2 + se2 > 0) tau2 / (tau2 + se2) else 0
    list(party = p, k = as.integer(j$k), mu = j$mu, se = sqrt(se2), sigma2 = sigma2,
         tau2 = tau2, w = w, shift = w * j$mu)
  })
  data.table::rbindlist(lapply(out, data.table::as.data.table))
}

xcj_log <- function(fit, label) {
  for (i in seq_len(nrow(fit))) {
    f <- fit[i]
    cat(sprintf("XCJ1  %s %-9s shift %+6.3f  (k=%d elections, mu %s, se %s, tau2 %s, w %.3f)\n",
                label, f$party, f$shift, f$k,
                if (is.finite(f$mu)) sprintf("%+.3f", f$mu) else "NA",
                if (is.finite(f$se)) sprintf("%.3f", f$se) else "NA",
                if (is.finite(f$tau2)) sprintf("%.3f", f$tau2) else "NA", f$w))
  }
  invisible(fit)
}

# Apply fitted shifts to a seats x classes matrix
#
# Adds each class's shift to its column (floored at 0) and rescales every row
# back to its pre-shift total. Classes without a shift are unchanged before
# the rescale.
xcj_shift_matrix <- function(shares, fit) {
  d <- stats::setNames(fit$shift, fit$party)[colnames(shares)]
  d[is.na(d)] <- 0
  if (all(d == 0)) return(shares)
  tot <- rowSums(shares)
  out <- sweep(shares, 2, d, "+"); out[out < 0] <- 0
  s <- rowSums(out)
  ok <- s > 0
  out[ok, ] <- out[ok, , drop = FALSE] * (tot[ok] / s[ok])
  out
}

# Apply fitted shifts to long (seat, party) predictions
#
# Seat-normalises to 100, shifts, floors at 0, rescales to 100, then scales
# back to the seat's raw total, so a raw `xgb_pred` keeps its own row sum.
xcj_shift_long <- function(x, seat, party, fit, hold = NULL) {
  if (is.null(hold)) hold <- rep(FALSE, length(x))
  d <- stats::setNames(fit$shift, fit$party)[party]
  d[is.na(d)] <- 0
  if (all(d == 0)) return(x)
  D <- data.table::data.table(x = x, seat = seat, d = unname(d), hold = hold)
  D[, i := .I]
  D[, y := {
    tot <- sum(x); fr <- sum(x[hold])
    live <- !hold
    if (tot <= 0 || !any(live)) x else {
      xn <- 100 * x / tot
      room <- 100 * (tot - fr) / tot            # share the live cells carry
      ys <- ifelse(live, pmax(0, xn + d), 0)
      s <- sum(ys)
      ys <- if (s > 0) ys * room / s else ys
      ys[!live] <- xn[!live]
      ys * tot / 100
    }
  }, by = seat]
  D[order(i)]$y
}

xcj_enabled <- function() identical(Sys.getenv("AUSPOL_XGB_CLASS_JUR_CAL", "0"), "1")

# Apply the correction to a whole as-at predictions table (all targets)
#
# Used by `scripts/build_forecasts_table.R`. Each target is corrected with a
# fit made only from elections dated before it; history is taken from the
# UNCORRECTED input, so the corrections never feed each other.
xcj_apply_asat <- function(P, log = TRUE) {
  if (!xcj_enabled()) return(P)
  H <- xcj_history(P)
  P <- data.table::copy(data.table::as.data.table(P))
  P[, xgb_pred_precal := xgb_pred]
  for (tg in unique(P$pair)) {
    fit <- xcj_fit(H, tg)
    if (log) xcj_log(fit, tg)
    r <- which(P$pair == tg)
    P$xgb_pred[r] <- xcj_shift_long(P$xgb_pred[r], P$seat[r], P$party[r], fit)
  }
  P
}
