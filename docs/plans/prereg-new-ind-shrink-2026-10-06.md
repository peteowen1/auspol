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
