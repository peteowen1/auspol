# Pre-registration v2: the same idea, with the collinearity removed before fitting

Written 2026-08-20, **before anything is refitted**. Committed before running.
Supersedes [prereg-independent-emergence.md](prereg-independent-emergence.md),
whose result is in
[independent-emergence-2026-08-20](../reviews/independent-emergence-2026-08-20.md).

## What v1 established

Arm B fixed the failure it was built for — three of the five catastrophic
independent misses went from near-zero to 0.42–0.98, accuracy rose by three
seats, log score more than halved — and was **not adopted**, on two counts:

- Brier improved by only **1.03 SE** against a 2 SE bar, and beat the
  dumb-temperature control by **0.66 SE**;
- it wrecked seats an **incumbent independent** already held: Sydney 0.999 →
  0.410, Wagga Wagga 1.000 → 0.524, Lake Macquarie 1.000 → 0.597.

The second is diagnosed, and it is a defect in the features rather than the
idea. `ind_prev` was fitted alongside `nonmajor_prev`, **which contains it**. The
two are collinear, the fit put essentially all the location weight on the
aggregate (`ind_prev` coefficient −0.0007), and the model was left unable to
distinguish "20% spread across minor parties" from "20% to a sitting
independent". Arm B then replaced each seat's independent share with a draw
centred on the aggregate, overwriting a sitting independent on 45%.

## The one change

**The two features are made disjoint**, so they cannot be collinear by
construction:

| v1 | v2 |
|---|---|
| `nonmajor_prev` = IND + OTH + OTH_RIGHT | `other_nonmajor_prev` = **OTH + OTH_RIGHT only** |
| `ind_prev` = IND (contained in the above) | `ind_prev` = IND (now disjoint from it) |

`abs_margin` and `coalition_held` are unchanged. The structure, the `log1p`
scale, the estimated spread and the estimated tail weight are **all unchanged**.

**Their correlation is reported before the fit is read**, as evidence the
collinearity is actually gone rather than assumed to be.

Nothing else moves. This is deliberately the minimum change that addresses the
diagnosis, so that if it works the reason is legible, and if it does not the
idea is the thing in question rather than the plumbing.

## Everything below is carried over from v1 unchanged

Same three arms — **A** as published, **B** with emergence, **S** the
single-temperature control fitted leave-one-seat-out. Same metrics: Brier, log
score, calibration slope, winner accuracy. Same fit: leave-one-seat-out on NSW
2019 → 2023, one election, one state, an unusually independent-friendly one, and
**a win here is still not evidence the rate transfers to Victoria 2026.**

Same decision rule:

- **Adopt B** if the Brier improvement exceeds **2 SE** of the paired per-seat
  difference, **and** the calibration slope moves toward 1, **and** it clears E1.
- **Keep A** otherwise.

Same refusals **E1–E5**: the shrinkage control (B must beat a dumb temperature);
the one-way ratchet on Victorian independent seats (stop above +2.0); no tuning
against the scoring metric; no per-seat overrides; accuracy must not fall by more
than 2 seats.

## One refusal added, from what v1 broke

- **G1 — no regression on incumbent independents.** For any seat where an
  independent both held the seat going in and won it again, arm B must not give
  that independent a probability below **0.80**.

  This is an absolute bar, not a significance test, and deliberately so: these
  are seats where near-certainty is *warranted* by the previous result, and a
  model that drops to 0.41 on Sydney is wrong in a way no amount of aggregate
  improvement excuses. Sizing it in standard errors would be the wrong tool —
  the question is not whether the drop is distinguishable from noise but whether
  the resulting number is defensible.

## What would make me refuse a v2 that passes

If B passes only because G1 was added — that is, if its Brier and E1 margins are
essentially unchanged from v1 and the sole difference is the incumbent seats no
longer breaking — then the honest reading is that **v1's aggregate result was
already the truth** and v2 has only stopped it doing visible harm. Report it that
way rather than as a win. The v1 numbers are recorded above precisely so this
comparison cannot be fudged.
