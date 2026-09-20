# What a smoke run moved. Companion of scripts/smoke_pair.sh.
#   Rscript scripts/smoke_diff.R <harness> [pair-year]
# Compares the newest *-smoke sharedetail for the harness against the
# reference: the newest NON-smoke, xgb-OFF sharedetail for the same pair(s)
# (the last rebuild's stage-1 file). Prints per-class RMSE against the
# actual result before and after, and the cells that moved most.
suppressMessages(library(data.table))
a <- commandArgs(TRUE); H <- a[1]; PAIR <- if (length(a) > 1 && nzchar(a[2])) a[2] else ""
OUT <- "output"
files <- list.files(OUT, pattern = sprintf("^backtest-%s.*-sharedetail.*[.]csv$", H), full.names = TRUE)
files <- files[!grepl("pooled", files)]
# The harness names files by an arm fingerprint plus the sim count when it is
# not the default, so a smoke run is the newest file tagged -n<SMOKE_SIMS>-
# and the reference is the newest file with NO sim tag (a default 20,000-sim
# run: the last rebuild's stage 1).
sims <- Sys.getenv("AUSPOL_SMOKE_SIMS", "500")
smoke <- files[grepl(sprintf("-n%s-", sims), files)]; ref <- files[!grepl("-n[0-9]+-", files)]
if (!length(smoke)) stop("SD0! no smoke sharedetail (-n", sims, "-) for ", H)
smoke <- smoke[which.max(file.mtime(smoke))]
S <- fread(smoke, showProgress = FALSE)
if ("xgb_primary_on" %in% names(S) && any(S$xgb_primary_on == 1)) stop("SD0! the smoke file has the xgb layer ON; smoke_pair.sh sets AUSPOL_XGB_PRIMARY=0")
pairs <- unique(S$pair); if (nzchar(PAIR)) pairs <- pairs[grepl(PAIR, pairs)]
R <- rbindlist(lapply(ref, function(f) { d <- fread(f, showProgress = FALSE); d[, file := basename(f)]; d[, mtime := file.mtime(f)]; d }), fill = TRUE)
R <- R[pair %in% pairs & (!"xgb_primary_on" %in% names(R) | xgb_primary_on == 0 | is.na(xgb_primary_on))]
if (!nrow(R)) stop("SD0! no xgb-off reference sharedetail for ", paste(pairs, collapse = ","))
R <- R[, .SD[mtime == max(mtime)], by = pair]
cat(sprintf("SD1  smoke %s vs reference %s\n", basename(smoke), paste(unique(R$file), collapse = ", ")))
M <- merge(S[pair %in% pairs, .(pair, seat, party, new = pred_share, actual = actual_share)],
           R[, .(pair, seat, party, old = pred_share)], by = c("pair", "seat", "party"))
M[, d := new - old]
cat(sprintf("SD2  %d cells compared, %d moved by more than 0.05 points, mean |move| %.3f\n", nrow(M), sum(abs(M$d) > 0.05), mean(abs(M$d))))
by <- M[, .(n = .N, moved = sum(abs(d) > 0.05), rmse_old = sqrt(mean((old - actual)^2)), rmse_new = sqrt(mean((new - actual)^2))), by = .(pair, party)]
by[, delta := round(rmse_new - rmse_old, 3)]
cat("SD3  per class RMSE against the actual result (points, lower is better; delta < 0 is an improvement)\n")
print(by[order(pair, delta)][, .(pair, party, n, moved, rmse_old = round(rmse_old, 2), rmse_new = round(rmse_new, 2), delta)])
tot <- M[, .(rmse_old = sqrt(mean((old - actual)^2)), rmse_new = sqrt(mean((new - actual)^2)))]
cat(sprintf("SD3  all cells: RMSE %.3f -> %.3f (%+.3f)\n", tot$rmse_old, tot$rmse_new, tot$rmse_new - tot$rmse_old))
cat("SD4  largest moves (old -> new, actual):\n")
print(M[order(-abs(d))][1:min(15, .N), .(pair, seat, party, old = round(old, 1), new = round(new, 1), actual = round(actual, 1), move = round(d, 1))])
