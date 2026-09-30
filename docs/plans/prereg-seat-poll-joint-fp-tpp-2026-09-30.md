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
