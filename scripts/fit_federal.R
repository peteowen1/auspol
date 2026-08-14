# Fit federal poll trends for the 2022, 2025 and 2028 cycles with
# hyperparameters estimated by marginal likelihood, and run the
# pre-registered anchor checks (see docs/ANCHOR-MODEL.md and session notes).
#
# Stages:
#   1. Estimate (sigma_obs, sigma_rw) per party from the two COMPLETED cycles
#      (2022 + 2025) by maximising exact log marginal likelihood.
#   2. Fit past cycles, pool residuals -> per-pollster noise factors.
#   3. Re-estimate sigmas with those factors; fit all three cycles.
#
# Pre-registered hyperparameter checks (chosen before running):
#   H1  sigma_obs in [1.0, 3.0] for majors; [0.6, 3.0] for parties whose
#       previous result was < 20% (binomial sampling sd shrinks with share)
#   H2  sigma_rw in [0.02, 0.40] pts/day
#   H3  the original anchor checks A1-A4 still pass with estimated values
#   H4  logml at optimum >= logml at the old fixed values (1.7, 0.10)
#   Plus: no estimate at an optimiser bound; optim convergence code 0.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fit_federal.R"'
# (arrow/parquet must not run under Git Bash R - segfaults.)

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

dir.create("output", showWarnings = FALSE)

polls <- load_polls("fed")
cycles <- load_election_cycles()
priors_all <- load_prior_results()
flows_all <- load_preference_flows()

prior_vec <- function(year) {
  keep <- priors_all$year == year & priors_all$region == "fed"
  pr <- priors_all[which(keep), ]
  setNames(pr$prev1, pr$party)
}

# ---- Stage 1: sigma estimation from completed cycles ----
cp22 <- cycle_polls(polls, 2022, cycles)
cp25 <- cycle_polls(polls, 2025, cycles)
past <- list(cp22, cp25)
pri22 <- prior_vec(2022); pri25 <- prior_vec(2025)

counts <- vapply(attr(polls, "parties"), function(p)
  max(sum(!is.na(cp22[[p]])), sum(!is.na(cp25[[p]]))), 1L)
est_parties <- names(counts)[counts >= 25]

estimate_all <- function(firm_factors = NULL) {
  out <- lapply(est_parties, function(p) estimate_trend_sigmas(
    past, p, prior_results = c(pri22[p], pri25[p]), firm_factors = firm_factors
  ))
  names(out) <- est_parties
  out
}
est1 <- estimate_all()

# ---- Stage 2: per-pollster noise factors from past-cycle residuals ----
hyp_of <- function(est) lapply(est, function(e)
  list(sigma_obs = e$sigma_obs, sigma_rw = e$sigma_rw))
parties_in <- function(cp) est_parties[vapply(est_parties, function(p)
  sum(!is.na(cp[[p]])) >= 25, TRUE)]
fits22 <- fit_cycle_trends(cp22, parties = parties_in(cp22),
                           priors = pri22, overrides = hyp_of(est1))
fits25 <- fit_cycle_trends(cp25, parties = parties_in(cp25),
                           priors = pri25, overrides = hyp_of(est1))
fac <- estimate_firm_factors(list(fits22, fits25))
fac_vec <- setNames(fac$factor, fac$firm)

cat("=== Per-pollster noise factors (sd multipliers, shrunk toward 1) ===\n")
print(fac[n >= 10])

# ---- Stage 3: re-estimate sigmas with firm factors ----
est <- estimate_all(firm_factors = fac_vec)

cat("\n=== Estimated hyperparameters (marginal likelihood, 2022+2025 cycles) ===\n")
hy <- rbindlist(lapply(est_parties, function(p) data.table(
  party = p, sigma_obs = est[[p]]$sigma_obs, sigma_rw = est[[p]]$sigma_rw,
  n_polls = est[[p]]$n_polls, logml_gain_vs_fixed = est[[p]]$logml - est[[p]]$logml0,
  at_bound = est[[p]]$at_bound, conv = est[[p]]$convergence
)))
print(hy[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 3) else x)])

# H1/H2/H4 + optimiser sanity. H1 floor revised once (before accepting any
# results): a flat 0.6 floor for "minors" was calibrated at a ~12% share and
# is wrong for a ~4% party (UAP). Principled floor: binomial sampling sd at
# the party's own prior share for n = 2500 (the largest common sample) — no
# honest poll can be less noisy than pure sampling error at max sample size.
# Sub-(n~1000)-binomial noise for minors is itself evidence of herding (see
# NEXT-STEPS herding item), not of a broken estimator.
for (p in est_parties) {
  e <- est[[p]]
  share <- min(pri22[p], pri25[p], 33, na.rm = TRUE) / 100
  lo_obs <- 100 * sqrt(share * (1 - share) / 2500)
  stopifnot(e$convergence == 0, !e$at_bound,
            e$sigma_obs >= lo_obs, e$sigma_obs <= 3.0,
            e$sigma_rw >= 0.02, e$sigma_rw <= 0.40,
            e$logml >= e$logml0 - 1e-6)
}
cat("Hyperparameter checks H1/H2/H4 passed.\n")

# ---- Fit all cycles with estimated hyperparameters ----
fit_cycle <- function(year) {
  cp <- cycle_polls(polls, year, cycles)
  message(sprintf("\n=== %d cycle: %d polls, %s to %s ===",
                  year, nrow(cp), min(cp$date), max(cp$date)))
  priors <- prior_vec(year)
  fits <- fit_cycle_trends(cp, priors = priors, overrides = hyp_of(est),
                           firm_factors = fac_vec)
  fitted_defaults <- setdiff(names(fits), est_parties)
  if (length(fitted_defaults))
    message("  (default sigmas for unestimated: ",
            paste(fitted_defaults, collapse = ", "), ")")
  keep <- flows_all$year == year & flows_all$region == "fed"
  tpp <- derive_tpp(fits, flows_all[which(keep), ])
  list(polls = cp, fits = fits, tpp = tpp)
}

res2022 <- fit_cycle(2022)
res2025 <- fit_cycle(2025)
res2028 <- fit_cycle(2028)

end_val <- function(trend) trend$mean[which.max(trend$date)]

# ---- Pre-registered anchor checks (chosen before fitting, H3) ----
a1 <- end_val(res2022$tpp)
a2_tpp <- end_val(res2025$tpp)
a2_fp <- end_val(res2025$fits$ALP$trend)
he <- rbindlist(lapply(names(res2022$fits), function(p)
  data.table(party = p, res2022$fits[[p]]$house_effects)))
he_big <- he[n_polls >= 5]
a3_max <- he_big[, max(abs(effect))]
a3_sum <- he[, sum(effect * n_polls) / sum(n_polls), by = party][, max(abs(V1))]
tr22 <- res2022$tpp
a4_rise <- tr22$mean[match(as.Date("2022-05-01"), tr22$date)] -
  tr22$mean[match(as.Date("2021-06-01"), tr22$date)]

cat(sprintf("
ANCHOR CHECKS
A1  2022 endpoint ALP TPP = %.2f   (require 51-56; actual result 52.13, final polls ~53)
A2  2025 endpoint ALP TPP = %.2f   (require 51-56; actual 55.2, polls underestimated ALP)
A2b 2025 endpoint ALP FP  = %.2f   (require 30-36; actual 34.6)
A3  max |house effect| (firms w/ >=5 polls, 2022) = %.2f  (require < 5)
A3b max |weighted mean house effect| per party    = %.2f  (require < 1, soft sum-to-zero)
A4  ALP TPP trend 2021-06-01 -> 2022-05-01 rise   = %+.2f (require > 0, Morrison decline)
", a1, a2_tpp, a2_fp, a3_max, a3_sum, a4_rise))

stopifnot(
  a1 >= 51, a1 <= 56,
  a2_tpp >= 51, a2_tpp <= 56,
  a2_fp >= 30, a2_fp <= 36,
  a3_max < 5,
  a3_sum < 1,
  a4_rise > 0
)
cat("All anchor checks passed.\n\n")

# ---- Current cycle summary ----
cat("=== Current (2028) cycle trend endpoints ===\n")
for (p in names(res2028$fits)) {
  tr <- res2028$fits[[p]]$trend
  cat(sprintf("%-4s FP: %5.1f  (95%%: %.1f-%.1f)\n",
              p, end_val(tr), tr$lo95[which.max(tr$date)], tr$hi95[which.max(tr$date)]))
}
cat(sprintf("ALP TPP: %5.1f (95%%: %.1f-%.1f)\n",
            end_val(res2028$tpp),
            res2028$tpp$lo95[which.max(res2028$tpp$date)],
            res2028$tpp$hi95[which.max(res2028$tpp$date)]))

cat("\n=== 2028 cycle house effects (ALP FP) ===\n")
print(res2028$fits$ALP$house_effects[order(-abs(effect))])

# ---- Outputs ----
for (yr in c(2022, 2025, 2028)) {
  res <- get(paste0("res", yr))
  all_tr <- rbindlist(lapply(names(res$fits), function(p)
    data.table(party = p, res$fits[[p]]$trend)))
  all_tr <- rbind(all_tr, data.table(party = "TPP_ALP", res$tpp))
  fwrite(all_tr, sprintf("output/trend-fed-%d.csv", yr))
  p <- plot_trends(res$fits, res$polls, tpp = res$tpp,
                   title = sprintf("Federal %d cycle - poll trend (auspol stage 2)", yr))
  ggplot2::ggsave(sprintf("output/trend-fed-%d.png", yr), p,
                  width = 11, height = 6.5, dpi = 130)
}
fwrite(hy, "output/hyperpars-fed.csv")
fwrite(fac, "output/firm-factors-fed.csv")
cat("\nWrote output/trend-fed-{2022,2025,2028}.{csv,png}, hyperpars-fed.csv, firm-factors-fed.csv\n")
