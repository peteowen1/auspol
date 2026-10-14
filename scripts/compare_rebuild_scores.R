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
cat(sprintf("KX3 elections worse by more than %.2f (EXPLAIN each, then Pete decides; not an automatic refusal since 2026-10-13): %s\n",
            guard, if (nrow(bad)) paste(sprintf("%s %+.4f", bad$pair, bad$change), collapse = ", ") else "none"))

# ---- The scorer Pete set on 2026-10-13 (docs/plans/weighting-design-2026-10-13.md) ------------------------------------
# Seats within an election share one statewide polling error, so the independent unit is the election: SE by
# jackknife over elections; better/worse counts reported; AEF-7 is the primary view, 2010+ the second, pre-2010
# reported only.
AEF7 <- c("fed2022", "fed2025", "nsw2023", "qld2024", "sa2026", "vic2022", "wa2025")
M[, year := as.integer(sub("^[a-z]+", "", pair))]
votes <- tryCatch({
  cc <- fread("output/candidacies.csv", select = c("election", "votes"), showProgress = FALSE)
  cc[, .(v = sum(votes, na.rm = TRUE)), by = election]
}, error = function(e) NULL)
# DECIDING LINE (Pete, 2026-10-13, revised same day): each election weighted by the SQUARE ROOT of its total formal
# votes. Per person (votes) put federal at 69% of AEF-7 and vic2022 -- the published forecast's own state -- at 2.7%
# of the score, so a Victoria-only fix barely registered; sqrt keeps bigger elections heavier (4x the voters = 2x the
# weight) with federal at 49%. Per person and election-equal are printed beside it.
view <- function(lab, m) {
  if (nrow(m) < 2) { cat(sprintf("KX4 %-22s fewer than 2 elections\n", lab)); return(invisible()) }
  G <- nrow(m)
  w <- if (!is.null(votes)) votes$v[match(m$pair, votes$election)] else rep(NA_real_, G)
  if (!all(is.finite(w) & w > 0)) { cat(sprintf("KX4! %s: formal votes missing for %s; cannot weight per person\n", lab,
                                                paste(m$pair[!(is.finite(w) & w > 0)], collapse = ", "))); return(invisible()) }
  pp <- sum(w * m$change) / sum(w)          # per person, secondary
  w <- sqrt(w)                                # deciding weight
  wm <- function(i) sum(w[i] * m$change[i]) / sum(w[i])
  d <- wm(seq_len(G))
  th <- vapply(seq_len(G), function(i) wm(setdiff(seq_len(G), i)), 0)
  se <- sqrt((G - 1) / G * sum((th - mean(th))^2))
  verdict <- if (d < -se) "BETTER (beyond 1 SE)" else if (d > se) "WORSE (beyond 1 SE)" else "within noise"
  cat(sprintf("KX4 %-22s %2d elections | SQRT-VOTES change %+.4f (SE %.4f) => %-20s | better %2d, worse %2d, same %2d | per person %+.4f | election-equal %+.4f | federal share of weight %.0f%%\n",
              lab, G, d, se, verdict, sum(m$change < -1e-6), sum(m$change > 1e-6), sum(abs(m$change) <= 1e-6),
              pp, mean(m$change), 100 * sum(w[grepl("^fed", m$pair)]) / sum(w)))
}
view("AEF-7 (primary)", M[pair %in% AEF7])
view("2010 on (second)", M[year >= 2010])
view("all (reported)", M)
view("pre-2010 (reported)", M[year < 2010])
