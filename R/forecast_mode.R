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
#' @param tpp_target Optional `list(mean=, sd=)` two-party anchor. When given,
#'   the Labor/Coalition split is moved to hit it, exactly as the published path
#'   does. When `NULL` the trend's own two-party figure is used with the spread
#'   implied by the trend band.
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

  # SECOND LEAKAGE ASSERTION, on the result rather than the filter. Checking
  # that a table filtered to <= as_at contains nothing later is true by
  # construction; this checks the polls the trend actually saw.
  cp <- cycle_polls(polls, year, cycles)
  used <- cp$date[cp$date <= as_at]
  if (length(used) && max(used) >= election_date) {
    stop("A poll dated on or after the election reached the trend.")
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

  if (!is.null(tpp_target)) {
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

  list(draws = draws, folded = folded, n_polls = tr$n_polls, fp = tr$fp,
       tpp = tr$tpp, mu = mu, sd = sd)
}
