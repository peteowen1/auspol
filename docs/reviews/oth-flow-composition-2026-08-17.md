# The OTH flow question is not answerable from distribution tables

Run 2026-08-17 against [../plans/prereg-oth-flow-composition.md](../plans/prereg-oth-flow-composition.md),
committed as `75abc68` before the run.

## Verdict: inconclusive. The flow is not changed.

Both pre-registered estimands were computed. **Neither measures the target
quantity**, and they disagree by 4.2 points in opposite directions — which is
the tell, not a range.

| Estimand | Flow to ALP | ΔTPP |
|---|---:|---:|
| primary (final exclusion, ALP-vs-LNP seats) | 65.22% | **+1.743** |
| secondary (pooled immediate transfers) | 26.28% | **−2.416** |
| currently published | 48.9% | — |

Had only one been registered, either would have cleared the ≥1.0 "defect"
threshold and changed the published two-party number. The pre-registration is
the only reason that did not happen.

## Why the primary estimand is void

It was specified as "the transfer at the final exclusion", on the reasoning
that the last exclusion's transfer *is* the two-party flow by definition. True
— but in a four-or-five-party field, **the last party excluded is the
third-placed party, which is the Greens or One Nation, not an OTH minor.**

| District | Last excluded | Flow to ALP |
|---|---|---:|
| Adelaide | GRN | 93.57 |
| Bragg | GRN | 80.10 |
| Dunstan | GRN | 84.11 |
| Colton | ONP | 32.39 |
| Elder | GRN | 33.22 — **failed reconciliation, excluded** |

Not one is an OTH exclusion. The estimand measures a real quantity; it is
simply a different one from the quantity registered for.

Elder is dropped on an anchor check the others pass: transferred votes should
equal the excluded candidate's running total. Adelaide 5131 = 5131, Bragg
3512 = 3512, Colton 4875 = 4875, Dunstan 4715 = 4715 — **Elder 3962 against
3707**, so its round assignment is wrong and the row is unusable.

## Why the secondary estimand is void

It measures the **immediate** transfer at the moment of exclusion, which is not
a two-party flow. An OTH ballot transferring to the Greens is redistributed
again later, and about 84% of it reaches Labor on the second pass. Counting
only the first hop therefore understates the eventual Labor share, and 26.28%
is a floor on the true value rather than an estimate of it.

## The deeper reason, which kills the whole approach

**Aggregate distribution tables carry no vote provenance.** Once an excluded
party's votes merge into the Greens' pile, nothing in the table distinguishes
them from ballots that started as Greens. So the eventual two-party
destination of an OTH ballot **cannot be recovered from these tables at all** —
not with more districts, not with a better parser.

Recovering it needs either ballot-level preference data or the electoral
commission's own two-party count broken down by originating party. **The
latter is exactly what `preference-estimates.csv` already is.** The published
48.9% comes from the right source, and this exercise cannot improve on it.

## What the run did establish, for free

The void primary estimand independently validates **two of the model's three
Victorian flows**, because it accidentally measured them:

| Party | Measured here (SA 2026) | Model's Victorian estimate |
|---|---:|---:|
| GRN | 86.7% (weighted, Elder excluded) | 83.5% |
| ONP | 32.4% (Colton) | 33.7% |

Both land within a few points, from a different state and an entirely separate
data path. That is not proof the Victorian numbers are right, but it is the
first independent check either has had.

## What remains open

**The original concern is untouched.** One Nation is modelled separately at
20.9% in 2026, so whatever it absorbs has left the OTH bucket, and the residual
may not resemble the historical blend that 48.9% was estimated on. That
argument still stands; this test simply could not evaluate it.

Closing it needs the composition question answered directly — what the OTH
bucket consists of in 2026 versus in the elections the flow was estimated
from — rather than a flow measured off transfer tables. Recorded as open in
`NEXT-STEPS.md` rather than left as a half-answer.
