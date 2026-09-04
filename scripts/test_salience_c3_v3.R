# Scores docs/plans/prereg-salience-c3-v3.md, committed at 1127fb4 before this
# scorer existed. Refits the gate model on the percentile feature (unchanged
# recipe otherwise -- GATE=15, fed2022 gated rows), scores it against
# output/c3-widened-population.csv (built by build_c3_widened_population.R,
# which asserts every join is row-count-preserving).
#
# Emits CV3* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

GATE <- 15
BAR1 <- 0.924   # Criterion 1: MDE at 2.80x the measured clustered SE

R <- fread("output/salience-v5.csv", showProgress = FALSE)
C <- fread("output/candidacies.csv", showProgress = FALSE)
statewide <- function(rg, yr) {
  d <- C[region == rg & year == yr, .(v = sum(votes)), by = party]
  setNames(100 * d$v / sum(d$v), d$party)
}
sa_ <- statewide("fed", 2019); sb_ <- statewide("fed", 2022)
TR <- R[election == "fed2022"]
mv <- vapply(TR$party, function(p)
  (if (p %in% names(sb_)) sb_[[p]] else 0) - (if (p %in% names(sa_)) sa_[[p]] else 0), 0)
TR[, base := pmax(0, prev_party + mv)]
TR[, xp := rank(jump, ties.method = "average") / .N]
TR[, gated := prev_party < GATE]
TR <- TR[gated == TRUE]
fit <- lm(pcv ~ base + xp, data = TR)
cs <- coef(summary(fit))
cat(sprintf("CV30 fitted on %d gated fed2022 rows | xp coef %+.4f (SE %.4f, t %+.2f, p %.4g)\n",
            nrow(TR), cs["xp",1], cs["xp",2], cs["xp",3], cs["xp",4]))

if (!file.exists("output/c3-widened-population.csv")) {
  stop("CV3! run scripts/build_c3_widened_population.R first")
}
POP <- fread("output/c3-widened-population.csv", showProgress = FALSE)
POP[, pred := base]
gi <- which(POP$gated & !is.na(POP$xp))
POP[gi, pred := pmax(0, predict(fit, POP[gi]))]

# ---- REFUSAL: ungated rows must not move -----------------------------------
ung <- POP[gated == FALSE]
mv_ung <- sum(abs(ung$pred - ung$base))
cat(sprintf("\nCV31 REFUSAL: %d ungated rows, aggregate |movement| %.6f (must be ~0) -> %s\n",
            nrow(ung), mv_ung, if (mv_ung <= 1e-6) "PASS" else "FAIL"))

# ---- Criterion 1: primary ---------------------------------------------------
E <- POP[emergence == TRUE & !is.na(xp)]
E[, `:=`(base_err = abs(base - pcv), pred_err = abs(pred - pcv), imp = abs(base - pcv) - abs(pred - pcv))]
cat(sprintf("\nCV32 usable emergences: %d across %d clusters\n", nrow(E), uniqueN(E$election)))

by_el <- E[, .(imp = mean(imp), n = .N), by = election]
k <- nrow(by_el)
se <- sd(by_el$imp) / sqrt(k)
cat(sprintf("CV32 by-cluster improvement:\n"))
print(by_el[order(election)])
cat(sprintf("CV32 %d clusters | clustered mean %.3f | sd %.3f | SE %.3f\n",
            k, mean(by_el$imp), sd(by_el$imp), se))
cat(sprintf("CV32 Criterion 1: clustered mean %.3f vs bar >= %.3f -> %s\n",
            mean(by_el$imp), BAR1, if (mean(by_el$imp) >= BAR1) "PASS" else "FAIL"))
cat(sprintf("CV32 all clusters positive: %s (%d of %d)\n",
            if (all(by_el$imp > 0)) "YES" else "NO", sum(by_el$imp > 0), k))

# ---- REFUSAL: survives dropping SA -----------------------------------------
Ex <- E[election != "sa2026"]
by_el_x <- Ex[, .(imp = mean(imp)), by = election]
kx <- nrow(by_el_x); sex <- sd(by_el_x$imp) / sqrt(kx)
cat(sprintf("\nCV33 REFUSAL, excluding sa2026: %d clusters | clustered mean %.3f | SE %.3f | MDE %.3f -> %s\n",
            kx, mean(by_el_x$imp), sex, 2.80 * sex,
            if (mean(by_el_x$imp) >= 2.80 * sex) "survives (not driven by SA)" else "DOES NOT SURVIVE"))

# ---- Criterion 2: do-no-harm guard, all gated non-major rows --------------
rmse <- function(p, a) sqrt(mean((p - a)^2))
G <- POP[gated == TRUE & !is.na(xp)]
cat("\nCV34 Criterion 2 (guard), by election:\n")
guard <- G[, .(n = .N, base_rmse = rmse(base, pcv), pred_rmse = rmse(pred, pcv)), by = election]
guard[, diff := pred_rmse - base_rmse]
print(guard[order(election)][, .(election, n, base_rmse = round(base_rmse, 3),
                                 pred_rmse = round(pred_rmse, 3), diff = round(diff, 3))])
worst <- max(guard$diff)
cat(sprintf("CV34 worst per-election RMSE change: %+.3f -> %s\n",
            worst, if (worst <= 0) "improves or flat everywhere" else "some worsening -- inspect"))

cat(sprintf("\nCV39 VERDICT: %s\n",
            if (mean(by_el$imp) >= BAR1 && mv_ung <= 1e-6) "CRITERION 1 PASSES" else "REFUSED"))
cat("CV39 Does not itself authorise shipping the percentile-based gate -- separate decision.\n")
