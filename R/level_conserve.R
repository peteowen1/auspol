# AUSPOL_LEVEL_CONSERVE: make the seats' implied statewide share equal the level.
#
# Every harness (and the live forecast) puts each class at its statewide level
# with dev_slope() and then renormalises each seat's row to 100. Level share a
# seat cannot hold -- an independent zeroed where none nominated, One Nation or
# the Greens zeroed where they did not stand, the whole level of a class with no
# candidate anywhere (dropped at R/forecast_statewide.R `keep <- intersect(...)`)
# -- is handed to whoever is left in that seat, pro rata. Measured over 28 state
# elections: ALP +1.07 (SE 0.38), Coalition +1.09 (SE 0.36) above the level they
# were handed (docs/reviews/wa-nt-seat-layer-trace-2026-10-25.md).
#
# This rakes the seat x class matrix (iterative proportional fitting) so every
# standing class's vote-weighted implied statewide share equals its level, the
# level first rescaled over the classes that actually stand, with every row
# still summing to its total. docs/plans/prereg-level-conserve-2026-10-25.md.
#
# Applied at one of two points (the value of the switch), like AUSPOL_IND_TYPICAL:
#   "base"  : on the base the frozen xgb trees see (just before the override /
#             xgb_primary_predict_live()), measured in the harnesses through
#             AUSPOL_XGB_BASE_DELTA;
#   "final" : after the last nomination zeroing, the last step before simulation;
#   "both"  : both.
# A POST-XGB-TRAINING switch (post_xgb_switches()): stage 1 must run it "0".
#
# WHAT IS HELD. A cell the harness holds at its value (the departed-hold
# matrix HELD, AUSPOL_DEPARTED_HOLD: a departed member's decayed personal vote)
# is never adjusted; it counts toward its class's total, and its class's other
# cells make up the rest. A cell of a class that does not stand in the seat
# (by the target's nomination table) is never adjusted either; at "final" it
# is already 0. A standing class with no level is held at its cells.

#' The validated `AUSPOL_LEVEL_CONSERVE` switch
#'
#' @return `"0"` (off, default), `"base"`, `"final"` or `"both"`.
#' @export
level_conserve_mode <- function() {
  m <- Sys.getenv("AUSPOL_LEVEL_CONSERVE", "0")
  if (!nzchar(m)) m <- "0"
  if (!m %in% c("0", "base", "final", "both"))
    stop("AUSPOL_LEVEL_CONSERVE must be \"0\", \"base\", \"final\" or \"both\"; got \"", m, "\"", call. = FALSE)
  m
}

#' Strength of the conservation, `AUSPOL_LEVEL_CONSERVE_LAMBDA`
#'
#' Final shares are `(1 - lambda) * current + lambda * raked`. Primary spec 1;
#' 0.5 is the pre-registered sensitivity.
#' @return numeric(1) in `[0, 1]`.
#' @export
level_conserve_lambda <- function() {
  v <- suppressWarnings(as.numeric(Sys.getenv("AUSPOL_LEVEL_CONSERVE_LAMBDA", "1")))
  if (length(v) != 1L || !is.finite(v) || v < 0 || v > 1)
    stop("AUSPOL_LEVEL_CONSERVE_LAMBDA must be a number in [0, 1]; got \"",
         Sys.getenv("AUSPOL_LEVEL_CONSERVE_LAMBDA"), "\"", call. = FALSE)
  v
}

#' Classes held out of the conservation, `AUSPOL_LEVEL_CONSERVE_HOLD`
#'
#' A comma list of classes whose level is dropped from the rake's targets, so
#' their cells keep their value and the other classes fill the rest in
#' proportion to their levels. Default `""` holds none (byte-identical).
#' Amendment 1 of `plans/prereg-level-conserve-2026-10-25.md` (IND: the level
#' cannot see candidates).
#' @return character vector of class names (possibly empty).
#' @export
level_conserve_hold <- function() {
  v <- trimws(strsplit(Sys.getenv("AUSPOL_LEVEL_CONSERVE_HOLD", ""), ",", fixed = TRUE)[[1]])
  v[nzchar(v)]
}

.lc_cache <- new.env(parent = emptyenv())

#' Seat weights for the implied statewide share: formal votes at the PREVIOUS election
#'
#' Knowable before polling day. The previous election is the latest one of the
#' same region in `output/candidacies.csv` with a year before the target's.
#' Seats are matched by [normalise_seat()]; a seat with no previous figure (a
#' new or renamed seat) gets the median of the matched weights. With no corpus
#' or no match at all the weights are equal, and attribute `source` says so.
#'
#' @param seats Character, the share matrix's rownames.
#' @param target Target election label, e.g. `"wa2017"`.
#' @param corpus Optional data.frame with `election, region, year, seat, votes`
#'   (default: `output/candidacies.csv`).
#' @return Numeric vector of weights (> 0), one per seat, with attributes
#'   `source` (text) and `n_matched`.
#' @export
level_conserve_weights <- function(seats, target, corpus = NULL) {
  region <- sub("[0-9]{4}$", "", target)
  year <- suppressWarnings(as.integer(sub("^[a-z]+", "", target)))
  if (is.null(corpus)) {
    f <- out_path("candidacies.csv")
    key <- paste(f, if (file.exists(f)) format(file.mtime(f)) else "missing")
    if (is.null(.lc_cache[[key]])) {
      .lc_cache[[key]] <- if (file.exists(f))
        data.table::fread(f, select = c("election", "region", "year", "seat", "votes"), showProgress = FALSE) else FALSE
    }
    corpus <- .lc_cache[[key]]
  }
  equal <- function(why) structure(rep(1, length(seats)), source = sprintf("EQUAL weights (%s)", why), n_matched = 0L)
  if (isFALSE(corpus) || is.null(corpus) || !nrow(corpus)) return(equal("no candidacies corpus"))
  cy <- suppressWarnings(as.integer(corpus$year))
  cr <- as.character(corpus$region)
  prev_years <- cy[cr == region & is.finite(cy) & cy < year]
  if (!length(prev_years) || !is.finite(year)) return(equal(sprintf("no earlier %s election in the corpus", region)))
  py <- max(prev_years)
  sel <- cr == region & cy == py & is.finite(suppressWarnings(as.numeric(corpus$votes)))
  sk <- normalise_seat(as.character(corpus$seat[sel]))
  v <- suppressWarnings(as.numeric(corpus$votes[sel]))
  tot <- tapply(v, sk, sum)
  tot <- tot[is.finite(tot) & tot > 0]
  w <- as.vector(tot[normalise_seat(seats)])   # tapply gives a 1-d array; its dim breaks `weights * M`
  hit <- is.finite(w) & !is.na(w)
  if (!any(hit)) return(equal(sprintf("no seat matched %s%d", region, py)))
  w[!hit] <- stats::median(w[hit])
  structure(w, source = sprintf("formal votes at %s%d (%d of %d seats matched, the rest at the median)",
                                region, py, sum(hit), length(seats)),
            n_matched = sum(hit))
}

#' Which cells have a candidate standing, from the target's nomination table
#'
#' Same rule as [zero_unnominated()]: a cell is NOT standing only when the
#' table has that seat and the class appears somewhere in the table, and the
#' seat has no `votes > 0` row for that class. Everything else stands (so a
#' label mismatch cannot remove a whole column).
#' @param shares Seat-by-class matrix.
#' @param target data.frame with `seat, party, votes`, or NULL (every cell stands).
#' @return Logical matrix shaped like `shares`.
#' @export
level_conserve_standing <- function(shares, target = NULL) {
  S <- matrix(TRUE, nrow(shares), ncol(shares), dimnames = dimnames(shares))
  if (is.null(target) || !nrow(target)) return(S)
  tg <- as.data.frame(target)[, c("seat", "party", "votes")]
  tg <- tg[is.finite(tg$votes) & tg$votes > 0, , drop = FALSE]
  if (!nrow(tg)) return(S)
  stood <- paste(normalise_seat(tg$seat), tg$party)
  known_seat <- normalise_seat(rownames(shares)) %in% unique(normalise_seat(tg$seat))
  rk <- normalise_seat(rownames(shares))
  for (cl in intersect(colnames(shares), unique(tg$party)))
    S[, cl] <- !known_seat | paste(rk, cl) %in% stood
  S
}

#' Rake a seat-by-class matrix to statewide class totals (iterative proportional fitting)
#'
#' Columns are matched to vote-weighted targets, rows to their current totals,
#' by alternating multiplicative scaling of the adjustable cells. Cells at 0
#' stay 0 and nothing goes negative. Cells not in `adjust` keep their value and
#' count toward their row and column.
#'
#' Targets: `level` restricted to the classes that stand (a positive cell
#' somewhere), rescaled so they sum to the weighted mean row total minus the
#' mass of classes with no level. A class with a level and no standing cell
#' gives its level up pro rata to the other classes' LEVELS.
#'
#' Refuses loudly (`stop()`) when the targets cannot be met: a column whose held
#' cells already exceed its target, a column with a positive target and no
#' adjustable cell, or no convergence within `refuse_gap` points after
#' `max_iter` sweeps.
#'
#' @param shares Numeric matrix, seats x classes, rows summing to ~100.
#' @param level Named numeric, the statewide level per class (points).
#' @param weights Numeric, one per row (> 0).
#' @param adjust Logical matrix shaped like `shares`, TRUE where a cell may be
#'   scaled (default: every cell).
#' @param tol Convergence tolerance on the worst column gap (points).
#' @param max_iter Maximum sweeps.
#' @param refuse_gap Worst column gap (points) above which it refuses.
#' @return The raked matrix, with attribute `report`: a list holding
#'   `target`, `before`, `after` (named, vote-weighted implied shares of the
#'   targeted classes), `dropped` (classes with a level and no standing cell),
#'   `dropped_mass`, `iter`, `gap`, `n_fixed_rows`.
#' @export
level_conserve_rake <- function(shares, level, weights, adjust = NULL,
                                tol = 1e-8, max_iter = 10000L, refuse_gap = 0.01) {
  X <- as.matrix(shares)
  storage.mode(X) <- "double"
  if (any(!is.finite(X)) || any(X < 0)) stop("LCV1!! level_conserve_rake(): shares must be finite and >= 0", call. = FALSE)
  if (length(weights) != nrow(X) || any(!is.finite(weights)) || any(weights <= 0))
    stop("LCV1!! level_conserve_rake(): need one positive finite weight per seat", call. = FALSE)
  if (is.null(names(level)) || anyDuplicated(names(level)) || any(!is.finite(level)) || any(level < 0))
    stop("LCV1!! level_conserve_rake(): level must be a uniquely named, finite, non-negative vector", call. = FALSE)
  if (anyDuplicated(colnames(X))) stop("LCV1!! level_conserve_rake(): duplicate class columns", call. = FALSE)
  A <- if (is.null(adjust)) matrix(TRUE, nrow(X), ncol(X)) else (adjust & !is.na(adjust))
  if (!identical(dim(A), dim(X))) stop("LCV1!! level_conserve_rake(): adjust must have the shape of shares", call. = FALSE)
  A <- A & X > 0
  weights <- as.vector(weights)
  W <- sum(weights)
  wmean <- function(v) sum(weights * v) / W
  implied <- function(M) colSums(weights * M) / W
  tot <- rowSums(X)
  stands <- colSums(X > 0) > 0
  lv <- level[names(level) %in% colnames(X)]
  dropped <- names(level)[!names(level) %in% colnames(X)[stands]]
  J <- colnames(X) %in% names(lv) & stands          # targeted classes
  A[, !J] <- FALSE                                  # a class with no level is held
  # A row that must fill share but has nothing adjustable is held whole.
  fixed_rows <- which(rowSums(X * A) <= 0 & rowSums(X * !A) < tot - 1e-9)
  if (length(fixed_rows)) A[fixed_rows, ] <- FALSE
  F <- X * !A
  r <- tot - rowSums(F)
  lvJ <- lv[colnames(X)[J]]
  if (!length(lvJ) || sum(lvJ) <= 0) stop("LCV1!! level_conserve_rake(): no standing class has a positive level", call. = FALSE)
  avail <- wmean(tot) - wmean(rowSums(F[, !J, drop = FALSE]))
  target <- lvJ / sum(lvJ) * avail
  tadj <- target - implied(F[, J, drop = FALSE])
  Y <- X * A
  cnow <- implied(Y[, J, drop = FALSE])
  bad <- names(tadj)[tadj < -1e-9 | (tadj > 1e-9 & cnow <= 0)]
  if (length(bad))
    stop(sprintf("LCV1!! level conservation infeasible: class(es) %s cannot reach their level (target %s; held %s; adjustable %s)",
                 paste(bad, collapse = ", "),
                 paste(sprintf("%.3f", target[bad]), collapse = "/"),
                 paste(sprintf("%.3f", (target - tadj)[bad]), collapse = "/"),
                 paste(sprintf("%.3f", cnow[bad]), collapse = "/")), call. = FALSE)
  before <- implied(X)[colnames(X)[J]]
  jj <- which(J)
  gap <- Inf; it <- 0L
  while (it < max_iter) {
    it <- it + 1L
    cs <- colSums(weights * Y[, jj, drop = FALSE]) / W
    f <- ifelse(cs > 0, tadj / cs, 1)
    Y[, jj] <- sweep(Y[, jj, drop = FALSE], 2L, f, `*`)
    rs <- rowSums(Y)
    g <- ifelse(rs > 0, r / rs, 1)
    Y <- Y * g
    gap <- max(abs(colSums(weights * Y[, jj, drop = FALSE]) / W - tadj))
    if (gap < tol) break
  }
  if (!is.finite(gap) || gap > refuse_gap)
    stop(sprintf("LCV1!! level conservation infeasible: worst class gap %.4f points after %d sweeps (refuses above %.2f)",
                 gap, it, refuse_gap), call. = FALSE)
  out <- F + Y
  dimnames(out) <- dimnames(shares)
  attr(out, "report") <- list(target = target, before = before, after = implied(out)[colnames(X)[J]],
                              dropped = dropped, dropped_mass = sum(level[dropped]),
                              iter = it, gap = gap, n_fixed_rows = length(fixed_rows),
                              n_held = sum(X > 0 & !A & matrix(J, nrow(X), ncol(X), byrow = TRUE)))
  out
}

#' Apply `AUSPOL_LEVEL_CONSERVE` at one pipeline position (the entry point every caller uses)
#'
#' A no-op returning `shares` unchanged unless the switch names this `stage`
#' (or is `"both"`). Prints one `LCV1` line saying what it applied: the weight
#' source, the level mass dropped (classes with no candidate), and per targeted
#' class the implied statewide share before and after against its target, with
#' the worst departure before and after.
#'
#' `"final"`: rakes `shares` directly (it runs after the last nomination zero).
#' `"base"`: the cells of classes not standing (by `target`) are first zeroed
#' and their share handed out pro rata (the later nomination zero hands it out
#' by flows, so this is approximate), that matrix is raked, and the CHANGE the
#' rake made is added to `shares` on the standing cells. Additive on purpose:
#' `AUSPOL_XGB_BASE_DELTA` re-predicts a cell from cached base_pred + (this
#' run's share - stage-1 share), and the cached base_pred is already after the
#' nomination zero, so passing the zeroing itself through would count it twice.
#' A cell the addition takes below 0 is set to 0 and its row's adjustable cells
#' rescaled; the count is printed.
#'
#' @param shares Seats x classes matrix (rows ~100).
#' @param level Named numeric statewide level the seats were built on.
#' @param label Target election label (also the weight lookup).
#' @param stage `"base"` or `"final"`.
#' @param target Nomination table (`seat, party, votes` with votes > 0 where a
#'   candidate stood) or NULL (every cell with share stands).
#' @param held Logical matrix (dimnames matched by name; missing = FALSE) of cells held at their value.
#' @param weights Optional per-seat weights (default [level_conserve_weights()]).
#' @param code Log code.
#' @return `shares`, conserved.
#' @export
level_conserve_apply <- function(shares, level, label, stage = c("base", "final"), target = NULL,
                                 held = NULL, weights = NULL, code = "LCV1") {
  stage <- match.arg(stage)
  mode <- level_conserve_mode()
  if (!(identical(mode, stage) || identical(mode, "both"))) return(shares)
  lam <- level_conserve_lambda()
  level <- unlist(level)
  level <- level[is.finite(level)]
  hold_cls <- level_conserve_hold()
  if (length(hold_cls)) {
    absent <- setdiff(hold_cls, colnames(shares))
    if (length(absent)) cat(sprintf("%s! AUSPOL_LEVEL_CONSERVE_HOLD names class(es) not in the shares: %s\n",
                                    code, paste(absent, collapse = ", ")))
    level <- level[!names(level) %in% hold_cls]
    cat(sprintf("%s  holding %s out of the rake (AUSPOL_LEVEL_CONSERVE_HOLD)\n", code, paste(hold_cls, collapse = ", ")))
  }
  if (is.null(weights)) weights <- level_conserve_weights(rownames(shares), label)
  H <- matrix(FALSE, nrow(shares), ncol(shares), dimnames = dimnames(shares))
  if (!is.null(held)) {
    ri <- match(rownames(shares), rownames(held)); ci <- match(colnames(shares), colnames(held))
    for (j in which(!is.na(ci))) H[!is.na(ri), j] <- held[ri[!is.na(ri)], ci[j]] %in% TRUE
  }
  S <- level_conserve_standing(shares, target)
  if (stage == "base") {
    Z <- shares
    Z[!S] <- 0
    zs <- rowSums(Z); k <- zs > 0
    if (any(H & !S)) H[!S] <- FALSE
    Zr <- Z
    Zr[k, ] <- renorm_hold(Z[k, , drop = FALSE], H[k, , drop = FALSE])
    Zr[!k, ] <- shares[!k, , drop = FALSE]                 # a row with no standing class: left alone
    attr(Zr, "skipped") <- NULL
    R <- level_conserve_rake(Zr, level, weights, adjust = S & !H)
    rep_ <- attr(R, "report")
    d <- lam * (R - Zr)
    out <- shares + d
    neg <- out < 0
    n_neg <- sum(neg)
    if (n_neg) {
      for (i in which(rowSums(neg) > 0)) {
        tot_i <- sum(shares[i, ])
        out[i, neg[i, ]] <- 0
        fx <- H[i, ]; s_free <- sum(out[i, !fx])
        if (s_free > 0) out[i, !fx] <- out[i, !fx] * (tot_i - sum(out[i, fx])) / s_free
      }
    }
    # Reported: the raked base, which is what reaches the frozen trees through
    # AUSPOL_XGB_BASE_DELTA (cached base_pred + this change). The later
    # nomination zero hands the non-standing share out by flows, not pro rata,
    # so at AUSPOL_XGB_PRIMARY=0 the final match is approximate.
    after <- rep_$after
  } else {
    R <- level_conserve_rake(shares, level, weights, adjust = S & !H)
    rep_ <- attr(R, "report")
    out <- (1 - lam) * shares + lam * R
    n_neg <- 0L
    after <- colSums(weights * out) / sum(weights)
    after <- after[names(rep_$after)]
  }
  attr(out, "report") <- NULL
  cls <- names(rep_$target)
  dep_b <- rep_$before - rep_$target; dep_a <- after - rep_$target
  cat(sprintf(paste0("%s  level conserve (%s, lambda %.2f) for %s: weights %s | level dropped %.2f points%s | ",
                     "max |implied - level| %.3f -> %.3f | %s | %d sweep(s), gap %.1e, %d held or non-standing cell(s) excluded%s%s\n"),
              code, stage, lam, label, if (is.null(attr(weights, "source"))) "supplied" else attr(weights, "source"),
              rep_$dropped_mass,
              if (length(rep_$dropped)) sprintf(" (no candidate: %s)", paste(rep_$dropped, collapse = "/")) else "",
              max(abs(dep_b)), max(abs(dep_a)),
              paste(sprintf("%s %.2f->%.2f (level %.2f)", cls, rep_$before, after, rep_$target), collapse = ", "),
              rep_$iter, rep_$gap, rep_$n_held,
              if (rep_$n_fixed_rows) sprintf(", %d row(s) with nothing adjustable left alone", rep_$n_fixed_rows) else "",
              if (stage == "base") sprintf(" | base: change added to standing cells, %d cell(s) clamped at 0", n_neg) else ""))
  out
}

