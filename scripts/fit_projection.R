# Fundamentals + projection: turn a poll trend into a statement about
# election day.
#
# Two stages, following the anchor:
#   1. Fundamentals — the expected result knowing no current polling: the
#      party's own history, incumbency and years in office, and for state
#      elections whether its federal counterpart governs.
#   2. Projection — mix trend and fundamentals by horizon, since polls carry
#      little information about a result two years out and most of it two
#      months out.
#
# Pre-registered checks, chosen before running:
#   P1  the optimal trend weight w must RISE as the election approaches:
#       w(30 days) > w(730 days). Falsifiable, and the whole premise.
#   P2  the error spread must FALL as the election approaches:
#       sd_err(30) < sd_err(730).
#   P3  the mix, scored leave-one-election-out so the weight has not seen the
#       election it is graded on, must beat BOTH trend-only and
#       fundamentals-only at a majority of horizons.
#   P4  fundamentals must beat two naive baselines out of sample: predicting
#       the previous result, and predicting the party's long-run average.
#   Note: in-sample `mae_mix` can never lose to either component, because the
#   weight grid spans 0 to 1. It is reported but proves nothing; P3 uses the
#   held-out number.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fit_projection.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

dir.create("output", showWarnings = FALSE)
HORIZONS <- c(30, 90, 180, 365, 730)

# ---- Stage 1: fundamentals ----
fdat <- build_fundamentals_data()
cat(sprintf("=== Fundamentals training data: %d rows ===\n", nrow(fdat)))
print(fdat[, .(n = .N, first = min(year), last = max(year)), by = party][order(-n)])

fund_models <- list()
fund_tab <- rbindlist(lapply(c("@TPP", "ALP", "LNP", "GRN", "OTH"), function(p) {
  m <- tryCatch(fit_fundamentals(fdat, p), error = function(e) NULL)
  if (is.null(m)) return(NULL)
  fund_models[[p]] <<- m
  # Paired sign test against the better of the two naive baselines: a mean
  # difference alone does not say whether the gain is real on 52-62 elections.
  base_err <- m$data$actual - m$data$prev_avg
  wins <- sum(abs(m$loo_errors) < abs(base_err))
  data.table(party = p, n = m$n, lambda = signif(m$lambda, 3),
             loo_mae = round(m$loo_mae, 3),
             mae_prev1 = round(m$baseline_prev1_mae, 3),
             mae_longrun = round(m$baseline_avg_mae, 3),
             beats_longrun_on = sprintf("%d/%d", wins, m$n),
             p_sign = signif(stats::binom.test(wins, m$n)$p.value, 3))
}))
cat("\n=== Fundamentals: leave-one-election-out vs naive baselines ===\n")
print(fund_tab)
cat("\ncoefficients (standardised) for @TPP:\n")
print(round(setNames(fund_models[["@TPP"]]$beta, fund_models[["@TPP"]]$features), 3))

# P4
p4 <- fund_tab[party == "@TPP"]
stopifnot(nrow(p4) == 1, p4$loo_mae < p4$mae_prev1, p4$loo_mae < p4$mae_longrun)
cat(sprintf("\nP4  @TPP fundamentals MAE %.2f beats prev-result %.2f and long-run %.2f  PASS\n",
            p4$loo_mae, p4$mae_prev1, p4$mae_longrun))

# Leave-one-out fundamentals predictions, keyed by election
m_tpp <- fund_models[["@TPP"]]
fund_loo <- data.table(year = m_tpp$data$year, region = m_tpp$data$region,
                       fund_tpp = m_tpp$data$actual - m_tpp$loo_errors)

# ---- Stage 2: trend at each horizon, refitted on polls available then ----
cat("\n=== Building projection data (refits the trend at each horizon) ===\n")
t0 <- Sys.time()
pdat <- build_projection_data(horizons = HORIZONS, verbose = FALSE)
cat(sprintf("built %d (election, horizon) rows in %.0f s\n", nrow(pdat),
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

pdat <- merge(pdat, fund_loo, by = c("year", "region"), all.x = TRUE)
cat(sprintf("of which %d have a fundamentals prediction\n", sum(!is.na(pdat$fund_tpp))))
print(pdat[!is.na(fund_tpp), .(n = .N, elections = uniqueN(paste(year, region))),
           by = horizon][order(horizon)])

mix <- fit_projection_mix(pdat)
cat("\n=== Projection mix by horizon (ALP two-party) ===\n")
print(mix[, .(horizon, n, w, mae_mix, mae_mix_loo, mae_trend, mae_fund,
              bias = round(bias, 3), sd_err = round(sd_err, 3))])

# ---- Pre-registered checks ----
w30 <- mix[horizon == min(horizon), w]
w730 <- mix[horizon == max(horizon), w]
sd30 <- mix[horizon == min(horizon), sd_err]
sd730 <- mix[horizon == max(horizon), sd_err]
beats <- mix[mae_mix_loo < mae_trend & mae_mix_loo < mae_fund, .N]

cat(sprintf("
P1  trend weight rises toward the election: w(%d)=%.2f > w(%d)=%.2f  %s
P2  error spread falls toward the election: sd(%d)=%.2f < sd(%d)=%.2f  %s
P3  held-out mix beats both components at %d of %d horizons  %s
",
  min(mix$horizon), w30, max(mix$horizon), w730,
  if (w30 > w730) "PASS" else "FAIL",
  min(mix$horizon), sd30, max(mix$horizon), sd730,
  if (sd30 < sd730) "PASS" else "FAIL",
  beats, nrow(mix), if (beats > nrow(mix) / 2) "PASS" else "FAIL"))
stopifnot(w30 > w730, sd30 < sd730, beats > nrow(mix) / 2)
cat("All projection checks passed.\n")

# ---- Apply to Victoria 2026 ----
cycles <- load_election_cycles()
vic_end <- cycles[region == "vic" & year == 2026, end]
days_out <- as.integer(vic_end - Sys.Date())
polls <- load_polls("vic")
priors_all <- load_prior_results()
kp <- priors_all$region == "vic" & priors_all$year == 2026
pr <- priors_all[which(kp), ]
priors <- setNames(pr$prev1, pr$party)
fl <- flows_for(load_preference_flows(), 2026, "vic", quiet = TRUE)

now <- trend_as_at(polls, 2026, cycles, Sys.Date(), priors, fl)
# The live election has no result, so it is absent from the training table by
# construction; its feature row is built with require_actual = FALSE.
live <- build_fundamentals_data(polled_only = FALSE, require_actual = FALSE)
kf <- live$region == "vic" & live$year == 2026 & live$party == "@TPP"
vic_row <- live[which(kf), ]
cat("\nVictoria 2026 fundamentals inputs:\n"); print(vic_row)
stopifnot(nrow(vic_row) == 1)
fund_vic <- predict_fundamentals(m_tpp, vic_row)

cat(sprintf("\n=== VICTORIA 2026 PROJECTION — %d days out ===\n", days_out))
cat(sprintf("trend now (ALP TPP)      : %.2f\n", now$tpp))
cat(sprintf("fundamentals (ALP TPP)   : %.2f\n", fund_vic))
if (is.finite(fund_vic)) {
  pj <- project_result(now$tpp, fund_vic, mix, days_out)
  cat(sprintf("PROJECTION               : %.2f  (95%%: %.2f - %.2f), trend weight %.2f\n",
              pj$mean, pj$lo95, pj$hi95, pj$w))
  cat(sprintf("2022 result was 55.00, so this is a swing of %+.2f\n", pj$mean - 55))
}

fwrite(mix, "output/projection-mix.csv")
fwrite(fund_tab, "output/fundamentals-validation.csv")
fwrite(pdat, "output/projection-data.csv")
cat("\nWrote output/projection-{mix,data}.csv and fundamentals-validation.csv\n")
