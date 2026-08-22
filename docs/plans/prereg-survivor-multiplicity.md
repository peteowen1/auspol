# Pre-registration: does the flow matrix need to know how many candidates a class ran?

Written 2026-08-22, **before anything is measured beyond the sizing in "Exposure"
below**. Committed before running.

## First, a correction to what the last two documents predicted

`reviews/wa-three-cornered-2026-08-22.md` and its plan said the fault was likely
that the matrix is "keyed on survivor **set**" and should be keyed on a
**multiset**. Reading `R/flow_matrix.R` rather than the earlier plan's summary
of it shows two things, and the first kills a hypothesis I had already written
down:

1. **The "degenerate rounds" version is refuted.** I expected rounds where only
   one class could receive votes — 100% by construction, measuring nothing — to
   be polluting the pooled fallback. Measured: **22 of 1,658** Western
   Australian rounds, and **zero** in Victoria, South Australia or Queensland.
   Removing them moves every pooled rate by **0.0 points**. And the pooled
   fallback is barely used at all: **97% of exclusion events sit in conditional
   cells** at `min_n = 3`.

2. **A multiset is not representable in the current data.** The survivor key is
   `paste(sort(unique(to)), collapse = "+")`, over party **classes**, and the
   transfers table is already aggregated to `(election, seat, round, from, to)`.
   Two Coalition candidates were summed into one `LNP` row before the matrix
   ever saw them. The count is not lost by the key — it is lost upstream.

**Recording the refutation is the point.** A prediction written before a result
is worth nothing if only its successes are reported.

## What the mechanism actually is

When two candidates of one class survive into a round, that class captures the
sum of two candidates' preference shares. The cell key cannot tell that round
apart from an ordinary contest:

- an ALP exclusion with Liberal and Labor surviving keys as `ALP|ALP+LNP`;
- an ALP exclusion with Liberal, **National** and Labor surviving keys as
  `ALP|ALP+LNP` **as well**.

The second sends far more to `LNP` than the first, for a structural reason that
has nothing to do with how anyone preferences. They share a cell and are
averaged together.

That is the same phenomenon as the three-cornered-seat arm, at a finer grain: a
seat can be three-cornered while the rounds that matter have only one Coalition
candidate left. **That arm scored −0.49 SE**, so the seat-level instrument has
been tried; this asks whether the per-round one does better.

## Exposure, sized before proposing to build anything

The question only matters if same-class contests are common in the jurisdictions
that would be used. **They are, and Victoria's own numbers prove it without any
new data**: `LNP → LNP` is **38.8%** of Victorian Coalition-origin transferred
votes. A Coalition candidate's preferences can only reach another Coalition
candidate if two of them stood in that seat.

So Victoria — the jurisdiction being forecast — carries the phenomenon at
scale. This is *not* an artefact imported from Western Australia, which is what
makes it worth testing at all.

## Gate 1, which must pass before any model change is written

The transfers files do not carry candidate counts, so this needs the Victorian,
South Australian and Queensland fetchers to emit **per-round, per-class
candidate multiplicity**. Before that work is done:

**Measure, from the raw cached sources, the share of exclusion rounds in
VIC + SA + QLD where any surviving class ran more than one candidate.**

- **If under 10% of rounds, STOP.** Following `stats-discipline`: removing an
  error component of spread `s` from total spread `σ` buys roughly `s²/2σ²`, so
  a mechanism touching under a tenth of the evidence cannot move the criterion
  enough to justify a three-fetcher data change. It would be recorded as a
  correctness matter and left.
- **At or above 10%, proceed**, and report the figure with the result either
  way.

Gate 1 is a measurement, not an experiment: it has no arms and cannot be
gamed by its own outcome. **The 10% threshold is fixed now.**

## What changes if Gate 1 passes

The cell key gains the multiplicity of each surviving class, so
`ALP|ALP1+LNP1` and `ALP|ALP1+LNP2` become different cells. `min_n = 3` is
unchanged, so thinner cells fall back exactly as they do today.

## What is measured

**Per-seat log score, leave-one-election-out, clustered on the election** — the
same criterion as every arm before it.

**Scored on Victoria, South Australia and Queensland ONLY. Western Australia is
excluded entirely from every arm.** That is deliberate and is the whole reason
this test is worth running: nothing in it can be confounded by the three
refused WA arms, and a positive result would be about the matrix rather than
about one state.

## Decision rule, fixed now

- **Adopt if the clustered difference exceeds 2 SE.** This is a NEW question
  rather than a fourth cut of the Western Australian data, so the 2.5 SE
  multiplicity bar from `prereg-wa-three-cornered.md` does not apply and 2 SE
  is the standing bar.
- **Between 0 and 2 SE: do not adopt, and report.** No "adopt anyway" clause.
  Unlike the Queensland flows decision, this is a **model change**, not a
  data-coverage change — there is no "more evidence beats less" argument to
  lean on, because the same evidence is being re-cut into more cells.
- **Negative: refuse**, and record that the survivor-conditioning line of
  enquiry is closed, since this is its finest available instrument.

## Refusals

- **M1 — the control.** Forcing every multiplicity to 1 must reproduce the
  current forecast **byte-for-byte**. If it does not, the key change is doing
  something besides splitting cells.
- **M2 — cell thinning.** Splitting cells necessarily reduces the events behind
  each. **Report the number of cells at `n >= 3` and the share of exclusion
  events they cover, before and after.** If the share of events in used cells
  falls below **90%** (it is 97% today), stop and report: a matrix that
  answers more precisely but falls back to the pooled rate far more often is
  not obviously better, and the log score alone will not show which happened.
- **M3 — the live forecast.** If any party's Victoria 2026 median moves by more
  than 2 seats, stop and report rather than ship.
- **M4 — no Western Australian data in any arm**, including as a tie-breaker
  or a robustness check. If WA appears anywhere, the result is confounded with
  three already-refused experiments.
- **M5 — the directional side effect.** If the change raises One Nation's
  Victorian win probability in more than **80% of seats** while the score gain
  is under 2 SE, stop and report. Named in advance because it is the exact
  shape that disqualified the One Nation seat-uncertainty change on 2026-08-19,
  and because One Nation is the party this repo has the most incentive to move.

## What this cannot see

- **Whether the remaining gap is survivor structure at all.** Two hypotheses of
  that family have now been refuted or fallen short. A third failure should be
  read as evidence the residual is something else, not as a reason for a fourth
  cut of the same idea.
- **Anything about the ORDER of exclusions**, which the matrix ignores entirely
  and which this does not address.
- **Anything about the One Nation allocation**, still fitted on one election.
