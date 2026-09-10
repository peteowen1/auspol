#' Build an xgb-flows-v1 conditional flow list for one target election
#'
#' Experimental, gated behind `AUSPOL_XGB_FLOWS` -- see
#' `scripts/fit_xgb_flows_v1.R` and `docs/plans/prereg-xgb-flows-v1-2026-09-10.md`.
#'
#' Predicts a replacement for `build_flow_matrix()`'s `conditional` list,
#' keyed identically (`"FROM|A+B+C"`), so it substitutes directly into an
#' existing `fm` object without touching `distribute_preferences()` or the
#' simulator. Enumerates every (from, survivor-set) key already observed
#' anywhere in the historical corpus (not per-seat -- `distribute_preferences()`
#' shares one conditional list across every seat in a simulation run, so a
#' genuinely per-seat prediction would need a core-engine change; this
#' substitutes a statewide-average version of the seat-level features
#' `fit_xgb_flows_v1.R` used, which is the honest simplification for this
#' first wired version, not a silent one).
#'
#' @param target_election,prev_election,region As elsewhere in this package.
#' @param min_events Only emit a key if the historical corpus has at least
#'   this many events for it (matches `build_flow_matrix()`'s own `min_n`
#'   default) -- below that, return nothing for the key and let the caller's
#'   existing `pooled` fallback handle it, same failure-open behaviour as the
#'   shipped mechanism.
#' @return A named list, same shape as `build_flow_matrix()$conditional`, or
#'   `NULL` if the model files are missing or nothing could be built.
#' @export
xgb_flow_conditional_for <- function(target_election, prev_election, region, min_events = 3L) {
  # Same leave-one-election-out rule as the per-seat version below -- see its
  # comment for why the all-data model is a leaked backtest.
  loo_f   <- sprintf("output/xgb-flows-v1-loo-%s.model", target_election)
  model_f <- if (file.exists(loo_f)) loo_f else "output/xgb-flows-v1-final.model"
  if (!identical(model_f, loo_f))
    cat(sprintf("XF9! %s not found -- falling back to the ALL-DATA model, which SAW %s in training. This arm is LEAKED; run scripts/fit_xgb_flows_loo.R.\n",
                loo_f, target_election))
  cols_f  <- "output/xgb-flows-v1-final-cols.json"
  if (!file.exists(model_f) || !file.exists(cols_f)) {
    cat(sprintf("XF9! %s / %s missing -- run scripts/fit_xgb_flows_v1.R; AUSPOL_XGB_FLOWS ignored\n", model_f, cols_f))
    return(NULL)
  }
  feat_f <- "output/xgb-flows-v1-features.csv"
  if (!file.exists(feat_f)) {
    cat(sprintf("XF9! %s missing -- run scripts/fit_xgb_flows_v1.R; AUSPOL_XGB_FLOWS ignored\n", feat_f))
    return(NULL)
  }
  model <- xgboost::xgb.load(model_f)
  feat_cols <- jsonlite::fromJSON(readLines(cols_f))
  TR <- data.table::fread(feat_f, showProgress = FALSE)
  # LEAVE THE TARGET ELECTION OUT of the historical rate/n computation, same
  # discipline as the training script's own leave-one-election-out CV.
  hist <- TR[TR$election != target_election]

  CLASSES <- c("ALP","GRN","IND","LNP","NAT","ONP","OTH","OTH_RIGHT")
  # Event-count-weighted mean of the observed share across every historical
  # occurrence of this (from,surv,to) key EXCLUDING the target election
  # (`hist` already filters that out). Not a fresh vote-weighted recompute --
  # an acceptable proxy for this first wired version, noted honestly rather
  # than presented as exact.
  key_rates <- hist[, list(rate = stats::weighted.mean(get("y"), w = pmax(1, get("cond_n"))),
                            n = data.table::uniqueN(paste(get("election"), get("seat"), get("round")))),
                     by = c("from","surv","to")]
  key_n <- hist[, list(n_cell = data.table::uniqueN(paste(get("election"), get("seat"), get("round")))),
                by = c("from","surv")]
  key_rates <- merge(key_rates, key_n, by = c("from","surv"), all.x = TRUE)
  key_rates <- key_rates[key_rates$n_cell >= min_events]
  if (!nrow(key_rates)) {
    cat("XF9! no historical cell clears min_events -- AUSPOL_XGB_FLOWS produced nothing, fallback pooled unaffected\n")
    return(NULL)
  }

  # Statewide-average primary shares for the TARGET election, as a
  # (deliberately not per-seat) proxy for to_primary/from_primary.
  cf <- "output/candidacies.csv"
  state_share <- stats::setNames(rep(0, length(CLASSES)), CLASSES)
  if (file.exists(cf)) {
    C <- data.table::fread(cf, showProgress = FALSE)
    Ct <- C[C$election == target_election]
    if (nrow(Ct)) {
      tot <- sum(Ct$pcv[Ct$party %in% CLASSES], na.rm = TRUE)
      st <- Ct[, list(v = sum(pcv, na.rm = TRUE)), by = party]
      for (i in seq_len(nrow(st))) if (st$party[i] %in% CLASSES) state_share[[st$party[i]]] <- 100 * st$v[i] / tot
    }
  }
  region_levels <- c("fed","nsw","qld","sa","vic","wa")

  out <- list()
  for (k in seq_len(nrow(key_rates))) {
    from <- key_rates$from[k]; surv_str <- key_rates$surv[k]
    surv <- strsplit(surv_str, "+", fixed = TRUE)[[1]]
    if (length(surv) < 2L) next
    rows <- data.table::data.table(to = surv)
    rows[, `:=`(cond_rate = key_rates$rate[k], cond_n = key_rates$n_cell[k],
                pool_rate = key_rates$rate[k], pool_n = key_rates$n_cell[k],
                n_survivors = length(surv), dest_same = 0L, dest_same_mp = 0L)]
    rows[, to_primary := vapply(to, function(p) if (p %in% names(state_share)) state_share[[p]] else 0, numeric(1))]
    rows[, from_primary := if (from %in% names(state_share)) state_share[[from]] else 0]
    for (cl in CLASSES) rows[[paste0("surv_", cl)]] <- as.integer(cl %in% surv)
    for (cl in CLASSES) rows[[paste0("from_", cl)]] <- as.integer(from == cl)
    for (cl in CLASSES) rows[[paste0("to_", cl)]]   <- as.integer(rows$to == cl)
    for (r in region_levels) rows[[paste0("region_", r)]] <- as.integer(region == r)
    miss <- setdiff(feat_cols, names(rows))
    if (length(miss)) next
    X <- as.matrix(rows[, ..feat_cols])
    pred <- pmax(0, predict(model, X))
    if (sum(pred) <= 0) next
    share <- 100 * pred / sum(pred)
    out[[paste0(from, "|", surv_str)]] <- stats::setNames(share, surv)
  }
  cat(sprintf("XF9  xgb flows conditional built for %s: %d key(s) (min_events=%d)\n",
              target_election, length(out), min_events))
  if (!length(out)) return(NULL)
  out
}

#' Build a PER-SEAT xgb-flows-v1 conditional override list
#'
#' The real per-seat version of [xgb_flow_conditional_for()] -- built after
#' review found the statewide-average version could never be a fair test of
#' a model whose own training used each seat's OWN primary shares as a
#' feature. Returns one conditional dict per seat, keyed to
#' `simulate_seat_contests()`'s new `conditional_override` parameter
#' (`R/seat_sim.R`), which consults each seat's own dict before falling back
#' to the shared `matrix$conditional` table -- see that parameter's own
#' docs for exactly where in the simulation this is consulted.
#'
#' @param shares Seats x parties numeric matrix -- the SAME shares matrix
#'   passed to `simulate_seat_contests()`, so each seat's own actual primary
#'   shares become the `to_primary`/`from_primary` features, not a
#'   statewide average.
#' @inheritParams xgb_flow_conditional_for
#' @return A list, one entry per `rownames(shares)`, each `NULL` or a named
#'   list of named numeric vectors in `build_flow_matrix()$conditional`'s
#'   own shape -- pass directly as `simulate_seat_contests(...,
#'   conditional_override = this)`.
#' @export
xgb_flow_conditional_override_for <- function(shares, target_election, prev_election, region, min_events = 3L) {
  # THE MODEL MUST NOT HAVE SEEN THIS ELECTION. `xgb-flows-v1-final.model` is
  # trained on every election including the target -- fit_xgb_flows_v1.R's CV
  # number is leave-one-election-out but the artifact it saves is not, and
  # until 2026-09-11 this function loaded that artifact. Holding the target out
  # of the rate FEATURES below does not undo weights fitted on its own labels.
  # scripts/fit_xgb_flows_loo.R writes one model per held-out election; prefer
  # it, and say loudly when falling back, because a silent fallback is a
  # leaked backtest that reads as a good result.
  loo_f   <- sprintf("output/xgb-flows-v1-loo-%s.model", target_election)
  cols_f  <- "output/xgb-flows-v1-final-cols.json"
  feat_f  <- "output/xgb-flows-v1-features.csv"
  model_f <- if (file.exists(loo_f)) loo_f else "output/xgb-flows-v1-final.model"
  if (identical(model_f, loo_f)) {
    cat(sprintf("XF9  leave-one-election-out flow model for %s: %s\n", target_election, loo_f))
  } else {
    # NOT EVERY MISSING LOO MODEL IS A LEAK. An election with no transfer file
    # of its own -- wa2001 is the standing example, excluded upstream -- never
    # enters the training corpus, so the all-data model has not seen it and no
    # per-election model was ever written for it. Crying "LEAKED" there trains
    # the reader to ignore the warning in the case that IS one, so check the
    # corpus before choosing which thing to say.
    in_corpus <- tryCatch({
      if (!file.exists(feat_f)) NA
      else target_election %in% unique(data.table::fread(feat_f, select = "election",
                                                          showProgress = FALSE)$election)
    }, error = function(e) NA)
    if (isTRUE(in_corpus)) {
      cat(sprintf("XF9! %s not found and %s IS in the training corpus -- falling back to the ALL-DATA model, which SAW it. This arm is LEAKED; run scripts/fit_xgb_flows_loo.R before quoting any number from it.\n",
                  loo_f, target_election))
    } else {
      cat(sprintf("XF9  %s is not in the flow training corpus (no transfer file of its own), so no held-out model exists and the all-data model has not seen it -- using it is correct here, not leakage.\n",
                  target_election))
    }
  }
  if (!file.exists(model_f) || !file.exists(cols_f) || !file.exists(feat_f)) {
    cat(sprintf("XF9! model/cols/features file missing -- run scripts/fit_xgb_flows_v1.R; AUSPOL_XGB_FLOWS per-seat override skipped\n"))
    return(NULL)
  }
  model <- xgboost::xgb.load(model_f)
  feat_cols <- jsonlite::fromJSON(readLines(cols_f))
  TR <- data.table::fread(feat_f, showProgress = FALSE)
  hist <- TR[TR$election != target_election]

  CLASSES <- c("ALP","GRN","IND","LNP","NAT","ONP","OTH","OTH_RIGHT")
  key_rates <- hist[, list(rate = stats::weighted.mean(get("y"), w = pmax(1, get("cond_n"))),
                            n = data.table::uniqueN(paste(get("election"), get("seat"), get("round")))),
                     by = c("from","surv","to")]
  key_n <- hist[, list(n_cell = data.table::uniqueN(paste(get("election"), get("seat"), get("round")))),
                by = c("from","surv")]
  key_rates <- merge(key_rates, key_n, by = c("from","surv"), all.x = TRUE)
  key_rates <- key_rates[key_rates$n_cell >= min_events]
  key_rates <- key_rates[lengths(strsplit(key_rates$surv, "+", fixed = TRUE)) >= 2L]
  if (!nrow(key_rates)) {
    cat("XF9! no historical cell clears min_events -- AUSPOL_XGB_FLOWS per-seat override produced nothing\n")
    return(NULL)
  }
  region_levels <- c("fed","nsw","qld","sa","vic","wa")

  seats <- rownames(shares)
  if (is.null(seats)) { cat("XF9! shares has no rownames -- cannot build per-seat override\n"); return(NULL) }

  # THE PERSONAL-VOTE FEATURES, ACTUALLY POPULATED. Until 2026-09-11 both were
  # hardcoded to 0 for every inference row while the model was TRAINED on real
  # values (scripts/fit_xgb_flows_v1.R section 5) -- so the two features the
  # pre-registration named as the reason Kiama should work were dead at the
  # only point they mattered. Not leakage: nominations close before polling
  # day, so who is re-standing where is knowable in advance, and the training
  # script derives them the same way from the same pair.
  ret_key <- character(0); ret_same <- integer(0); ret_same_mp <- integer(0)
  ret <- tryCatch(candidate_returns(prev_election, target_election),
                  error = function(e) { cat(sprintf("XF9! candidate_returns(%s, %s) failed: %s -- dest_same/dest_same_mp stay 0\n", prev_election, target_election, conditionMessage(e))); NULL })
  if (!is.null(ret) && nrow(ret)) {
    ret <- data.table::as.data.table(ret)
    ret_key     <- paste(normalise_seat(ret$seat), ret$party)
    ret_same    <- ifelse(is.na(ret$same), 0L, as.integer(ret$same))
    ret_same_mp <- ifelse(is.na(ret$same_mp), 0L, as.integer(ret$same_mp))
    dup <- duplicated(ret_key)
    if (any(dup)) { ret_key <- ret_key[!dup]; ret_same <- ret_same[!dup]; ret_same_mp <- ret_same_mp[!dup] }
  }
  seat_norm <- normalise_seat(seats)

  # ONE BATCH, every (seat x key x destination) row, ONE predict() call --
  # not a per-seat model reload/loop, which would be needlessly slow for
  # 50-150 seats x ~100+ keys.
  rows_list <- vector("list", length(seats))
  for (si in seq_along(seats)) {
    sh <- shares[si, ]
    R <- key_rates[, list(from, surv, to, cond_rate = rate, cond_n = n_cell,
                           pool_rate = rate, pool_n = n_cell)]
    R[, seat_i := si]
    R[, n_survivors := lengths(strsplit(surv, "+", fixed = TRUE))]
    # match() on a pre-built key vector, NOT merge()-then-positional-assign:
    # data.table::merge() sorts by default, so a positional re-assignment after
    # it splices features onto the wrong rows. Same fix as the six in
    # R/xgb_primary_override.R.
    if (length(ret_key)) {
      ri <- match(paste(seat_norm[si], R$to), ret_key)
      R[, `:=`(dest_same    = ifelse(is.na(ri), 0L, ret_same[ri]),
               dest_same_mp = ifelse(is.na(ri), 0L, ret_same_mp[ri]))]
    } else {
      R[, `:=`(dest_same = 0L, dest_same_mp = 0L)]
    }
    R[, to_primary := vapply(to, function(p) if (p %in% names(sh)) unname(sh[[p]]) else 0, numeric(1))]
    R[, from_primary := vapply(from, function(p) if (p %in% names(sh)) unname(sh[[p]]) else 0, numeric(1))]
    rows_list[[si]] <- R
  }
  ALLR <- data.table::rbindlist(rows_list)
  # COVERAGE, not presence. A feature that is present, correctly typed and 0%
  # populated is exactly the failure this replaced, and it passed every other
  # check for a day. Print the rate so a silent reversion is visible.
  cat(sprintf("XF9  dest_same populated on %d of %d rows (%.1f%%), dest_same_mp on %d (%.1f%%)\n",
              sum(ALLR$dest_same == 1L), nrow(ALLR), 100 * mean(ALLR$dest_same == 1L),
              sum(ALLR$dest_same_mp == 1L), 100 * mean(ALLR$dest_same_mp == 1L)))
  if (length(ret_key) && !any(ALLR$dest_same == 1L)) {
    cat(sprintf("XF9! dest_same is 0 on every row although candidate_returns() gave %d keys -- the seat/party join found nothing; check seat naming between shares rownames and output/candidacies.csv\n", length(ret_key)))
  }
  for (cl in CLASSES) ALLR[[paste0("surv_", cl)]] <- as.integer(mapply(function(s) cl %in% strsplit(s, "+", fixed = TRUE)[[1]], ALLR$surv))
  for (cl in CLASSES) ALLR[[paste0("from_", cl)]] <- as.integer(ALLR$from == cl)
  for (cl in CLASSES) ALLR[[paste0("to_",   cl)]] <- as.integer(ALLR$to   == cl)
  for (r in region_levels) ALLR[[paste0("region_", r)]] <- as.integer(region == r)
  miss <- setdiff(feat_cols, names(ALLR))
  if (length(miss)) {
    cat(sprintf("XF9! feature mismatch, missing: %s -- per-seat override skipped\n", paste(miss, collapse=",")))
    return(NULL)
  }
  X <- as.matrix(ALLR[, ..feat_cols])
  pred <- pmax(0, predict(model, X))
  ALLR[, pred := pred]

  out <- vector("list", length(seats)); names(out) <- seats
  for (si in seq_along(seats)) {
    seat_rows <- ALLR[ALLR$seat_i == si]
    if (!nrow(seat_rows)) next
    seat_out <- list()
    for (ky in unique(paste0(seat_rows$from, "|", seat_rows$surv))) {
      sub <- seat_rows[paste0(seat_rows$from, "|", seat_rows$surv) == ky]
      if (sum(sub$pred) <= 0) next
      seat_out[[ky]] <- stats::setNames(100 * sub$pred / sum(sub$pred), sub$to)
    }
    if (length(seat_out)) out[[si]] <- seat_out
  }
  n_built <- sum(!vapply(out, is.null, logical(1)))
  cat(sprintf("XF9  per-seat xgb flows override built for %s: %d of %d seats, %d key(s) each (min_events=%d)\n",
              target_election, n_built, length(seats), nrow(key_rates), min_events))
  if (n_built == 0L) return(NULL)
  out
}
