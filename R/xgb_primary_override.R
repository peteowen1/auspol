#' Substitute the XGBoost challenger's primary predictions into a shares matrix
#'
#' Exploratory only -- not part of the published model. Loads the
#' leave-one-pair-out out-of-fold predictions written by
#' `scripts/fit_xgb_primary_cv.R` (`output/xgb-primary-oof-predictions.csv`)
#' and overwrites every (seat, party) cell of `shares` that file covers for
#' `pair_label`, renormalising each seat's row back to 100. Cells the xgb file
#' doesn't cover (should not happen for a class the shares matrix carries;
#' logged if it does) keep the harness's own value.
#'
#' @param shares Numeric matrix, seats x parties, summing to ~100 per row.
#' @param pair_label The target election label, matching the `pair` column
#'   in the oof-predictions file.
#' @param enabled Logical; defaults to `AUSPOL_XGB_PRIMARY` env var == "1".
#' @return The overridden matrix, or `shares` unchanged if not enabled.
#' @export
xgb_primary_override <- function(shares, pair_label, enabled = NULL) {
  if (is.null(enabled)) enabled <- identical(Sys.getenv("AUSPOL_XGB_PRIMARY", "0"), "1")
  if (!isTRUE(enabled)) return(shares)
  f <- "output/xgb-primary-oof-predictions.csv"
  if (!file.exists(f)) {
    cat(sprintf("XG1! %s missing; AUSPOL_XGB_PRIMARY ignored\n", f))
    return(shares)
  }
  X <- data.table::fread(f, showProgress = FALSE)
  X <- X[X$pair == pair_label]
  if (!nrow(X)) {
    cat(sprintf("XG1! no xgb predictions for %s; shares unchanged\n", pair_label))
    return(shares)
  }
  out <- shares
  n_hit <- 0L; n_miss <- 0L
  for (p in colnames(out)) {
    xp <- X[X$party == p]
    # setNames(...)[rownames(out)] silently keeps only the FIRST match per
    # seat if xp has duplicate (seat) rows -- an arbitrary pick among
    # duplicates, not an error. Guard rather than trust the input file is
    # one row per cell: a one-candidate-to-many-rows join upstream (the
    # exact shape found in docs/reviews/xgb-primary-flag-bugfixes-2026-09-10.md)
    # would otherwise feed this silently.
    dup <- xp[duplicated(xp$seat) | duplicated(xp$seat, fromLast = TRUE)]
    if (nrow(dup)) {
      stop(sprintf("xgb_primary_override(): %d duplicate seat row(s) for party %s, pair %s -- %s is not one row per (seat, party) cell",
                    nrow(dup), p, pair_label, f))
    }
    v <- stats::setNames(xp$xgb_pred, xp$seat)[rownames(out)]
    hit <- !is.na(v)
    out[hit, p] <- pmax(0, v[hit])
    n_hit <- n_hit + sum(hit); n_miss <- n_miss + sum(!hit)
  }
  out <- 100 * out / rowSums(out)
  cat(sprintf("XG1  xgb primary override ON for %s: %d cells replaced, %d kept (no xgb prediction)\n",
              pair_label, n_hit, n_miss))
  out
}

#' Predict LIVE primary shares with the final XGBoost model (not a backtest)
#'
#' Builds the same feature columns `fit_xgb_primary.R` builds for the
#' historical backtest, from the CURRENT forecast's own inputs, and predicts
#' with the model `scripts/fit_xgb_primary_final.R` trained on all 22
#' historical pairs (`output/xgb-primary-final.model` /
#' `-final-cols.json`). Same reference result as the backtest v1 arm:
#' pooled seat log loss 0.3358 -> 0.3122 leave-one-pair-out
#' (docs/reviews/xgb-primary-challenger-2026-09-09.md). Known weakness,
#' unresolved as of that write-up: worse than the shipped model specifically
#' on rare independent/minor-party emergences -- exactly the ONP-surge shape
#' this forecast is making for Victoria. NOT shipped; `AUSPOL_XGB_PRIMARY_LIVE`
#' defaults to 0 in `published_flags.R` pending the fix queue in
#' `docs/NEXT-STEPS.md`.
#'
#' @param shares The just-computed shipped-model shares matrix (seats x
#'   parties, summing to 100/row) -- becomes the `pred_share` feature.
#' @param mat22 Seat-level 2022 class shares matrix, same shape as `shares`.
#' @param a22 Named numeric vector, 2022 STATEWIDE class shares.
#' @param state_mean Named numeric vector, the forecast's statewide class
#'   shares this cycle.
#' @param returns `candidate_returns()` output, or `NULL` before vic2026
#'   nominations close (then same/same_mp default FALSE for every seat).
#' @param region Single string; must be one of the six regions the final
#'   model was trained on ("fed","nsw","qld","sa","vic","wa").
#' @param enabled Logical; defaults to `AUSPOL_XGB_PRIMARY_LIVE` env var == "1".
#' @return The overridden shares matrix, or `shares` unchanged if not
#'   enabled or the saved model/cols files are missing.
#' @export
xgb_primary_predict_live <- function(shares, mat22, a22, state_mean, returns,
                                      region = "vic", enabled = NULL) {
  if (is.null(enabled)) enabled <- identical(Sys.getenv("AUSPOL_XGB_PRIMARY_LIVE", "0"), "1")
  if (!isTRUE(enabled)) return(shares)
  model_f <- "output/xgb-primary-final.model"
  cols_f  <- "output/xgb-primary-final-cols.json"
  if (!file.exists(model_f) || !file.exists(cols_f)) {
    cat(sprintf("XG4! %s / %s missing -- run scripts/fit_xgb_primary_final.R; shares unchanged\n", model_f, cols_f))
    return(shares)
  }
  model <- xgboost::xgb.load(model_f)
  feat_cols <- jsonlite::fromJSON(readLines(cols_f))

  MAJ <- c("ALP", "LNP", "NAT")
  cf <- "output/candidacies.csv"
  n_prev <- NULL
  if (file.exists(cf)) {
    C22 <- data.table::fread(cf, showProgress = FALSE)
    C22 <- C22[C22$election == "vic2022"]
    n_prev <- C22[, .N, by = list(seat, party)]
  }

  seats <- rownames(shares); parties <- colnames(shares)
  rows <- data.table::CJ(seat = seats, party = parties, sorted = FALSE)
  rows[, pred_share := mapply(function(s, p) shares[s, p], seat, party)]
  rows[, x           := mapply(function(s, p) if (p %in% colnames(mat22)) mat22[s, p] else 0, seat, party)]
  rows[, level_prev  := vapply(party, function(p) if (p %in% names(a22)) unname(a22[[p]]) else 0, numeric(1))]
  rows[, level_now   := vapply(party, function(p) if (p %in% names(state_mean)) unname(state_mean[[p]]) else 0, numeric(1))]
  rows[, dev_prev    := x - level_prev]
  rows[, n_cand_prev := 0L]
  if (!is.null(n_prev)) {
    m <- merge(rows[, list(seat, party)], n_prev, by = c("seat","party"), all.x = TRUE)
    rows[, n_cand_prev := ifelse(is.na(m$N), 0L, m$N)]
  }
  rows[, n_cand_now := 1L]   # unknown pre-nomination; matches the backtest fallback
  rows[, same_i := 0L]; rows[, same_mp_i := 0L]
  if (!is.null(returns)) {
    R <- data.table::as.data.table(returns)
    m <- merge(rows[, list(seat, party)], R, by = c("seat","party"), all.x = TRUE)
    rows[, same_i := ifelse(is.na(m$same), 0L, as.integer(m$same))]
    if ("same_mp" %in% names(R)) rows[, same_mp_i := ifelse(is.na(m$same_mp), 0L, as.integer(m$same_mp))]
  }
  rows[, is_major_i := as.integer(party %in% MAJ)]

  party_levels <- c("ALP","GRN","IND","LNP","NAT","ONP","OTH","OTH_RIGHT")
  region_levels <- c("fed","nsw","qld","sa","vic","wa")
  for (p in party_levels) rows[[paste0("party_", p)]] <- as.integer(rows$party == p)
  for (r in region_levels) rows[[paste0("region_", r)]] <- as.integer(region == r)

  miss <- setdiff(feat_cols, names(rows))
  if (length(miss)) stop("xgb_primary_predict_live(): model expects columns not built here: ",
                          paste(miss, collapse = ", "))
  X <- as.matrix(rows[, ..feat_cols])
  pred <- predict(model, X)
  rows[, xgb_pred := pmax(0, pred)]

  out <- shares
  for (p in parties) {
    v <- stats::setNames(rows[rows$party == p]$xgb_pred, rows[rows$party == p]$seat)[seats]
    hit <- !is.na(v)
    out[hit, p] <- v[hit]
  }
  out <- 100 * out / rowSums(out)
  cat(sprintf("XG4  LIVE xgb primary prediction ON for %s: %d seat-classes overridden\n", region, nrow(rows)))
  out
}
