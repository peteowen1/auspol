# Pre-registration: seed ensemble for the xgb layer (`AUSPOL_XGB_ENSEMBLE`)

Registered 2026-10-02 before running. Pete chose it after the noise floor.

## Why
An equally valid refit (seeds 42/7/99) moved Victoria's seat log loss by up to
0.011, the AEF-7 ledger by 0.004 and primary RMSE by 0.031
(plans/noise-floor-2026-10-02.md), so differences of that size in any test are
not evidence. Averaging K fits shrinks the fit-to-fit spread by about sqrt(K)
and usually helps accuracy a little.

## Change
K = 3: per as-at target and for the production model, one CV (as now) fixes the
rounds, then K trainings with seeds base, base+1, base+2; raw predictions
averaged, then floored at 0. K = 1 reproduces today exactly.

## Runs (rebuild from stage 4; stages 1-3 unchanged)
- E42: `AUSPOL_XGB_ENSEMBLE=3 AUSPOL_XGB_SEED=42 AUSPOL_SEED=42`
- E7:  `AUSPOL_XGB_ENSEMBLE=3 AUSPOL_XGB_SEED=7  AUSPOL_SEED=7`
Compared with v57 (K=1, seed 42) and the K=1 seed-7 run (`20261002-1114-bfc14ff-from3`).

## Criteria
1. ACCURACY, E42 vs v57: 22-election per-election log loss not worse by more
   than 0.0012 (the single-seed range); primary RMSE (all rows) not worse by
   more than 0.01.
2. NOISE, |E42 - E7| against |v57 - seed-7 K=1|: smaller on Victoria seat log
   loss and on primary RMSE (all rows). Reported for the ledger and 22
   elections too.
Ships if 1 holds and 2 shows the spread reduced. Stage 4 time is reported.

## RESULT, 2026-10-02 13:05: PASSES

E42 `20261002-1251-1221385-from4`, E7 `20261002-1303-1221385-from4`.
1. Accuracy, E42 vs v57: 22-election log loss 0.3422 -> 0.3408; primary RMSE
   4.1507 -> 4.1534 (+0.0027, inside 0.01); ledger 0.2700 -> 0.2682; Victoria
   0.2723 -> 0.2750 (inside noise). PASS.
2. Noise, |E42-E7| vs |v57-seed7 K=1|: Victoria log loss 0.0041 -> 0.0018;
   primary RMSE 0.0312 -> 0.0087; Victoria RMSE 0.0395 -> 0.0241. PASS.
   22-election 0.0012 -> 0.0020 and ledger 0.0006 -> 0.0008 did not shrink:
   both runs also changed the SIMULATION seed, which the ensemble cannot
   average away. Stage 4 cost: 216 -> 226 s.
