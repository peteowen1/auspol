# Does adding Western Australia's transfers forecast better?
#
# Criterion, decision rule and refusals are fixed in
# docs/plans/prereg-wa-flows.md, committed before any arm was run.
#
# NINE elections, not ten. New South Wales is excluded because it is optional
# preferential -- see the amendment at the foot of that plan. Six federal, two
# Victorian, one South Australian.
#
# Arms, each written to its own filename because a shared one has silently
# overwritten a baseline here four times:
#
#   baseline  AUSPOL_QLD_FLOWS=1                              -> *-qld
#   plus WA   AUSPOL_QLD_FLOWS=1 AUSPOL_WA_FLOWS=1            -> *-qld-wa
#   control   the same, plus AUSPOL_WA_CUTOFF=1990-01-01      -> *-qld-wa-cut
#
# The cutoff is PER SOURCE. It was global on the first attempt, so the
# control held Queensland out as well and could not match a baseline that
# has it. W1 failed and was correct to; the arms above are unaffected.
#
# Emits SW* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

SUF <- Sys.getenv("AUSPOL_SCORE_SUFFIX", "-n5000")   # sims tag the arms carry
EPS <- 1e-6

arm_files <- function(tag) {
  file.path("output", c(sprintf("backtest-fed%s%s.csv", SUF, tag),
                        sprintf("backtest-vic%s%s.csv", SUF, tag),
                        sprintf("backtest-sa%s%s.csv", SUF, tag)))
}
read_arm <- function(tag) {
  f <- arm_files(tag)
  miss <- f[!file.exists(f)]
  if (length(miss)) stop("Arm '", tag, "' is missing: ", paste(miss, collapse = ", "))
  d <- rbindlist(lapply(f, fread, showProgress = FALSE), fill = TRUE)
  d[, .(pair, seat, actual, prob, pred)]
}

# BYTE-IDENTICAL ARMS ABORT. Comparing log scores cannot tell "no effect" from
# "the same file twice", and this repo has produced the latter four times --
# most recently a filename guard that changed where runs wrote while the
# comparison still read the old name. The md5 is the check; the score is not.
md5_of <- function(tag) tools::md5sum(arm_files(tag))
# tools::md5sum() returns NA for a file that does not exist, and
# identical(NA, NA) is TRUE -- so with NEITHER arm run, the byte-identity check
# below fired and reported "the same run scored twice", which is the wrong
# diagnosis for "nothing has been run yet" and sends the reader hunting a
# duplicate-run bug that is not there.
.want <- c(arm_files("-qld"), arm_files("-qld-wa"))
if (!all(file.exists(.want))) {
  stop("Arms have not been run. Missing: ",
       paste(basename(.want[!file.exists(.want)]), collapse = ", "))
}
base_h <- md5_of("-qld"); wa_h <- md5_of("-qld-wa")
if (identical(unname(base_h), unname(wa_h))) {
  stop("The baseline and Western Australia arms are byte-identical. That is ",
       "not a null result, it is the same run scored twice.")
}

A <- read_arm("-qld");    A[, arm := "base"]
B <- read_arm("-qld-wa"); B[, arm := "wa"]
cat(sprintf("\nSW1  %d seat-elections per arm across %d elections: %s\n",
            nrow(A), uniqueN(A$pair), paste(sort(unique(A$pair)), collapse = ", ")))
if (nrow(A) != nrow(B)) {
  stop("The arms score different numbers of seats (", nrow(A), " vs ", nrow(B),
       "). An arm that drops seats is fitted on an easier subset, not better.")
}
if (uniqueN(A$pair) != 9L) {
  stop("Expected 9 elections and found ", uniqueN(A$pair),
       ". New South Wales must not be here and nothing may be missing.")
}

M <- merge(A, B, by = c("pair", "seat"), suffixes = c("_a", "_b"))
stopifnot(nrow(M) == nrow(A), all(M$actual_a == M$actual_b))
M[, `:=`(ls_a = -log(pmax(prob_a, EPS)), ls_b = -log(pmax(prob_b, EPS)))]

# Clustered on the ELECTION, which is the independent observation. Seats within
# an election share a statewide vote and a flow matrix, so treating 1,300 seats
# as 1,300 observations would understate the standard error by roughly 12x.
per <- M[, .(n = .N,
             base = mean(ls_a), wa = mean(ls_b),
             gain = mean(ls_a) - mean(ls_b),
             acc_a = mean(pred_a == actual_a), acc_b = mean(pred_b == actual_b)),
         by = pair][order(pair)]
cat("\nSW2  per-election log score, lower is better\n")
print(per[, .(pair, n, base = round(base, 4), wa = round(wa, 4),
              gain = round(gain, 4),
              accuracy = sprintf("%.1f%% -> %.1f%%", 100 * acc_a, 100 * acc_b))])

g <- per$gain
se <- stats::sd(g) / sqrt(length(g))
t  <- mean(g) / se
cat(sprintf("\nSW3  mean gain %+.4f, SE %.4f, %+.2f SE on %d df\n",
            mean(g), se, t, length(g) - 1L))
cat(sprintf("SW3  improved in %d of %d elections\n", sum(g > 0), length(g)))
cat(sprintf("SW3  pooled accuracy %.2f%% -> %.2f%%\n",
            100 * mean(M$pred_a == M$actual_a), 100 * mean(M$pred_b == M$actual_b)))

# W1, the plumbing control. Western Australia's earliest election predates
# every backtest election, so unlike Queensland there is no set that naturally
# admits nothing. This arm runs with the flows ON and a cutoff that admits
# nothing, and MUST reproduce the baseline exactly.
cat("\nSW4  control W1: flows on, cutoff 1990, nothing admissible\n")
if (all(file.exists(arm_files("-qld-wa-cut")))) {
  same <- identical(unname(md5_of("-qld")), unname(md5_of("-qld-wa-cut")))
  cat(sprintf("SW4  %s\n", if (same)
    "PASS -- byte-identical to the baseline, so the filter is what admits data." else
    "FAIL -- the control differs from the baseline. The date filter is not the only thing switching WA on, and nothing else in this run can be believed."))
  if (!same) stop("Control W1 failed.")
} else {
  cat("SW4  NOT RUN. The control is required by the pre-registration; the\n")
  cat("SW4  measurement above is not decidable without it.\n")
}

cat(sprintf("\nSW5  decision rule from docs/plans/prereg-wa-flows.md\n"))
cat(sprintf("SW5  %+.2f SE -> %s\n", t,
            if (t > 2) "ADOPT (over 2 SE)"
            else if (t > 0) "positive but under 2 SE: adopt if the control passes and no refusal fires"
            else if (t > -1) "negative but within 1 SE: adopt is not available; report"
            else "REFUSE AND INVESTIGATE (negative by more than 1 SE)"))

# ---- the fallback arm W2 fixed in advance ----------------------------------
# Refusal W2 named this before any result: if the pooled LNP->LNP rate cleared
# 30%, admit Western Australia's non-LNP-origin exclusions and drop its
# LNP-origin ones, AND score it as its own arm rather than substituting it for
# the primary one. The rate came in at 36.4%, so W2 fired and this is run.
if (all(file.exists(arm_files("-qld-wa-nolnp")))) {
  C <- read_arm("-qld-wa-nolnp")
  if (identical(unname(md5_of("-qld-wa")), unname(md5_of("-qld-wa-nolnp")))) {
    stop("The fallback arm is byte-identical to the full WA arm; the LNP-origin ",
         "drop did not apply.")
  }
  M2 <- merge(A, C, by = c("pair", "seat"), suffixes = c("_a", "_c"))
  stopifnot(nrow(M2) == nrow(A))
  M2[, `:=`(ls_a = -log(pmax(prob_a, EPS)), ls_c = -log(pmax(prob_c, EPS)))]
  p2 <- M2[, .(gain = mean(ls_a) - mean(ls_c)), by = pair][order(pair)]
  g2 <- p2$gain; se2 <- stats::sd(g2) / sqrt(length(g2))
  cat("
SW6  fallback arm: WA without its Coalition-origin exclusions
")
  print(p2[, .(pair, gain = round(gain, 4))])
  cat(sprintf("SW6  mean gain %+.4f, SE %.4f, %+.2f SE on %d df, improved in %d of %d
",
              mean(g2), se2, mean(g2) / se2, length(g2) - 1L,
              sum(g2 > 0), length(g2)))
  cat(sprintf("SW6  full WA was %+.2f SE; the fallback is %+.2f SE
",
              t, mean(g2) / se2))
} else {
  cat("
SW6  fallback arm NOT RUN. W2 fired, so the pre-registration requires it.
")
}

fwrite(per, file.path("output", "wa-flows-per-election.csv"))
