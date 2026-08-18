# Recompute POLL_TRACKING_BOUND on the SAME model path the checks assert on.
#
# The first execution of docs/plans/prereg-per-party-poll-check.md's rule used
# the deviations already sitting in output/others-bias-tests.csv. Those come
# from trend_as_at() with its defaults -- sigmas = "default", weights =
# "equal". The checks in fit_vic.R / fit_federal.R / fit_nsw.R run on fits from
# fit_cycle_unfolded() with PER-CYCLE sigmas and per-pollster noise factors.
# CLAUDE.md is explicit that these are two different model paths that must be
# distinguished, and calibrating a threshold on one while asserting it on the
# other is a straight mismatch.
#
# It is not a small one. On the three cycles where both paths can be compared,
# the fuller path's worst per-party deviation is 1.64x to 3.12x the default
# path's. A bound of 2.5 derived from default-path data is therefore far
# stricter than the rule intended when applied to fuller-path fits.
#
# The RULE is unchanged and was fixed in advance: the 99th percentile of
# |fitted - mean(final 90 days of polls)|, rounded up to the nearest 0.5, with
# adoption refused above 5.0. Only the data it is computed over is corrected.
# This is fixing an execution error, not choosing a new criterion.

suppressMessages(devtools::load_all(".", quiet = TRUE))
library(data.table)

REGIONS <- c("fed", "nsw", "vic", "qld", "sa", "wa")
MIN_YEAR <- 1990
W <- 90L
MIN_POLLS <- 3L

cycles <- load_election_cycles()
ev <- load_eventual_results()
pol <- load_polled_elections()
pri_all <- load_prior_results()
flows_all <- load_preference_flows()

rows <- list(); skipped <- 0L
t0 <- Sys.time()

for (rg in REGIONS) {
  f <- anchor_data_path(sprintf("poll-data-%s.csv", rg), must_exist = FALSE)
  if (!file.exists(f)) next
  polls <- suppressMessages(load_polls(rg))
  for (y in sort(pol$year[which(pol$region == rg & pol$year >= MIN_YEAR)])) {
    krow <- cycles$region == rg & cycles$year == y
    if (!any(krow)) { skipped <- skipped + 1L; next }
    cyc <- cycles[which(krow), ]

    # Same completeness filter as the original calibration, so the only thing
    # that changes between the two runs is the model path.
    ka <- ev$region == rg & ev$year == y & ev$party != "@TPP"
    act <- ev[which(ka), ]
    if (!nrow(act) || abs(sum(act$actual) - 100) > 5) { skipped <- skipped + 1L; next }

    kp <- pri_all$region == rg & pri_all$year == y
    pr <- pri_all[which(kp), ]
    if (!nrow(pr)) { skipped <- skipped + 1L; next }
    priors <- stats::setNames(pr$prev1, pr$party)

    fl <- tryCatch(flows_for(flows_all, y - 1L, rg, quiet = TRUE,
                             cycles = cycles, as_of = cyc$start[1]),
                   error = function(e) NULL)
    if (is.null(fl)) { skipped <- skipped + 1L; next }

    # THE POINT OF THIS SCRIPT: per-cycle sigmas and firm factors, matching the
    # configuration the checks run on rather than the default one.
    r <- tryCatch(trend_as_at(polls, y, cycles, cyc$end[1], priors, fl,
                              sigmas = "per_cycle", weights = "firm_factors"),
                  error = function(e) NULL)
    if (is.null(r)) { skipped <- skipped + 1L; next }

    cp <- cycle_polls(polls, y, cycles)
    late <- cp$date > cyc$end[1] - W
    for (p in names(r$fp)) {
      if (!(p %in% names(cp))) next
      v <- cp[[p]][late]
      n <- sum(!is.na(v))
      if (n < MIN_POLLS) next
      rows[[length(rows) + 1L]] <- data.table(
        region = rg, year = y, party = p, n = n,
        fitted = unname(r$fp[[p]]), poll90 = mean(v, na.rm = TRUE))
    }
    message(sprintf("  %s %d done (%.0f s elapsed)", rg, y,
                    as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
}

dt <- rbindlist(rows)
stopifnot(nrow(dt) > 0)
dt[, dev := abs(fitted - poll90)]

cat(sprintf("\n%d (cycle, party) rows over %d cycles; %d cycles skipped\n",
            nrow(dt), uniqueN(dt[, .(region, year)]), skipped))
qs <- quantile(dt$dev, c(.5, .75, .9, .95, .99, 1))
print(round(qs, 3))

p99 <- unname(qs["99%"])
BOUND <- ceiling(p99 * 2) / 2
cat(sprintf("\n99th percentile = %.3f  ->  BOUND = %.1f\n", p99, BOUND))
cat(sprintf("plan's refusal condition (> 5.0): %s\n",
            if (BOUND > 5) "REFUSE ADOPTION" else "ok"))
cat(sprintf("breaching rows at that bound: %d of %d (%.1f%%)\n",
            sum(dt$dev > BOUND), nrow(dt), 100 * mean(dt$dev > BOUND)))
print(dt[dev > BOUND, .(region, year, party, dev = round(dev, 2), n)][order(-dev)])

fwrite(dt, file.path("output", "poll-tracking-calibration.csv"))
cat(sprintf("\nWrote output/poll-tracking-calibration.csv in %.0f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
