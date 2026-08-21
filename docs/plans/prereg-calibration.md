# Pre-registration: the seat model is over-confident. Can that be fixed with a model change rather than a knob?

Written before anything is fitted. Committed before running.

## The defect

Calibration slope, where 1 is perfect and below 1 means probabilities too
extreme:

| | slope |
|---|---:|
| fed2010 / 2013 / 2016 | 0.249 / 0.189 / 0.297 |
| fed2019 / 2022 / 2025 | 0.329 / 0.183 / 0.441 |
| vic2018 | 0.512 |
| vic2022 | **2.515** |
| nsw2023 | 0.541 |
| sa2026 | 0.299 |

**Over-confident in 9 of 10.** This is not a borderline reading: a slope near
0.2 means a seat given 95% wins far less often than 95% of the time.

It is only visible now because the corpus went from 166 seats across 2 elections
to **1,099 across 10** — six federal pairs and South Australia were added, and
the federal ones had never been scored against this model at all.

## THE POWER CALCULATION, DONE FIRST

The independent observation is the **election**. Ten clusters, **9 degrees of
freedom**, against the 1 and 2 that every earlier decision here has had.

Concretely: the seat-swing port read **−1.22 SE** on 3 elections. An effect of
the same size on 10 elections reads about **−2.2 SE**, since the clustered SE
falls with `sqrt(n)`. **So this test can detect effects of the size this repo
has actually been arguing about** — which no previous test on this model could.

That is the point of running it now rather than after another election.

## Arms

- **A — status quo.**
- **B — wider seat spread.** One multiplier on `seat_sd`, fitted
  leave-one-election-out. A model change: more genuine per-seat uncertainty.
- **C — TEMPERATURE, AND THIS IS THE NULL TO BEAT.** Post-hoc scaling of the
  output probabilities, one parameter fitted leave-one-election-out. This adds
  no knowledge whatsoever; it just flattens what the model already said.
- **D — both.**

**C exists because `CLAUDE.md` records the shrinkage control arm: any noise
added to an over-confident model improves calibration.** So B improving the
slope proves nothing on its own. B must beat C, or the honest finding is "the
output needed rescaling", which needs no model change and should be shipped as
one.

## What is measured

**Leave-one-election-out log score**, clustered on the election. Log score
rather than the slope, because the slope can be driven to 1 by throwing away
information, and log score cannot — it penalises both over-confidence and lost
discrimination.

Reported alongside, not as criteria: Brier, calibration slope, and accuracy.

## Decision rule, fixed now

- **Adopt B (or D) only if it beats BOTH A and C by more than 2 SE** on the
  election-clustered paired log-score difference.
- **If C beats B**, ship C and say plainly that the fix is output rescaling, not
  a better model.
- **If nothing beats A by 2 SE**, keep A and report that the over-confidence is
  real but not fixable by these means.
- Ties go to A, then to the simpler of the remainder.

## Refusals — what disqualifies an apparent win

- **K1 — accuracy must not fall.** A change that improves log score while
  calling fewer seats correctly is trading the thing the forecast is for.
  Pooled accuracy must stay within 1 percentage point of A.
- **K2 — the fitted parameter must be stable.** If the multiplier varies by more
  than a factor of 2 across the ten folds, it is fitting elections rather than a
  property of the model.
- **K3 — a win resting on one election is refused.** Dropping any single
  election must leave the result above 2 SE. With 10 clusters this is a real
  test rather than a formality.
- **K4 — Victoria 2018→2022 must not be the mechanism.** It is the ONE
  under-confident election, so any change that widens uncertainty will look good
  there for the opposite reason to everywhere else. Report its contribution
  separately; if it carries the result, the finding is about that election.
- **K5 — the live forecast.** If any party's Victoria 2026 seat median moves by
  more than 2, stop and report rather than ship. Widening uncertainty should
  move intervals, not centres, and a moved centre means something else happened.
- **K6 — no reading the slope as the result.** The slope is reported because it
  is the symptom. Adopting on the slope is exactly the mistake arm C exists to
  expose.

## What this cannot see

- **Whether the over-confidence is the same defect in every election.** Federal,
  NSW, Victorian and South Australian contests differ in party structure; one
  multiplier assumes a single cause.
- **Whether Victoria 2026 is like the nine or like the one.** vic2022 is the
  only under-confident election in the set and it is the most recent Victorian
  one, which is uncomfortable for a Victorian forecast.
- **Anything about the One Nation allocation**, whose shape is fitted on SA 2026
  and remains untestable until Victoria votes.
