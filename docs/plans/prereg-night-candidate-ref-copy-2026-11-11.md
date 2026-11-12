# Pre-registration: night booth reference by candidate, COPY version (2026-11-11)

Written before any run of this arm. Pete's choice, 11 Nov, after `plans/prereg-night-candidate-ref-2026-11-11.md`
FAILED: "Build copy version", with the warning put to him in the question that the design was chosen AFTER seeing
that run's per-seat results.

## What changes

`night_booth_update(cand_ref = "copy")`: a candidate who stood in the same seat at the previous election under a
DIFFERENT class keeps those votes under the old class (the party's history stays: Monash's new Liberal is projected
from the Liberal booth pattern) AND has them added under their current class (their own pattern: Mirani's Andrew).
A balancing row keeps every unit's reference total unchanged. Off is byte-identical; "move" is the failed version.

## Honesty about the evidence

All 29 targets were seen in the move run, and this design answers its failure (Monash). A pass here is therefore
weak evidence: it says the copy version does not do the damage the move version did, not that it generalises. The
first clean test is the next real night with a party-switcher (whether vic2026 has any is UNCHECKED: the live VEC
table carries no candidate names yet). Whatever happens here is reported with that caveat, and a pass does not by itself ship it to the live night.

## Runs

Same replays as the move run, same seeds: simulated (1,000 sims) fed2022, fed2025, nsw2023, qld2024, sa2026, wa2025,
vic2022; real nights fed2022 and fed2025 (20,000 sims, live pair_cal). Base arms are reused from
`deciding-runs/20261111-night-cand-ref/` only if a fresh base run on the new code is byte-identical (qld2024 simulated
and vic2022 simulated, checked in the job before anything else; otherwise every base reruns).

## Decision rule (the move run's, unchanged)

- Primary: target-seat night-average seat-winner log loss, copy minus base, simulated and real; both must fall.
- Guard: no election's all-seat average worse by more than 0.002.
- Known answers, stated now: Mirani qld2024 LNP above base at fraction 0.5 (the move run's fraction-1 answer could not
  move; this is the fraction where the mechanism acts); Monash fed2025 not worse than base by more than 0.01 (the
  failure this version exists to avoid).
- Unacceptable: any seat summing above 1; vic2022 not byte-identical.
- Outcome: PASS means "kept as an option for the live night, Pete decides"; it does NOT become the live default from
  these replays alone (see Honesty above). FAIL closes it.

## RESULT (11 Nov 2026, 6:02pm): PASS, kept as an option (off); Pete decides on the live night

Run: `deciding-runs/20261111-night-cand-ref-copy/` (code f5f28acf). Base reused from `20261111-night-cand-ref/` after
the off path on the new code reproduced it exactly (qld2024 and vic2022 simulated, 7 of 7 files each).

Night-average seat-winner log loss, copy minus base (lower is better):

| election | targets | all seats (sim) | targets (sim) | all seats (real) | targets (real) |
|---|---|---|---|---|---|
| fed2022 | 4 | +0.0000 | +0.0001 | -0.0000 | -0.0004 |
| fed2025 | 8 | -0.0013 | -0.0246 | -0.0001 | -0.0023 |
| nsw2023 | 7 | +0.0005 | +0.0023 | | |
| qld2024 | 2 | -0.0083 | -0.3845 | | |
| sa2026 | 4 | -0.0001 | -0.0010 | | |
| wa2025 | 4 | +0.0000 | +0.0006 | | |
| vic2022 | 0 | 0 (identical) | | | |

PRIMARY: simulated -0.0328 (SE 0.0272, 29 targets); real -0.0017 (SE 0.0016, 12 targets). No election worse by more
than 0.002 (worst nsw2023 +0.0005, Kiama +0.015). Mirani LNP at half count 0.509 -> 0.596 (holds). Monash simulated
-0.198 (holds; the move version was +1.99). No seat above 1. **PASS.**

Read with: both primary falls are about 1 SE; the gain is Mirani and Monash, everything else within +-0.02. The design
was chosen after the move run, on the same 29 seats, so this says the copy version avoids the move version's damage
and helps the two seats it was aimed at; it is not out-of-sample evidence. Mirani is still called wrong at full count.
Live use needs candidate names in the night booth table (the VEC website pages carry them; `scripts/vec_web_booths.R`).

### Amendment 1 (2026-11-12, AFTER the result; the original clauses above are left as written)

The vic2022 replays and this prereg's scorer joined the 2018 booth table to 2022 by exact district name, and
`output/booths-vic2018.csv` spells 25 of 87 districts its own way ("South Westcoast", "Albertpark"). That hid vic2022's
two class-switchers (Marilyn Nuske, Bendigo West, OTH -> IND; Jim Doukas, South-West Coast, OTH_RIGHT -> IND), so the
"vic2022 byte-identical" clause rested on the bug, not on vic2022 having no targets. Fixed 264cc306 (replays) and
5963c174 (scorer); rerun `deciding-runs/20261112-vic2022-names/results-cand-ref.txt`:

- Simulated primary, 30 target seats: -0.03170 (SE 0.02628); real nights unchanged, -0.00169 (SE 0.00161).
- vic2022 night-average seat-winner log loss: -0.00057 (better); largest win-probability move 0.050.
- Every other clause passes; "vic2022 identical" is FALSE, so the scorer prints FAIL.

Pete, 12 Nov: keep `cand_ref = "copy"` ON for 28 Nov; the identical clause is void (its premise was the naming bug).
