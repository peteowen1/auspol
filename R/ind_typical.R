# AUSPOL_IND_TYPICAL: an independent who is not the sitting member starts from
# the typical vote of past independents with the same signals, not from the
# statewide independent average.
#
# Pete, 2026-10-09, after walking four Victorian rows (Bass 2018, Hawthorn
# 2018, Brunswick 2022, Mildura 2022): the statewide average (5-7 points) is
# pulled up by the few who surge; a first-timer's median is 2.3 (n 1,453) and a
# returning loser's 2.4 (n 422), against 32.2 for a sitting member (n 83).
# Signals separate them: no signal median 2.6, council elected 9.0, top-quarter
# salience 7.6, Climate 200 19.1. docs/SEAT-REGISTRY.md (cross-seat, Victorian
# independents) and docs/plans/prereg-ind-typical-2026-10-09.md.
#
# Applied at one of two points (the value of the switch):
#   "base"  : before the frozen xgb trees, replacing new_ind_shrink_apply()'s
#             work (the trees then add their correction on top);
#   "final" : after the xgb override, so the trees' IND correction is replaced.
# A POST-XGB-TRAINING switch like AUSPOL_NEW_IND_SHRINK (post_xgb_switches()).

#' The validated `AUSPOL_IND_TYPICAL` switch
#'
#' @return `"0"` (off, shipped), `"base"` or `"final"`.
#' @export
ind_typical_mode <- function() {
  m <- Sys.getenv("AUSPOL_IND_TYPICAL", "0")
  if (!nzchar(m)) m <- "0"
  if (!m %in% c("0", "base", "final"))
    stop("AUSPOL_IND_TYPICAL must be \"0\", \"base\" or \"final\"; got \"", m, "\"", call. = FALSE)
  if (m != "0" && identical(new_ind_mode(), "1"))
    stop("AUSPOL_IND_TYPICAL=", m, " replaces AUSPOL_NEW_IND_SHRINK; set AUSPOL_NEW_IND_SHRINK=0 with it", call. = FALSE)
  m
}

# The signals, as model columns, from a feature table's IND rows.
.it_design <- function(d) {
  num <- function(v) { v <- suppressWarnings(as.numeric(v)); v[!is.finite(v)] <- 0; v }
  X <- cbind(
    intercept   = 1,
    # Climate 200 split by level: the federal teal wave (fed2022) must not set
    # the state effect (Sandringham 2022 went 9.2 -> 65.1 when it did).
    c200_fed    = num(d$c200) * as.numeric(grepl("^fed", d$pair)),
    c200_state  = num(d$c200) * as.numeric(!grepl("^fed", d$pair)),
    council_el  = num(d$council_elected),
    council_any = as.numeric(num(d$council_pct) > 0),
    own_prev    = log1p(num(d$own_prev_pcv)),
    returning   = as.numeric(num(d$same_i) == 1),
    jump        = log1p(100 * pmax(num(d$jump), 0)),
    permit      = num(d$permit),
    n_ind       = log(pmax(num(d$n_cand_now), 1))
  )
  X
}

.it_features <- function(features = NULL) {
  if (!is.null(features)) return(data.table::as.data.table(features))
  f <- out_path("xgb-primary-v6-features.csv")
  if (!file.exists(f)) stop("AUSPOL_IND_TYPICAL needs ", f, " (the stage-1 features and actuals)", call. = FALSE)
  data.table::fread(f, showProgress = FALSE)
}

# Which IND rows are in scope: an independent NOMINATED (from the candidacy
# corpus, known before polling day -- `n_cand_now` is 1 even in seats with no
# independent, 78 of 147 fed2022 rows), and it is not a sitting independent
# member standing again (same_mp_i).
.it_nominated <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      f <- out_path("candidacies.csv")
      if (!file.exists(f)) stop("AUSPOL_IND_TYPICAL needs output/candidacies.csv", call. = FALSE)
      C <- data.table::fread(f, select = c("election", "seat", "party"), showProgress = FALSE)
      C <- C[C$party == "IND", ]
      cache <<- unique(paste(C$election, normalise_seat(C$seat)))
    }
    cache
  }
})
.it_scope <- function(d) {
  mp <- suppressWarnings(as.numeric(d$same_mp_i))
  d$party == "IND" & paste(d$pair, normalise_seat(d$seat)) %in% .it_nominated() & !(mp %in% 1)
}

#' Fit the typical-independent model, time-forward
#'
#' On every IND cell of elections strictly before `target` in scope (an
#' independent stood; not a sitting independent re-standing):
#' `log(actual + 1)` regressed on the signals in `.it_design()`. Each signal's
#' coefficient is shrunk toward 0 by its own precision, `b * b^2 / (b^2 + se^2)`
#' (SE clustered on election), the form [seat_poll_weight()] uses. Each
#' jurisdiction's mean residual is an intercept shift shrunk by
#' `tau^2 / (tau^2 + se_j^2)`. Predictions are the conditional MEAN on the share
#' scale, `exp(fit) * smear - 1`, with Duan's smearing factor from the training
#' residuals, so a group's average is right and a typical member is not
#' handed the surges' share.
#' @param target Election label; nothing dated on or after it is read.
#' @param features Optional pre-read feature table.
#' @return list `beta` (shrunk), `beta_raw`, `se`, `region_shift`, `smear`, `n`, `n_el`.
#' @export
ind_typical_fit <- function(target, features = NULL) {
  FT <- .it_features(features)
  pairs <- unique(FT$pair)
  pairs <- pairs[elections_before(pairs, target)]
  tr <- FT[FT$pair %in% pairs & .it_scope(FT), ]
  act <- suppressWarnings(as.numeric(tr$actual_share))
  tr <- tr[is.finite(act), ]; act <- act[is.finite(act)]
  if (nrow(tr) < 50L) return(NULL)
  X <- .it_design(tr); y <- log1p(pmax(act, 0))
  keep <- colSums(abs(X)) > 0
  X <- X[, keep, drop = FALSE]
  XtX_inv <- solve(crossprod(X))
  b <- as.numeric(XtX_inv %*% crossprod(X, y)); names(b) <- colnames(X)
  e <- as.numeric(y - X %*% b)
  el <- tr$pair; G <- length(unique(el))
  meat <- Reduce(`+`, lapply(split(seq_along(e), el), function(i) {
    s <- crossprod(X[i, , drop = FALSE], e[i]); s %*% t(s) }))
  V <- XtX_inv %*% meat %*% XtX_inv * G / max(1, G - 1)
  se <- sqrt(pmax(diag(V), 0)); names(se) <- colnames(X)
  bs <- b
  sl <- setdiff(names(b), "intercept")
  bs[sl] <- b[sl] * b[sl]^2 / (b[sl]^2 + se[sl]^2)
  e_s <- as.numeric(y - X %*% bs)
  # jurisdiction intercept shifts, shrunk (DerSimonian-Laird between-region variance)
  rg <- sub("[0-9]{4}$", "", tr$pair)
  rm <- tapply(e_s, rg, mean); rn <- tapply(e_s, rg, length); rv <- tapply(e_s, rg, stats::var) / rn
  rv[!is.finite(rv)] <- stats::var(e_s)
  mu <- sum(rm / rv) / sum(1 / rv)
  tau2 <- max(0, stats::var(as.numeric(rm)) - mean(rv))
  shift <- (rm - mu) * tau2 / (tau2 + rv)
  # A jurisdiction with one cell has no variance, and with few earlier elections
  # tau2 can be undefined: no shift rather than an NA that reaches the seat
  # simulation (fed2007 under STAT=mean failed in leader_seat_apply, 2026-10-09).
  shift[!is.finite(shift)] <- 0
  if (!is.finite(mu)) mu <- 0
  e_f <- e_s - unname(shift[rg])
  list(beta = bs, beta_raw = b, se = se, region_shift = shift + mu, smear = mean(exp(e_f)),
       n = nrow(tr), n_el = G)
}

#' Predict the typical independent share for a target's in-scope IND cells
#' @param target Election label.
#' @param fit From [ind_typical_fit()].
#' @param features Optional pre-read feature table.
#' @return data.table `seat`, `skey`, `pred` (share points).
#' @export
ind_typical_predict <- function(target, fit, features = NULL) {
  FT <- .it_features(features)
  d <- FT[FT$pair == target & .it_scope(FT), ]
  if (!nrow(d)) return(data.table::data.table(seat = character(0), skey = character(0), pred = numeric(0)))
  X <- .it_design(d)[, names(fit$beta), drop = FALSE]
  rg <- sub("[0-9]{4}$", "", target)
  sh <- if (rg %in% names(fit$region_shift)) fit$region_shift[[rg]] else 0
  # AUSPOL_IND_TYPICAL_STAT: "median" (default) predicts the typical member of
  # the group; "mean" multiplies by the smearing factor, the group's average.
  st <- Sys.getenv("AUSPOL_IND_TYPICAL_STAT", "median")
  if (!st %in% c("median", "mean")) stop("AUSPOL_IND_TYPICAL_STAT must be \"median\" or \"mean\", not ", st, call. = FALSE)
  p <- exp(as.numeric(X %*% fit$beta) + sh) * (if (st == "mean") fit$smear else 1) - 1
  data.table::data.table(seat = d$seat, skey = normalise_seat(d$seat), pred = pmax(p, 0))
}

#' Replace in-scope independent shares with the typical-independent prediction
#'
#' A no-op unless `AUSPOL_IND_TYPICAL` equals `stage`. Each in-scope IND cell
#' with a share above 0 is set to its prediction, and the difference is shared
#' among the seat's other classes in proportion, so the row total is unchanged.
#' @param shares Seats x classes matrix.
#' @param target Election label.
#' @param stage `"base"` or `"final"`: where the caller sits.
#' @param code Log prefix.
#' @param features Optional pre-read feature table.
#' @return `shares`.
#' @export
ind_typical_apply <- function(shares, target, stage = c("base", "final"), code = "IT1", features = NULL) {
  stage <- match.arg(stage)
  if (!identical(ind_typical_mode(), stage) || !"IND" %in% colnames(shares)) return(shares)
  fit <- ind_typical_fit(target, features)
  if (is.null(fit)) {
    cat(sprintf("%s! %s: fewer than 50 earlier independent cells; shares unchanged\n", code, target))
    return(shares)
  }
  pr <- ind_typical_predict(target, fit, features)
  ci <- match("IND", colnames(shares))
  ri <- match(pr$skey, normalise_seat(rownames(shares)))
  ok <- which(!is.na(ri))
  out <- shares; moved <- 0; n <- 0L
  for (k in ok) {
    i <- ri[k]; old <- shares[i, ci]; tot <- sum(shares[i, ])
    if (old <= 0 || tot - old <= 0) next
    new <- min(pr$pred[k], tot)
    out[i, ] <- shares[i, ] * (tot - new) / (tot - old)
    out[i, ci] <- new
    moved <- moved + (new - old); n <- n + 1L
  }
  cat(sprintf("%s  typical-independent (%s) for %s: %d cell(s), mean change %+.2f points; fit on %d cells in %d elections; coefs %s; region shift %s %.3f; smear %.3f\n",
              code, stage, target, n, if (n) moved / n else 0, fit$n, fit$n_el,
              paste(sprintf("%s %.2f", names(fit$beta), fit$beta), collapse = ", "),
              sub("[0-9]{4}$", "", target), if (sub("[0-9]{4}$", "", target) %in% names(fit$region_shift)) fit$region_shift[[sub("[0-9]{4}$", "", target)]] else 0,
              fit$smear))
  out
}
