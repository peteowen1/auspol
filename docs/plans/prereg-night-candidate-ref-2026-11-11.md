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
