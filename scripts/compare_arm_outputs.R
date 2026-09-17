# Compare two arm output files and report the EXACT-ZERO-MOVEMENT bucket
# FIRST, before any other statistic -- CITIUS's discipline (cross-session
# exchange 2026-09-17, docs/plans/repo-speedup-2026-09-17.md item 2).
#
# Two failures this repo has already hit are both invisible to an aggregate
# metric and both visible here on line one:
#   - rows the mechanism under test should touch come back IDENTICAL to the
#     baseline (the arm never actually fired -- e.g. both sides read a frozen
#     snapshot file instead of the one being swapped, as happened to a fork's
#     first base_margin backtest pass today)
#   - EVERY row is identical (there is no experiment: the flag never reached
#     the code path, or both env vars resolved to the same value)
#
# CITIUS's own correction, learned the hard way: bucket on movement EXACTLY
# zero, not "below a small threshold". A <=0.01% threshold folded in rows
# that had genuinely moved a little and made a healthy comparison report a
# significant difference on its own invariance guard.
#
# Usage:
#   Rscript scripts/compare_arm_outputs.R <file_a> <file_b> \
#     [key_cols=pair,seat,party] [value_col=xgb_pred]
#
# Example, using today's cached base_margin OOF predictions:
#   Rscript scripts/compare_arm_outputs.R \
#     output/_prereg_basemargin/oof-BASELINE.csv \
#     output/_prereg_basemargin/oof-BASEMARGIN.csv \
#     pair,seat,party xgb_pred

suppressMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: compare_arm_outputs.R <file_a> <file_b> [key_cols] [value_col]")
file_a <- args[1]; file_b <- args[2]
key_cols <- if (length(args) >= 3) strsplit(args[3], ",")[[1]] else c("pair", "seat", "party")
value_col <- if (length(args) >= 4) args[4] else "xgb_pred"

if (!file.exists(file_a)) stop("Not found: ", file_a)
if (!file.exists(file_b)) stop("Not found: ", file_b)

a <- fread(file_a, showProgress = FALSE)
b <- fread(file_b, showProgress = FALSE)
for (f in c(key_cols, value_col)) {
  if (!f %in% names(a)) stop(f, " not found in ", file_a, " -- columns are: ", paste(names(a), collapse = ", "))
  if (!f %in% names(b)) stop(f, " not found in ", file_b, " -- columns are: ", paste(names(b), collapse = ", "))
}

setnames(a, value_col, "val_a"); setnames(b, value_col, "val_b")
m <- merge(a[, c(key_cols, "val_a"), with = FALSE],
           b[, c(key_cols, "val_b"), with = FALSE],
           by = key_cols, all = TRUE)

n_a <- nrow(a); n_b <- nrow(b); n_m <- nrow(m)
only_a <- sum(is.na(m$val_b)); only_b <- sum(is.na(m$val_a))
cat(sprintf("CA0  %s: %d rows | %s: %d rows | %d keys matched, %d only in A, %d only in B\n",
            basename(file_a), n_a, basename(file_b), n_b, n_m - only_a - only_b, only_a, only_b))
if (only_a > 0 || only_b > 0) {
  cat("CA0! unmatched keys exist -- check key_cols is right before trusting anything below\n")
}

mm <- m[!is.na(val_a) & !is.na(val_b)]
mm[, rel_move := fifelse(val_a == 0, fifelse(val_b == 0, 0, Inf), abs(val_b - val_a) / abs(val_a))]

# THE ZERO-MOVEMENT BUCKET, FIRST. Exact zero, not a threshold -- see header.
n_zero <- sum(mm$rel_move == 0)
pct_zero <- 100 * n_zero / nrow(mm)
cat(sprintf("\nCA1  EXACT-ZERO-MOVEMENT BUCKET (read this before anything else): %d / %d rows (%.1f%%)\n",
            n_zero, nrow(mm), pct_zero))
if (pct_zero >= 99.9) {
  cat("CA1! >=99.9% identical -- there is no experiment here. Check the arm actually applied\n")
} else if (pct_zero < 0.1) {
  cat("CA1! <0.1% identical -- if you expected a targeted change (most rows untouched), this arm touched EVERYTHING; check for a confound\n")
}

# THE REST, only meaningful once the zero bucket above has been read.
moved <- mm[rel_move > 0 & is.finite(rel_move)]
cat(sprintf("\nCA2  of the %d rows that moved: mean |rel move| %.4f | median %.4f | max %.4f\n",
            nrow(moved), mean(moved$rel_move), stats::median(moved$rel_move), max(moved$rel_move)))
cat(sprintf("CA2  raw value change: mean %.4f | mean |change| %.4f | sd(A) %.4f sd(B) %.4f\n",
            mean(mm$val_b - mm$val_a), mean(abs(mm$val_b - mm$val_a)), stats::sd(mm$val_a), stats::sd(mm$val_b)))

if ("pair" %in% key_cols && uniqueN(mm$pair) > 1) {
  cat("\nCA3  by pair (rows unchanged | mean |rel move| among rows that moved)\n")
  print(mm[, .(n = .N,
               pct_zero = round(100 * mean(rel_move == 0), 1),
               mean_abs_move = round(mean(abs(val_b - val_a)), 4)),
           by = pair][order(pair)])
}
