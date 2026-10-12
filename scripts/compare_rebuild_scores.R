# Compare two rebuilds' per-election seat log loss (pooled-backtest.csv from scripts/pool_backtests.R).
# Used for docs/plans/prereg-own-poll-source-step2-2026-10-12.md, where the arm needs a full rebuild in an isolated
# worktree. Seat log loss = minus the log of the probability given to the winner; lower is better.
# Run: Rscript scripts/compare_rebuild_scores.R <baseline pooled-backtest.csv> <arm pooled-backtest.csv> [guard]
# Emits KX* codes.
suppressMessages(library(data.table))
a <- commandArgs(TRUE); stopifnot(length(a) >= 2)
guard <- if (length(a) >= 3) as.numeric(a[3]) else 0.02
B <- fread(a[1]); A <- fread(a[2])
cat(sprintf("KX0 baseline %s (code %s), arm %s (code %s)\n", a[1], paste(unique(B$code), collapse = ","), a[2], paste(unique(A$code), collapse = ",")))
M <- merge(B[, .(pair, n_b = n, ll_b = logloss)], A[, .(pair, n_a = n, ll_a = logloss)], by = "pair")
if (nrow(M) != nrow(B) || nrow(M) != nrow(A)) cat(sprintf("KX1! elections: baseline %d, arm %d, common %d\n", nrow(B), nrow(A), nrow(M)))
if (any(M$n_b != M$n_a)) { cat("KX1! seat counts differ:\n"); print(M[n_b != n_a]) }
pooled <- function(ll, n) sum(ll * n) / sum(n)
d_full <- pooled(M$ll_a, M$n_a) - pooled(M$ll_b, M$n_b)
th <- vapply(M$pair, function(p) { m <- M$pair != p; pooled(M$ll_a[m], M$n_a[m]) - pooled(M$ll_b[m], M$n_b[m]) }, 0)
G <- nrow(M); se <- sqrt((G - 1) / G * sum((th - mean(th))^2))
cat(sprintf("KX2 pooled seat log loss over %d seats / %d elections: baseline %.4f, arm %.4f, change %+.4f (SE %.4f, jackknife over elections) => %s\n",
            sum(M$n_a), G, pooled(M$ll_b, M$n_b), pooled(M$ll_a, M$n_a), d_full, se,
            if (d_full <= se) "no worse than +1 SE: PASS" else "worse by more than 1 SE: FAIL"))
M[, change := ll_a - ll_b]
print(M[order(-change), .(pair, seats = n_a, baseline = round(ll_b, 4), arm = round(ll_a, 4), change = round(change, 4))], nrows = 40)
bad <- M[M$change > guard]
cat(sprintf("KX3 guard: elections worse by more than %.2f: %s\n", guard, if (nrow(bad)) paste(sprintf("%s %+.4f", bad$pair, bad$change), collapse = ", ") else "none"))
