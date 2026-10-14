# Does the published path's primary-share error grow as seats get smaller? (NT calibration, 2026-10-14)
# Every pair's scored sharedetail (scripts/ledger_inputs.R) joined to the seat's formal votes at the target
# election (output/candidacies.csv). z = (actual - predicted) / sqrt(p(1-p)), p = predicted share; the
# simulation's per-cell spread is 1.10 + 8.67 * sqrt(p(1-p)), so a z spread that rises as seats shrink means
# the shipped spread is too narrow for small seats.
#   Rscript scripts/diag_spread_by_size.R
suppressMessages(library(data.table))
OUT <- "output"; source("scripts/ledger_inputs.R")
pb <- fread(file.path(OUT, "pooled-backtest.csv"))
S <- rbindlist(lapply(pb$pair, function(pr) { d <- tryCatch(run_table(pr, "sharedetail"), error = function(e) NULL)
  if (is.null(d) || !nrow(d)) return(NULL); if (!"pair" %in% names(d)) d[, pair := pr]; d[pair == pr] }), fill = TRUE)
C <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
fm <- C[, list(formal = sum(as.numeric(votes), na.rm = TRUE)), by = list(pair = election, seat)]
S <- merge(S, fm, by = c("pair", "seat"))
S <- S[is.finite(pred_share) & is.finite(actual_share) & pred_share >= 2 & formal > 0]
cat(sprintf("SBS0 %d cells, %d seats, %d elections with a formal-vote count\n", nrow(S), uniqueN(S[, paste(pair, seat)]), uniqueN(S$pair)))
S[, p := pred_share / 100][, err := actual_share - pred_share][, z := err / sqrt(p * (1 - p))]
S[, sd_model := 1.10 + 8.67 * sqrt(p * (1 - p))]
S[, size := cut(formal, c(0, 8000, 15000, 30000, 60000, Inf), labels = c("<8k", "8-15k", "15-30k", "30-60k", "60k+"))]
cat("RMS error / the simulation's own sd for that cell: 1.00 = spread right, above 1 = spread too narrow\n")
print(S[, list(cells = .N, seats = uniqueN(paste(pair, seat)), rmse = round(sqrt(mean(err^2)), 2),
               sd_model = round(sqrt(mean(sd_model^2)), 2), ratio = round(sqrt(mean(err^2)) / sqrt(mean(sd_model^2)), 2),
               nt_share = round(mean(startsWith(pair, "nt")), 2)), by = size][order(size)])
cat("\nMajors only (ALP, LNP):\n")
print(S[party %in% c("ALP", "LNP"), list(cells = .N, ratio = round(sqrt(mean(err^2)) / sqrt(mean(sd_model^2)), 2)), by = size][order(size)])
cat("\nNon-NT only (does size matter outside NT?):\n")
print(S[!startsWith(pair, "nt"), list(cells = .N, ratio = round(sqrt(mean(err^2)) / sqrt(mean(sd_model^2)), 2)), by = size][order(size)])
