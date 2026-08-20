# Does the trend systematically sit below recent polls, and does that help?
#
# Against docs/plans/prereg-poll-lag.md, committed BEFORE this ran. The decision
# rule and refusals P1-P4 are there and are NOT restated here.
#
# The Victorian One Nation fit is 20.66 against a 23.05 mean of the last 11
# polls. That has been treated as a defect for two days and two attempts to fix
# it have failed their own pre-registrations. Neither tested whether the lag is
# harmful. This does.
#
# Emits PL* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

WINDOW <- 90

d <- fread("output/fp-coverage.csv")   # fitted endpoint, actual, posterior sd
d[, cyc := paste(region, year)]
cycles <- load_election_cycles()
pri <- as.data.table(load_prior_results())

# Recent-poll mean per party-cycle, from the same polls the trend was fitted on.
rows <- list()
for (rg in unique(d$region)) {
  polls <- load_polls(rg)
  for (yr in unique(d[region == rg, year])) {
    cp <- as.data.table(cycle_polls(polls, yr, cycles))
    if (!nrow(cp)) next
    last_date <- max(cp$date)
    recent <- cp[date >= last_date - WINDOW]
    for (pty in d[region == rg & year == yr, party]) {
      if (!pty %in% names(cp)) next
      v <- recent[[pty]]; v <- v[is.finite(v)]
      if (!length(v)) next
      rows[[length(rows) + 1L]] <- data.table(
        region = rg, year = yr, party = pty,
        poll_mean = mean(v), n_polls = length(v))
    }
  }
}
pm <- rbindlist(rows)
d <- merge(d, pm, by = c("region", "year", "party"))
d <- merge(d, pri[, .(region, year, party, prior = prev1)],
           by = c("region", "year", "party"), all.x = TRUE)
d[, `:=`(gap = fitted - poll_mean, err = fitted - actual,
         poll_err = poll_mean - actual)]

cat(sprintf("\nPL1  %d party-cycles with both a fit and >=1 poll in the last %d days\n",
            nrow(d), WINDOW))

cat(sprintf("PL2  gap (fitted - recent poll mean): mean %+.3f, median %+.3f, sd %.3f; negative in %d of %d\n",
            mean(d$gap), stats::median(d$gap), stats::sd(d$gap),
            sum(d$gap < 0), nrow(d)))
cat("PL2  by party class\n")
print(d[, .(n = .N, gap = round(mean(gap), 2), level = round(mean(fitted), 1)),
        by = party][order(-n)])

# Clustered SE on a paired difference, cycle as the unit.
clustered_se_mean <- function(dd, col) {
  per <- dd[, .(m = mean(.SD[[1]]), n = .N), by = cyc, .SDcols = col]
  w <- per$n / sum(per$n)
  mu <- sum(w * per$m)
  sqrt(sum(w^2 * (per$m - mu)^2) * nrow(per) / (nrow(per) - 1))
}

compare <- function(dd, label) {
  dd <- copy(dd)
  dd[, d_abs := abs(err) - abs(poll_err)]      # negative => the TREND is better
  se <- clustered_se_mean(dd, "d_abs")
  mae_t <- mean(abs(dd$err)); mae_p <- mean(abs(dd$poll_err))
  sig <- mean(dd$d_abs) / se
  cat(sprintf("\n%s  (n = %d over %d cycles)\n", label, nrow(dd), uniqueN(dd$cyc)))
  cat(sprintf("  MAE  trend %.3f | recent polls %.3f | difference %+.3f (%.2f clustered SE)\n",
              mae_t, mae_p, mae_t - mae_p, sig))
  cat(sprintf("  RMSE trend %.3f | recent polls %.3f\n",
              sqrt(mean(dd$err^2)), sqrt(mean(dd$poll_err^2))))
  list(mae_t = mae_t, mae_p = mae_p, sig = sig, n = nrow(dd))
}

cat("\nPL3  which predicts the actual better?")
pool <- compare(d, "PL3  POOLED")

# Victoria-like: prior under 3%, recent polling over 10%. Defined in the plan
# BEFORE looking; an empty subset is the finding, not a licence to widen it.
vl <- d[is.finite(prior) & prior < 3 & poll_mean > 10]
cat(sprintf("\nPL4  Victoria-like subset (prior < 3%%, recent polls > 10%%): %d rows\n",
            nrow(vl)))
if (nrow(vl)) print(vl[, .(region, year, party, prior = round(prior, 2),
                           poll_mean = round(poll_mean, 1),
                           fitted = round(fitted, 1), actual = round(actual, 1),
                           gap = round(gap, 1))])
if (nrow(vl) >= 5) {
  sub <- compare(vl, "PL4  VICTORIA-LIKE")
} else {
  cat("PL4  fewer than 5 -- reporting the pooled result only, per the plan.\n")
  sub <- NULL
}

# P3: the direction of the One Nation record, which pre-commits a refusal.
onp <- d[party == "ONP"]
cat(sprintf("\nPL5  P3 check -- One Nation cycles: n = %d, mean error %+.2f (positive = we OVER-state)\n",
            nrow(onp), if (nrow(onp)) mean(onp$err) else NA_real_))
if (nrow(onp)) print(onp[, .(region, year, prior = round(prior, 2),
                             poll_mean = round(poll_mean, 1),
                             fitted = round(fitted, 1), actual = round(actual, 1),
                             err = round(err, 2))])

# P4: is any poll-mean advantage about house effects rather than shrinkage?
cat(sprintf("\nPL6  P4 check -- correlation of gap with the trend's error: %.3f\n",
            stats::cor(d$gap, d$err)))
cat(sprintf("PL6  regression of err on gap: slope %.3f\n",
            stats::coef(stats::lm(err ~ gap, data = d))[["gap"]]))

verdict <- if (pool$mae_t <= pool$mae_p || abs(pool$sig) <= 2) {
  "LAG IS NOT A DEFECT -- trend is no worse than following the polls; close it, change nothing"
} else {
  "SHRINKAGE IS HARMFUL -- worth a separate pre-registered experiment on the walk"
}
cat(sprintf("\nPL7  verdict: %s\n", verdict))
fwrite(d, file.path("output", "poll-lag.csv"))
cat("Wrote output/poll-lag.csv\n")
