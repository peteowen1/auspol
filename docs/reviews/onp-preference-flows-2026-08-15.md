# One Nation preference flows: the largest single lever, and why it does not flip the result

2026-08-15. Immutable record of the evidence; the decision it feeds is in
[../NEXT-STEPS.md](../NEXT-STEPS.md).

## Why this looked like the biggest risk in the model

One Nation is polling **20.9%** of the Victorian first preference vote. Every
point of that reaches the two-party figure through an *assumed* preference
flow, so the **trend** two-party number moves 0.21 points for every 1 point
the flow moves. Nothing else in the model has that leverage.

The forecast assumes **25.5%** of One Nation preferences go to Labor — the
**lowest of all 24 estimates in the anchor's file**, and not an observation
but a forward assumption.

## What the page said, and why it was wrong

> "One Nation at 21% is unprecedented in Victoria and its preference behaviour
> is estimated from federal elections, not Victorian ones."

Both halves are wrong. `flows_for()` deliberately **never reaches across
regions** — that guard exists because a data.table shadowing bug once handed
Victoria the federal flows and pushed its 2022 validation 3 points high. And
the anchor's file carries an authored Victorian row for 2026: `2026,vic,ONP
FP,25.5`. The caveat described a mechanism the code explicitly prevents.
Fixed.

## The pooled spread is the wrong measure of uncertainty

Across all 24 estimates the flow ranges 25.5–54.4 with sd 8.70, which looks
like enormous uncertainty. Almost all of it is **trend**, not noise. One
Nation preferences have moved steadily toward the Coalition for thirty years —
federally 54.4 (1998), 53.3 (2001), 44.1 (2004), 40.0 (2019), 34.8 (2022),
26.2 (2025).

Regressing the **21 observed** flows (excluding the three forward projections)
on year:

- slope **−0.605 points per year**, p < 0.001, **R² = 0.738**
- residual sd around the trend **3.73 points**, against a pooled sd of 7.28

The honest year-on-year uncertainty is about **3.7 points**, half what pooling
suggests. Reading a trended series as noise would have overstated it twofold.

## Where the assumption sits, and the comparator that argues against it

The fitted trend predicts **34.1** for 2026. The forecast uses **25.5** —
**2.3 residual standard deviations below the trend line.**

The anchor applies the same 25.5 to Victoria 2026, NSW 2027 and federal 2028,
so it is a deliberate, consistent forward view, not a Victoria-specific claim.
It is defensible: the most recent *federal* observation was 26.2 in 2025.

But **South Australia voted in March 2026 with One Nation on 22.9%** — the
closest analogue available to Victoria's 20.9%, in the same year — and
delivered an **observed** flow of **36.15**, slightly *above* the trend.

| Election | ONP first preference | Flow to ALP | Observed? |
|---|---:|---:|---|
| SA 2026 | 22.9 | 36.15 | yes |
| Qld 1998 | 22.7 | 47.20 | yes |
| Qld 2017 | 13.7 | 45.00 | yes |
| **Vic 2026** | **20.9** | **25.50** | **no — assumed** |

Every completed high-One-Nation election has produced a flow well above 25.5.
That is direct evidence against "a bigger One Nation directs preferences more
strongly to the Coalition", since SA 2026 is both the largest recent One
Nation vote and one of the more Labor-directed recent flows.

## What it is actually worth — measured, not extrapolated

The flow moves the *trend* two-party figure, but the published number mixes
trend and fundamentals at **w = 0.52**, and fundamentals (46.47) do not depend
on flows at all. So the headline moves by roughly **half** the trend shift.
Recomputing the full projection under each assumption:

| Flow | Source | Trend TPP | **Published** | Shift |
|---:|---|---:|---:|---:|
| 25.5 | current forecast | 47.06 | **46.78** | — |
| 34.1 | fitted trend for 2026 | 48.96 | **47.76** | +0.98 |
| 36.15 | SA 2026 observed, comparable ONP | 49.41 | **47.99** | +1.21 |
| 42.0 | Victoria's own 2018 estimate | 50.71 | **48.66** | +1.88 |

Held-out standard error at this horizon: **2.42**.

**The headline finding is that this does not flip the result.** Across the
entire plausible range of flow assumptions — from the anchor's forward view to
Victoria's own eight-year-old estimate — Labor's two-party vote runs from 46.8
to 48.7, and **never reaches 50**. The most defensible alternative, the SA
2026 comparator, moves it +1.21 points, about **half a standard error**.

Two reasons the sensitivity is smaller than it first appears:

1. The mix weight is 0.52, halving any trend shift.
2. Fundamentals sit at 46.47, close to the trend, so they pull the mixed
   number down rather than amplifying a favourable flow.

A first-pass linear estimate on the trend figure alone gave +2.2 points and
"line-ball" — nearly double the truth, and the wrong qualitative conclusion.
The mix weight is exactly the kind of factor a back-of-envelope drops.

**This is a point-estimate question, not an uncertainty one.** The residual
scatter around the flow trend (3.73 points) contributes only
`0.209 × 0.52 × 3.73 = 0.41` points of extra two-party spread; in quadrature
with 2.42 that widens the interval by under 2%. Not worth changing.

## What was done, and what was not

Done:

- Corrected the false caveat about federal flows.
- Published the sensitivity on the page, so the largest lever is visible
  rather than buried in an input file.
- Added check **G2**, failing when the assumed flow sits more than 2.5
  residual sds from the observed trend. This assumption is at 2.3 and should
  not drift further without someone noticing.

Deliberately **not** done: changing the flow, or widening the interval. The
flow is the anchor's authored input and he is the domain expert; and now that
the effect is measured, it moves the headline about half a standard error and
changes no conclusion a reader would draw. Recorded as Pete's call, not
treated as one.
