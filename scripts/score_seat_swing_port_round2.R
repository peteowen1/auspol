# Does the seat-swing port help the CANDIDATE model? Round 2.
#
# Against docs/plans/prereg-seat-swing-port-round2.md, committed before this
# ran. The three zones and refusals P1-P5 are there and are NOT restated.
#
# DEVIATION FROM THE PLAN, RECORDED RATHER THAN QUIETLY ABSORBED. The plan says
# three elections. There are TWO. seat_swing_adjustment() needs the seat file
# for the election being predicted and 2018vic.txt does not exist, so Victoria
# 2014->2018 cannot be ported and runs identically in both arms. The testable
# set is Victoria 2018->2022 and NSW 2023.
#
# That makes the power WORSE than the plan assumed -- a clustered standard
# error on ONE degree of freedom, not two. The plan already predicted the result
# would land in zone 3; this makes that near-certain.
#
# `prob` in the backtest output is the probability the model gave the party that
# actually won, so the Brier contribution of a seat is (1 - prob)^2.
#
# Emits PR* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

off <- fread(file.path("output", "backtest-vic-OFF.csv"), showProgress = FALSE)
on  <- fread(file.path("output", "backtest-vic-ON.csv"),  showProgress = FALSE)
stopifnot(nrow(off) == nrow(on))

m <- merge(off[, .(seat, pair, actual, p_off = prob)],
           on[, .(seat, pair, p_on = prob)], by = c("seat", "pair"))
if (nrow(m) != nrow(off)) stop("Seats do not line up between arms.")

# vic2018 is the untestable cycle: the port could not be applied, so both arms
# must be IDENTICAL there. If they are not, something other than the port moved
# and the comparison is invalid.
v18 <- m[pair == "vic2018"]
if (nrow(v18)) {
  d18 <- max(abs(v18$p_on - v18$p_off))
  cat(sprintf("\nPR0  vic2018 (not portable): largest probability difference %.6f\n", d18))
  if (d18 > 1e-9) {
    stop("Victoria 2014->2018 cannot be ported, so the two arms must be ",
         "identical there. They differ by ", signif(d18, 3), ", which means ",
         "something other than the seat-swing port changed between runs.")
  }
  cat("PR0  identical, as it must be. The comparison isolates the port.\n")
}

m[, `:=`(b_off = (1 - p_off)^2, b_on = (1 - p_on)^2)]
m[, d := b_on - b_off]      # negative = the port is better

cat("\nPR1  per election\n")
per <- m[, .(seats = .N,
             brier_off = mean(b_off), brier_on = mean(b_on),
             gain = mean(b_off) - mean(b_on)), by = pair]
print(per[, .(pair, seats, brier_off = round(brier_off, 5),
              brier_on = round(brier_on, 5), gain = round(gain, 5))])

test <- m[pair != "vic2018"]
cat(sprintf("\nPR2  testable set: %d seats across %d election(s): %s\n",
            nrow(test), uniqueN(test$pair),
            paste(unique(test$pair), collapse = ", ")))

# Two standard errors, both reported. The per-seat one is comparable with the
# original run's -0.04 SE; the election-clustered one is the honest number,
# because seats in a cycle share a flow matrix and the statewide draws.
mean_d <- mean(test$d)
se_seat <- stats::sd(test$d) / sqrt(nrow(test))
cat(sprintf("PR3  paired Brier difference %+.5f (negative = port better)\n", mean_d))
cat(sprintf("PR3  per-seat SE %.5f -> %+.2f SE  [comparable with round 1's -0.04]\n",
            se_seat, mean_d / se_seat))
per_el <- test[, .(d = mean(d)), by = pair]
if (nrow(per_el) > 1) {
  se_cl <- stats::sd(per_el$d) / sqrt(nrow(per_el))
  cat(sprintf("PR3  election-clustered SE %.5f on %d df -> %+.2f SE  [the honest one]\n",
              se_cl, nrow(per_el) - 1L, mean_d / se_cl))
} else {
  cat("PR3  only ONE testable election here, so no clustered SE exists. NSW 2023\n")
  cat("PR3  must be run separately and combined by hand; see PR6.\n")
}

# ---- zone 3 rule 2: direction consistency ----------------------------------
cat("\nPR4  direction by election (zone 3 rule 2 needs the port ahead in most)\n")
print(per_el[, .(pair, gain = round(-d, 5), port_better = d < 0)])

# ---- zone 3 rule 4: the mechanism check, which can override everything ------
# The adjustment sums to zero across seats, so it must move individual seats
# without moving the total. A non-zero net shift means it is doing something
# other than redistributing.
cat("\nPR5  mechanism -- the port redistributes, so seats must move and the mean must not\n")
moved <- test[abs(p_on - p_off) > 1e-6]
cat(sprintf("PR5  seats whose probability moved: %d of %d\n", nrow(moved), nrow(test)))
cat(sprintf("PR5  mean signed probability change: %+.6f (should be near zero)\n",
            mean(test$p_on - test$p_off)))
if (!nrow(moved)) {
  stop("The port changed no seat probabilities at all. It did not run, whatever ",
       "the diagnostics printed.")
}

cat("\nPR6  NSW 2023 must be scored the same way before any verdict. Its round-1\n")
cat("PR6  figure was -0.04 SE; refusal P3 says that number must not move.\n")
fwrite(m, file.path("output", "seat-swing-port-round2.csv"))
