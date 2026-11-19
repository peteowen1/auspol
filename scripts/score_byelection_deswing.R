# Scorer for docs/plans/prereg-byelection-deswing-2026-11-19.md: two full rebuilds (base = switch off, arm = on).
#   Rscript scripts/score_byelection_deswing.R <base output dir> <arm output dir>
# Reads each dir's published-predictions.csv (the published path, every class) and pooled-backtest.csv.
# Primary: squared error on the primary-vote cells of the by-election seats (both majors stood, non-zero swing to the
# by-election date), arm minus base, SE by jackknife over elections. Guard: pooled seat log loss (compare_rebuild_scores.R).
# Prints BDS* codes. Must be run from the repo root (reads the by-election table and polls).
suppressMessages({ library(data.table); devtools::load_all(".", quiet = TRUE) })
a <- commandArgs(TRUE); if (length(a) != 2L) stop("usage: Rscript scripts/score_byelection_deswing.R <base dir> <arm dir>")
rd <- function(d) { f <- file.path(d, "published-predictions.csv"); if (!file.exists(f)) stop("missing ", f); fread(f, showProgress = FALSE) }
B <- rd(a[1]); A <- rd(a[2])
cat(sprintf("BDS0 base %s: %d rows / %d elections; arm %s: %d rows / %d elections\n", a[1], nrow(B), uniqueN(B$pair), a[2], nrow(A), uniqueN(A$pair)))
if (!setequal(unique(B$pair), unique(A$pair))) cat(sprintf("BDS0! elections differ between base and arm: only base %s; only arm %s\n",
  paste(setdiff(unique(B$pair), unique(A$pair)), collapse = ","), paste(setdiff(unique(A$pair), unique(B$pair)), collapse = ",")))
# by-election seats the arm can move: both majors stood, and a non-zero ALP or LNP swing to the by-election date
tab <- byelection_table(); dts <- election_dates(); labs <- names(dts)[order(unlist(dts))]
cases <- list()
for (reg in unique(tab$region)) { L <- labs[sub("[0-9]{4}$", "", labs) == reg]; if (length(L) < 2) next
  for (i in 2:length(L)) { b <- byelections_between(L[i - 1], L[i], table = tab); if (!nrow(b)) next
    for (st in unique(b$seat[b$both_majors])) {
      cases[[length(cases) + 1]] <- data.table(pair = L[i], seat = st) } } }
cases <- unique(rbindlist(cases))
cat(sprintf("BDS1 by-election seats with both majors standing: %d in %d elections\n", nrow(cases), uniqueN(cases$pair)))
key <- c("pair", "seat", "party")
M <- merge(B[, .(pair, seat, party, actual, base = ours)], A[, .(pair, seat, party, arm = ours)], by = key)
M <- merge(M, cases, by = c("pair", "seat"))[!is.na(actual)]
moved <- M[, .(moved = any(abs(arm - base) > 0.05)), by = .(pair, seat)]
cat(sprintf("BDS2 scored by-election seats: %d (cells %d); seats the arm moved by > 0.05 pt: %d\n",
            uniqueN(M[, .(pair, seat)]), nrow(M), sum(moved$moved)))
if (!any(moved$moved)) { cat("BDS2! the arm moved NO by-election seat: it did not apply (check BYS1 in the arm's stage logs); no verdict\n"); quit(status = 2) }
M[, d := (arm - actual)^2 - (base - actual)^2]
per <- M[, .(n = .N, d = sum(d)), by = pair]
tot <- sum(per$d); G <- nrow(per)
th <- vapply(per$pair, function(p) sum(per$d[per$pair != p]), 0) * G / (G - 1)   # leave-one-out totals rescaled to G elections
se <- sqrt((G - 1) / G * sum((th - mean(th))^2))
cat(sprintf("BDS3 PRIMARY squared error, arm minus base: %+.1f (SE %.1f, jackknife over %d elections; base total %.1f) => %s\n",
            tot, se, G, sum((M$base - M$actual)^2), if (tot < -se) "lower by more than 1 SE: PASS" else "FAIL"))
cat(sprintf("BDS4 leave-one-election-out: primary still lower with any one election dropped: %s (worst %+.1f without %s)\n",
            if (all(th < 0)) "YES" else "NO", max(th), per$pair[which.max(th)]))
print(per[order(d), .(pair, cells = n, change = round(d, 1))], nrows = 60)
# seat log loss on the by-election seats themselves (unacceptable-win clause)
sl <- function(d) { f <- file.path(d, "published-predictions.csv"); x <- fread(f, showProgress = FALSE)
  x <- merge(x, cases, by = c("pair", "seat")); x[won %in% TRUE, .(ll = -log(pmax(sum(p_win), 1e-6))), by = .(pair, seat)] }
LB <- sl(a[1]); LA <- sl(a[2]); L <- merge(LB, LA, by = c("pair", "seat"), suffixes = c("_b", "_a"))
lp <- L[, .(d = sum(ll_a - ll_b), n = .N), by = pair]; tl <- sum(lp$d) / sum(lp$n)
thl <- vapply(lp$pair, function(p) sum(lp$d[lp$pair != p]) / sum(lp$n[lp$pair != p]), 0)
sel <- sqrt((nrow(lp) - 1) / nrow(lp) * sum((thl - mean(thl))^2))
cat(sprintf("BDS5 by-election seats' own seat log loss, arm minus base: %+.4f per seat (SE %.4f, %d seats) => %s\n",
            tl, sel, nrow(L), if (tl > sel) "RISES by more than 1 SE: unacceptable-win clause, to Pete" else "not worse by more than 1 SE"))
cat("BDS6 guard: run Rscript scripts/compare_rebuild_scores.R <base>/pooled-backtest.csv <arm>/pooled-backtest.csv\n")
