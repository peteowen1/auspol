# Choose the sum-to-zero prior by held-out error, the way every other
# hyperparameter in this model is chosen.
#
# szc_sd_pts pins the level of the house effects -- how far the polling
# industry as a whole may sit from the truth. It was hand-set at 0.3 and never
# estimated, the only prior in the model still asserted rather than fitted.
#
# The rule, the grid and the materiality bar are fixed in
# docs/plans/prereg-szc-v2.md, written and committed BEFORE this ran. Do not
# edit them to fit a result; that is the whole point of the file existing.
#
# Slow: refits every cycle at every horizon, once per grid point. ~35 s each.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/tune_szc.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

GRID      <- c(0.3, 0.75, 1.5, 3.0)   # pre-registered
INCUMBENT <- 0.3                      # wins ties and near-ties
MATERIAL  <- 0.02                     # MAE a challenger must beat it by

cat("=== choosing szc_sd_pts by held-out error ===\n")
cat("grid:", paste(GRID, collapse = ", "),
    "  incumbent:", INCUMBENT, "  bar:", MATERIAL, "MAE\n\n")

# The fundamentals are independent of szc -- they use no polling -- so fit
# them ONCE outside the grid. Refitting per grid point would waste time and,
# worse, let a stochastic component vary between arms and be misattributed to
# the prior. Leave-one-out predictions, keyed by election, exactly as
# fit_projection.R builds them.
m_tpp <- fit_fundamentals(build_fundamentals_data(), "@TPP")
fund_loo <- data.table(year = m_tpp$data$year, region = m_tpp$data$region,
                       fund_tpp = m_tpp$data$actual - m_tpp$loo_errors)

res <- rbindlist(lapply(GRID, function(s) {
  t0 <- Sys.time()
  dat <- build_projection_data(szc_sd_pts = s, verbose = FALSE)
  dat <- merge(dat, fund_loo, by = c("year", "region"), all.x = TRUE)
  # projection_loo() returns one ROW PER held-out prediction, not a summary.
  # `loo$mae` is silently NULL, data.table() then drops the column, and
  # rbindlist(fill = TRUE) accepts the result without complaint -- so the whole
  # grid ran to completion twice, refitting every cycle, and produced a table
  # with no results in it. It failed four steps later on setorder, pointing at
  # a symptom rather than the cause. Assert the shape here instead.
  loo <- projection_loo(dat, debias = FALSE)
  stopifnot(is.data.frame(loo), nrow(loo) > 50, "err" %in% names(loo))
  mae <- mean(abs(loo$err))
  stopifnot(is.finite(mae))
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("  szc %.2f  held-out MAE %.4f  (n = %d pairs, %.0f s)\n",
              s, mae, nrow(loo), secs))
  data.table(szc = s, mae = mae, n = nrow(loo))
}), fill = TRUE)

# An arm that silently dropped out would leave a shorter table and a ranking
# over fewer values than were registered.
stopifnot(nrow(res) == length(GRID), "mae" %in% names(res),
          all(is.finite(res$mae)))
setorder(res, mae)
cat("\n=== ranked ===\n")
print(res[, .(szc, mae = round(mae, 4), n)])

inc_mae <- res[szc == INCUMBENT, mae]
best    <- res[1]
gain    <- inc_mae - best$mae

cat(sprintf("\nincumbent %.2f: %.4f\nbest %.2f: %.4f\ngain: %.4f\n",
            INCUMBENT, inc_mae, best$szc, best$mae, gain))

# Rule 2: the incumbent wins unless beaten by more than the materiality bar.
# Rule 5: among qualifying values within the bar of each other, take the
# smaller -- less freedom for the industry mean to absorb real signal.
if (best$szc == INCUMBENT || gain <= MATERIAL) {
  chosen <- INCUMBENT
  verdict <- sprintf("KEEP %.2f (gain %.4f does not clear the %.2f bar)",
                     INCUMBENT, gain, MATERIAL)
} else {
  qual <- res[inc_mae - mae > MATERIAL]
  chosen <- min(qual$szc)
  verdict <- sprintf("ADOPT %.2f (beats incumbent by %.4f; smallest of %d qualifying)",
                     chosen, inc_mae - res[szc == chosen, mae], nrow(qual))
}

cat(sprintf("\nG4  szc_sd_pts by held-out error: %s\n", verdict))
cat(sprintf("G4  n = %d election-horizon pairs, grid %s\n",
            best$n, paste(GRID, collapse = "/")))

# The value the package actually uses, so a divergence is visible rather than
# discovered later. formals() reads the shipped default without refitting.
current <- formals(fit_trend)$szc_sd_pts
cat(sprintf("G4  shipped default is %s; this run chose %.2f  %s\n",
            format(current), chosen,
            if (isTRUE(all.equal(as.numeric(current), chosen))) "AGREE"
            else "DISAGREE -- update fit_trend() or explain why not"))
