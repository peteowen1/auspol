# Turn the v4 salience ranking into a per-seat surge hazard.
#
# WHY THIS SUPERSEDES fit_salience_hazard.R. That version fitted on the
# case-control emergence sample and recalibrated the intercept to a measured
# base rate, because Group A was selected on winning. v4 gives something
# strictly better: a COMPLETE election. All 151 fed2022 seats, 14 non-major
# winners, no selection at all -- so the intercept is unbiased by construction
# and no case-control correction is needed.
#
# THE HONEST COST: fitting and scoring on the same election is in-sample. This
# reports the in-sample fit AND a leave-one-out cross-validated version, and the
# LOO figure is the one to quote. A second election (fed2019 or fed2025) would
# be a genuine out-of-sample test and neither has been fetched with this method.
#
# THE STATISTIC is `jump` -- campaign mean minus pre-campaign baseline, on the
# single cross-seat scale built by 38 chained queries. AUC 0.971 over the full
# field, 0.932 with zeros excluded, and every non-major winner had a positive
# jump.
#
# Emits FV* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

CLIP <- 0.35   # pre-registered in prereg-salience-surge-hazard.md; not a knob
EL <- Sys.getenv("AUSPOL_SALIENCE_ELECTION", "fed2022")
f <- sprintf("output/salience-v4-%s.csv", EL)
if (!file.exists(f)) stop("no ", f, " -- run scripts/fetch_salience_v4.R")
R <- fread(f, showProgress = FALSE)
R[, won := as.logical(elected)][is.na(won), won := FALSE]

cat(sprintf("FV1  %s: %d seats | %d non-major winners (%.1f%%)\n",
            EL, nrow(R), sum(R$won), 100 * mean(R$won)))

# log1p keeps the many zeros finite and compresses the long right tail; jump
# spans -5 to 58 and a linear term would let Kooyong dominate the fit.
R[, x := log1p(pmax(jump, 0))]
g <- glm(won ~ x, data = R, family = binomial())
cs <- coef(summary(g))
cat(sprintf("FV2  in-sample: intercept %+.3f | slope %+.3f (SE %.3f, z %+.2f, p %.4g)\n",
            cs[1, 1], cs[2, 1], cs[2, 2], cs[2, 3], cs[2, 4]))

# LEAVE-ONE-OUT. Fitting and scoring the same 151 rows flatters the result; each
# seat's hazard here is predicted by a model that never saw that seat.
R[, haz_loo := NA_real_]
for (i in seq_len(nrow(R))) {
  gi <- suppressWarnings(glm(won ~ x, data = R[-i], family = binomial()))
  R[i, haz_loo := predict(gi, newdata = R[i], type = "response")]
}
R[, haz_ins := predict(g, type = "response")]
for (nm in c("haz_ins", "haz_loo")) {
  v <- R[[nm]]
  n1 <- sum(R$won); n0 <- nrow(R) - n1
  rk <- rank(v)
  cat(sprintf("FV3  AUC %-8s %.3f\n", nm,
              (sum(rk[which(R$won)]) - n1 * (n1 + 1) / 2) / (n1 * n0)))
}

R[, surge_h := pmin(pmax(haz_loo, 0), CLIP)]
cat(sprintf("\nFV4  hazard: median %.4f | mean %.4f | max %.4f | at the %.2f clip: %d\n",
            median(R$surge_h), mean(R$surge_h), max(R$surge_h), CLIP,
            sum(R$surge_h >= CLIP - 1e-9)))
cat(sprintf("FV4  above 0.10: %d seats | at the floor: %d\n",
            sum(R$surge_h > 0.10), sum(R$surge_h <= min(R$surge_h) + 1e-9)))

# CALIBRATION, the check that decides whether these are probabilities or just
# an ordering. An AUC says nothing about whether 0.30 means 30%.
R[, bin := cut(surge_h, c(-1, .02, .05, .10, .25, 1))]
cat("\nFV5  predicted hazard against realised win rate (leave-one-out)\n")
print(R[, .(seats = .N, said = round(100 * mean(surge_h), 1),
            won = sum(won), happened = round(100 * mean(won), 1)),
        by = bin][order(bin)], row.names = FALSE)

out <- R[, .(election = EL, seat, who = keyword, party, pcv, won,
             jump, surge_h)]
fwrite(out, "output/salience-hazard.csv")
cat(sprintf("\nFV9  wrote output/salience-hazard.csv (%d seats)\n", nrow(out)))
cat("FV9  the six seats the pre-registration names as the gate\n")
GATE <- c("North Sydney", "Goldstein", "Fowler", "Curtin", "Mackellar", "Kooyong")
print(out[seat %in% GATE][order(-surge_h),
      .(seat, who, pct = round(pcv, 1), won, jump = round(jump, 2),
        surge_h = round(surge_h, 4))], row.names = FALSE)
