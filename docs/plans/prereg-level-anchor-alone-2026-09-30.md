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

## RESULT (full rebuild ZA, 14:43-15:01, three harness slots)

**Refused: criterion 2 fails.** Pooled log loss per-election mean -0.0001
(SE 0.0100, better in 5 of 16; overall 0.3409 -> 0.3419): a tie. Primary
RMSE 4.1771 -> 4.1811 (worse). AEF-7 ledger 0.2722 -> 0.2730 (guard holds).
Majors' statewide level error unchanged (2.71); nsw2023 Labor 32.7 -> 35.4
(actual 37.0).

Same era split as arm Z: better fed2019 -0.048, vic2018 -0.054, wa2017
-0.110; worse fed2007 +0.031, fed2013 +0.016, fed2016 +0.017, wa2005 +0.023,
wa2008 +0.050, wa2013 +0.037, fed2025 +0.019. So the proportional rescale was
not the cause: the anchor itself helps the older elections (plausibly where
polls were worse) and costs the recent ones. Anchoring stays. Next idea, its
own prereg: an anchor weight that depends on the polls' own track record.
