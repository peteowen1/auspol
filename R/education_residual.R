#' Correct a primary prediction toward what education explains about its error
#'
#' Fits ONE coefficient per class on the residual, LEAVE-ONE-PAIR-OUT, and
#' applies it as an offset. The existing prediction is left intact -- this is
#' not the wholesale reallocation refused in
#' `docs/plans/prereg-class-concentration-v2-2026-09-15.md`, which threw the
#' per-seat predictions away and doubled pooled RMSE.
#'
#' Tested against `docs/plans/prereg-education-residual-correction-2026-09-15.md`.
#'
#' `z` is standardised WITHIN pair. Mean Year 12 completion drifts 51.4 to 60.8
#' across the corpus, so a raw value carries that drift between elections --
#' the fault `reviews/xgb-primary-sd-and-census-2026-09-12.md` found when
#' census was tried as a model feature.
#'
#' LEAKAGE: the coefficient for pair X is fitted on every pair EXCEPT X, from
#' out-of-fold predictions. Nothing from the election being predicted reaches
#' its own coefficient.
#'
#' @param cls Party class, one of the pre-registered `ONP`, `OTH_RIGHT`, `GRN`.
#' @param exclude_pair The pair being predicted; excluded from the fit.
#' @param feature Census column to use. The pre-registered placebo is
#'   `"born_aus_pct"`, which matched education exactly in the reallocation
#'   test -- if it matches again the mechanism is "correct toward anything
#'   correlated", not education.
#' @param oof,census Source tables.
#' @return Single numeric coefficient, or `NA_real_` if the class has too few
#'   training rows.
#' @export
education_residual_b <- function(cls, exclude_pair,
                                 feature = "yr12_pct",
                                 oof = "output/xgb-primary-v6-oof-predictions.csv",
                                 census = "output/census-features.csv") {
  if (!file.exists(oof) || !file.exists(census)) return(NA_real_)
  O <- data.table::fread(oof, showProgress = FALSE)
  C <- data.table::fread(census, showProgress = FALSE)
  if (!feature %in% names(C)) return(NA_real_)
  # `.cls` and `.ex`, never the bare argument names: a name matching a column
  # inside `[` binds to the COLUMN, recorded eight times in CLAUDE.md.
  .cls <- cls; .ex <- exclude_pair
  O <- O[O$party == .cls & O$pair != .ex]
  if (!nrow(O)) return(NA_real_)
  C <- C[, c("pair", "seat", feature), with = FALSE]
  data.table::setnames(C, feature, ".f")
  M <- merge(O, C, by = c("pair", "seat"))
  if (nrow(M) < 100) return(NA_real_)
  M[, .resid := actual_share - xgb_pred]
  # Within-pair z, and a pair with no spread in the feature contributes
  # nothing rather than dividing by zero.
  M[, .z := {
    s <- stats::sd(.f)
    if (!is.finite(s) || s <= 0) rep(0, .N) else (.f - mean(.f)) / s
  }, by = pair]
  den <- sum(M$.z * M$.z)
  if (!is.finite(den) || den <= 0) return(NA_real_)
  sum(M$.z * M$.resid) / den
}

#' Apply the fitted correction to one election's shares
#'
#' @param shares Numeric matrix, seats x classes.
#' @param pair The election being predicted.
#' @param classes Which classes to correct. Pre-registered as ONP, OTH_RIGHT,
#'   GRN. IND is excluded in advance: its education correlation is inconsistent
#'   in sign across elections (-0.357 to +0.240).
#' @param feature Census column; see [education_residual_b()].
#' @param census Source table.
#' @return The corrected matrix, rows renormalised to their original totals.
#' @export
education_residual_apply <- function(shares, pair,
                                     classes = c("ONP", "OTH_RIGHT", "GRN"),
                                     feature = "yr12_pct",
                                     census = "output/census-features.csv") {
  if (!file.exists(census)) {
    cat("ER1! census features missing; education residual correction SKIPPED\n")
    return(shares)
  }
  C <- data.table::fread(census, showProgress = FALSE)
  .p <- pair
  C <- C[C$pair == .p]
  if (!nrow(C) || !feature %in% names(C)) {
    cat(sprintf("ER1! no census rows for %s; correction SKIPPED\n", pair))
    return(shares)
  }
  f <- suppressWarnings(as.numeric(C[[feature]]))[match(rownames(shares), C$seat)]
  if (anyNA(f)) {
    # Reported and skipped, not silently part-applied: correcting some seats
    # and not others would shift the statewide total in a way nobody chose.
    cat(sprintf("ER1! %d of %d seats have no census row for %s; correction SKIPPED\n",
                sum(is.na(f)), length(f), pair))
    return(shares)
  }
  s <- stats::sd(f)
  if (!is.finite(s) || s <= 0) return(shares)
  z <- (f - mean(f)) / s
  tot <- rowSums(shares)
  applied <- character(0)
  for (cl in intersect(classes, colnames(shares))) {
    b <- education_residual_b(cl, pair, feature = feature, census = census)
    if (!is.finite(b)) next
    shares[, cl] <- pmax(0, shares[, cl] + b * z)
    applied <- c(applied, sprintf("%s b=%+.4f", cl, b))
  }
  if (!length(applied)) {
    cat("ER1! no class had enough training rows; correction SKIPPED\n")
    return(shares)
  }
  # Renormalise to the ORIGINAL row totals, so the correction moves shares
  # BETWEEN classes within a seat and never changes the seat's total.
  rs <- rowSums(shares)
  keep <- rs > 0
  shares[keep, ] <- shares[keep, ] * (tot[keep] / rs[keep])
  cat(sprintf("ER1  education residual correction ON for %s (%s): %s\n",
              pair, feature, paste(applied, collapse = ", ")))
  shares
}
