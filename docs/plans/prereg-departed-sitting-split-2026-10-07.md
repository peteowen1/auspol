# Pre-registration: departed-independent rate split by whether the leader was the sitting member

Written 2026-10-07, before the arm is built or run. Pete chose this over a
time-forward pooled rate (quiz, 2026-10-07). Evidence and the leak it fixes:
`docs/reviews/departed-rate-provenance-2026-10-07.md`.

**Disclosed: the split was formed AFTER seeing retention by group** on the same
cells this arm is scored on (sitting 0.38 on 12, not sitting 0.63 on 66). The
arm is therefore not a blind test of the split. What keeps it honest is that
each target's rates use only EARLIER elections, so no cell's own outcome sets
its own rate, and the criteria below are fixed now.

## The rule

`AUSPOL_DEPARTED_SUCCESSOR = "sitting"` (same plumbing as the successor flag,
second value; default stays `"0"`):

- Population: `output/departed-ind-successors.csv` (IND class leader >= 10% at
  the previous election, did not stand in the seat again, an IND stands now),
  excluding cells where an IND candidate is a sitting or former MP (defector
  machinery), as in the successor prereg.
- Group: `sitting` if the departed leader was elected at the previous election,
  else `not_sitting`. Cells whose departed leader has no elected flag (vic2010)
  are left out and keep today's behaviour.
- Rate per target T: ratio of means over the group's cells with polling day
  strictly before T's, partial-pooled toward the time-forward pooled rate exactly
  as `scripts/fit_departed_successor_rates.R` does (same shrinkage formula, SE
  clustered on election). Targets with no earlier cell take no per-seat rate:
  they keep today's behaviour and are reported separately.
- Held through renormalisation (`renorm_hold()`), so the measured rate is the
  rate that reaches the forecast. A screen-permitted successor keeps the 1.0 path.
- Measured post-xgb (`AUSPOL_XGB_BASE_DELTA=1`), switch zeroed in rebuild stage 1.

## Criterion, in order

Screen with `scripts/quick_arm.R` on the pairs holding cells; the deciding run
is the full 20,000-sim arm.

1. **Primary, targeted:** mean absolute error of the IND share on the arm's
   cells, before vs after, must fall by more than 1 SE clustered on pair.
2. The other cells of those rows must not worsen by as much.
3. **Do-no-harm:** pooled seat log loss and actual-weighted primary RMSE, each
   not worse by more than 1 SE (cluster = pair).
4. Byte-identical in every row without an arm cell (quick_arm's max-difference check).

## What would make a win unacceptable

- IND win probability falling on net in arm cells where an independent won
  (the disqualifier that refused both hold arms).
- More than half the primary gain from two seats.
- The gain coming only from the `not_sitting` group's rate RISING toward its
  unheld ~0.6, i.e. the arm reproducing today's accidental effective rate and
  nothing more. Report both groups' rates and the per-group error change.

## Decision rule

1-4 pass and no disqualifier fires: ship (`published_flags.R`,
`docs/MODEL-REGISTRY.md`, same commit). Otherwise off, case table to Pete.

## Amendments

None. Later amendments go below this line; the text above stays unedited.
