# Pollster scorecard ------------------------------------------------------
#
# Three things about a pollster that our model computes as a byproduct and
# nobody in Australia publishes as a maintained, comparable table:
#
#   lean     - how far their polls sit from the average pollster, after the
#              trend has accounted for when they polled. This is a house
#              effect, not an accuracy claim: a firm can lean and still be
#              right if the whole field is off.
#   noise    - how variable their polls are relative to peers, and against the
#              binomial sampling floor. Below the floor means their polls
#              agree with each other more closely than random sampling allows,
#              which is the signature of herding.
#   accuracy - how close their FINAL poll came to the actual result. The one
#              readers care about, and the one requiring no model at all.
#
# Lean and accuracy are computed from entirely separate routes: lean from the
# latent-trend fit, accuracy from comparing a published number to an election
# result. That makes them a check on each other, which
# `pollster_lean_predicts_error()` exercises.

#' Final-poll accuracy of each pollster at each election
#'
#' For every election with a known result, takes each firm's last published
#' two-party figure inside `window` days and compares it with the actual.
#'
#' Graded on the pollster's OWN published two-party number, not on one derived
#' from their primaries through our preference flows: the published figure is
#' what they put their name to, including their own preference assumptions.
#'
#' @param regions Regions to include.
#' @param min_year Earliest election year.
#' @param window Days before the election counted as a final poll.
#' @return data.table: `year`, `region`, `firm`, `poll_date`, `days_before`,
#'   `poll_tpp`, `actual_tpp`, `error` (poll minus actual, so positive means
#'   the poll overstated Labor).
#' @export
pollster_accuracy <- function(regions = c("fed", "nsw", "vic", "qld"),
                              min_year = 1990, window = 30) {
  cycles <- load_election_cycles()
  ev <- load_eventual_results()
  out <- list()
  for (rg in regions) {
    polls <- tryCatch(suppressMessages(load_polls(rg)), error = function(e) NULL)
    if (is.null(polls)) next
    keep_c <- cycles$region == rg & cycles$year >= min_year
    cyc <- cycles[which(keep_c), ]
    for (i in seq_len(nrow(cyc))) {
      y <- cyc$year[i]
      ka <- ev$region == rg & ev$year == y & ev$party == "@TPP"
      if (!any(ka)) next
      actual <- ev$actual[which(ka)][1]
      end <- cyc$end[i]
      k <- polls$date >= (end - window) & polls$date <= end &
        !is.na(polls$tpp_published)
      p <- polls[which(k), ]
      if (!nrow(p)) next
      # One row per firm: their LAST poll of the campaign
      p <- p[order(p$firm, p$date), ]
      last <- p[which(!duplicated(p$firm, fromLast = TRUE)), ]
      out[[length(out) + 1L]] <- data.table::data.table(
        year = y, region = rg, firm = last$firm, poll_date = last$date,
        days_before = as.integer(end - last$date),
        poll_tpp = last$tpp_published, actual_tpp = actual,
        error = last$tpp_published - actual)
    }
  }
  res <- data.table::rbindlist(out)
  if (nrow(res)) res <- res[order(res$firm, res$year), ]
  res
}

#' Per-firm house effects pooled across cycles
#'
#' A firm's lean on one party, poll-weighted across every cycle it was fitted
#' in. House effects are identified only up to the sum-to-zero constraint
#' within each cycle, so these are relative to the average pollster of the
#' day, which is the only thing the polls can tell us.
#'
#' @param fits_by_cycle List of [fit_cycle_trends()] results.
#' @param party Party whose house effect to pool.
#' @return data.table: `firm`, `lean_pts`, `n_polls`, `n_cycles`.
#' @export
pollster_lean <- function(fits_by_cycle, party = "ALP") {
  rows <- list()
  for (fits in fits_by_cycle) {
    f <- fits[[party]]
    if (is.null(f)) next
    he <- f$house_effects
    rows[[length(rows) + 1L]] <- data.table::data.table(
      firm = he$firm, effect_pts = he$effect_pts, n_polls = he$n_polls)
  }
  if (!length(rows)) return(data.table::data.table())
  d <- data.table::rbindlist(rows)
  d <- d[which(d$firm != "(other firms)"), ]
  by_firm <- split(d, d$firm)
  data.table::rbindlist(lapply(names(by_firm), function(fm) {
    x <- by_firm[[fm]]
    data.table::data.table(
      firm = fm,
      lean_pts = sum(x$effect_pts * x$n_polls) / sum(x$n_polls),
      n_polls = sum(x$n_polls), n_cycles = nrow(x))
  }))[order(-abs(lean_pts))]
}

#' Does a firm's estimated lean predict which way it missed?
#'
#' Lean comes from the latent-trend fit; final-poll error comes from comparing
#' a published number with an election result. Nothing connects them in the
#' code, so agreement is evidence that both measure something real — and
#' disagreement would be a warning that the house effects are an artefact of
#' the trend model rather than a property of the pollster.
#'
#' @param lean From [pollster_lean()].
#' @param accuracy From [pollster_accuracy()].
#' @param min_polls Firms with fewer pooled polls than this are excluded.
#' @return List: `n` (firms compared), `cor`, `p_value`, `data`.
#' @export
#' @param within_election Compare each firm's error with the average error of
#'   the firms polling the SAME election, rather than with zero. This is the
#'   comparison that matches what a house effect claims. Raw final-poll error
#'   is dominated by how wrong the whole field was — 2019 missed by about
#'   three points for everyone — and that common miss swamps any relative
#'   lean. Comparing raw errors gives r = +0.08 (p = 0.75) on Australian data,
#'   which says nothing either way.
pollster_lean_predicts_error <- function(lean, accuracy, min_polls = 20,
                                         within_election = TRUE) {
  acc <- data.table::copy(accuracy)
  if (within_election) {
    acc[, err_use := error - mean(error), by = c("year", "region")]
  } else {
    acc[, err_use := error]
  }
  agg <- acc[, list(mean_error = mean(err_use), n_elections = .N), by = "firm"]
  m <- merge(lean[which(lean$n_polls >= min_polls), ], agg, by = "firm")
  if (nrow(m) < 4) {
    return(list(n = nrow(m), cor = NA_real_, p_value = NA_real_, data = m))
  }
  ct <- stats::cor.test(m$lean_pts, m$mean_error)
  list(n = nrow(m), cor = unname(ct$estimate), p_value = ct$p.value,
       within_election = within_election, data = m)
}

#' Each firm's implied poll-to-poll noise against the binomial floor
#'
#' The herding measure, and it must be ABSOLUTE. [estimate_firm_factors()]
#' returns a RELATIVE factor, normalised so the poll-weighted average is one;
#' a value of 0.7 means "quieter than the average Australian pollster", which
#' says nothing about sampling theory if the whole field is quiet. Reading
#' those factors as a herding check — as an earlier version of the scorecard
#' did — compares pollsters with each other and calls the answer physics.
#'
#' The absolute figure is the fitted `sigma_obs` for the cycle, which is
#' estimated by marginal likelihood and so is not shrunk by the trend,
#' multiplied by the firm's factor and expressed in percentage points at the
#' level the party actually polled. Below the binomial sd for a poll of
#' `n_ref` respondents, a firm's polls agree with each other more closely than
#' random sampling permits.
#'
#' @param fits_by_cycle List of [fit_cycle_trends()] results.
#' @param factors From [estimate_firm_factors()].
#' @param party Party to measure on.
#' @param n_ref Reference sample size for the binomial floor.
#' @return data.table: `firm`, `implied_sd_pts`, `binomial_floor`, `ratio`,
#'   `n_polls`. A ratio below 1 is the herding signal.
#' @export
pollster_noise_vs_binomial <- function(fits_by_cycle, factors, party = "ALP",
                                       n_ref = 1500) {
  rows <- list()
  for (fits in fits_by_cycle) {
    f <- fits[[party]]
    if (is.null(f)) next
    lvl <- mean(f$trend$mean)
    sd_pts <- sd_from_link(f$meta$sigma_obs, lvl, f$meta$scale)
    he <- f$house_effects
    rows[[length(rows) + 1L]] <- data.table::data.table(
      firm = he$firm, n_polls = he$n_polls, sd_pts = sd_pts,
      floor = binomial_sd_link(lvl, n_ref, "points"))
  }
  if (!length(rows)) return(data.table::data.table())
  d <- data.table::rbindlist(rows)
  d <- d[which(d$firm != "(other firms)"), ]
  by_firm <- split(d, d$firm)
  out <- data.table::rbindlist(lapply(names(by_firm), function(fm) {
    x <- by_firm[[fm]]
    data.table::data.table(
      firm = fm, n_polls = sum(x$n_polls),
      base_sd_pts = sum(x$sd_pts * x$n_polls) / sum(x$n_polls),
      binomial_floor = sum(x$floor * x$n_polls) / sum(x$n_polls))
  }))
  fac <- factors[, c("firm", "factor"), with = FALSE]
  out <- merge(out, fac, by = "firm", all.x = TRUE)
  out[is.na(factor), factor := 1]
  out[, implied_sd_pts := base_sd_pts * factor]
  out[, ratio := implied_sd_pts / binomial_floor]
  out[order(ratio), c("firm", "n_polls", "implied_sd_pts", "binomial_floor",
                      "ratio"), with = FALSE]
}

#' Assemble the pollster scorecard
#'
#' @param lean From [pollster_lean()].
#' @param factors From [estimate_firm_factors()].
#' @param accuracy From [pollster_accuracy()].
#' @param min_polls Minimum pooled polls for a firm to be listed.
#' @return data.table, one row per firm.
#' @export
pollster_scorecard <- function(lean, factors, accuracy, min_polls = 20) {
  acc <- accuracy[, list(
    elections = .N,
    final_mae = mean(abs(error)),
    final_bias = mean(error)), by = "firm"]
  out <- merge(lean, acc, by = "firm", all.x = TRUE)
  if (!is.null(factors) && nrow(factors)) {
    out <- merge(out, factors[, c("firm", "factor"), with = FALSE],
                 by = "firm", all.x = TRUE)
    data.table::setnames(out, "factor", "noise_factor")
  }
  out <- out[which(out$n_polls >= min_polls), ]
  out[order(-out$n_polls), ]
}
