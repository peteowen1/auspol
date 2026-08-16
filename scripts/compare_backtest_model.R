# Does the fuller trend model actually forecast better?
#
# Arm A: default volatility for every cycle -- what the published forecast
#        does today.
# Arm B: volatility estimated from each cycle's own polls up to the cutoff,
#        shrunk toward those defaults. Leakage-free by construction.
#
# Criterion, decision rule and the coverage guard are fixed in
# docs/plans/prereg-backtest-model.md, committed before this ran.
#
# Run from repo root:
#   powershell.exe -Command 'Rscript "scripts/compare_backtest_model.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

MATERIAL <- 0.02   # pre-registered: B must beat A by more than this
COVER    <- 0.05   # pre-registered: pair counts must agree within this

m_tpp <- fit_fundamentals(build_fundamentals_data(), "@TPP")
fund_loo <- data.table(year = m_tpp$data$year, region = m_tpp$data$region,
                       fund_tpp = m_tpp$data$actual - m_tpp$loo_errors)

arm <- function(sigmas) {
  t0 <- Sys.time()
  dat <- build_projection_data(sigmas = sigmas, verbose = FALSE)
  skipped <- attr(dat, "skipped")
  n_err <- if (!is.null(skipped) && nrow(skipped)) skipped[reason == "error", .N] else 0L
  dat <- merge(dat, fund_loo, by = c("year", "region"), all.x = TRUE)
  loo <- projection_loo(dat, debias = FALSE)
  stopifnot(is.data.frame(loo), nrow(loo) > 50, "err" %in% names(loo))
  cat(sprintf("  %-10s MAE %.4f   pairs %d   errors %d   (%.0f s)\n",
              sigmas, mean(abs(loo$err)), nrow(loo), n_err,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  list(mae = mean(abs(loo$err)), n = nrow(loo), n_err = n_err, loo = loo)
}

cat("=== does per-cycle volatility forecast better? ===\n")
A <- arm("default")
B <- arm("per_cycle")

# Rule 2: a model that silently drops cycles is not more accurate, it is
# fitted on an easier subset. Check coverage BEFORE looking at the MAE.
cover <- abs(B$n - A$n) / A$n
cat(sprintf("\ncoverage: A %d pairs, B %d pairs, difference %.1f%% (limit %.0f%%)\n",
            A$n, B$n, 100 * cover, 100 * COVER))
if (A$n_err > 0 || B$n_err > 0) {
  stop("A backtest arm skipped a pair with reason 'error' (A: ", A$n_err,
       ", B: ", B$n_err, "). That is a bug, not a thin cycle.")
}
if (cover > COVER) {
  stop(sprintf("Arm B covers %.1f%% fewer/more pairs than A, past the %.0f%% limit. Its MAE is not comparable.",
               100 * cover, 100 * COVER))
}

gain <- A$mae - B$mae
cat(sprintf("\nA (default)   %.4f\nB (per-cycle) %.4f\ngain %.4f\n",
            A$mae, B$mae, gain))
verdict <- if (gain > MATERIAL) {
  sprintf("ADOPT per-cycle (beats default by %.4f, clears the %.2f bar)", gain, MATERIAL)
} else {
  sprintf("KEEP default (gain %.4f does not clear the %.2f bar)", gain, MATERIAL)
}
cat(sprintf("\nG6  backtest model: %s\n", verdict))

# Registered up front: if the overall result is close, the per-horizon split
# is the more useful finding. The expectation was that per-cycle volatility
# helps at short horizons, where a cycle has many polls, and hurts at long
# ones, where it is estimated from very few.
cat("\n=== by horizon (registered as the interesting cut regardless) ===\n")
byh <- merge(
  A$loo[, .(A_mae = mean(abs(err)), n = .N), by = horizon],
  B$loo[, .(B_mae = mean(abs(err))), by = horizon], by = "horizon")
byh[, gain := round(A_mae - B_mae, 4)]
print(byh[order(horizon), .(horizon, n, A_mae = round(A_mae, 4),
                            B_mae = round(B_mae, 4), gain)])
