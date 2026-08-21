# Does fed_swing's value decay with time since the federal election?
#
# Against docs/plans/prereg-gap-decay.md, committed before South Australia was
# scored. The decision rule and refusals G1-G5 are there and are NOT restated.
#
# G5 NEEDED A CLARIFICATION AND IT IS RECORDED RATHER THAN MADE QUIETLY. The
# clause says the original five elections' gains must be unchanged, or the run
# is invalid. But those gains come from leave-one-election-out, so adding South
# Australia to the training folds changes them legitimately -- the clause as
# written would fire on correct behaviour. Its INTENT is to catch upstream data
# drift, so it is implemented as: re-run the five-election configuration exactly
# as published and confirm it reproduces. Both sets of gains are reported. This
# clarification does not favour either outcome; it is a data-integrity check.
#
# Emits GD* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
fs <- fread(file.path(P, "fed-swing-transposed.csv"), showProgress = FALSE)

# (cycle, region, seat file holding its actual swing, federal election before
#  it, months between the two polling days, in the original five?)
CYCLES <- list(
  list(2022L, "vic", 2026L, 2022L,  6L, TRUE),
  list(2023L, "nsw", 2027L, 2022L, 10L, TRUE),
  list(2020L, "qld", 2024L, 2019L, 17L, TRUE),
  list(2018L, "sa",  2022L, 2016L, 20L, FALSE),
  list(2018L, "vic", 2022L, 2016L, 24L, TRUE),
  list(2019L, "nsw", 2023L, 2016L, 34L, TRUE),
  list(2022L, "sa",  2026L, 2019L, 34L, FALSE))

meta <- rbindlist(lapply(CYCLES, function(k) data.table(
  election = sprintf("%s%d", k[[2]], k[[1]]), fed = k[[4]],
  gap_months = k[[5]], original = k[[6]])))

d <- rbindlist(lapply(CYCLES, function(k) {
  after <- as.data.table(load_seats(k[[3]], k[[2]]))[, .(seat, actual = prev_swing)]
  tra <- fs[region == k[[2]] & cycle == k[[1]], .(seat, fed_swing)]
  m <- merge(after[is.finite(actual)], tra, by = "seat")
  m[, election := sprintf("%s%d", k[[2]], k[[1]])][]
}))
d[, `:=`(dev = actual - mean(actual),
         fed_c = fed_swing - mean(fed_swing)), by = election]

gains <- function(dat) {
  rbindlist(lapply(unique(dat$election), function(e) {
    f <- stats::lm(dev ~ fed_c, data = dat[election != e])
    te <- dat[election == e]
    mae <- mean(abs(te$dev - stats::predict(f, newdata = te)))
    data.table(election = e, seats = nrow(te), dispersion = mean(abs(te$dev)),
               gain = mean(abs(te$dev)) - mae)
  }))
}

# ---- G5: does the five-election configuration still reproduce? --------------
orig_el <- meta[original == TRUE, election]
g5 <- gains(d[election %in% orig_el])
PUBLISHED <- c(vic2022 = 0.3304, nsw2023 = 0.3773, qld2020 = -0.2849,
               vic2018 = -0.2021, nsw2019 = -0.0497)
g5[, published := PUBLISHED[election]]
g5[, drift := gain - published]
cat("\nGD1  G5 -- the original five, re-run in their original configuration\n")
print(g5[, .(election, gain = round(gain, 4), published = round(published, 4),
             drift = round(drift, 5))])
if (max(abs(g5$drift)) > 0.001) {
  stop("The original five elections' gains have moved by up to ",
       round(max(abs(g5$drift)), 4), ". Something upstream changed and this ",
       "run cannot be interpreted until that is explained.")
}
cat("GD1  reproduces to within 0.001. Nothing upstream moved.\n")

# ---- the test, on all seven -------------------------------------------------
g <- merge(gains(d), meta, by = "election")
setorder(g, gap_months)
cat("\nGD2  all seven elections, ordered by gap\n")
print(g[, .(election, fed, gap_months, seats, dispersion = round(dispersion, 3),
            gain = round(gain, 4), new = !original)])

# ---- G4: dispersion floor ---------------------------------------------------
excluded <- g[dispersion < 2.0]
if (nrow(excluded)) {
  cat(sprintf("\nGD3  G4 -- EXCLUDING %s: dispersion %s is below the 2.0 floor, so its\n",
              paste(excluded$election, collapse = ", "),
              paste(round(excluded$dispersion, 3), collapse = ", ")))
  cat("GD3  gain is uninformative about gap for the same reason qld2020 was.\n")
}
gt <- g[dispersion >= 2.0]

# ---- the prediction: both SA elections at or below zero ---------------------
sa <- g[election %in% c("sa2018", "sa2022")]
cat(sprintf("\nGD4  THE PRE-REGISTERED PREDICTION: both SA gains at or below zero\n"))
print(sa[, .(election, gap_months, dispersion = round(dispersion, 3),
             gain = round(gain, 4), predicted_ok = gain <= 0)])
both_ok <- all(sa$gain <= 0)
split <- length(unique(sa$gain > 0)) > 1L
refuted <- any(sa$gain > 0.20)

# ---- the group comparison ---------------------------------------------------
short <- gt[gap_months <= 12]; long <- gt[gap_months > 12]
sd_all <- stats::sd(gt$gain)
se <- sd_all * sqrt(1 / nrow(short) + 1 / nrow(long))
diff <- mean(short$gain) - mean(long$gain)
cat(sprintf("\nGD5  short gap (n=%d, %s): mean gain %+.4f\n", nrow(short),
            paste(short$election, collapse = ", "), mean(short$gain)))
cat(sprintf("GD5  long  gap (n=%d, %s): mean gain %+.4f\n", nrow(long),
            paste(long$election, collapse = ", "), mean(long$gain)))
cat(sprintf("GD5  difference %+.4f, SE %.4f -> %+.2f SE (bar set in advance: 2 SE)\n",
            diff, se, diff / se))
cat(sprintf("GD5  the plan predicted this would land near the bar; 2 SE is %.4f\n",
            2 * se))
cat(sprintf("GD5  Spearman correlation between gap and gain: %+.2f (n = %d)\n",
            stats::cor(gt$gap_months, gt$gain, method = "spearman"), nrow(gt)))

# ---- G1: is the gap confounded with the federal election? -------------------
cat("\nGD6  G1 -- gap against federal election, which this design cannot separate\n")
print(gt[, .(elections = paste(election, collapse = ", "),
             gaps = paste(gap_months, collapse = ", "),
             mean_gain = round(mean(gain), 4)), by = fed][order(fed)])

# ---- verdict ----------------------------------------------------------------
cat(sprintf("\nGD7  verdict: %s\n", if (refuted) {
  sprintf("REFUTED -- an SA election gained more than +0.20 (%s)",
          paste(sprintf("%s %+.3f", sa$election, sa$gain), collapse = ", "))
} else if (split) {
  "SPLIT (G3) -- the two SA elections disagree in sign, so nothing is concluded"
} else if (diff / se > 2 && both_ok) {
  "CONFIRMED at the pre-registered bar -- but see G1: gap and federal election are confounded, and this design cannot separate them"
} else {
  sprintf("UNDECIDED -- %+.2f SE against a 2 SE bar, which is what the plan predicted. Both SA gains %s the prediction.",
          diff / se, if (both_ok) "MATCH" else "do not match")
}))
cat("GD7  No change to SEAT_SWING_COEF on this evidence, as pre-registered.\n")
fwrite(g, file.path("output", "gap-decay.csv"))
