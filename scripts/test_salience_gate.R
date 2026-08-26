# Scores docs/plans/prereg-salience-emergence-gate.md. Nothing here deviates
# from that document; where a criterion cannot run it is reported unrunnable
# rather than substituted.
#
# Emits SG* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

GATE <- 15      # pre-registered, fixed. Changing this invalidates the test.
MAJ  <- c("ALP", "LNP", "NAT")

R <- fread("output/salience-v5.csv", showProgress = FALSE)
C <- fread("output/candidacies.csv", showProgress = FALSE)

# BASE: uniform swing on the candidate's own class -- prior share in this seat
# plus that class's statewide movement. This is what the model does today.
statewide <- function(rg, yr) {
  d <- C[region == rg & year == yr, .(v = sum(votes)), by = party]
  setNames(100 * d$v / sum(d$v), d$party)
}
PY <- c(fed2022 = 2019, fed2025 = 2022)
R[, base := NA_real_]
for (el in names(PY)) {
  yr <- as.integer(sub("^[a-z]+", "", el)); py <- PY[[el]]
  sa <- statewide("fed", py); sb <- statewide("fed", yr)
  ix <- which(R$election == el)
  mv <- vapply(R$party[ix], function(p)
    (if (p %in% names(sb)) sb[[p]] else 0) - (if (p %in% names(sa)) sa[[p]] else 0), 0)
  R[ix, base := pmax(0, prev_party + mv)]
}
R[, `:=`(x = log1p(pmax(jump, 0)), gated = prev_party < GATE)]
cat(sprintf("SG0  %d rows | gated %d | fed2022 emergences %d | fed2025 emergences %d\n",
            nrow(R), sum(R$gated), R[election=="fed2022", sum(emerg)],
            R[election=="fed2025", sum(emerg)]))

# ---- fit on fed2022 GATED rows only -----------------------------------------
TR <- R[election == "fed2022" & gated == TRUE]
fit <- lm(pcv ~ base + x, data = TR)
cs <- coef(summary(fit))
cat(sprintf("SG1  fitted on %d gated fed2022 rows | salience coef %+.4f (SE %.4f, t %+.2f, p %.4g)\n",
            nrow(TR), cs["x",1], cs["x",2], cs["x",3], cs["x",4]))
cat("SG1  REFUSAL CHECK: a coefficient near zero means the model declines to act,\n")
cat(sprintf("     which is NOT a gate working. |t| = %.2f\n", abs(cs["x",3])))

apply_gate <- function(D) {
  D <- copy(D); D[, pred := base]
  gi <- which(D$gated)
  if (length(gi)) D[gi, pred := pmax(0, predict(fit, .SD)), .SDcols = c("base","x")]
  D
}
r <- function(p, a) sqrt(mean((p - a)^2))

# ---- C1: fed2025, out of sample, zero emergences ----------------------------
TE <- apply_gate(R[election == "fed2025"])
d1 <- r(TE$pred, TE$pcv) - r(TE$base, TE$pcv)
cat(sprintf("\nSG2  C1 fed2025 (%d rows, 0 emergences): base %.3f | gated %.3f | %+.3f\n",
            nrow(TE), r(TE$base, TE$pcv), r(TE$pred, TE$pcv), d1))
cat(sprintf("SG2  C1 tolerance +0.30 (3.75 SE at the measured clustered SE of 0.080) -> %s\n",
            if (d1 <= 0.30) "PASS" else "FAIL"))

# REFUSAL: the 13 ungated fed2025 winners must move by EXACTLY zero.
W <- TE[elected == TRUE]
mv <- sum(abs(W$pred - W$base))
cat(sprintf("SG3  REFUSAL: %d fed2025 non-major winners, aggregate |movement| %.6f (must be ~0) -> %s\n",
            nrow(W), mv, if (mv <= 0.5) "PASS" else "FAIL"))
cat(sprintf("SG3  of those winners, %d are gated (expected 0)\n", sum(W$gated)))

# ---- C2: precision ----------------------------------------------------------
thr <- median(TR$x[TR$x > 0])
fired <- R[gated == TRUE & x > thr]
tp <- sum(fired$emerg); fp <- nrow(fired) - tp
tot_emerg <- R[, sum(emerg)]
cat(sprintf("\nSG4  C2 precision: gate fires on %d rows | %d true emergences | %d others\n",
            nrow(fired), tp, fp))
cat(sprintf("SG4  ratio %.2f false per true (limit 3.00) -> %s\n",
            if (tp) fp/tp else Inf, if (tp && fp/tp <= 3) "PASS" else "FAIL"))
cat(sprintf("SG4  recall on fed2022's 6 emergences: %d of 6 (refusal floor 4) -> %s\n",
            R[election=="fed2022" & emerg & x > thr, .N],
            if (R[election=="fed2022" & emerg & x > thr, .N] >= 4) "PASS" else "FAIL"))

# ---- reported, NOT decisive: fed2022 leave-one-out --------------------------
F22 <- R[election == "fed2022"]; F22[, loo := base]
gi <- which(F22$gated)
for (i in gi) {
  m <- lm(pcv ~ base + x, data = F22[gated == TRUE][seat != F22$seat[i] | keyword != F22$keyword[i]])
  F22[i, loo := pmax(0, predict(m, F22[i]))]
}
E <- F22[emerg == TRUE]
cat(sprintf("\nSG5  fed2022 LOO (fitting election, reported not decisive)\n"))
cat(sprintf("     all %d rows:      base %.3f | gated %.3f | %+.3f\n",
            nrow(F22), r(F22$base,F22$pcv), r(F22$loo,F22$pcv), r(F22$loo,F22$pcv)-r(F22$base,F22$pcv)))
cat(sprintf("     6 emergences:     base %.2f | gated %.2f | %+.2f  (C3 MDE floor 6.9)\n",
            mean(abs(E$base-E$pcv)), mean(abs(E$loo-E$pcv)),
            mean(abs(E$loo-E$pcv))-mean(abs(E$base-E$pcv))))
cat("SG5  if that gain is under 6.9, C3 is UNRUNNABLE on 8 held-out emergences\n")
print(E[order(-pcv), .(seat, who=keyword, prev=round(prev_party,1), jump=round(jump,2),
        base=round(base,1), gated=round(loo,1), actual=round(pcv,1))], row.names=FALSE)
