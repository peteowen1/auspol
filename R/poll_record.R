# Statewide poll weighting from the past, not the present cycle.
#
# Pete, 2026-10-09: weight polls by pollster track record (sample size stopped
# at its pre-registered gate: 15.5% coverage). Two arms, both learned ONLY from
# elections whose result was known when the cycle under test began
# (`as_of = cycle start`, the pin flows_for() already uses), and one scoring
# helper for the "bands" half of the criterion.
# docs/plans/prereg-statewide-poll-sample-weights-2026-10-09.md (Amendment 1).

# Constants (docs/CONSTANTS.md).
POLL_RECORD_HALFLIFE <- 30   # days before polling day at which a poll's record weight halves
POLL_RECORD_K <- 12          # pseudo-polls pulling a firm's record to the pooled record (estimate_firm_factors() uses 12)
POLL_RECORD_PARTIES <- c("ALP", "LNP", "GRN")

.poll_record_cache <- new.env(parent = emptyenv())

#' Every past poll's deviation from the result, beyond what all pollsters missed
#'
#' For each completed election (region, year) and each poll in its cycle: per
#' party in `POLL_RECORD_PARTIES`, `e = poll - result`, minus the
#' recency-weighted mean `e` over every poll of that election and party (the
#' miss every pollster shared, e.g. 2019's Labor overstatement, is not one
#' firm's record). Recency weight `0.5^(days before polling day / POLL_RECORD_HALFLIFE)`.
#' Cached per process.
#' @param regions Poll files to read.
#' @return data.table `region`, `year`, `election`, `firm`, `party`, `d`, `rec`.
#' @export
poll_error_table <- function(regions = c("fed", "vic", "nsw", "qld", "wa", "sa")) {
  key <- paste(sort(regions), collapse = ",")
  if (!is.null(.poll_record_cache[[key]])) return(.poll_record_cache[[key]])
  cycles <- load_election_cycles()
  ev <- load_eventual_results()
  out <- list()
  for (rg in regions) {
    if (!file.exists(anchor_data_path(sprintf("poll-data-%s.csv", rg), must_exist = FALSE))) next
    pl <- suppressMessages(load_polls(rg))
    cy <- cycles[cycles$region == rg]
    for (k in seq_len(nrow(cy))) {
      el_end <- cy$end[k]; el_year <- cy$year[k]
      inn <- which(pl$date > cy$start[k] & pl$date <= el_end)
      if (!length(inn)) next
      for (p in intersect(POLL_RECORD_PARTIES, names(pl))) {
        hit <- ev$region == rg & ev$year == el_year & ev$party == p
        if (!any(hit)) next
        act <- ev$actual[which(hit)][1]
        y <- pl[[p]][inn]
        ok <- is.finite(y)
        if (sum(ok) < 2L) next
        e <- y[ok] - act
        rec <- 0.5^(as.numeric(el_end - pl$date[inn][ok]) / POLL_RECORD_HALFLIFE)
        out[[length(out) + 1L]] <- data.table::data.table(
          region = rg, year = el_year, election = el_end, firm = pl$firm[inn][ok],
          party = p, d = e - sum(rec * e) / sum(rec), rec = rec)
      }
    }
  }
  tab <- data.table::rbindlist(out)
  .poll_record_cache[[key]] <- tab
  tab
}

#' Pollster noise multipliers from their record, time-forward
#'
#' Each firm's recency-weighted mean squared deviation from results (beyond the
#' shared miss; [poll_error_table()]) over every election held BEFORE `as_of`,
#' relative to the pooled value, shrunk toward the pool by `POLL_RECORD_K`
#' pseudo-polls (effective polls = summed recency weights), as an sd ratio:
#' `sqrt(((n_f * v_f + K * v) / (n_f + K)) / v)`. 1 = average record. A firm
#' with no record gets no entry (weight 1 in [obs_noise_factors()]).
#' @param as_of Date; only elections strictly before it are used.
#' @return Named numeric vector (names = firm), attribute `n_elections`.
#' @export
firm_record_factors <- function(as_of) {
  tab <- poll_error_table()
  as_of_d <- as.Date(as_of)
  used <- tab[tab$election < as_of_d]
  if (!nrow(used)) return(structure(numeric(0), n_elections = 0L))
  # A record from an election on or after as_of would be the result being
  # forecast leaking in; this cannot fire unless the filter above is broken.
  stopifnot(all(used$election < as_of_d))
  v_pool <- sum(used$rec * used$d^2) / sum(used$rec)
  agg <- used[, list(n = sum(rec), v = sum(rec * d^2) / sum(rec)), by = firm]
  f <- sqrt(((agg$n * agg$v + POLL_RECORD_K * v_pool) / (agg$n + POLL_RECORD_K)) / v_pool)
  structure(stats::setNames(f, agg$firm), n_elections = length(unique(paste(used$region, used$year))))
}

#' Poll noise (sigma_obs, sigma_rw) estimated from EARLIER cycles of a region
#'
#' Replaces the fixed 1.7-point default for one target cycle: maximum marginal
#' likelihood ([estimate_trend_sigmas()]) pooled over that region's completed
#' cycles that ended on or before the target cycle's start. Cached per
#' (region, target year, party). `NULL` when fewer than two earlier cycles
#' have enough polls, or the estimate sits at a bound (the caller keeps the
#' defaults rather than dropping the cycle).
#' @param polls From [load_polls()] for the region.
#' @param year Target election year.
#' @param party Party column.
#' @param cycles From [load_election_cycles()].
#' @param pri_all From [load_prior_results()].
#' @return list `sigma_obs`, `sigma_rw` (model scale) or `NULL`.
#' @export
poll_sigmas_time_forward <- function(polls, year, party, cycles, pri_all) {
  rg <- attr(polls, "region")
  key <- paste("sig", rg, year, party)
  if (exists(key, envir = .poll_record_cache, inherits = FALSE)) return(.poll_record_cache[[key]])
  # DISK CACHE (each estimate is ~5 s and deterministic given the earlier
  # cycles' polls): keyed on region, year, party and the count and last date of
  # the polls that feed it, so a refreshed poll file invalidates the row.
  disk <- out_path("poll-sigmas-tf-cache.csv")
  n_feed <- sum(polls$date <= max(cycles$start[which(cycles$region == rg & cycles$year == year)], as.Date("1900-01-01")))
  feed_key <- paste(rg, year, party, n_feed)
  if (file.exists(disk)) {
    dc <- data.table::fread(disk, showProgress = FALSE)
    hit <- which(dc$cache_key == feed_key)
    if (length(hit)) {
      res <- if (is.na(dc$sigma_obs[hit[1]])) NULL else list(sigma_obs = dc$sigma_obs[hit[1]], sigma_rw = dc$sigma_rw[hit[1]])
      assign(key, res, envir = .poll_record_cache)
      return(res)
    }
  }
  # Masks outside the brackets: `year` is also a column of `cycles`, and inside
  # `[` it would bind to the column (CLAUDE.md data.table NSE; this exact line
  # selected every cycle on its first run, 2026-10-09).
  target_year <- year
  is_tgt <- cycles$region == rg & cycles$year == target_year
  tgt_start <- cycles$start[which(is_tgt)][1]
  earlier <- cycles[which(cycles$region == rg & cycles$end <= tgt_start), ]
  res <- NULL
  if (nrow(earlier) >= 2L) {
    pl <- lapply(earlier$year, function(y) cycle_polls(polls, y, cycles))
    pr <- vapply(earlier$year, function(y) {
      h <- pri_all$region == rg & pri_all$year == y & pri_all$party == party
      if (any(h)) pri_all$prev1[which(h)][1] else NA_real_
    }, numeric(1))
    est <- tryCatch(estimate_trend_sigmas(pl, party, prior_results = pr), error = function(e) NULL)
    if (!is.null(est) && !isTRUE(est$at_bound) && is.finite(est$sigma_obs) && is.finite(est$sigma_rw))
      res <- list(sigma_obs = est$sigma_obs, sigma_rw = est$sigma_rw)
  }
  assign(key, res, envir = .poll_record_cache)
  row <- data.table::data.table(cache_key = feed_key,  # not `key`: that is data.table()'s own argument (CLAUDE.md)
                                 sigma_obs = if (is.null(res)) NA_real_ else res$sigma_obs,
                                sigma_rw = if (is.null(res)) NA_real_ else res$sigma_rw)
  data.table::fwrite(row, disk, append = file.exists(disk))
  res
}

#' Score held-out polls against a trend fitted before them
#'
#' For each poll after the fit's last day and each fitted party: the predictive
#' distribution on the model scale is `N(level_T + house_j, sd_T^2 +
#' sigma_rw^2 * gap + sd_house_j^2 + (sigma_obs * f_j)^2)`, where `f_j` is the
#' firm's noise factor in the arm (1 if none) and an unseen firm takes the
#' house prior (`sigma_house_pts`, 3 points by default as in [fit_trend()]).
#' Returns the log density and the standardised residual. The transform's
#' Jacobian is the same for every arm, so log densities compare across arms.
#' @param fits Named list of [fit_trend()] results fitted with `want_var = TRUE`.
#' @param polls_after Polls dated after the fits' last day (same columns).
#' @param firm_w Named noise factors used in the fit, or `NULL`.
#' @param sigma_house_pts House-effect prior sd for an unseen firm.
#' @return data.table `date`, `firm`, `party`, `y`, `logdens`, `z`.
#' @export
poll_predictive_scores <- function(fits, polls_after, firm_w = NULL, sigma_house_pts = 3) {
  if (!nrow(polls_after)) return(NULL)
  data.table::rbindlist(lapply(names(fits), function(p) {
    f <- fits[[p]]
    if (!p %in% names(polls_after)) return(NULL)
    y <- polls_after[[p]]
    ok <- which(is.finite(y))
    if (!length(ok)) return(NULL)
    tr <- f$trend; last <- which.max(tr$date)
    sc <- f$meta$scale
    m_T <- tr$mean_link[last]; s_T <- tr$sd_link[last]
    if (!is.finite(s_T)) stop("poll_predictive_scores needs fits with want_var = TRUE")
    hs <- f$house_effects
    fm <- polls_after$firm[ok]
    # A firm the fit saw but pooled (fewer than min_firm_polls) takes the
    # "(other firms)" house effect; one it never saw takes the prior.
    seen <- unique(f$residuals$firm)
    fm_key <- ifelse(fm %in% hs$firm, fm, ifelse(fm %in% seen & "(other firms)" %in% hs$firm, "(other firms)", fm))
    hi <- match(fm_key, hs$firm)
    s_house0 <- sd_to_link(sigma_house_pts, f$meta$p_ref, sc)
    h_m <- ifelse(is.na(hi), 0, hs$effect[hi])
    h_s <- ifelse(is.na(hi) | !is.finite(hs$sd[hi]), s_house0, hs$sd[hi])
    fac <- if (is.null(firm_w)) rep(1, length(ok)) else unname(firm_w[fm])
    fac[!is.finite(fac)] <- 1
    gap <- as.numeric(polls_after$date[ok] - tr$date[last])
    yl <- to_link(pmin(pmax(y[ok], SHARE_CLAMP[1]), SHARE_CLAMP[2]), sc)$z
    v <- s_T^2 + f$meta$sigma_rw^2 * gap + h_s^2 + (f$meta$sigma_obs * fac)^2
    m <- m_T + h_m
    data.table::data.table(date = polls_after$date[ok], firm = fm, party = p, y = y[ok],
                           logdens = stats::dnorm(yl, m, sqrt(v), log = TRUE),
                           z = (yl - m) / sqrt(v))
  }))
}
