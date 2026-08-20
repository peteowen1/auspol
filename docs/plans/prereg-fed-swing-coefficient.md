# Pre-registration: re-fit the seat-swing coefficient on four elections, not two

Written 2026-08-20, **before anything is re-fitted**. Committed before running.

## The problem

`SEAT_SWING_COEF = c(fed = 0.7452)` went live this morning. It was fitted on the
**two** elections with a published `fed_swing` — Victoria 2022 and NSW 2023.

Transposing `fed_swing` onto state districts from AEC booth data now gives four:

| fit | coefficient |
|---|---:|
| published measure, 2 elections | **0.7452** — live |
| transposed measure, same 2 elections | 0.6207 |
| transposed measure, 4 elections | **0.393** |

The two measures correlate at 0.942, so part of that drop is **attenuation** — a
noisier predictor pulls its own coefficient toward zero. The rest is a sample
effect. Attenuation-corrected, the four-election estimate is about **0.44**
against 0.745 live: the model may be applying the adjustment **~70% too
strongly**.

This is the trap the whole day has been about, applied to something shipped
today.

## The subtlety that decides the design

**A coefficient must be fitted on the same measure it is applied to.** Fitting on
the noisier transposed measure and applying to the cleaner published one would
under-apply by exactly the attenuation. So the choice is not just a number — it
is which *measure* the model uses.

## The three arms

- **A — status quo.** Published `fed_swing`, coefficient 0.7452. Only two
  elections have the published measure, so this arm cannot be tested on more.
- **B — transposed.** Transposed `fed_swing` throughout, coefficient fitted
  leave-one-election-out on the other three. Four elections, ~348 seats.
- **C — no adjustment.** Uniform swing. The floor, and the arm that already
  disqualified three predictors today.

## What is measured

Predicting each seat's **deviation from its own election's statewide swing**,
which is what the adjustment exists to do.

- **Leave-one-election-out MAE**, the criterion the seat-swing work has used
  throughout.
- **Per-election gain**, so no single election carries the result.
- The **fitted coefficient per held-out fold**, because its stability is the
  question that prompted this.

## Decision rule, fixed now

- **Adopt whichever arm has the lowest pooled leave-one-election-out MAE**,
  provided it beats C. If A and B are within **1 SE** of each other, keep A —
  the status quo does not lose a tie, because switching measures has a cost the
  MAE does not price (the transposed measure must be recomputed whenever the
  AEC or the correspondences change).
- **If neither beats C**, remove the adjustment entirely and say so. Three
  predictors were removed today on exactly that test.

## Refusals

- **S1 — no mixing measures.** The coefficient and the input must be the same
  measure in every arm. Fitting on transposed and applying to published is the
  attenuation mismatch this plan exists to avoid.
- **S2 — no attenuation correction as a shortcut.** The ~0.44 figure quoted
  above is an estimate used to *motivate* this test, not a value to adopt.
  Dividing a coefficient by a reliability estimate and shipping the result is
  not a fit.
- **S3 — report the effect on the live forecast.** Victoria 2026 currently uses
  the published measure with 0.7452. Report what each arm does to the seat
  medians, and **if any party's median moves by more than 2, stop and report**
  rather than ship.
- **S4 — the two new elections are not privileged.** Victoria 2018 and NSW 2019
  are what changed the answer. Report the per-election gains so that if the
  effect rests on one of them, that is visible rather than buried in a pooled
  number.
- **S5 — a worse coefficient is still a result.** If the four-election fit is
  simply less accurate out of sample than the two-election one, that is the
  finding, and the extra data does not automatically win for being extra.

## What this cannot see

Whether the transposed measure is *right*. It reproduces the published one at
r = 0.95 with a mean absolute difference of 2–3 points, and the published one is
itself a transposition someone else did. Neither is ground truth; they are two
estimates of the same quantity.
