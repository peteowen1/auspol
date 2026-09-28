# Pre-registration: which side lost its member (own vs opposing departed member)

Written 2026-09-28, before running. Pete chose "target-seat signals" for the
seat-level swing concentration behind v44's worst upsets.

## Evidence

v44's worst seats against AEF are a challenging major under-called by 7-17
points in seats it flipped (Parramatta Labor 31.7 vs 47.0). Measured on
v44's predictions over 892 two-major seats: where the incumbent party's
candidate is NOT the sitting member (187 seats; `same_mp_i = 0` on the
incumbent row, reliable in every pair, unlike the seat file's `retirement`
column, hardcoded 0 on 11 of 23 training pairs), actual minus prediction is
incumbent -0.53 (SE 0.45) vs +0.31 otherwise, challenger +1.58 (SE 0.40) vs
+0.70. `retirement_i` is a SEAT flag (on both majors' rows), so the model has
to infer which side lost its member.

## The change (xgb layer, all three feature builders)

`AUSPOL_XGB_DEPARTED_SIDE=1` adds two features:
- `own_departed_i` = 1 on the incumbent major's row when its candidate is
  not the sitting member;
- `opp_departed_i` = 1 on the OTHER major's row in such a seat.
0 elsewhere (a genuine "no", not filler: every two-major seat has a value).
In `scripts/fit_xgb_primary_v6.R` (flows to the as-at models),
`fit_xgb_primary_v6_final.R`, and live `xgb_primary_predict_live()`.

The same fix in `base_pred` (CLAUDE.md: test both layers) is a second arm,
pre-registered after this one's result: the baseline misses the incumbent
side by 2.4 points and the challenger by 0.9.

## Criterion

1. Rebuild against v44 (0.2881): seat log loss must not rise; weighted
   primary RMSE reported.
2. Named targets: the challenger's residual in departed-member seats (1.58)
   must shrink, and Parramatta / Monaro Labor must move toward actual.

**Unacceptable**: any change to rows outside the two majors in departed
seats beyond what refitting the trees implies (reported as the share of
rows whose prediction moved more than 0.5).
