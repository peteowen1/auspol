# Generic arm scorer: baseline snapshot vs arm snapshot. Committed with its prereg BEFORE the arm runs.
#
# Usage: Rscript scripts/score_arm.R <baseline_dir> <arm_dir> [move_threshold=0.5] [regions=all]
# Target cells are those whose BASE_PRED (pre-xgb) moved by more than the threshold between the two runs:
# chosen from predictions only, never from the outcome. regions (e.g. "wa") restricts the target cells.
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
if (length(a) < 2L) stop("usage: score_arm.R <baseline_dir> <arm_dir> [threshold] [regions]")
thr <- if (length(a) >= 3) as.numeric(a[3]) else 0.5
reg <- if (length(a) >= 4 && a[4] != "all") strsplit(a[4], ",")[[1]] else NULL
rd <- function(d, f) { p <- file.path(d, f); if (!file.exists(p)) stop("missing ", p); fread(p, showProgress = FALSE) }
FA <- rd(a[1], "forecasts.csv"); FB <- rd(a[2], "forecasts.csv")
LA <- rd(a[1], "aef-comparison-full.csv"); LB <- rd(a[2], "aef-comparison-full.csv")
stopifnot(nrow(FA) > 1000, nrow(FB) > 1000)
k <- c("election", "seat", "party")
W <- merge(FA[, c(k, "region", "base_pred", "xgb_pred", "actual_share"), with = FALSE], FB[, c(k, "base_pred", "xgb_pred"), with = FALSE], by = k, suffixes = c("_a", "_b"))
cat(sprintf("SA0 matched %d rows (baseline %d, arm %d)\n", nrow(W), nrow(FA), nrow(FB)))
W[, d := (actual_share - xgb_pred_b)^2 - (actual_share - xgb_pred_a)^2]
T <- W[abs(base_pred_b - base_pred_a) > thr]   # base_pred: moves only where the mechanism acts (xgb retraining moves ~900 cells by noise)
if (!is.null(reg)) T <- T[region %in% reg]
cat(sprintf("SA1 target cells (base_pred moved > %.2f%s): %d in %d elections\n", thr,
            if (is.null(reg)) "" else paste0(", regions ", paste(reg, collapse = ",")), nrow(T), uniqueN(T$election)))
if (nrow(T) < 5) { cat("SA2 PRIMARY => NOT ASSESSABLE (fewer than 5 target cells): counts as FAIL
") } else {
D <- sum(T$d); se <- sd(T$d) * sqrt(nrow(T)); base <- sum((T$actual_share - T$xgb_pred_a)^2)
cat(sprintf("SA2 PRIMARY target squared error %.1f -> %.1f, change %.1f (%.0f%%), SE %.1f => %s\n",
            base, base + D, D, 100 * D / base, se,
            if (D < -2 * se && D < -0.1 * base) "PASS (< -2 SE and < -10%)" else "FAIL"))
print(T[, .(cells = .N, change = round(sum(d), 1)), by = election][order(change)], row.names = FALSE)
print(T[order(d)][c(1:min(8, .N), max(1, .N - 4):.N), .(election, seat, party, base = round(xgb_pred_a, 1), arm = round(xgb_pred_b, 1), actual = round(actual_share, 1))], row.names = FALSE)
}
eps <- 1e-6
ll <- function(L) L[, .(pair, seat, ll = -log(pmax(eps, ifelse(is.na(our_p), eps, our_p))))]
G <- merge(ll(LA), ll(LB), by = c("pair", "seat"), suffixes = c("_a", "_b")); G[, dd := ll_b - ll_a]
cl <- G[, .(s = sum(dd), n = .N), by = pair]
gm <- sum(cl$s) / sum(cl$n); gse <- sqrt(nrow(cl) / (nrow(cl) - 1) * sum((cl$s - cl$n * gm)^2)) / sum(cl$n)
cat(sprintf("SA3 GUARD ledger log loss %.4f -> %.4f (change %+.4f, SE %.4f) => %s\n", mean(G$ll_a), mean(G$ll_b), gm, gse, if (gm <= gse) "HOLDS" else "BREACHED"))
wc <- W[, .(s = sum(d), n = .N), by = election]
wm <- sum(wc$s) / sum(wc$n); wse <- sqrt(nrow(wc) / (nrow(wc) - 1) * sum((wc$s - wc$n * wm)^2)) / sum(wc$n)
cat(sprintf("SA4 GUARD whole-table RMSE %.3f -> %.3f (mean sq change %+.3f, SE %.3f) => %s\n",
            sqrt(mean((W$actual_share - W$xgb_pred_a)^2)), sqrt(mean((W$actual_share - W$xgb_pred_b)^2)), wm, wse, if (wm <= wse) "HOLDS" else "BREACHED"))
print(wc[, .(election, mean_sq_change = round(s / n, 3))][order(-mean_sq_change)][1:5], row.names = FALSE)
# ---- SA5: seat-winner log loss per election from forecasts-seats.csv (all pairs, incl. WA), paired by seat
SA <- rd(a[1], "forecasts-seats.csv"); SB <- rd(a[2], "forecasts-seats.csv")
wl <- function(S) S[is_winner %in% c(TRUE, 1, "TRUE"), .(election, seat, ll = -log(pmax(eps, win_prob)))]
P <- merge(wl(SA), wl(SB), by = c("election", "seat"), suffixes = c("_a", "_b"))
if (!is.null(reg)) P <- P[sub("[0-9]+$", "", election) %in% reg]
stopifnot(nrow(P) > 0)
pe <- P[, .(seats = .N, ll_base = round(mean(ll_a), 4), ll_arm = round(mean(ll_b), 4), change = round(mean(ll_b - ll_a), 4),
            se = round(sd(ll_b - ll_a) / sqrt(.N), 4)), by = election][order(change)]
cat(sprintf("\nSA5 seat-winner log loss (lower is better), %d seats in %d elections%s: %.4f -> %.4f\n", nrow(P), uniqueN(P$election),
            if (is.null(reg)) "" else paste0(" [", paste(reg, collapse = ","), "]"), mean(P$ll_a), mean(P$ll_b)))
print(pe, row.names = FALSE)
