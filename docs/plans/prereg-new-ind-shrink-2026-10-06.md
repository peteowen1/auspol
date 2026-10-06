# Pre-registration: unknown new independents shrunk (2026-10-06)

Written BEFORE the arm ran. From docs/reviews/vic-ind-overcall-2026-10-06.md: a sole independent with no
earlier vote anywhere in the region is over-called in Victoria by +3.16 points per cell (SE 0.31, n=75).
`AUSPOL_NEW_IND_SHRINK=1` multiplies their base share by a time-forward factor (sum actual / sum base over
earlier elections' cells), partially pooled across jurisdictions, bounded to [0,1]. Post-xgb like the
re-entry carry: stage 1 off, stage 6 re-predicts changed cells through the frozen as-at trees. Dry run:
factor 1.000 on 18 of 22 targets; vic2018 0.964, vic2022 0.737 (26 cells, base-level squared error
558 -> 461); fed2007 0.970, wa2025 0.990.

Arm: `AUSPOL_NEW_IND_SHRINK=1`, stage 6 at shipped settings otherwise, all harnesses; baseline the shipped
snapshot `output/snapshots/20261006-2141-1c3f440-from6`.

1. PRIMARY (targeted): published-share squared error on the changed cells falls by more than 2 SE.
2. GUARD: 22-election seat-winner log loss (SA6) rises by no more than 1 SE.
3. GUARD: AEF-7 ledger rises by no more than 1 SE.
4. DISQUALIFIER: vic2022 or vic2018 seat-winner log loss rises by more than 0.005.

Ship if 1 passes, 2 and 3 hold and 4 does not fire; otherwise off and to Pete. Named in advance: the
cell definition excludes a class prior of 10 or more (a boundary taken from the review, not fitted);
the effect is expected to be small outside Victoria by construction.

## Result, capped arm (`output/snapshots/20261006-2344-0a54b75-from6`): PASSES

Changed independent cells 51 (fed2007, vic2018, vic2022, wa2025): squared error 1,200 -> 1,035 (-166, SE 41,
cells as units): PASS. SA6 22 elections -0.0000: holds. Ledger 0.2742 -> 0.2741: holds. vic2022 -0.0004,
vic2018 +0.0003: disqualifier does not fire.

## Amendment 1 (2026-10-06, after the result above; Pete's challenge) -- the uncapped version

The clauses above are unedited. Pete asked why the fix is Victoria-only and whether that overfits. It is not
coded Victoria-only: the factor is fitted for every jurisdiction, but bounded to [0, 1], so where earlier
elections UNDER-called these candidates (federal, NSW: k ~1.5) the bound holds the factor at 1 and the half
of the fix that would raise them is silently dropped. Arm: `AUSPOL_NEW_IND_SHRINK=1`,
`AUSPOL_NEW_IND_SHRINK_CAP=0`, same baseline and the same four criteria, measured on the cells the uncapped
version changes. Decision rule: if the uncapped arm passes all four, it ships (it is the stronger version);
if it fails where the capped one passed, the capped one ships and the failure is reported to Pete with the
cells that drove it. Post hoc: chosen after seeing the capped result, and marked so.
