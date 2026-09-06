# Size the relationship between salience jump magnitude and ACTUAL vote share,
# among candidates the screen already permits, across every election
# output/salience-v6.csv covers. This is a pre-sizing step: does jump predict
# how big the emergence is (not just whether one happened), before any change
# is made to how the seat model uses it.
#
# Emits SZ* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

SAL <- fread("output/salience-v6.csv")
cat(sprintf("SZ0  %d rows across elections: %s\n", nrow(SAL),
            paste(sort(unique(SAL$election)), collapse = ", ")))

# GOVERNED POPULATION ONLY, same definition salience_permit_for() uses:
# prev_party < 15 and not a surging class. We don't have `ret` here without
# rebuilding it per-election, so approximate with prev_party < 15 for this
# sizing pass -- returning candidates are a separate, already-handled case and
# diluting them in would only pull the fit toward zero.
cand <- SAL[prev_party < 15 & jump > 0]
cat(sprintf("SZ1  %d candidates: low prior vote (<15%%), registered any salience (jump>0)\n",
            nrow(cand)))

fit <- lm(pcv ~ jump, data = cand)
cat(sprintf("SZ2  pcv ~ jump: intercept %.2f, slope %.2f, R^2 %.3f, n=%d\n",
            coef(fit)[1], coef(fit)[2], summary(fit)$r.squared, nrow(cand)))

cat("\nSZ3  the known emergent winners, jump vs actual pcv:\n")
print(cand[elected == TRUE][order(-jump), .(election, seat, keyword, party,
      jump = round(jump, 3), pcv = round(pcv, 1))])

cat("\nSZ4  low-prior candidates who registered salience but did NOT win, for contrast:\n")
print(cand[elected == FALSE][order(-jump)][1:15, .(election, seat, keyword, party,
      jump = round(jump, 3), pcv = round(pcv, 1))])

cat(sprintf("\nSZ5  correlation(jump, pcv) among governed-registered candidates: %.3f\n",
            cor(cand$jump, cand$pcv)))
