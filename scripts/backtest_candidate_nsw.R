# Backtest the candidate-level seat model on NSW 2023.
#
# Against docs/plans/prereg-candidate-model-backtest.md (redesigned section),
# committed before this ran. The decision rule and refusals C1-C6 are there.
#
# THE MODEL THAT PUBLISHES EVERY SEAT NUMBER HAS NEVER BEEN SCORED. The
# calibration this repo has -- slope 1.113, Brier 0.0583 -- scores the two-party
# model, which is now a cross-check only.
#
# Nothing here is fitted on NSW 2023:
#   predictors and margins   load_seats(2023, "nsw")  -- the pre-election file
#   seat primaries to swing  nswec-2019-nsw-firstprefs.csv
#   transfer matrix          nsw2019 transfers ONLY, asserted below
#   truth                    nswec-2023-nsw-firstprefs.csv, cross-checked
#
# What this does NOT test: the Victoria-specific One Nation allocation (order by
# Greens share, magnitudes quantile-mapped onto SA). NSW One Nation has a real
# 2019 base to swing from -- 1.10% statewide -- so it is swung like every other
# party. That allocation needs its own test and does not get one here.
#
# Emits BT* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

N_SIMS <- 20000
SEED   <- 42
SMOOTH <- 0.15
PREF   <- election_data_path()

fp19 <- fread(file.path(PREF, "nswec-2019-nsw-firstprefs.csv"))
fp23 <- fread(file.path(PREF, "nswec-2023-nsw-firstprefs.csv"))
tx   <- fread(file.path(PREF, "nswec-nsw-transfers.csv"))

# LEAKAGE GUARD. The whole point of using NSW is that the flow matrix predates
# the election being scored. Asserted, not assumed -- three leaks have entered
# this repo before, one while fixing another.
tx19 <- tx[election == "nsw2019"]
stopifnot(nrow(tx19) > 0, !any(tx19$election == "nsw2023"))
cat(sprintf("\nBT0  flow matrix from %d transfers, elections: %s\n",
            nrow(tx19), paste(unique(tx19$election), collapse = ", ")))
fm <- build_flow_matrix(tx19, min_n = 3L)

seats <- as.data.table(load_seats(2023, "nsw"))

# Per-seat 2019 shares as a matrix.
w19 <- dcast(fp19, seat ~ party, value.var = "votes", fill = 0)
mat <- as.matrix(w19[, -1, with = FALSE]); rownames(mat) <- w19$seat
mat <- 100 * mat / rowSums(mat)

state19 <- fp19[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
state23 <- fp23[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
cat("\nBT1  statewide first preferences\n")
print(data.table(party = names(state19), y2019 = round(state19, 2),
                 y2023 = round(state23[names(state19)], 2),
                 swing = round(state23[names(state19)] - state19, 2))[order(-y2023)])

# TRUTH is the NSWEC's own declaration -- the candidate its distribution table
# marks ELECTED -- and NOT this package's exclusion of the actual votes.
#
# That distinction matters more than it looks. Deciding the winner by running
# real 2023 votes through distribute_preferences() would put the SAME flow
# matrix on both sides of the comparison, so any systematic flaw in it would
# cancel and the model would score better than it deserves. It is the leakage
# shape this repo keeps finding: a check that shares its error with the thing
# being checked.
win <- fread(file.path(PREF, "nswec-nsw-winners.csv"))[election == "nsw2023"]
stopifnot(nrow(win) == 93L)
truth <- setNames(win$winner, win$seat)
cat(sprintf("
BT2  truth from the NSWEC's ELECTED rows: %s
",
            paste(sprintf("%s %d", names(table(truth)), as.integer(table(truth))),
                  collapse = ", ")))

# Cross-check against the 2027 file's incumbent. NAT/LIB are recorded separately
# there and classify_party() maps both to LNP, so normalise before comparing --
# raw, eleven rural Coalition seats look like conflicts when both sources agree.
coal <- function(x) fifelse(x %in% c("NAT", "LIB", "LNP", "CLP"), "LNP", x)
inc27 <- as.data.table(load_seats(2027, "nsw"))[, .(seat, incumbent)]
chk <- merge(data.table(seat = names(truth), declared = unname(truth)), inc27, by = "seat")
chk[, `:=`(declared = coal(declared), incumbent = coal(incumbent))]
disagree <- chk[declared != incumbent]
cat(sprintf("BT2  cross-check against the 2027 incumbent: %d of %d differ
",
            nrow(disagree), nrow(chk)))
if (nrow(disagree)) {
  print(disagree)
  cat("BT2  differences are expected where a by-election has since changed hands;
")
  cat("BT2  the DECLARED 2023 result is truth and all 93 seats are scored.
")
}
keep <- names(truth)


# ---- project each seat's 2023 primaries: uniform swing off its 2019 share ----
parties <- colnames(mat)
shares <- mat
for (p in parties) {
  if (!p %in% names(state23)) next
  shares[, p] <- pmax(0, mat[, p] + (state23[[p]] - state19[[p]]))
}
shares <- 100 * shares / rowSums(shares)

sp <- seat_swing_spread(seats, unname(state23[["ALP"]] - state19[["ALP"]]))
cat(sprintf("\nBT3  seat spread: within %.2f, between %.2f\n", sp$sd_within, sp$sd_between))

set.seed(SEED)
psd <- setNames(rep(1.5, length(parties)), parties)
sim <- simulate_seat_contests(shares, fm, party_sd = psd, seat_sd = sp$sd_within,
                              n_sims = N_SIMS, smooth = SMOOTH, seed = SEED)
wp <- as.data.table(sim$win_prob)

sc <- merge(data.table(seat = names(truth), actual = unname(truth))[seat %in% keep],
            wp, by = "seat", all.x = TRUE, allow.cartesian = TRUE)
# A party absent from win_prob won zero draws; that is a real zero, not missing.
p_actual <- sc[party == actual, .(seat, p = prob)]
allseats <- data.table(seat = keep)
p_actual <- merge(allseats, p_actual, by = "seat", all.x = TRUE)
p_actual[is.na(p), p := 0]
pred <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
res <- merge(p_actual, pred, by = "seat")
res <- merge(res, data.table(seat = names(truth), actual = unname(truth)), by = "seat")

cat(sprintf("\nBT4  scored %d seats\n", nrow(res)))
cat(sprintf("BT4  winner accuracy: %d of %d (%.1f%%)\n",
            sum(res$pred == res$actual), nrow(res),
            100 * mean(res$pred == res$actual)))
cat(sprintf("BT5  Brier (on the party that won): %.4f\n", mean((1 - res$p)^2)))
eps <- 1e-6
cat(sprintf("BT5  mean log score: %.4f  (worse = more confident misses)\n",
            -mean(log(pmax(res$p, eps)))))
cat(sprintf("BT5  seats where the winner got < 5%% from us: %d\n", sum(res$p < 0.05)))
z <- data.frame(y = as.integer(res$pred == res$actual),
                lo = stats::qlogis(pmin(pmax(res$pred_p, eps), 1 - eps)))
if (length(unique(z$y)) > 1) {
  cat(sprintf("BT6  calibration slope on the argmax call: %.3f\n",
              stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]]))
}
res[, bin := cut(pred_p, c(0, .6, .7, .8, .9, .95, 1), include.lowest = TRUE)]
cat("BT6  reliability of the argmax call\n")
print(res[, .(n = .N, predicted = round(mean(pred_p), 3),
              observed = round(mean(pred == actual), 3)), by = bin][order(bin)])
cat("\nBT7  misses, worst first\n")
print(res[pred != actual][order(p)][, .(seat, we_said = pred,
                                        our_p = round(pred_p, 3),
                                        actual, p_we_gave_it = round(p, 3))])
# How much of the damage is independents? NSW 2023 elected NINE, and this
# model can barely elect any -- a defect already recorded but never costed.
cat("
BT8  with and without the seats an independent won
")
for (lab in c("all seats", "excluding IND wins")) {
  d <- if (lab == "all seats") res else res[actual != "IND"]
  z2 <- data.frame(y = as.integer(d$pred == d$actual),
                   lo = stats::qlogis(pmin(pmax(d$pred_p, eps), 1 - eps)))
  sl <- if (length(unique(z2$y)) > 1)
    stats::coef(stats::glm(y ~ lo, data = z2, family = stats::binomial()))[["lo"]] else NA_real_
  cat(sprintf("     %-20s n %2d | accuracy %.1f%% | Brier %.4f | slope %s
",
              lab, nrow(d), 100 * mean(d$pred == d$actual),
              mean((1 - d$p)^2),
              if (is.finite(sl)) sprintf("%.3f", sl) else "n/a"))
}
cat(sprintf("BT8  independents won %d of %d scored seats; we gave them a mean %.3f
",
            sum(res$actual == "IND"), nrow(res),
            mean(res[actual == "IND", p])))

fwrite(res[order(seat)], file.path("output", "backtest-nsw2023.csv"))
cat("\nWrote output/backtest-nsw2023.csv\n")
