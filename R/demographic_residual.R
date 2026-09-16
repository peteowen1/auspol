#' Correct a primary prediction toward what DEMOGRAPHICS explain about its error
#'
#' Arm A of `docs/plans/prereg-demographic-axis-2026-09-15.md`. The
#' single-feature ancestor in [education_residual_apply()] was REFUSED: it bet
#' everything on `yr12_pct` and its `born_aus_pct` placebo was not a placebo at
#' all, correlating -0.706 with it over 1,989 seats.
#'
#' This fits ALL seven census columns at once under an elastic net, so each
#' column earns its own penalised coefficient instead of one being hand-picked,
#' and the honest control is the within-pair permutation in [.er_shuffle()]
#' rather than a swapped column.
#'
#' THREE PROPERTIES THAT ARE DESIGN, NOT ACCIDENT:
#'
#' * **Within-pair z.** Mean Year 12 completion drifts 51.4 to 60.8 across the
#'   corpus, so a raw value carries that drift between elections and a tree or a
#'   linear fit reads it as a jurisdiction label. This is the fault
#'   `reviews/xgb-primary-sd-and-census-2026-09-12.md` found when census was
#'   first tried as a model feature.
#' * **No intercept.** Each `z` is mean-zero within its pair, so a coefficient
#'   vector with no intercept produces corrections that also sum to zero across
#'   a pair's seats. The correction therefore MOVES vote between seats and
#'   leaves the statewide total for each class alone. An intercept would shift
#'   every seat together and silently re-level the state.
#' * **Folds are PAIRS.** `lambda` and `alpha` are chosen by leave-one-training-
#'   pair-out CV, never by row-wise folds. Seats within an election share
#'   campaign, leader and statewide swing, so row-wise folds would leak a pair
#'   into its own validation set and choose a penalty far too weak.
#'
#' LEAKAGE: the model for pair X is fitted on every pair EXCEPT X, from
#' out-of-fold predictions, and the penalty is tuned inside that training set.
#' Nothing from the election being predicted reaches its own coefficients.
#'
#' @param cls Party class.
#' @param exclude_pair The pair being predicted; excluded from the fit entirely.
#' @param features Census columns to offer the model.
#' @param alphas Elastic-net mixing values to search. 0 is ridge, 1 is lasso.
#' @param oof,census Source tables.
#' @param shuffle Control seed; see [.er_shuffle()]. 0 is the real fit.
#' @return A list with `b` (named coefficient vector), `alpha`, `lambda` and
#'   `n` (training rows), or `NULL` when the class cannot be fitted.
#' @export
demographic_residual_fit <- function(cls, exclude_pair,
                                     features = DEMO_FEATURES,
                                     alphas = c(0, 0.25, 0.5, 0.75, 1),
                                     oof = "output/xgb-primary-v6-oof-predictions.csv",
                                     census = "output/census-features.csv",
                                     shuffle = 0L) {
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    cat("DR0! glmnet not installed; demographic correction unavailable\n")
    return(NULL)
  }
  if (!file.exists(oof) || !file.exists(census)) return(NULL)
  O <- data.table::fread(oof, showProgress = FALSE)
  C <- data.table::fread(census, showProgress = FALSE)
  feats <- intersect(features, names(C))
  if (!length(feats)) return(NULL)
  for (f in feats) C <- .er_shuffle(C, f, shuffle)
  # `.cls` and `.ex`, never the bare argument names: a symbol matching a column
  # binds to the COLUMN inside `[`, recorded eight times in CLAUDE.md.
  .cls <- cls; .ex <- exclude_pair
  O <- O[O$party == .cls & O$pair != .ex]
  if (!nrow(O)) return(NULL)
  M <- merge(O, C[, c("pair", "seat", feats), with = FALSE], by = c("pair", "seat"))
  if (nrow(M) < 100) return(NULL)

  Z <- .demo_z(M, feats)
  y <- M$actual_share - M$xgb_pred
  keep <- stats::complete.cases(Z) & is.finite(y)
  Z <- Z[keep, , drop = FALSE]; y <- y[keep]; pr <- M$pair[keep]
  if (length(y) < 100 || length(unique(pr)) < 3) return(NULL)
  # A column with no spread left after z-scoring carries no information and
  # makes glmnet's standardisation undefined; drop it rather than feed a
  # constant in. `apply` over columns, so a single surviving column still
  # returns a matrix.
  sdv <- apply(Z, 2, stats::sd)
  Z <- Z[, is.finite(sdv) & sdv > 0, drop = FALSE]
  if (!ncol(Z)) return(NULL)

  foldid <- as.integer(factor(pr))
  best <- NULL
  for (a in alphas) {
    cv <- tryCatch(
      glmnet::cv.glmnet(Z, y, alpha = a, foldid = foldid,
                        standardize = FALSE, intercept = FALSE),
      error = function(e) NULL)
    if (is.null(cv)) next
    i <- which(cv$lambda == cv$lambda.min)[1]
    sc <- cv$cvm[i]
    if (is.null(best) || sc < best$score) {
      best <- list(score = sc, alpha = a, lambda = cv$lambda.min, fit = cv)
    }
  }
  if (is.null(best)) return(NULL)
  cf <- as.matrix(stats::coef(best$fit, s = "lambda.min"))
  b <- cf[rownames(cf) != "(Intercept)", 1]
  names(b) <- rownames(cf)[rownames(cf) != "(Intercept)"]
  list(b = b, alpha = best$alpha, lambda = best$lambda, n = length(y))
}

#' The census columns offered to the demographic correction
#'
#' Named here rather than at each call site so the six harnesses cannot drift
#' apart -- which the surge training pair lists already did once, costing
#' Queensland its four One Nation winners until 2026-09-07.
#' @export
DEMO_FEATURES <- c("yr12_pct", "born_aus_pct", "indig_pct", "over55_pct",
                   "under35_pct", "lang_other_pct", "edu_25plus_pct")

#' Standardise each census column within its pair
#'
#' @param M Table carrying `pair` and the feature columns.
#' @param feats Columns to standardise.
#' @return Numeric matrix, one column per feature.
#' @keywords internal
.demo_z <- function(M, feats) {
  out <- vapply(feats, function(f) {
    v <- suppressWarnings(as.numeric(M[[f]]))
    # Centre and scale WITHIN pair. ave() over a split keeps the row order.
    mu <- stats::ave(v, M$pair, FUN = function(x) mean(x, na.rm = TRUE))
    sg <- stats::ave(v, M$pair, FUN = function(x) stats::sd(x, na.rm = TRUE))
    z <- (v - mu) / sg
    z[!is.finite(z)] <- NA_real_
    z
  }, numeric(nrow(M)))
  if (is.null(dim(out))) out <- matrix(out, nrow = nrow(M),
                                       dimnames = list(NULL, feats))
  out
}

#' Apply the fitted demographic correction to one election's shares
#'
#' PARTIAL APPLICATION IS DELIBERATE, and fixed in advance by
#' `docs/plans/prereg-demographic-axis-2026-09-15.md`. The single-feature
#' ancestor skipped an entire election if any seat lacked a census row, which
#' discarded 13 of 23 pairs -- including fed2025 over ONE seat out of 152.
#'
#' Both numbers re-verified against `output/census-features.csv` on
#' 2026-09-17, because a sibling plan
#' (`prereg-education-residual-correction-2026-09-15.md`) tabulates fed2025 as
#' **3** of 152 and this docstring inherited the other figure. This one is
#' right: exactly 13 of the 23 pairs carry a row with a missing census value,
#' and fed2025's single such row is **Bullwinkel** -- a division created in
#' 2021, so it has no prior-election census to carry forward. The sibling's
#' table is counting NON-EXACT rows (a seat matched to an older boundary
#' vintage) and labelling them "no census row", which are different things:
#' fed2025 has 1 of each, not 3 of either. Its nsw2023 (5) and wa2025 (9)
#' figures are right as non-exact counts, and its "of 152"/"of 59"
#' denominators are census-file row counts, not chamber sizes -- fed2025's
#' chamber is 150.
#'
#' Here a seat with no census row simply gets no correction, which is the
#' neutral action, and `z` is re-centred over the seats that DO have data so the
#' corrections still sum to about zero and the statewide class totals are
#' preserved exactly as they are under full coverage. Coverage is printed for
#' every pair, because a pair corrected on 56% of its seats must never be
#' silently compared with one corrected on 100%.
#'
#' @param shares Numeric matrix, seats x classes.
#' @param pair The election being predicted.
#' @param classes Which classes to correct.
#' @param features,census,shuffle See [demographic_residual_fit()].
#' @return The corrected matrix, rows renormalised to their original totals.
#' @export
demographic_residual_apply <- function(shares, pair,
                                       classes = c("ONP", "OTH_RIGHT", "GRN"),
                                       features = DEMO_FEATURES,
                                       census = "output/census-features.csv",
                                       shuffle = 0L) {
  if (!file.exists(census)) {
    cat("DR1! census features missing; demographic correction SKIPPED\n")
    return(shares)
  }
  C <- data.table::fread(census, showProgress = FALSE)
  feats <- intersect(features, names(C))
  if (!length(feats)) {
    cat("DR1! no census feature columns present; correction SKIPPED\n")
    return(shares)
  }
  for (f in feats) C <- .er_shuffle(C, f, shuffle)
  .p <- pair
  C <- C[C$pair == .p]
  if (!nrow(C)) {
    cat(sprintf("DR1! no census rows for %s; correction SKIPPED\n", pair))
    return(shares)
  }
  idx <- match(rownames(shares), C$seat)
  cov_ok <- !is.na(idx)
  if (!any(cov_ok)) {
    cat(sprintf("DR1! no seat of %s matched a census row; correction SKIPPED\n", pair))
    return(shares)
  }
  # Re-centred on the COVERED seats, so the corrections sum to zero over the
  # seats that actually receive one.
  Z <- matrix(0, nrow = nrow(shares), ncol = length(feats),
              dimnames = list(rownames(shares), feats))
  usable <- character(0)
  for (f in feats) {
    v <- rep(NA_real_, nrow(shares))
    v[cov_ok] <- suppressWarnings(as.numeric(C[[f]][idx[cov_ok]]))
    ok <- is.finite(v)
    s <- if (sum(ok) > 1) stats::sd(v[ok]) else NA_real_
    if (!is.finite(s) || s <= 0) next
    Z[ok, f] <- (v[ok] - mean(v[ok])) / s
    usable <- c(usable, f)
  }
  if (!length(usable)) {
    cat(sprintf("DR1! no census column varies across %s; correction SKIPPED\n", pair))
    return(shares)
  }

  tot <- rowSums(shares)
  applied <- character(0)
  for (cl in intersect(classes, colnames(shares))) {
    fit <- demographic_residual_fit(cl, pair, features = usable,
                                    census = census, shuffle = shuffle)
    if (is.null(fit) || !length(fit$b)) next
    bf <- intersect(names(fit$b), colnames(Z))
    if (!length(bf)) next
    adj <- as.vector(Z[, bf, drop = FALSE] %*% fit$b[bf])
    # A seat with no census data has z = 0 on every column, so its adjustment is
    # already exactly zero; this is belt and braces against a future column
    # whose default is not zero.
    adj[!cov_ok] <- 0
    shares[, cl] <- pmax(0, shares[, cl] + adj)
    nz <- names(fit$b)[fit$b != 0]
    applied <- c(applied, sprintf("%s[a=%.2f n=%d: %s]", cl, fit$alpha, fit$n,
                                  if (length(nz)) paste(sprintf("%s%+.3f", nz, fit$b[nz]),
                                                        collapse = " ") else "all shrunk to zero"))
  }
  if (!length(applied)) {
    cat(sprintf("DR1! no class could be fitted for %s; correction SKIPPED\n", pair))
    return(shares)
  }
  rs <- rowSums(shares)
  keep <- rs > 0
  shares[keep, ] <- shares[keep, ] * (tot[keep] / rs[keep])
  # The control announces itself, and coverage is never implicit: an experiment
  # that never ran looks exactly like an experiment with no effect.
  cat(sprintf("DR1  demographic correction ON for %s (%d of %d seats covered, %d columns%s)\n",
              pair, sum(cov_ok), length(cov_ok), length(usable),
              if (identical(as.integer(shuffle), 0L)) "" else
                sprintf(", SHUFFLED CONTROL seed=%s", shuffle)))
  for (a in applied) cat(sprintf("DR1    %s\n", a))
  shares
}
