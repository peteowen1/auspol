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
  cat(sprintf("FS1  trend TPP %.2f, fundamentals (LOO) %.2f, projection %.2f, draws realise %.2f\n",
              FC$tpp, fr, FC$anchor$mean, FC$implied_tpp))
  list(st_fc = st_fc, draws = sw_draws, folded = FC$folded, n_polls = FC$n_polls,
       tpp = FC$tpp, fund = fr, anchor_mean = FC$anchor$mean,
       implied_tpp = FC$implied_tpp)
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
