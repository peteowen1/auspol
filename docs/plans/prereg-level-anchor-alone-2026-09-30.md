# Pre-registration: the fundamentals anchor alone (`AUSPOL_LEVEL_RECIPE=unanchored`)

Written 2026-09-30 14:40, before the rebuild. Follows arm Z
(`prereg-level-recipe-retest-2026-09-30.md`): "live" dropped the anchor AND
rescaled the trend endpoints to 100, won RMSE (4.19 -> 4.17) and the ledger
(0.2726 -> 0.2672) but lost pooled log loss (+0.0003 per election), better in
recent elections and worse in early ones. The two changes could not be told
apart.

## The change

`unanchored`: the statewide level is the poll trend, NOT pulled to the
trend/fundamentals projection; the unfitted remainder goes to OTH exactly as
in the published recipe (no proportional rescale). Everything else as
published (v53).

## Decision rule (against v53 = output/rebuild-V53, FULL rebuild: the level
feeds stage-1 base_pred and level_pred)

1. **Primary: pooled seat log loss** (CR2 per-election mean) improves.
2. **And primary RMSE** (all rows) improves.
3. Guard: AEF-7 ledger not worse by more than 0.003.
4. Reported: per election; early (<= 2013) vs later; statewide level error
   for the majors; nsw2023 Labor level.

Same rule as arm Z, so the two are comparable: if this passes where Z failed,
the rescale was the harm; if it fails the same way, the anchor itself helps
early elections.
