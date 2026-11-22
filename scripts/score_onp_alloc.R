# Scorer for docs/plans/prereg-onp-direct-model-2026-11-22.md, Amendment 1: two full rebuilds (base, arm).
#   Rscript scripts/score_onp_alloc.R <base output dir> <arm output dir>
# Reads each dir's published-predictions.csv (the published path: every class, after the trees). Prints OAS* codes.
# Primary: squared error on One Nation's seat primary over the cells the arm moved, arm minus base, SE by jackknife
# over elections. Then leave-one-election-out, the sa2026 / qld2024 seat log loss clause (SE over seats), and the
# seats One Nation won. The pooled seat log loss guard is scripts/compare_rebuild_scores.R on the two pooled-backtest.csv.
suppressMessages(library(data.table))
a <- commandArgs(TRUE); if (length(a) != 2L) stop("usage: Rscript scripts/score_onp_alloc.R <base dir> <arm dir>")
rd <- function(d) { f <- file.path(d, "published-predictions.csv"); if (!file.exists(f)) stop("missing ", f); fread(f, showProgress = FALSE) }
B <- rd(a[1]); A <- rd(a[2])
cat(sprintf("OAS0 base %s: %d rows / %d elections; arm %s: %d rows / %d elections\n", a[1], nrow(B), uniqueN(B$pair), a[2], nrow(A), uniqueN(A$pair)))
if (!setequal(unique(B$pair), unique(A$pair))) cat(sprintf("OAS0! elections differ: only base %s; only arm %s\n",
  paste(setdiff(unique(B$pair), unique(A$pair)), collapse = ","), paste(setdiff(unique(A$pair), unique(B$pair)), collapse = ",")))
key <- c("pair", "seat", "party")
if (anyDuplicated(B[, ..key]) || anyDuplicated(A[, ..key])) stop("OAS0! duplicated (pair, seat, party) rows")
M <- merge(B[, .(pair, seat, party, actual, won, base = ours, p_base = p_win)], A[, .(pair, seat, party, arm = ours, p_arm = p_win)], by = key)
if (nrow(M) != nrow(B) || nrow(M) != nrow(A)) cat(sprintf("OAS0! rows: base %d, arm %d, matched %d\n", nrow(B), nrow(A), nrow(M)))
O <- M[M$party == "ONP" & !is.na(M$actual) & !is.na(M$base) & !is.na(M$arm)]
O[, moved := abs(arm - base) > 0.05]
cat(sprintf("OAS1 One Nation cells with a result: %d in %d elections; moved by the arm (> 0.05 pt): %d in %d elections\n",
            nrow(O), uniqueN(O$pair), sum(O$moved), uniqueN(O$pair[O$moved])))
if (!any(O$moved)) { cat("OAS1! the arm moved NO One Nation cell: it did not apply (look for ONM1 / ONT1 in the arm's logs); no verdict\n"); quit(status = 2) }
S <- O[O$moved]
S[, d := (arm - actual)^2 - (base - actual)^2]
pe <- S[, .(cells = .N, base_sq = sum((base - actual)^2), change = sum(d)), by = pair]
G <- nrow(pe); tot <- sum(pe$change)
loo <- tot - pe$change
se <- if (G >= 2) sqrt((G - 1) / G * sum((loo - mean(loo))^2)) else NA_real_
cat(sprintf("OAS2 PRIMARY squared error on the moved One Nation cells, arm minus base: %+.1f of a base total %.1f (%+.1f%%), SE %.1f (jackknife over %d elections) => %s\n",
            tot, sum(pe$base_sq), 100 * tot / sum(pe$base_sq), se, G,
            if (!is.finite(se)) "NO SE (fewer than 2 elections)" else if (tot < -se) "lower by more than 1 SE: PASS" else if (tot > se) "HIGHER by more than 1 SE: FAIL" else "within 1 SE: FAIL (not lower by more than 1 SE)"))
cat(sprintf("OAS3 leave-one-election-out: primary still lower with any one election dropped: %s (worst %+.1f without %s)\n",
            if (all(loo < 0)) "YES" else "NO", max(loo), pe$pair[which.max(loo)]))
print(pe[order(change), .(pair, cells, base_sq = round(base_sq, 1), change = round(change, 1))], nrows = 60)
cat(sprintf("OAS4 One Nation share RMSE, every One Nation cell with a result (%d): base %.3f, arm %.3f\n", nrow(O), sqrt(mean((O$base - O$actual)^2)), sqrt(mean((O$arm - O$actual)^2))))
# seat log loss by seat from the winner's row; clamp 1e-6 as everywhere
W <- M[M$won %in% TRUE & !is.na(M$p_base) & !is.na(M$p_arm)]
W[, dl := -log(pmax(p_arm, 1e-6)) + log(pmax(p_base, 1e-6))]
for (p in c("sa2026", "qld2024")) { w <- W[W$pair == p]
  if (!nrow(w)) { cat(sprintf("OAS5! %s: no winner rows -- clause cannot be read\n", p)); next }
  m <- mean(w$dl); s <- stats::sd(w$dl) / sqrt(nrow(w))
  cat(sprintf("OAS5 %s seat log loss, arm minus base: %+.4f (SE %.4f over %d seats) => %s\n", p, m, s, nrow(w),
              if (m > s) "WORSE by more than 1 SE: the unacceptable-win clause TRIPS" else "not worse by more than 1 SE")) }
ow <- W[W$party == "ONP"]
if (nrow(ow)) { ow[, dp := p_arm - p_base]
  cat(sprintf("OAS6 seats One Nation won: %d; largest fall in its win probability %+.3f (%s %s) => %s\n", nrow(ow), min(ow$dp), ow$pair[which.min(ow$dp)], ow$seat[which.min(ow$dp)],
              if (min(ow$dp) < -0.10) "a won seat lost more than 0.10: the clause TRIPS" else "none lost more than 0.10"))
  print(ow[order(dp), .(pair, seat, p_base = round(p_base, 3), p_arm = round(p_arm, 3))], nrows = 40)
} else cat("OAS6! no seat won by One Nation in the scored set -- clause cannot be read\n")
cat("OAS7 guard: Rscript scripts/compare_rebuild_scores.R <base>/pooled-backtest.csv <arm>/pooled-backtest.csv\n")
