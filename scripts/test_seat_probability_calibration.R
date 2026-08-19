# Are our per-seat win probabilities calibrated?
#
# Against docs/plans/prereg-seat-probability-calibration.md, committed before
# anything was measured. The decision rule and five refusals are in the plan and
# are NOT restated here.
#
# The pendulum gives every seat a probability that Labor holds it. That claim
# has never been checked. Two-party interval coverage is checked (93% against a
# claimed 95%) and first-preference coverage was checked today; per-seat
# probabilities are the most visible output and the least tested.
#
# Emits SC* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

N_SIMS <- 20000
HORIZON <- 30

# (before-file, after-file, region, year) -- predictors from the file written
# BEFORE the election, outcome from the one written for the following cycle.
ELECTIONS <- list(
  list(before = "2022vic.txt", after = "2026vic.txt", rg = "vic", yr = 2022),
  list(before = "2023nsw.txt", after = "2027nsw.txt", rg = "nsw", yr = 2023)
)

cycles <- load_election_cycles(); ev <- load_eventual_results()
pri_all <- load_prior_results(); mix <- fread("output/projection-mix.csv")
sd_err <- mix[horizon == HORIZON, sd_err_loo][1]

rows <- list()
for (E in ELECTIONS) {
  seats <- load_seats(E$yr, E$rg)
  after <- load_seats(as.integer(sub("^(\\d+).*$", "\\1", E$after)), E$rg)

  # The outcome: each seat's ACTUAL two-party swing at this election, which the
  # following cycle's file records as its "previous" swing.
  out <- merge(seats[, .(seat, margin, incumbent, classic)],
               after[, .(seat, actual_swing = prev_swing)], by = "seat")
  out <- out[classic == TRUE & is.finite(actual_swing) & is.finite(margin)]
  # Labor holds the seat if its margin plus the swing toward Labor stays above 0.
  out[, alp_won := (margin + actual_swing) > 0]

  ka <- ev$region == E$rg & ev$year == E$yr & ev$party == "@TPP"
  actual_tpp <- ev$actual[which(ka)][1]
  kp <- pri_all$region == E$rg & pri_all$year == E$yr
  prev_tpp <- pri_all[which(kp)][party == "@TPP", prev1][1]
  stopifnot(is.finite(actual_tpp), is.finite(prev_tpp))

  sp <- seat_swing_spread(seats, actual_tpp - prev_tpp)
  cat(sprintf("\nSC0  %s %d: %d classic seats; ALP held %d; TPP %.2f -> %.2f\n",
              toupper(E$rg), E$yr, nrow(out), sum(out$alp_won), prev_tpp, actual_tpp))

  run <- function(tpp_mean, tpp_sd, label) {
    s <- seats[seat %in% out$seat]
    sim <- simulate_seats(s, tpp_mean = tpp_mean, tpp_sd = tpp_sd,
                          prev_tpp = prev_tpp, seat_sd = sp$sd_within,
                          region_sd = sp$sd_between, n_sims = N_SIMS, seed = 7)
    bs <- sim$by_seat[, .(seat, p = alp_win_prob)]
    m <- merge(bs, out[, .(seat, alp_won)], by = "seat")
    m[, `:=`(election = paste(E$rg, E$yr), arm = label)]
    m[, alp_total := sim$alp_total[1]]
    list(m = m, tot = sim$seats_won)
  }

  # Conditional: hand it the actual statewide result. Diagnostic only.
  a <- run(actual_tpp, 0, "conditional")
  # Forecast: the projection the model would have made, with its own spread.
  b <- run(actual_tpp, sd_err, "forecast")
  rows[[length(rows) + 1L]] <- a$m
  rows[[length(rows) + 1L]] <- b$m

  q <- stats::quantile(b$tot, c(0.05, 0.95))
  cat(sprintf("SC0  seat-count 90%% range %d-%d; actual %d -> %s\n",
              round(q[1]), round(q[2]), sum(out$alp_won),
              if (sum(out$alp_won) >= q[1] && sum(out$alp_won) <= q[2]) "COVERED" else "MISSED"))
}

dt <- rbindlist(rows)
fwrite(dt, file.path("output", "seat-prob-calibration.csv"))

brier <- function(p, y) mean((p - y)^2)
slope_of <- function(d) {
  # The clamp must land in the DATA FRAME the formula is evaluated in. Written
  # as `p <- pmin(...)` then `~ qlogis(p)`, the formula resolves `p` to the
  # column and the local clamp is ignored -- qlogis(0) is -Inf and glm dies.
  # Same shadowing family as the loop-variable bug above.
  z <- data.frame(alp_won = as.integer(d$alp_won),
                  lo = stats::qlogis(pmin(pmax(d$p, 1e-6), 1 - 1e-6)))
  stats::coef(stats::glm(alp_won ~ lo, data = z, family = stats::binomial()))[["lo"]]
}

# NOT `for (arm in ...) dt[arm == get("arm")]`. `arm` is also a COLUMN, so the
# comparison is the column against itself and every row survives -- the NSE
# shadowing this repo has been bitten by repeatedly. Name the loop variable
# differently and subset outside the frame.
for (this_arm in c("conditional", "forecast")) {
  d <- dt[dt$arm == this_arm]
  cat(sprintf("
=== %s ===
", toupper(this_arm)))
  cat(sprintf("SC1  n = %d; predicted mean %.3f; observed rate %.3f\n",
              nrow(d), mean(d$p), mean(d$alp_won)))
  d[, bin := cut(p, seq(0, 1, 0.1), include.lowest = TRUE)]
  cat("SC2  reliability\n")
  print(d[, .(n = .N, predicted = round(mean(p), 3),
              observed = round(mean(alp_won), 3),
              gap = round(mean(alp_won) - mean(p), 3)), by = bin][order(bin)])
  base <- mean(d$alp_won)
  cat(sprintf("SC3  Brier %.4f | base-rate %.4f | incumbent-certain %.4f\n",
              brier(d$p, d$alp_won), brier(rep(base, nrow(d)), d$alp_won),
              brier(as.numeric(d$p > 0.5), d$alp_won)))
  sl <- slope_of(d)
  cat(sprintf("SC4  calibration slope %.3f (1 = calibrated, <1 = overconfident)\n", sl))
  worst <- d[, .(n = .N, gap = abs(mean(alp_won) - mean(p))), by = bin][n >= 5]
  cat(sprintf("SC5  worst reliability bin with n>=5: %.3f\n", max(worst$gap)))
}

fc <- dt[dt$arm == "forecast"]
sl <- slope_of(fc)
verdict <- if (sl >= 0.8 && sl <= 1.25) {
  sprintf("CALIBRATED (slope %.3f) -- change nothing", sl)
} else if (sl < 0.8) {
  sprintf("OVERCONFIDENT (slope %.3f) -- test a temperature", sl)
} else {
  sprintf("UNDERCONFIDENT (slope %.3f) -- report, do not sharpen", sl)
}
cat(sprintf("\nSC6  verdict: %s\n", verdict))
cat("Wrote output/seat-prob-calibration.csv\n")
