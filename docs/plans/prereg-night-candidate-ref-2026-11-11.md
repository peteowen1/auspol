# Pre-registration: night booth reference by CANDIDATE, not class (2026-11-11)

Written before any code or run. Pete's choice 11 Nov ("By candidate"; "test it both ways").

## What changes

`night_booth_update()` projects each class's uncounted votes in a seat (later booths, postal, absent) from that
class's share of the same unit at the previous election, moved by the swing on the counted units. A candidate who
stood in the SAME seat last time under a DIFFERENT class loses their own history: Mirani 2024, Stephen Andrew was
One Nation in 2020 and KAP (OTH_RIGHT) in 2024, so OTH_RIGHT's reference was the UAP's ~1% and Andrew's lower
postal share was never carried. The arm (`cand_ref = TRUE`) re-labels a returning candidate's previous-election
booth votes with their CURRENT class before the reference is aggregated (names matched within the seat, letters
only, case-folded). A class whose previous holder left it keeps the rest of its reference, possibly none.
Nothing else changes; off is byte-identical to today.

Targets (same seat, previous election, different class; booth tables `output/booths-<pair>.csv`): 29 candidates.
fed2022 4 (Hughes Kelly, Eden-Monaro Holgate, Hunter Bonds, Lalor Moinuddin), fed2025 8 (incl. Monash Broadbent,
Calare Gee, Moore Goodenough), nsw2023 7 (Barwon Butler, Murray Dalton, Orange Donato, Kiama Ward, ...), qld2024 2
(Mirani Andrew, Burnett Hudson), sa2026 4, wa2025 4, vic2022 0.

## Runs (both ways, same seeds)

1. Simulated replays (`scripts/night_replay_json.R`, 1,000 sims, fractions 0, 0.05, 0.1, 0.25, 0.5, 0.75, 1, gap_k 5,
   2CP on where a 2CP file exists, standard-name 2CP files for qld/sa) on fed2022, fed2025, nsw2023, qld2024, sa2026,
   wa2025, from states dumped by `quick_arm.R AUSPOL_NIGHT_DUMP`. vic2022 has no target and is the byte-identity check.
2. Real-night replays (`night_replay_feed.R` fed2022, fed2025; `night_replay_vec.R` vic2022) at 20,000 sims, live
   defaults (pair_cal on).

## Metric and decision rule

- Primary (the change is targeted, so the targets decide): seat-winner log loss on the TARGET seats, averaged over
  fractions >= 0.05 (simulated) and over counted times (real), seats weighted equally, arm minus base. Lower is better.
- Guard (do no harm): on every election, all-seat night-average log loss not worse by more than 0.002; the
  non-target seats on each election must be unchanged to within 1e-9 unless a target shares a pooled vote-type gap
  with them (`.night_type_gap` pools by class; reported, not decisive).
- Ship (live night default) if the primary falls AND no election's guard fails.
- Known answer, stated now: Mirani 2024 at fraction 1, LNP above base. If not, the arm is broken.
- Unacceptable even if it passes: any seat's probabilities summing above 1; vic2022 not byte-identical.
- Reported, not decisive: Monash fed2025 (Broadbent) at each time; per-target table.
- Noise: 29 targets; SE clustered on seat. A primary fall inside 1 SE is reported as such.

## Amendment (11 Nov, before any run; original text above unedited)

The live VEC booth table (`night_booth_table()`) carries no candidate names, so `cand_ref` cannot run on the vic2022
real-night replay (it stops with NX15). vic2022 has 0 targets, so nothing is lost for the test: the real-night
replays are fed2022 and fed2025 only, and vic2022 stays the byte-identity check on the simulated replay. Shipping to
the live vic2026 night would first need candidate names in `night_booth_table()` (the VEC feed has them).

## RESULT (11 Nov 2026): FAIL, `cand_ref` stays off

Run: `deciding-runs/20261111-night-cand-ref/` (code 7f921437; scored by `scripts/score_night_cand_ref.R`). Relabelled
per election, as the replays printed: fed2022 4, fed2025 8, nsw2023 7, qld2024 2, sa2026 4, wa2025 4, vic2022 0.

Simulated replays (1,000 sims, fractions 0.05 to 1), night-average seat-winner log loss, cand_ref minus base (lower
is better):

| election | seats | targets | all seats | targets | largest non-target change |
|---|---|---|---|---|---|
| fed2022 | 151 | 4 | +0.0000 | +0.0003 | 0.0003 |
| fed2025 | 150 | 8 | **+0.0130** | +0.2437 | 0.0016 |
| nsw2023 | 93 | 7 | +0.0004 | +0.0004 | 0.0344 |
| qld2024 | 93 | 2 | -0.0070 | -0.3255 | 0 |
| sa2026 | 47 | 4 | -0.0004 | -0.0042 | 0 |
| wa2025 | 59 | 4 | -0.0008 | -0.0123 | 0.0031 |
| vic2022 | 88 | 0 | 0 | none | 0 (byte-identical, as required) |

PRIMARY simulated (29 targets): +0.0426 (SE 0.0730). REAL-NIGHT: +0.2429 (SE 0.2434, 12 targets; fed2022 all seats +0.0000, fed2025 all seats +0.0194, both 20,000 sims at the live
pair_cal). Monash again carries it: +2.92 (base 4.55 already at the floor much of the night); Moore -0.005, Calare -0.001.

Clauses: primary falls FALSE; no election worse by > 0.002 FALSE (fed2025 +0.0130); Mirani known answer FAILS as
written (LNP at fraction 1: 0.006 both ways); no seat above 1 TRUE; vic2022 identical TRUE. **FAIL.**

Read with:
- Monash fed2025 (+1.99) carries the failure. Relabelling Broadbent's 2022 Liberal votes as his new independent class
  leaves the Liberal class with no reference of its own, so the new Liberal candidate is projected from almost
  nothing: at 5% counted, Liberal first preferences 11.2 with the switch against 31.7 without (actual 31.8). Base
  already called Monash wrong (Liberal 0.024 at 5%); the switch pushed it to the floor. By full count both agree.
- Helped: Mirani -0.65, Kalgoorlie -0.05, Moore -0.04, MacKillop -0.02.
- The Mirani known answer was set at fraction 1, where the switch cannot act any more (every unit counted on the
  standard-name 2CP file); it moves at half count (LNP 0.509 -> 0.578 in the 11 Nov smoke test). The arm runs; the
  known answer was the wrong one to register. Recorded, not used to pass anything.
- Lesson for any next version: COPY, not move. The old class keeps its reference and the returning candidate brings
  their own pattern as well. That design is chosen after seeing these results, so it needs its own prereg and a
  held-out test (all 29 targets here are now seen); not built.
