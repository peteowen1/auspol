# Pre-registration: seat polls' primary AND two-party figures, weights fitted jointly (`AUSPOL_SEAT_POLL_BLEND=3`)

Written 2026-09-30 12:20, before building. Pete (quiz answer): "we should
probably use every poll's primary and every poll's tpp to learn from ... let
the modelling process decide how much weight to give each".

## Why

The v50 blend uses only primaries. 139 seat polls report only a two-party
figure (87 federal 2016, 16 NSW 2023, 17 Queensland, 19 federal 2019-25),
including Parramatta 2023 (RedBridge: Coalition 46; ours 55.2; AEF 47.4;
actual 41.5), and most polls with primaries also give a two-party figure.
AEF credits "adjustment towards seat polling" +2.35 two-party in Parramatta.

## The change

- Seat two-party poll: mean over polls in the 90-day window of Labor's share
  of Labor-vs-Coalition two-party figures (Coalition figures flipped).
- Our two-party per seat: `ALP + sum(other share x flow to ALP)` over
  Labor + Coalition + the flowed shares, flows from `flows_for()`
  (earlier elections only), from this run's as-at primaries
  (`current_seat_predictions()`).
- Joint weights, time-forward (earlier elections only): for every polled
  (seat, class) cell, miss = b1 x (poll primary - ours) + b2 x s x (poll
  two-party - our two-party), s = +1 for Labor, -1 for the Coalition, 0 else;
  a missing figure contributes 0. Through the origin, SE clustered on
  seat-election, each b shrunk `b^3/(b^2+se^2)` and clamped to [0, 1].
- Applied after the override, port and demographic step as the v50 blend is,
  in all six harnesses and live (shipped table extended).

## Decision rule (against published v53 = output/rebuild-V53; rebuild from stage 6: the blend runs on the xgb layer only and, since v53, corrections learn from this run)

1. **Primary (targeted): seat log loss on polled seat-elections** (seats with
   any seat poll in the window), paired by seat. Must improve by more than
   1 SE.
2. Guard: pooled seat log loss (all elections, CR2) not worse by more than
   1 SE; primary RMSE not worse by more than 1 SE.
3. Reported: b1, b2 per target; nsw2023 Parramatta and Penrith; fed2016
   (two-party only); the like-for-like ledger.

## AMENDMENT (2026-09-30 12:52, before any valid run; text above unedited)

Two corrections. (1) The blend runs after the port and seat-poll position,
i.e. BEFORE the demographic step, not after it. (2) A LEAK in the first build,
found from Pete's question "can't we use dates not years": `.our_seat_tpp()`
called `flows_for(year - 1)` without `as_of`, and `flows_for()` estimates
unobserved flows from the latest five elections as of TODAY, so every target
got the same flows (Greens 83.461, One Nation 33.730) including elections
after it. Now filtered by date first (`elections_before()`), differing on 17
of 18 targets. Rebuild J3 (launched 12:49) ran the leaky version and is
discarded; the valid run is J4. Production paths were checked: the statewide
draws (`R/forecast_mode.R:112`) and projection data (`R/projection.R:305`)
pass `as_of` and are time-forward; the off-by-default NSW exhaustion arm
(`backtest_candidate_nsw.R:1004`) uses the target's own flows and is noted.

## RESULT (rebuild J4 vs v53, 13:00-13:11; J3 discarded for the flow leak)

**Refused.** Polled seat-elections (357): log loss 0.3497 -> 0.3674 (+0.0177,
SE 0.0080, better in 108). Guards also fail: pooled log loss 0.3409 ->
0.3457; primary RMSE 4.1771 -> 4.1973 (+0.170 MSE, SE 0.041). AEF-7 ledger
0.2722 -> 0.2839.

By election (polled seats): nsw2023 -0.2027 (n 6; Parramatta's winner
probability 0.111 -> 0.395), fed2019 -0.1223 (n 10), qld2020 -0.0512 (n 3);
fed2025 +0.0459 (n 150), fed2022 +0.0132 (n 151), sa2026 +0.038 (n 1).
Weights e.g. nsw2023 w_primary 0.20 / w_twoparty 0.38; fed2025 0.20 / 0.41.

Reading: two-party figures help where polls are few and direct, and hurt
where MRP releases dominate. A direct-polls-only two-party blend is the
obvious next arm, but it was suggested by this result, so it needs its own
prereg.
