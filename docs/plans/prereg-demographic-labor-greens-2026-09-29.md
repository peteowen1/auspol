# Pre-registration: demographic correction for Labor and Greens, time-forward (`AUSPOL_DEMO_RESID=2`)

Written 2026-09-29 21:50, before the rebuild. Pete chose this after walking
five nsw2023 seats (Parramatta, Bankstown, Heathcote, Balmain, Dubbo):
option 1, "build it for Greens and Labor only".

## Why

- The parked demographic correction (`AUSPOL_DEMO_RESID=1`, 2026-09-15) was
  refused on a leave-one-out fit and never offered Labor: its classes were
  ONP, OTH_RIGHT and GRN, fitted on the frozen v6 residual file.
- Labor's seat-specific miss rises with the share speaking another language at
  home in 16 of 22 elections (nsw2019 +0.79 per 10 points, t 3.7; nsw2023
  +0.70, t 2.9). Time-forward it is small (pooled 0.25, SE 0.14).
- Worked examples: the Greens fit is stable (Balmain +1.5 toward actual; Dubbo
  -0.8), Labor small (Parramatta +0.6 of 14), the Liberal fit spreads large
  offsetting weights over correlated columns (Year 12 +1.06, degree -1.07), so
  it is left out.

## The change

Mode "2" of `demographic_residual_apply()`: classes ALP and GRN; training
table = `output/forecasts.csv` (every election's `xgb_pred_seat` from an as-at
model), summed per (election, seat, class); only elections before the target;
all seven census columns z-scored within each election; elastic net, alpha
and lambda by leave-one-training-election-out CV; no intercept, so it moves
vote between seats and leaves each class's statewide total alone. Applied
right after the xgb override in all six harnesses (the existing wiring).
Not wired into live `fit_seats_full.R`: that follows only if it ships.

## Measurement (rebuild V against fresh v51 = `output/rebuild-R2/`)

1. **Primary: primary-vote RMSE over all 22 elections**, every (election,
   seat, class) row of the harness share-detail files, points, lower is
   better. Must improve.
2. **And** pooled seat log loss (`compare_rebuilds.R` CR2, per-election mean)
   does not worsen by more than 1 SE.
3. **And** the permutation control (`AUSPOL_DEMO_RESID_SHUFFLE=1`, census
   rows shuffled between seats within each election, rebuild W) gains less
   than half as much RMSE as the real arm. Run only if 1 and 2 pass.
4. Reported: Labor and Greens RMSE separately; AEF-7 ledger; the five
   worked-example seats; per-election change.

Expected size: nsw2023 alone moved 4.71 -> 4.67 in the worked example, so the
effect may sit near what one rebuild can resolve. If it does not clear 1, it
is refused, not re-tuned.
