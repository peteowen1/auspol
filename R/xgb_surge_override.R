#' Per-seat surge parameters from the XGBoost emergence model
#'
#' Replaces the salience-derived emergence parameters the simulator runs on --
#' `surge_h`, `surge_party`, `surge_mu`, `surge_sd` -- with predictions from
#' `scripts/fit_xgb_emergence_v4.R`. **No simulator change is needed**: all four
#' are already per-seat vectors and the mixture is already implemented in the
#' compiled core (`src/seat_sim_core.cpp`, the `surge_h[i]` branch).
#'
#' Why. The salience hazard fires on almost nothing that actually happens:
#' `surge_h <= 0.05` on 184 of 201 historical emergences, and it only carries
#' real signal for independents. The xgb model, given the primary model's full
#' 25-feature set rather than the 7 that happened to be in an output file,
#' reaches out-of-fold AUC 0.936 overall -- IND 0.922, ONP 0.862 (the salience
#' version was 0.201, i.e. actively inverted), OTH_RIGHT 0.835, GRN 0.876 --
#' and gives candidates who did surge a median probability of 0.162 against
#' 0.003 for those who did not.
#'
#' BACKTEST ONLY SO FAR. A backtest must predict a pair with a model that never
#' saw it, so this reads the leave-one-pair-out out-of-fold file.
#'
#' **`live = TRUE` IS NOT IMPLEMENTED.** It prints a message and returns `NULL`.
#' The live forecast has no out-of-fold row for an election that has not
#' happened, so it would need the all-data model plus a feature builder that
#' constructs the 25 v6 columns from the current forecast's own inputs -- the
#' equivalent of `xgb_primary_predict_live()`, which does not exist for the
#' emergence model. Until it does, `fit_seats_full.R` cannot use this and does
#' not call it.
#'
#' This docstring previously described the live path as though it worked, which
#' is how an unimplemented stub gets wired into a published forecast on the
#' strength of its own documentation. Corrected by the review gate 2026-09-11.
#'
#' KNOWN, MEASURED, NOT FIXED: a calibration check -- generating outcomes from
#' the model's own predicted distributions and scoring them the way the real
#' ones are scored -- says this model is somewhat OVER-dispersed. It scores 2.83
#' on reality against 3.48 on its own self-generated data, i.e. reality sits
#' closer to its predictions than its own error bars imply. The published
#' behaviour was badly UNDER-dispersed, so this is a move through correct rather
#' than toward it, and the seat-level count is what decides whether it has gone
#' too far: 26 of 2,050 historical seat-elections were won by an emerging
#' non-major, and an arm that elects far more than that has over-corrected.
#'
#' @param shares Seats x classes matrix, as passed to `simulate_seat_contests()`.
#' @param target_election Pair label, e.g. `"fed2022"`, `"vic2026"`.
#' @param live NOT IMPLEMENTED -- `TRUE` returns `NULL` with a message. Reserved
#'   for a future live path once the emergence model has a feature builder.
#' @return `NULL`, or a list with `surge_h`, `surge_party`, `surge_mu` and
#'   `surge_sd`, each one entry per row of `shares` in the same order.
#' @export
xgb_surge_params_for <- function(shares, target_election, live = FALSE) {
  seats <- rownames(shares)
  if (is.null(seats)) {
    cat("XS9! shares has no rownames -- cannot build per-seat surge parameters\n")
    return(NULL)
  }
  oof_f <- "output/xgb-emergence-v4-oof.csv"
  if (!isTRUE(live)) {
    if (!file.exists(oof_f)) {
      cat(sprintf("XS9! %s missing -- run scripts/fit_xgb_emergence_v4.R; AUSPOL_XGB_SURGE ignored\n", oof_f))
      return(NULL)
    }
    P <- data.table::fread(oof_f, showProgress = FALSE)
    P <- P[P$pair == target_election]
    if (!nrow(P)) {
      cat(sprintf("XS9! no out-of-fold surge rows for %s -- surge parameters unchanged\n", target_election))
      return(NULL)
    }
  } else {
    cat("XS9! live mode is not wired yet -- the emergence model has no live feature builder\n")
    return(NULL)
  }

  # One row per (seat, class); the simulator wants ONE recipient per seat, so
  # take the class with the highest hazard. match() on a pre-built key, never
  # merge()-then-positional-assign: data.table::merge() sorts by default and
  # would splice the wrong seat's parameters in. Same fix as the six in
  # R/xgb_primary_override.R.
  P <- P[order(-P$p_emerge)]
  first <- !duplicated(P$seat)
  top <- P[first]
  idx <- match(seats, top$seat)
  miss <- sum(is.na(idx))

  h  <- ifelse(is.na(idx), 0, top$p_emerge[idx])
  mu <- ifelse(is.na(idx), NA_real_, top$mu[idx])
  sdv <- ifelse(is.na(idx), NA_real_, top$sd_j[idx])
  pty <- ifelse(is.na(idx), NA_character_, as.character(top$party[idx]))

  # A recipient the shares matrix does not carry cannot receive anything, so
  # drop the name and let the simulator pick among eligible classes rather than
  # silently surging nobody.
  bad <- !is.na(pty) & !(pty %in% colnames(shares))
  if (any(bad)) {
    # COUNTED AND PRINTED, not silently dropped. A seat whose predicted
    # recipient class is absent from this jurisdiction's shares matrix keeps a
    # NON-ZERO hazard while losing its named recipient -- so the simulator
    # allocates probability to "a surge happens here" with nobody to receive
    # it. Every other drop in this function is counted; this one was not, and
    # the summary below used table(), which discards NA, so the affected seats
    # vanished from the tally too. Found by the review gate 2026-09-11.
    cat(sprintf("XS9! %d of %d seat(s) name a recipient class absent from the shares matrix (%s) -- surge_party dropped to NA, hazard left intact\n",
                sum(bad), length(seats), paste(sort(unique(pty[bad])), collapse = ", ")))
    pty[bad] <- NA_character_
  }

  # surge_mu/surge_sd must be finite for every seat, including the ones with no
  # prediction, because the simulator takes them as full-length vectors. Seats
  # with hazard 0 never draw from them; the pooled values are a safe filler.
  mu[!is.finite(mu)]  <- stats::median(top$mu, na.rm = TRUE)
  sdv[!is.finite(sdv)] <- stats::median(top$sd_j, na.rm = TRUE)
  sdv <- pmax(sdv, 0.1)

  cat(sprintf("XS9  xgb surge params for %s: %d of %d seats (%d with no row), mean hazard %.3f, max %.3f, mean jump %.1f\n",
              target_election, sum(!is.na(idx)), length(seats), miss, mean(h), max(h), mean(mu)))
  # useNA = "ifany": table() drops NA by default, so seats with no named
  # recipient disappeared from this tally entirely and the counts silently
  # failed to sum to the number of seats.
  .tb <- table(pty, useNA = "ifany")
  names(.tb)[is.na(names(.tb))] <- "(none)"
  cat(sprintf("XS9  recipients over %d seats: %s\n", length(seats),
              paste(sprintf("%s=%d", names(.tb), as.integer(.tb)), collapse = " ")))
  list(surge_h = unname(h), surge_party = unname(pty),
       surge_mu = unname(mu), surge_sd = unname(sdv))
}
