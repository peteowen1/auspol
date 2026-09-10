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
#' Builds the same v6 feature columns `scripts/fit_xgb_primary_v6.R` builds
#' for the historical backtest, from the CURRENT forecast's own inputs, and
#' predicts with the model `scripts/fit_xgb_primary_v6_final.R` trained on
#' all 22 historical pairs (`output/xgb-primary-v6-final.model` /
#' `-v6-final-cols.json`). Same reference result as the backtest v6 arm:
#' pooled seat log loss 0.3403 -> ~0.3071 leave-one-pair-out, the best of
#' v1-v6 (`docs/reviews/xgb-primary-v5-seat-features-2026-09-10.md` for v5;
#' v6 adds the salience/emergence features -- jump, governed, permit,
#' surge_h, is_recipient -- on top of v5's set, built specifically because
#' v5's live smoke test found a severe side effect: Victoria's statewide
#' IND/OTH_RIGHT predicted share collapsed ~10x/~180x across 87 seats, 55 of
#' 87 predicting both classes exactly zero. v6 fixes this on the vic2022
#' backtest proxy (IND/OTH_RIGHT sums INCREASE slightly rather than
#' collapsing) -- but see the IMPORTANT CAVEAT below.
#'
#' **IMPORTANT CAVEAT, read before trusting this today**: the salience/surge
#' features (jump/governed/permit/surge_h/is_recipient) need a salience
#' corpus for the TARGET election. A PARTIAL one now exists for vic2026 --
#' `scripts/fetch_candidates_vic2026_prenomination.R` (Wikipedia, pre-
#' nomination, necessarily incomplete/unofficial) and
#' `scripts/fetch_seat_salience_vic2026_live.R` (real Google Trends data for
#' the IND/ONP/OTH_RIGHT candidates it found) feed into
#' `scripts/build_vic2026_salience_corpus.R`, which is what actually writes
#' into `output/salience-v6.csv` in the schema `governed_population()` reads
#' -- run that script (idempotent, safe to rerun) after either fetcher finds
#' new candidates. **This is a real, separate step, not automatic** -- an
#' earlier claim that it "activates with no further code change" once
#' nominations close was wrong: the two fetch scripts and the file this
#' function reads were never connected until `build_vic2026_salience_corpus.R`
#' was built. Coverage today: 46 of 88 seats, IND/ONP/OTH_RIGHT only -- most
#' seats and all other classes still run on safe defaults (jump=0,
#' governed=0, permit=1 protect, surge_h=0, is_recipient=0). Re-run all three
#' scripts in sequence after 9 Nov nominations close and a fuller candidate
#' list exists, to extend coverage -- that part, and only that part, needs no
#' further code change.
#'
#' **Ship decision**: Pete's explicit, contemporaneous instruction this
#' session was to ship whichever variant has the best pooled seat log loss
#' and iterate on regressions afterward, rather than waiting for every named
#' case to clear. Known, named, NOT fixed by this: SA2026 One Nation remains
#' broken (log loss 0.4536, essentially unchanged from v5's 0.4537 -- adding
#' salience features did not help this specific case, since `is_recipient`
#' still never fires for SA2026 ONP, a separate, already-documented
#' surge-hazard misattribution bug) -- this is a deliberate, informed
#' tradeoff, not an oversight. `AUSPOL_XGB_PRIMARY_LIVE` in
#' `published_flags.R` is the switch; set it back to "0" to revert to the
#' shipped-only model with no other change needed.
#'
#' @param shares The just-computed shipped-model shares matrix (seats x
#'   parties, summing to 100/row) -- becomes the `pred_share` feature.
#' @param mat22 Seat-level 2022 class shares matrix, same shape as `shares`.
#' @param a22 Named numeric vector, 2022 STATEWIDE class shares.
#' @param state_mean Named numeric vector, the forecast's statewide class
#'   shares this cycle.
#' @param returns `candidate_returns()` output, or `NULL` before vic2026
#'   nominations close (then same/same_mp default FALSE for every seat).
#' @param own_prev `personal_prior_vote()` output, or `NULL` before vic2026
#'   nominations close (then `own_prev_pcv` is NA for every row, routed by
#'   xgb's native missing-value handling, same as the backtest's treatment
#'   of thin/absent cells).
#' @param region Single string; must be one of the six regions the final
#'   model was trained on ("fed","nsw","qld","sa","vic","wa").
#' @param year Target election year, used for `load_seats(year, region)` and
#'   for identifying this election's own rows in `output/candidacies.csv`
#'   (`historic_elected`/`ballot_position`, both NA pre-nomination -- fine,
#'   same missing-value routing).
#' @param prev_year Prior election year, for the corresponding prior-year
#'   candidacy row counts.
#' @param enabled Logical; defaults to `AUSPOL_XGB_PRIMARY_LIVE` env var == "1".
#' @return The overridden shares matrix, or `shares` unchanged if not
#'   enabled or the saved model/cols files are missing.
#' @export
xgb_primary_predict_live <- function(shares, mat22, a22, state_mean, returns,
                                      own_prev = NULL, region = "vic",
                                      year = 2026L, prev_year = 2022L,
                                      enabled = NULL) {
  if (is.null(enabled)) enabled <- identical(Sys.getenv("AUSPOL_XGB_PRIMARY_LIVE", "0"), "1")
  if (!isTRUE(enabled)) return(shares)
  model_f <- "output/xgb-primary-v6-final.model"
  cols_f  <- "output/xgb-primary-v6-final-cols.json"
  if (!file.exists(model_f) || !file.exists(cols_f)) {
    cat(sprintf("XG4! %s / %s missing -- run scripts/fit_xgb_primary_v6_final.R; shares unchanged\n", model_f, cols_f))
    return(shares)
  }
  model <- xgboost::xgb.load(model_f)
  feat_cols <- jsonlite::fromJSON(readLines(cols_f))

  MAJ <- c("ALP", "LNP", "NAT")
  target_election <- sprintf("%s%d", region, year)
  prev_election    <- sprintf("%s%d", region, prev_year)
  cf <- "output/candidacies.csv"
  n_prev <- NULL; agg_now <- NULL
  if (file.exists(cf)) {
    C <- data.table::fread(cf, showProgress = FALSE)
    n_prev <- C[C$election == prev_election][, .N, by = list(seat, party)]
    # candidacy-level, aggregated to (seat, party), TARGET election only --
    # will be empty pre-nomination (same shape as the backtest's own
    # target-election aggregation in fit_xgb_primary_v5.R). `swing`
    # DELIBERATELY excluded -- it is the target election's own outcome, and
    # using it here would be the same leakage the v5 fitting script refused.
    cand_now <- C[C$election == target_election]
    if (nrow(cand_now)) {
      cand_now[, historic_elected_l := toupper(as.character(historic_elected)) %in% c("Y", "TRUE", "1")]
      agg_now <- cand_now[, list(
        historic_elected_any = any(historic_elected_l, na.rm = TRUE),
        ballot_pos_min = suppressWarnings(min(as.numeric(ballot_position), na.rm = TRUE))
      ), by = list(seat, party)]
      agg_now[!is.finite(ballot_pos_min), ballot_pos_min := NA_real_]
    }
  }

  seats <- rownames(shares); parties <- colnames(shares)
  rows <- data.table::CJ(seat = seats, party = parties, sorted = FALSE)
  rows[, pred_share := mapply(function(s, p) shares[s, p], seat, party)]
  rows[, x           := mapply(function(s, p) if (p %in% colnames(mat22)) mat22[s, p] else 0, seat, party)]
  rows[, level_prev  := vapply(party, function(p) if (p %in% names(a22)) unname(a22[[p]]) else 0, numeric(1))]
  rows[, level_now   := vapply(party, function(p) if (p %in% names(state_mean)) unname(state_mean[[p]]) else 0, numeric(1))]
  rows[, dev_prev    := x - level_prev]
  # KEY-MATCHED, NOT merge()-THEN-POSITIONAL, throughout this function.
  # data.table::merge() defaults to sort=TRUE, which returns its result
  # re-sorted by the join key -- NOT in `rows`'s original CJ(sorted=FALSE)
  # order. Assigning `rows[, col := m$col]` afterward is a POSITIONAL
  # assignment, so it silently spliced every relational feature (n_cand_prev,
  # same/same_mp, own_prev_pcv, the load_seats() block, historic_elected/
  # ballot_position, and the salience features below) onto the WRONG
  # seat/party row for every prediction -- found by review before this ever
  # ran live, reproduced directly (not just read) by the reviewing agent.
  # match() on an explicit key, subsetting by position, has no such ordering
  # assumption -- the same safe pattern already used for surge_h/is_recipient
  # further down in this function, now applied everywhere.
  key_now <- paste(rows$seat, rows$party)

  rows[, n_cand_prev := 0L]
  if (!is.null(n_prev)) {
    idx <- match(key_now, paste(n_prev$seat, n_prev$party))
    rows[, n_cand_prev := ifelse(is.na(idx), 0L, n_prev$N[idx])]
  }
  rows[, n_cand_now := 1L]   # unknown pre-nomination; matches the backtest fallback
  rows[, same_i := 0L]; rows[, same_mp_i := 0L]
  if (!is.null(returns)) {
    R <- data.table::as.data.table(returns)
    idx <- match(key_now, paste(R$seat, R$party))
    rows[, same_i := ifelse(is.na(idx), 0L, as.integer(R$same[idx]))]
    if ("same_mp" %in% names(R)) rows[, same_mp_i := ifelse(is.na(idx), 0L, as.integer(R$same_mp[idx]))]
  }
  rows[, is_major_i := as.integer(party %in% MAJ)]

  # own_prev_pcv: the identity-matched candidate's own prior share, from
  # personal_prior_vote() -- distinct from the seat/class-level `x` above.
  rows[, own_prev_pcv := NA_real_]
  if (!is.null(own_prev)) {
    OP <- data.table::as.data.table(own_prev)
    if (all(c("seat", "party", "own_prev_pcv") %in% names(OP))) {
      idx <- match(key_now, paste(OP$seat, OP$party))
      rows[, own_prev_pcv := OP$own_prev_pcv[idx]]
    }
  }

  # seat-level, from load_seats() -- absent entirely for WA (no seat-notes
  # file exists there; NA is correct, xgb routes it natively, same as the
  # backtest's treatment of this exact gap).
  rows[, `:=`(margin = NA_real_, fed_swing = NA_real_, retirement_i = NA_integer_,
              soph_cand_i = NA_integer_, soph_party_i = NA_integer_,
              prev_swing = NA_real_, is_incumbent_party_i = NA_integer_)]
  sf <- tryCatch(data.table::as.data.table(load_seats(year, region)), error = function(e) NULL)
  if (!is.null(sf) && nrow(sf)) {
    # The anchor's incumbent field distinguishes LIB/NAT/LNP where
    # classify_party() buckets all three as "LNP" -- same mapping the v5
    # fitting script uses, so retirement/soph_cand/soph_party (which
    # describe the INCUMBENT's situation) attach to the right row.
    sf[, incumbent_class := ifelse(incumbent %in% c("LIB", "NAT", "LNP"), "LNP", incumbent)]
    idx <- match(rows$seat, sf$seat)
    rows[, margin := sf$margin[idx]]
    rows[, fed_swing := sf$fed_swing[idx]]
    rows[, retirement_i := as.integer(sf$retirement[idx])]
    rows[, soph_cand_i := as.integer(sf$soph_cand[idx])]
    rows[, soph_party_i := as.integer(sf$soph_party[idx])]
    rows[, prev_swing := sf$prev_swing[idx]]
    rows[, is_incumbent_party_i := as.integer(rows$party == sf$incumbent_class[idx])]
  } else {
    cat(sprintf("XG4! load_seats(%d, %s) unavailable -- seat-file features NA for every row\n", year, region))
  }

  rows[, historic_elected_i := NA_integer_]
  rows[, ballot_pos_min := NA_real_]
  if (!is.null(agg_now)) {
    idx <- match(key_now, paste(agg_now$seat, agg_now$party))
    rows[, historic_elected_i := as.integer(agg_now$historic_elected_any[idx])]
    rows[, ballot_pos_min := agg_now$ballot_pos_min[idx]]
  }

  # SALIENCE/EMERGENCE FEATURES (v6, new vs v5): jump, governed, permit,
  # surge_h, is_recipient. Both governed_population() and surge_hazard_for()
  # need a salience corpus for the TARGET election, which does not exist for
  # vic2026 until nominations close (12 noon, 9 Nov 2026) -- SAME gap already
  # handled the identical way for arm CS/surge-v2 elsewhere in
  # fit_seats_full.R (.returns/.permit and .hz there). Falls back to the safe
  # defaults for every row until then, printed rather than silent; activates
  # automatically once vic2026's salience corpus exists, no further code
  # change needed -- see this function's own docstring for what that means
  # for the degeneracy fix specifically.
  rows[, `:=`(jump = 0, governed = 0L, permit = 1L, surge_h = 0, is_recipient = 0L)]
  sal <- tryCatch(governed_population(target_election, prev_election, region),
                   error = function(e) {
                     cat(sprintf("XG5! governed_population() FAILED for %s (not just \"no corpus yet\"): %s\n",
                                 target_election, conditionMessage(e)))
                     NULL
                   })
  if (!is.null(sal) && nrow(sal)) {
    sal[, permit_v := salience_screen(jump, governed)]
    SAL <- sal[, .(permit = as.integer(any(permit_v == 1)),
                   governed = as.integer(any(governed == 1)),
                   jump = max(jump, na.rm = TRUE)),
               by = .(seat, party)]
    idx <- match(key_now, paste(SAL$seat, SAL$party))
    rows[, jump := ifelse(is.na(idx), 0, SAL$jump[idx])]
    rows[, governed := ifelse(is.na(idx), 0L, SAL$governed[idx])]
    # "No claim" defaults to PROTECT (permit=1), not "verified safe" -- see
    # the identical fix and reasoning in scripts/fit_xgb_primary_v4.R and
    # docs/reviews/xgb-primary-flag-bugfixes-2026-09-10.md.
    rows[, permit := ifelse(is.na(idx), 1L, SAL$permit[idx])]
    cat(sprintf("XG5  salience corpus found for %s: %d of %d seat-classes matched\n",
                target_election, sum(!is.na(idx)), nrow(rows)))
  } else {
    cat(sprintf("XG5! no salience corpus yet for %s -- jump/governed/permit at safe defaults for every row\n",
                target_election))
  }
  v2_train_pairs <- list(
    list(election = "fed2010", prev = "fed2007", region = "fed"),
    list(election = "fed2013", prev = "fed2010", region = "fed"),
    list(election = "fed2016", prev = "fed2013", region = "fed"),
    list(election = "fed2019", prev = "fed2016", region = "fed"),
    list(election = "fed2022", prev = "fed2019", region = "fed"),
    list(election = "vic2022", prev = "vic2018", region = "vic"),
    list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
    list(election = "sa2026",  prev = "sa2022",  region = "sa"),
    list(election = "wa2008",  prev = "wa2005",  region = "wa"))
  hz <- tryCatch(surge_hazard_for(target_election, prev_election, region, v2_train_pairs),
                 error = function(e) {
                   cat(sprintf("XG5! surge_hazard_for() FAILED for %s (not just \"no corpus yet\"): %s\n",
                               target_election, conditionMessage(e)))
                   NULL
                 })
  if (!is.null(hz)) {
    sh <- setNames(hz$seat_hazard$surge_h, hz$seat_hazard$seat)[rows$seat]
    rows[, surge_h := ifelse(is.na(sh), 0, unname(sh))]
    if (!is.null(hz$seat_recipient)) {
      rc <- setNames(hz$seat_recipient$party, hz$seat_recipient$seat)[rows$seat]
      rows[, is_recipient := as.integer(!is.na(rc) & unname(rc) == party)]
    }
    cat(sprintf("XG5  surge hazard found for %s: %d seats\n", target_election, nrow(hz$seat_hazard)))
  } else {
    cat(sprintf("XG5! no surge hazard yet for %s -- surge_h/is_recipient at safe defaults for every row\n",
                target_election))
  }

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
  cat(sprintf("XG4  LIVE xgb v6 primary prediction ON for %s: %d seat-classes overridden\n", region, nrow(rows)))
  out
}
