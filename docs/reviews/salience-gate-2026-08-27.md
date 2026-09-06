# The salience gate works and does not ship: C2 fails as pre-registered

2026-08-27. Scores `docs/plans/prereg-salience-emergence-gate.md`, committed at
`476a868` before any model was fitted.

**Decision rule was: ship only if C1 and C2 pass. C2 fails. It does not ship.**

That is written first because everything below it is favourable, and the point
of a pre-registration is that a favourable result does not get to rewrite the
rule it was measured against.

## Results

| criterion | result | verdict |
|---|---|---|
| **C1** fed2025 RMSE, out of sample, tolerance +0.30 | **−0.266** (6.787 → 6.521) | **PASS** |
| **C2** precision, max 3 false per true emergence | **12.17** (6 true, 73 others) | **FAIL** |
| refusal: ungated fed2025 winners must not move | 0.000000 across 13 | PASS |
| refusal: recall ≥ 4 of fed2022's 6 emergences | 6 of 6 | PASS |
| refusal: coefficient must not be ~zero | **+16.50** (SE 1.10, t 14.95) | PASS |
| **C3** positive test on 8 held-out emergences | **not run** — data not fetched | pending |

## What the gate actually does, isolated

The pre-registration named one direction of the coefficient trap — C1 passing
because the model declines to act — but not its mirror: the fit re-estimates
`base` as well as salience, so an improvement could be recalibration wearing
salience's name. Separated:

| | fed2025 RMSE | fed2022's 6 emergences, mean abs error |
|---|--:|--:|
| uniform base | 6.787 | 25.21 |
| + recalibrated base ONLY | 6.685 | **25.48** |
| + salience | 6.521 | **7.20** |

**Recalibration alone makes the emergences slightly WORSE.** The entire
18.29-point gain is salience. The base coefficient falls to 0.763, which is the
same shrinkage the deviation-slope work found independently.

Per-seat, fed2022 leave-one-out (fitting election, not decisive):

| seat | candidate | prior | jump | base | gated | actual |
|---|---|--:|--:|--:|--:|--:|
| Kooyong | Monique Ryan | 9.0 | 5.21 | 10.8 | **38.6** | 40.3 |
| Mackellar | Sophie Scamps | 12.2 | 1.52 | 14.0 | 25.6 | 38.1 |
| Goldstein | Zoe Daniel | 1.4 | 3.25 | 3.2 | **25.5** | 34.5 |
| Fowler | Dai Le | 0.0 | 1.61 | 1.8 | 17.0 | 29.5 |
| Curtin | Kate Chaney | 7.7 | 1.75 | 9.6 | 24.3 | 29.5 |
| North Sydney | Kylea Tink | 4.4 | 1.22 | 6.3 | 18.3 | 25.2 |

Dai Le is the case the current model cannot represent at all: prior independent
vote **0.0%**, so uniform swing projects 1.8% and no amount of seat-level
variance reaches 29.5%. The gate projects 17.0%.

## Why C2 failed, and why that is not being fixed today

C2 capped the gate at 3 non-emergent firings per true emergence. It fired on 79
gated rows: 6 true, 73 others.

**C2 was mis-specified for the model it was testing.** The gate is a *continuous*
coefficient on `log1p(jump)`, not a binary trigger, so "the gate fires" had to be
operationalised with a threshold — and the count of false positives is an
artefact of where that threshold is put, not a property of the model. A
continuous term that adds +1.6 points to a candidate polling 2% has not
meaningfully "fired" on them.

Two things follow, and the second is the one that matters:

1. The criterion does not measure what it was written to prevent. What it was
   guarding against is "a rule that fires on everyone", and the direct evidence
   on that is C1: on an election with **zero** emergences the gate *improved*
   RMSE and moved all 13 ungated winners by exactly zero.
2. **It is not being re-specified now.** Rewriting a criterion after it fails,
   in the direction that rescues the result, is precisely what this repo has
   done twice and written down twice. A replacement C2 belongs in a new
   pre-registration, written before it is scored.

So the honest position is: **the gate looks strong and is unshipped**, on a
criterion I now believe was the wrong test. That is the correct cost of writing
criteria in advance, and paying it is the only thing that makes the other
criteria worth anything.

## C3 is runnable, and now worth the fetch

The previous design died because its in-sample upper bound (4.8 points) sat
below the minimum detectable effect on 8 held-out emergences (6.9). This one
delivers **18.29 points**, comfortably above that floor. So for the first time
the positive test can resolve.

What it needs: fed2010, 2013, 2016 and 2019, which cannot share the 2021–2025
window because Google drops to monthly buckets above roughly five years and a
monthly series cannot measure an 8-week campaign. They need their own windows,
chained in TIME on candidates appearing in both — the same trick used across
seats, applied across dates. **Untested, and if it proves unreliable C3 must be
abandoned rather than run on incomparable scales**, which is the fault that
killed the previous design.

## Limits, unchanged

- Single Trends pull per candidate; no replicates.
- Nothing tests a state election. Victoria is the live target, 28 Nov 2026, and
  its candidates are not yet nominated.
- The 15% gate excludes Nicolette Boele (prior 20.9%, won Bradfield on 27.0%),
  the one genuine near-emergence in fed2025. Recorded in advance, not tuned away.
- 6 emergences fitted. Small.
