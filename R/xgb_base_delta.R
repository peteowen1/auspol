# Measurement mode for targeted base_pred fixes (AUSPOL_XGB_BASE_DELTA, default
# "0"). Not a model change. Called from xgb_primary_override().

#' Where the stage-1 reference shares for a pair live
#' @param pair_label Election label.
#' @return Path `output/xgb-base-ref/<pair>.csv`.
#' @keywords internal
#' @noRd
xgb_base_ref_path <- function(pair_label) out_path("xgb-base-ref", paste0(pair_label, ".csv"))

#' Record the shares a stage-1 harness holds at the override point
#'
#' WHY A SIDECAR. The cached `base_pred` is the harness's shares at the END of a
#' stage-1 run (after nomination zeroing, the salience blend and so on). The
#' override at stage 6 sits EARLIER in the pipeline, so its `shares` differ from
#' the cached base by those later steps even with no fix on: measured on vic2022,
#' 272 of 528 cells differed by more than 0.05 (Narracan ALP 0.0 cached against
#' 30.4 here, because Labor did not stand; Mulgrave IND 5.3 against 1.3, the
#' salience blend). A comparison against the cached base is therefore useless at
#' baseline. Recording the SAME point in the stage-1 run gives a reference that
#' differs from a stage-6 run only by what the run itself changed.
#'
#' Written by [xgb_primary_override()] when it is disabled (stage 1) and
#' `AUSPOL_XGB_BASE_RECORD=1`.
#' @param shares The harness's share matrix at the override call.
#' @param pair_label Election label.
#' @return The path written, invisibly.
#' @keywords internal
#' @noRd
xgb_base_ref_write <- function(shares, pair_label) {
  p <- xgb_base_ref_path(pair_label)
  dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
  long <- data.table::data.table(seat = rep(rownames(shares), times = ncol(shares)),
                                 party = rep(colnames(shares), each = nrow(shares)),
                                 share = as.vector(shares))
  data.table::fwrite(long, p)
  cat(sprintf("XG9r base-delta reference for %s recorded: %d cells -> %s\n", pair_label, nrow(long), p))
  invisible(p)
}

#' Re-predict a few cells of an as-at model with a new base_pred (no retrain)
#'
#' base_pred is BOTH the base_margin and a feature of the as-at models
#' (`AUSPOL_XGB_BASE_MARGIN=2`, `scripts/fit_xgb_primary_asat.R`), so a changed
#' base share has to change both. This loads the frozen as-at model(s) for
#' `pair_label` (the saved seed ensemble, averaged as the fit script averages
#' it), takes the cells' other features from `output/xgb-primary-v6-features.csv`,
#' and predicts each cell twice: with the cached base (`old`) and with the new
#' one (`new`). Returns `NULL`, with a log line, when the models or features
#' cannot reproduce the cached base, so the caller falls back to the additive
#' estimate.
#'
#' @param pair_label Target election label, e.g. `"vic2022"`.
#' @param seat,party Character vectors naming the cells.
#' @param base_new,base_old Numeric vectors: the new and the cached base share.
#' @param f Path of the predictions file in use; only the as-at file has models.
#' @return `list(new=, old=, n_models=)` of raw (unclamped) predictions, or `NULL`.
#' @keywords internal
#' @noRd
.xgb_asat_repredict <- function(pair_label, seat, party, base_new, base_old, f) {
  if (!identical(basename(f), "xgb-primary-asat-predictions.csv")) {
    cat(sprintf("XG9! %s is not the as-at predictions file; no frozen model for it\n", f))
    return(NULL)
  }
  mdir <- out_path("xgb-primary-asat")
  mf <- file.path(mdir, paste0(pair_label, ".ubj"))
  cf <- file.path(mdir, "feat_cols.txt")
  ff <- out_path("xgb-primary-v6-features.csv")
  need <- c(mf, cf, ff)
  miss <- need[!file.exists(need)]
  if (length(miss)) {
    cat(sprintf("XG9! cannot re-predict %s, missing %s\n", pair_label, paste(miss, collapse = ", ")))
    return(NULL)
  }
  cols <- readLines(cf, warn = FALSE)
  FT <- data.table::fread(ff, select = unique(c("pair", "seat", "party", "base_pred", cols)),
                          showProgress = FALSE)
  keep_rows <- which(FT$pair == pair_label)
  FT <- FT[keep_rows]
  ix <- match(paste(seat, party), paste(FT$seat, FT$party))
  if (anyNA(ix)) {
    cat(sprintf("XG9! %d of %d cells not in the features file for %s\n", sum(is.na(ix)), length(ix), pair_label))
    return(NULL)
  }
  worst <- max(abs(FT$base_pred[ix] - base_old))
  if (!is.finite(worst) || worst > 1e-3) {
    cat(sprintf("XG9! features-file base_pred differs from the cached base by up to %.4f for %s; cannot re-predict\n",
                worst, pair_label))
    return(NULL)
  }
  M_old <- as.matrix(FT[ix, cols, with = FALSE])
  M_new <- M_old
  if ("base_pred" %in% cols) M_new[, "base_pred"] <- base_new
  mfs <- mf
  k <- 2L
  while (file.exists(sub("[.]ubj$", sprintf("-m%d.ubj", k), mf))) {
    mfs <- c(mfs, sub("[.]ubj$", sprintf("-m%d.ubj", k), mf)); k <- k + 1L
  }
  mods <- lapply(mfs, xgboost::xgb.load)
  pred_with <- function(M, margin) {
    dm <- xgboost::xgb.DMatrix(data = M, missing = NA)
    xgboost::setinfo(dm, "base_margin", margin)
    acc <- 0
    for (m in mods) acc <- acc + stats::predict(m, dm) / length(mods)
    acc
  }
  list(new = pred_with(M_new, base_new), old = pred_with(M_old, base_old), n_models = length(mods))
}

#' Measurement mode: feed this run's base share to the frozen as-at trees
#'
#' `AUSPOL_XGB_BASE_DELTA=1`. The backtest override reads a static file of
#' as-at predictions, so a fix that changes `base_pred` for a few cells can
#' only reach it by rebuilding from stage 1, which retrains the as-at models
#' and moves unrelated elections by ~0.005 log loss each. The live forecast
#' never retrains for a base_pred change: it hands the new base_pred to the
#' frozen trees as `base_margin`. This does the same in the backtests.
#'
#' For each (seat, class) cell, takes delta = this run's `shares` at the
#' override minus the same shares recorded by the stage-1 run
#' (`output/xgb-base-ref/<pair>.csv`, see `xgb_base_ref_write()`); the new base
#' is the cached `base_pred` the as-at prediction was built on plus delta. Cells
#' within `AUSPOL_XGB_BASE_DELTA_TOL`
#' (default 0.05 points) keep the cached prediction untouched. The others are
#' re-predicted by the frozen as-at model with the new base as BOTH
#' `base_margin` and the `base_pred` feature (the faithful version), corrected
#' so that an unchanged base reproduces the cached value exactly. If the model
#' cannot be loaded the additive estimate `cached + (new base - old base)` is
#' used and the log says "ADDITIVE (approximate)". Predictions are clamped at 0
#' and each seat that had a changed cell is rescaled to its pre-shift total; the
#' caller then renormalises to 100 and nomination zeroing still applies later.
#'
#' @param shares Seats x classes matrix the harness holds before the override.
#' @param X The cached predictions for `pair_label` (`pair, seat, party,
#'   base_pred, xgb_pred, ...`).
#' @param pair_label Target election label.
#' @param f Predictions file in use.
#' @return `X` with `xgb_pred` replaced for the changed cells; the per-cell
#'   comparison is attached as attribute `base_delta`.
#' @keywords internal
#' @noRd
xgb_base_delta_apply <- function(shares, X, pair_label, f) {
  tol <- as.numeric(Sys.getenv("AUSPOL_XGB_BASE_DELTA_TOL", "0.05"))
  if (!is.finite(tol) || tol < 0) stop("AUSPOL_XGB_BASE_DELTA_TOL must be a number >= 0")
  if (!"base_pred" %in% names(X)) {
    cat(sprintf("XG9! %s has no base_pred column; AUSPOL_XGB_BASE_DELTA ignored\n", f))
    return(X)
  }
  Xd <- data.table::copy(X)
  si <- match(Xd$seat, rownames(shares)); pj <- match(Xd$party, colnames(shares))
  has <- !is.na(si) & !is.na(pj)
  now <- rep(NA_real_, nrow(Xd))
  now[has] <- shares[cbind(si[has], pj[has])]
  base_old <- Xd$base_pred
  # The reference: this pair's shares at the same point of a stage-1 run
  # (xgb_base_ref_write). delta = what this run changed; the new base the frozen
  # trees see is the cached base plus that change, so every later pipeline step
  # (zeroing, blends) stays exactly as it was when the cached base was built.
  rf <- xgb_base_ref_path(pair_label)
  if (file.exists(rf)) {
    R0 <- data.table::fread(rf, showProgress = FALSE)
    ref <- R0$share[match(paste(Xd$seat, Xd$party), paste(R0$seat, R0$party))]
    delta <- now - ref
    src <- sprintf("reference %s (%s)", basename(rf), format(file.mtime(rf), "%Y-%m-%d %H:%M"))
  } else {
    # No silent fallback (review of 1c3f440): comparing with the cached base_pred
    # moved 272 of 528 vic2022 cells at baseline, so a run without references
    # would re-predict hundreds of cells and still look like a forecast.
    stop(sprintf("AUSPOL_XGB_BASE_DELTA=1 but %s is missing: run stage 1 of scripts/rebuild_forecasts.sh (it records the references), or set AUSPOL_XGB_BASE_DELTA=0 to keep the cached as-at predictions", rf),
         call. = FALSE)
  }
  base_new <- base_old + delta
  fin <- has & is.finite(delta)
  big <- fin & abs(delta) > 0.05
  ch <- fin & abs(delta) > tol
  version <- "nothing to re-predict"
  old_pred <- Xd$xgb_pred
  n_seats <- 0L
  if (any(ch)) {
    rp <- .xgb_asat_repredict(pair_label, Xd$seat[ch], Xd$party[ch], base_new[ch], base_old[ch], f)
    if (!is.null(rp)) {
      new_pred <- pmax(0, rp$new + (old_pred[ch] - pmax(0, rp$old)))
      resid <- max(abs(pmax(0, rp$old) - old_pred[ch]))
      version <- sprintf("FAITHFUL (frozen as-at trees, %d model(s), new base_margin + new base_pred feature; unchanged-base re-prediction matches cache to %.4f)",
                         rp$n_models, resid)
    } else {
      new_pred <- pmax(0, old_pred[ch] + delta[ch])
      version <- "ADDITIVE (approximate: cached prediction + base delta)"
    }
    pre <- tapply(old_pred, Xd$seat, sum, na.rm = TRUE)
    Xd$xgb_pred[ch] <- new_pred
    chs <- unique(Xd$seat[ch])
    n_seats <- length(chs)
    for (s in chs) {
      r <- which(Xd$seat == s)
      post <- sum(Xd$xgb_pred[r], na.rm = TRUE)
      if (post > 0) Xd$xgb_pred[r] <- Xd$xgb_pred[r] * pre[[s]] / post
    }
  }
  cat(sprintf("XG9  base-delta mode ON for %s: %d of %d cells have |delta| > 0.05; %d acted on (tolerance %.3f) in %d seat(s) | %s | vs %s\n",
              pair_label, sum(big), sum(has), sum(ch), tol, n_seats, version, src))
  if (any(big)) {
    o <- utils::head(which(big)[order(-abs(delta[big]))], 5L)
    for (i in o) {
      cat(sprintf("XG9    %-22s %-10s base %7.2f -> %7.2f | pred %7.2f -> %7.2f\n",
                  Xd$seat[i], Xd$party[i], base_old[i], base_new[i], old_pred[i], Xd$xgb_pred[i]))
    }
  }
  attr(Xd, "base_delta") <- data.frame(seat = Xd$seat, party = Xd$party, base_old = base_old,
                                      base_new = base_new, delta = delta, acted = ch)
  Xd
}
