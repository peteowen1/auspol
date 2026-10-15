# Pre-registration: a leak-free "surging" flag for the salience screen (2026-10-15)

Findings: `docs/reviews/surge-flag-leak-2026-10-15.md`. Committed BEFORE any arm
below is run. Pete, 15 Oct: "size it, then prereg".

## What is decided already, and what this decides

The shipped flag reads the target election's own result. **It goes regardless of
the result below**: a leak is removed on correctness (the 14 Oct leak fixes
shipped at seat log loss 0.3262 -> 0.3264 on the same basis). The cost of the leak
is measured and reported, never used to keep it.

This experiment decides only **which leak-free rule replaces it**:

| Arm | Switch | Rule |
|---|---|---|
| S (shipped, leaks) | `AUSPOL_SURGE_SOURCE=actual` | `abs(actual swing) >= 5`. Reported only: the value of the leak. |
| N | `AUSPOL_SURGE_SOURCE=none` | no class is ever surging (what the live forecast already runs). |
| T | `AUSPOL_SURGE_SOURCE=forecast` | `level_pred - prev >= 5`, rises only, from the time-forward statewide forecast (`output/level-pred.csv`, rebuild stage 3). |

One switch in `surging_parties()`, so the screen in all seven harnesses and the
xgb training features (`fit_xgb_primary_v4/v6.R`) change together. Registered in
`scripts/published_flags.R` in the same commit. Threshold 5 is unchanged (it is
the existing constant; not tuned here).

## Dry run on known cases (done before committing; `level-pred.csv` of 15 Oct)

| Case | Actual swing | T swing | Should T flag | T flags |
|---|---|---|---|---|
| sa2026 One Nation | +19.9 | +17.8 | yes | yes |
| qld2017 One Nation | +12.8 | +12.0 | yes | yes |
| nt2020 IND (collapse) | -8.1 | 0.0 | no | no |
| nt2020 Territory Alliance (new party) | +14.1 | none | yes | **no** |

T flags 16 class-elections (S: 51). Elections where T and N differ: fed2007,
nsw2011, nsw2015, qld2012, qld2015, qld2017, qld2024, sa2022, sa2026, wa2001,
wa2005, wa2013, wa2017, wa2021, wa2025 (15).

## Criterion

Measured by the full rebuild (stages 1-8, 20,000 sims), because the xgb training
features change and `quick_arm.R` reads a static xgb file. One rebuild per arm:
N and T (S is the 15 Oct snapshot `20261015-1317-20697de-from1`).

1. **Primary (targeted), T vs N:** pooled seat log loss over the 15 elections
   where T and N differ, SE clustered on election. T ships if it is lower by
   more than 1 SE; N ships if T is higher by more than 1 SE; otherwise **N**
   (the simpler rule, and the one live already runs).
2. **Guard, all 35 elections:** the winner must not be worse than the other arm
   by more than 1 SE (clustered on election). Reported, also: share RMSE
   (weighted), AEF-7 ledger, reliability at 0.9 / 0.95 / 0.99 with counts.
3. **Reported, never decisive:** S minus winner, i.e. what the leak was worth,
   per election.

Noise: the 35-election pooled change of 14 Oct had SE 0.0039; over 15
elections expect SE ~0.006. The expected T-vs-N effect is unknown and may sit
inside it, in which case rule 1 picks N.

## What would make an apparent win unacceptable (decided now)

- **T wins on one election**: if more than half of T's primary gain comes from a
  single election, T is refused and N ships.
- **T flags a fall**: impossible by construction; asserted in code (stop).
- **Live cannot compute T**: `level-pred.csv` has no vic2026 row today. T ships
  only if the live run reads the same pre-election level it would in a backtest
  (`state_mean` from `fit_seats_full.R` stage one, or a vic2026 row in
  `level-pred.csv`), printed at the point of use. Otherwise N ships.
- **Nelson (nt2020) must not keep a full carry**: under the winning arm, IND in
  Nelson nt2020 must be predicted below 45% (it was 43.2 before the port, 59.4
  after; actual 29.6). If not, something else permits it and the fix is
  incomplete.

## What this cannot see

- A new party with no forecast row (Territory Alliance 2020) is never surging
  under T. That is what the forecast knew; under S it was handed the result.
- NT has no polls, so `level_pred` = previous result and no NT class can surge
  under T or N.
- SA-Best 2018 (filed IND, 17.7% actual, `level_pred` 4.6%): the statewide
  forecast misses it, a level-pred gap, not this rule's.
