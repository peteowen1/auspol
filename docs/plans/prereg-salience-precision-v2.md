# Pre-registration: the salience gate's precision criterion, re-specified

2026-09-04, written before this criterion is scored decisively against
anything beyond the dry-run cases named below. Replaces C2 of
`prereg-salience-emergence-gate.md`, per ticket C1 of
`plan-candidate-level-model.md`. Nothing else in that document changes: the
gate (prior party share < 15%), the model (`pcv ~ base + log1p(max(jump,0))`,
fitted on fed2022 gated rows), C1 and C3, and every refusal clause stand as
written.

## What was wrong with the old C2, restated plainly

`docs/reviews/salience-gate-2026-08-27.md` diagnosed it: the gate is a
**continuous** coefficient on `log1p(jump)`, not a binary trigger, so "the
gate fires" needed an arbitrary threshold to count against — `median(x[x>0])`
in the training data, chosen for no reason connected to the question being
asked. The false-positive count that failed C2 (73 non-emergent "false
positives" against 6 true emergences) was a property of where that threshold
sat, not of the model. Fourteen of those "false positives" polled 15–26%
against a base prediction of 6.9 — exactly the behaviour the gate is supposed
to produce, scored as a mistake.

**This document scores the gate in the units it actually predicts: vote
share.** No threshold anywhere in either criterion below.

## Criterion 1 (primary) — does the gate damage ordinary gated candidates?

**On fed2025's gated subset, RMSE(gated model) must not worsen against
RMSE(base) by more than 0.37 points.**

fed2025 carries **zero** true emergences (confirmed: `sum(emerg)` on the gated
subset is 0), so every one of its 331 gated rows is by construction a case the
gate should either help or leave alone — never a case it should be rewarded
for moving toward. This is the same logic the old C1 used, but scoped to the
**gated subset specifically** rather than pooled across all 388 rows. Pooling
is the loophole a "fires on everyone" failure mode could hide behind: gated
rows are under a third of the corpus, so damage concentrated there could pass
a pooled RMSE test comfortably while still being real.

**Sized from this data, not chosen off a scale.** Clustered on seat (141
seats among the 331 gated rows, matching the convention the old C1 used): the
by-seat mean-error-difference has sd 1.559, giving a clustered SE of **0.1313**
and an MDE at 2.80× that of **0.368**, rounded to 0.37.

**Observed, reported here because it was already computed while sizing the
bar and should not be re-discovered as if fresh**: gated RMSE moves
**base 4.147 → gated 3.738, a −0.410 point IMPROVEMENT** — comfortably past
the bar in the favourable direction. Gated MAE is flat (+0.050, well inside
noise). This is disclosed now, before the criterion is run decisively, per
the same rule that governs every other bar in this repo: a criterion sized
after seeing the number it needs to clear is not a criterion.

## Criterion 2 (secondary, reported not decisive) — does it move people the right way?

**Among gated fed2025 rows where the gate moves the prediction away from
base, the sign of that move must agree with the sign of the actual result's
departure from base more often than chance, at p < 0.05 by a two-sided
binomial test.**

This is the direct, continuous replacement for what "precision" was reaching
for: not "did it fire on too many people" but "when it moved someone, was
that the right direction." Observed: **cor(predicted move, actual move) =
0.485** across all 331 gated rows, and among the 293 rows where the gate
actually moved the prediction, **57.4% agreed in sign** with the actual
outcome (binomial test against 50%: p ≈ 0.004, so the bar is already cleared
on this data).

**Reported, not decisive, for one honest reason**: 293 observations are not
293 independent draws in the way a binomial test assumes — Australian
electorates share state-level and campaign-level correlation, and no
clustering correction is applied here. Treating this as informative but not a
pass/fail gate on its own avoids overstating precision a naive test cannot
actually deliver. Criterion 1 is where the real bar sits.

## Dry-run: verdicts checked against known cases before committing

| case | expected | observed | verdict |
|---|---|---|---|
| Nicolette Boele, Bradfield, fed2025 (prior 20.9%, won 27.0%) | **ungated, zero effect** — she is the named reason the 15% line exists as a hard cutoff, not a soft one | `gated = FALSE`, `base` and `pcv` both untouched by the model (base 22.86 computed from uniform swing alone, gate never applied) | **PASS** |
| Dai Le, Fowler, fed2022 (prior 0.0%, won 29.5%) | **gated, moved substantially toward the actual result** | base 1.85 → pred 15.07 (actual 29.51) — undershoots but moves 13.2 points in the right direction, the single largest under-call the gate cannot fully close | **PASS** — this is what the gate is FOR, not a failure that it doesn't close the whole gap |

Both are the cases the previous design's diagnosis named by name
(`salience-gate-2026-08-27.md`'s per-seat table and the review that preceded
it). Neither required inventing a new example to make the criterion look
good.

## Refusal — what disqualifies a winner, stated before running

- **If Criterion 1 passes only because the gated model's coefficient on `x`
  is near zero.** Same refusal clause the original document already carries
  for C1; restated here because it applies with equal force to this
  replacement.
- **If Criterion 1's gain is concentrated in one or two seats rather than
  broadly shared.** Report the by-seat distribution of the error difference,
  not just its mean; a criterion that passes on 5 seats and is flat on 136
  is not the same finding as one that helps broadly.
- **If the 0.37 bar is loosened after this document is committed.** It is
  computed from the same fed2025 data the criterion will be scored on one
  final time; recomputing it after seeing a different number is exactly the
  move `CLAUDE.md` names as the repeated failure in this repo's own history.
- **If Criterion 2's sign-agreement rate is quoted without the clustering
  caveat above.** It is supporting evidence, not proof.

## What this cannot see

- **This re-specifies the criterion. It does not re-decide whether the gate
  ships.** C1 (of the original document) already passed; C3 (the positive
  test on 8 held-out federal emergences, 2010–2019) was never run because the
  data was not fetched at the time. Both still gate adoption. This document
  only replaces the broken precision check.
- **Still against `salience-v5.csv`** (20 elections, non-majors only),
  matching the model this criterion was sized to score. `salience-v6.csv`
  (22 elections, majors included, landed 2026-08-28) is not used here
  deliberately — swapping the corpus and the criterion in the same document
  would conflate two changes and make neither result attributable. Rerunning
  this whole thread against v6 is its own, separate, future ticket.
- **The by-seat clustered SE (141 clusters, 331 observations) assumes each
  seat's gated rows are exchangeable within that seat**, which is a
  reasonable approximation but not verified against an alternative clustering
  (e.g. by state, or by whether the seat had more than one gated candidate).
