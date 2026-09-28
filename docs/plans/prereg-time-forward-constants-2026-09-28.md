# Pre-registration: every fitted constant in base_pred learns only from earlier elections

Written 2026-09-28, before running. A LEAK FIX: it ships whatever it does to
the score, and the rebuild gives the honest ledger.

## The defect

The 2026-09-19 time-forward work converted the xgb models (as-at, one per
election) but not the constants fitted inside `base_pred`. These choose their
training elections by excluding ONLY the target, so a backtest of fed2019
learns from nsw2023, sa2026 and fed2025:

- `R/split_slope.R` lines ~180, 349, 440, 582, 670 (split slopes, conditional
  slopes, major same/new slopes, class slopes, `fit_major_departed_slope()`
  which also supplies `AUSPOL_MAJOR_SLOPE`)
- `R/candidate_returns.R` lines ~941, 1064 (returner / defector discounts)
- `R/htv_flow.R:71` (how-to-vote card flow effect)
- `R/state_deviation.R` (state-deviation coefficient), and any other
  "leave-one-pair-out" fit found while fixing these
- `R/xgb_flow_override.R` 101, 239: checked, fixed if reachable in the
  shipped configuration

The live Victorian forecast is unaffected (every other election precedes
vic2026). Only backtest scores, i.e. the ledger, are optimistic.

## The change

One helper, `fit_pairs_for(target_election, pairs)`: under
`AUSPOL_TIME_FORWARD_FITS=1` (the new default) it keeps only pairs whose
election is dated strictly before the target's; `0` restores leave-target-out
for comparison. Every site above calls it. Existing `min_n` fall-backs are left
as they are (a cliff Pete dislikes; replacing them with shrinkage is a
separate change, noted, not bundled into a leak fix).

## Checks (verification, not a gate)

- Each fit prints how many earlier pairs it used; a unit test proves the
  helper drops a later election.
- The published Victorian forecast is byte-identical before and after (every
  pair precedes 2026), proving the fix touches backtests only.
- Rebuild against v44 (0.2881): the new number is the honest ledger and is
  logged whatever it is, per election.
