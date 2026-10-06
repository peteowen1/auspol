# Breakout mixture (AUSPOL_BREAKOUT_MIX) ------------------------------------
#
# WHAT. For a non-major class the model predicts under 15% in a seat, the
# simulator draws that class's primary from a MIXTURE: with probability `p`
# (a calibrated, time-forward probability that the class breaks out to 20%+)
# its share comes from the distribution of earlier breakouts, otherwise from
# today's distribution. The other classes in the seat give up the difference
# in proportion, so every draw still sums to the same seat total.
#
# WHY A MIXTURE AND NOT A MEAN SHIFT. Measured in the proxy of
# docs/reviews/breakout-risk-design-2026-10-05.md: moving the point forecast
# by p * (breakout - pred) changed nothing (row error +0.085, SE 0.20) while
# the mixture cut seat-winner log loss by 0.030 (SE 0.012), all of it on the
# 73 non-major winners. The insurance is in the TAIL, not the centre.
#
# WHY THIS IS NOT THE REFUSED UPSET FLOOR. docs/reviews/upset-signal-2026-10-02.md:
# the floor moved a final win probability by a fitted eps for every minor
# contender. This acts on SHARES, inside each draw, only where the model is
# under 15, and the count still decides -- a breakout that falls short loses.
#
# TIME-FORWARD, BY CONSTRUCTION. For a target election T every fit here uses
# only elections dated strictly before T: the classifier, its calibration (fit
# on the classifier's own time-forward predictions for those earlier
# elections), and the breakout share distribution. Leave-one-election-out
# features (`surge_h`, `is_recipient`) are NOT used -- fit_xgb_primary_v6.R
# builds them by leaving out only the target, which still trains on later
# elections (CLAUDE.md, "Leave-one-out is NOT time-forward").
#
# Census demographics, which the design review used (54 features), are left
# out here: output/census-features.csv carries a 2016 or 2021 vintage for
# elections back to 2007, which is look-ahead, and blanking the late ones would
# make the column a label for the era (the constant-within-subgroup trap).
# So this runs on the 47 remaining features.

.BO_CLASSES   <- c("IND", "OTH", "OTH_RIGHT", "ONP")  # GRN excluded: a different phenomenon (review s.2)
.BO_HARD      <- 15    # only rows the model predicts under this get the mixture
.BO_Y         <- 20    # a "breakout" is an actual primary of at least this
.BO_MIN_POS   <- 5     # fewer earlier breakouts than this: no classifier at all
.BO_CAL_K     <- 10    # Platt calibration shrunk toward identity by npos / (npos + k)
.BO_Q_K       <- 10    # breakout quantiles shrunk toward the all-row ones by n / (n + k)
.BO_P_CAP     <- 0.5   # cap on p pending recalibration on the real simulator (review s.4)
.BO_Q_GRID    <- seq(0, 1, by = 0.01)
.BO_CACHE_VERSION <- "bo-cache-1"

.bo_memo <- new.env(parent = emptyenv())
.bo_live <- new.env(parent = emptyenv())

#' @noRd
.bo_cache_dir <- function(cache_dir = NULL) {
  if (!is.null(cache_dir)) return(cache_dir)
  e <- Sys.getenv("AUSPOL_BREAKOUT_CACHE_DIR", "")
  if (nzchar(e)) e else out_path("cache", "breakout")
}

# Same two-layer memo as .cs_cached() in R/cross_seat_vote.R: in-session
# environment, then a small RDS so the separate processes of a rebuild share
# one fit. A corrupt entry is recomputed; a failed write is reported.
#' @noRd
.bo_cached <- function(key, compute, cache_dir = NULL, disk = TRUE) {
  if (exists(key, envir = .bo_memo, inherits = FALSE)) return(get(key, envir = .bo_memo, inherits = FALSE))
  f <- file.path(.bo_cache_dir(cache_dir), paste0(key, ".rds"))
  val <- NULL
  if (disk && file.exists(f)) val <- tryCatch(readRDS(f), error = function(e) NULL)
  if (is.null(val)) {
    val <- compute()
    if (disk) tryCatch({
      dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
      tmp <- tempfile(pattern = paste0(key, "-"), tmpdir = dirname(f), fileext = ".tmp")
      saveRDS(val, tmp)
      if (!file.rename(tmp, f)) { unlink(tmp); stop("rename failed") }
    }, error = function(e) cat(sprintf("BO8! breakout cache write failed (%s): %s\n", f, conditionMessage(e))))
  }
  assign(key, val, envir = .bo_memo)
  val
}

# The CODE a cached value depends on is part of its key (the lesson .cs_fingerprint
# records): editing the fit must invalidate entries without a manual version bump.
#' @noRd
.bo_fingerprint <- function(what, frame, ...) {
  fns <- c(".bo_fit_predict", ".bo_design", ".bo_add_derived", ".bo_raw_p", "breakout_p_for",
           "breakout_share_dist", ".bo_calibrate", "election_dates")
  code <- lapply(fns, function(f) if (exists(f, mode = "function")) deparse(get(f, mode = "function")) else NULL)
  ev <- Sys.getenv(); ev <- ev[grepl("^AUSPOL_BREAKOUT_", names(ev)) & names(ev) != "AUSPOL_BREAKOUT_CACHE_DIR"]
  digest::digest(list(.BO_CACHE_VERSION, what, as.data.frame(frame), ev[order(names(ev))], code, list(...)),
                 algo = "xxhash64")
}

#' Clear the in-session breakout memo (tests and benchmarks)
#' @return Invisibly `NULL`.
#' @export
clear_breakout_cache <- function() {
  rm(list = ls(.bo_memo, all.names = TRUE), envir = .bo_memo)
  invisible(NULL)
}

# Called by xgb_primary_predict_live() with its finished feature rows, so the
# live forecast's breakout classifier sees the same pre-election features the
# xgb model did. Inert: nothing reads it unless AUSPOL_BREAKOUT_MIX is on.
#' @noRd
.bo_stash_live <- function(target_election, rows) {
  assign(target_election, data.table::copy(rows), envir = .bo_live)
  invisible(NULL)
}

#' @noRd
.bo_feature_groups <- function() {
  list(
    model_pred = c("lxp", "lxp2", "lbp"),
    salience   = c("jump", "jump_nzp", "sal_present", "governed", "permit"),
    endorse    = c("c200", "voices"),
    council    = c("council_mayor", "council_elected", "council_lost", "council_pct"),
    poll       = c("lpoll", "lpgap", "poll_days", "poll_n", "poll_present", "seat_polled"),
    prior_vote = c("lsp", "own_prev_pcv0", "seat_outperf", "historic_elected_i", "same_i", "same_mp_i",
                   "is_incumbent_party_i"),
    structure  = c("margin", "retirement_i", "ballot_pos_min", "n_cand_now", "n_cand_prev", "level_pred",
                   "level_prev", "ltm", "rank_in_seat", "dev_prev", "prev_swing"),
    context    = c("cls_IND", "cls_ONP", "cls_OTH_RIGHT",
                   "reg_fed", "reg_nsw", "reg_qld", "reg_sa", "reg_vic", "reg_wa"))
}

# Seat-poll class primaries within 120 days before each election, one row per
# (election, normalised seat, class). Same classing as the design review.
#' @noRd
.bo_seat_polls <- function(poll_file, edates) {
  if (!file.exists(poll_file)) {
    cat(sprintf("BO2! seat-poll file %s missing -- poll features NA for every row\n", poll_file))
    return(NULL)
  }
  S <- data.table::fread(poll_file, showProgress = FALSE, na.strings = c("", "NA"))
  S <- S[S$row_type == "poll" & is.finite(S$fp) & !is.na(S$fieldwork_end)]
  pu <- toupper(trimws(S$party))
  S[, cls := data.table::fifelse(pu == "ALP", "ALP",
             data.table::fifelse(pu %in% c("LIB", "NAT", "LNP", "L/NP", "CLP"), "LNP",
             data.table::fifelse(pu == "GRN", "GRN",
             data.table::fifelse(pu %in% c("ON", "ONP"), "ONP",
             data.table::fifelse(pu == "IND" | grepl("\\(IND\\)$", pu), "IND",
             data.table::fifelse(pu %in% c("UAP", "KAP"), "OTH_RIGHT", "OTH"))))))]
  ed <- edates[S$election]
  S[, days_out := as.numeric(as.Date(unname(ed)) - as.Date(fieldwork_end))]
  S <- S[is.finite(S$days_out) & S$days_out > 0 & S$days_out <= 120]
  if (!nrow(S)) return(NULL)
  S[, k := normalise_seat(seat_name)]
  S[, pid := paste(seat_name, pollster, date_raw)]
  pp <- S[, list(fp = sum(fp), days_out = days_out[1]), by = list(election, k, pid, cls)]
  pp[, list(poll_fp = mean(fp), poll_days = min(days_out), poll_n = .N), by = list(election, k, cls)]
}

# Derived features, identical for the training frame and a live target. `D`
# holds every class in each seat (rank and top-major need the majors).
#' @noRd
.bo_add_derived <- function(D, PS = NULL) {
  D[, k := normalise_seat(seat)]
  if (!is.null(PS) && nrow(PS)) {
    D[PS, `:=`(poll_fp = i.poll_fp, poll_days = i.poll_days, poll_n = i.poll_n),
      on = list(election, k, party = cls)]
    spe <- unique(PS[, list(election, k)])
    D[, seat_polled := 0L]
    D[spe, seat_polled := 1L, on = list(election, k)]
  } else {
    D[, `:=`(poll_fp = NA_real_, poll_days = NA_real_, poll_n = NA_real_, seat_polled = 0L)]
  }
  D[, poll_present := as.integer(!is.na(poll_fp))]
  D[, poll_gap := poll_fp - xgb_pred]
  # jump, governed, permit are 0/defaults where a candidate has no salience row;
  # that zero is "no data", not "no jump", so it becomes NA (the constant-within-
  # subgroup trap: a filler value would label the rows without a corpus).
  D[sal_present == 0L, c("jump", "governed", "permit") := NA]
  # Percentile of jump among NON-ZERO jumps within the election (CLAUDE.md: a
  # percentile of a mostly-tied variable reports "is this the mode?").
  D[, jump_nzp := NA_real_]
  for (e in unique(D$election)) {
    i <- which(D$election == e & is.finite(D$jump) & D$jump > 0)
    if (length(i) >= 10) data.table::set(D, i, "jump_nzp", rank(D$jump[i], ties.method = "average") / length(i))
    j <- which(D$election == e & is.finite(D$jump) & D$jump <= 0)
    if (length(j)) data.table::set(D, j, "jump_nzp", 0)
  }
  maj <- D[D$party %in% c("ALP", "LNP"), list(top_major_pred = max(xgb_pred)), by = list(election, seat)]
  D[maj, top_major_pred := i.top_major_pred, on = list(election, seat)]
  D[, rank_in_seat := data.table::frank(-xgb_pred, ties.method = "min"), by = list(election, seat)]
  D[, own_prev_pcv0 := data.table::fifelse(is.na(own_prev_pcv), 0, own_prev_pcv)]
  for (cc in c("IND", "ONP", "OTH_RIGHT")) data.table::set(D, NULL, paste0("cls_", cc), as.integer(D$party == cc))
  reg_now <- sub("[0-9]+$", "", D$election)
  for (r in c("fed", "nsw", "qld", "sa", "vic", "wa")) data.table::set(D, NULL, paste0("reg_", r), as.integer(reg_now == r))
  D[, `:=`(lxp = log1p(pmax(xgb_pred, 0)), lbp = log1p(pmax(base_pred, 0)))]
  D[, lxp2 := lxp^2]
  D[, lpoll := log1p(pmax(poll_fp, 0))]
  D[, lpgap := sign(poll_gap) * log1p(abs(poll_gap))]
  D[, lsp := log1p(pmax(seat_prev_pcv, 0))]
  D[, ltm := log1p(pmax(top_major_pred, 0))]
  for (v in unlist(.bo_feature_groups())) {
    if (!v %in% names(D)) data.table::set(D, NULL, v, NA_real_)
    if (is.logical(D[[v]])) data.table::set(D, NULL, v, as.integer(D[[v]]))
  }
  D
}

#' Build the breakout classifier's training frame from disk
#'
#' One row per (election, seat, class) for every election with an as-at
#' primary forecast, with the classifier's 47 time-forward-safe features, the
#' outcome `y` (actual primary at least 20) and whether the class actually
#' stood (`named`: a candidacy exists). Every input is pre-election
#' information except `actual_share` / `y`, which are the label.
#'
#' Sources: `output/xgb-primary-asat-predictions.csv` (the as-at model's own
#' honest prediction, `xgb_pred`), `output/xgb-primary-v6-features.csv`,
#' `output/salience-v6.csv` (whether the candidate has a salience row),
#' `output/candidacies.csv`, and
#' `external/reference/polls/seat-polls/seat_polls.csv`.
#'
#' @param out_dir Directory holding the output files. Default `out_path()`.
#' @param poll_file Seat-poll file.
#' @return A data.table.
#' @export
breakout_frame <- function(out_dir = out_path(),
                           poll_file = file.path(pkg_root(), "external", "reference", "polls",
                                                 "seat-polls", "seat_polls.csv")) {
  pf <- file.path(out_dir, "xgb-primary-asat-predictions.csv")
  ff <- file.path(out_dir, "xgb-primary-v6-features.csv")
  sf <- file.path(out_dir, "salience-v6.csv")
  cf <- file.path(out_dir, "candidacies.csv")
  for (f in c(pf, ff, sf, cf)) if (!file.exists(f)) stop("breakout_frame(): missing ", f)
  P <- data.table::fread(pf, showProgress = FALSE, na.strings = c("NA", ""))
  X <- data.table::fread(ff, showProgress = FALSE, na.strings = c("NA", ""))
  drop_x <- intersect(c("actual_share", "base_pred", "jump", "governed", "permit", "surge_h", "is_recipient"), names(X))
  X[, (drop_x) := NULL]
  P[, c("surge_h", "is_recipient") := NULL]
  D <- merge(P, X, by = c("pair", "seat", "party"), all.x = TRUE)
  if (nrow(D) != nrow(P)) stop("breakout_frame(): feature join changed the row count")
  data.table::setnames(D, "pair", "election")
  ed <- election_dates()
  D[, edate := as.Date(unname(ed[election]))]
  if (anyNA(D$edate)) stop("breakout_frame(): no election date for ", paste(unique(D$election[is.na(D$edate)]), collapse = ", "))
  SV <- data.table::fread(sf, showProgress = FALSE)
  SV <- unique(SV[, list(election, k = normalise_seat(seat), party)])
  D[, k := normalise_seat(seat)]
  D[, sal_present := 0L]
  D[SV, sal_present := 1L, on = list(election, k, party)]
  C <- data.table::fread(cf, showProgress = FALSE, select = c("election", "seat", "party"))
  C <- unique(C)
  D[, named := FALSE]
  D[C, named := TRUE, on = list(election, seat, party)]
  PS <- .bo_seat_polls(poll_file, ed)
  D <- .bo_add_derived(D, PS)
  D[, y := as.integer(actual_share >= .BO_Y)]
  data.table::setorder(D, edate, election, seat, party)
  D
}

# Feature matrix for the classifier.
#' @noRd
.bo_design <- function(D) {
  f <- unlist(.bo_feature_groups(), use.names = FALSE)
  M <- as.matrix(as.data.frame(D)[, f, drop = FALSE])
  storage.mode(M) <- "double"
  M
}

# One time-forward xgboost fit (xgb.cv with folds grouped by election, early
# stopping), predicting `te`. The global RNG is restored afterwards so turning
# the switch on does not move any random number the caller draws later.
#' @noRd
.bo_fit_predict <- function(tr, te) {
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
  on.exit(if (had_seed) assign(".Random.seed", old_seed, envir = globalenv())
          else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE))
            rm(".Random.seed", envir = globalenv()), add = TRUE)
  Xtr <- .bo_design(tr); Xte <- .bo_design(te)
  els <- unique(tr$election); kf <- min(5L, length(els))
  set.seed(1)
  folds <- if (kf >= 2L) {
    grp <- split(els, rep_len(seq_len(kf), length(els)))
    lapply(grp, function(g) which(tr$election %in% g))
  } else {
    # One earlier election only: folds by row (there is no election to hold out).
    unname(split(sample.int(nrow(tr)), rep_len(1:3, nrow(tr))))
  }
  dtr <- xgboost::xgb.DMatrix(Xtr, label = tr$y, missing = NA)
  prm <- list(objective = "binary:logistic", eta = 0.05, max_depth = 3, subsample = 0.8,
              colsample_bytree = 0.8, min_child_weight = 2, lambda = 5, eval_metric = "logloss",
              nthread = 1)
  set.seed(1)
  cv <- xgboost::xgb.cv(params = prm, data = dtr, nrounds = 300, folds = folds,
                        early_stopping_rounds = 25, verbose = 0)
  ev <- cv$evaluation_log
  nb <- max(5L, ev$iter[which.min(ev[[grep("test_logloss_mean", names(ev))]])])
  set.seed(1)
  m <- xgboost::xgb.train(params = prm, data = dtr, nrounds = nb, verbose = 0)
  list(p = as.numeric(stats::predict(m, xgboost::xgb.DMatrix(Xte, missing = NA))), nrounds = nb)
}

# Raw (uncalibrated) time-forward p for one election's rows: trained only on
# named non-major rows of elections dated strictly before `edate_t`.
#' @noRd
.bo_raw_p <- function(frame, te, edate_t) {
  tr <- frame[frame$edate < edate_t & frame$named & frame$party %in% .BO_CLASSES & is.finite(frame$y)]
  npos <- sum(tr$y)
  if (!nrow(tr) || npos < .BO_MIN_POS) return(NULL)
  r <- .bo_fit_predict(tr, te)
  list(p = r$p, nrounds = r$nrounds, n_train = nrow(tr), pos_train = npos,
       train_elections = unique(tr$election[order(tr$edate, tr$election)]))
}

# Platt calibration on logit(p), fitted on earlier elections' time-forward
# predictions for HARD rows only (the rows the mixture touches), and shrunk
# toward identity by npos / (npos + .BO_CAL_K). Returns c(a, b, w, n, npos).
#' @noRd
.bo_calibrate <- function(oof) {
  oof <- oof[is.finite(oof$p_raw) & is.finite(oof$y) & oof$xgb_pred < .BO_HARD]
  npos <- sum(oof$y)
  if (!nrow(oof) || npos < 2L) return(c(a = 0, b = 1, w = 0, n = nrow(oof), npos = npos))
  lp <- stats::qlogis(pmin(pmax(oof$p_raw, 1e-4), 1 - 1e-4))
  fit <- tryCatch(suppressWarnings(stats::glm(oof$y ~ lp, family = stats::binomial())),
                  error = function(e) NULL)
  cf <- if (is.null(fit) || !all(is.finite(stats::coef(fit)))) c(0, 1) else unname(stats::coef(fit))
  w <- npos / (npos + .BO_CAL_K)
  c(a = cf[1], b = cf[2], w = w, n = nrow(oof), npos = npos)
}

#' @noRd
.bo_apply_cal <- function(p_raw, cal) {
  lp <- stats::qlogis(pmin(pmax(p_raw, 1e-4), 1 - 1e-4))
  z <- (1 - cal[["w"]]) * lp + cal[["w"]] * (cal[["a"]] + cal[["b"]] * lp)
  pmin(stats::plogis(z), .BO_P_CAP)
}

#' Time-forward breakout probability per (seat, class) for one election
#'
#' Trains an xgboost classifier for "this class's actual primary is at least
#' 20" on every named non-major row of elections dated STRICTLY before
#' `target`, calibrates it (Platt, fitted on the same classifier's own
#' time-forward predictions for those earlier elections, hard rows only, shrunk
#' toward identity), caps it at 0.5 and predicts the target's rows. Cached per
#' target (in session and on disk; the key includes the data and the code).
#'
#' Prints `BO3` with the top ten p for the target.
#'
#' @param target Election label, e.g. `"fed2019"` or `"vic2026"`.
#' @param frame From [breakout_frame()]; built (and memoised) when `NULL`.
#' @param live_rows For an election not in `frame` (the live forecast): its
#'   feature rows. Defaults to the rows `xgb_primary_predict_live()` stashed.
#' @param cache_dir,disk Cache location and whether to use the disk layer.
#' @return data.table `seat, party, xgb_pred, p_raw, p`, with attributes
#'   `calibration` and `train_elections`; `NULL` when fewer than five earlier
#'   breakouts exist.
#' @export
breakout_p_for <- function(target, frame = NULL, live_rows = NULL, cache_dir = NULL, disk = TRUE) {
  tgt <- target
  if (is.null(frame)) frame <- .bo_frame_cached(cache_dir)
  ed <- election_dates()
  edate_t <- if (tgt %in% frame$election) frame$edate[match(tgt, frame$election)] else as.Date(unname(ed[tgt]))
  if (is.na(edate_t)) stop("breakout_p_for(): no date for ", tgt)
  fp <- .bo_fingerprint("frame", frame)
  # Raw time-forward p for every EARLIER election (the calibration set), each
  # from its own strictly-earlier fit.
  earlier <- unique(frame[frame$edate < edate_t, list(election, edate)])
  data.table::setorder(earlier, edate)
  # Every non-major row of election `el` (named or not), predicted by the fit on
  # elections strictly before it. One cache entry per election, shared by its
  # role as a calibration election and as a target.
  raw_one <- function(el) {
    te_el <- frame[frame$election == el & frame$party %in% .BO_CLASSES]
    r_el <- .bo_cached(paste0("raw-", el, "-", fp), function() {
      x <- .bo_raw_p(frame, te_el, te_el$edate[1])
      if (is.null(x)) list(none = TRUE) else x
    }, cache_dir, disk)
    list(te = te_el, r = r_el)
  }
  oof <- data.table::rbindlist(lapply(earlier$election, function(el) {
    o <- raw_one(el)
    if (isTRUE(o$r$none)) return(NULL)
    keep <- o$te$named
    data.table::data.table(election = el, seat = o$te$seat[keep], party = o$te$party[keep],
                           xgb_pred = o$te$xgb_pred[keep], y = o$te$y[keep], p_raw = o$r$p[keep])
  }))
  cal <- if (nrow(oof)) .bo_calibrate(oof) else c(a = 0, b = 1, w = 0, n = 0, npos = 0)
  # The target's own rows and raw p.
  if (tgt %in% frame$election) {
    o <- raw_one(tgt); te <- o$te; r <- o$r
  } else {
    if (is.null(live_rows)) live_rows <- get0(tgt, envir = .bo_live, inherits = FALSE)
    if (is.null(live_rows)) stop("breakout_p_for(): ", tgt, " has no rows on disk and no live rows ",
                                 "(xgb_primary_predict_live() stashes them; is AUSPOL_XGB_PRIMARY_LIVE on?)")
    te <- .bo_live_frame(live_rows, tgt, edate_t, frame)
    te <- te[te$party %in% .BO_CLASSES]
    r <- .bo_raw_p(frame, te, edate_t)
    if (is.null(r)) r <- list(none = TRUE)
  }
  if (isTRUE(r$none)) {
    cat(sprintf("BO3! %s: fewer than %d breakouts in earlier elections -- no breakout p\n", tgt, .BO_MIN_POS))
    return(NULL)
  }
  out <- data.table::data.table(seat = te$seat, party = te$party, xgb_pred = te$xgb_pred,
                                p_raw = r$p, p = .bo_apply_cal(r$p, cal))
  if (any(!is.finite(out$p)) || any(out$p < 0 | out$p > 1)) stop("breakout_p_for(): p outside [0, 1]")
  attr(out, "calibration") <- cal
  attr(out, "train_elections") <- r$train_elections
  cat(sprintf("BO3  %s: classifier on %d rows / %d breakouts from %d earlier elections (%s .. %s), %d rounds; calibration a=%.2f b=%.2f w=%.2f (%d hard rows, %d breakouts)\n",
              tgt, r$n_train, r$pos_train, length(r$train_elections), r$train_elections[1],
              utils::tail(r$train_elections, 1), r$nrounds, cal[["a"]], cal[["b"]], cal[["w"]],
              as.integer(cal[["n"]]), as.integer(cal[["npos"]])))
  # The rows the mixture can touch (predicted under 15) are the ones worth reading.
  hard <- out[is.finite(out$xgb_pred) & out$xgb_pred < .BO_HARD]
  top <- hard[order(-hard$p)][seq_len(min(10L, nrow(hard)))]
  cat(sprintf("BO3  %s top p among rows predicted under %d: %s\n", tgt, .BO_HARD,
              paste(sprintf("%s %s %.3f (pred %.1f)", top$seat, top$party, top$p, top$xgb_pred), collapse = "; ")))
  out
}

# Live target rows -> the training frame's columns (salience presence and the
# derived features). Seat polls are read for the target exactly as for training.
#' @noRd
.bo_live_frame <- function(live_rows, tgt, edate_t, frame) {
  L <- data.table::copy(data.table::as.data.table(live_rows))
  L[, election := tgt]
  L[, edate := edate_t]
  if (!"sal_present" %in% names(L)) L[, sal_present := if ("bo_sal_row" %in% names(L)) as.integer(bo_sal_row) else 0L]
  L[, named := TRUE]
  L[, y := NA_integer_]
  ed <- election_dates()
  PS <- .bo_seat_polls(file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv"), ed)
  .bo_add_derived(L, PS)
}

#' @noRd
.bo_frame_cached <- function(cache_dir = NULL) {
  out_dir <- out_path()
  srcs <- file.path(out_dir, c("xgb-primary-asat-predictions.csv", "xgb-primary-v6-features.csv",
                               "salience-v6.csv", "candidacies.csv"))
  srcs <- c(srcs, file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv"))
  key <- paste0("frame-", digest::digest(list(.BO_CACHE_VERSION, unname(tools::md5sum(srcs[file.exists(srcs)])),
                                             deparse(breakout_frame), deparse(.bo_add_derived)), algo = "xxhash64"))
  .bo_cached(key, function() breakout_frame(out_dir), cache_dir, disk = FALSE)
}

#' Time-forward breakout share distribution
#'
#' Quantiles (0, 0.01, ..., 1) of the actual primary of earlier BREAKOUTS:
#' rows the model predicted under 15 that reached 20 or more, from elections
#' dated strictly before `target`. Shrunk, quantile by quantile, toward the
#' same quantiles over every earlier breakout (any prediction) by weight
#' `n / (n + 10)`, so a thin early set degrades toward the broader one rather
#' than falling off a cliff.
#'
#' @param target Election label.
#' @param frame From [breakout_frame()].
#' @return Numeric vector of 101 quantiles (percent), with attributes `n_hard`,
#'   `n_all`, `w` and `elections`; `NULL` when there is no earlier breakout.
#' @export
breakout_share_dist <- function(target, frame = NULL) {
  tgt <- target
  if (is.null(frame)) frame <- .bo_frame_cached()
  ed <- election_dates()
  edate_t <- if (tgt %in% frame$election) frame$edate[match(tgt, frame$election)] else as.Date(unname(ed[tgt]))
  B <- frame[frame$edate < edate_t & frame$party %in% .BO_CLASSES & is.finite(frame$actual_share) &
               frame$actual_share >= .BO_Y]
  if (!nrow(B)) return(NULL)
  hard <- B$actual_share[B$xgb_pred < .BO_HARD]
  q_all <- unname(stats::quantile(B$actual_share, .BO_Q_GRID, type = 7))
  w <- length(hard) / (length(hard) + .BO_Q_K)
  q <- if (length(hard)) w * unname(stats::quantile(hard, .BO_Q_GRID, type = 7)) + (1 - w) * q_all else q_all
  q <- pmin(cummax(q), 99)
  attr(q, "n_hard") <- length(hard); attr(q, "n_all") <- nrow(B); attr(q, "w") <- w
  attr(q, "elections") <- unique(B$election[order(B$edate, B$election)])
  q
}

#' Simulator inputs for the breakout mixture (AUSPOL_BREAKOUT_MIX)
#'
#' The one call every harness and `fit_seats_full.R` make before
#' [simulate_seat_contests()]. With the switch at `"0"` (the default) it returns
#' `list(p = NULL, q = NULL)` without reading anything, which the simulator
#' treats as byte-identical to not passing them.
#'
#' With `"1"`: `p` is a matrix the shape of `shares` holding the calibrated
#' time-forward breakout probability for every non-major class (`IND`, `OTH`,
#' `OTH_RIGHT`, `ONP`) whose share in `shares` is above 0 and under 15, and 0
#' everywhere else; `q` is [breakout_share_dist()] for the target.
#'
#' @param target Election label of the contest being simulated.
#' @param shares The seats x classes matrix about to be simulated.
#' @param enabled Defaults to `AUSPOL_BREAKOUT_MIX == "1"`.
#' @param frame Optional [breakout_frame()] (tests).
#' @return `list(p, q)`.
#' @export
breakout_mix_args <- function(target, shares, enabled = NULL, frame = NULL) {
  if (is.null(enabled)) {
    mode <- Sys.getenv("AUSPOL_BREAKOUT_MIX", "0")
    if (!mode %in% c("0", "1")) stop("AUSPOL_BREAKOUT_MIX must be \"0\" or \"1\"; got \"", mode, "\"")
    enabled <- identical(mode, "1")
  }
  if (!isTRUE(enabled)) return(list(p = NULL, q = NULL))
  sh <- as.matrix(shares)
  P <- breakout_p_for(target, frame = frame)
  q <- breakout_share_dist(target, frame = frame)
  if (is.null(P) || is.null(q)) {
    cat(sprintf("BO1! %s: breakout mixture requested but no p or no breakout distribution -- mixture OFF for this pair\n", target))
    return(list(p = NULL, q = NULL))
  }
  pm <- base::matrix(0, nrow(sh), ncol(sh), dimnames = dimnames(sh))
  ri <- match(P$seat, rownames(sh)); ci <- match(P$party, colnames(sh))
  ok <- !is.na(ri) & !is.na(ci)
  pm[cbind(ri[ok], ci[ok])] <- P$p[ok]
  elig <- base::matrix(colnames(sh) %in% .BO_CLASSES, nrow(sh), ncol(sh), byrow = TRUE) & sh > 0 & sh < .BO_HARD
  pm[!elig] <- 0
  n_el <- sum(elig); n_p <- sum(pm > 0)
  cat(sprintf("BO1  %s breakout mixture ON: %d of %d eligible cells carry p (sum %.2f, max %.3f); %d of %d classifier rows matched a share cell; breakout q50 %.1f, q90 %.1f (n_hard %d, w %.2f)\n",
              target, n_p, n_el, sum(pm), max(pm), sum(ok), nrow(P), q[51], q[91],
              attr(q, "n_hard"), attr(q, "w")))
  list(p = pm, q = as.numeric(q))
}
