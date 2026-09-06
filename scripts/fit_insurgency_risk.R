# Per-seat non-major insurgency risk, fitted LEAVE-ONE-ELECTION-OUT.
#
# Against docs/plans/prereg-insurgency-conditional-shrink.md, committed before
# this file was written.
#
# WHY THIS EXISTS. `shrink` is a flat per-draw coin toss, so it caps every seat
# at 1 - s/2 -- 0.9598 at s = 0.10, with no seat above 0.99 where the unshrunk
# model had 529. It absorbs one specific risk (a non-major taking a seat called
# safe for a major: 8 of the 9 misses at pred_p > 0.9999) by charging that risk
# to all 886 seats, including the 672 whose measured risk is under 1.5%.
#
# LEAKAGE. Every feature is computed from the `from` election only, by
# scripts/build_upset_features.R. The fold being predicted contributes nothing
# to the fit it is scored under -- that is the whole point of the LOEO loop, and
# the in-sample fit is computed alongside ONLY to report the gap, never to
# produce the risk that ships.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

FEAT <- "output/fed-upset-features.csv"
if (!file.exists(FEAT))
  stop("run scripts/build_upset_features.R first; ", FEAT, " is missing")
D <- fread(FEAT, showProgress = FALSE)

# TWO FEATURES, and this is a pre-registered ceiling rather than a starting
# point. There are 49 non-major wins in the corpus; a third feature would be one
# per 16 events. The pre-registration refuses a third in advance.
FORM <- nm_win ~ log1p(nm_best) + nm_held

cat(sprintf("IR1  %d seat-elections | %d non-major wins (%.2f%%) | %d elections\n",
            nrow(D), sum(D$nm_win), 100 * mean(D$nm_win), uniqueN(D$pair)))

# ---- leave-one-election-out ------------------------------------------------
D[, risk_loeo := NA_real_]
for (e in unique(D$pair)) {
  tr <- D[pair != e]; te <- which(D$pair == e)
  m  <- suppressWarnings(glm(FORM, data = tr, family = binomial()))
  D[te, risk_loeo := predict(m, newdata = D[te], type = "response")]
  cat(sprintf("IR2  fold %s: trained on %d seats (%d wins), predicted %d\n",
              e, nrow(tr), sum(tr$nm_win), length(te)))
}
stopifnot(!anyNA(D$risk_loeo))

# ---- in-sample, for the pre-registered agreement check only ----------------
m_all <- suppressWarnings(glm(FORM, data = D, family = binomial()))
D[, risk_insample := predict(m_all, type = "response")]
gap <- abs(mean(D$risk_loeo) - mean(D$risk_insample)) / mean(D$risk_insample)
cat(sprintf("IR3  mean risk: LOEO %.4f | in-sample %.4f | gap %.1f%% (refuse above 20%%)\n",
            mean(D$risk_loeo), mean(D$risk_insample), 100 * gap))
if (gap > 0.20) cat("IR3  *** GAP EXCEEDS THE PRE-REGISTERED 20% -- risk model is fitting noise\n")

# ---- the shrink this implies ----------------------------------------------
# Flat shrink s caps a seat at 1 - s/2, so s_i = 2 * r_i caps seat i at 1 - r_i:
# "this seat's ceiling is its own upset risk". The 0.20 clip is pre-registered
# and is not a tuning knob.
D[, shrink_i := pmin(pmax(2 * risk_loeo, 0), 0.20)]
cat(sprintf("IR4  shrink_i: median %.4f | mean %.4f | max %.4f | at the 0.20 clip: %d seats\n",
            median(D$shrink_i), mean(D$shrink_i), max(D$shrink_i),
            sum(D$shrink_i >= 0.20 - 1e-9)))
cat(sprintf("IR4  seats whose implied ceiling exceeds 0.99: %d of %d (flat shrink gives 0)\n",
            sum(1 - D$risk_loeo > 0.99), nrow(D)))

# ---- does the out-of-sample risk actually discriminate? --------------------
o <- D[order(-risk_loeo)]
n1 <- sum(D$nm_win); n0 <- nrow(D) - n1
r  <- rank(D$risk_loeo)
auc <- (sum(r[D$nm_win == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
cat(sprintf("IR5  out-of-sample AUC %.3f over %d wins and %d non-wins\n", auc, n1, n0))

D[, rb := cut(risk_loeo, c(-1, .01, .02, .05, .15, .50, 1))]
cat("IR5  predicted risk vs realised, OUT OF SAMPLE:\n")
print(D[, .(seats = .N, wins = sum(nm_win),
            said = round(100 * mean(risk_loeo), 1),
            happened = round(100 * mean(nm_win), 1)), by = rb][order(rb)],
      row.names = FALSE)

fwrite(D[, .(pair, seat, nm_best, nm_held, risk_loeo, shrink_i, nm_win)],
       "output/fed-insurgency-risk.csv")
cat("IR6  wrote output/fed-insurgency-risk.csv\n")
