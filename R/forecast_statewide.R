#' Build a FORECAST statewide for one backtest pair, from polls only
#'
#' The statewide vote a harness swings its seats toward, predicted from the poll
#' trend and leave-one-out fundamentals instead of read off the election being
#' predicted.
#'
#' WHY THIS EXISTS. Every backtest in this repo takes its statewide target from
#' `st_b` -- the target election's own counted result. The federal harness's
#' banner calls that "this harness's whole design"; Pete's ruling on 2026-09-11
#' is that it is leakage, because the thing being built is a forecast:
#' *"everything for an election forecast shold be predictive"*. He is right, and
#' the framing as a deliberate design choice was mine, never his.
#'
#' `backtest_candidate_fed.R` already had an honest path behind
#' `AUSPOL_FORECAST_MODE`, and it is ~250 lines carrying two fixes that cost
#' real money to find. Copy-pasting it into five more harnesses is how those get
#' lost, so the core is here, once.
#'
#' THE FIX THIS FUNCTION EXISTS TO PRESERVE. A class with no poll series -- IND
#' always, because no pollster publishes an independent voting-intention figure
#' -- has no forecast level of its own, only a share of the fitted OTH. DELETING
#' it, which the federal harness once did, removes the class from the simulation
#' entirely, so no seat can ever return "IND wins" however safe. Measured:
#' fed2025 forecast-mode log loss 1.2914, **71.8% of it from ten sitting
#' independents scoring exactly zero** -- not unlikely, structurally impossible.
#' So a folded class is RESCALED into the bucket, never dropped, and gets its
#' own draw column split from OTH's by the prior election's ratio, which keeps
#' its uncertainty correlated with OTH rather than invented.
#'
#' NOT PORTED, deliberately, and still federal-only: `AUSPOL_IND_TREND` (a
#' fitted drift for folded classes, off by default) and `AUSPOL_MINOR_POLL_ADJ`
#' (minor-party poll overstatement, off by default). Both are optional arms that
#' sit on top of this core; moving them needs its own measurement per region and
#' they are off in the published configuration. A harness calling this function
#' gets the core and not those, which is why this says so rather than leaving
#' the gap silent.
#'
#' @param region One of `"fed"`, `"nsw"`, `"qld"`, `"sa"`, `"vic"`, `"wa"`.
#' @param year The target election year.
#' @param election_date The polling day, as a `Date` or a parseable string.
#' @param parties Character vector of the classes the simulation carries.
#' @param st_a Named numeric, the PRIOR election's statewide percentages. Used
#'   only to split a folded class out of OTH by its previous share.
#' @param fund_loo A `data.table` of `year`, `region`, `fund` -- the
#'   leave-one-out fundamentals prediction. Fitting on every election and then
#'   predicting one of them leaks that election's result through the prior,
#'   which is the same leak as using its polls.
#' @param mix The projection-mix table (`output/projection-mix.csv`).
#' @param n_sims,seed Passed through to [statewide_draws_as_at()].
#' @return A list: `st_fc` (named numeric, the forecast statewide level),
#'   `draws` (n_sims x length(parties) matrix), `folded`, `n_polls`, `tpp`,
#'   `fund`, `anchor_mean`, `implied_tpp`. Stops rather than returning `NULL`
#'   when no trend can be fitted -- a thin cycle must be reported, not silently
#'   scored as though the forecast had succeeded.
#' @export
forecast_statewide_for <- function(region, year, election_date, parties, st_a,
                                   fund_loo, mix, n_sims = 20000L, seed = NULL) {
  ed <- tryCatch(as.Date(election_date), error = function(e) as.Date(NA))
  if (!is.finite(ed)) stop("forecast_statewide_for(): unparseable election_date for ", region, year)
  # NINTH instance of the data.table NSE trap (CLAUDE.md keeps the count).
  # `year` and `region` are both arguments here AND columns of `fund_loo`, and
  # data.table scopes the table's columns into the WHOLE `i` expression -- so
  # `fund_loo$year == year` resolved to `fund_loo$year == fund_loo$year`,
  # always TRUE, returned every row, and the length-1 guard below fired with a
  # message about leakage that had nothing to do with the actual fault.
  # Qualifying the LEFT side with `$` does not help; only differently-named
  # locals do.
  year_arg <- year; region_arg <- region
  fr <- fund_loo[fund_loo$year == year_arg & fund_loo$region == region_arg, ]$fund
  if (length(fr) != 1L || !is.finite(fr)) {
    stop("No leave-one-out fundamentals prediction for ", region, year,
         ". Anchoring to a projection built on this election's own result ",
         "would be the same leak as using its polls.", call. = FALSE)
  }
  # One day out. project_result() blends trend and fundamentals BY HORIZON, so
  # the horizon has to be the real one rather than a convenient default.
  tpp_fn <- function(trend_tpp) {
    pj <- project_result(trend_tpp, fr, mix, horizon = 1L)
    list(mean = pj$mean, sd = pj$sd)
  }
  FC <- statewide_draws_as_at(region, year, as_at = ed - 1, election_date = ed,
                              parties = parties, n_sims = n_sims, seed = seed,
                              tpp_target = tpp_fn)
  if (is.null(FC)) {
    stop("No trend could be fitted for ", region, year, " at ", as.character(ed - 1),
         ". A thin cycle must be reported, not silently scored as if the ",
         "forecast had succeeded.", call. = FALSE)
  }

  sw_draws <- FC$draws
  st_fc <- colMeans(sw_draws)
  unmodelled <- character(0)
  if (length(FC$folded) && "OTH" %in% parties) {
    unmodelled <- FC$folded
    bucket <- c(unmodelled, "OTH")
    # A FOLDED CLASS MAY NOT HAVE CONTESTED THE PRIOR ELECTION, so it has no
    # prior share to split by. `st_a[name]` on a named vector returns NA for a
    # missing name (never an error -- `[[` would throw, which is the documented
    # trap), and NA then propagates through the ratio into the draws and out to
    # a statewide summing to NA. Caught by testing vic2022, where One Nation is
    # folded and did not stand in vic2018: ONP came back NA and the whole
    # statewide with it. Treat an absent prior as zero share, and if the entire
    # bucket is absent fall back to an equal split rather than dividing by nil.
    prior <- vapply(bucket, function(p) {
      v <- st_a[p]
      if (length(v) != 1L || !is.finite(v)) 0 else unname(v)
    }, numeric(1))
    base_share <- sum(prior)
    ratio <- stats::setNames(
      if (isTRUE(base_share > 0)) prior / base_share
      else rep(1 / length(bucket), length(bucket)),
      bucket)
    # AUSPOL_BUCKET_SPLIT = cand_resid / cand_naive: split the bucket by the
    # per-candidate model's predicted class shares for THIS election instead of
    # the previous election's mix (the bucket's total is unchanged). Each share
    # comes from a model fitted on earlier elections only
    # (scripts/fit_minor_candidates.R, MC2). Any bucket class without a
    # prediction falls back to the prior-ratio split for the whole pair.
    # docs/plans/prereg-bucket-split-candidates-2026-09-28.md.
    cr <- candidate_bucket_ratio(paste0(region, year), bucket)
    if (!is.null(cr)) ratio <- cr
    # EVERY DRAW, not just the point estimate. simulate_seat_contests() requires
    # statewide_draws to cover every column in `parties` or it errors, so an
    # unmodelled class needs its own draw column. There is no genuine trend draw
    # for it, so each simulated OTH draw is SPLIT by the prior election's ratio
    # within the bucket -- preserving that draw's total, since the ratios sum to
    # 1, and giving the folded classes variation correlated with OTH's own
    # uncertainty rather than independent of it. oth_draw is already on the
    # forecast scale, so it is split by ratio only.
    # REPLACE the folded columns, never cbind new ones. statewide_draws_as_at()
    # returns a column for EVERY party in `parties`, folded ones included (it
    # builds `mu`/`sd` over all of them and only skips the fitted-mean loop), so
    # appending produces a matrix with TWO columns called "IND" -- and
    # `sw_draws[, "IND"]` then silently takes whichever comes first. Caught here
    # by the extraction proof: 9 columns for 7 parties, IND at both 4.01 and
    # 1.15. **The federal harness does the same cbind and is very likely
    # carrying this bug**; flagged separately rather than assumed, because it
    # decides whether its forecast-mode numbers mean what they say.
    # FOLD FIRST, THEN SPLIT, or the total leaks. A folded class is not exactly
    # zero in the raw draws -- statewide_draws_as_at() gives it `fallback_sd`
    # noise around a zero mean and the row is renormalised -- so simply
    # overwriting its column throws that share away and the statewide stops
    # summing to 100. Measured on fed2022: 97.7 instead of 100.0, i.e. 2.3
    # points of vote silently deleted, which would then be redistributed by
    # every downstream renormalisation. Add the folded columns INTO the bucket
    # before splitting it.
    oth_draw <- sw_draws[, "OTH"]
    for (p in unmodelled) oth_draw <- oth_draw + sw_draws[, p]
    for (p in unmodelled) sw_draws[, p] <- oth_draw * ratio[[p]]
    sw_draws[, "OTH"] <- oth_draw * ratio[["OTH"]]
    if (anyDuplicated(colnames(sw_draws)))
      stop("forecast_statewide_for(): duplicate party columns in the draws -- ",
           paste(colnames(sw_draws)[duplicated(colnames(sw_draws))], collapse = ", "))
    st_fc <- colMeans(sw_draws)
  }
  cat(sprintf("FS1  %s%d forecast statewide: %d polls to %s; folded into OTH: %s\n",
              region, year, FC$n_polls, as.character(ed - 1),
              if (length(FC$folded)) paste(FC$folded, collapse = ", ") else "none"))
  cat(sprintf("FS1  trend TPP %.2f, fundamentals %.2f, projection %.2f, draws realise %.2f\n",
              FC$tpp, fr, FC$anchor$mean, FC$implied_tpp))
  list(st_fc = st_fc, draws = sw_draws, folded = FC$folded, n_polls = FC$n_polls,
       tpp = FC$tpp, fund = fr, anchor_mean = FC$anchor$mean,
       implied_tpp = FC$implied_tpp)
}

#' Split ratios for the unpolled bucket from the per-candidate model
#'
#' Under `AUSPOL_BUCKET_SPLIT = cand_resid / cand_naive`, returns each bucket
#' class's share of the bucket as predicted by the per-candidate minor-party
#' model (`scripts/fit_minor_candidates.R`, time-forward: each election
#' predicted by models fitted on earlier elections). `NULL` under the default
#' `prior`, or when any bucket class lacks a prediction (the caller then keeps
#' the previous election's ratios, and this says so). One function for the
#' shared statewide block and the federal harness's own copy, so the two
#' cannot drift. docs/plans/prereg-bucket-split-candidates-2026-09-28.md.
#'
#' @param election Label such as `"vic2022"`.
#' @param bucket Class names in the bucket.
#' @return Named numeric ratios summing to 1, or `NULL`.
#' @export
candidate_bucket_ratio <- function(election, bucket) {
  split_mode <- Sys.getenv("AUSPOL_BUCKET_SPLIT", "cand_naive")
  if (!split_mode %in% c("cand_resid", "cand_naive")) return(NULL)
  # The SPLIT reads the v2 candidate model (v44); v3 (defectors and newcomers
  # treated as personal votes) divides worse but totals better, so each
  # purpose names its source. plans/prereg-minor-candidate-defectors-2026-09-28.md.
  sf <- out_path(Sys.getenv("AUSPOL_BUCKET_SPLIT_SRC", "minor-class-shares-v2.csv"))
  if (!file.exists(sf)) stop("AUSPOL_BUCKET_SPLIT=", split_mode, " needs ", sf,
                             " (scripts/fit_minor_candidates.R).")
  cs <- data.table::fread(sf, showProgress = FALSE)
  col <- if (split_mode == "cand_resid") "pred_resid" else "pred_naive"
  # A differently-named local, NEVER the bare argument: `election` is also a
  # column, and data.table binds a bare name inside `[` to the column, so
  # `cs$election == election` was always TRUE and every class took the FIRST
  # election's share (caught by the fed2025 smoke: IND 0.18 instead of 0.44).
  el_arg <- election
  pr <- cs[cs$election == el_arg, ]
  if (anyDuplicated(pr$cls)) stop("candidate_bucket_ratio(): duplicate class rows for ", el_arg)
  pred <- stats::setNames(pr[[col]], pr$cls)[bucket]
  if (all(is.finite(pred)) && sum(pred) > 0) {
    ratio <- stats::setNames(pred / sum(pred), bucket)
    cat(sprintf("BS1  %s: bucket split by candidate model (%s): %s\n", election, split_mode,
                paste(sprintf("%s %.2f", bucket, ratio), collapse = ", ")))
    return(ratio)
  }
  cat(sprintf("BS1! %s: no candidate-model share for %s; prior-ratio split kept\n", election,
              paste(bucket[!is.finite(pred)], collapse = ", ")))
  NULL
}

#' The unpolled bucket's total from the per-candidate model
#'
#' Sum of the per-candidate model's predicted statewide shares (`pred_naive`,
#' time-forward) over the bucket classes, for `AUSPOL_BUCKET_TOTAL=cand`.
#' `NULL` when off or when any bucket class lacks a prediction.
#' docs/plans/prereg-bucket-total-candidates-2026-09-28.md.
#'
#' @param election Label such as `"nsw2023"`.
#' @param bucket Class names in the bucket.
#' @return A single number (share points), or `NULL`.
#' @export
candidate_bucket_total <- function(election, bucket) {
  if (!Sys.getenv("AUSPOL_BUCKET_TOTAL", "poll") %in% c("cand", "blend")) return(NULL)
  sf <- out_path(Sys.getenv("AUSPOL_BUCKET_TOTAL_SRC", "minor-class-shares-v3.csv"))
  if (!file.exists(sf)) stop("AUSPOL_BUCKET_TOTAL=cand needs ", sf, " (scripts/fit_minor_candidates.R).")
  cs <- data.table::fread(sf, showProgress = FALSE)
  el_arg <- election   # never the bare argument inside `[` (NSE trap)
  pr <- cs[cs$election == el_arg, ]
  if (anyDuplicated(pr$cls)) stop("candidate_bucket_total(): duplicate class rows for ", el_arg)
  pred <- stats::setNames(pr$pred_naive, pr$cls)[bucket]
  if (!all(is.finite(pred))) {
    cat(sprintf("BT1! %s: no candidate-model share for %s; bucket total left to the polls\n", el_arg,
                paste(bucket[!is.finite(pred)], collapse = ", ")))
    return(NULL)
  }
  sum(pred)
}

#' How far to move the bucket total from the polls toward the candidate model
#'
#' For `AUSPOL_BUCKET_TOTAL=blend`: least squares of `actual - poll` on
#' `cand - poll` over pairs dated strictly before `before`, shrunk by
#' `w_hat^2 / (w_hat^2 + se^2)` and clamped to 0..1. Under 3 earlier pairs the
#' standard error is not estimable and the weight is 0 (the poll total).
#' docs/plans/prereg-bucket-total-blend-2026-09-28.md.
#'
#' @param before Date of the election being forecast.
#' @param hist data.table (pair, date, poll_total, cand_total, actual); read
#'   from `output/bucket-total-history.csv` when NULL.
#' @return list: `w`, `w_hat`, `se`, `n`, `latest` (last pair used).
#' @export
bucket_total_blend <- function(before, hist = NULL) {
  before <- as.Date(before)
  if (is.null(hist)) {
    f <- out_path("bucket-total-history.csv")
    if (!file.exists(f)) stop("output/bucket-total-history.csv is missing (scripts/build_bucket_total_history.R).")
    hist <- data.table::fread(f, showProgress = FALSE)
  }
  h <- hist[as.Date(hist$date) < before, ]
  n <- nrow(h)
  latest <- if (n) h$pair[which.max(as.Date(h$date))] else NA_character_
  if (n < 3L) return(list(w = 0, w_hat = NA_real_, se = NA_real_, n = n, latest = latest))
  dc <- h$cand_total - h$poll_total
  da <- h$actual - h$poll_total
  ss <- sum(dc^2)
  if (!isTRUE(ss > 0)) return(list(w = 0, w_hat = NA_real_, se = NA_real_, n = n, latest = latest))
  w_hat <- sum(dc * da) / ss
  se <- sqrt(sum((da - w_hat * dc)^2) / (n - 1)) / sqrt(ss)
  w <- min(1, max(0, w_hat)) * w_hat^2 / (w_hat^2 + se^2)
  list(w = w, w_hat = w_hat, se = se, n = n, latest = latest)
}

#' Leave-one-out fundamentals, fitted once per run
#'
#' Convenience wrapper so every harness builds the same held-out table the same
#' way rather than five copies of four lines.
#'
#' @return A `data.table` of `year`, `region`, `fund`.
#' @export
fundamentals_loo_table <- function() {
  m <- fit_fundamentals(build_fundamentals_data(), "@TPP")
  data.table::data.table(year = m$data$year, region = m$data$region,
                         fund = m$data$actual - m$loo_errors)
}

#' Replace a harness's oracle statewide with the forecast when asked
#'
#' One block for all six harnesses (until 2026-09-19 fed and sa each carried
#' their own copy and nsw/qld/vic/wa had none: `docs/MODEL-REGISTRY.md`'s one
#' OPEN GAP). Under `AUSPOL_FORECAST_MODE=1` the statewide the seats swing
#' toward is [forecast_statewide_for()]'s poll-and-fundamentals projection as
#' at the day before; otherwise `st_b`, the target election's own counted
#' result, is returned unchanged (the oracle, kept only so a plain run stays
#' byte-identical while the switch is measured).
#'
#' @param region,year,election_date,parties,st_a,n_sims,seed As
#'   [forecast_statewide_for()].
#' @param st_b Named numeric, the oracle statewide.
#' @param code The harness's log prefix (e.g. `"BV0"`).
#' @param mode `Sys.getenv("AUSPOL_FORECAST_MODE")` by default.
#' @param on_fail `"stop"` (default) or `"skip"`: what to do when no trend can be
#'   fitted. `"skip"` prints a loud line and returns `NULL` so a multi-pair
#'   harness can drop the pair; it never falls back to the oracle.
#' @return Named numeric on `names(st_b)`, with attribute `oracle` (the
#'   replaced values) when the forecast was used.
#' @export
forecast_statewide_or_oracle <- function(region, year, election_date, parties, st_a, st_b,
                                         code = "BX0", n_sims = 20000L, seed = 42L,
                                         mode = Sys.getenv("AUSPOL_FORECAST_MODE", "1"),
                                         on_fail = c("stop", "skip")) {
  if (!identical(mode, "1")) return(st_b)
  on_fail <- match.arg(on_fail)
  # A class in the target's statewide but not the caller's party list (a new
  # entrant) must still get a forecast level, or it would be dropped from the
  # returned vector; the union here means the five call sites cannot differ.
  parties <- union(parties, names(st_b))
  fc <- tryCatch(
    # ALWAYS 20,000 draws for the statewide level, whatever the harness's own
    # sim count: st_fc is colMeans(draws), so at 2,000 sims base_pred jittered
    # by ~0.1 point between otherwise identical runs (seen in the v40 -> v41
    # stage-1 comparison on the untouched WA pairs). The draws are cheap.
    # AUSPOL_FUND_TIME_FORWARD (default 1): fundamentals and mix from earlier
    # elections only (plans/prereg-statewide-time-forward-2026-09-29.md).
    if (identical(Sys.getenv("AUSPOL_FUND_TIME_FORWARD", "1"), "1")) {
      ftf <- data.table::data.table(year = year, region = region, fund = fundamentals_tf(region, year))
      mtf <- projection_mix_tf(region, year)
      cat(sprintf("%sf time-forward statewide: fundamentals %.2f, day-before trend weight %.2f
",
                  code, ftf$fund, mtf$w[mtf$horizon == 1]))
      forecast_statewide_for(region, year, election_date, parties, st_a, ftf, mtf,
                             n_sims = max(n_sims, 20000L), seed = seed)
    } else {
      forecast_statewide_for(region, year, election_date, parties, st_a,
                             fundamentals_loo_table(),
                             data.table::fread(file.path("output", "projection-mix.csv"), showProgress = FALSE),
                             n_sims = max(n_sims, 20000L), seed = seed)
    },
    error = function(e) e)
  if (inherits(fc, "error")) {
    # A cycle too thin to fit a trend (wa2021: four polls in 180 days, none
    # earlier in the term) has NO forecast statewide. In a multi-pair harness
    # the honest treatment is to skip the pair loudly, never to fall back to
    # the oracle -- that would score a leak as a forecast.
    if (on_fail == "stop") stop(conditionMessage(fc), call. = FALSE)
    cat(sprintf("%s! no forecast statewide for %s%d (%s) -- pair SKIPPED in forecast mode, not scored\n",
                code, region, year, conditionMessage(fc)))
    return(NULL)
  }
  keep <- intersect(names(fc$st_fc), names(st_b))
  out <- fc$st_fc[keep]
  cat(sprintf("%s  forecast statewide replaces the oracle for %s%d. Mean |error| %.2f pts over %d classes: %s\n",
              code, region, year, mean(abs(out - st_b[keep]), na.rm = TRUE), length(out),
              paste(sprintf("%s %.1f(%.1f)", keep, out, st_b[keep]), collapse = " ")))
  attr(out, "oracle") <- st_b[keep]
  out
}
