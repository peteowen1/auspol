# The extra first-preference variance the trend posterior does not contain.
#
# Coverage of our published first-preference intervals is 69.8% at a nominal
# 95% (scripts/test_fp_coverage.R). The missing variance is poll-to-result
# error: the trend already runs to election day, so walk propagation is inside
# the posterior; what is absent is the systematic gap between what polls say and
# what happens.
#
# The STRUCTURE is chosen by testing alternatives against the residuals rather
# than assumed:
#
#   multiplicative (inflate the posterior sd)  REFUTED
#     cor(|error|, posterior sd) = -0.036, p = 0.68. A well-determined trend is
#     no more accurate in absolute terms than a poorly-determined one, so there
#     is nothing for a multiplier to scale.
#
#   proportional to the party's level (i.e. a link-scale term)  REFUTED
#     error sd is 2.37 at a mean level of 6%, 2.18 at 12%, 2.35 at 40%;
#     cor(|error|, level) = -0.002. Flat in points, not in ratio.
#
#   additive in quadrature, constant in points  SUPPORTED, and estimated here.
#
# So: err_i ~ N(0, sd_post_i^2 + tau^2), with tau by maximum likelihood over the
# per-observation posterior sds -- not a single borrowed number, and not a
# factor chosen to make coverage land on target.
#
# Emits EV* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

d <- fread("output/fp-coverage.csv")
d[, err := fitted - actual]
d[, cyc := paste(region, year)]
cat(sprintf("\nEV1  %d party-cycles over %d cycles\n", nrow(d), uniqueN(d$cyc)))

# Negative log-likelihood of tau given the per-observation posterior sds.
nll <- function(tau, dd) {
  v <- dd$sd^2 + tau^2
  0.5 * sum(log(v) + dd$err^2 / v)
}
fit_tau <- function(dd) {
  stats::optimize(function(t) nll(t, dd), interval = c(0, 20))$minimum
}

tau_all <- fit_tau(d)
mom <- sqrt(max(0, mean(d$err^2) - mean(d$sd^2)))
cat(sprintf("EV2  tau (maximum likelihood)   = %.3f points\n", tau_all))
cat(sprintf("EV2  tau (method of moments)    = %.3f points  [agreement check]\n", mom))
cat(sprintf("EV2  for comparison, the TPP projection error borrowed earlier = %.3f\n",
            fread("output/projection-mix.csv")[horizon == 30, sd_err_loo][1]))

# Leave-one-cycle-out: tau estimated without the cycle it is scored on, so the
# coverage below is not fitted to the rows it is measured on.
d[, tau_loo := NA_real_]
for (c1 in unique(d$cyc)) {
  d[cyc == c1, tau_loo := fit_tau(d[cyc != c1])]
}
cat(sprintf("EV3  leave-one-cycle-out tau: %.3f to %.3f (spread %.3f)\n",
            min(d$tau_loo), max(d$tau_loo), max(d$tau_loo) - min(d$tau_loo)))

cover <- function(dd, lvl, sdcol) {
  z <- stats::qnorm(1 - (1 - lvl) / 2)
  mean(abs(dd$err) <= z * dd[[sdcol]])
}
d[, sd_new := sqrt(sd^2 + tau_loo^2)]
LV <- c(0.50, 0.80, 0.95)
out <- data.table(nominal = LV,
                  before = vapply(LV, function(l) cover(d, l, "sd"), 1),
                  after  = vapply(LV, function(l) cover(d, l, "sd_new"), 1))
out[, `:=`(before = round(before, 3), after = round(after, 3))]
cat("\nEV4  coverage, held-out tau\n"); print(out)

cat("\nEV5  by party class at nominal 95%\n")
print(d[, .(n = .N, before = round(cover(.SD, 0.95, "sd"), 3),
            after = round(cover(.SD, 0.95, "sd_new"), 3)), by = party][order(-n)])

cat("\nEV6  by level band at nominal 95% (a constant tau must not favour one end)\n")
d[, band := cut(fitted, c(0, 10, 20, 30, 100))]
print(d[, .(n = .N, mean_level = round(mean(fitted), 1),
            after = round(cover(.SD, 0.95, "sd_new"), 3)), by = band][order(band)])

fwrite(d[, .(region, year, party, fitted, actual, sd, tau_loo, sd_new)],
       file.path("output", "fp-extra-var.csv"))
cat(sprintf("\nEV7  FP_EXTRA_SD = %.2f points\n", round(tau_all, 2)))
cat("Wrote output/fp-extra-var.csv\n")
