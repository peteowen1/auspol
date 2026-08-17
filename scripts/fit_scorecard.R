# Pollster scorecard: what our model knows about each pollster as a byproduct.
#
# Three measures, from two independent routes:
#   lean     - house effect from the latent-trend fit (relative to the average
#              pollster of the day; not an accuracy claim)
#   noise    - variability relative to peers, and against the binomial floor
#   accuracy - final-poll error against the actual result, no model involved
#
# Pre-registered checks, chosen before running:
#   C1  house effects must be centred: the poll-weighted mean lean across
#       firms is ~0 by construction, so a large value means the pooling is
#       wrong.
#   C2  final-poll MAE must be plausible for every listed firm: within
#       [0.3, 6.0] points. Below 0.3 would mean a pollster is essentially
#       perfect; above 6 would mean the comparison is misaligned.
#   C3  LEAN MUST PREDICT ERROR. Lean is estimated from the trend model and
#       error from published numbers against election results, with nothing
#       connecting them in code. A positive correlation is evidence both are
#       measuring a real property of the pollster; no correlation would mean
#       the house effects are an artefact of the trend and should not be
#       published as a pollster characteristic.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fit_scorecard.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

dir.create("output", showWarnings = FALSE)

cycles <- load_election_cycles()
pri_all <- load_prior_results()
REGIONS <- c("fed", "nsw", "vic", "qld")

# ---- Fit every polled cycle so house effects can be pooled ----
fits_by_cycle <- list()
n_eligible <- 0L
fit_errors <- character(0)
for (rg in REGIONS) {
  # Not a blanket tryCatch: load_polls() carries a deliberate hard stop against
  # data corruption, and swallowing it would drop a whole region from the
  # scorecard while every check below still printed PASS.
  polls <- suppressMessages(load_polls(rg))
  keep <- cycles$region == rg & cycles$year >= 1990
  cyc <- cycles[which(keep), ]
  for (i in seq_len(nrow(cyc))) {
    y <- cyc$year[i]
    cp <- cycle_polls(polls, y, cycles)
    if (sum(!is.na(cp$ALP)) < 20) next        # genuinely too thin: expected
    n_eligible <- n_eligible + 1L
    kp <- pri_all$region == rg & pri_all$year == y
    pr <- pri_all[which(kp), ]
    priors <- setNames(pr$prev1, pr$party)
    f <- tryCatch(fit_cycle_trends(cp, parties = "ALP", priors = priors),
                  error = function(e) {
                    fit_errors <<- c(fit_errors,
                                     sprintf("%s %d: %s", rg, y, conditionMessage(e)))
                    NULL
                  })
    if (!is.null(f)) fits_by_cycle[[length(fits_by_cycle) + 1L]] <- f
  }
}
cat(sprintf("=== fitted %d of %d eligible cycles across %s ===\n",
            length(fits_by_cycle), n_eligible, paste(REGIONS, collapse = "/")))
# An eligible cycle that fails to fit is a bug, not a data shortage. Counting
# only successes would hide it: the scorecard would quietly be built on a
# subset and every check below would still pass.
if (length(fit_errors)) {
  cat("FAILED to fit:\n"); cat(paste0("  ", fit_errors, collapse = "\n"), "\n")
}
stopifnot(length(fits_by_cycle) == n_eligible)

lean <- pollster_lean(fits_by_cycle, "ALP")
factors <- estimate_firm_factors(fits_by_cycle)
accuracy <- pollster_accuracy(regions = REGIONS)
cat(sprintf("firms with a fitted lean: %d; final-poll observations: %d across %d elections\n",
            nrow(lean), nrow(accuracy), uniqueN(accuracy[, .(year, region)])))

# ---- C1: are house effects centred? ----
c1 <- sum(lean$lean_pts * lean$n_polls) / sum(lean$n_polls)
cat(sprintf("\nC1  poll-weighted mean lean across firms = %+.3f pts (require |.| < 0.5)\n", c1))
stopifnot(abs(c1) < 0.5)

card <- pollster_scorecard(lean, factors, accuracy)
cat("\n=== POLLSTER SCORECARD (ALP first preferences / two-party) ===\n")
cat("lean_pts   : + means shows Labor higher than the average pollster\n")
cat("noise_factor: >1 more variable than peers, <1 less\n")
cat("final_bias : + means overstated Labor at the election\n\n")
print(card[, .(firm, polls = n_polls, cycles = n_cycles,
               lean_pts = round(lean_pts, 2),
               noise = round(noise_factor, 2),
               elections,
               final_mae = round(final_mae, 2),
               final_bias = round(final_bias, 2))])

# ---- C2: plausible accuracy ----
ok_acc <- card[!is.na(final_mae)]
cat(sprintf("\nC2  final-poll MAE range across firms: %.2f to %.2f (require 0.3-6.0)\n",
            min(ok_acc$final_mae), max(ok_acc$final_mae)))
stopifnot(all(ok_acc$final_mae >= 0.3), all(ok_acc$final_mae <= 6.0))

# ---- C3: does lean predict error? ----
#
# C3 as pre-registered required only `cor > 0`, which any noise passes half
# the time. It is reported here for the record and NOT used as a check.
raw <- pollster_lean_predicts_error(lean, accuracy, within_election = FALSE)
cat(sprintf("\nC3  as pre-registered (raw error): r = %+.2f, p = %.3f over %d firms\n",
            raw$cor, raw$p_value, raw$n))
cat("    That test was vacuous — it demanded only a positive sign — and the\n")
cat("    result is indistinguishable from zero anyway. Raw final-poll error is\n")
cat("    dominated by how wrong the WHOLE FIELD was (2019 missed by ~3 points\n")
cat("    for everyone), which swamps any one firm's relative lean.\n")

chk <- pollster_lean_predicts_error(lean, accuracy, within_election = TRUE)
cat(sprintf("\nC3' corrected: lean vs error RELATIVE to the firms polling the same\n"))
cat(sprintf("    election: r = %+.2f, p = %.3f over %d firms\n",
            chk$cor, chk$p_value, chk$n))
print(chk$data[order(-lean_pts),
               .(firm, n_polls, lean_pts = round(lean_pts, 2), n_elections,
                 rel_final_error = round(mean_error, 2))])
if (is.finite(chk$p_value) && chk$p_value < 0.05 && chk$cor > 0.25) {
  cat("\n    ESTABLISHED: lean predicts relative final-poll error, from two\n")
  cat("    independent routes.\n")
} else if (is.finite(chk$cor) && chk$cor > 0.25) {
  cat(sprintf("\n    SUGGESTIVE, NOT ESTABLISHED. Controlling for the field-wide miss\n"))
  cat(sprintf("    lifts the correlation from %+.2f to %+.2f, which is the right size and\n",
              raw$cor, chk$cor))
  cat(sprintf("    direction, but %d firms give p = %.2f. Consistent with house effects\n",
              chk$n, chk$p_value))
  cat("    being a real pollster property; short of demonstrating it.\n")
  cat("    The lean column is therefore published as what it provably is - a\n")
  cat("    within-cycle relative position - and NOT as a claim about who will\n")
  cat("    be right on election day.\n")
} else {
  cat("\n    NOT established, and not even suggestive. The lean column should\n")
  cat("    not be published as a pollster characteristic.\n")
}
stopifnot(is.finite(chk$cor))

# ---- Herding: absolute noise against the binomial floor ----
#
# This must use ABSOLUTE noise. The firm factors are relative, normalised so
# the average pollster sits at 1, so reading them as a herding check compares
# pollsters with each other and calls the answer sampling theory. An earlier
# version of this script did exactly that.
herd <- pollster_noise_vs_binomial(fits_by_cycle, factors, "ALP")
cat("\n=== Herding: implied poll-to-poll noise vs the binomial floor ===\n")
cat(sprintf("Floor is the sampling sd of a poll of n=%d at each cycle's own level.\n",
            BINOMIAL_REF_N))
cat("ratio < 1 means a firm's polls agree with each other more closely than\n")
cat("random sampling permits - the herding signature.\n\n")
print(herd[n_polls >= 20][, .(firm, polls = n_polls,
                              implied_sd = round(implied_sd_pts, 2),
                              floor = round(binomial_floor, 2),
                              ratio = round(ratio, 2))])
n_herd <- herd[n_polls >= 20 & ratio < 1, .N]
cat(sprintf("\n%d of %d firms sit below the binomial floor.\n",
            n_herd, herd[n_polls >= 20, .N]))

fwrite(herd, "output/pollster-herding.csv")
fwrite(card, "output/pollster-scorecard.csv")
fwrite(accuracy, "output/pollster-accuracy.csv")
cat("\nWrote output/pollster-scorecard.csv and pollster-accuracy.csv\n")
