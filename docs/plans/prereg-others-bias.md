# Pre-registration: why is "Others" fitted 3.6 points low?

Written 2026-08-18, before anything is built or run. Committed before any
result.

## The finding this comes from

Across 54 completed cycles, the model's endpoint first preferences are close to
unbiased for every party except one
([../reviews/couple-party-trends-2026-08-18.md](../reviews/couple-party-trends-2026-08-18.md)):

| party | n | bias (fitted − actual) |
|---|---:|---:|
| **OTH** | 54 | **−3.60** |
| LNP | 54 | −1.11 |
| ONP | 6 | +0.01 |
| GRN | 33 | +0.10 |
| ALP | 54 | +0.33 |

This is a bigger claim than the drifting-sum question it replaced. That one
turned out to be a symptom; this is the disease, and unlike the sum it is a
**bias in a published number**, not an untidiness every consumer already
renormalises away.

## Why it is worth chasing even though two-party barely moves

Correcting it moves Victoria's published two-party figure by **−0.012** —
nothing, because Others flows to Labor at 48.9%, almost exactly even. So this
is not pursued for the headline.

It is worth chasing because:

1. **The page publishes first preferences directly.** Others is printed at 11.1
   and history says this model under-calls that party at a cycle endpoint.
2. **The candidate-level seat model consumes the minor field.** It currently
   scales OTH to the forecast total, so a level error is absorbed — but that
   absorption is a workaround for this bias, not a design.
3. **If the cause is cause 2 below, it is not about Others at all.** An
   industry-wide polling bias would be invisible for every party, and Others is
   simply where it is large enough to see.

## Candidate causes, fixed now

- **C1 — the prior is too sticky.** Each party's trend is anchored to the
  previous election's result. Minor-party vote has risen for decades, so an
  anchor that far back drags a growing series down.
- **C2 — every pollster misses the same way.** House effects are identified by
  a soft weighted sum-to-zero constraint (`R/trend.R:119-124`). **A bias shared
  by all firms is invisible to that by construction** — the structure that makes
  house effects identifiable is exactly what hides an industry-wide miss.
- **C3 — the walk is too slow.** Minor-party support may rise through a
  campaign faster than the random walk's step size allows the level to follow.

## Discriminating tests, fixed now

Each cause predicts something different, and the tests are chosen so that
confirming one does not confirm the others.

**T1 (targets C1).** Regress the endpoint bias on the gap between the previous
election's OTH result and the eventual one. If the prior is dragging, seats
where OTH grew most since the last election should show the largest negative
bias. **Predicts:** a significantly negative slope. C2 and C3 predict none.

**T2 (targets C2).** Compare the fitted endpoint against the **mean of the
final 30 days of published polls**, not against the actual result. If the model
tracks the polls and the polls miss, the model-vs-polls gap is near zero while
the polls-vs-actual gap carries the whole −3.60. **Predicts:** |model − polls|
much smaller than |polls − actual|. C1 and C3 predict the opposite, since both
are failures to follow the polls.

**T3 (targets C3).** Split the bias by how much OTH moved during the final 90
days. If the walk is too slow, bias should scale with late movement.
**Predicts:** bias correlated with late movement. T2's answer is independent of
this.

T2 is the one that matters most, because if it fires the problem is not in this
model at all and no amount of re-specifying the trend will fix it.

## Decision rule, fixed now

- **T2 fires** (polls carry the miss): record it as a limit of poll-based
  forecasting, publish the caveat on the page beside the Others figure, and
  **do not** change the trend model. A model that faithfully tracks biased
  inputs is working correctly.
- **T1 fires** (prior too sticky): test a weaker anchor for OTH specifically,
  by held-out first-preference MAE over a pre-registered grid, adopting only on
  a **>0.02 MAE** gain — the same bar every other constant here was held to.
- **T3 fires**: same treatment for the walk sigma on OTH.
- **Nothing fires**: record the bias as measured and unexplained. That is a
  legitimate outcome and more useful than a story fitted after the fact.
- **More than one fires**: report all, change nothing yet, and re-register a
  test that separates them. Two causes both "confirmed" on the same data is
  usually one confound.

## Threats, stated before the run

- **"Others" is not a party.** It is a residual bucket whose composition
  changes every election, so some of the bias may be definitional rather than
  modelling error — a party that existed at the last election and was folded
  into OTH at this one moves the target without anyone being wrong.
- **Only 54 cycles, and 6 with One Nation.** Any per-party conclusion beyond
  OTH itself is underpowered.
- **The comparison uses actual results as truth**, which is right, but the
  earlier version of this measurement was confounded by cycles where the
  recorded actuals were themselves incomplete (WA 2025 summed to 63.9). The
  filter requiring actuals within 100 ± 5 must stay.
