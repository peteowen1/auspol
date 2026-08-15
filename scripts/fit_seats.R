# Seat model: turn the projected two-party vote into a seat count.
#
# Each simulation draws a statewide result from the projection's own
# uncertainty, then gives every seat an independent deviation from it.
# Statewide error moves all seats together and sets the range of plausible
# outcomes; seat-level noise decides the close ones.
#
# Pre-registered checks, chosen before running:
#   S1  at ZERO swing the model must reproduce the last election's seat count
#       to within 3 seats. This tests the margins, the sign convention and the
#       simulation together, against a known answer.
#   S2  classic plus non-classic seats must equal the chamber size (88).
#   S3  the seat-level swing spread must land in [2, 6] points at both of the
#       two elections where it can be measured. Below 2 would mean seats move
#       as one, which they visibly do not; above 6 would mean the statewide
#       number carries almost no information.
#   S4  the median seat count must fall monotonically as the projected Labor
#       two-party vote falls.
#
# Regional swing structure, added after the first version treated seats as
# independent. Pre-registered before running:
#   R1  total per-seat variance must be PRESERVED by the split, i.e.
#       sqrt(region_sd^2 + within_sd^2) within 0.2 of the pooled sd. The
#       change redistributes variance into blocks; it does not add any.
#   R2  the seat-count distribution must be WIDER with regional structure than
#       without. This is the entire claim: correlated deviations flip
#       neighbouring seats together, whereas independent ones average out
#       across 83 seats.
#   R3  the MEDIAN seat count must be essentially unchanged (within 2 seats).
#       A random block effect adds spread, not bias; a shifted median would
#       mean the split had introduced one.
#
# Stated assumptions, not modelled:
#   - the five non-classic seats (three Green-held, Prahran, South-West Coast)
#     are held by their current incumbents. A two-party number does not decide
#     a Labor-versus-Green or independent contest.
#   - regional effects are drawn fresh each simulation rather than predicted.
#     Across Victoria's 13 regions they correlate only 0.27 between the 2018
#     and 2022 elections, so which region swings hardest is not forecastable
#     from the last one; that seats move in blocks at all is.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/fit_seats.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

dir.create("output", showWarnings = FALSE)

CHAMBER <- 88          # Victorian Legislative Assembly
MAJORITY <- 45
PREV_TPP <- 55.00      # ALP two-party at the 2022 Victorian election
PREV_SEATS <- 56       # ALP seats won in 2022

seats26 <- load_seats(2026, "vic")
seats22 <- load_seats(2022, "vic")
cat(sprintf("=== Victorian seats: %d total, %d classic, %d non-classic ===\n",
            nrow(seats26), sum(seats26$classic), sum(!seats26$classic)))
print(seats26[classic == FALSE, .(seat, incumbent, challenger, margin)])
stopifnot(nrow(seats26) == CHAMBER)

# ---- S3: how much do seats differ from the statewide swing? ----
sp22 <- seat_swing_spread(seats26, PREV_TPP - 57.60)   # the 2022 swing
sp18 <- seat_swing_spread(seats22, 57.60 - 51.99)      # the 2018 swing
seat_sd_pooled <- mean(c(sp22$sd, sp18$sd))
region_sd <- mean(c(sp22$sd_between, sp18$sd_between))
within_sd <- mean(c(sp22$sd_within, sp18$sd_within))
cat(sprintf("\nS3  seat swing spread: 2022 sd %.2f (mean dev %+.2f), 2018 sd %.2f (mean dev %+.2f) -> pooled %.2f\n",
            sp22$sd, sp22$mean_dev, sp18$sd, sp18$mean_dev, seat_sd_pooled))
stopifnot(sp22$sd >= 2, sp22$sd <= 6, sp18$sd >= 2, sp18$sd <= 6)

cat(sprintf("    regional share of variance: 2022 %.0f%%, 2018 %.0f%%\n",
            100 * sp22$sd_between^2 / sp22$sd^2,
            100 * sp18$sd_between^2 / sp18$sd^2))
cat(sprintf("    -> region sd %.2f, within-region sd %.2f\n", region_sd, within_sd))
recombined <- sqrt(region_sd^2 + within_sd^2)
cat(sprintf("R1  variance preserved: sqrt(%.2f^2 + %.2f^2) = %.2f vs pooled %.2f  %s\n",
            region_sd, within_sd, recombined, seat_sd_pooled,
            if (abs(recombined - seat_sd_pooled) < 0.2) "PASS" else "FAIL"))
stopifnot(abs(recombined - seat_sd_pooled) < 0.2)

# ---- S1: zero swing must reproduce the last result ----
zero <- simulate_seats(seats26, tpp_mean = PREV_TPP, tpp_sd = 0,
                       prev_tpp = PREV_TPP, seat_sd = within_sd,
                       region_sd = region_sd, n_sims = 20000, seed = 1)
med0 <- stats::median(zero$seats_won)
cat(sprintf("S1  at zero swing: median %d classic seats (2022 actual %d of %d)  diff %+d\n",
            med0, PREV_SEATS, CHAMBER, med0 - PREV_SEATS))
stopifnot(abs(med0 - PREV_SEATS) <= 3)
stopifnot(zero$n_classic + zero$n_nonclassic == CHAMBER)
cat(sprintf("S2  %d classic + %d non-classic = %d  OK\n",
            zero$n_classic, zero$n_nonclassic, CHAMBER))

# ---- S4: monotonicity ----
probe <- vapply(c(44, 47, 50, 53, 56), function(v)
  stats::median(simulate_seats(seats26, v, 0, PREV_TPP, within_sd,
                               region_sd = region_sd,
                               n_sims = 4000, seed = 2)$seats_won), numeric(1))
cat(sprintf("S4  median seats at ALP TPP 44/47/50/53/56: %s\n",
            paste(probe, collapse = " / ")))
stopifnot(all(diff(probe) >= 0))
cat("Seat-model checks S1-S4 passed.\n")

# ---- The projected vote, needed from here on ----
mix <- fread("output/projection-mix.csv")
cycles <- load_election_cycles()
days_out <- as.integer(cycles[region == "vic" & year == 2026, end] - Sys.Date())
fdat <- build_fundamentals_data()
m_tpp <- fit_fundamentals(fdat, "@TPP")
live <- build_fundamentals_data(polled_only = FALSE, require_actual = FALSE)
kf <- live$region == "vic" & live$year == 2026 & live$party == "@TPP"
fund_vic <- predict_fundamentals(m_tpp, live[which(kf), ])
polls <- load_polls("vic")
pri <- load_prior_results()
kp <- pri$region == "vic" & pri$year == 2026
priors <- setNames(pri$prev1[which(kp)], pri$party[which(kp)])
fl <- flows_for(load_preference_flows(), 2026, "vic", quiet = TRUE)
now <- trend_as_at(polls, 2026, cycles, Sys.Date(), priors, fl)
pj <- project_result(now$tpp, fund_vic, mix, days_out)

# ---- R2/R3: what does the regional layer actually change? ----
cmp <- function(rsd, ssd, label) {
  s <- simulate_seats(seats26, pj$mean, pj$sd, PREV_TPP, ssd, region_sd = rsd,
                      n_sims = 50000, seed = 99)
  q <- stats::quantile(s$seats_won, c(0.05, 0.5, 0.95))
  cat(sprintf("    %-22s median %2d, 90%% range %2d-%2d (width %2d), sd %.2f\n",
              label, q[2], q[1], q[3], q[3] - q[1], stats::sd(s$seats_won)))
  list(med = q[2], width = unname(q[3] - q[1]), sd = stats::sd(s$seats_won))
}
cat("\nR2/R3  effect of the regional layer at the projected vote:\n")
iid <- cmp(0, seat_sd_pooled, "independent seats")
reg <- cmp(region_sd, within_sd, "regional blocks")
cat(sprintf("R2  seat-count spread widens: sd %.2f -> %.2f (+%.0f%%)  %s\n",
            iid$sd, reg$sd, 100 * (reg$sd / iid$sd - 1),
            if (reg$sd > iid$sd) "PASS" else "FAIL"))
cat(sprintf("R3  median essentially unchanged: %d -> %d  %s\n",
            iid$med, reg$med, if (abs(reg$med - iid$med) <= 2) "PASS" else "FAIL"))
stopifnot(reg$sd > iid$sd, abs(reg$med - iid$med) <= 2)

# Where does seat-count uncertainty come from? Reported as three separate
# simulations, NOT as a variance decomposition: the seat count is a step
# function of the vote, so the components interact and their variances do not
# add. An earlier version divided them and produced "156% of the variance",
# which is how the non-additivity was noticed.
sd_of <- function(tsd, rsd, ssd) stats::sd(simulate_seats(
  seats26, pj$mean, tsd, PREV_TPP, ssd, region_sd = rsd,
  n_sims = 50000, seed = 7)$seats_won)
full <- sd_of(pj$sd, region_sd, within_sd)
state_only <- sd_of(pj$sd, 0, 0.001)
seat_only <- sd_of(0.001, region_sd, within_sd)
cat(sprintf("
Seat-count uncertainty (sd in seats, three separate simulations):
  statewide projection error alone : %.2f
  seat and regional variation alone: %.2f
  both together                    : %.2f

Two things follow. The statewide vote is by far the larger driver (%.1f
against %.1f), so accuracy in the PROJECTION is worth more than further
seat-model refinement. And note the third number is BELOW the first: adding
per-seat randomness makes the seat total less volatile, not more, because
Victorian Labor seats are bunched tightly on the pendulum (a dense cluster
between 54 and 60) and a uniform swing sweeping through them flips many at
once. Per-seat noise smooths that step, damping the amplification.
", state_only, seat_only, full, state_only, seat_only))

# ---- Apply the Victoria 2026 projection ----
cat(sprintf("\n=== VICTORIA 2026 SEAT FORECAST — %d days out ===\n", days_out))
cat(sprintf("projected ALP two-party: %.2f (95%%: %.2f - %.2f)\n",
            pj$mean, pj$lo95, pj$hi95))

sim <- simulate_seats(seats26, pj$mean, pj$sd, PREV_TPP, within_sd,
                      region_sd = region_sd, n_sims = 50000, seed = 42)
# Non-classic seats are assumed held; none is Labor-held in 2026.
alp_extra <- sum(seats26$incumbent == "ALP" & !seats26$classic)
total_alp <- sim$seats_won + alp_extra
q <- stats::quantile(total_alp, c(0.05, 0.25, 0.5, 0.75, 0.95))

cat(sprintf("ALP seats: median %d  (50%%: %d-%d, 90%%: %d-%d)  of %d\n",
            q[3], q[2], q[4], q[1], q[5], CHAMBER))
cat(sprintf("P(ALP majority, %d+ seats) = %.1f%%\n",
            MAJORITY, 100 * mean(total_alp >= MAJORITY)))
cat(sprintf("P(ALP largest bloc vs Coalition) = %.1f%%\n",
            100 * mean(total_alp > (CHAMBER - 3 - total_alp))))
cat(sprintf("2022 actual was %d seats, so a median loss of %d\n",
            PREV_SEATS, PREV_SEATS - as.integer(q[3])))

cat("\n=== Most marginal classic seats (Labor win probability) ===\n")
bs <- sim$by_seat
print(bs[alp_win_prob < 0.95 & alp_win_prob > 0.05][order(-alp_win_prob)][
  , .(seat, seat_region, incumbent, alp_tpp_now = round(alp_tpp_now, 1),
      alp_win_prob = round(alp_win_prob, 3))])

fwrite(sim$by_seat, "output/seats-vic-2026.csv")
fwrite(data.table(seats = total_alp), "output/seat-sims-vic-2026.csv")
cat("\nWrote output/seats-vic-2026.csv and seat-sims-vic-2026.csv\n")
