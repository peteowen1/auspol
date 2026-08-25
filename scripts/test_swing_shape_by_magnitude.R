# Does the right swing shape depend on the SIZE of the statewide move?
# Against docs/plans/prereg-swing-shape-by-magnitude.md
#
# Uniform already beat proportional 3.724 to 3.970 on this corpus and that is
# not re-litigated. This asks whether the pooled answer hides a magnitude
# dependence -- uniform right for small moves, proportional for large ones.
#
# Criterion, bar, decision rule and five refusals are in the plan.
#
# Emits SM* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

SE_BAR <- 2.20
SIGN_MIN <- 8L
PREF <- election_data_path()

fs <- list.files(PREF, pattern = "firstprefs\\.csv$", full.names = TRUE)
meta <- data.table(f = fs, base = basename(fs))
meta[, region := tstrsplit(base, "-", keep = 3)[[1]]]
meta[, year := as.integer(tstrsplit(base, "-", keep = 2)[[1]])]
meta <- meta[!is.na(year)][order(region, year)]

load1 <- function(f) {
  d <- fread(f, showProgress = FALSE)
  if (!all(c("seat", "party", "votes") %in% names(d))) return(NULL)
  d[, tot := sum(votes), by = seat]
  d[, p := 100 * votes / tot]
  d[, .(seat, party, p, votes)]
}

rows <- list()
for (rg in unique(meta$region)) {
  yy <- meta[region == rg, year]
  if (length(yy) < 2) next
  for (i in seq_len(length(yy) - 1L)) {
    a <- load1(meta[region == rg & year == yy[i], f])
    b <- load1(meta[region == rg & year == yy[i + 1], f])
    if (is.null(a) || is.null(b)) next
    sa <- a[, .(sw_a = 100 * sum(votes) / sum(a$votes)), by = party]
    sb <- b[, .(sw_b = 100 * sum(votes) / sum(b$votes)), by = party]
    st <- merge(sa, sb, by = "party")
    j <- merge(a[, .(seat, party, p_a = p)], b[, .(seat, party, p_b = p)],
               by = c("seat", "party"))
    j <- merge(j, st, by = "party")
    j[, `:=`(cycle = paste(rg, yy[i], yy[i + 1]), region = rg)]
    rows[[length(rows) + 1L]] <- j
  }
}
D <- rbindlist(rows, fill = TRUE)
D <- D[p_a >= 3 & sw_a >= 2 & is.finite(p_a) & is.finite(p_b)]
D[, d_seat := p_b - p_a]
D[, d_state := sw_b - sw_a]
D[, abs_state := abs(d_state)]

D[, err_uniform := abs(d_seat - d_state)]
D[, err_prop := abs(d_seat - p_a * d_state / sw_a)]
D[, advantage := err_uniform - err_prop]   # positive => proportional better

cat(sprintf("SM1  %d observations, %d cycle-pairs, %d regions\n",
            nrow(D), uniqueN(D$cycle), uniqueN(D$region)))
cat(sprintf("SM1  pooled MAE: uniform %.3f | proportional %.3f  (uniform wins, as before)\n",
            mean(D$err_uniform), mean(D$err_prop)))
cat(sprintf("SM1  |d_state| ranges %.1f to %.1f\n", min(D$abs_state), max(D$abs_state)))

cluster_se <- function(form, data, cluster) {
  m <- stats::lm(form, data = data)
  X <- stats::model.matrix(m); u <- stats::residuals(m)
  bread <- solve(crossprod(X))
  g <- split(seq_len(nrow(X)), cluster)
  meat <- Reduce(`+`, lapply(g, function(i) tcrossprod(crossprod(X[i, , drop = FALSE], u[i]))))
  G <- length(g); N <- nrow(X); K <- ncol(X)
  V <- bread %*% meat %*% bread * (G / (G - 1)) * ((N - 1) / (N - K))
  list(coef = stats::coef(m), se = sqrt(diag(V)), G = G)
}
show <- function(f, term, lbl) {
  b <- f$coef[[term]]; s <- f$se[[term]]
  cat(sprintf("     %-38s coef %+8.5f  SE %7.5f  ratio %+6.2f\n", lbl, b, s, b / s))
  b / s
}

cat("\nSM2  CRITERION -- advantage on |d_state| (positive = proportional gains with size)\n")
f1 <- cluster_se(advantage ~ abs_state, D, D$cycle)
r1 <- show(f1, "abs_state", "|d_state| alone")

cat("\nSM3  R2 -- control for the party's own base, since proportional\n")
cat("     mechanically does better on large bases and big swings may be big parties\n")
f2 <- cluster_se(advantage ~ abs_state + p_a, D, D$cycle)
r2 <- show(f2, "abs_state", "|d_state|, controlling base")
show(f2, "p_a", "base itself")

cat("\nSM4  mean advantage by |d_state| decile -- the crossover\n")
D[, dec := cut(abs_state, breaks = quantile(abs_state, seq(0, 1, 0.1)),
               include.lowest = TRUE, labels = FALSE)]
tab <- D[, .(n = .N, lo = round(min(abs_state),1), hi = round(max(abs_state),1),
             mae_unif = round(mean(err_uniform),3),
             mae_prop = round(mean(err_prop),3),
             advantage = round(mean(advantage),3)), by = dec][order(dec)]
print(tab)
pos <- tab[advantage > 0]
if (nrow(pos)) {
  cat(sprintf("SM4  proportional first wins in decile %d, |d_state| >= %.1f points\n",
              min(pos$dec), tab[dec == min(pos$dec), lo]))
} else {
  cat("SM4  proportional never wins in any decile -- no crossover in range\n")
}

cat("\nSM5  R3 -- smallest decile must still favour UNIFORM\n")
sm <- tab[dec == 1]
cat(sprintf("     decile 1 (|d_state| %.1f-%.1f): advantage %+.3f -> %s\n",
            sm$lo, sm$hi, sm$advantage,
            if (sm$advantage < 0) "uniform wins, PASS" else "proportional wins, REFUSE R3"))

cat("\nSM6  R1 -- drop South Australia (largest swings, motivated this)\n")
noSA <- D[region != "sa"]
f3 <- cluster_se(advantage ~ abs_state + p_a, noSA, noSA$cycle)
r3 <- show(f3, "abs_state", "|d_state|, no SA")

cat("\nSM7  per cycle-pair sign\n")
per <- D[, {
  if (.N >= 20 && stats::var(abs_state) > 0)
    .(n = .N, coef = round(stats::coef(stats::lm(advantage ~ abs_state))[["abs_state"]], 5))
  else .(n = .N, coef = NA_real_)
}, by = cycle][order(-n)]
print(per)
same <- sum(sign(per$coef) == sign(f2$coef[["abs_state"]]), na.rm = TRUE)
usable <- sum(!is.na(per$coef))
cat(sprintf("SM7  %d of %d usable cycle-pairs share the sign (need >= %d of 12)\n",
            same, usable, SIGN_MIN))

c1 <- r2 >= SE_BAR
c2 <- same >= SIGN_MIN
c3 <- nrow(pos) > 0 && sm$advantage < 0
cat("\nSM8  VERDICT\n")
cat(sprintf("     criterion 1, controlled >= %.2f SE : %s (%.2f)\n", SE_BAR,
            if (c1) "PASS" else "FAIL", r2))
cat(sprintf("     criterion 2, sign in >= %d of 12    : %s (%d)\n", SIGN_MIN,
            if (c2) "PASS" else "FAIL", same))
cat(sprintf("     criterion 3, crossover in range    : %s\n", if (c3) "PASS" else "FAIL"))
cat(sprintf("     R1, survives dropping SA           : %s (%.2f)\n",
            if (r3 >= 1) "PASS" else "REFUSE", r3))
cat(sprintf("\n     OVERALL: %s\n",
            if (c1 && c2 && c3 && r3 >= 1) "magnitude dependence SUPPORTED (adoption NOT authorised, R4/R5)"
            else "REFUSED / not established"))

fwrite(D, file.path("output", "swing-shape-by-magnitude.csv"))
cat("\nWrote output/swing-shape-by-magnitude.csv\n")
