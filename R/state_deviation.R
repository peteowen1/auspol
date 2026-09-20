#' Correct a federal seat's primaries for how its STATE is moving
#'
#' A federal forecast anchors to a national swing, so it cannot say that Western
#' Australia swung to Labor harder than the country did. In 2022 it did, by a
#' lot: mean ALP per-seat primary error +6.43 across 15 WA seats, positive in 14
#' of them, with Hasluck +10.4, Tangney +10.3, Pearce +9.7 and Swan +6.0. The
#' same shape appears in every federal election -- the spread of state-level
#' means runs sd 2.6 to 4.2 points.
#'
#' Pete identified the cause: *"tangey and hasluck would be fixed by state level
#' polling within fed elections? as WA was polling higher than other states for
#' ALP?"* Tested against
#' `docs/plans/prereg-state-deviation-2026-09-15.md`.
#'
#' FEDERAL ONLY, and that is the whole design. `CLAUDE.md` records these same
#' four columns going into the primary model as FEATURES and costing 3.8740 ->
#' 3.9297 pooled RMSE: they exist only for federal pairs, so 6,100 non-federal
#' cells were filled with `state_poll_dev = 0` and `state_elec_gap = 999`, and a
#' tree splits on a filler as cleanly as on a measurement. Ninety-six percent of
#' non-federal predictions moved, by up to 5.87 points, on columns that said
#' nothing about them. Applying the correction after the fact, to federal seats
#' only, means no non-federal cell is touched and there is no filler to key on.
#'
#' LEAKAGE: the coefficient for pair X is fitted on the state-level residuals of
#' every OTHER federal pair. Nothing from the election being predicted reaches
#' its own coefficient.
#'
#' @name state_deviation
NULL

#' Fit the state-deviation coefficient for one class, leave-one-pair-out
#'
#' @param cls `"ALP"` or `"LNP"`. Each gets its own coefficient rather than
#'   assuming `b_LNP = -b_ALP`: the deviation is defined on the ALP swing, and
#'   how much of it comes out of the Coalition rather than the minors is an
#'   empirical question, not an identity.
#' @param exclude_pair The federal pair being predicted; excluded from the fit.
#' @param oof,dev Source tables.
#' @param shuffle Control seed. 0 is the real fit; any other integer permutes
#'   which state each seat belongs to, within its election, destroying the
#'   seat-to-state link while leaving every marginal and the whole procedure
#'   intact. See [.sd_shuffle()].
#' @return Single coefficient, or `NA_real_` when there is too little to fit.
#' @export
state_deviation_b <- function(cls, exclude_pair,
                              oof = out_path("xgb-primary-v6-oof-predictions.csv"),
                              dev = out_path("state-deviation-features.csv"),
                              shuffle = 0L) {
  if (!file.exists(oof) || !file.exists(dev)) return(NA_real_)
  O <- data.table::fread(oof, showProgress = FALSE)
  D <- data.table::fread(dev, showProgress = FALSE)
  D <- .sd_shuffle(D, shuffle)
  .cls <- cls; .ex <- exclude_pair
  O <- O[O$party == .cls & grepl("^fed", O$pair) & O$pair != .ex]
  if (!nrow(O)) return(NA_real_)
  M <- merge(O, unique(D[, c("pair", "seat", "state", "state_poll_dev", "state_poll_n"),
                         with = FALSE]),
             by = c("pair", "seat"))
  # A state-year with no polling contributes nothing. The file stores that as
  # poll_dev 0 with n 0, and a zero is a value a regression would happily fit;
  # the count is what distinguishes "no deviation" from "no reading".
  M <- M[M$state_poll_n > 0]
  if (!nrow(M)) return(NA_real_)
  M[, .resid := actual_share - xgb_pred]
  # ONE ROW PER STATE-YEAR, not per seat. Seats within a state share the
  # deviation exactly, so fitting on seats would treat 47 NSW divisions as 47
  # independent observations of one number and shrink the standard error by
  # roughly sqrt(47) -- the same clustering fault CLAUDE.md records for the
  # 139 party-cycles that were really 33 independent cycles ("Cluster the
  # standard error on the right unit").
  S <- M[, .(err = mean(.resid), dev = .SD$state_poll_dev[1L]), by = c("pair", "state")]
  if (nrow(S) < 5) return(NA_real_)
  den <- sum(S$dev * S$dev)
  if (!is.finite(den) || den <= 0) return(NA_real_)
  sum(S$dev * S$err) / den
}

#' Two-predictor state-deviation coefficients (v2)
#'
#' Arm of `docs/plans/prereg-state-deviation-v2-2026-09-19.md`. Same
#' leave-target-out, one-row-per-state-year residual table as
#' [state_deviation_b()], regressed on BOTH `state_poll_dev` and the decayed
#' prior state-election swing `state_elec_dev * exp(-gap / 24)`, by ridge
#' with the penalty chosen leave-one-election-out on the state-year table.
#' A state-year with neither source is dropped from the fit and gets no
#' correction at apply time.
#'
#' @inheritParams state_deviation_b
#' @param lambdas Ridge penalty grid.
#' @return Named numeric `c(b_poll, b_elec, lambda, n)`, or `NA`s when too
#'   little to fit.
#' @export
state_deviation_b2 <- function(cls, exclude_pair,
                               oof = out_path("xgb-primary-v6-oof-predictions.csv"),
                               dev = out_path("state-deviation-features.csv"),
                               shuffle = 0L,
                               lambdas = c(1, 3, 10, 30, 100, 300)) {
  na2 <- c(b_poll = NA_real_, b_elec = NA_real_, lambda = NA_real_, n = NA_real_)
  if (!file.exists(oof) || !file.exists(dev)) return(na2)
  O <- data.table::fread(oof, showProgress = FALSE)
  D <- data.table::fread(dev, showProgress = FALSE)
  D <- .sd_shuffle(D, shuffle)
  .cls <- cls; .ex <- exclude_pair
  O <- O[O$party == .cls & grepl("^fed", O$pair) & O$pair != .ex]
  if (!nrow(O)) return(na2)
  keep <- c("pair", "seat", "state", "state_poll_dev", "state_poll_n", "state_elec_dev", "state_elec_gap")
  if (!all(keep %in% names(D))) return(na2)
  M <- merge(O, unique(D[, keep, with = FALSE]), by = c("pair", "seat"))
  if (!nrow(M)) return(na2)
  M[, .resid := actual_share - xgb_pred]
  M[, .x1 := ifelse(state_poll_n > 0, state_poll_dev, 0)]
  M[, .x2 := .sd_elec_term(state_elec_dev, state_elec_gap)]
  S <- M[, .(err = mean(.resid), x1 = .SD$.x1[1L], x2 = .SD$.x2[1L]), by = c("pair", "state")]
  S <- S[x1 != 0 | x2 != 0]
  if (nrow(S) < 6 || length(unique(S$pair)) < 3) return(na2)
  X <- cbind(S$x1, S$x2); y <- S$err
  ridge <- function(X, y, lam) {
    XtX <- crossprod(X) + diag(lam, ncol(X))
    # a collinear or near-empty design must not kill the run: it scores Inf
    # in the penalty search and NA if it is the final fit
    tryCatch(as.numeric(solve(XtX, crossprod(X, y))), error = function(e) rep(NA_real_, ncol(X)))
  }
  # penalty by leave-one-ELECTION-out, the independent unit
  sse <- vapply(lambdas, function(lam) {
    sum(vapply(unique(S$pair), function(pr) {
      tr <- S$pair != pr
      b <- ridge(X[tr, , drop = FALSE], y[tr], lam)
      if (anyNA(b)) return(Inf)
      sum((y[!tr] - X[!tr, , drop = FALSE] %*% b)^2)
    }, numeric(1)))
  }, numeric(1))
  if (!any(is.finite(sse))) return(na2)
  lam <- lambdas[which.min(sse)]
  b <- ridge(X, y, lam)
  if (anyNA(b)) return(na2)
  c(b_poll = b[1], b_elec = b[2], lambda = lam, n = nrow(S))
}

#' The decayed prior-state-election term
#' @param elec_dev,gap Columns of the state-deviation table.
#' @keywords internal
.sd_elec_term <- function(elec_dev, gap) {
  ed <- suppressWarnings(as.numeric(elec_dev)); g <- suppressWarnings(as.numeric(gap))
  out <- ifelse(is.finite(ed) & is.finite(g) & g < 999, ed * exp(-g / 24), 0)
  out[!is.finite(out)] <- 0
  out
}

#' Permute which state each seat sits in, within its election
#'
#' The honest null for this mechanism. It leaves every state's deviation value
#' and every election's set of seats untouched and destroys only the
#' correspondence between them, so anything that still improves is the
#' flexibility of the procedure rather than a measurement.
#'
#' @param D The state-deviation table.
#' @param shuffle 0 leaves `D` alone; any other integer is the RNG seed.
#' @return `D`, with `state` and its attached values permuted within each pair.
#' @keywords internal
.sd_shuffle <- function(D, shuffle = 0L) {
  shuffle <- suppressWarnings(as.integer(shuffle))
  if (!isTRUE(is.finite(shuffle)) || shuffle == 0L) return(D)
  D <- data.table::copy(D)
  # Saved and restored so a control run cannot quietly become a second arm by
  # moving every downstream simulation draw.
  .old <- if (exists(".Random.seed", .GlobalEnv)) get(".Random.seed", .GlobalEnv) else NULL
  set.seed(shuffle)
  cols <- c("state", "state_poll_dev", "state_elec_dev", "state_elec_gap", "state_poll_n")
  cols <- intersect(cols, names(D))
  D[, (cols) := {
    i <- sample.int(.N)
    lapply(.SD, function(v) v[i])
  }, by = pair, .SDcols = cols]
  if (is.null(.old)) {
    if (exists(".Random.seed", .GlobalEnv)) rm(".Random.seed", envir = .GlobalEnv)
  } else {
    assign(".Random.seed", .old, envir = .GlobalEnv)
  }
  D
}

#' Apply the state-deviation correction to one federal election's shares
#'
#' @param shares Numeric matrix, seats x classes.
#' @param pair The federal pair being predicted. A non-federal pair returns
#'   `shares` untouched and says so -- the mechanism is federal by construction.
#' @param classes Which classes to correct.
#' @param dev,shuffle See [state_deviation_b()].
#' @param mode 1 = shipped polls-only form; 2 = [state_deviation_b2()] (v2 arm).
#' @return The corrected matrix, rows renormalised to their original totals.
#' @export
state_deviation_apply <- function(shares, pair, classes = c("ALP", "LNP"),
                                  dev = out_path("state-deviation-features.csv"),
                                  shuffle = 0L, mode = 1L) {
  mode <- suppressWarnings(as.integer(mode))
  if (identical(mode, 2L)) return(.state_deviation_apply2(shares, pair, classes, dev, shuffle))
  if (!grepl("^fed", pair)) {
    cat(sprintf("SD1  %s is not a federal election; state-deviation correction not applicable\n", pair))
    return(shares)
  }
  if (!file.exists(dev)) {
    cat("SD1! state-deviation features missing; correction SKIPPED\n")
    return(shares)
  }
  D <- data.table::fread(dev, showProgress = FALSE)
  D <- .sd_shuffle(D, shuffle)
  .p <- pair
  D <- unique(D[D$pair == .p, c("seat", "state", "state_poll_dev", "state_poll_n"), with = FALSE])
  if (!nrow(D)) {
    cat(sprintf("SD1! no state-deviation rows for %s; correction SKIPPED\n", pair))
    return(shares)
  }
  i <- match(rownames(shares), D$seat)
  dv <- rep(0, nrow(shares))
  np <- rep(0, nrow(shares))
  ok <- !is.na(i)
  dv[ok] <- suppressWarnings(as.numeric(D$state_poll_dev[i[ok]]))
  np[ok] <- suppressWarnings(as.numeric(D$state_poll_n[i[ok]]))
  # A seat whose state has no polling reading gets no correction. That is the
  # neutral action, and it is why Tasmania, the ACT and the Northern Territory
  # are untouched here -- none of them has state-level federal polling.
  live <- ok & is.finite(dv) & is.finite(np) & np > 0
  if (!any(live)) {
    cat(sprintf("SD1! no seat of %s sits in a state with polling; correction SKIPPED\n", pair))
    return(shares)
  }
  dv[!live] <- 0

  tot <- rowSums(shares)
  applied <- character(0)
  skipped <- character(0)
  for (cl in intersect(classes, colnames(shares))) {
    b <- state_deviation_b(cl, pair, dev = dev, shuffle = shuffle)
    if (!is.finite(b)) { skipped <- c(skipped, cl); next }
    shares[, cl] <- pmax(0, shares[, cl] + b * dv)
    applied <- c(applied, sprintf("%s b=%+.4f", cl, b))
  }
  # PARTIAL failure used to print nothing -- total failure (below) fires SD1!,
  # but one class dropping out of several was only inferable by diffing
  # `applied` against `classes` by hand. Found by the review gate 2026-09-16.
  if (length(skipped)) {
    cat(sprintf("SD1! %s: not enough training rows, no correction applied\n",
                paste(skipped, collapse = ", ")))
  }
  if (!length(applied)) {
    cat(sprintf("SD1! no class could be fitted for %s; correction SKIPPED\n", pair))
    return(shares)
  }
  rs <- rowSums(shares)
  keep <- rs > 0
  shares[keep, ] <- shares[keep, ] * (tot[keep] / rs[keep])
  st <- unique(D$state[i[live]])
  cat(sprintf("SD1  state-deviation correction ON for %s (%d of %d seats, states %s%s): %s\n",
              pair, sum(live), length(live), paste(sort(st), collapse = "/"),
              if (identical(as.integer(shuffle), 0L)) "" else
                sprintf(", SHUFFLED CONTROL seed=%s", shuffle),
              paste(applied, collapse = ", ")))
  shares
}

# v2 apply: two predictors, five states, seats with neither source untouched.
.state_deviation_apply2 <- function(shares, pair, classes, dev, shuffle) {
  if (!grepl("^fed", pair)) {
    cat(sprintf("SD1  %s is not a federal election; state-deviation correction not applicable\n", pair))
    return(shares)
  }
  if (!file.exists(dev)) { cat("SD1! state-deviation features missing; correction SKIPPED\n"); return(shares) }
  D <- data.table::fread(dev, showProgress = FALSE)
  D <- .sd_shuffle(D, shuffle)
  .p <- pair
  keep <- c("seat", "state", "state_poll_dev", "state_poll_n", "state_elec_dev", "state_elec_gap")
  if (!all(keep %in% names(D))) { cat("SD1! v2 needs state_elec_dev/gap columns; correction SKIPPED\n"); return(shares) }
  D <- unique(D[D$pair == .p, keep, with = FALSE])
  if (!nrow(D)) { cat(sprintf("SD1! no state-deviation rows for %s; correction SKIPPED\n", pair)); return(shares) }
  i <- match(rownames(shares), D$seat); ok <- !is.na(i)
  x1 <- rep(0, nrow(shares)); x2 <- rep(0, nrow(shares))
  x1[ok] <- ifelse(D$state_poll_n[i[ok]] > 0, suppressWarnings(as.numeric(D$state_poll_dev[i[ok]])), 0)
  x2[ok] <- .sd_elec_term(D$state_elec_dev[i[ok]], D$state_elec_gap[i[ok]])
  x1[!is.finite(x1)] <- 0; x2[!is.finite(x2)] <- 0
  live <- ok & (x1 != 0 | x2 != 0)
  if (!any(live)) { cat(sprintf("SD1! v2: no seat of %s has a state poll or a fresh state election; correction SKIPPED\n", pair)); return(shares) }
  tot <- rowSums(shares); applied <- character(0); skipped <- character(0)
  for (cl in intersect(classes, colnames(shares))) {
    b <- state_deviation_b2(cl, pair, dev = dev, shuffle = shuffle)
    if (!all(is.finite(b[c("b_poll", "b_elec")]))) { skipped <- c(skipped, cl); next }
    shares[, cl] <- pmax(0, shares[, cl] + b[["b_poll"]] * x1 + b[["b_elec"]] * x2)
    applied <- c(applied, sprintf("%s b_poll=%+.4f b_elec=%+.4f (lambda %g, n %d)", cl,
                                  b[["b_poll"]], b[["b_elec"]], b[["lambda"]], as.integer(b[["n"]])))
  }
  if (length(skipped)) cat(sprintf("SD1! v2 %s: not enough training rows, no correction applied\n", paste(skipped, collapse = ", ")))
  if (!length(applied)) { cat(sprintf("SD1! v2: no class could be fitted for %s; correction SKIPPED\n", pair)); return(shares) }
  rs <- rowSums(shares); k <- rs > 0
  shares[k, ] <- shares[k, ] * (tot[k] / rs[k])
  st <- unique(D$state[i[live]])
  # per-state term sizes, so the plan's dry-run cases can be read off the log
  ps <- unique(data.table::data.table(state = D$state[i[live]], x1 = round(x1[live], 2), x2 = round(x2[live], 2)))
  cat(sprintf("SD1  v2 state-deviation ON for %s (%d of %d seats, states %s%s): %s | terms %s\n",
              pair, sum(live), length(live), paste(sort(st), collapse = "/"),
              if (identical(as.integer(shuffle), 0L)) "" else sprintf(", SHUFFLED CONTROL seed=%s", shuffle),
              paste(applied, collapse = ", "),
              paste(sprintf("%s poll %+.2f elec %+.2f", ps$state, ps$x1, ps$x2), collapse = "; ")))
  shares
}
