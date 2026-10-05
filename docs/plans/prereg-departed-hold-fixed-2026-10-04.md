# Pre-registration: hold a departed leader's decayed cell fixed through renormalisation

Written 2026-10-04 before any harness run under the new switch. Pete chose this
design ("1") over refitting a lower rate, after the walk below. No new constant
is fitted: the rate stays the measured 0.38.

## The claim

`AUSPOL_HONOUR_DEPARTED` (shipped on) multiplies a departed leader's class base
by `departed_rate` (IND 0.38) BEFORE the seat row is renormalised to 100. That
rate was measured on FINAL vote shares (`reviews/departed-leader-retention-
2026-09-15.md:30`, `mean(now %) / mean(prev %)`, 305 cases, 46.7 -> 17.8). The
row then sums to far less than 100 and the renormalisation scales every cell
back up, including the decayed independent, so the retention that actually
reaches the forecast is about 0.6-0.7, not 0.38.

Walk, `scratchpad/walk_run.log`, fed2013 harness at `AUSPOL_XGB_PRIMARY=0`,
points of vote share:

| seat | IND prior | IND after slope | row total | IND after renorm | effective retention | actual IND |
|---|--:|--:|--:|--:|--:|--:|
| New England | 52.0 | 21.1 | 58.8 | 35.9 | 0.69 | 20.4 |
| Lyne | 39.8 | 16.5 | 68.5 | 24.0 | 0.60 | 7.6 |

## The rule

After the slope step and before the final `100 * shares / rowSums(shares)`,
every (seat, class) cell where the departed-leader decay fired is HELD at its
decayed value. The remaining cells in that row are scaled by one common factor
so the row sums to 100. If the other cells sum to zero, or the held cell alone
is at or above 100, the row is left as the old code would leave it and the seat
is named in the log.

"Fired" means exactly `departed` in `screened_slopes()` (`R/dev_slope.R:348`):
`honour_departed & !prior_leader_returns & !permitted`. `screened_slopes()`
gets an attribute marking those seats; nothing else about its return changes.
A permitted successor (Wentworth 2022, Goldstein) is therefore NOT held and
must be byte-identical to today.

Switch `AUSPOL_DEPARTED_HOLD`, default `"0"`. One arm, `"1"`.

## Named cases, chosen before running

Targets (the cells the change is for): every (pair, seat, class) where the
decay fires, in every harness. Flagships, expected to improve by arithmetic
(held value = 0.38 x prior, before the other classes absorb it):

| seat | held IND | old IND | actual IND |
|---|--:|--:|--:|
| New England fed2013 | 19.8 | 35.9 | 20.4 |
| Lyne fed2013 | 15.1 | 24.0 | 7.6 |
| Churchlands wa2013 | 25.6 | ~31 | 16.3 |

Churchlands is in `backtest_candidate_wa.R`, which does not call
`screened_slopes()` (verified 2026-10-04 by grep: no call site in that file), so
it is NOT touched by this change. Stated here so the gap is a decision and not
a silent omission. Morwell vic2022 is the Victorian flagship.

Known loser, named so it cannot be a surprise: Indi fed2019 (McGowan's endorsed
successor Haines took 32.4 against our 23.1). If the decay fires there, holding
makes the independent cell smaller and Haines worse. The rule cannot see an
endorsed successor.

## Criterion, in order

1. **Primary, targeted.** Mean absolute primary error on the held cell, over
   every target (pair, seat, class), `AUSPOL_XGB_PRIMARY=0` (base_pred only),
   before vs after. Must fall by more than one SE, clustered by pair (seats in
   one pair share swing, so the pair is the independent unit).
2. **Same cases, the other cells.** Mean absolute error summed over ALL cells of
   the target rows must also fall. The released vote now lands on the other
   classes; if the held cell improves and the rest worsen by as much, it was
   only moved.
3. **Do-no-harm.** Pooled seat log loss over all pairs scored by the five wired
   harnesses must not rise by more than one SE (cluster = pair). Primary RMSE
   weighted by actual share, pooled, likewise.
4. **Byte-identical where it should be.** Every row where the decay did not fire
   must be identical to the old output (0 cells differ). Checked cell by cell.
5. **Secondary.** Seat log loss on target seats; win probability of the
   departed class in seats it was held.

## What would make an apparent win unacceptable

- The gain coming from New England / Lyne alone with the other targets flat or
  worse. Report the per-case table, not just the mean.
- Criterion 1 passing and criterion 2 failing (vote moved, not fixed).
- Independent win probability falling in seats where an independent genuinely
  won (new-candidate winners, Haines-shaped). Count those seats before and after;
  a net fall is disqualifying.
- Any change in a row where the decay did not fire (criterion 4).
- A gain at `AUSPOL_XGB_PRIMARY=0` that disappears or reverses once the xgb layer
  is retrained on the new `base_pred`: the trained model learned to correct the
  old over-called independent, so it may double-correct. The retrained arm is
  part of the test, not a follow-up.

## What the criteria cannot see

- Endorsed-successor seats (the data has no endorsement field).
- Which major the freed vote should go to: the scaling is proportional, so the
  rule does not choose, which the data gave no support for.
- Whether 0.38 is itself right per class: only IND has a fitted departed rate.

## Reach

- `scripts/fit_seats_full.R` (published, Victoria) reads `screened_slopes()` at
  line ~1048 and normalises at ~1126; wired in the same change. A base_pred fix
  reaches the published number through `xgb_primary_predict_live()`'s
  `base_margin` on the next run, with no retrain (CLAUDE.md "Two XGB-primary
  override paths").
- Backtests at `AUSPOL_XGB_PRIMARY=1` read a STATIC cached pool and will not
  see the change until the 4-step retrain (`reviews/xgb-primary-circularity-
  2026-09-13.md`). The retrained arm is run before any decision.
- Five harnesses wired: fed, nsw, qld, sa, vic. WA not wired (no `screened_slopes()`
  call); the commit says so.

## Decision rule

Criteria 1-4 pass AND no named disqualifier fires AND the retrained arm keeps
the gain: ship (`published_flags.R` and `docs/MODEL-REGISTRY.md` in the same
commit). Anything else: the switch stays off, the case table goes to Pete. A
refusal on a favourable headline mean goes to Pete, not to me.

## Amendments

None. Any later amendment is added below this line with the original text
above left unedited.

### Amendment 1, 2026-10-05, written AFTER the arm-A sweep and labelled as post hoc

Arm A (hold every class where the decay fires) was swept over 16 pairs
(`reviews/departed-hold-sweep-2026-10-05.md`). Clause 1 passed; clause 3b
(weighted RMSE +1.4 SE) and the independent-win-probability disqualifier failed, so by
the rule above arm A stays off. Pete asked why and whether it can be improved.

What the sweep showed: 2,872 held cells, of which 101 (3.5%) are classes with a prior seat
share of 15% or more, the population the 0.38 was measured on
(`reviews/departed-leader-retention-2026-09-15.md`, "polled 15% or more at the previous
election"). On those 101 cells the hold improved the error (5.74 -> 5.31) and the weighted
squared error (-478). Almost all of the damage is in classes under 15% (Kennedy fed2013
OTH_RIGHT alone is +8,882 of the +15,050 total).

**Arm B** (declared now, NOT before the sweep): `AUSPOL_DEPARTED_HOLD=1` with
`AUSPOL_DEPARTED_HOLD_MIN_PRIOR=15`, holding a cell only where the class's prior seat share
(`mat`, the row-normalised prior matrix) is at least 15. The 15 comes from the retention
review's population, not from tuning on the sweep. Everything else is as above: the same
clauses, the same disqualifiers, the same decision rule.

Limits, stated so they cannot be hidden later: arm B was chosen after seeing arm A's
per-cell results on these same 16 pairs, so passing clauses 3b and the win-probability test
is partly by construction. It is an EXPLORATORY result, not a confirmation. Independent
support is the 305-case retention measurement, not the sweep. The retrained-xgb arm and the
20,000-simulation deciding run remain required before any ship. `mat` is row-normalised, so
a cell near 15 can sit on the other side of the line from the raw candidacy sum.
