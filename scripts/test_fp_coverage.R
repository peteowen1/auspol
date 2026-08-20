# Do our first-preference intervals contain the truth as often as they claim?
#
# Against docs/plans/prereg-fp-interval-coverage.md, committed before anything
# was measured. The decision rule and four refusals are in the plan and are NOT
# restated here.
#
# The repo reports two-party interval coverage on the published page (93%
# against a claimed 95%, over 195 pairs). First-preference coverage has never
# been measured. This measures it.
#
# Emits FC* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

REGIONS <- c("fed", "nsw", "vic", "qld", "sa", "wa")
MIN_YEAR <- 1990
LEVELS <- c(0.50, 0.80, 0.95)

cycles <- load_election_cycles(); ev <- load_eventual_results()
pol <- load_polled_elections(); pri_all <- load_prior_results()
mix <- fread("output/projection-mix.csv")

rows <- list(); t0 <- Sys.time()
for (rg in REGIONS) {
  f <- anchor_data_path(sprintf("poll-data-%s.csv", rg), must_exist = FALSE)
  if (!file.exists(f)) next
  polls <- suppressMessages(load_polls(rg))
  ps_all <- attr(polls, "parties")
  for (y in sort(pol$year[which(pol$region == rg & pol$year >= MIN_YEAR)])) {
    if (!any(cycles$region == rg & cycles$year == y)) next
    ka <- ev$region == rg & ev$year == y & ev$party != "@TPP"
    act <- ev[which(ka), ]
    if (!nrow(act) || abs(sum(act$actual) - 100) > 5) next
    kp <- pri_all$region == rg & pri_all$year == y
    pr <- pri_all[which(kp), ]
    if (!nrow(pr)) next
    priors <- stats::setNames(pr$prev1, pr$party)

    cp <- cycle_polls(polls, y, cycles)
    cnt <- vapply(ps_all, function(q) sum(!is.na(cp[[q]])), 1L)
    sel <- names(cnt)[cnt >= 8]
    if (!("ALP" %in% sel)) next

    # want_var = TRUE: the posterior bands are the whole point here, and the
    # backtest elsewhere skips the variance solve for speed.
    fits <- tryCatch(
      fit_cycle_unfolded(cp, parties = sel, priors = priors, want_var = TRUE,
                         verbose = FALSE),
      error = function(e) NULL)
    if (is.null(fits)) next

    for (p in names(fits)) {
      ka2 <- act$party == p
      if (!any(ka2)) next
      tr <- fits[[p]]$trend
      i <- which.max(tr$date)
      if (!is.finite(tr$lo95[i]) || !is.finite(tr$hi95[i])) next
      rows[[length(rows) + 1L]] <- data.table(
        region = rg, year = y, party = p,
        fitted = tr$mean[i],
        sd = (tr$hi95[i] - tr$lo95[i]) / (2 * stats::qnorm(0.975)),
        actual = act$actual[which(ka2)][1])
    }
    message(sprintf("  %s %d done (%.0f s)", rg, y,
                    as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
}

dt <- rbindlist(rows)
stopifnot(nrow(dt) > 0)
dt <- dt[is.finite(sd) & sd > 0]
cat(sprintf("\nFC1  %d (cycle, party) rows over %d cycles\n",
            nrow(dt), uniqueN(dt[, paste(region, year)])))
cat(sprintf("FC1  mean fitted sd %.2f points; mean |fitted - actual| %.2f\n",
            mean(dt$sd), mean(abs(dt$fitted - dt$actual))))

covers <- function(d, lvl, infl = 1) {
  z <- stats::qnorm(1 - (1 - lvl) / 2)
  mean(abs(d$fitted - d$actual) <= z * d$sd * infl)
}

cat("\nFC2  coverage of the trend band as published (no projection inflation)\n")
cov_raw <- data.table(nominal = LEVELS,
                      covered = vapply(LEVELS, function(l) covers(dt, l), 1))
cov_raw[, gap := round(covered - nominal, 3)]
print(cov_raw[, .(nominal, covered = round(covered, 3), gap)])

cat("\nFC3  by party class, at nominal 95%\n")
print(dt[, .(n = .N, sd = round(mean(sd), 2),
             covered95 = round(covers(.SD, 0.95), 3)), by = party][order(-n)])

# The pre-registered second suspect: the band is uncertainty about TODAY, while
# the actual is an election-day result. The two-party figure is inflated by a
# MEASURED projection error; first preferences are not. Use that same measured
# number -- not one chosen to make coverage land on target.
sd_err <- mix[horizon == 30, sd_err_loo][1]
cat(sprintf("\nFC4  measured projection error at 30 days (sd_err_loo): %.3f points\n",
            sd_err))
dt[, sd_infl := sqrt(sd^2 + sd_err^2)]
covers2 <- function(d, lvl) {
  z <- stats::qnorm(1 - (1 - lvl) / 2)
  mean(abs(d$fitted - d$actual) <= z * d$sd_infl)
}
cov_inf <- data.table(nominal = LEVELS,
                      covered = vapply(LEVELS, function(l) covers2(dt, l), 1))
cov_inf[, gap := round(covered - nominal, 3)]
cat("FC4  coverage after adding the measured projection error in quadrature\n")
print(cov_inf[, .(nominal, covered = round(covered, 3), gap)])

cat("\nFC5  by party class after inflation, at nominal 95%\n")
print(dt[, .(n = .N, covered95 = round(covers2(.SD, 0.95), 3)),
         by = party][order(-n)])

raw95 <- cov_raw$covered[cov_raw$nominal == 0.95]
inf95 <- cov_inf$covered[cov_inf$nominal == 0.95]
verdict <- if (raw95 >= 0.90) {
  sprintf("intervals are calibrated (%.1f%% at nominal 95%%) -- change nothing",
          100 * raw95)
} else if (inf95 >= 0.90 && inf95 <= 1.0) {
  sprintf("TOO NARROW (%.1f%%); the measured projection error brings it to %.1f%%",
          100 * raw95, 100 * inf95)
} else {
  sprintf("TOO NARROW (%.1f%%) and the projection error does not close it (%.1f%%)",
          100 * raw95, 100 * inf95)
}
cat(sprintf("\nFC6  verdict: %s\n", verdict))

fwrite(dt, file.path("output", "fp-coverage.csv"))
cat("\nWrote output/fp-coverage.csv\n")
