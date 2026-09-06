# Score the emergence test: does Google Trends separate a non-major who WON a
# seat the model called hopeless from one who stood and lost?
#
# Reported four ways, because pooling them would hide the things that matter:
#
#   1. ALL rows -- the headline, and the least trustworthy.
#   2. INCUMBENT-ANCHORED only. A ratio against the sitting member and a ratio
#      against the prime minister are not the same measurement and must not be
#      averaged. The PM fallback is used exactly when the incumbent retired,
#      which is also when these seats fall, so the two groups are not random
#      subsets of each other either.
#   3. WITHOUT the hand-added row. Allegra Spender was added at Pete's request
#      as a case he can check by eye; the model already gave her 0.396, so she
#      is not a model failure and counting her among them would flatter the
#      signal.
#   4. 2016 ONWARD. The 2010 queries all returned 0.000, which is more likely a
#      dead window -- Trends volume was far lower then, and a 7-day span at that
#      vintage may return nothing -- than a real reading. Averaging structural
#      zeros into an AUC would understate a signal rather than measure it.
#
# Emits SE* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

R <- fread("output/emergence-trends.csv", showProgress = FALSE)
H <- fread("output/emergence-test.csv", showProgress = FALSE)
if ("hand_added" %in% names(H))
  R <- merge(R, unique(H[, .(seat, election, hand_added)]),
             by = c("seat", "election"), all.x = TRUE)
if (!"hand_added" %in% names(R)) R[, hand_added := FALSE]
R[is.na(hand_added), hand_added := FALSE]

auc_of <- function(d) {
  d <- d[is.finite(ratio)]
  a <- sum(d$grp == "A_won"); b <- nrow(d) - a
  if (a < 3 || b < 3) return(list(auc = NA_real_, n1 = a, n0 = b, p = NA_real_))
  rk <- rank(d$ratio)
  list(auc = (sum(rk[d$grp == "A_won"]) - a * (a + 1) / 2) / (a * b),
       n1 = a, n0 = b,
       p = suppressWarnings(wilcox.test(d[grp == "A_won", ratio],
                                        d[grp == "B_lost", ratio])$p.value))
}
report <- function(d, label) {
  r <- auc_of(d)
  if (is.na(r$auc)) {
    cat(sprintf("  %-34s too few rows (%d won, %d lost)\n", label, r$n1, r$n0))
  } else {
    cat(sprintf("  %-34s AUC %.3f | %2d won vs %2d lost | p %.3f\n",
                label, r$auc, r$n1, r$n0, r$p))
  }
}

cat(sprintf("SE1  %d rows, %d with a usable ratio\n\n",
            nrow(R), sum(is.finite(R$ratio))))

cat("SE2  ratio distribution by group (usable rows only)\n")
print(R[is.finite(ratio), .(n = .N,
                            zero = sum(ratio == 0),
                            median = round(median(ratio), 3),
                            mean = round(mean(ratio), 3),
                            max = round(max(ratio), 3)), by = grp],
      row.names = FALSE)

cat("\nSE3  AUC, cut four ways\n")
report(R,                                   "all rows")
report(R[anchor_type == "incumbent"],       "incumbent-anchored only")
report(R[hand_added == FALSE],              "excluding the hand-added row")
report(R[election != "fed2010"],            "2013 onward (2010 all zero)")
report(R[election %in% c("fed2016","fed2019","fed2022","fed2025")],
                                            "2016 onward")
report(R[anchor_type == "incumbent" & hand_added == FALSE &
           election %in% c("fed2016","fed2019","fed2022","fed2025")],
                                            "incumbent + no hand-add + 2016 on")

cat("\nSE4  the winners, loudest first -- the seats this exists to fix\n")
print(R[grp == "A_won"][order(-ratio)][,
        .(election, seat, name, pct = round(pcv, 1), our_p = round(our_p, 4),
          anchor, ratio = round(ratio, 3), anchor_type)], row.names = FALSE)

cat("\nSE5  the loudest LOSERS -- false positives cost seats too\n")
print(head(R[grp == "B_lost"][order(-ratio)][,
        .(election, seat, name, pct = round(pcv, 1),
          anchor, ratio = round(ratio, 3))], 10), row.names = FALSE)
