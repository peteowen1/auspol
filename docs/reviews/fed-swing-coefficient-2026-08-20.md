# The alarm was wrong: 0.7452 stands, and the transposed measure is only good where it validates

Run 2026-08-20 against
[../plans/prereg-fed-swing-coefficient.md](../plans/prereg-fed-swing-coefficient.md),
committed before anything was re-fitted.

**Verdict: KEEP A. The live coefficient is not too large.** I raised that alarm
an hour earlier and it does not survive the test.

## What I claimed and what is true

I reported that the four-election fit gave 0.393 against 0.7452 live, and that
"the published model may be applying the seat-swing adjustment about 70% too
strongly."

Head to head on the 180 seats that have both measures, leave-one-election-out:

| arm | pooled MAE |
|---|---:|
| **A — published measure, coefficient ~0.75** | **3.3674** |
| B — transposed measure, coefficient ~0.39 | 3.5513 |
| C — uniform swing, no adjustment | 3.9462 |

**B is +0.184 MAE worse than A, at +1.68 SE.** The status quo wins outright, not
on the tie-break.

## Why the low coefficient was not evidence of anything

A coefficient fitted on a noisier predictor is **attenuated** — pulled toward
zero — and is *correct for that predictor*. So 0.39 on the transposed measure
and 0.75 on the published one are not competing estimates of one quantity; they
are the right coefficients for two different inputs. Comparing them directly, as
I did, was the error.

What decides between them is out-of-sample accuracy, and the cleaner measure
with the larger coefficient wins.

## The transposed measure works where it validates and not elsewhere

Arm B's per-election gains against uniform swing:

| election | gain |
|---|---:|
| vic2018 | **−0.330** |
| nsw2019 | **−0.067** |
| vic2022 | +0.366 |
| nsw2023 | +0.418 |

**Negative on exactly the two new cycles.** Those are the ones where the
correspondence files are keyed to 2019 federal boundaries and had to be matched
against federal 2016 through a rename map and a booth-name fallback. The
validation that passed — r = 0.952 and 0.949 — was run on vic2022 and nsw2023,
the two cycles that needed none of that.

So the honest reading: **the transposition is sound where it was checked and
unreliable where it could not be.** The 362-seat sample is really 180 good seats
and 168 noisy ones, and that is why it produced a weaker relationship rather
than a better-powered one.

## What this does to the seat-type finding

The seat-type reversal (F = 0.36 on 180 seats, F = 5.14 on 348) used the same
348 seats, 168 of which are now known to carry a noisy `fed_swing`.

That does **not** invalidate it — noise in `fed_swing` would if anything make it
*harder* for seat type to add anything, since a poorly-measured control leaves
more variance for another variable to soak up. Which is exactly the concern:
**some of seat type's apparent significance may be it standing in for the part
of `fed_swing` the transposed measure got wrong.**

Untested either way. The seat-type result should be treated as suggestive rather
than established until it can be run on 348 seats with a clean `fed_swing`, and
that needs correspondence files keyed to the right boundary vintage — not more
elections.

## The standing lesson, third time today

Three times today a number moved when the sample grew, and the reflex each time
was to trust the bigger sample. Twice that was right (the independent model
reversing, the seat-swing predictors collapsing). **Here it was wrong**, because
the extra data was worse data and the comparison was between measures rather
than between samples.

More data is not automatically better data. The question to ask first is what
the new observations are *measured with*.
