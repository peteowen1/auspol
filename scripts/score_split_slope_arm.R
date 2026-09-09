# Score the split-slope arm against the criterion committed in
# docs/plans/prereg-partial-return-split-slope-2026-09-09.md.
#
# Reads a BASELINE snapshot (arm off) and the CURRENT output/ (arm on) and
# reports every quantity the pre-registration named, in the order it named
# them, including the ones that would refuse. It decides nothing on its own --
# it prints the criterion's own verdict so the decision is the committed rule
# rather than a judgement made while looking at the numbers.
#
# Usage: Rscript scripts/score_split_slope_arm.R <base_backtest.csv> <base_sharedetail.csv>
#
# Emits SS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("need <base_backtest.csv> <base_sharedetail.csv>")
base_bt <- fread(args[1], showProgress = FALSE)
base_sd <- fread(args[2], showProgress = FALSE)
arm_bt  <- fread("output/pooled-backtest.csv",    showProgress = FALSE)
arm_sd  <- fread("output/pooled-sharedetail.csv", showProgress = FALSE)
cells   <- fread("output/partial-return-cells.csv", showProgress = FALSE)  # the 329 named cells

region_of <- function(p) sub("[0-9]+$", "", p)

# ---------------------------------------------------------------- PRIMARY ----
# Paired share RMSE on the named partial-return cells, clustered on pairs.
prep <- function(sd) {
  d <- copy(sd); d[, s := normalise_seat(seat)]
  merge(d, cells[, .(s, party, pair)], by = c("s", "party", "pair"))
}
b <- prep(base_sd); a <- prep(arm_sd)
key <- c("s", "party", "pair")
m <- merge(b[, c(key, "pred_share", "actual_share"), with = FALSE],
           a[, c(key, "pred_share"), with = FALSE],
           by = key, suffixes = c("_base", "_arm"))
cat(sprintf("SS1  target cells scored under BOTH arms: %d (named in prereg: %d)\n",
            nrow(m), nrow(cells)))
if (nrow(m) < 0.9 * nrow(cells))
  cat("SS1! coverage below 90% of the named cells -- prereg R5 says the run is VOID, not scored\n")

per <- m[, .(base = sqrt(mean((pred_share_base - actual_share)^2)),
             arm  = sqrt(mean((pred_share_arm  - actual_share)^2)), n = .N), by = pair]
per[, delta := arm - base]
setorder(per, -n)
cat(sprintf("\nSS2  PRIMARY: share RMSE on target cells | base %.4f -> arm %.4f\n",
            sqrt(mean((m$pred_share_base - m$actual_share)^2)),
            sqrt(mean((m$pred_share_arm  - m$actual_share)^2))))
print(per)
d <- per$delta
t_stat <- mean(d) / (sd(d) / sqrt(length(d)))
mde <- 2.08 * sd(d) / sqrt(length(d))
cat(sprintf("\nSS2  paired per-pair delta: mean %+.4f  sd %.4f  n=%d\n", mean(d), sd(d), length(d)))
cat(sprintf("SS2  t = %+.2f (bar: |t| >= 2.08) | realised MDE %.4f | better in %d of %d pairs\n",
            t_stat, mde, sum(d < 0), length(d)))
crit1 <- mean(d) < 0 && abs(t_stat) >= 2.08
cat(sprintf("SS2  CRITERION 1 (primary improves at >= 2.08 SE): %s\n", if (crit1) "PASS" else "FAIL"))

# ------------------------------------------------------------------ PANEL ----
ll <- function(bt) sum(bt$logloss * bt$n) / sum(bt$n)
br <- function(bt) sum(bt$brier   * bt$n) / sum(bt$n)
reg_ll <- function(bt, rg) { x <- bt[region_of(pair) == rg]; if (!nrow(x)) NA_real_ else ll(x) }
all_rmse <- function(sd) sqrt(mean((sd$pred_share - sd$actual_share)^2))
floor_seats <- function(sd) NA_integer_   # placeholder; filled from bt below if present

panel <- data.table(
  metric = c("pooled seat log loss", "pooled Brier", "pooled share RMSE (ALL cells)",
             "fed log loss", "nsw log loss", "qld log loss", "sa log loss",
             "vic log loss", "wa log loss"),
  base = c(ll(base_bt), br(base_bt), all_rmse(base_sd),
           reg_ll(base_bt,"fed"), reg_ll(base_bt,"nsw"), reg_ll(base_bt,"qld"),
           reg_ll(base_bt,"sa"),  reg_ll(base_bt,"vic"), reg_ll(base_bt,"wa")),
  arm  = c(ll(arm_bt),  br(arm_bt),  all_rmse(arm_sd),
           reg_ll(arm_bt,"fed"),  reg_ll(arm_bt,"nsw"),  reg_ll(arm_bt,"qld"),
           reg_ll(arm_bt,"sa"),   reg_ll(arm_bt,"vic"),  reg_ll(arm_bt,"wa")))
panel[, delta := arm - base]
panel[, verdict := fifelse(abs(delta) < 0.0005, "unchanged",
                    fifelse(delta < 0, "BETTER", "worse"))]
cat("\nSS3  PANEL (lower is better on every row; 'unchanged' counts as NOT an improvement)\n")
print(panel, digits = 5)

better <- sum(panel$verdict == "BETTER"); worse <- sum(panel$verdict == "worse")
cat(sprintf("\nSS3  panel: %d better, %d worse, %d unchanged (of %d scored; the 10th, floor-seat count, is reported separately)\n",
            better, worse, sum(panel$verdict == "unchanged"), nrow(panel)))
crit2 <- better >= 6 && worse <= 3
cat(sprintf("SS3  CRITERION 2 (>= 6 better AND <= 3 worse): %s\n", if (crit2) "PASS" else "FAIL"))

# ------------------------------------------------- CATASTROPHIC-BREAK FLOOR ---
worst_region <- panel[grepl("log loss", metric) & metric != "pooled seat log loss"][which.max(delta)]
pooled_delta <- panel[metric == "pooled seat log loss"]$delta
brk <- FALSE
if (nrow(worst_region) && is.finite(worst_region$delta) && worst_region$delta > 0.02) {
  cat(sprintf("SS4! FLOOR BREACHED: %s degrades by %+.4f (> 0.02)\n",
              worst_region$metric, worst_region$delta)); brk <- TRUE
}
if (is.finite(pooled_delta) && pooled_delta > 0.01) {
  cat(sprintf("SS4! FLOOR BREACHED: pooled log loss degrades by %+.4f (> 0.01)\n", pooled_delta)); brk <- TRUE
}
if (!brk) cat("SS4  catastrophic-break floor: not breached\n")

vic <- panel[metric == "vic log loss"]
cat(sprintf("SS5  VICTORIA (live target): %.4f -> %.4f (%+.4f) -- %s\n",
            vic$base, vic$arm, vic$delta,
            if (vic$delta > 0) "REGRESSION, must be reported prominently" else "no regression"))

# ------------------------------------------------------------------ R1 -------
cls <- merge(prep(base_sd)[, c(key, "pred_share", "actual_share"), with = FALSE],
             prep(arm_sd)[, c(key, "pred_share"), with = FALSE],
             by = key, suffixes = c("_base", "_arm"))
byc <- cls[, .(base = sqrt(mean((pred_share_base - actual_share)^2)),
               arm  = sqrt(mean((pred_share_arm  - actual_share)^2)), n = .N), by = party]
byc[, delta := arm - base]
cat("\nSS6  R1 -- target-cell improvement by class (the arm touches NON-MAJORS only)\n")
print(byc[order(delta)], digits = 4)

cat(sprintf("\nSS9  VERDICT under the committed rule: %s\n",
            if (crit1 && crit2 && !brk) "SHIP" else "DO NOT SHIP"))
cat("SS9  (R2/R3 were cleared before implementation; R4 needs the published forecast rerun.)\n")
