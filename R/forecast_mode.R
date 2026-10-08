# Statewide draws for a backtest, from polls rather than from the answer -------
#
# Against docs/plans/prereg-forecast-mode.md.
#
# WHY THIS EXISTS, and it is not mainly about fairness. The backtest harnesses
# inject each election's ACTUAL statewide first preferences and add only
# per-seat noise. `scripts/fit_seats_full.R` -- the model that publishes --
# draws the statewide vote from the projection, correlated across parties, and
# passes it to `simulate_seat_contests(statewide_draws = )`. No harness does.
#
# So every calibration figure this repo has quoted describes a TIGHTER variant
# than the one it ships, and nothing measures the published configuration. That
# is the same failure as the two seat models, in a new guise, and it survived
# because backtest numbers look like model numbers.
#
# This function produces the statewide draws a forecaster could have made on a
# given date, using the same construction the published path uses.

#' Statewide first-preference draws as at a date, leakage-guarded
#'
#' Builds the `statewide_draws` matrix `simulate_seat_contests()` expects, from
#' the poll trend as at `as_at` rather than from the election result. The
#' construction mirrors `scripts/fit_seats_full.R`: per-party spreads come from
#' the trend's own 95% band, the draws are correlated across parties, and the
#' two-party total is anchored to a projection.
#'
#' @param region Region code, e.g. `"vic"`, `"fed"`.
#' @param year Election year being predicted.
#' @param as_at Cutoff date. Polls after it are excluded. Pass election day
#'   minus one day for a backtest.
#' @param election_date The election being predicted. Used ONLY by the leakage
#'   assertion, which refuses a cutoff on or after it.
#' @param parties Character vector of party classes the seat model simulates.
#' @param n_sims Number of draws.
#' @param party_cor Optional correlation matrix over `parties`. Supply the same
#'   one the published path uses; `NULL` draws independently.
#' @param tpp_target Two-party anchor. `scripts/fit_seats_full.R` moves the
#'   Labor/Coalition split to hit the PROJECTION's two-party figure rather than
#'   the trend's own, because the projection is the calibrated object -- its 95%
#'   intervals contain the truth 92.8% of the time over 195 election-horizon
#'   pairs -- and the seat model inherits that calibration instead of rebuilding
#'   it. Omitting it means the draws carry the raw first-preference trend's
#'   two-party implication, which is a different and less calibrated quantity.
#'
#'   Either a `list(mean=, sd=)`, or a FUNCTION of the trend's own two-party
#'   value returning such a list. The function form exists because the
#'   projection blends the trend with fundamentals, so it cannot be computed
#'   until the trend has been fitted -- which happens inside here.
#'
#'   `NULL` leaves the split unanchored. That is NOT the published construction
#'   and should only be used deliberately.
#' @param fallback_sd Per-party spread used when the trend gives no band for a
#'   party. Not a modelling choice made here: it is the published path's own
#'   fallback, kept identical so this measures what we ship.
#' @param fp_extra_sd First-preference variance correction, added in quadrature
#'   to each party's trend band. **This is not optional and not a tuning knob**:
#'   `scripts/fit_seats_full.R` applies exactly this
#'   (`sd_vec <- sqrt(trend_sd^2 + FP_EXTRA_SD^2)`, `FP_EXTRA_SD = 2.419`,
#'   adopted in `docs/reviews/fp-widening-choice-*.md`), so omitting it here
#'   would mean this function measures something the repo does not publish.
#'
#'   Omitting it is not hypothetical -- the first version of this function did,
#'   understating statewide spread by roughly 2.6x, and the resulting backtest
#'   came out MORE over-confident rather than less. That looked like a finding
#'   about the seat model and was a missing constant.
#' @param seed Optional seed.
#' @return A list with `draws` (`n_sims` x `parties` matrix, rows summing to
#'   100), `folded` (parties the trend could not fit, folded into `OTH`),
#'   `n_polls`, and `fp` (the trend's point estimate). `NULL` if the trend
#'   cannot be fitted at that cutoff, which is a thin cycle rather than an error.
#' @export
statewide_draws_as_at <- function(region, year, as_at, election_date, parties,
                                  n_sims = 20000L, party_cor = NULL,
                                  tpp_target = NULL, fallback_sd = 1.5,
                                  fp_extra_sd = 2.419, seed = NULL) {
  # as.Date() THROWS on an unparseable string rather than returning NA, so the
  # is.finite() check below could never fire on the input it was written for --
  # a guard that cannot fail, which is the hazard CLAUDE.md catalogues. Parsing
  # through tryCatch turns the throw into the NA the guard actually tests.
  as_date <- function(x) tryCatch(as.Date(x), error = function(e) as.Date(NA))
  as_at <- as_date(as_at)
  election_date <- as_date(election_date)
  # F1. THE LEAKAGE GUARD, asserted before anything is computed. A backtest may
  # not see the election it predicts, and a unit test passing on one cycle is
  # not a guarantee across ten.
  if (!is.finite(as_at) || !is.finite(election_date)) {
    stop("as_at and election_date must both be real dates.")
  }
  if (as_at >= election_date) {
    stop("as_at (", as.character(as_at), ") is on or after the election being ",
         "predicted (", as.character(election_date), "). A forecast cannot see ",
         "its own result.")
  }

  cycles <- load_election_cycles()
  polls  <- load_polls(region)
  pri    <- load_prior_results()
  kp     <- pri$region == region & pri$year == year
  # `prev1` is the previous election's result for that party, which is what
  # fit_seats_full.R passes; the column is not called `pct`.
  priors <- stats::setNames(pri$prev1[which(kp)], pri$party[which(kp)])
  if (!length(priors)) {
    stop("No prior results for region ", region, " year ", year,
         ". The trend cannot be anchored, and a forecast without an anchor is ",
         "not the published construction.")
  }
  # Flows as of the START of the cycle, which is the pattern
  # build_projection_data() already uses -- a later flow estimate would be a
  # leak arriving through the preferences rather than through the polls.
  cyc <- cycles[cycles$region == region & cycles$year == year, ]
  as_of <- if (nrow(cyc)) min(cyc$start) else as_at
  fl <- flows_for(load_preference_flows(), year, region, as_of = as_of,
                  cycles = cycles, quiet = TRUE)

  tr <- trend_as_at(polls, year, cycles, as_at, priors, fl, with_series = TRUE)
  if (is.null(tr)) return(NULL)

  # SECOND LEAKAGE ASSERTION -- and the first version of this could not fail.
  # It re-applied `cp$date <= as_at`, the identical filter trend_as_at() uses
  # internally, so it could never catch a leak originating INSIDE that function:
  # the thing it claimed to check. The comment said it checked "the polls the
  # trend actually saw" and it checked the input filter a second time.
  #
  # This compares the trend's OWN reported poll count against an independently
  # derived one. If trend_as_at() ever admitted a poll past the cutoff, it would
  # report more polls than exist at or before it, and this fires.
  cp <- cycle_polls(polls, year, cycles)
  n_eligible <- sum(cp$date <= as_at)
  if (tr$n_polls > n_eligible) {
    stop("trend_as_at() used ", tr$n_polls, " polls but only ", n_eligible,
         " are dated on or before ", as.character(as_at),
         ". A poll from after the cutoff reached the trend.")
  }

  s <- data.table::as.data.table(tr$series)
  last <- s[s$date == max(s$date), ]
  fp_parties <- setdiff(unique(last$party), "TPP_ALP")

  # D1. A party the trend could not fit is FOLDED INTO OTH, which is what the
  # live path does. Carrying its previous result forward would invent a series
  # the polls do not support. Reported, never silent: an election where One
  # Nation vanished into OTH must not be quoted as evidence about One Nation.
  folded <- setdiff(setdiff(parties, "OTH"), fp_parties)

  mu <- stats::setNames(numeric(length(parties)), parties)
  sd <- stats::setNames(rep(fallback_sd, length(parties)), parties)
  for (p in intersect(parties, fp_parties)) {
    r <- last[last$party == p, ]
    mu[[p]] <- r$mean[1]
    band <- (r$hi95[1] - r$lo95[1]) / (2 * 1.96)
    if (is.finite(band) && band > 0) sd[[p]] <- band
  }
  # A FITTED SERIES WHOSE PARTY IS NOT A SIMULATION CLASS MUST LAND IN ITS
  # CLASS, or it vanishes into the OTH remainder below. WA polls carry the
  # Nationals as their own column (`NAT FP`) while the seat model's class is
  # LNP (classify_party folds them): until 2026-09-20 the WA statewide
  # forecast dropped NAT's ~6 points from LNP and handed them to OTH (wa2017
  # forecast LNP 35.4 / OTH 16.3 against actual 36.6 / ~5). Folded here by
  # class, with the bands combined in quadrature.
  extra <- setdiff(fp_parties, parties)
  folded_into <- list()   # class -> named shares folded in, for the anchoring's implied two-party
  for (q in extra) {
    cls <- tryCatch(classify_party(name = q, code = q), error = function(e) NA_character_)
    if (is.na(cls) || !cls %in% parties || cls == "OTH") next
    r <- last[last$party == q, ]
    if (!nrow(r) || !is.finite(r$mean[1])) next
    mu[[cls]] <- mu[[cls]] + r$mean[1]
    band <- (r$hi95[1] - r$lo95[1]) / (2 * 1.96)
    if (is.finite(band) && band > 0) sd[[cls]] <- sqrt(sd[[cls]]^2 + band^2)
    folded_into[[cls]] <- c(folded_into[[cls]], stats::setNames(r$mean[1], q))
    cat(sprintf("FM1  %s%d: fitted series %s (%.1f) folded into class %s\n", region, year, q, r$mean[1], cls))
  }
  # AUSPOL_LEVEL_RECIPE=live scores the LIVE forecast's recipe in the
  # backtests (Pete 2026-09-28: "test live on back test ... use the method
  # that performs best"): the level is the trend endpoints rescaled to 100
  # (the live seat shares are renormalised) and NOT anchored to the
  # projection. docs/plans/prereg-level-recipe-2026-09-28.md.
  # CAUTION: the live script anchors its level too when
  # AUSPOL_LIVE_LEVEL_ANCHOR is "1" (scripts/fit_seats_full.R, LL1), so this
  # recipe matches the live forecast only with that switch at "0". The two
  # ship together (v56, 2026-09-30); a comment here claiming the live anchor
  # "reaches only the draws' spread" was stale from 2026-09-28 and misled.
  live_recipe <- identical(Sys.getenv("AUSPOL_LEVEL_RECIPE", "live"), "live")
  close_prop <- live_recipe || identical(Sys.getenv("AUSPOL_CLOSE_PROPORTIONAL", "0"), "1")
  if (close_prop && "OTH" %in% fp_parties && "OTH" %in% parties) {
    # AUSPOL_CLOSE_PROPORTIONAL=1: the trend fits each party separately, so the
    # endpoints need not sum to 100. Rescale every fitted class, OTH included,
    # by 100 / sum -- derive_tpp()'s normalisation -- rather than dumping the
    # shortfall into OTH, which put ~2 points too many into the others bucket
    # in 17 of 22 elections. docs/plans/prereg-close-proportional-2026-09-28.md.
    fitted_cls <- names(mu)[mu > 0]
    raw_sum <- sum(mu[fitted_cls])
    mu[fitted_cls] <- mu[fitted_cls] * 100 / raw_sum
    # the series folded into a class are part of its mean; keep their share of it
    folded_into <- lapply(folded_into, function(v) v * 100 / raw_sum)
    cat(sprintf("CP1  %s%d: fitted endpoints summed %.2f, rescaled to 100 (OTH %.2f)\n",
                region, year, raw_sum, mu[["OTH"]]))
  } else if ("OTH" %in% parties) {
    # everything unfitted lands here, so its mean absorbs the remainder
    mu[["OTH"]] <- max(0.1, 100 - sum(mu[setdiff(parties, "OTH")]))
  }

  # The published first-preference widening, in quadrature. See fp_extra_sd.
  if (is.finite(fp_extra_sd) && fp_extra_sd > 0) {
    sd <- sqrt(sd^2 + fp_extra_sd^2)
  }
  # KNOWN, LEFT IN: a class the polls do not track has mean 0 here, is drawn
  # from N(0, 2.85), floored at 0.1 and renormalised, so it carries about 1.1
  # points of phantom vote per class, paid by the polled classes (nsw2023's
  # three unpolled classes cost Labor 1.2 points before any anchoring).
  # Zeroing it (`sd[folded] <- 0`) removed the majors' statewide bias and
  # still lost on rebuild v43 (ledger 0.2943 -> 0.3022), because the phantom
  # vote offsets the anchoring below pushing the Coalition up. The two must
  # change together. docs/plans/prereg-phantom-minor-vote-2026-09-20.md.
  #
  # AUSPOL_ANCHOR_IMPLIED=1 is that joint change (the arm pre-registered in
  # docs/plans/prereg-anchor-implied-tpp-2026-09-20.md): unpolled classes draw
  # exactly zero here, and the anchoring below takes its trend input from the
  # draws' own implied two-party rather than the published TPP series.
  anchor_implied <- identical(Sys.getenv("AUSPOL_ANCHOR_IMPLIED", "0"), "1")
  anchor_exhaust <- identical(Sys.getenv("AUSPOL_ANCHOR_EXHAUST", "0"), "1")

  if (!is.null(seed)) set.seed(seed)
  K <- length(parties)
  if (is.null(party_cor)) {
    draws <- vapply(parties, function(p)
      stats::rnorm(n_sims, mu[[p]], sd[[p]]), numeric(n_sims))
  } else {
    cm <- party_cor[parties, parties, drop = FALSE]
    Z <- matrix(stats::rnorm(n_sims * K), nrow = n_sims)
    draws <- Z %*% chol(cm)
    draws <- sweep(sweep(draws, 2, sd[parties], "*"), 2, mu[parties], "+")
  }
  # pmax(0.1, m) DROPS the dim attribute, so the matrix goes first -- the trap
  # CLAUDE.md records twice.
  draws <- pmax(draws, 0.1)
  colnames(draws) <- parties
  if (anchor_implied && length(folded)) {
    draws[, folded] <- 0
    cat(sprintf("AI1  %s%d: unpolled classes drawn at exactly zero: %s\n",
                region, year, paste(folded, collapse = ", ")))
  }
  draws <- draws / rowSums(draws) * 100

  # AUSPOL_OTHERS_SCALE=1: the unpolled "others" bucket (OTH plus every folded
  # class) shrunk by the poll overstatement measured on elections held BEFORE
  # this one; the share removed goes back to the polled classes, and the
  # anchoring below then re-balances Labor and Coalition to the two-party
  # target. docs/plans/prereg-others-bucket-size-2026-09-27.md.
  if (identical(Sys.getenv("AUSPOL_OTHERS_SCALE", "0"), "1")) {
    ob <- others_bucket_scale(election_date)
    bucket <- intersect(c("OTH", folded), parties)
    before_b <- mean(rowSums(draws[, bucket, drop = FALSE]))
    draws <- others_bucket_apply(draws, bucket, ob$k)
    cat(sprintf("OB2  %s%d: others bucket x%.3f (n %d earlier elections, latest %s; w %.2f): %.2f -> %.2f\n",
                region, year, ob$k, ob$n, if (ob$n) utils::tail(ob$pairs, 1) else "none",
                ob$w, before_b, mean(rowSums(draws[, bucket, drop = FALSE]))))
  }

  # AUSPOL_BUCKET_TOTAL=cand: the bucket's TOTAL from the per-candidate model,
  # applied before the anchoring so Labor and Coalition are rebalanced to the
  # two-party target afterwards. plans/prereg-bucket-total-candidates-2026-09-28.md.
  bt_bucket <- intersect(c("OTH", folded), parties)
  bt <- candidate_bucket_total(paste0(region, year), bt_bucket)
  if (!is.null(bt)) {
    b_now <- mean(rowSums(draws[, bt_bucket, drop = FALSE]))
    target_bt <- bt
    if (identical(Sys.getenv("AUSPOL_BUCKET_TOTAL", "poll"), "blend")) {
      bl <- bucket_total_blend(election_date)
      target_bt <- b_now + bl$w * (bt - b_now)
      cat(sprintf("BKT2  %s%d: blend w %.2f (w_hat %.2f, se %.2f, n %d earlier pairs, latest %s) -> total %.2f\n",
                  region, year, bl$w, bl$w_hat, bl$se, bl$n, bl$latest, target_bt))
    }
    draws <- others_bucket_apply(draws, bt_bucket, target_bt / b_now)
    cat(sprintf("BKT1  %s%d: bucket total from candidate model %.2f (polls left %.2f)\n",
                region, year, bt, b_now))
  }

  if (live_recipe && !is.null(tpp_target)) {
    cat(sprintf("LR1  %s%d: live recipe, level NOT anchored (trend TPP %.2f)\n", region, year, tr$tpp))
    tpp_target <- NULL
  }
  # AUSPOL_LEVEL_RECIPE=unanchored: the anchoring ALONE switched off, everything
  # else as published (no proportional rescale). Arm Z's "live" bundled both,
  # so its split by era could not be attributed.
  # plans/prereg-level-anchor-alone-2026-09-30.md.
  if (identical(Sys.getenv("AUSPOL_LEVEL_RECIPE", "live"), "unanchored") && !is.null(tpp_target)) {
    cat(sprintf("LR2  %s%d: level NOT anchored, no rescale (trend TPP %.2f)\n", region, year, tr$tpp))
    tpp_target <- NULL
  }
  if (!is.null(tpp_target)) {
    flow_of <- function(p) {
      f <- fl$flow_alp[fl$party == p]
      if (length(f)) f[1] / 100 else 0.489
    }
    minors <- setdiff(parties, c("ALP", "LNP"))
    implied <- draws[, "ALP"] +
      rowSums(vapply(minors, function(p) draws[, p] * flow_of(p),
                     numeric(n_sims)))
    # A series folded into LNP (WA's NAT) still sends its own flow to Labor;
    # without this its preferences vanished from `implied` and the anchoring
    # over-corrected Labor upward (wa2001 smoke, 2026-09-20). Deliberately
    # Coalition-only: the general form (series flow minus its class's rate,
    # for any class) was smoked on the only other fold, fed2016 NXT -> IND,
    # and moved every SA seat the wrong way (RMSE 4.154 -> 4.172), because a
    # party with no transfer history has only a pooled guess for a flow.
    # docs/plans/prereg-poll-series-class-fold-2026-09-20.md.
    for (cls in names(folded_into)) if (cls == "LNP") for (q in names(folded_into[[cls]])) {
      share_of_col <- if (isTRUE(mu[[cls]] > 0)) folded_into[[cls]][[q]] / mu[[cls]] else 0
      implied <- implied + draws[, cls] * share_of_col * flow_of(q)
    }
    # AUSPOL_ANCHOR_EXHAUST=1: implied two-party NET OF EXHAUSTED BALLOTS, the
    # basis derive_tpp() (R/tpp.R) puts the published series on and the NSW
    # count, fundamentals and results all use. Without it, under optional
    # preferential voting the anchoring compares a full-preferential number
    # with an OPV target (nsw2019/nsw2023 gaps +1.58/+1.42).
    # docs/plans/prereg-anchor-exhaust-2026-09-27.md. Flows with no exhaust
    # (every non-NSW election) take the old path untouched.
    denom <- 100
    ex_share <- .exhaust_shares(fl, minors)
    if (anchor_exhaust && any(ex_share > 0)) {
      lost <- vapply(minors, function(p) draws[, p] * ex_share[[p]], numeric(n_sims))
      denom <- 100 - rowSums(lost)
      implied <- 100 * (implied - rowSums(sweep(lost, 2, vapply(minors, flow_of, 1), "*"))) / denom
    }
    # The mix's trend input: the published TPP series by default; under the
    # arm, the two-party these draws already imply, so the anchoring spends
    # nothing reconciling two estimates of one quantity and applies only the
    # fundamentals' pull. Both printed, so the arm shows what it changed.
    trend_in <- if (anchor_implied) mean(implied) else tr$tpp
    if (anchor_implied) {
      cat(sprintf("AI2  %s%d: mix trend input = implied %.2f (published TPP series %.2f, gap %+.2f)\n",
                  region, year, mean(implied), tr$tpp, mean(implied) - tr$tpp))
    }
    if (is.function(tpp_target)) tpp_target <- tpp_target(trend_in)
    if (!all(c("mean", "sd") %in% names(tpp_target)) ||
        !is.finite(tpp_target$mean) || !is.finite(tpp_target$sd) ||
        tpp_target$sd <= 0) {
      stop("tpp_target must supply a finite `mean` and a positive `sd`. A ",
           "zero or missing sd would anchor every draw to one two-party value ",
           "and remove the uncertainty this function exists to carry.")
    }
    target <- stats::rnorm(n_sims, tpp_target$mean, tpp_target$sd)
    # A two-party gap on the non-exhausted total becomes a first-preference
    # move of gap * denom / 100: moving ALP up and LNP down by the same amount
    # leaves that denominator unchanged. denom is 100 without exhaustion.
    d <- if (identical(denom, 100)) target - implied else (target - implied) * denom / 100
    draws[, "ALP"] <- pmax(0.1, draws[, "ALP"] + d)
    draws[, "LNP"] <- pmax(0.1, draws[, "LNP"] - d)
    draws <- draws / rowSums(draws) * 100
  }

  # The realised two-party value of the draws, computed with the SAME flows the
  # anchoring used. Reported so a caller can verify the anchor landed rather
  # than recomputing it with a flat rate and reading a wrong number -- which is
  # exactly what a first diagnostic here did.
  flow_out <- function(q) {
    f <- fl$flow_alp[fl$party == q]
    if (length(f)) f[1] / 100 else 0.489
  }
  mnr <- setdiff(parties, c("ALP", "LNP"))
  num_out <- draws[, "ALP"] +
    rowSums(vapply(mnr, function(q) draws[, q] * flow_out(q), numeric(n_sims)))
  ex_out <- .exhaust_shares(fl, mnr)
  implied_tpp <- if (anchor_exhaust && any(ex_out > 0)) {
    lost <- vapply(mnr, function(q) draws[, q] * ex_out[[q]], numeric(n_sims))
    mean(100 * (num_out - rowSums(sweep(lost, 2, vapply(mnr, flow_out, 1), "*"))) /
           (100 - rowSums(lost)))
  } else mean(num_out)

  list(draws = draws, folded = folded, n_polls = tr$n_polls, fp = tr$fp,
       tpp = tr$tpp, mu = mu, sd = sd, implied_tpp = implied_tpp,
       anchor = tpp_target)
}

# Share (0-1) of each party's first preferences that exhausts, from a flow
# table's `exhaust` column (percent). A party with no row takes OTH's rate,
# and 0 if OTH has none either -- the same fallback derive_tpp() uses.
.exhaust_shares <- function(fl, parties) {
  ex_col <- if ("exhaust" %in% names(fl)) fl$exhaust else rep(0, nrow(fl))
  oth <- ex_col[fl$party == "OTH"]
  oth <- if (length(oth) && is.finite(oth[1])) oth[1] else 0
  vapply(parties, function(p) {
    e <- ex_col[fl$party == p]
    (if (length(e) && is.finite(e[1])) e[1] else oth) / 100
  }, numeric(1))
}

#' Check seat totals against the per-seat probabilities that produced them
#'
#' Two identities tie a set of per-seat win probabilities to the distribution of
#' the seat total, and any simulation must satisfy both whatever model produced
#' it:
#'
#' 1. **The expected total is the sum of the probabilities**, exactly. The total
#'    is a sum of Bernoulli indicators and expectation is linear, however
#'    strongly the seats correlate.
#' 2. **The variance is at least the independent-seat variance**, `sum p(1-p)`.
#'    Seats sharing a statewide draw are positively correlated, and positive
#'    correlation can only add variance. A total tighter than that floor is
#'    arithmetically impossible.
#'
#' This replaced a cross-check against the retired two-party seat model, which
#' `CLAUDE.md` forbids keeping. The reference here is arithmetic rather than
#' another model, which makes it both rule-compliant and stronger: it cannot
#' agree with a wrong answer because the other model shares the error.
#'
#' @param probs Per-seat win probabilities for one party.
#' @param totals That party's simulated seat total, one entry per simulation.
#' @param max_mean_gap Tolerated difference between the mean total and the sum
#'   of probabilities. Monte Carlo noise on the mean is `sd/sqrt(n_sims)`, many
#'   times smaller than this at any usable `n_sims`, so a larger gap is a bug.
#' @return A list with `mean_total`, `expected`, `mean_gap`, `sd_total`,
#'   `floor_sd`, `sd_ratio` and `ok`.
#' @export
check_seat_totals <- function(probs, totals, max_mean_gap = 0.5) {
  probs <- probs[is.finite(probs)]
  if (!length(probs) || !length(totals)) {
    stop("check_seat_totals() needs both probabilities and totals; an empty ",
         "input would pass every test it is given.")
  }
  if (any(probs < 0 | probs > 1)) stop("probabilities must lie in [0, 1].")
  expected <- sum(probs)
  floor_sd <- sqrt(sum(probs * (1 - probs)))
  mean_total <- mean(totals)
  sd_total <- stats::sd(totals)
  mean_gap <- abs(mean_total - expected)
  sd_ratio <- if (floor_sd > 0) sd_total / floor_sd else NA_real_
  list(mean_total = mean_total, expected = expected, mean_gap = mean_gap,
       sd_total = sd_total, floor_sd = floor_sd, sd_ratio = sd_ratio,
       ok = mean_gap <= max_mean_gap && is.finite(sd_ratio) && sd_ratio >= 1)
}
