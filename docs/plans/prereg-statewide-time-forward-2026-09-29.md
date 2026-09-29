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

## AMENDMENT (2026-09-29, after rebuild R's stage 1 stopped; the text above is unedited)

wa2001 (February 2001) has too few earlier elections carrying time-forward
fundamentals to fit a mix, so its pair was skipped and stage 2 refused to pool
a stale file. Rule added: when no mix can be fitted, the projection uses the
poll trend alone (weight 1), with bias and spread from the earlier elections'
own trend errors (these need no fundamentals). It does not favour any result:
it applies only where the earlier evidence for mixing is absent.

## RESULT (2026-09-29 17:30, rebuild R against rebuild P = v50)

**Ships as ledger v51, as pre-registered: a leak fix ships whatever it scores.**

AEF-7 ledger seat log loss (lower is better) 0.2719 -> 0.2760; weighted
primary RMSE 4.887 -> 4.882; TCP MAE 3.79 -> 3.79; accuracy 88.9% -> 88.3%.
All matched elections (`compare_rebuilds.R`, 1,593 seat-elections in 16
elections): 0.3359 -> 0.3437, per-election mean +0.0081 (SE 0.0032), better
in 3 of 16.

Ledger per election, seat log loss v50 -> v51 (negative = better):

| pair | n | v50 | v51 | change |
|---|---|---|---|---|
| fed2022 | 151 | 0.2611 | 0.2638 | +0.0027 |
| fed2025 | 150 | 0.2957 | 0.3061 | +0.0105 |
| nsw2023 | 88 | 0.2673 | 0.2577 | **-0.0096** |
| qld2024 | 93 | 0.2930 | 0.2955 | +0.0025 |
| sa2026 | 47 | 0.2658 | 0.2519 | -0.0139 |
| vic2022 | 78 | 0.2218 | 0.2436 | +0.0218 |
| wa2025 | 53 | 0.2845 | 0.2907 | +0.0062 |

Statewide Labor two-party, day-before trend / time-forward fundamentals /
projection (trend weight): nsw2023 54.17 / 46.22 / **52.58** (0.80; was 52.03,
actual ~54.3); vic2022 56.94 / 48.95 / 55.74 (0.85; actual 55.0, so the extra
trend weight moved it away); fed2019 52.80 / 49.28 / 52.80 (1.00; actual 48.5:
the leaked mix had leaned on the fundamentals in the one year the polls were
badly wrong, worth +0.035 there). The largest non-ledger cost is fed2019; the
largest ledger cost vic2022. Both are the honest price of the mix weight no
longer knowing about later elections.

The target moved as intended: nsw2023's projection rose 0.55 points toward
the trend and its seat log loss fell 0.0096. The remaining nsw2023 gap is the
fundamentals themselves (46.22 against ~54.3), not a leak.
