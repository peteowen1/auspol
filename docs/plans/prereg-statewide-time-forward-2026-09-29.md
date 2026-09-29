# Pre-registration: time-forward statewide fundamentals and trend mix (leak fix)

Written 2026-09-29, before running. A LEAK FIX: ships whatever it does to the
score, as v45/v47/v49 did.

## The defect

Every backtest's statewide projection blends the poll trend with a
fundamentals prediction by a horizon-dependent weight:

- **Fundamentals**: `fundamentals_loo_table()` (`R/forecast_statewide.R`) and
  the fed harness's own copy are LEAVE-ONE-OUT ridge fits, so NSW 2023's
  prediction was fitted partly on later elections and its penalty chosen on
  all of them. Effect is small: nsw2023 46.51 -> 46.22.
- **Mix weight**: `output/projection-mix.csv` was fitted by
  `fit_projection_mix()` on all 42 elections. Its day-before trend weight is
  0.72. Refitted on earlier elections only it is 0.80-1.00 (nsw2023 0.80,
  nsw2019 1.00, vic2022/qld2024/fed2022 0.85). So the leak gave the
  fundamentals more weight than history supported.

Found walking nsw2023 (Pete chose the statewide level over seat-specific
swings): the poll trend had Labor at 54.17 two-party (actual ~54.3), the
projection pulled it to 52.03, and anchoring the majors to that moved
Labor's primary from 35.4 to 32.2 (actual 37.0).

## The change (`AUSPOL_FUND_TIME_FORWARD`, default "1")

`R/fundamentals_tf.R`: `fundamentals_tf()` fits `fit_fundamentals()` on
elections before the target only; `projection_mix_tf()` refits the mix on
`output/projection-data.csv` rows of earlier elections, each carrying its own
time-forward fundamentals. Used by `forecast_statewide_or_oracle()` (vic,
nsw, qld, sa, wa) and the fed harness. "0" restores the old tables for
comparison. The live Victoria 2026 forecast is untouched: every election in
both tables precedes it.

## Checks

Print the fundamentals and day-before weight per target. Full rebuild against
v50 (the statewide feeds stage-1 base_pred); ledger and all elections
reported per election; the statewide Labor two-party projection per target
before and after.
