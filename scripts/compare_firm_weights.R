# Does down-weighting noisy pollsters improve the forecast?
#
# Arm A: every poll weighted equally -- what the published forecast does.
# Arm B: two-pass. Fit with equal weights, estimate each firm's noise from
#        THIS cycle's own residuals, refit with those weights. Leakage-free by
#        construction; see docs/plans/prereg-firm-factors.md for why the
#        cross-cycle version is out of scope.
#
# Criterion, bar and coverage guard fixed in that pre-registration, committed
# before this ran. The expectation on record is that it FAILS: per-cycle
# volatility, the same family of change, gained 0.0041 for 33x the runtime.
#
# Run from repo root:
#   powershell.exe -Command 'Rscript "scripts/compare_firm_weights.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

MATERIAL <- 0.02   # pre-registered
COVER    <- 0.05   # pre-registered

m_tpp <- fit_fundamentals(build_fundamentals_data(), "@TPP")
fund_loo <- data.table(year = m_tpp$data$year, region = m_tpp$data$region,
                       fund_tpp = m_tpp$data$actual - m_tpp$loo_errors)

arm <- function(weights) {
  t0 <- Sys.time()
  dat <- build_projection_data(weights = weights, verbose = FALSE)
  skipped <- attr(dat, "skipped")
  n_err <- if (!is.null(skipped) && nrow(skipped)) skipped[reason == "error", .N] else 0L
  dat <- merge(dat, fund_loo, by = c("year", "region"), all.x = TRUE)
  loo <- projection_loo(dat, debias = FALSE)
  stopifnot(is.data.frame(loo), nrow(loo) > 50, "err" %in% names(loo))
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("  %-13s MAE %.4f   pairs %d   errors %d   (%.0f s)\n",
              weights, mean(abs(loo$err)), nrow(loo), n_err, secs))
  list(mae = mean(abs(loo$err)), n = nrow(loo), n_err = n_err,
       loo = loo, secs = secs)
}

cat("=== does down-weighting noisy pollsters help? ===\n")
A <- arm("equal")
B <- arm("firm_factors")

# Coverage BEFORE accuracy: an arm that quietly drops difficult cycles is
# fitted on an easier subset, not more accurate.
cover <- abs(B$n - A$n) / A$n
cat(sprintf("\ncoverage: A %d pairs, B %d pairs, difference %.1f%% (limit %.0f%%)\n",
            A$n, B$n, 100 * cover, 100 * COVER))
if (A$n_err > 0 || B$n_err > 0) {
  stop("An arm skipped a pair with reason 'error' (A: ", A$n_err, ", B: ",
       B$n_err, "). That is a bug, not a thin cycle.")
}
if (cover > COVER) {
  stop(sprintf("Arm B covers %.1f%% more/fewer pairs than A, past the %.0f%% limit; the MAEs are not comparable.",
               100 * cover, 100 * COVER))
}

gain <- A$mae - B$mae
cat(sprintf("\nA (equal weights) %.4f\nB (firm factors)  %.4f\ngain %.4f   runtime %.1fx\n",
            A$mae, B$mae, gain, B$secs / A$secs))
verdict <- if (gain > MATERIAL) {
  sprintf("ADOPT firm factors (beats equal weighting by %.4f, clears the %.2f bar)",
          gain, MATERIAL)
} else {
  sprintf("KEEP equal weights (gain %.4f does not clear the %.2f bar)",
          gain, MATERIAL)
}
cat(sprintf("\nG8  poll weighting: %s\n", verdict))

# Registered in advance as reportable regardless: alternating signs across
# horizons are noise, not a regime where the change helps.
cat("\n=== by horizon (reported regardless of the headline) ===\n")
byh <- merge(A$loo[, .(A_mae = mean(abs(err)), n = .N), by = horizon],
             B$loo[, .(B_mae = mean(abs(err))), by = horizon], by = "horizon")
byh[, gain := round(A_mae - B_mae, 4)]
print(byh[order(horizon), .(horizon, n, A_mae = round(A_mae, 4),
                            B_mae = round(B_mae, 4), gain)])
