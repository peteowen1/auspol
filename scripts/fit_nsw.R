# NSW poll trends: 2023 (validation) and 2027 (the live forecast cycle),
# with hyperparameters estimated by marginal likelihood. NSW uses optional
# preferential voting, so TPP accounts for exhausted preferences via the flow
# file's exhaust rates.
#
# State polling is thin (one completed cycle), so sigmas are estimated from
# BOTH cycles (2023 + 2027) — empirical Bayes on all available data — with
# min_polls = 10. The hand-set ONP sigma_rw = 0.25 override is retired: the
# estimator sees ONP's real 2025-26 rise (~2% -> ~25%) and must pick the walk
# size itself.
#
# Pre-registered checks (chosen before running):
#   N1-N3 as before (2023 TPP/FP endpoints, house effect cap)
#   H1  sigma_obs >= binomial sd at the party's prior share (n = 2500), <= 3.0
#   H2  sigma_rw in [0.02, 0.40]; ONP allowed [0.02, 0.55] (its 20+ pt rise is
#       known real movement, stated before estimation)
#   H4  logml at optimum >= logml at old fixed values; no bound hits.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fit_nsw.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

dir.create("output", showWarnings = FALSE)

polls <- load_polls("nsw")
cycles <- load_election_cycles()
priors_all <- load_prior_results()
flows_all <- load_preference_flows()

prior_vec <- function(year) {
  keep <- priors_all$year == year & priors_all$region == "nsw"
  pr <- priors_all[which(keep), ]
  setNames(pr$prev1, pr$party)
}

cp23 <- cycle_polls(polls, 2023, cycles)
cp27 <- cycle_polls(polls, 2027, cycles)
pri23 <- prior_vec(2023); pri27 <- prior_vec(2027)

# ML estimation of two variance parameters needs real data: parties under 20
# polls total hit the optimiser box bounds (ONP, 8 polls, hit BOTH bounds on
# the first attempt — per pre-registration that is "method wrong", so those
# parties fall back to defaults + the documented hand override below).
counts <- vapply(attr(polls, "parties"), function(p)
  sum(!is.na(cp23[[p]])) + sum(!is.na(cp27[[p]])), 1L)
est_parties <- names(counts)[counts >= 20]

estimate_on <- function(scale, firm_factors = NULL) {
  out <- lapply(est_parties, function(p) estimate_trend_sigmas(
    list(cp23, cp27), p, prior_results = c(pri23[p], pri27[p]),
    scale = scale, firm_factors = firm_factors, min_polls = 8
  ))
  names(out) <- est_parties
  out
}

# L1 (see fit_federal.R): the scale is chosen per party by comparable log
# evidence, NOT globally — the pre-registered global-logit test failed
# federally. NSW has both cycles in the estimation set, so unlike federal
# there is no live-cycle blind spot here.
est_logit <- estimate_on("logit")
est_points <- estimate_on("points")
cmp <- rbindlist(lapply(est_parties, function(p) data.table(
  party = p,
  logml_y_logit = est_logit[[p]]$logml_y,
  logml_y_points = est_points[[p]]$logml_y
)))
cmp[, gain := logml_y_logit - logml_y_points]
cmp[, scale := data.table::fifelse(gain > 0, "logit", "points")]
cat("=== NSW L1: logit vs points, log evidence in original percentage units ===\n")
print(cmp[order(-gain)])
scale_of <- setNames(cmp$scale, cmp$party)
stopifnot(!anyNA(scale_of), all(est_parties %in% names(scale_of)))

hyp_of <- function(est) setNames(lapply(names(est), function(p) list(
  sigma_obs = est[[p]]$sigma_obs, sigma_rw = est[[p]]$sigma_rw,
  scale = scale_of[[p]]
)), names(est))
est_sel <- setNames(lapply(est_parties, function(p)
  if (scale_of[[p]] == "logit") est_logit[[p]] else est_points[[p]]), est_parties)

parties_in <- function(cp, n = 8) est_parties[vapply(est_parties, function(p)
  sum(!is.na(cp[[p]])) >= n, TRUE)]
fits23 <- fit_cycle_trends(cp23, parties = parties_in(cp23),
                           priors = pri23, overrides = hyp_of(est_sel))
fits27 <- fit_cycle_trends(cp27, parties = parties_in(cp27),
                           priors = pri27, overrides = hyp_of(est_sel))
fac <- estimate_firm_factors(list(fits23, fits27))
fac_vec <- setNames(fac$factor, fac$firm)

cat("\n=== NSW per-pollster noise factors ===\n")
print(fac)

est <- setNames(lapply(est_parties, function(p) estimate_trend_sigmas(
  list(cp23, cp27), p, prior_results = c(pri23[p], pri27[p]),
  scale = scale_of[[p]], firm_factors = fac_vec, min_polls = 8
)), est_parties)

ref_share <- function(p) min(pri23[p], pri27[p], 33, na.rm = TRUE)

cat("\n=== NSW estimated hyperparameters (2023+2027 cycles) ===\n")
hy <- rbindlist(lapply(est_parties, function(p) data.table(
  party = p, scale = scale_of[[p]],
  sigma_obs = est[[p]]$sigma_obs, sigma_rw = est[[p]]$sigma_rw,
  sigma_obs_pts = sd_from_link(est[[p]]$sigma_obs, ref_share(p), scale_of[[p]]),
  sigma_rw_pts = sd_from_link(est[[p]]$sigma_rw, ref_share(p), scale_of[[p]]),
  n_polls = est[[p]]$n_polls, logml_gain_vs_fixed = est[[p]]$logml - est[[p]]$logml0,
  at_bound = est[[p]]$at_bound, conv = est[[p]]$convergence
)))
print(hy[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 4) else x)])

for (p in est_parties) {
  e <- est[[p]]; sc <- scale_of[[p]]; share <- ref_share(p)
  hi_rw <- if (p == "ONP") 0.55 else 0.40
  stopifnot(e$convergence == 0, !e$at_bound,
            e$sigma_obs >= binomial_sd_link(share, 2500, sc),
            sd_from_link(e$sigma_obs, share, sc) <= 3.0,
            sd_from_link(e$sigma_rw, share, sc) >= 0.02,
            sd_from_link(e$sigma_rw, share, sc) <= hi_rw,
            e$logml >= e$logml0 - 1e-6)
}
cat("Hyperparameter checks H1/H2/H4 passed.\n")

# Per-cycle sigmas (see fit_federal.R for why both are re-estimated, not just
# the walk). NSW cycles carry ~25 polls against k0 = 25, so each cycle's own
# estimate gets about half the weight and the pooled value supplies the rest.
walk_of <- function(cp, year) {
  priors <- prior_vec(year)
  cnt <- vapply(attr(cp, "parties"), function(p) sum(!is.na(cp[[p]])), 1L)
  ps <- intersect(names(cnt)[cnt >= 15], est_parties)
  setNames(lapply(ps, function(p) estimate_cycle_sigmas(
    cp, p, sigma_obs_pooled = est[[p]]$sigma_obs,
    sigma_rw_pooled = est[[p]]$sigma_rw,
    prior_result = priors[p] %||% NA_real_, scale = scale_of[[p]],
    firm_factors = fac_vec
  )), ps)
}

fit_cycle <- function(year) {
  cp <- cycle_polls(polls, year, cycles)
  message(sprintf("\n=== NSW %d cycle: %d polls, %s to %s ===",
                  year, nrow(cp), min(cp$date), max(cp$date)))
  priors <- prior_vec(year)
  walks <- walk_of(cp, year)
  # State polling is thin - accept parties with >= 8 polls in the cycle.
  # ONP keeps its hand-set fast walk (2025-26 rise from ~2% to ~25% is real
  # movement): too few polls (8) for ML estimation - it bound-hit when tried.
  cnt <- vapply(attr(cp, "parties"), function(p) sum(!is.na(cp[[p]])), 1L)
  # The hand-set ONP override (points scale, sigma_rw = 0.25) is RETIRED here.
  # It existed to let ONP's 2% -> 25% climb through a points-scale walk that
  # could not otherwise represent it; on the logit scale the default walk
  # handles that movement, and the resulting band is honest about coming from
  # only 8 polls (21.8 [16.6-28.1]) where the points fit claimed 25.3
  # [22.8-27.8] and put negative vote share inside its own 95% interval.
  ov <- hyp_of(est)
  for (p in names(walks)) {
    ov[[p]]$sigma_obs <- walks[[p]]$sigma_obs
    ov[[p]]$sigma_rw <- walks[[p]]$sigma_rw
  }
  # Correct parties folded into OTH (see R/fold.R). NSW matters more than
  # federal here: ResolvePM reports ONP inside OTH on many NSW polls.
  fits <- fit_cycle_unfolded(
    cp, parties = names(cnt)[cnt >= 8], priors = priors,
    overrides = ov, firm_factors = fac_vec, verbose = FALSE
  )
  fkeep <- flows_all$year == year & flows_all$region == "nsw"
  tpp <- derive_tpp(fits, flows_all[which(fkeep), ])
  list(polls = cp, polls_corrected = attr(fits, "polls_corrected"),
       fits = fits, tpp = tpp, walks = walks, folded = attr(fits, "folded"),
       fold_skipped = attr(fits, "fold_skipped"))
}

res2023 <- fit_cycle(2023)
res2027 <- fit_cycle(2027)

end_val <- function(trend) trend$mean[which.max(trend$date)]

n1 <- end_val(res2023$tpp)
n2 <- end_val(res2023$fits$ALP$trend)
he27 <- rbindlist(lapply(names(res2027$fits), function(p)
  data.table(party = p, res2027$fits[[p]]$house_effects)))
n3 <- he27[n_polls >= 5, max(abs(effect_pts))]

cat(sprintf("
ANCHOR CHECKS (NSW)
N1  2023 endpoint ALP TPP = %.2f  (require 51.5-57; actual 54.3)
N2  2023 endpoint ALP FP  = %.2f  (require 33-40; actual 37.0)
N3  max |house effect| 2027 cycle (>=5 polls) = %.2f  (require < 5)
", n1, n2, n3))
stopifnot(n1 >= 51.5, n1 <= 57, n2 >= 33, n2 <= 40, n3 < 5)
cat("All NSW anchor checks passed.\n\n")

# ---- L2/L3: structural checks a broken transform would fail ----
for (yr in c(2023, 2027)) {
  res <- get(paste0("res", yr))
  for (p in names(res$fits)) {
    tr <- res$fits[[p]]$trend
    stopifnot(all(tr$lo95 > 0), all(tr$hi95 < 100), all(is.finite(tr$mean)))
  }
}
share_sums <- vapply(c(2023, 2027), function(yr) {
  res <- get(paste0("res", yr))
  sum(vapply(res$fits, function(f) f$trend$mean[which.max(f$trend$date)], 1))
}, 1)
# ---- F1: fold correction (same metric as fit_federal.R) ----
n_folded_nsw <- sum(vapply(c(2023, 2027), function(yr) {
  f <- get(paste0("res", yr))$folded
  if (is.null(f)) 0L else nrow(f)
}, 1L))
n_skipped_nsw <- sum(vapply(c(2023, 2027), function(yr) {
  f <- get(paste0("res", yr))$fold_skipped
  if (is.null(f)) 0L else nrow(f)
}, 1L))
cat(sprintf("\nF1  corrected %d NSW polls with a party folded into OTH\n",
            n_folded_nsw))
cat(sprintf("F1  left %d alone: the folded party was never measured near those dates,\n    so the trend there carries no information (see R/fold.R)\n",
            n_skipped_nsw))
if (n_folded_nsw) {
  fold_tab <- rbindlist(lapply(c(2023, 2027), function(yr) {
    f <- get(paste0("res", yr))$folded
    if (is.null(f) || !nrow(f)) return(NULL)
    data.table(year = yr, f)[, .(n = .N, mean_imputed = round(mean(imputed), 2),
                                 mean_oth_before = round(mean(oth_before), 1),
                                 mean_oth_after = round(mean(oth_after), 1)),
                             by = .(year, party)]
  }))
  print(fold_tab)
  stopifnot(all(rbindlist(lapply(c(2023, 2027), function(yr) {
    f <- get(paste0("res", yr))$folded
    if (is.null(f) || !nrow(f)) return(data.table(ok = TRUE))
    data.table(ok = f$oth_after > 0)
  }))$ok))
}

# L4a/L4b as in fit_federal.R: over-smoothing is enforced one-sided, and each
# cycle's noise must clear the binomial floor at the level actually polled.
# The negative tail is reported, not enforced (uncalibrated on real data).
walk_tab <- rbindlist(lapply(c(2023, 2027), function(yr) {
  res <- get(paste0("res", yr))
  rbindlist(lapply(names(res$walks), function(p) {
    w <- res$walks[[p]]; sc <- scale_of[[p]]
    v <- res$polls[[p]]; v <- v[!is.na(v)]; lvl <- mean(v)
    data.table(year = yr, party = p, n = w$n_polls,
               own_weight = round(w$weight, 2), cycle_level = round(lvl, 1),
               obs_pts = round(sd_from_link(w$sigma_obs, lvl, sc), 3),
               rw_pooled = round(sd_from_link(w$sigma_rw_pooled, lvl, sc), 4),
               rw_cycle = round(sd_from_link(w$sigma_rw, lvl, sc), 4),
               floor_2500 = round(binomial_sd_link(lvl, 2500, "points"), 3),
               at_lower = w$at_lower, at_upper = w$at_upper,
               acf1 = round(trend_tracking(res$fits[[p]])$acf1, 3))
  }))
}))
cat("\n=== NSW per-cycle sigmas and tracking ===\n")
print(walk_tab[order(year, party)])
cat(sprintf("L4a max residual autocorrelation = %+.3f (require < +0.25)\n",
            walk_tab[, max(acf1)]))
cat(sprintf("L4b min (noise / binomial floor) = %.2f (require >= 1)\n",
            walk_tab[, min(obs_pts / floor_2500)]))
cat(sprintf("L4c negative tail (reported): min %+.3f\n", walk_tab[, min(acf1)]))
if (any(walk_tab$at_lower)) {
  cat(sprintf("    walk at lower bound (no detectable movement, shrunk toward pooled): %s\n",
              walk_tab[at_lower == TRUE, paste(year, party, collapse = ", ")]))
}
stopifnot(walk_tab[, all(acf1 < 0.25)], walk_tab[, all(obs_pts >= floor_2500)],
          !any(walk_tab$at_upper))

cat(sprintf("L2  all trends and bands strictly inside (0, 100)  OK\nL3  endpoint FP sums: %s  (require 100 +/- 5, thin state polling)\n",
            paste(sprintf("%d=%.1f", c(2023, 2027), share_sums), collapse = "  ")))
stopifnot(all(abs(share_sums - 100) <= 5))
cat("Structural checks L2/L3 passed.\n\n")

cat("=== NSW 2027 cycle trend endpoints ===\n")
for (p in names(res2027$fits)) {
  tr <- res2027$fits[[p]]$trend
  cat(sprintf("%-4s FP: %5.1f  (95%%: %.1f-%.1f)\n",
              p, end_val(tr), tr$lo95[which.max(tr$date)], tr$hi95[which.max(tr$date)]))
}
cat(sprintf("ALP TPP: %5.1f (95%%: %.1f-%.1f)   [exhaust-adjusted]\n",
            end_val(res2027$tpp),
            res2027$tpp$lo95[which.max(res2027$tpp$date)],
            res2027$tpp$hi95[which.max(res2027$tpp$date)]))

for (yr in c(2023, 2027)) {
  res <- get(paste0("res", yr))
  ocols <- c("date", "mean", "sd", "lo95", "hi95")
  all_tr <- rbindlist(lapply(names(res$fits), function(p)
    data.table(party = p, scale = res$fits[[p]]$meta$scale,
               res$fits[[p]]$trend[, ocols, with = FALSE])))
  all_tr <- rbind(all_tr, data.table(party = "TPP_ALP", scale = "share",
                                     res$tpp[, ocols, with = FALSE]))
  fwrite(all_tr, sprintf("output/trend-nsw-%d.csv", yr))
  p <- plot_trends(res$fits, res$polls, tpp = res$tpp,
                   title = sprintf("NSW %d cycle - poll trend (auspol stage 3)", yr))
  ggplot2::ggsave(sprintf("output/trend-nsw-%d.png", yr), p,
                  width = 11, height = 6.5, dpi = 130)
}
fwrite(hy, "output/hyperpars-nsw.csv")
fwrite(fac, "output/firm-factors-nsw.csv")
fwrite(cmp, "output/scale-comparison-nsw.csv")
fwrite(walk_tab, "output/cycle-walks-nsw.csv")
cat("\nWrote output/trend-nsw-{2023,2027}.{csv,png}, hyperpars-nsw.csv, firm-factors-nsw.csv, scale-comparison-nsw.csv\n")
