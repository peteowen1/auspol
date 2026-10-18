# The salience screen's "surging" flag reads the result it predicts (2026-10-15)

Found tracing nt2020's +0.18 seat log loss under the WA/NT screened-slopes port
(published 15 Oct). Status: **LIVE**, not fixed. Pre-registration:
`docs/plans/prereg-surge-flag-time-forward-2026-10-15.md`.

## The defect

`surging_parties()` (`R/party_surge.R:64`) flags a party class as surging when
`abs(party_swing(region, prev, target)$swing) >= 5`. `party_swing()` sums
`votes` from `output/candidacies.csv` **at the target election**: the actual
result of the election being predicted. Two faults in one line:

1. **Leakage.** Every backtest screen sees its own election's outcome. Live,
   `candidacies.csv` has no vic2026 votes, so the same call fails and the
   screen runs with no surging class: backtests and the published forecast run
   different models.
2. **`abs()`.** A collapse counts as a surge. 28 of the 51 flags across the 35
   scored elections are falls.

## What it does

A class flagged surging is ungoverned, so a new class leader gets permit TRUE
(`R/salience_screen.R:462` for leaders without a salience row; ungoverned rows
otherwise). A permitted new leader takes slope 1.0, a full uniform carry of the
class's previous vote (`R/dev_slope.R:372`), which also bypasses the
departed-leader decay.

Worked example, Nelson nt2020: Gerry Wood (IND) won 60.5% in 2016 and retired.
NT's IND vote fell 18.8% -> 10.7% statewide at the 2020 election, so IND was
flagged "surging". Beverley Ratahi (IND, new) was permitted and given Wood's
whole base: IND predicted 59.4% (actual 29.6%); CLP 29.3% (actual 50.5%, won).
CLP win probability 0.458 -> 0.015 under the port; 77% of nt2020's regression.
Measured: `AUSPOL_HONOUR_DEPARTED=0` and `AUSPOL_SURGE_RECIPIENT=0` each change
0 of 150 nt2020 cells (quick_arm), because the permit path runs before both.

## Size (35 scored elections, 8,587 seat-class cells)

| Count | n |
|---|---|
| class-elections flagged from the actual result | 51 (28 falls) |
| permits TRUE as shipped | 3,431 |
| permits that exist only because of the flag | 598, in 15 elections |
| of those, only because a fall counted | 195, in 9 elections |

Largest: fed2013 95, qld2012 73, wa2025 68, wa2017 61, wa2021 59, qld2020 42.
Sizing script: run against `salience_permit_for()` with `surging_parties`
swapped three ways (shipped / rise-only / none).

## It reaches the published forecast

The production as-at xgb models (`output/xgb-primary-asat/feat_cols.txt`)
train on `permit` and `governed`, built by `fit_xgb_primary_v6.R:527` through
the same call. Training rows carry the outcome; the live vic2026 row is built
with no surging class. That is train/serve skew in the published number, not
only a backtest artefact. Not yet measured: how much the published vic2026
seat probabilities move.
