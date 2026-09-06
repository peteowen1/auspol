# Scores docs/plans/prereg-salience-precision-v2.md, committed at 6443e73
# before this script existed. Reuses the same gate/model setup as
# scripts/test_salience_gate.R (unchanged: GATE=15, pcv ~ base + log1p(jump),
# fitted on fed2022 gated rows) and replaces ONLY that document's C2 with the
# two vote-share-phrased criteria this pre-registration specifies. C1 and C3
# of the original document are untouched by this script.
#
# Emits PV* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

GATE <- 15      # pre-registered, fixed -- same value as test_salience_gate.R
BAR1 <- 0.37    # Criterion 1: gated RMSE must not worsen by more than this
ALPHA2 <- 0.05  # Criterion 2: two-sided binomial bar, reported not decisive

R <- fread("output/salience-v5.csv", showProgress = FALSE)
C <- fread("output/candidacies.csv", showProgress = FALSE)

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

TR <- R[election == "fed2022" & gated == TRUE]
fit <- lm(pcv ~ base + x, data = TR)
cs <- coef(summary(fit))
cat(sprintf("PV0  fitted on %d gated fed2022 rows | salience coef %+.4f (SE %.4f, t %+.2f)\n",
            nrow(TR), cs["x",1], cs["x",2], cs["x",3]))

apply_gate <- function(D) {
  D <- copy(D); D[, pred := base]
  gi <- which(D$gated)
  if (length(gi)) D[gi, pred := pmax(0, predict(fit, .SD)), .SDcols = c("base","x")]
  D
}

# ---- Criterion 1: gated-subset RMSE, fed2025 (zero true emergences) --------
TE <- apply_gate(R[election == "fed2025"])
G <- TE[gated == TRUE]
if (sum(G$emerg) != 0L) {
  stop("PV! fed2025 gated subset now contains ", sum(G$emerg), " true emergence(s) -- ",
       "this criterion assumes zero by construction and is void if that changes.")
}
rmse <- function(p, a) sqrt(mean((p - a)^2))
d1 <- rmse(G$pred, G$pcv) - rmse(G$base, G$pcv)
cat(sprintf("\nPV1  Criterion 1: gated RMSE base %.3f -> gated %.3f, diff %+.3f (n=%d rows, %d seats)\n",
            rmse(G$base, G$pcv), rmse(G$pred, G$pcv), d1, nrow(G), uniqueN(G$seat)))
cat(sprintf("PV1  bar: must not worsen by more than +%.2f -> %s\n",
            BAR1, if (d1 <= BAR1) "PASS" else "FAIL"))

# Refusal: coefficient near zero means the model declined to act.
cat(sprintf("PV1  REFUSAL CHECK: |t| on salience coefficient = %.2f\n", abs(cs["x",3])))

# Refusal: gain concentrated in a handful of seats vs broadly shared.
by_seat <- G[, .(d = mean(abs(pred - pcv)) - mean(abs(base - pcv)), n = .N), by = seat]
n_improved <- sum(by_seat$d < 0); n_worsened <- sum(by_seat$d > 0)
cat(sprintf("PV1  by-seat spread: %d of %d seats improved, %d worsened, %d unchanged\n",
            n_improved, nrow(by_seat), n_worsened, nrow(by_seat) - n_improved - n_worsened))

# ---- Criterion 2: direction agreement, reported not decisive ---------------
G[, `:=`(pred_move = pred - base, actual_move = pcv - base)]
ct <- cor(G$pred_move, G$actual_move)
M <- G[pred_move != 0]
agree <- sum(sign(M$pred_move) == sign(M$actual_move))
bt <- stats::binom.test(agree, nrow(M), p = 0.5, alternative = "two.sided")
cat(sprintf("\nPV2  Criterion 2 (reported, not decisive): cor(predicted move, actual move) = %.4f\n", ct))
cat(sprintf("PV2  sign agreement %d of %d moved rows (%.1f%%), binomial p = %.4g vs alpha %.2f -> %s\n",
            agree, nrow(M), 100 * agree / nrow(M), bt$p.value, ALPHA2,
            if (bt$p.value < ALPHA2 && agree / nrow(M) > 0.5) "clears bar (informational)" else "does not clear"))
cat("PV2  NOT clustering-corrected -- informational only, per the pre-registration\n")

# ---- Dry-run cases, re-checked here rather than trusted from the document --
cat("\nPV3  Dry-run: Boele, Bradfield, fed2025 (must be ungated, zero effect)\n")
b <- TE[grepl("Boele", keyword, ignore.case = TRUE)]
if (nrow(b) != 1L) stop("PV! expected exactly one Boele row, found ", nrow(b))
ok_b <- !b$gated && isTRUE(all.equal(b$pred, b$base))
cat(sprintf("     gated=%s, base=%.2f, pred=%.2f -> %s\n", b$gated, b$base, b$pred,
            if (ok_b) "PASS" else "FAIL"))

cat("\nPV3  Dry-run: Dai Le, Fowler, fed2022 (must be gated, move toward actual)\n")
te2 <- apply_gate(R[election == "fed2022"])
dl <- te2[grepl("Dai Le|Le, Dai", keyword, ignore.case = TRUE)]
if (nrow(dl) != 1L) stop("PV! expected exactly one Dai Le row, found ", nrow(dl))
moved_toward <- abs(dl$pred - dl$pcv) < abs(dl$base - dl$pcv)
cat(sprintf("     gated=%s, base=%.2f, pred=%.2f, actual=%.2f -> %s\n",
            dl$gated, dl$base, dl$pred, dl$pcv,
            if (dl$gated && moved_toward) "PASS" else "FAIL"))

cat(sprintf("\nPV4  VERDICT: Criterion 1 %s. This replaces C2 of prereg-salience-emergence-gate.md;\n",
            if (d1 <= BAR1) "PASSES" else "FAILS"))
cat("PV4  C1 (original) and C3 (unrun, needs fed2010-2019 fetch) still gate adoption.\n")
