# Should POLL_TRACKING_BOUND scale with poll count?
# Against docs/plans/prereg-poll-tracking-bound-scaling.md
#
# poll_tracking_check() compares a fitted endpoint against a MEAN of n polls.
# That mean carries its own sampling error, ~sd/sqrt(n), so even a perfect fit
# shows a deviation of expected size proportional to 1/sqrt(n) and a FIXED
# bound is structurally harsher on thinly-polled parties.
#
# The grid, criterion, decision rule and five refusal conditions are in the
# plan and are NOT restated here, so they cannot drift toward whatever comes
# out.
#
# ORDERING IS LOAD-BEARING AND ENFORCED BELOW. The plan requires the bound
# function to be derived and printed BEFORE anyone looks at whether NSW 2027
# passes under it. NSW is examined in the LAST section, after every refusal
# condition has already been evaluated.
#
# Emits BS* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

MIN_CYCLES_WITH_SPREAD <- 20L   # plan's abort gate
PCTILE <- 0.99                  # same rule as the fixed bound
SE_BAR <- 2                     # plan's adoption bar, in clustered SE

dt <- fread("output/poll-tracking-calibration.csv", showProgress = FALSE)
stopifnot(nrow(dt) > 0, all(c("region","year","party","n","dev") %in% names(dt)))
dt[, cycle := paste(region, year)]

cat("\n=== poll-tracking bound scaling ===\n")
cat(sprintf("%d rows over %d cycles\n", nrow(dt), uniqueN(dt$cycle)))

# ---- BS1: the abort gate, BEFORE any estimate ------------------------------
# Without within-cycle variation in n, the effect of n is not separable from
# the effect of the cycle, and any relationship found would be a cycle effect
# wearing a poll-count costume.
spread <- dt[, .(n_rows = .N, distinct_n = uniqueN(n),
                 min_n = min(n), max_n = max(n)), by = cycle]
n_with_spread <- sum(spread$distinct_n >= 2L)
cat(sprintf("\nBS1  %d of %d cycles contain >= 2 distinct values of n\n",
            n_with_spread, nrow(spread)))
cat(sprintf("BS1  n ranges %d to %d across the corpus\n", min(dt$n), max(dt$n)))
print(spread[order(-distinct_n)][1:min(10, nrow(spread))])

if (n_with_spread < MIN_CYCLES_WITH_SPREAD) {
  cat(sprintf(paste0(
    "\nBS1  ABORT: %d cycles with within-cycle spread in n, against a\n",
    "     pre-registered floor of %d. The effect of n cannot be separated\n",
    "     from the effect of the cycle on this record.\n"),
    n_with_spread, MIN_CYCLES_WITH_SPREAD))
  quit(save = "no", status = 0)
}
cat(sprintf("BS1  gate PASSED (%d >= %d)\n", n_with_spread, MIN_CYCLES_WITH_SPREAD))

# ---- cluster-robust SE, clustered on the cycle -----------------------------
# Implemented here rather than pulled in: this package imports only
# data.table/Matrix/stats/utils, and adding a dependency for one variance
# estimator would be a bigger change than the estimator.
cluster_se <- function(form, data, cluster) {
  m <- stats::lm(form, data = data)
  X <- stats::model.matrix(m)
  u <- stats::residuals(m)
  bread <- solve(crossprod(X))
  g <- split(seq_len(nrow(X)), cluster)
  meat <- Reduce(`+`, lapply(g, function(i) {
    xu <- crossprod(X[i, , drop = FALSE], u[i])
    tcrossprod(xu)
  }))
  G <- length(g); N <- nrow(X); K <- ncol(X)
  adj <- (G / (G - 1)) * ((N - 1) / (N - K))
  V <- bread %*% meat %*% bread * adj
  list(model = m, coef = stats::coef(m), se = sqrt(diag(V)), G = G)
}

dt[, inv_sqrt_n := 1 / sqrt(n)]
dt[, log_n := log(n)]

fit_isn <- cluster_se(dev ~ inv_sqrt_n, dt, dt$cycle)
fit_n   <- cluster_se(dev ~ n,          dt, dt$cycle)
fit_ln  <- cluster_se(dev ~ log_n,      dt, dt$cycle)

report <- function(lbl, f, term) {
  b <- f$coef[[term]]; s <- f$se[[term]]
  cat(sprintf("BS2  %-12s coef %+8.4f  clustered SE %6.4f  ratio %+6.2f  (G=%d)\n",
              lbl, b, s, b / s, f$G))
  b / s
}
cat("\nBS2  shape comparison -- 1/sqrt(n) is the mechanism's prediction;\n")
cat("     the other two are reported so a real effect of the WRONG shape is visible\n")
r_isn <- report("1/sqrt(n)", fit_isn, "inv_sqrt_n")
r_n   <- report("n",         fit_n,   "n")
r_ln  <- report("log(n)",    fit_ln,  "log_n")

cat(sprintf("\nBS2  adj R2: 1/sqrt(n) %.4f | n %.4f | log(n) %.4f\n",
            summary(fit_isn$model)$adj.r.squared,
            summary(fit_n$model)$adj.r.squared,
            summary(fit_ln$model)$adj.r.squared))

crit1 <- abs(r_isn) >= SE_BAR
crit2 <- summary(fit_isn$model)$adj.r.squared >=
         max(summary(fit_n$model)$adj.r.squared,
             summary(fit_ln$model)$adj.r.squared)
cat(sprintf("\nBS2  criterion 1 (|ratio| >= %d SE): %s\n", SE_BAR,
            if (crit1) "PASS" else "FAIL"))
cat(sprintf("BS2  criterion 2 (1/sqrt(n) not beaten on fit): %s\n",
            if (crit2) "PASS" else "FAIL"))

# ---- BS3: derive the scaled bound by the SAME 99th-percentile rule ---------
# bound(n) = k / sqrt(n), with k the smallest value such that
# dev_i <= k/sqrt(n_i) for PCTILE of rows -- i.e. the percentile of
# dev * sqrt(n). Same rule as the fixed bound, applied conditionally.
dt[, scaled_stat := dev * sqrt(n)]
k <- unname(quantile(dt$scaled_stat, PCTILE))
FIXED <- POLL_TRACKING_BOUND
cat(sprintf("\nBS3  k = %.1fth percentile of dev*sqrt(n) = %.4f\n", 100*PCTILE, k))
cat("BS3  implied bound(n) = k/sqrt(n):\n")
grid_n <- sort(unique(pmin(dt$n, 30)))
grid_n <- unique(c(3, 5, 10, 15, 20, 25, 30))
print(data.table(n = grid_n, scaled_bound = round(k / sqrt(grid_n), 3),
                 fixed = FIXED,
                 tighter_than_fixed = k / sqrt(grid_n) < FIXED))

# ---- BS4: the refusal conditions, evaluated BEFORE looking at NSW ----------
dt[, breach_fixed  := dev > FIXED]
dt[, breach_scaled := dev > k / sqrt(n)]

cat(sprintf("\nBS4  historical breaches: fixed %d of %d | scaled %d of %d\n",
            sum(dt$breach_fixed), nrow(dt), sum(dt$breach_scaled), nrow(dt)))

# R1 -- the anchor row must still breach.
anchor <- dt[which.max(dev)]
r1_ok <- anchor$dev > k / sqrt(anchor$n)
cat(sprintf("BS4  R1 anchor (%s %s, dev %.2f on n=%d): scaled bound %.2f -> %s\n",
            anchor$cycle, anchor$party, anchor$dev, anchor$n,
            k / sqrt(anchor$n), if (r1_ok) "still breaches, PASS" else "CLEARED, REFUSE"))

# R2 -- must not be a uniform loosening.
obs_n <- sort(unique(dt$n))
r2_ok <- any(k / sqrt(obs_n) < FIXED)
cat(sprintf("BS4  R2 uniform loosening: bound < %.1f at some observed n? %s\n",
            FIXED, if (r2_ok) "yes, PASS" else "NO -- looser everywhere, REFUSE"))

# R3 -- must not breach zero rows.
r3_ok <- sum(dt$breach_scaled) > 0L
cat(sprintf("BS4  R3 breaches nothing? %s\n",
            if (r3_ok) "no, PASS" else "YES -- catches nothing, REFUSE"))

cat("\nBS4  rows breaching under EITHER rule:\n")
print(dt[breach_fixed | breach_scaled,
         .(cycle, party, n, dev = round(dev,2),
           scaled_bound = round(k/sqrt(n),2), breach_fixed, breach_scaled)][order(-dev)])

adopt <- crit1 && crit2 && r1_ok && r2_ok && r3_ok
cat(sprintf("\nBS5  VERDICT on the historical record: %s\n",
            if (adopt) "all criteria and refusals pass" else "REFUSED"))

# ---- BS6: ONLY NOW look at the live cycles ---------------------------------
# Deliberately last. The bound function above was derived without reference to
# any of this, which is the whole point.
cat("\nBS6  live cycles, examined only after the bound was fixed:\n")
live <- data.table(
  cycle = c("vic 2026", "nsw 2027"),
  party = c("ONP", "ONP"),
  n = c(10L, 3L),
  dev = c(2.39, 5.15))
live[, scaled_bound := round(k / sqrt(n), 2)]
live[, breach_fixed := dev > FIXED]
live[, breach_scaled := dev > k / sqrt(n)]
print(live)
cat("\nBS6  R4 (Victoria must not flip to breaching): ")
v <- live[cycle == "vic 2026"]
cat(if (!v$breach_scaled) "does not breach, PASS\n" else "FLIPS TO BREACH -- REFUSE\n")
# R5 -- min_polls must NOT have moved. The plan forbids raising it: NSW 2027's
# One Nation is asserted on by one poll's margin, so a bump from 3 to 4 would
# make the breach vanish by declining to look. The default is a literal in the
# function signature, so it is compared directly rather than evaluated.
mp <- formals(poll_tracking_check)$min_polls
r5_ok <- is.numeric(mp) && as.integer(mp) == 3L
cat(sprintf("BS6  R5 min_polls still 3 (found %s): %s\n",
            format(mp), if (r5_ok) "confirmed" else "CHANGED -- REFUSE"))

fwrite(dt, file.path("output", "bound-scaling.csv"))
cat("\nWrote output/bound-scaling.csv\n")
