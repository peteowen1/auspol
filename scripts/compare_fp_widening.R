# Which widening factor for first-preference bands: the pre-registered two-party
# projection error, or the ML estimate on the FP residuals?
#
# Against docs/plans/prereg-fp-widening-choice.md, committed BEFORE this ran.
# The rule and its four refusals are there and are NOT restated here. In short:
# candidate A (2.419, pre-registered) is the default and wins ties; B (2.127)
# only gets considered if A fails, and adopting B is a recorded deviation.
#
# Emits FW* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

d <- fread("output/fp-coverage.csv")
d[, err := fitted - actual]
d[, cyc := paste(region, year)]

A_VALUE <- fread("output/projection-mix.csv")[horizon == 30, sd_err_loo][1]

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

# Test 1: every level within 5 points of nominal.
t1_A <- all(lvl_tab$A_gap <= 5); t1_B <- all(lvl_tab$B_gap <= 5)
cat(sprintf("FW3  test 1 (all levels within 5 pts): A %s | B %s\n",
            if (t1_A) "PASS" else "FAIL", if (t1_B) "PASS" else "FAIL"))

# Test 2: R2 restricted to classes with n >= 20, per the addendum -- a class of
# 3 sitting at 100% says nothing, and the original R2 did not exclude it.
cls <- d[, .(n = .N,
             A = round(cover(.SD, 0.95, "sd_A"), 3),
             B = round(cover(.SD, 0.95, "sd_B"), 3)), by = party][order(-n)]
cls[, `:=`(A_over = round((A - 0.95) * 100, 1), B_over = round((B - 0.95) * 100, 1))]
cat("\nFW4  by party class at nominal 95% ('over' = points above nominal)\n")
print(cls)
big <- cls[n >= 20]
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
  sprintf("ADOPT A = %.3f (pre-registered; wins ties)", A_VALUE)
} else if (pass_B) {
  "ADOPT B -- a DEVIATION from R3; record why A failed, in numbers"
} else {
  "ADOPT NEITHER -- the missing variance is not a constant in points"
}
cat(sprintf("\nFW9  verdict: %s\n", verdict))
fwrite(d[, .(region, year, party, fitted, actual, sd, b_loo, sd_A, sd_B)],
       file.path("output", "fp-widening-compare.csv"))
cat("Wrote output/fp-widening-compare.csv\n")
