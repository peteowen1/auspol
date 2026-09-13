#' Per-seat surge parameters from the candidate-level emergence model
#'
#' Replaces the salience-derived emergence parameters the simulator runs on --
#' `surge_h`, `surge_party`, `surge_mu`, `surge_sd` -- with predictions from
#' `scripts/fit_xgb_emergence_v5.R`. **No simulator change is needed**: all four
#' are already per-seat vectors and the mixture is already implemented in the
#' compiled core (`src/seat_sim_core.cpp`, the `surge_h[i]` branch).
#'
#' WHY v5 AND NOT v4. v4 modelled the party CLASS in a seat. Three of the six
#' 2022 teals were training negatives under that target, because Wentworth's
#' independent vote went 33.0 to 35.8 -- a rise of 2.8 -- while Allegra Spender
#' personally went 0 to 35.8 and Kerryn Phelps did not stand. v4 gave Wentworth
#' a 1.1% hazard and Mackellar 1.3%. v5 models the CANDIDATE, which is what Pete
#' asked for on 2026-08-27, and gives those seats 28.7% and 17.4%.
#'
#' v5 also fixed a data fault that corrupted v4's inputs: Victoria's source puts
#' the party ABBREVIATION in `party_raw` and leaves `party_ab` empty, so a
#' `classify_party(party_raw, party_ab)` call returned `OTH` for all 731 vic2022
#' candidates. Every Labor and Liberal candidate then survived the non-majors
#' filter with no previous vote, and a 35% major-party result scored as a
#' 35-point emergence.
#'
#' THE TARGET. A non-major candidate whose own vote rose at least 10 points on
#' a baseline that depends on the class, because the two kinds of vote behave
#' differently (Pete's call, 2026-09-12):
#'
#' * GRN and ONP are INSTITUTIONAL. The vote belongs to the party and a new
#'   candidate inherits it, so the baseline is the class's previous share.
#' * IND, OTH and OTH_RIGHT are PERSONAL. The vote leaves with the person, so
#'   the baseline is what that individual polled in that seat last time.
#'
#' THE HAZARD IS CALIBRATED, AND THAT MATTERS. Taking the highest-scoring
#' candidate in a seat SELECTS on the prediction, so the winner's realised rate
#' beats its stated probability -- the raw argmax gave a mean 0.075 against a
#' 15.5% realised rate for independents. `fit_xgb_emergence_v5.R` corrects this
#' with a leave-one-pair-out isotonic regression, which is monotone and so
#' cannot reorder seats. An xgboost seat model was tried first and rejected: it
#' scored AUC 0.665 against 0.739 for the single feature it was built on.
#'
#' KNOWN AND NOT FIXED. sa2026 badly under-fires -- 10.9% predicted against
#' 63.8% realised -- which is the One Nation breakthrough, the case the surge
#' exists for. One Nation's out-of-fold AUC under this target is 0.555, barely
#' above a coin toss, and OTH ranks worse than chance at 0.148 on 31 emergences
#' in 2,590 rows. Greens (0.902) and independents (0.677) carry the model.
#'
#' BACKTEST ONLY. A backtest must predict a pair with a model that never saw it,
#' so this reads the leave-one-pair-out file.
#'
#' **`live = TRUE` IS NOT IMPLEMENTED.** It prints a message and returns `NULL`.
#' The live forecast has no out-of-fold row for an election that has not
#' happened, so it would need the all-data model plus a feature builder that
#' constructs the v6 columns from the current forecast's own inputs -- the
#' equivalent of `xgb_primary_predict_live()`, which does not exist for the
#' emergence model. Until it does, `fit_seats_full.R` cannot use this and does
#' not call it.
#'
#' This docstring previously described the live path as though it worked, which
#' is how an unimplemented stub gets wired into a published forecast on the
#' strength of its own documentation. Corrected by the review gate 2026-09-11.
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
  if (isTRUE(live)) {
    cat("XS9! live mode is not wired yet -- the emergence model has no live feature builder\n")
    return(NULL)
  }
  # AUSPOL_XGB_SURGE_SRC names the file, so the v4 and v5 models can be run
  # against each other without editing code. Registered in published_flags.R.
  oof_f <- Sys.getenv("AUSPOL_XGB_SURGE_SRC", "output/xgb-emergence-v5-seat.csv")
  if (!file.exists(oof_f)) {
    cat(sprintf("XS9! %s missing -- run scripts/fit_xgb_emergence_v5.R; AUSPOL_XGB_SURGE ignored\n", oof_f))
    return(NULL)
  }
  P <- data.table::fread(oof_f, showProgress = FALSE)
  need <- c("pair", "seat", "surge_h", "surge_party", "surge_mu", "surge_sd")
  if (!all(need %in% names(P))) {
    cat(sprintf("XS9! %s lacks %s -- AUSPOL_XGB_SURGE ignored\n", oof_f,
                paste(setdiff(need, names(P)), collapse = ", ")))
    return(NULL)
  }
  # NSE guard: `pair` is a column of P, so a bare `target_election` on the right
  # is fine but the argument must not share a column's name. It does not; the
  # local copy is belt and braces against a future rename. See CLAUDE.md.
  want <- target_election
  P <- P[P$pair == want]
  if (!nrow(P)) {
    cat(sprintf("XS9! no out-of-fold surge rows for %s in %s -- surge parameters unchanged\n",
                want, oof_f))
    return(NULL)
  }
  if (anyDuplicated(P$seat)) {
    cat(sprintf("XS9! %s carries %d duplicate seat rows for %s -- AUSPOL_XGB_SURGE ignored\n",
                oof_f, sum(duplicated(P$seat)), want))
    return(NULL)
  }

  # v5 writes ONE row per seat, already carrying the chosen recipient and the
  # calibrated hazard, so there is no argmax to take here. match() on the seat
  # name, never merge()-then-positional-assign: data.table::merge() sorts by
  # default and would splice the wrong seat's parameters in. Same fix as the six
  # in R/xgb_primary_override.R.
  idx <- match(seats, P$seat)
  miss <- sum(is.na(idx))

  h   <- ifelse(is.na(idx), 0, P$surge_h[idx])
  mu  <- ifelse(is.na(idx), NA_real_, P$surge_mu[idx])
  sdv <- ifelse(is.na(idx), NA_real_, P$surge_sd[idx])
  pty <- ifelse(is.na(idx), NA_character_, as.character(P$surge_party[idx]))

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
  mu[!is.finite(mu)]   <- stats::median(P$surge_mu, na.rm = TRUE)
  sdv[!is.finite(sdv)] <- stats::median(P$surge_sd, na.rm = TRUE)
  sdv <- pmax(sdv, 0.1)

  cat(sprintf("XS9  xgb surge params for %s from %s: %d of %d seats (%d with no row), mean hazard %.3f, max %.3f, mean jump %.1f\n",
              want, basename(oof_f), sum(!is.na(idx)), length(seats), miss,
              mean(h), max(h), mean(mu)))
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
