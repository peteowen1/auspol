# refold_unfitted(), against docs/plans/prereg-refold-unfitted.md
#
# Two arms, off and on, on the same cycles and the same fitted parties. Only the
# OTH column's values differ, so n is equal by construction -- which is verified
# rather than assumed, because assuming it is exactly what went wrong in the
# inclusion-floor experiment.
#
# Emits RF* codes.

suppressMessages(devtools::load_all(".", quiet = TRUE))
library(data.table)

FLOOR <- 8L
ADOPT_BY <- 0.02
MIN_ROWS <- 5L
REGIONS <- c("fed", "nsw", "vic", "qld", "sa", "wa")
MIN_YEAR <- 1990

cycles <- load_election_cycles()
ev <- load_eventual_results()
pol <- load_polled_elections()
pri_all <- load_prior_results()

rows <- list(); refolds <- list()
t0 <- Sys.time()

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
    sel <- names(cnt)[cnt >= FLOOR]
    if (!("ALP" %in% sel)) next

    # The arms differ ONLY in the poll table handed to the fit. Same parties,
    # same priors, same cycle.
    stub <- stats::setNames(vector("list", length(sel)), sel)
    cp_on <- refold_unfitted(cp, fits = stub)
    rf <- attr(cp_on, "refolded")
    if (!is.null(rf) && nrow(rf)) {
      refolds[[length(refolds) + 1L]] <- cbind(region = rg, year = y, rf)
    }

    for (arm in c("off", "on")) {
      cpa <- if (identical(arm, "off")) cp else cp_on
      fits <- tryCatch(
        fit_cycle_unfolded(cpa, parties = sel, priors = priors, verbose = FALSE),
        error = function(e) NULL)
      if (is.null(fits)) next
      for (p in names(fits)) {
        ka2 <- act$party == p
        if (!any(ka2)) next
        tr <- fits[[p]]$trend
        rows[[length(rows) + 1L]] <- data.table(
          region = rg, year = y, arm = arm, party = p,
          fitted = tr$mean[which.max(tr$date)],
          actual = act$actual[which(ka2)][1])
      }
    }
    message(sprintf("  %s %d done (%.0f s)", rg, y,
                    as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
}

dt <- rbindlist(rows)
stopifnot(nrow(dt) > 0)
dt[, err := abs(fitted - actual)]

rf_all <- if (length(refolds)) rbindlist(refolds) else data.table()
cat(sprintf("\nRF1  rows refolded across the whole record: %d, in %d cycles\n",
            nrow(rf_all),
            if (nrow(rf_all)) uniqueN(rf_all[, paste(region, year)]) else 0L))
if (nrow(rf_all)) {
  print(rf_all[, .(rows = .N, mean_added = round(mean(added), 2)),
               by = .(region, year, party)][order(-rows)])
}

# The plan's "changes nothing" branch: a correction that almost never fires is
# not worth the code that can go wrong.
if (nrow(rf_all) < MIN_ROWS) {
  cat(sprintf("RF1  fewer than %d rows refolded -- per the plan, do not adopt.\n",
              MIN_ROWS))
}

# n must be equal by construction. Verify rather than assume.
n_by_arm <- dt[, .N, by = arm]
cat("\nRF2  rows scored per arm (must be equal)\n"); print(n_by_arm)
keys <- lapply(split(dt, dt$arm), function(d) paste(d$region, d$year, d$party))
same_rows <- length(unique(lapply(keys, sort))) == 1L
cat(sprintf("RF2  arms score identical (cycle, party) sets: %s\n", same_rows))
stopifnot(same_rows)

res <- dt[, .(mae = mean(err), n = .N), by = arm]
off <- res$mae[res$arm == "off"]; on <- res$mae[res$arm == "on"]
cat("\nRF3  total FP MAE (the criterion)\n"); print(res)
cat(sprintf("RF3  gain (off - on) = %+.4f;  adopt above %.2f\n", off - on, ADOPT_BY))

oth <- dt[party == "OTH", .(oth_mae = round(mean(err), 4), n = .N), by = arm]
cat("\nRF4  OTH MAE (reported, not the criterion)\n"); print(oth)
oth_gain <- oth$oth_mae[oth$arm == "off"] - oth$oth_mae[oth$arm == "on"]

# Only the cycles the correction actually touched can show anything; the rest
# are identical by construction and dilute the average.
touched <- if (nrow(rf_all)) unique(rf_all[, paste(region, year)]) else character(0)
if (length(touched)) {
  sub <- dt[paste(region, year) %in% touched]
  cat(sprintf("\nRF5  restricted to the %d cycle(s) actually refolded\n",
              length(touched)))
  print(sub[, .(mae = round(mean(err), 4), n = .N), by = arm])
  print(sub[party == "OTH", .(oth_mae = round(mean(err), 4)), by = arm])
}

verdict <- if (nrow(rf_all) < MIN_ROWS) {
  "REJECT: fires too rarely to be worth the code"
} else if (oth_gain > 0 && (off - on) <= ADOPT_BY) {
  sprintf(paste0("REJECT: OTH improves by %+.4f while the total moves only ",
                 "%+.4f. Moving vote into OTH changes what OTH has left to get ",
                 "wrong, so OTH-only evidence is the expected shape of an ",
                 "artefact."), oth_gain, off - on)
} else if ((off - on) > ADOPT_BY) {
  "ADOPT"
} else {
  sprintf("REJECT: gain %+.4f does not clear %.2f", off - on, ADOPT_BY)
}
cat(sprintf("\nRF6  verdict: %s\n", verdict))

fwrite(dt, file.path("output", "refold-test.csv"))
cat(sprintf("\nWrote output/refold-test.csv in %.0f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
