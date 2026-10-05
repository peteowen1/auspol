# Score the by-election level + departed arm against its baseline, as pre-registered in
# docs/plans/prereg-byelection-level-2026-10-05.md. Committed BEFORE the arm ran.
#
# Usage: Rscript scripts/score_byelection_level.R <baseline_snapshot_dir> <arm_snapshot_dir>
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
if (length(a) != 2L) stop("usage: score_byelection_level.R <baseline_dir> <arm_dir>")
rd <- function(d, f) { p <- file.path(d, f); if (!file.exists(p)) stop("missing ", p); fread(p, showProgress = FALSE) }
FA <- rd(a[1], "forecasts.csv"); FB <- rd(a[2], "forecasts.csv")
LA <- rd(a[1], "aef-comparison-full.csv"); LB <- rd(a[2], "aef-comparison-full.csv")
SA <- rd(a[1], "forecasts-seats.csv"); SB <- rd(a[2], "forecasts-seats.csv")
cat(sprintf("BL0 baseline %s: %d rows | arm %s: %d rows\n", a[1], nrow(FA), a[2], nrow(FB)))
stopifnot(nrow(FA) > 1000, nrow(FB) > 1000, nrow(LA) > 600, nrow(LB) > 600)
devtools::load_all("C:/dev/auspol", quiet = TRUE)
MAJ <- c("ALP", "LNP", "NAT")
k <- c("election", "seat", "party")
tgt_el <- unique(FA$election)
C0 <- fread("C:/dev/auspol/output/candidacies.csv", showProgress = FALSE)
# ---- target cells from the by-election winners table, for every forecast pair
W <- rbindlist(lapply(all_election_pairs(), function(pr) {
  if (!pr$election %in% tgt_el) return(NULL)
  bw <- tryCatch(byelection_winner_rows(pr$prev, pr$election), error = function(e) NULL)
  if (is.null(bw) || !nrow(bw)) return(NULL)
  bw <- as.data.table(bw)[, election := pr$election]
  P <- C0[C0$election == pr$prev & C0$elected %in% TRUE, .(.s = normalise_seat(seat), old_party = party)]
  bw[, .s := normalise_seat(seat)]
  merge(bw[, .(election, seat, .s, winner = name, party)], P, by = ".s", all.x = TRUE)
}))
if (is.null(W)) stop("BL1! no by-election winners found for any forecast election")
# map the seat spelling to the forecasts table's spelling
fs <- unique(FA[, .(election, seat, .s = normalise_seat(seat))])
W <- merge(W[, !"seat"], fs, by = c("election", ".s"))
A_cells <- unique(W[!party %in% MAJ, .(election, seat, party)])                      # non-major winners
B_cells <- unique(W[old_party %in% MAJ & old_party != party, .(election, seat, party = old_party)])   # majors that lost
cat(sprintf("BL1 target cells: A non-major winners %d; B majors that lost the seat %d\n", nrow(A_cells), nrow(B_cells)))
print(A_cells); print(B_cells)
stopifnot(nrow(A_cells) >= 3, nrow(B_cells) >= 3)
paired <- function(cells, label) {
  M <- merge(merge(cells, FA[, c(k, "xgb_pred", "actual_share"), with = FALSE], by = k),
             FB[, c(k, "xgb_pred"), with = FALSE], by = k, suffixes = c("_a", "_b"))
  miss <- fsetdiff(cells, M[, ..k])
  if (nrow(miss)) stop(label, "! ", nrow(miss), " cell(s) missing from a forecasts table: ", paste(do.call(paste, miss), collapse = "; "))
  M[, d := (actual_share - xgb_pred_b)^2 - (actual_share - xgb_pred_a)^2]
  D <- sum(M$d); se <- sd(M$d) * sqrt(nrow(M))
  cat(sprintf("\n%s: squared error %.1f -> %.1f, change %.1f, SE %.1f (n=%d)\n", label,
              sum((M$actual_share - M$xgb_pred_a)^2), sum((M$actual_share - M$xgb_pred_b)^2), D, se, nrow(M)))
  print(M[order(d), .(election, seat, party, base = round(xgb_pred_a, 1), arm = round(xgb_pred_b, 1), actual = round(actual_share, 1))], row.names = FALSE)
  c(D = D, se = se)
}
pA <- paired(A_cells, "BL2 PRIMARY (A)")
# 2 SE AND at least 20% of the baseline: a dry run on two snapshots that never
# touched these cells passed a 1-SE bar on noise (-115, SE 78, 3% of 3,627).
base_A <- sum((merge(A_cells, FA, by = k)[, (actual_share - xgb_pred)^2]))
cat(sprintf("BL2 => %s (needs change < -2 SE = %.1f and < -20%% of %.1f = %.1f)\n",
            if (pA[["D"]] < -2 * pA[["se"]] && pA[["D"]] < -0.2 * base_A) "PASS" else "FAIL",
            -2 * pA[["se"]], base_A, -0.2 * base_A))
pB <- paired(B_cells, "BL3 SECONDARY (B)")
cat(sprintf("BL3 => %s\n", if (pB[["D"]] <= pB[["se"]]) "HOLDS (not worse by more than 1 SE)" else "BREACHED"))
# ---- guards, as in score_defector_by_level.R
eps <- 1e-6
ll <- function(L) L[, .(pair, seat, ll = -log(pmax(eps, ifelse(is.na(our_p), eps, our_p))))]
G <- merge(ll(LA), ll(LB), by = c("pair", "seat"), suffixes = c("_a", "_b")); G[, d := ll_b - ll_a]
cl <- G[, .(s = sum(d), n = .N), by = pair]
gm <- sum(cl$s) / sum(cl$n); gse <- sqrt(nrow(cl) / (nrow(cl) - 1) * sum((cl$s - cl$n * gm)^2)) / sum(cl$n)
cat(sprintf("\nBL4 GUARD ledger log loss %.4f -> %.4f (change %+.4f, SE %.4f) => %s\n", mean(G$ll_a), mean(G$ll_b), gm, gse, if (gm <= gse) "HOLDS" else "BREACHED"))
Wt <- merge(FA[, c(k, "xgb_pred", "actual_share"), with = FALSE], FB[, c(k, "xgb_pred"), with = FALSE], by = k, suffixes = c("_a", "_b"))
Wt[, d := (actual_share - xgb_pred_b)^2 - (actual_share - xgb_pred_a)^2]
wc <- Wt[, .(s = sum(d), n = .N), by = election]
wm <- sum(wc$s) / sum(wc$n); wse <- sqrt(nrow(wc) / (nrow(wc) - 1) * sum((wc$s - wc$n * wm)^2)) / sum(wc$n)
cat(sprintf("BL5 GUARD whole-table RMSE %.3f -> %.3f (mean sq change %+.3f, SE %.3f) => %s\n",
            sqrt(mean((Wt$actual_share - Wt$xgb_pred_a)^2)), sqrt(mean((Wt$actual_share - Wt$xgb_pred_b)^2)), wm, wse, if (wm <= wse) "HOLDS" else "BREACHED"))
# ---- disqualifier: a by-election winner (A) who WON again must not lose > 0.05 win probability
Q <- merge(merge(A_cells, SA[, .(election, seat, party, p_a = win_prob, is_winner)], by = k), SB[, .(election, seat, party, p_b = win_prob)], by = k)
Q <- Q[is_winner %in% c(TRUE, 1, "TRUE")]
cat(sprintf("\nBL6 DISQUALIFIER non-major winners who won again (n=%d)\n", nrow(Q)))
if (!nrow(Q)) cat("BL6 => UNVERIFIABLE (counts as FIRES)\n") else {
  print(Q[, .(election, seat, party, p_a = round(p_a, 3), p_b = round(p_b, 3))], row.names = FALSE)
  cat(sprintf("BL6 => %s\n", if (any(Q$p_b < Q$p_a - 0.05)) "FIRES" else "does not fire"))
}
