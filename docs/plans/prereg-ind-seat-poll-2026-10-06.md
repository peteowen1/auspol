# Pre-registration: independents read from their seat polls (2026-10-06)

Written BEFORE the build reported or any arm ran. Scored with `scripts/score_arm.R` (SA2/SA3/SA5/SA6)
plus the targeted check below.

## Why

Pete (2026-10-06): a strong independent is "a candidate polling well as an independent, noted by their
salience and good seat polls", not a random breakout. `docs/reviews/seat-polls-independents-2026-10-06.md`:
the fed2022 YouGov MRP files the independent under OTH (so the poll's IND figure is dropped in Nicholls,
Cowper, Calare, Bradfield, Fowler and wrongly lifts OTH in Goldstein, Mackellar); the blend uses one
class-blind weight (~0.26) fitted on major-party cells, while the best-fitting weight on the large
fed2022 IND gaps is 1.23 (Goldstein 4.4 -> 12.1 after the blend, actual 34.5); Mayo 2016 and Wakehurst
have no primary on disk.

## The arm (all three together, one arm: they act on the same cells)

`AUSPOL_SEAT_POLL_IND_MAP=1` (MRP OTH -> IND remap), `AUSPOL_SEAT_POLL_IND_WEIGHT=1` (IND-specific
time-forward shrunk weight, only with a direct poll and a named independent), plus the hand-keyed
Mayo 2016 and Wakehurst primaries. Start stage: as the build reports (the blend is applied after xgb,
so expected stage 6). Baseline: the shipped configuration (`output/snapshots/20261006-0054-ff0a13d-from1`
for stages 1-5, its stage-6 outputs for comparison).

## Criteria

1. PRIMARY (targeted): squared error of the published seat primaries on IND cells in seats with a
   direct poll (the arm's own footprint) must fall by more than 2 SE AND at least 20% (the 2-SE + 20%
   bar from the by-election prereg, set because few cells pass a 1-SE bar on noise).
2. GUARD (SA6): seat-winner log loss over all 22 elections may not rise by more than 1 SE.
3. GUARD (SA3): the AEF-7 ledger may not rise by more than 1 SE.
4. DISQUALIFIER: fed2025 seat-winner log loss rises by more than 0.005 (the review warns an ungated IND
   weight moves already-good fed2025 rows the wrong way; the gate must hold that).

Ship all three switches only if 1 passes, 2 and 3 hold and 4 does not fire; otherwise off and to Pete.
Named in advance: only fed2022 strongly supports an IND weight; fed2016 (Mayo) and nsw2023 (Wakehurst)
gain only through the new primaries; Victoria 2026 has almost no seat polls today, so the live effect
is near zero until Victorian seats are polled.
