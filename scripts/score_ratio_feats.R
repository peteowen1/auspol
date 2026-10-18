# Score AUSPOL_XGB_RATIO_FEATS on docs/plans/prereg-growth-ratio-features-2026-10-18.md's terms: two isolated
# rebuilds from stage 3 (same inputs, switch off vs on). Primary: seat share RMSE of the published path on the
# minor classes (ONP, IND, OTH_RIGHT, OTH, GRN), SE clustered on election (jackknife); guard: seat log loss and
# ALP/LNP share RMSE. Lower is better everywhere. Codes GRF0-GRF6.
#   Rscript scripts/score_ratio_feats.R <baseline repo copy> <arm repo copy>
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
if (length(a) != 2) stop("usage: score_ratio_feats.R <baseline repo copy> <arm repo copy>")
rd <- function(d) {
  p <- fread(file.path(d, "output", "published-predictions.csv"))
  b <- fread(file.path(d, "output", "pooled-backtest.csv"))
  list(p = p[is.finite(actual)], b = b)
}
B <- rd(a[1]); A <- rd(a[2])
cat(sprintf("GRF0 baseline %d rows / %d elections (code %s); arm %d rows / %d elections (code %s)\n",
            nrow(B$p), uniqueN(B$p$pair), paste(unique(B$b$code), collapse = ","), nrow(A$p), uniqueN(A$p$pair), paste(unique(A$b$code), collapse = ",")))
m <- merge(B$p[, .(pair, seat, party, actual, base = ours)], A$p[, .(pair, seat, party, arm = ours)], by = c("pair", "seat", "party"))
cat(sprintf("GRF1 %d cells matched in both\n", nrow(m)))
jk <- function(x, f) {   # election-jackknife SE of a statistic f(x) of the paired cells
  els <- unique(x$pair); G <- length(els); full <- f(x)
  th <- vapply(els, function(e) f(x[pair != e]), 0)
  c(est = full, se = sqrt((G - 1) / G * sum((th - mean(th))^2)))
}
rmse_d <- function(x) sqrt(mean((x$arm - x$actual)^2)) - sqrt(mean((x$base - x$actual)^2))
MIN <- c("ONP", "IND", "OTH_RIGHT", "OTH", "GRN")
pr <- function(lab, x) {
  r <- jk(x, rmse_d)
  cat(sprintf("  %-34s cells %5d | RMSE base %.3f arm %.3f | arm-base %+.4f (SE %.4f)%s\n", lab, nrow(x),
              sqrt(mean((x$base - x$actual)^2)), sqrt(mean((x$arm - x$actual)^2)), r["est"], r["se"],
              if (r["est"] < -r["se"]) "  arm better by >1 SE" else if (r["est"] > r["se"]) "  arm WORSE by >1 SE" else "  within 1 SE"))
  invisible(r)
}
cat("GRF2 seat share RMSE, points (lower is better), SE by election jackknife:\n")
r1 <- pr("PRIMARY: minor classes", m[party %in% MIN])
for (k in MIN) pr(paste0("  ", k), m[party == k])
rg <- pr("GUARD: ALP + LNP", m[party %in% c("ALP", "LNP")])
pr("surge elections (sa2026 wa2025 qld2017)", m[party %in% MIN & pair %in% c("sa2026", "wa2025", "qld2017")])
pr("collapse elections (wa2021 qld2020)", m[party %in% MIN & pair %in% c("wa2021", "qld2020")])
bb <- merge(B$b[, .(pair, ll_b = logloss)], A$b[, .(pair, ll_a = logloss, n)], by = "pair")
G <- nrow(bb); d <- weighted.mean(bb$ll_a - bb$ll_b, bb$n)
th <- vapply(seq_len(G), function(i) weighted.mean((bb$ll_a - bb$ll_b)[-i], bb$n[-i]), 0)
se <- sqrt((G - 1) / G * sum((th - mean(th))^2))
cat(sprintf("GRF3 GUARD seat log loss, %d elections: base %.4f arm %.4f, arm-base %+.4f (SE %.4f) -> %s\n", G,
            weighted.mean(bb$ll_b, bb$n), weighted.mean(bb$ll_a, bb$n), d, se, if (d > se) "FAILS" else "passes"))
pe <- m[party %in% MIN, .(d = sum((arm - actual)^2) - sum((base - actual)^2)), by = pair][order(d)]
net <- sum(pe$d); top <- if (net < 0) max(pe$d / net) else NA
cat(sprintf("GRF4 REFUSAL one election > half the primary gain: largest share %s (%s) -> %s\n", format(round(top, 2)),
            if (is.na(top)) "-" else pe$pair[which.max(pe$d / net)], if (is.na(top)) "no net gain" else if (top > 0.5) "REFUSED" else "passes"))
cat("GRF5 fed2025 One Nation by previous-share band and Melbourne (reported):\n")
C <- fread(file.path(a[1], "output", "candidacies.csv"))
nb <- fread(file.path(a[1], "output", "notional-baselines.csv"))[election == "fed2025" & party == "ONP", .(seat, prev = pcv)]
f25 <- merge(m[pair == "fed2025" & party == "ONP"], nb, by = "seat")
print(f25[, .(cells = .N, actual = round(mean(actual), 1), base = round(mean(base), 1), arm = round(mean(arm), 1)),
          by = .(band = cut(prev, c(-1, 1, 3, 6, 10, 100)))][order(band)])
print(m[pair == "fed2025" & seat == "Melbourne", .(party, actual = round(actual, 1), base = round(base, 1), arm = round(arm, 1))])
cat(sprintf("GRF6 VERDICT: primary %s; guard %s\n",
            if (r1["est"] < -r1["se"]) "arm better than baseline by more than 1 SE" else "arm NOT better by more than 1 SE",
            if (d > se || rg["est"] > rg["se"]) "FAILS" else "passes"))
