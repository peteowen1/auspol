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
  if ("OTH" %in% parties) {
    # everything unfitted lands here, so its mean absorbs the remainder
    mu[["OTH"]] <- max(0.1, 100 - sum(mu[setdiff(parties, "OTH")]))
  }

  # The published first-preference widening, in quadrature. See fp_extra_sd.
  if (is.finite(fp_extra_sd) && fp_extra_sd > 0) {
    sd <- sqrt(sd^2 + fp_extra_sd^2)
  }

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
  draws <- draws / rowSums(draws) * 100

  if (is.function(tpp_target)) tpp_target <- tpp_target(tr$tpp)
  if (!is.null(tpp_target)) {
    if (!all(c("mean", "sd") %in% names(tpp_target)) ||
        !is.finite(tpp_target$mean) || !is.finite(tpp_target$sd) ||
        tpp_target$sd <= 0) {
      stop("tpp_target must supply a finite `mean` and a positive `sd`. A ",
           "zero or missing sd would anchor every draw to one two-party value ",
           "and remove the uncertainty this function exists to carry.")
    }
    flow_of <- function(p) {
      f <- fl$flow_alp[fl$party == p]
      if (length(f)) f[1] / 100 else 0.489
    }
    minors <- setdiff(parties, c("ALP", "LNP"))
    implied <- draws[, "ALP"] +
      rowSums(vapply(minors, function(p) draws[, p] * flow_of(p),
                     numeric(n_sims)))
    target <- stats::rnorm(n_sims, tpp_target$mean, tpp_target$sd)
    d <- target - implied
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
  implied_tpp <- mean(draws[, "ALP"] +
    rowSums(vapply(mnr, function(q) draws[, q] * flow_out(q), numeric(n_sims))))

  list(draws = draws, folded = folded, n_polls = tr$n_polls, fp = tr$fp,
       tpp = tr$tpp, mu = mu, sd = sd, implied_tpp = implied_tpp,
       anchor = tpp_target)
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
