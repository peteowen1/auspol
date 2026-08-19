# ANCHOR_K, per docs/plans/prereg-anchor-informativeness.md
#
# A previous-election result near zero says almost nothing about where a party
# starts, but trend_anchor() pinned day 0 to it at the TIGHTER of the two
# anchors -- tighter than a party with no previous result at all. Below
# anchor_k the weak anchor is used instead. Both sd values are unchanged; K is
# the only new number.
#
# The grid, criterion, four acceptance criteria and four refusals are in the
# plan and are NOT restated here so they cannot drift.
#
# Emits AK* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

GRID <- c(1, 2, 3, 5, 8)     # K = 0 is the control, not a grid point
CONTROL <- 0
NO_HARM <- 0.02
REGIONS <- c("fed", "nsw", "vic", "qld", "sa", "wa")
MIN_YEAR <- 1990
MAJORS <- c("ALP", "LNP", "LIB", "NAT")

cycles <- load_election_cycles(); ev <- load_eventual_results()
pol <- load_polled_elections(); pri_all <- load_prior_results()

rows <- list(); t0 <- Sys.time()
for (rg in REGIONS) {
  f <- anchor_data_path(sprintf("poll-data-%s.csv", rg), must_exist = FALSE)
  if (!file.exists(f)) next
  polls <- suppressMessages(load_polls(rg))
  ps_all <- attr(polls, "parties")
  for (y in sort(pol$year[which(pol$region == rg & pol$year >= MIN_YEAR)])) {
    if (!any(cycles$region == rg & cycles$year == y)) next
    ka <- ev$region == rg & ev$year == y & ev$party != "@TPP"
    act <- ev[which(ka), ]
    if (!nrow(act) || abs(sum(act$actual) - 100) > 5) next
    kp <- pri_all$region == rg & pri_all$year == y
    pr <- pri_all[which(kp), ]
    if (!nrow(pr)) next
    priors <- stats::setNames(pr$prev1, pr$party)

    cp <- cycle_polls(polls, y, cycles)
    cnt <- vapply(ps_all, function(q) sum(!is.na(cp[[q]])), 1L)
    sel <- names(cnt)[cnt >= 8]
    if (!("ALP" %in% sel)) next
    late <- cp$date > max(cp$date) - 30

    for (K in c(CONTROL, GRID)) {
      fits <- tryCatch(
        fit_cycle_unfolded(cp, parties = sel, priors = priors,
                           anchor_k = K, verbose = FALSE),
        error = function(e) NULL)
      if (is.null(fits)) next
      for (p in names(fits)) {
        ka2 <- act$party == p
        if (!any(ka2)) next
        tr <- fits[[p]]$trend
        v <- if (p %in% names(cp)) cp[[p]][late] else NA_real_
        rows[[length(rows) + 1L]] <- data.table(
          region = rg, year = y, K = K, party = p,
          fitted = tr$mean[which.max(tr$date)],
          actual = act$actual[which(ka2)][1],
          prior = unname(priors[p] %||% NA_real_),
          polls30 = if (any(!is.na(v))) mean(v, na.rm = TRUE) else NA_real_)
      }
    }
    message(sprintf("  %s %d done (%.0f s)", rg, y,
                    as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
}

dt <- rbindlist(rows)
stopifnot(nrow(dt) > 0)
dt[, err := abs(fitted - actual)]
dt[, cyc := paste(region, year)]
cat(sprintf("\nAK1  %d rows, %d cycles, K in {%s}\n", nrow(dt), uniqueN(dt$cyc),
            paste(sort(unique(dt$K)), collapse = ", ")))

# Every K must fit the same rows, or the comparison is the inclusion-floor
# mistake again: an arm cannot win by declining to predict.
n_by_K <- dt[, .N, by = K][order(K)]
cat("AK1  rows per K (must be equal)\n"); print(n_by_K)
stopifnot(length(unique(n_by_K$N)) == 1L)

per <- dt[, .(mae = mean(err)), by = .(cyc, K)]
by_K <- per[, .(mae = mean(mae)), by = K][order(K)]
ctrl <- by_K$mae[by_K$K == CONTROL]
by_K[, vs_control := round(mae - ctrl, 4)]
cat("\nAK2  mean per-cycle FP MAE by K\n"); print(by_K)

# Leave-one-cycle-out: pick K on the other cycles, score on the held-out one.
loo <- rbindlist(lapply(unique(per$cyc), function(c1) {
  tr <- per[cyc != c1, .(mae = mean(mae)), by = K]
  best <- tr$K[which.min(tr$mae)]
  data.table(cyc = c1, K_chosen = best,
             mae = per[cyc == c1 & K == best, mae],
             mae_ctrl = per[cyc == c1 & K == CONTROL, mae])
}))
cat(sprintf("\nAK3  leave-one-cycle-out: held-out MAE %.4f vs control %.4f (gain %+.4f)\n",
            mean(loo$mae), mean(loo$mae_ctrl), mean(loo$mae_ctrl) - mean(loo$mae)))
cat("AK3  K chosen per held-out cycle:\n"); print(table(loo$K_chosen))

best_K <- by_K$K[which.min(by_K$mae)]
runner <- sort(by_K$mae)[2]
cat(sprintf("\nAK4  best K = %g (MAE %.4f); runner-up %.4f; margin %.4f\n",
            best_K, min(by_K$mae), runner, runner - min(by_K$mae)))

gap <- function(d) d[is.finite(polls30), mean(abs(fitted - polls30))]
big <- dt[is.finite(prior) & is.finite(polls30) & abs(prior - polls30) > 10]
cat(sprintf("\nAK5  A2 target group (|prior - polls| > 10): %d rows per K\n",
            nrow(big[K == CONTROL])))
print(big[, .(gap_to_polls = round(gap(.SD), 4)), by = K][order(K)])

# R1: a party whose polls sit NEAR its low prior must be essentially unmoved.
near <- dt[is.finite(prior) & is.finite(polls30) & prior < best_K &
             abs(prior - polls30) < 5]
cat(sprintf("\nAK6  R1 near-prior group (prior < %g, |prior - polls| < 5): %d rows\n",
            best_K, nrow(near[K == CONTROL])))
if (nrow(near)) print(near[, .(gap = round(gap(.SD), 4)), by = K][order(K)])

# R2: majors must be bit-for-bit unaffected.
mj <- dcast(dt[party %in% MAJORS], region + year + party ~ K, value.var = "fitted")
cols <- setdiff(names(mj), c("region", "year", "party"))
moved <- sum(vapply(setdiff(cols, as.character(CONTROL)), function(cc)
  sum(abs(mj[[cc]] - mj[[as.character(CONTROL)]]) > 1e-9, na.rm = TRUE), 1L))
cat(sprintf("\nAK7  R2 major-party fitted values that moved at any K: %d (must be 0)\n",
            moved))

cat(sprintf("\nAK8  R3 best K at grid edge (%g or %g): %s\n",
            min(GRID), max(GRID),
            if (best_K %in% range(GRID)) "YES -- REFUSE" else "no"))
fwrite(dt, file.path("output", "anchor-k.csv"))
cat("\nWrote output/anchor-k.csv\n")
