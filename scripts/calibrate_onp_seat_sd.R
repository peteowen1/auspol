# ONP_SEAT_SD, per docs/plans/prereg-onp-seat-uncertainty.md
#
# The Victorian One Nation seat allocation orders districts by Greens share
# (federally fitted coefficient) and quantile-maps onto South Australia's
# observed spread. South Australia voted in March 2026, so its actual per-seat
# One Nation shares are known -- which makes the method scorable.
#
# The rule, fixed before this was written: RMSE of that method against SA,
# rounded UP to the nearest 0.5, and REFUSE if it comes out below 3.5.
#
# Why the residual measures the right thing: quantile mapping forces the
# predicted marginal distribution to match SA's by construction, so magnitude
# cannot be wrong. Only the ORDERING can be, and the residual is precisely that
# -- which is the uncertainty the simulation currently omits.
#
# Emits OS* codes.

suppressMessages(devtools::load_all(".", quiet = TRUE))
library(data.table)

PREF <- election_data_path()
ONP_B1 <- -0.0968   # the same Greens coefficient fit_seats_full.R uses
FLOOR <- 3.5        # SEAT_SD; below this, refuse per the plan

fp <- fread(file.path(PREF, "ecsa-2026-sa-firstprefs.csv"))
tot <- fp[, list(total = sum(votes)), by = "seat"]
sh <- merge(fp, tot, by = "seat")
sh[, pct := 100 * votes / total]

w <- dcast(sh, seat ~ party, value.var = "pct", fill = 0)
stopifnot("GRN" %in% names(w), "ONP" %in% names(w))
actual <- setNames(w$ONP, w$seat)
grn <- setNames(w$GRN, w$seat)
cat(sprintf("\nOS1  SA districts with first preferences: %d\n", nrow(w)))
cat(sprintf("OS1  actual ONP: %.1f%% to %.1f%%, mean %.1f%%\n",
            min(actual), max(actual), mean(actual)))

# The method, applied to SA exactly as fit_seats_full.R applies it to Victoria.
target <- sort(actual / mean(actual))          # the spread being mapped onto
idx <- ONP_B1 * grn
ord <- order(idx)                              # strongest Greens first
ratio <- numeric(length(ord)); names(ratio) <- names(grn)
for (r in seq_along(ord)) {
  q <- (r - 1) / (length(ord) - 1)
  pos <- q * (length(target) - 1)
  lo <- floor(pos) + 1; hi <- min(lo + 1, length(target))
  ratio[names(grn)[ord[r]]] <- target[lo] + (pos - (lo - 1)) * (target[hi] - target[lo])
}
pred <- mean(actual) * ratio[names(actual)]

resid <- pred - actual
rmse <- sqrt(mean(resid^2))
BOUND <- ceiling(rmse * 2) / 2
cat(sprintf("\nOS2  RMSE of the allocation against SA = %.3f -> ONP_SEAT_SD = %.1f\n",
            rmse, BOUND))
cat(sprintf("OS2  mean |error| = %.3f;  worst seat off by %.1f points\n",
            mean(abs(resid)), max(abs(resid))))
cat(sprintf("OS2  correlation predicted vs actual = %+.3f\n",
            stats::cor(pred, actual)))

# A uniform allocation is the thing the ordering claims to beat. If it does not,
# the ordering is carrying no information and the uncertainty is the whole
# spread, not the residual.
rmse_flat <- sqrt(mean((mean(actual) - actual)^2))
cat(sprintf("OS3  RMSE of a FLAT allocation = %.3f (ordering %s it by %.3f)\n",
            rmse_flat, if (rmse < rmse_flat) "beats" else "LOSES to",
            abs(rmse_flat - rmse)))

cat(sprintf("\nOS4  plan's refusal condition (below %.1f): %s\n", FLOOR,
            if (BOUND < FLOOR) "REFUSE -- the allocation would be claiming to be
     more precise than a measured share" else "ok, adopt"))

out <- data.table(seat = names(actual), grn = round(grn[names(actual)], 2),
                  predicted = round(pred, 2), actual = round(actual, 2),
                  error = round(resid, 2))
print(out[order(-abs(error))][1:8])
fwrite(out, file.path("output", "onp-seat-calibration.csv"))
cat("\nWrote output/onp-seat-calibration.csv\n")
