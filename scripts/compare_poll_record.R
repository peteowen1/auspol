# Does a pollster's track record, or poll noise estimated from earlier cycles,
# improve the statewide trend?
#
# Arms (docs/plans/prereg-statewide-poll-sample-weights-2026-10-09.md, Amendment 1):
#   equal   : every poll the same, fixed 1.7-point noise -- what publishes (incumbent)
#   record  : weights = "record"    (firm noise from deviations from past RESULTS)
#   noise   : sigmas  = "pooled_tf" (sigma_obs, sigma_rw from earlier cycles)
#   both    : the two together
#
# Criterion fixed in the pre-registration before this ran (Pete: accuracy OR bands):
#   SHIP if guards pass and either
#     (1) held-out MAE (projection_loo) improves by more than 0.02, or
#     (2) MAE no worse than +0.02 AND held-out-poll log predictive density higher
#         by more than 1 SE (clustered on region-election) AND 95% coverage of
#         held-out polls closer to 95% than the incumbent's.
#   Guards: pair coverage within 5%, zero `error` skips, B2/B3 published-interval
#   coverage in [88%, 99%] / [38%, 62%], runtime under 3x (else the MAE bar is 0.04).
#
# Each arm's projection rows and poll scores are written to output/ as soon as
# the arm finishes, so an interrupted run keeps what it computed.
#
#   powershell.exe -Command 'Rscript "scripts/compare_poll_record.R"'
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
MATERIAL <- 0.02; COVER <- 0.05; RUNTIME_X <- 3

m_tpp <- fit_fundamentals(build_fundamentals_data(), "@TPP")
fund_loo <- data.table(year = m_tpp$data$year, region = m_tpp$data$region,
                       fund_tpp = m_tpp$data$actual - m_tpp$loo_errors)
ARMS <- list(equal = c("default", "equal"), record = c("default", "record"),
             noise = c("pooled_tf", "equal"), both = c("pooled_tf", "record"))
res <- list()
for (nm in names(ARMS)) {
  a <- ARMS[[nm]]
  t0 <- Sys.time()
  dat <- suppressWarnings(build_projection_data(sigmas = a[1], weights = a[2], score_polls = TRUE, verbose = FALSE))
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  sk <- attr(dat, "skipped"); ps <- attr(dat, "poll_scores")
  n_err <- if (!is.null(sk) && nrow(sk)) sum(sk$reason == "error") else 0L
  d2 <- merge(dat, fund_loo, by = c("year", "region"), all.x = TRUE)
  loo <- projection_loo(d2, debias = FALSE)
  stopifnot(nrow(loo) > 50, nrow(ps) > 100)
  fwrite(loo[, arm := nm], out_path(sprintf("poll-record-loo-%s.csv", nm)))
  fwrite(ps[, arm := nm], out_path(sprintf("poll-record-scores-%s.csv", nm)))
  res[[nm]] <- list(loo = loo, ps = ps, n_err = n_err, secs = secs, n = nrow(loo))
  cat(sprintf("PWR1 %-6s MAE %.4f | pairs %d | errors %d | held-out polls %d, log dens %.4f, cover95 %.3f | B2 %.3f B3 %.3f | %.0f s\n",
              nm, mean(abs(loo$err)), nrow(loo), n_err, nrow(ps), mean(ps$logdens), mean(abs(ps$z) < 1.96),
              mean(abs(loo$z) < 1.96), mean(abs(loo$z) < 0.6745), secs))
}

inc <- res$equal
key <- c("region", "year", "horizon", "date", "firm", "party", "y")
cat("\nPWR2 per-horizon held-out MAE (lower is better):\n")
ph <- rbindlist(lapply(names(res), function(nm) res[[nm]]$loo[, .(mae = mean(abs(err))), by = horizon][, arm := nm]))
print(dcast(ph, horizon ~ arm, value.var = "mae"), digits = 4)
cat("\nPWR2b per-region held-out MAE:\n")
pr <- rbindlist(lapply(names(res), function(nm) res[[nm]]$loo[, .(mae = mean(abs(err))), by = region][, arm := nm]))
print(dcast(pr, region ~ arm, value.var = "mae"), digits = 4)

verdicts <- list()
for (nm in setdiff(names(res), "equal")) {
  r <- res[[nm]]
  mae_gain <- mean(abs(inc$loo$err)) - mean(abs(r$loo$err))
  bar <- if (r$secs > RUNTIME_X * inc$secs) 2 * MATERIAL else MATERIAL
  cover_diff <- abs(r$n - inc$n) / inc$n
  # Paired log density on the same held-out poll cells, SE clustered on region-election.
  m <- merge(inc$ps[, c(key, "logdens"), with = FALSE], r$ps[, c(key, "logdens", "z"), with = FALSE],
             by = key, suffixes = c("_inc", "_arm"))
  m[, dd := logdens_arm - logdens_inc]
  cl <- m[, .(s = sum(dd), n = .N), by = .(region, year)]
  G <- nrow(cl); mu <- sum(cl$s) / sum(cl$n)
  se <- sqrt(sum((cl$s - mu * cl$n)^2) / sum(cl$n)^2 * G / (G - 1))
  cov_inc <- mean(abs(inc$ps$z) < 1.96); cov_arm <- mean(abs(r$ps$z) < 1.96)
  b2 <- mean(abs(r$loo$z) < 1.96); b3 <- mean(abs(r$loo$z) < 0.6745)
  guards <- c(coverage = cover_diff <= COVER, no_errors = r$n_err == 0 && inc$n_err == 0,
              B2 = b2 >= 0.88 && b2 <= 0.99, B3 = b3 >= 0.38 && b3 <= 0.62)
  acc <- mae_gain > bar
  bands <- mae_gain >= -bar && mu > se && abs(cov_arm - 0.95) < abs(cov_inc - 0.95)
  ship <- all(guards) && (acc || bands)
  cat(sprintf("\nPWR3 %s vs equal: MAE gain %+.4f (bar %.2f; runtime %.1fx) | log dens %+.4f per poll-party (SE %.4f, %d clusters, %d cells) | cover95 %.3f vs %.3f | guards %s | accuracy %s, bands %s => %s\n",
              nm, mae_gain, bar, r$secs / inc$secs, mu, se, G, nrow(m), cov_arm, cov_inc,
              paste(sprintf("%s=%s", names(guards), guards), collapse = " "), acc, bands, if (ship) "SHIP" else "REFUSE"))
  verdicts[[nm]] <- data.table(arm = nm, mae_inc = mean(abs(inc$loo$err)), mae_arm = mean(abs(r$loo$err)), mae_gain = mae_gain,
                               bar = bar, runtime_x = r$secs / inc$secs, logdens_gain = mu, logdens_se = se, clusters = G,
                               cells = nrow(m), cover95_inc = cov_inc, cover95_arm = cov_arm, B2 = b2, B3 = b3,
                               guards_ok = all(guards), accuracy = acc, bands = bands, ship = ship)
}
fwrite(rbindlist(verdicts), out_path("poll-record-compare.csv"))
cat("\nPWR9 wrote output/poll-record-compare.csv\n")
