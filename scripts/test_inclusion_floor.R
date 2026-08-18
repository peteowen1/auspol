# The party-inclusion floor, against docs/plans/prereg-party-inclusion-floor.md
#
# Which parties get fitted at all is decided by a per-cycle poll count -- 8 in
# the state scripts. A party under it is not fitted, its support stays inside
# OTH, and unfold_others() cannot run on it. One Nation misses the NSW 2023
# floor by a single poll.
#
# The grid, criterion and decision rule are in the plan and are NOT restated
# here, so they cannot drift toward whatever comes out.
#
# Emits IF* codes.

suppressMessages(devtools::load_all(".", quiet = TRUE))
library(data.table)

FLOORS <- c(5L, 6L, 7L, 8L, 10L, 12L, 15L)
STATUS_QUO <- 8L
ADOPT_BY <- 0.02
REGIONS <- c("fed", "nsw", "vic", "qld", "sa", "wa")
MIN_YEAR <- 1990

cycles <- load_election_cycles()
ev <- load_eventual_results()
pol <- load_polled_elections()
pri_all <- load_prior_results()
flows_all <- load_preference_flows()

cat("\n=== party-inclusion floor ===\n")
cat("floors:", paste(FLOORS, collapse = ", "),
    "| status quo:", STATUS_QUO, "| adopt by:", ADOPT_BY, "MAE\n\n")

rows <- list()
t0 <- Sys.time()

for (rg in REGIONS) {
  f <- anchor_data_path(sprintf("poll-data-%s.csv", rg), must_exist = FALSE)
  if (!file.exists(f)) next
  polls <- suppressMessages(load_polls(rg))
  ps_all <- attr(polls, "parties")

  for (y in sort(pol$year[which(pol$region == rg & pol$year >= MIN_YEAR)])) {
    krow <- cycles$region == rg & cycles$year == y
    if (!any(krow)) next
    cyc <- cycles[which(krow), ]

    ka <- ev$region == rg & ev$year == y & ev$party != "@TPP"
    act <- ev[which(ka), ]
    if (!nrow(act) || abs(sum(act$actual) - 100) > 5) next

    kp <- pri_all$region == rg & pri_all$year == y
    pr <- pri_all[which(kp), ]
    if (!nrow(pr)) next
    priors <- stats::setNames(pr$prev1, pr$party)

    cp <- cycle_polls(polls, y, cycles)
    cnt <- vapply(ps_all, function(q) sum(!is.na(cp[[q]])), 1L)

    for (fl in FLOORS) {
      sel <- names(cnt)[cnt >= fl]
      if (!("ALP" %in% sel)) next
      fits <- tryCatch(
        fit_cycle_unfolded(cp, parties = sel, priors = priors, verbose = FALSE),
        error = function(e) NULL)
      if (is.null(fits)) next
      corrected <- attr(fits, "folded")
      n_corr <- if (is.null(corrected)) 0L else nrow(corrected)

      for (p in names(fits)) {
        ka2 <- act$party == p
        # A party the recorded result does not break out cannot be scored. It
        # is counted, because a floor that adds fits the criterion is blind to
        # is not obviously an improvement.
        tr <- fits[[p]]$trend
        rows[[length(rows) + 1L]] <- data.table(
          region = rg, year = y, floor = fl, party = p,
          fitted = tr$mean[which.max(tr$date)],
          actual = if (any(ka2)) act$actual[which(ka2)][1] else NA_real_,
          scorable = any(ka2), n_corrected = n_corr)
      }
    }
    message(sprintf("  %s %d done (%.0f s)", rg, y,
                    as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
}

dt <- rbindlist(rows)
stopifnot(nrow(dt) > 0)
dt[, err := abs(fitted - actual)]

# IF1 -- the pre-registered criterion: TOTAL first-preference MAE across all
# fitted, scorable parties.
#
# Computed TWICE, because the obvious version is confounded. Each floor fits a
# different set of (cycle, party) rows -- 149 at floor 5 down to 125 at floor 15
# -- and the rows a higher floor declines to fit are the thinly-polled minor
# parties, which are the hardest. Comparing raw means therefore rewards a floor
# for NOT PREDICTING the difficult cases. The plan warned about this trap in one
# form (scoring OTH alone) and missed it in this one.
raw <- dt[scorable == TRUE, .(mae = mean(err), n_fits = .N,
                              n_cycles = uniqueN(paste(region, year))),
          by = floor][order(floor)]
cat("\nIF1  raw FP MAE by floor -- CONFOUNDED, shown so the confound is visible\n")
print(raw)
cat("     n_fits and n_cycles differ by arm; do not read this table as a result.\n")

dt[, row_key := paste(region, year, party)]
common <- Reduce(intersect,
                 lapply(sort(unique(dt$floor)),
                        function(f) dt[scorable == TRUE & floor == f, row_key]))
pd <- dt[scorable == TRUE & row_key %in% common]
res <- pd[, .(mae = mean(err), n = .N), by = floor][order(floor)]
sq_mae <- res$mae[res$floor == STATUS_QUO]
res[, vs_sq := round(mae - sq_mae, 4)]
cat("\nIF1b total FP MAE on the rows EVERY floor fits (the valid comparison)\n")
print(res)

cat("\nIF2  OTH MAE on those same rows (reported, not the criterion)\n")
print(pd[party == "OTH", .(oth_mae = round(mean(err), 4), n = .N),
         by = floor][order(floor)])

cat("\nIF3  fits the recorded results cannot score\n")
print(dt[scorable == FALSE, .(unscorable = .N), by = floor][order(floor)])

corr <- unique(dt[, .(region, year, floor, n_corrected)])[
  , .(fold_corrections = sum(n_corrected)), by = floor][order(floor)]
cat("\nIF4  unfold_others() corrections enabled\n")
print(corr)

best <- res[which.min(mae)]
gain <- sq_mae - best$mae
cat(sprintf("\nIF5  best floor %d at MAE %.4f; status quo %d at %.4f; gain %.4f\n",
            best$floor, best$mae, STATUS_QUO, sq_mae, gain))

# IF6 -- THE ANCHOR, and it is what decides this.
#
# A floor is a rule about which parties exist in the forecast, so before
# believing any error metric, check what the winning floor does to a party we
# already know must be in the model. One Nation polls 24.67 in the NSW 2027
# cycle on 8 polls. A floor that excludes a party polling 24.67 is wrong
# whatever it does to historical MAE, and this repo's own rule is that an anchor
# failing means the METHOD is wrong rather than the anchor being an exception.
LIVE <- list(list(rg = "vic", yr = 2026L), list(rg = "nsw", yr = 2027L),
             list(rg = "fed", yr = 2028L))
anchor <- rbindlist(lapply(LIVE, function(z) {
  pl <- suppressMessages(load_polls(z$rg))
  cpz <- cycle_polls(pl, z$yr, cycles)
  cz <- vapply(attr(pl, "parties"), function(q) sum(!is.na(cpz[[q]])), 1L)
  mz <- vapply(attr(pl, "parties"), function(q) mean(cpz[[q]], na.rm = TRUE), 1)
  rbindlist(lapply(names(cz), function(q) data.table(
    region = z$rg, year = z$yr, party = q, n_polls = cz[[q]],
    mean_share = round(mz[[q]], 2))))
}))
anchor <- anchor[is.finite(mean_share) & mean_share >= 5]
anchor[, fitted_at_best := n_polls >= best$floor]
anchor[, fitted_at_sq := n_polls >= STATUS_QUO]
cat("\nIF6  parties polling >= 5% in a LIVE cycle, and whether each floor fits them\n")
print(anchor[order(-mean_share)])
lost <- anchor[fitted_at_sq == TRUE & fitted_at_best == FALSE]
anchor_ok <- nrow(lost) == 0L
if (!anchor_ok) {
  cat(sprintf("IF6  ANCHOR FAILS: floor %d would drop %s\n", best$floor,
              paste(sprintf("%s %s (%.1f%% on %d polls)", lost$region, lost$party,
                            lost$mean_share, lost$n_polls), collapse = "; ")))
}

verdict <- if (identical(as.integer(best$floor), as.integer(STATUS_QUO))) {
  "status quo already best -- no change"
} else if (!anchor_ok) {
  sprintf(paste0("REFUSE floor %d: it clears the MAE bar but drops a party ",
                 "polling in double digits. The criterion cannot see that."),
          best$floor)
} else if (gain <= ADOPT_BY) {
  sprintf("gain %.4f does not clear %.2f -- keep %d", gain, ADOPT_BY, STATUS_QUO)
} else {
  sprintf("ADOPT floor %d", best$floor)
}
cat(sprintf("IF5  verdict: %s\n", verdict))


fwrite(dt, file.path("output", "inclusion-floor.csv"))
cat(sprintf("\nWrote output/inclusion-floor.csv in %.0f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
