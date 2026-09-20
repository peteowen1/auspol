#' The honest null: permute demographics across seats, within each election
#'
#' `born_aus_pct` was pre-registered as the placebo for the education
#' correction and was NOT one: r(yr12_pct, born_aus_pct) = -0.706 over 1,989
#' seats, so the two columns read a single class-and-urbanity axis from opposite
#' ends and the check could not separate the hypotheses it named
#' (`docs/plans/prereg-education-residual-correction-2026-09-15.md`). With seven
#' mutually correlated census columns there is no "other column" that works as a
#' control at all.
#'
#' So the control has to break the LINK rather than swap the variable. This
#' permutes which seat gets which seat's demographics, inside each election, so
#' that every marginal distribution and the entire fitting procedure are
#' unchanged and only the seat-to-demographics correspondence is destroyed.
#' Anything that survives is the flexibility of the procedure, not a
#' measurement.
#'
#' Permuting WITHIN a pair, not across the corpus, matters: mean Year 12
#' completion drifts 51.4 to 60.8 between elections, so a corpus-wide shuffle
#' would also destroy the between-pair structure and would be a weaker, easier
#' null to beat.
#'
#' @param C Census table.
#' @param feature Column to permute.
#' @param shuffle 0 leaves `C` untouched; any other integer is the RNG seed, so
#'   a control can be run several times and its spread reported rather than one
#'   draw being taken as the answer.
#' @return `C`, with `feature` permuted within each pair when `shuffle` is set.
#' @keywords internal
.er_shuffle <- function(C, feature, shuffle = 0L) {
  shuffle <- suppressWarnings(as.integer(shuffle))
  if (!isTRUE(is.finite(shuffle)) || shuffle == 0L) return(C)
  C <- data.table::copy(C)
  # The seed is set and restored around the permutation so a control run does
  # not silently move every downstream draw in the harness -- the simulation
  # seed is a published switch and a control must not become a second arm.
  .old <- if (exists(".Random.seed", .GlobalEnv)) get(".Random.seed", .GlobalEnv) else NULL
  set.seed(shuffle)
  # Permute by pair. `.f` is assigned by reference per group; `pair` is a real
  # column so it is referenced bare only in `by=`, never in `i`.
  C[, (feature) := sample(.SD[[1L]]), by = pair, .SDcols = feature]
  if (is.null(.old)) {
    if (exists(".Random.seed", .GlobalEnv)) rm(".Random.seed", envir = .GlobalEnv)
  } else {
    assign(".Random.seed", .old, envir = .GlobalEnv)
  }
  C
}

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
#' @param shuffle Permutation control. 0 fits on the real census; any other
#'   integer is the RNG seed for [.er_shuffle()], which permutes `feature`
#'   WITHIN each pair so the seat-to-demographics link is broken while every
#'   marginal is preserved. Must be passed identically here and to
#'   [education_residual_apply()] -- a control shuffled at fit and not at apply
#'   measures something else entirely.
#' @return Single numeric coefficient, or `NA_real_` if the class has too few
#'   training rows.
#' @export
education_residual_b <- function(cls, exclude_pair,
                                 feature = "yr12_pct",
                                 oof = out_path("xgb-primary-v6-oof-predictions.csv"),
                                 census = out_path("census-features.csv"),
                                 shuffle = 0L) {
  if (!file.exists(oof) || !file.exists(census)) return(NA_real_)
  O <- data.table::fread(oof, showProgress = FALSE)
  C <- data.table::fread(census, showProgress = FALSE)
  if (!feature %in% names(C)) return(NA_real_)
  C <- .er_shuffle(C, feature, shuffle)
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
#' @param shuffle Permutation control; see [education_residual_b()]. Pass the
#'   same value both places or the control is not a control.
#' @return The corrected matrix, rows renormalised to their original totals.
#' @export
education_residual_apply <- function(shares, pair,
                                     classes = c("ONP", "OTH_RIGHT", "GRN"),
                                     feature = "yr12_pct",
                                     census = out_path("census-features.csv"),
                                     shuffle = 0L) {
  if (!file.exists(census)) {
    cat("ER1! census features missing; education residual correction SKIPPED\n")
    return(shares)
  }
  C <- data.table::fread(census, showProgress = FALSE)
  # Shuffled at FIT and at APPLY both. Permuting only one end would leave a
  # genuine coefficient sprayed onto the wrong seats, which measures how much
  # damage noise does -- a different question from whether the procedure
  # manufactures a gain out of nothing.
  C <- .er_shuffle(C, feature, shuffle)
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
    #
    # NAME THE SEATS. The count alone sent a whole session down the wrong path
    # on 2026-09-15: "5 of 93" reads as a census gap, and the real cause can be
    # either a missing census row OR a seat the two sides spell differently.
    # Only the names distinguish those, and they need opposite fixes.
    .miss <- rownames(shares)[is.na(f)]
    cat(sprintf("ER1! %d of %d seats have no census row for %s; correction SKIPPED\n  missing: %s\n",
                length(.miss), length(f), pair,
                paste(utils::head(.miss, 12), collapse = ", ")))
    return(shares)
  }
  s <- stats::sd(f)
  if (!is.finite(s) || s <= 0) return(shares)
  z <- (f - mean(f)) / s
  tot <- rowSums(shares)
  applied <- character(0)
  skipped <- character(0)
  for (cl in intersect(classes, colnames(shares))) {
    b <- education_residual_b(cl, pair, feature = feature, census = census,
                              shuffle = shuffle)
    if (!is.finite(b)) { skipped <- c(skipped, cl); next }
    shares[, cl] <- pmax(0, shares[, cl] + b * z)
    applied <- c(applied, sprintf("%s b=%+.4f", cl, b))
  }
  # PARTIAL failure was previously silent: total failure printed ER1!, but one
  # class of three dropping out (not enough training rows for it specifically)
  # produced no message at all -- only visible by diffing `applied` against
  # `classes` by hand. Found by the review gate 2026-09-16.
  if (length(skipped)) {
    cat(sprintf("ER1! %s: not enough training rows, no correction applied\n",
                paste(skipped, collapse = ", ")))
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
  # The control announces itself. An experiment that never ran looks exactly
  # like an experiment with no effect, and a control that silently failed to
  # shuffle would read as "the null also improves" -- the most expensive wrong
  # conclusion available here.
  cat(sprintf("ER1  education residual correction ON for %s (%s%s): %s\n",
              pair, feature,
              if (identical(as.integer(shuffle), 0L)) "" else
                sprintf(", SHUFFLED CONTROL seed=%s", shuffle),
              paste(applied, collapse = ", ")))
  shares
}
