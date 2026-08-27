# Compare two backtest arms on the metrics that describe whether the FORECAST is
# better, and on the subsets we care about.
#
# WHY THIS EXISTS. A summary line gives one Brier and one calibration slope for a
# whole election. That is not enough to answer "is this change good": a targeted
# improvement can be invisible in the aggregate, and a metric can be too noisy to
# resolve any plausible effect. The calibration slope has sd 0.562 across 17
# pairs, so its minimum detectable effect is 0.419 -- it refused a change that
# improves independent seats by 15% on log loss.
#
# Usage: Rscript scripts/compare_arms.R <base.csv> <arm.csv> [label]
# Both files come from a backtest harness and carry seat, pred, pred_p, actual.
suppressMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("need <base.csv> <arm.csv>")
lab <- if (length(args) >= 3L) args[3] else "arm"

rd <- function(f, a) {
  d <- fread(f, showProgress = FALSE)
  need <- c("pred", "pred_p", "actual")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(f, " lacks: ", paste(miss, collapse = ", "))
  d[, `:=`(arm = a, won = as.integer(pred == actual))][]
}
A <- rd(args[1], "base"); B <- rd(args[2], lab)
if (nrow(A) != nrow(B)) cat(sprintf("!! row counts differ: %d vs %d\n", nrow(A), nrow(B)))
D <- rbind(A, B, fill = TRUE)

sc <- function(x) {
  p <- pmin(pmax(x$pred_p, 1e-9), 1 - 1e-9); w <- x$won
  list(n = nrow(x), acc = 100 * mean(w), brier = mean((p - w)^2),
       logloss = -mean(w * log(p) + (1 - w) * log(1 - p)))
}
row <- function(expr, label) {
  a <- sc(D[arm == "base"][eval(expr, .SD)]); b <- sc(D[arm == lab][eval(expr, .SD)])
  if (!a$n) return(invisible())
  mark <- function(x, y) if (y <= x) "BETTER" else "worse"
  cat(sprintf("\n%-32s n=%d\n", label, a$n))
  cat(sprintf("   accuracy  %6.1f%% -> %6.1f%%   %s\n", a$acc, b$acc,
              if (b$acc >= a$acc) "better/same" else "worse"))
  cat(sprintf("   Brier     %7.4f -> %7.4f   %s\n", a$brier, b$brier, mark(a$brier, b$brier)))
  cat(sprintf("   log loss  %7.4f -> %7.4f   %s\n", a$logloss, b$logloss, mark(a$logloss, b$logloss)))
}
cat(sprintf("Comparing base against '%s' | %d rows each\n", lab, nrow(A)))
row(quote(rep(TRUE, .N)), "ALL SEATS")
row(quote(actual == "IND"), "seats an INDEPENDENT won")
row(quote(!actual %in% c("ALP", "LNP", "NAT")), "seats any NON-MAJOR won")
row(quote(actual %in% c("ALP", "LNP", "NAT")), "seats a major won")
row(quote(pred_p >= 0.99), "we said 99%+ certain")
row(quote(pred_p >= 0.90 & pred_p < 0.99), "we said 90-99%")
row(quote(pred_p < 0.75), "genuinely close (<75%)")

# ECE with TAIL-FOCUSED bands. Equal-width bins put most seats in one bucket and
# hide the only region where decisions live. Counts are printed because an empty
# bin is not evidence.
cat("

RELIABILITY by band, with counts -- an empty bin is not evidence
")
EDGES <- c(0, 0.5, 0.75, 0.9, 0.95, 0.99, 0.999, 1)
for (a in c("base", lab)) {
  x <- D[arm == a & !is.na(pred_p)]
  x[, band := cut(pred_p, EDGES, include.lowest = TRUE)]
  t <- x[, list(n = .N, said = mean(pred_p), got = mean(won)), by = band][order(band)]
  cat(sprintf("
   %s
", a))
  for (i in seq_len(nrow(t))) {
    cat(sprintf("     %-14s n %4d | said %6.2f%% | got %6.2f%% | gap %+6.2f
",
                as.character(t$band[i]), t$n[i], 100 * t$said[i], 100 * t$got[i],
                100 * (t$got[i] - t$said[i])))
  }
  cat(sprintf("     ECE %.4f
", sum(t$n * abs(t$said - t$got)) / nrow(x)))
}

cat("\n\nRELIABILITY at the top end -- the documented failure mode\n")
for (a in c("base", lab)) {
  x <- D[arm == a & pred_p >= 0.99]
  if (!nrow(x)) next
  cat(sprintf("   %-8s said %.2f%% over %4d seats | right %.1f%% | gap %+.1f pts\n",
              a, 100 * mean(x$pred_p), nrow(x), 100 * mean(x$won),
              100 * (mean(x$won) - mean(x$pred_p))))
}
cat("\nSeats called 99%+ that were LOST\n")
for (a in c("base", lab)) {
  x <- D[arm == a & pred_p >= 0.99 & won == 0]
  cat(sprintf("   %-8s %d seat(s)%s\n", a, nrow(x),
      if (nrow(x)) paste0(": ", paste(sprintf("%s %.4f (%s beat %s)",
          x$seat, x$pred_p, x$actual, x$pred), collapse = "; ")) else ""))
}
