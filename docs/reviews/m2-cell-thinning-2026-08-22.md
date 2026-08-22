# Refusal M2 fires: the split costs more coverage than it is allowed to

Against `docs/plans/prereg-survivor-multiplicity.md`. **Stopped before any arm
was scored**, which is the cheapest place a refusal can fire.

## The number

Conditioning each cell on how many candidates of a class survived:

| | cells observed | cells at n ≥ 3 | exclusion events in usable cells |
|---|---:|---:|---:|
| current key (class set) | 115 | 78 | **1,444 of 1,496 (97%)** |
| with multiplicity | 265 | 102 | **1,283 of 1,496 (86%)** |

Refusal M2, fixed before the measurement: *"If the share of events in used cells
falls below 90% (it is 97% today), stop and report."*

**86% < 90%. M2 fires.**

## Why this is a refusal and not a detail

Splitting cells is not free. The multiplicity key more than doubles the cell
count, 115 → 265, and while more cells clear `min_n` in absolute terms (78 →
102), the split ones scatter the evidence: **161 more exclusion events now fall
below the threshold and are answered by the pooled rate instead.**

So the change makes the matrix more precise where it still has data and *less*
informed everywhere else, and a single log score cannot tell those two effects
apart. That is exactly why M2 was written as a coverage floor rather than left
to the criterion — and it is the reason to stop rather than to score and hope
the number comes out positive.

## What was NOT done, deliberately

`min_n = 3` could be lowered to 2, which would recover most of the coverage.
**That is not done here.** `min_n` is a pre-registered constant with its own
history, and changing it *after* seeing that it blocks a result is precisely the
rationalisation pattern `CLAUDE.md` records twice. If a lower floor is worth
having, it is worth pre-registering on its own terms — including what it costs
in cells built from two seats — and not as a rescue.

Nor was the arm scored anyway "just to see". A pre-registration that yields when
the answer is still unknown is not a pre-registration.

## What survives, and it is worth keeping

The exposure finding from Gate 1 stands and is not affected by this refusal:
**44.5% of Victorian exclusion rounds have a class fielding more than one
candidate**, and it is dominated by the catch-all buckets — `OTH_RIGHT` (133
rounds), `OTH` (67), `IND` (47), then `LNP` (34).

That is a real property of our own classification scheme, in the jurisdiction
being forecast, in the published model today. **M2 says this particular remedy
costs too much coverage; it does not say the problem is imaginary.**

The plausible remedies now look different from a finer cell key:

- **narrow the buckets** so `OTH_RIGHT` is not one class doing the work of six,
  which addresses the cause rather than conditioning around it;
- **weight by candidate count** inside the existing cell instead of splitting
  it, which costs no coverage at all.

Both are different experiments needing their own plans. Neither is implied by
anything measured here.

## What was kept in the code

The three fetchers now emit `to_n`, the per-round per-class candidate count, and
`build_flow_matrix()` gained a `multiplicity` argument defaulting to `FALSE`.

**Nothing published changes.** Verified:

- the flow matrix is unchanged — 1,496 exclusions, 78 cells at n ≥ 3 of 115
  observed, and every pooled rate matches to the decimal (`ALP → LNP` 30.8,
  `LNP → LNP` 16.3, Victoria's own 38.8);
- `seat-shares-vic-2026.csv` is byte-identical;
- the run is deterministic on repeat.

Keeping the column costs nothing and means the next plan in this area does not
have to redo three parsers to ask its question.

## One thing I could not attribute, stated rather than glossed

`output/seat-probs-vic-2026.csv` changed on this run. It is **not** the column:
the flow matrix is unchanged, `tx` is used nowhere else in
`scripts/fit_seats_full.R`, `seat-shares` is byte-identical, and the run
reproduces itself exactly. `output/` is gitignored, so no previous copy survives
to diff against, and I cannot say what the old file corresponded to.

The likeliest reading is that the published artefact had drifted behind the
code — the published-vs-deployed hazard `C:\dev\CLAUDE.md` records — and this
run refreshed it. **Stated as an open question rather than assumed benign**,
because "probably stale" is exactly the sort of thing that turns out not to be.
