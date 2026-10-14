# Seat-size spread table for AUSPOL_SIZE_SD (default "0" = off). 2026-10-14, NT calibration:
# favourites the model called 0.90-0.97 won 8 of 19 in NT (93.9% elsewhere), and the published path's
# share error relative to the simulation's own per-cell sd is ~2.0x in seats under 15,000 formal votes
# against ~1.0x in larger ones (scripts/diag_spread_by_size.R), outside NT as well as in it.
#
# For each target election, fitted TIME-FORWARD on every earlier election's published cells (pairs whose
# polling day is before the target's): ten equal-count bins of log formal votes; per bin
# ratio = RMS(actual - predicted) / RMS(1.10 + 8.67 sqrt(p(1-p))); weighted lm of log(ratio) on the bin's mean
# log formal votes. The slope is shrunk toward 0 by w = max(0, 1 - se^2 / b^2), and the widening is
# RELATIVE to the training cells' median seat size, so a seat at or above the median is unchanged:
#   factor(f) = max(1, exp(w * b * (log f - log f_median)))
# Writes output/spread-by-size.csv (target, n_cells, n_pairs, slope, se, w, f_median).
#   Rscript scripts/fit_spread_by_size.R
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
OUT <- "output"; source("scripts/ledger_inputs.R")
pb <- fread(file.path(OUT, "pooled-backtest.csv"))
S <- rbindlist(lapply(pb$pair, function(pr) { d <- tryCatch(run_table(pr, "sharedetail"), error = function(e) NULL)
  if (is.null(d) || !nrow(d)) return(NULL); if (!"pair" %in% names(d)) d[, pair := pr]; d[pair == pr] }), fill = TRUE)
C <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
fm <- C[, list(formal = sum(as.numeric(votes), na.rm = TRUE)), by = list(pair = election, seat)]
S <- merge(S, fm, by = c("pair", "seat"))
S <- S[is.finite(pred_share) & is.finite(actual_share) & pred_share >= 2 & formal > 0]
S[, p := pred_share / 100][, err := actual_share - pred_share][, sdm := 1.10 + 8.67 * sqrt(p * (1 - p))][, lf := log(formal)]
ed <- election_dates()
S[, day := as.Date(unname(ed[pair]))]
cat(sprintf("SPZ0  %d cells, %d elections (published path, pooled-backtest.csv runs)\n", nrow(S), uniqueN(S$pair)))
targets <- unique(c(pb$pair, "vic2026", "nsw2027", "fed2028"))
res <- rbindlist(lapply(targets, function(tg) {
  tday <- as.Date(unname(ed[tg])); if (is.na(tday)) return(NULL)
  tr <- S[S$day < tday]
  if (uniqueN(tr$pair) < 3L || nrow(tr) < 500L)
    return(data.table(target = tg, n_cells = nrow(tr), n_pairs = uniqueN(tr$pair), slope = 0, se = NA_real_, w = 0,
                      f_median = if (nrow(tr)) exp(stats::median(tr$lf)) else NA_real_))
  tr[, bin := cut(lf, unique(stats::quantile(lf, seq(0, 1, 0.1))), include.lowest = TRUE)]
  B <- tr[, list(n = .N, lf = mean(lf), ratio = sqrt(mean(err^2)) / sqrt(mean(sdm^2))), by = bin]
  f <- stats::lm(log(ratio) ~ lf, data = B, weights = n)
  b <- unname(stats::coef(f)[2]); se <- unname(sqrt(diag(stats::vcov(f)))[2])
  w <- if (is.finite(b) && is.finite(se) && b != 0) max(0, 1 - se^2 / b^2) else 0
  data.table(target = tg, n_cells = nrow(tr), n_pairs = uniqueN(tr$pair), slope = b, se = se, w = w,
             f_median = exp(stats::median(tr$lf)))
}))
res[, factor_5k := pmax(1, exp(w * slope * (log(5000) - log(f_median))))]
res[, factor_20k := pmax(1, exp(w * slope * (log(20000) - log(f_median))))]
print(res[, list(target, n_pairs, slope = round(slope, 3), se = round(se, 3), w = round(w, 2), f_median = round(f_median),
                 factor_5k = round(factor_5k, 2), factor_20k = round(factor_20k, 2))], nrows = 60)
fwrite(res, file.path(OUT, "spread-by-size.csv"))
cat(sprintf("SPZ1  wrote output/spread-by-size.csv (%d targets)\n", nrow(res)))
