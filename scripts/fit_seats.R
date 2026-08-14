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
# Stated assumptions, not modelled:
#   - the five non-classic seats (three Green-held, Prahran, South-West Coast)
#     are held by their current incumbents. A two-party number does not decide
#     a Labor-versus-Green or independent contest.
#   - seat deviations are independent. Real ones cluster by region, so the
#     spread of SEAT COUNTS here is, if anything, too narrow.
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
seat_sd <- mean(c(sp22$sd, sp18$sd))
cat(sprintf("\nS3  seat swing spread: 2022 sd %.2f (mean dev %+.2f), 2018 sd %.2f (mean dev %+.2f) -> using %.2f\n",
            sp22$sd, sp22$mean_dev, sp18$sd, sp18$mean_dev, seat_sd))
stopifnot(sp22$sd >= 2, sp22$sd <= 6, sp18$sd >= 2, sp18$sd <= 6)

# ---- S1: zero swing must reproduce the last result ----
zero <- simulate_seats(seats26, tpp_mean = PREV_TPP, tpp_sd = 0,
                       prev_tpp = PREV_TPP, seat_sd = seat_sd,
                       n_sims = 20000, seed = 1)
med0 <- stats::median(zero$seats_won)
cat(sprintf("S1  at zero swing: median %d classic seats (2022 actual %d of %d)  diff %+d\n",
            med0, PREV_SEATS, CHAMBER, med0 - PREV_SEATS))
stopifnot(abs(med0 - PREV_SEATS) <= 3)
stopifnot(zero$n_classic + zero$n_nonclassic == CHAMBER)
cat(sprintf("S2  %d classic + %d non-classic = %d  OK\n",
            zero$n_classic, zero$n_nonclassic, CHAMBER))

# ---- S4: monotonicity ----
probe <- vapply(c(44, 47, 50, 53, 56), function(v)
  stats::median(simulate_seats(seats26, v, 0, PREV_TPP, seat_sd,
                               n_sims = 4000, seed = 2)$seats_won), numeric(1))
cat(sprintf("S4  median seats at ALP TPP 44/47/50/53/56: %s\n",
            paste(probe, collapse = " / ")))
stopifnot(all(diff(probe) >= 0))
cat("Seat-model checks S1-S4 passed.\n")

# ---- Apply the Victoria 2026 projection ----
mix <- fread("output/projection-mix.csv")
cycles <- load_election_cycles()
days_out <- as.integer(cycles[region == "vic" & year == 2026, end] - Sys.Date())

# Rebuild the projected two-party vote (same route as fit_projection.R)
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

cat(sprintf("\n=== VICTORIA 2026 SEAT FORECAST — %d days out ===\n", days_out))
cat(sprintf("projected ALP two-party: %.2f (95%%: %.2f - %.2f)\n",
            pj$mean, pj$lo95, pj$hi95))

sim <- simulate_seats(seats26, pj$mean, pj$sd, PREV_TPP, seat_sd,
                      n_sims = 50000, seed = 42)
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
