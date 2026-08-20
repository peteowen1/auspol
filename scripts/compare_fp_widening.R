# Which widening factor for first-preference bands: the pre-registered two-party
# projection error, or the ML estimate on the FP residuals?
#
# Against docs/plans/prereg-fp-widening-choice.md, committed BEFORE this ran.
# The rule and its four refusals are there and are NOT restated here. In short:
# candidate A (2.419, pre-registered) is the default and wins ties; B (2.127)
# only gets considered if A fails, and adopting B is a recorded deviation.
#
# Test 1 was AMENDED after the first run -- see the amendment at the foot of the
# plan. It required coverage within 5 fixed points of nominal, which at the 50%
# level is 1.16 clustered standard errors: a rule that rejects a perfectly
# calibrated interval about a quarter of the time. It now sizes itself to the
# data, at 2 clustered SE.
#
# THE CLUSTER IS THE CYCLE, NOT THE PARTY-CYCLE. Within a cycle the shares sum
# to 100, so a party over-estimated forces another under; the 139 rows are 33
# independent observations. Treating them as 139 understates the SE by enough
# to matter, which is the whole reason the first version of this test was wrong.
#
# Emits FW* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

d <- fread("output/fp-coverage.csv")
d[, err := fitted - actual]
d[, cyc := paste(region, year)]

A_VALUE <- fread("output/projection-mix.csv")[horizon == 30, sd_err_loo][1]
stopifnot("no horizon-30 row in projection-mix.csv, so A has no value" =
          is.finite(A_VALUE))

# B is re-estimated leave-one-cycle-out so its coverage is held out, exactly as
# in estimate_fp_extra_var.R. A needs no such treatment: it is measured on
# two-party projection error, which is not these residuals at all.
nll <- function(tau, dd) { v <- dd$sd^2 + tau^2; 0.5 * sum(log(v) + dd$err^2 / v) }
d[, b_loo := NA_real_]
for (c1 in unique(d$cyc)) {
  d[cyc == c1, b_loo := stats::optimize(function(t) nll(t, d[cyc != c1]),
                                        interval = c(0, 20))$minimum]
}
d[, `:=`(sd_A = sqrt(sd^2 + A_VALUE^2), sd_B = sqrt(sd^2 + b_loo^2))]

cat(sprintf("\nFW1  %d party-cycles; A = %.3f (pre-registered); B = %.3f to %.3f (held out)\n",
            nrow(d), A_VALUE, min(d$b_loo), max(d$b_loo)))

cover <- function(dd, lvl, sdcol) {
  mean(abs(dd$err) <= stats::qnorm(1 - (1 - lvl) / 2) * dd[[sdcol]])
}
LV <- c(0.50, 0.80, 0.95)
lvl_tab <- data.table(
  nominal = LV,
  before = round(vapply(LV, function(l) cover(d, l, "sd"), 1), 3),
  A      = round(vapply(LV, function(l) cover(d, l, "sd_A"), 1), 3),
  B      = round(vapply(LV, function(l) cover(d, l, "sd_B"), 1), 3))
lvl_tab[, `:=`(A_gap = round(abs(A - nominal) * 100, 1),
               B_gap = round(abs(B - nominal) * 100, 1))]
cat("\nFW2  coverage by level (gaps in points)\n"); print(lvl_tab)

# Test 1 (amended): every level within 2 CLUSTERED standard errors of nominal.
#
# `hit_col` is passed as a STRING and the helper's arguments are deliberately
# not named after any column in `d`. A local called `sd` or `party` here would
# bind to the column inside the data.table brackets -- the shadowing trap this
# repo has hit six times.
clustered_se <- function(dd, hit_col) {
  pbar <- mean(dd[[hit_col]])
  per <- dd[, .(m = mean(.SD[[1]]), n = .N), by = cyc, .SDcols = hit_col]
  w <- per$n / sum(per$n)
  # Between-cluster variance of the weighted mean, with the usual (k-1) scaling.
  sqrt(sum(w^2 * (per$m - pbar)^2) * nrow(per) / (nrow(per) - 1))
}

se_rows <- rbindlist(lapply(LV, function(l) {
  zc <- stats::qnorm(1 - (1 - l) / 2)
  d[, `:=`(hit_A = as.integer(abs(err) <= zc * sd_A),
           hit_B = as.integer(abs(err) <= zc * sd_B))]
  seA <- clustered_se(d, "hit_A"); seB <- clustered_se(d, "hit_B")
  data.table(nominal = l,
             se_A_pts = round(seA * 100, 1), se_B_pts = round(seB * 100, 1),
             sig_A = round(abs(mean(d$hit_A) - l) / seA, 2),
             sig_B = round(abs(mean(d$hit_B) - l) / seB, 2))
}))
cat(sprintf("
FW3  test 1 sizes itself: %d party-cycles are %d independent cycles
",
            nrow(d), uniqueN(d$cyc)))
print(se_rows)
t1_A <- all(se_rows$sig_A <= 2); t1_B <- all(se_rows$sig_B <= 2)
cat(sprintf("FW3  test 1 (every level within 2 clustered SE): A %s | B %s
",
            if (t1_A) "PASS" else "FAIL", if (t1_B) "PASS" else "FAIL"))
cat(sprintf("FW3  the ORIGINAL 5-point rule, for the record: A %s | B %s
",
            if (all(lvl_tab$A_gap <= 5)) "PASS" else "FAIL",
            if (all(lvl_tab$B_gap <= 5)) "PASS" else "FAIL"))

# Test 2: R2 restricted to classes with n >= 20, per the addendum -- a class of
# 3 sitting at 100% says nothing, and the original R2 did not exclude it.
cls <- d[, .(n = .N,
             A = round(cover(.SD, 0.95, "sd_A"), 3),
             B = round(cover(.SD, 0.95, "sd_B"), 3)), by = party][order(-n)]
cls[, `:=`(A_over = round((A - 0.95) * 100, 1), B_over = round((B - 0.95) * 100, 1))]
cat("\nFW4  by party class at nominal 95% ('over' = points above nominal)\n")
print(cls)
big <- cls[n >= 20]
# `all()` over an empty set is TRUE, so with no class reaching n = 20 this test
# would report PASS having checked nothing, and feed that straight into an ADOPT
# verdict. Named in CLAUDE.md as a guard that cannot fail; it is not firing on
# the current data (ALP 33, OTH 33, LNP 28, GRN 28) but the script's whole job
# is to gate a decision, so it refuses rather than passes vacuously.
if (!nrow(big)) {
  stop("Test 2 has nothing to check: no party class reaches n = 20 party-cycles. ",
       "Largest is ", cls[which.max(n), party], " at ", max(cls$n),
       ". A PASS here would mean the check did not run, not that it succeeded.")
}
t2_A <- all(big$A_over <= 5); t2_B <- all(big$B_over <= 5)
cat(sprintf("FW5  test 2 (no class with n>=20 over nominal by >5): A %s | B %s\n",
            if (t2_A) "PASS" else "FAIL", if (t2_B) "PASS" else "FAIL"))

# F1: pooled coverage must not be carried by over-covering small classes.
low <- big[pmin(A, B) < 0.90]
cat(sprintf("FW6  F1 check -- classes with n>=20 still under 90%%: %s\n",
            if (nrow(low)) paste(low$party, collapse = ", ") else "none"))

# F2: a constant in points must not favour one end of the scale.
d[, band := cut(fitted, c(0, 10, 20, 30, 100))]
bnd <- d[, .(n = .N, mean_level = round(mean(fitted), 1),
             A = round(cover(.SD, 0.95, "sd_A"), 3),
             B = round(cover(.SD, 0.95, "sd_B"), 3)), by = band][order(band)]
cat("\nFW7  F2 check -- coverage at 95% by level band\n"); print(bnd)
ends <- bnd[band %in% c("(0,10]", "(30,100]")]
skew_A <- abs(diff(ends$A)) * 100; skew_B <- abs(diff(ends$B)) * 100
cat(sprintf("FW8  F2 end-to-end skew (>10 pts disqualifies a constant): A %.1f | B %.1f\n",
            skew_A, skew_B))

pass_A <- t1_A && t2_A && skew_A <= 10
pass_B <- t1_B && t2_B && skew_B <= 10
verdict <- if (pass_A) {
  sprintf("ADOPT A = %.3f (pre-registered; wins ties). F4 STILL OWED.", A_VALUE)
} else if (pass_B) {
  "ADOPT B -- a DEVIATION from R3; record why A failed, in numbers"
} else {
  "ADOPT NEITHER -- the missing variance is not a constant in points"
}
cat(sprintf("\nFW9  verdict: %s\n", verdict))
fwrite(d[, .(region, year, party, fitted, actual, sd, b_loo, sd_A, sd_B)],
       file.path("output", "fp-widening-compare.csv"))
cat("Wrote output/fp-widening-compare.csv\n")
