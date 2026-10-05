# Read-only comparison for docs/plans/prereg-salience-fed-nsw-onoff-2026-10-03.md.
# Written and committed BEFORE the ON arms were read. Usage:
#   Rscript scripts/compare_salience_onoff.R <fed|nsw> <on_summary.csv> <off_summary.csv> \
#                                            <on_sharedetail.csv> <off_sharedetail.csv>
# Summary files: fed has seat,actual,prob,pred,pred_p,pair ; nsw has seat,p,pred,pred_p,actual,bin
# (prob / p = probability given to the ACTUAL winner). Pass several nsw pairs by running once per pair
# and concatenating the printed per-pair table by hand: this script scores whatever it is given.
EPS <- 1e-6
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 5L, args[1] %in% c("fed", "nsw"))
jur <- args[1]
rd <- function(f) { stopifnot(file.exists(f)); utils::read.csv(f, stringsAsFactors = FALSE) }
on <- rd(args[2]); off <- rd(args[3]); son <- rd(args[4]); soff <- rd(args[5])
pcol <- if (jur == "fed") "prob" else "p"
if (jur == "nsw") { on$pair <- "nsw"; off$pair <- "nsw" }
cat(sprintf("rows: ON %d, OFF %d seat-elections | sharedetail rows ON %d, OFF %d\n", nrow(on), nrow(off), nrow(son), nrow(soff)))
stopifnot(nrow(on) == nrow(off), nrow(on) > 0L, nrow(son) == nrow(soff))
key <- function(d) paste(d$pair, d$seat, sep = "|")
m <- merge(data.frame(k = key(on), p_on = pmax(on[[pcol]], EPS), pair = on$pair, seat = on$seat, pred_on = on$pred),
           data.frame(k = key(off), p_off = pmax(off[[pcol]], EPS), pred_off = off$pred), by = "k")
stopifnot(nrow(m) == nrow(on))   # every seat-election present in both arms, else the comparison is not like-for-like
m$ll_on <- -log(m$p_on); m$ll_off <- -log(m$p_off)
per <- do.call(rbind, lapply(split(m, m$pair), function(d) data.frame(pair = d$pair[1], n = nrow(d),
         ll_off = mean(d$ll_off), ll_on = mean(d$ll_on), delta = mean(d$ll_on) - mean(d$ll_off))))
cat("\nTable 1 - mean seat log loss per pair (lower is better); delta = ON - OFF (negative = ON better)\n")
print(format(per, digits = 4), row.names = FALSE)
d <- per$delta
cat(sprintf("\nPRIMARY %s: mean delta %+.4f over %d pair(s); sd %s; SE %s; worst pair %+.4f (guard b: <= +0.011); guard a (<= +0.01): %s\n",
            jur, mean(d), length(d),
            if (length(d) > 1L) sprintf("%.4f", stats::sd(d)) else "NA (n = 1)",
            if (length(d) > 1L) sprintf("%.4f", stats::sd(d) / sqrt(length(d))) else "NA (n = 1)",
            max(d), if (mean(d) <= 0.01) "PASS" else "FAIL"))
cat(sprintf("guard b (no pair worse than +0.011): %s\n", if (max(d) <= 0.011) "PASS" else "FAIL"))
# floor events: winner at the floor (file resolution is 1e-4, so p <= 1e-4) under ON but not OFF
fl <- sum(m$p_on <= 1e-4 & m$p_off > 1e-4)
fo <- sum(m$p_off <= 1e-4 & m$p_on > 1e-4)
cat(sprintf("guard c floor events: winner at the floor under ON but not OFF: %d (must be 0); the reverse: %d\n", fl, fo))
cat(sprintf("seats whose predicted winner differs between arms: %d of %d\n", sum(m$pred_on != m$pred_off), nrow(m)))
# cells and per-class bias
kc <- function(d) paste(d$pair, d$seat, d$party, sep = "|")
c1 <- data.frame(k = kc(son), on = son$pred_share, act = son$actual_share, party = son$party)
c0 <- data.frame(k = kc(soff), off = soff$pred_share)
cc <- merge(c1, c0, by = "k"); stopifnot(nrow(cc) == nrow(son))
chg <- abs(cc$on - cc$off) > 1e-9
cat(sprintf("\ncells with a different predicted share: %d of %d\n", sum(chg), nrow(cc)))
if (any(chg)) {
  b <- do.call(rbind, lapply(split(cc[chg, ], cc$party[chg]), function(x) data.frame(
    party = x$party[1], n = nrow(x), bias_off = mean(x$off - x$act), bias_on = mean(x$on - x$act),
    se_on_minus_off = stats::sd(abs(x$on - x$act) - abs(x$off - x$act)) / sqrt(nrow(x)),
    abs_bias_change = abs(mean(x$on - x$act)) - abs(mean(x$off - x$act)))))
  b$grows_gt_2se <- b$n > 1L & b$abs_bias_change > 2 * b$se_on_minus_off
  cat("Table 2 - signed error (pred - actual, points) on the cells arm C changed, by class\n")
  print(format(b, digits = 3), row.names = FALSE)
  cat(sprintf("guard d (refuse if any class's absolute bias grows by more than 2 SE): %s\n", if (any(b$grows_gt_2se, na.rm = TRUE)) "FAIL" else "PASS"))
}
if (jur == "fed") {
  teal <- c("Goldstein", "Curtin", "North Sydney", "Kooyong", "Mackellar", "Fowler")
  t <- m[m$pair == "fed2022" & m$seat %in% teal, c("seat", "p_off", "p_on")]
  t$on_minus_off <- t$p_on - t$p_off
  cat("\nTable 3 - fed2022 teal seats: probability given to the actual winner (higher is better)\n")
  print(format(t, digits = 3), row.names = FALSE)
  cat(sprintf("teal seats found: %d of 6 (must be 6); falling under ON: %d (rule: at most 1)\n", nrow(t), sum(t$on_minus_off < 0)))
}
