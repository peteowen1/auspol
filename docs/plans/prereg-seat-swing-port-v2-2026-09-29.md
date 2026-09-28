# Pre-registration: time-forward seat-swing port (`AUSPOL_SEAT_SWING_PORT=2`)

Written 2026-09-29, before running.

## Why this is being re-tested

The August port (`=1`) was refused three times on calibration slope, a
criterion since deprecated, while picking winners better in 3 of 3. It is
not testable as it stood, for three reasons found today:

1. **Leak.** `SEAT_SWING_COEF = 0.7452` (`R/seat_swing.R:41`) was fitted
   once across every state cycle, including the ones it was scored on.
2. **Erased.** It ran BEFORE `xgb_primary_override()`, which overwrites every
   ALP/LNP cell it has a prediction for. Under the shipped
   `AUSPOL_XGB_PRIMARY=1` the port did almost nothing.
3. **Corrupt input.** In the AEC's 2025 booth two-party file, divisions with
   no 2022 comparison (Wannon, Nicholls, Bendigo, Mackellar, Brisbane,
   Goldstein; 411 booths, 4.3% of votes) report the booth's whole share as
   its Swing. `scripts/transpose_fed_swing.R` took that as a swing: Bendigo
   West +55.5, vic2026 sd 11.30. Those booths are now dropped (FSWN), giving
   vic2026 a mean of +2.55 and an sd of 3.21. Earlier years lose 0.3–1.0% of votes the same way.

## The change

`R/seat_swing_port.R`:

- **Fit.** For target T, regress each seat's two-party swing relative to its state's
  (`output/seat-tpp-estimates.csv`, previous state election to this one)
  through the origin on its transposed federal swing relative to its cycle
  mean. Use state cycles dated before T only (`elections_before`).
- **Shrink.** Shrink toward 0: `b * b^2/(b^2 + se^2)`, where se is the larger of the
  cluster-robust (by cycle) and ordinary errors. Fewer than 3 earlier cycles gives 0.
- **Apply.** Apply `coef * (fed_swing - mean)`, re-centred, +adj to ALP and -adj to LNP,
  renormalised. This runs AFTER the xgb override, in the vic, nsw, qld and sa harnesses and
  live `fit_seats_full.R`.

**Coefficients per target:**

| Target | Coefficient (se) | Earlier cycles | Seats matched |
|---|---|---|---|
| vic2022 | 0.324 (0.089) | 4 | 79 of 88 |
| nsw2023 | 0.391 (0.075) | 5 | 88 of 93 |
| qld2024 | 0.422 (0.059) | 6 | all |
| sa2026 | 0.422 (0.052) | 7 | 46 of 47 |
| vic2026 (live) | 0.436 (0.051) | 8 | 87 of 87 |

vic2018, nsw2019 and qld2020 get 0 (too few earlier cycles). sa2018 has no
sa2014 baseline in the corpus, so it never enters. That gap is recorded, not fixed:
SA's 2018 redistribution makes a name match weak.

## Decision rule

Rebuild against rebuild K (v47):

- **Primary:** ledger seat log loss (lower is better), 0.2840.
- **Targeted:** seat log loss on the 8 ported elections (vic2018/22,
  nsw2019/23, qld2020/24, sa2022/26) from `forecasts-seats.csv`. Three of these
  (vic2018, nsw2019, qld2020) have a coefficient of 0 and must be byte-identical.
  That is the control.
- **Ship if** the targeted mean improves AND the ledger does not worsen by more
  than one seat-level SE. **Refuse otherwise.**
- **Unacceptable even if it passes:** any change on a control election, or on fed/wa
  (both mean the switch leaked somewhere it should not reach).
- **Reported regardless:** weighted primary RMSE and TCP MAE.
