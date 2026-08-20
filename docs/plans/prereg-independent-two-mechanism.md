# Pre-registration v3: incumbent independents and emergent ones are different problems

Written 2026-08-20, **before anything is fitted**. Committed before running.
Supersedes v1 ([plan](prereg-independent-emergence.md),
[result](../reviews/independent-emergence-2026-08-20.md)) and v2
([plan](prereg-independent-emergence-v2.md),
[result](../reviews/independent-emergence-v2-2026-08-20.md)).

## What two rounds established

One conditional distribution over "the independent vote in this seat" cannot
serve both cases, and both rounds failed in the same place for the same reason:

- **v1** — features collinear, incumbent independents overwritten
  (Sydney 0.999 → 0.410). Brier 1.03 SE, E1 0.66 SE.
- **v2** — collinearity removed and `ind_prev` given real weight (+0.0680).
  **Aggregate identical**: Brier 1.01 SE, E1 0.65 SE. Sydney still 0.410.

The v2 medians say why. The single term is **exponential in the original
units**, so it crosses the identity line near 50% and misses below it:

| seat | IND last time | v2 median | actual |
|---|---:|---:|---:|
| Lake Macquarie | 53.5 | 52.2 | 57.5 |
| Wagga Wagga | 46.1 | 47.6 | 44.2 |
| **Sydney** | **41.4** | **20.0** | **41.1** |
| **Dubbo** | **28.4** | **39.7** | **0.0** |

Dubbo is a third problem again: the independent did not stand.

## The structure, fixed now: three mechanisms, not one

A seat is routed by **what its own previous first preferences say**, never by
the seat file's `incumbent` field — which records the current holder, is
contaminated by by-elections, and classifies the Shooters, Fishers and Farmers
as `IND` where we classify them `OTH_RIGHT`.

**Route 1 — a sitting independent (previous independent vote ≥ 15%).**

- **Recontest**: a probability `r` that they stand again, estimated from the
  data. Dubbo says this is not 1.
- **If they stand**: their vote is centred on `log1p(previous)` with a
  coefficient **estimated, not fixed at 1** — the claim "next ≈ previous" is the
  hypothesis, not an assumption. Spread estimated on the same scale.
- **If they do not**: the seat falls through to route 3.

**Route 2 — no sitting independent: emergence.** Exactly the v2 model, whose
one job is now to describe seats with little or no independent history rather
than to also hold up incumbents.

**Route 3 — the independent vote goes to zero** and the seat is contested
without one.

The **15%** routing cut-off is a judgement about what "a sitting independent"
means, set now and **not tuned**: it must not be adjusted after seeing any
score. It is checked once for sensitivity at 10% and 20% and both are reported,
so a knife-edge is visible rather than hidden.

## What is fitted, and on what

All parameters on **NSW 2019 → 2023**, leave-one-seat-out. Route 1 has only a
handful of seats, and that is stated up front: with roughly six sitting
independents, its parameters are **estimated from very little** and any
confidence interval on them is wide. If route 1 cannot be fitted stably it is
reported as unfittable rather than forced.

**Nothing numeric is taken from any other model.** The idea of splitting
recontest from emergence is the anchor's; every number here is ours.

## Metrics, arms and decision rule — unchanged from v1 and v2

Arms **A** (as published), **B** (three mechanisms), **S** (single temperature,
leave-one-seat-out). Brier, log score, calibration slope, winner accuracy.

- **Adopt B** if the Brier improvement over A exceeds **2 SE** of the paired
  per-seat difference, **and** the slope moves toward 1, **and** it clears E1.
- **Keep A** otherwise.

Refusals **E1–E5** and **G1** carry over verbatim: the shrinkage control; the
+2.0 cap on Victorian independent seats; no tuning against the scoring metric;
no per-seat overrides; accuracy must not fall by more than 2 seats; and no seat
where an independent held and won may be given below **0.80**.

## Added refusals

- **H1 — route 1 must not be a lookup of the answer.** Its coefficient on
  `log1p(previous independent vote)` is fitted leave-one-seat-out like
  everything else. If it comes out indistinguishable from 1 that is a finding
  worth stating, not a licence to hard-code 1 and stop fitting.
- **H2 — the recontest rate is not a free knob.** It is estimated from how often
  a sitting independent actually stood again, and **not** adjusted to make the
  scores work. If the sample is too small to estimate it, say so and set it to 1
  with that stated as an assumption, rather than picking a value that helps.
- **H3 — three mechanisms must beat one.** v2's numbers are recorded above. If
  B's Brier and E1 margins are not clearly better than v2's 1.01 SE and 0.65 SE,
  then splitting the mechanisms did not help either, and the honest conclusion
  is that **this whole line of work does not clear a dumb temperature** and
  should stop. Two rounds have already landed on that margin; a third landing
  there is the answer, not an invitation to a fourth.

## What the criteria still cannot see

One election, one state, an unusually independent-friendly one. Six sitting
independents. Nothing about who is standing in Victoria in 2026. A win here
remains no evidence the rates transfer.
