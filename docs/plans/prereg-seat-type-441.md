# Pre-registration: does seat type add anything to `fed_swing`, on 441 seats?

Written 2026-08-20, **before the test is run**. Committed before running.

## Why this is being rerun

`docs/reviews/seat-type-and-demographics-2026-08-20.md` tested it and got
**F = 0.36, p = 0.78** — nothing. It then corrected itself, saying the test had
**180 seats** and three extra degrees of freedom, and that `F = 0.36` is not
evidence of absence at that size. It named the real constraint: *only 180 seats
have a `fed_swing` to test anything against.*

That constraint is now **441 seats across 5 elections** — Victoria 2018 (79),
NSW 2019 (88), Queensland 2020 (93), Victoria 2022 (88), NSW 2023 (93).

## THE POWER CALCULATION, DONE FIRST

`CLAUDE.md` requires every tolerance to be written in standard errors, or its
size in standard errors computed when it is written. Four criteria have failed
that way. So, before running:

**The independent observation is the ELECTION, not the seat.** Every seat in a
cycle is scored against that cycle's own statewide swing, so seat errors within
a cycle are not independent. n = 5, not 441.

The per-election gains from `fed_swing` itself, which is the closest available
estimate of how much a per-election MAE difference bounces around:

```
-0.202, -0.050, -0.285, +0.330, +0.377   ->   sd 0.312
```

So `SE = 0.312 / sqrt(5) = 0.140`, and a result must clear about **0.28 MAE**
to reach 2 SE. Against a baseline MAE near 3.2 that is a **9% improvement**.

**This test cannot detect anything smaller than a 9% improvement.** That is
recorded here, in advance, because it is the number that decides whether a null
result means anything — and on the reliability-bin and first-preference
precedents, it is the number that gets discovered afterwards instead.

**A null result here therefore does NOT retire the question.** It rules out a
large effect and says nothing about a small one. If seat type comes back null,
the correct write-up is "no effect larger than 9% of baseline error", not "seat
type does not matter".

## Arms

- **A — status quo.** `dev ~ fed_swing`, centred within election.
- **B — plus seat type.** `dev ~ fed_swing + seat_type`, four levels from
  `Data/seat-types.csv` (inner-metro, outer-metro, provincial, rural).
- **C — seat type alone.** `dev ~ seat_type`. Included because it decides
  *which* claim a null supports: seat type carrying no information at all is a
  different finding from seat type being redundant to `fed_swing`.

## What is measured

Each seat's **deviation from its own election's statewide swing**.

- **Leave-one-election-out MAE**, the criterion this work has used throughout.
- **Per-election gain**, so no single election carries the result.
- **The fitted seat-type coefficients per fold**, because a real effect should
  keep its sign.

## Decision rule, fixed now

- **Adopt B only if it beats A by more than 2 SE** on the election-clustered
  paired difference — that is, by more than **0.28 MAE**, using the SE computed
  from this run's own five per-election differences rather than the 0.140
  estimated above.
- **If B beats A by less than 2 SE, keep A.** The status quo does not lose a
  tie, and a sub-threshold win is not a win.
- Report C regardless, and report whether the seat-type coefficients hold their
  sign across all five folds.

## Refusals — what would disqualify an apparent WIN

`CLAUDE.md` requires this section, because two of three experiments were refused
on grounds invented after seeing the results.

- **R1 — a win resting on one election is refused.** If removing the single
  best-performing election drops the gain below 2 SE, it is not adopted. With
  five clusters one election is 20% of the evidence.
- **R2 — sign instability is refused.** If any seat-type coefficient changes
  sign across the five folds, the effect is not stable enough to ship, however
  the MAE reads.
- **R3 — a directional side effect on the live forecast disqualifies.** Seat
  type is not in the published model. If adopting it moves any party's Victoria
  2026 seat median by more than **2 seats**, stop and report rather than ship.
  This is the clause that caught the One Nation change, and it is written here
  in advance rather than after.
- **R4 — a win that is really a dispersion effect is refused.** Queensland 2020
  has a baseline MAE of 1.676 against 3.2-4.5 elsewhere. If B's gain comes
  disproportionately from the low-dispersion election, the finding is about
  election dispersion and not about seat type, and it must be written up as
  such.
- **R5 — Victoria 2026 seat types must exist before adoption.** The 2026
  Victorian districts postdate `seat-types.csv`. If any 2026 seat has no type,
  the feature cannot be applied to the forecast at all, and adopting it would
  mean inventing a classification — which is exactly the thing this repo does
  not do.

## What this criterion cannot see

- **Whether the classification is right.** `seat-types.csv` is the anchor's
  four-way taxonomy, used here as input data. Its boundaries between outer-metro
  and provincial are someone else's judgement.
- **Anything below 9% of baseline error**, as computed above.
- **Interaction with dispersion.** The test fits one coefficient per seat type
  across five elections whose baseline MAE ranges from 1.68 to 4.51. A seat type
  that matters only in high-dispersion elections would be averaged away, and
  this design cannot recover it.
