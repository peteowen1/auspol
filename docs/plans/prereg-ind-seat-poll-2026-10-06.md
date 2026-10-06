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

## Result (2026-10-06, `output/snapshots/20261006-1434-e22bdc6-from6`, stage 6, 9.6 min) -- REFUSED, to Pete

| Criterion | Result | Verdict |
|---|---|---|
| 1 PRIMARY (86 IND cells whose blended share moved > 0.5, stage-6 sharedetail) | 4,048 -> 3,091 (-24%), SE 791 (1.2 SE) | FAIL (needs 2 SE) |
| 2 GUARD SA6 (22 elections) | 0.2898 -> 0.2889 (SE 0.0016) | holds |
| 3 GUARD ledger | 0.2809 -> 0.2760 (SE 0.0044) | holds (AEF 0.2825) |
| 4 DISQUALIFIER fed2025 | +0.0058 | FIRES (bar 0.005) |

Per election: fed2022 -0.0178, nsw2023 -0.0150, sa2026 -0.0022; fed2025 +0.0058, fed2019 +0.0088.
Gains: Goldstein 13.5 -> 27.1 (34.5), Wakehurst 14.4 -> 26.3 (35.9), Kooyong 18.4 -> 27.2 (40.5),
Nicholls 8.5 -> 13.9 (25.5); fed2022 IND cells -970. Losses: the OTH -> IND remap fires where the poll's
OTH is not an independent: fed2025 McMahon 9.3 -> 23.5 (9.8), fed2022 Richmond 5.8 -> 16.2 (5.6), Parkes
4.2 -> 13.9 (2.5), Lyne 8.8 -> 16.9 (8.8); fed2025's 55 cells +384. The remap rule (IND blank, OTH >= 10,
an IND candidate standing) is too loose. Switches stay off.

## Amendment 1 (2026-10-06, after the result above; Pete chose it)

The original clauses above are unedited. The remap now fires only where the seat's independent is a
credible contender by pre-election evidence: endorsed by Climate 200 or a Voices group
(`output/endorsement-features.csv`) or the sitting independent member (elected IND at the previous
election in that seat). This drops the false remaps (fed2025 McMahon; fed2022 Richmond, Parkes, Lyne)
and also Nicholls (not endorsed, not sitting), which the first run helped. Same switches, same
criteria, same baseline, run from stage 6. Post hoc: it favours the later answer and is marked so.

### Amendment 1 result (`output/snapshots/20261006-1503-ef0db08-from6`) -- REFUSED, to Pete

PRIMARY 71 IND cells 4,272 -> 2,869 (-33%), SE 742 (1.9 SE): FAIL; SA6 0.2898 -> 0.2888 holds; ledger
0.2809 -> 0.2757 holds; fed2025 +0.0055: DISQUALIFIER FIRES. The credible-contender rule removed the
false remaps (fed2022 cells -1,414: Goldstein 13.5 -> 27.1, Wakehurst 14.4 -> 26.7, Kooyong 18.4 ->
27.2). The fed2025 damage (49 cells +389; McMahon 9.3 -> 24.0 with no remap) comes from the IND-specific
WEIGHT, which the build's dry run already showed hurts fed2025. Switches stay off.

## Decision (2026-10-06): SHIPPED on Pete's override

Pete chose to ship Amendment 1 as is, overriding both near-misses on the record: the primary at 1.9 SE
against 2 SE (-33% on 71 IND cells) and the fed2025 disqualifier (+0.0055 against 0.005, from the
IND-only weight; McMahon 9.3 -> 24.0). In exchange: the 2022 teals and Wakehurst read from their polls
(Goldstein 13.5 -> 27.1, Wakehurst 14.4 -> 26.7, Kooyong 18.4 -> 27.2) and the ledger falls 0.2809 ->
0.2757 (AEF 0.2825). All three switches "1" in `published_flags.R` and as R defaults. Live Victoria
2026: no change (0 seats move > 0.02) until Victorian seats are polled.
