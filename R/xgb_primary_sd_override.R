#' Per-cell primary-vote SD from the XGBoost spread model
#'
#' Builds the `sd_override` matrix `simulate_seat_contests()` takes, from
#' `scripts/fit_xgb_primary_sd.R`. Same shape and convention as
#' [salience_sd_matrix()]: seats x classes, `NA` where the model makes no claim,
#' and combined with any other override by [combine_sd_override()], which takes
#' the elementwise maximum.
#'
#' WHY. The surge mechanism was binned on 2026-09-12 because it could rank WHO
#' emerges but not WHETHER an election produces a wave, so it fired into quiet
#' seats and cost pooled federal seat log loss 0.3010 -> 0.3440. The replacement
#' is honest width: if the model cannot say which year has a teal, it should be
#' WIDE on candidates who could plausibly emerge rather than fire a coin-flip
#' jump. A seat where an independent might poll 8 or might poll 35 gets a large
#' SD, the simulator draws the whole range, and the tail carries the emergence
#' on its own -- no hazard, no recipient, and no double-count with the point
#' estimate.
#'
#' WHAT IT PREDICTS. The absolute error of the shipped primary prediction,
#' converted to an SD: for a normal, E|e| = sd * sqrt(2/pi), so a predicted
#' mean-absolute-error divided by that constant is the SD the simulator wants.
#' Leave-one-pair-out, so a pair is always scored by a model that never saw it.
#'
#' MEASURED. Gaussian log score over 13,352 held-out cells improved 1.8661 to
#' 1.2863 against one flat SD for the whole corpus, and the gain is concentrated
#' exactly where it is needed: IND 1.50, OTH 0.95, ONP 0.91, against ALP 0.03
#' and LNP 0.09. Allegra Spender's actual result sits 1.31 SDs from the
#' prediction under this model against 5.5 under the flat value.
#'
#' First-time independents are wide because the DATA says they are, not because
#' anything here encodes it: the model has `cand_all_new`, `own_prev_pcv` and
#' the salience block, and learns the spread from them.
#'
#' BACKTEST ONLY. A backtest must predict a pair with a model that never saw it,
#' so this reads the leave-one-pair-out file. There is no live path yet, for the
#' same reason `xgb_surge_params_for()` has none: a live forecast has no
#' out-of-fold row for an election that has not happened.
#'
#' @param shares Seats x classes matrix, as passed to `simulate_seat_contests()`.
#' @param target_election Pair label, e.g. `"fed2022"`.
#' @param floor_sd Optional lower bound applied to every value set.
#' @return A seats x classes matrix with `NA` where no prediction exists, and an
#'   `n_set` attribute counting the cells filled; or `NULL` if unavailable.
#' @export
xgb_primary_sd_matrix <- function(shares, target_election, floor_sd = NA_real_) {
  seats <- rownames(shares)
  if (is.null(seats)) {
    cat("XD9! shares has no rownames -- cannot build a per-cell sd override\n")
    return(NULL)
  }
  f <- Sys.getenv("AUSPOL_XGB_PRIMARY_SD_SRC", "output/xgb-primary-sd-oof.csv")
  if (!file.exists(f)) {
    cat(sprintf("XD9! %s missing -- run scripts/fit_xgb_primary_sd.R; AUSPOL_XGB_PRIMARY_SD ignored\n", f))
    return(NULL)
  }
  P <- data.table::fread(f, showProgress = FALSE)
  need <- c("pair", "seat", "party", "sd_hat")
  if (!all(need %in% names(P))) {
    cat(sprintf("XD9! %s lacks %s -- ignored\n", f,
                paste(setdiff(need, names(P)), collapse = ", ")))
    return(NULL)
  }
  # NSE guard: `pair` is a column of P, so the argument is copied to a
  # differently-named local before being used inside the filter. See CLAUDE.md
  # -- this has bitten nine times.
  want <- target_election
  P <- P[P$pair == want]
  if (!nrow(P)) {
    cat(sprintf("XD9! no out-of-fold sd rows for %s -- sd override unchanged\n", want))
    return(NULL)
  }
  if (anyDuplicated(paste(P$seat, P$party))) {
    cat(sprintf("XD9! %s carries duplicate (seat, party) rows for %s -- ignored\n", f, want))
    return(NULL)
  }

  # RESTRICTED TO THE CLASSES IT ACTUALLY HELPS, and this is not a tuning
  # choice -- the model's own validation says so. Its Gaussian log-score gain
  # over a flat SD was IND 1.50, OTH 0.95, ONP 0.91, against ALP 0.03 and
  # LNP 0.09. Setting every cell replaces the tuned seat_sd machinery for the
  # majors too, and measured on fed2022 that cost the 144 non-teal seats
  # 0.267 -> 0.278 of log loss (Tangney, Hunter, Higgins, Robertson, Mallee --
  # all major-party seats) while the teals gained. Widen where the model knows
  # something; leave the rest alone.
  cls <- Sys.getenv("AUSPOL_XGB_PRIMARY_SD_CLASSES", "IND,OTH,OTH_RIGHT,ONP")
  cls <- trimws(strsplit(cls, ",")[[1]])
  out <- base::matrix(NA_real_, nrow(shares), ncol(shares), dimnames = dimnames(shares))
  ri <- match(P$seat, rownames(shares))
  ci <- match(P$party, colnames(shares))
  keep <- !is.na(ri) & !is.na(ci) & is.finite(P$sd_hat) & P$sd_hat > 0 &
          P$party %in% cls
  if (any(keep)) {
    v <- P$sd_hat[keep]
    if (is.finite(floor_sd)) v <- pmax(v, floor_sd)
    out[cbind(ri[keep], ci[keep])] <- v
  }
  attr(out, "n_set") <- sum(keep)
  cat(sprintf("XD9  xgb primary sd for %s: %d of %d cells set | mean %.2f, median %.2f, max %.2f\n",
              want, sum(keep), length(out),
              mean(out, na.rm = TRUE), stats::median(out, na.rm = TRUE),
              suppressWarnings(max(out, na.rm = TRUE))))
  # Rows the shares matrix has but the model does not cover are a real gap, not
  # a rounding detail: they keep whatever the other override says, or the
  # simulator's default. Printed rather than left to be inferred.
  miss <- sum(is.na(match(rownames(shares), P$seat)))
  if (miss) cat(sprintf("XD9  %d of %d seats have no sd prediction and keep the existing value\n",
                        miss, length(seats)))
  out
}
