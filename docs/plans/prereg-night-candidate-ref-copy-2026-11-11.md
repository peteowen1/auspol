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
