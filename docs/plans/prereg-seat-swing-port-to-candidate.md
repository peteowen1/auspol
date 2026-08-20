# Pre-registration: port the seat-swing adjustment into the candidate model

Written 2026-08-20, **before the port is written**. Committed before running.

## Why this is the outstanding item

Pete's instruction was: take what the two-party model learned, put it in the
candidate model, **measure whether error improves**, and once the learning has
moved, stop improving the two-party model.

The learning has been measured but **not moved**. `seat_swing_adjustment()`
reaches only `simulate_seats()`, the two-party cross-check. The candidate model
publishes every seat number on the page and does not use it.

Two things had to be settled first and now are:

- **C6 is answered.** The port was refused this morning because `soph_cand`
  moved 54% of its value when refitted without NSW. On five elections the
  largest shift of any coefficient is 1.19 SE. Stable.
- **Only one predictor is worth porting.** `retirement`, `soph_cand` and
  `soph_party` are worth **−0.0008** pooled against uniform swing — actively
  harmful. Porting before measuring would have moved three harmful terms into
  the published model.

## The design problem, and the choice being made

`seat_swing_adjustment()` returns points of **two-party swing toward Labor**.
The candidate model works in **first preferences**. There is no automatic
translation, so the choice is registered here rather than made in code and
discovered later.

**The adjustment is applied as a transfer between the two major parties in that
seat**: a seat with an adjustment of +2 points has its ALP primary raised and
its LNP primary lowered such that the seat's two-party-preferred moves by 2
points. Minor-party primaries are untouched.

Why this and not the alternatives:

- It is the **same mechanism the statewide anchoring already uses** in
  `fit_seats_full.R`, which moves `d` points from LNP to ALP to hit the
  projection. Using one mechanism twice is easier to reason about than two.
- The adjustment was **fitted on two-party swing**, so applying it to a
  two-party quantity keeps the units it was estimated in. Spreading it across
  minor parties would apply a coefficient to something it was never fitted on.
- It leaves the minor-party field alone, which matters because the One Nation
  allocation and the independent handling are separate, already-fraught
  mechanisms that this must not silently perturb.

**The conversion factor is not a free parameter.** Moving `x` points of primary
vote from LNP to ALP moves the two-party figure by `x` only if the flow between
them is one-for-one. It is not; the correct shift is derived from the seat's own
preference flows, and it is computed, not assumed. If it cannot be derived
cleanly the port is abandoned rather than approximated.

## What is measured

The **candidate model's** error, on the two backtests built today:

- **NSW 2023** — 88 seats, flow matrix from 2019, truth from the NSWEC's
  declarations.
- **Federal, six pairs** — 886 division-pairs, each flow matrix from the
  previous election, truth from the AEC's `Elected` column.

Both, because today showed one election can say the opposite of six.

Arms: **A** the candidate model as published, **B** with the adjustment.
Metrics: Brier, log score, calibration slope, winner accuracy.

**Federal note.** `fed_swing` does not exist for federal elections, so the
federal backtest **cannot test this component at all**. It is run anyway as a
guard: arm B must come out identical to arm A there, because the adjustment has
nothing to act on. **If it differs, the implementation is wrong**, and that is
the most useful thing the federal run can tell us.

So the decisive evidence is NSW 2023 — **one election, 88 seats**. That is
exactly the sample size that misled us today, and it is stated here in advance:
a pass on NSW alone is weak evidence, and the write-up must say so.

## Decision rule, fixed now

- **Adopt** if the Brier improvement on NSW 2023 exceeds **2 SE** of the paired
  per-seat difference, **and** the federal arms are identical, **and** the
  calibration slope does not move away from 1.
- **Keep A** otherwise.

## Refusals

- **M1 — the federal identity check is a hard gate, not a diagnostic.** If arm B
  differs from arm A on federal data, stop. There is no `fed_swing` there and
  any difference is a bug, whatever the NSW numbers look like.
- **M2 — no re-deriving the conversion to improve the score.** The primary-to-
  two-party factor is computed from the seat's flows once. If the result is
  disappointing, the factor is not revisited.
- **M3 — the two-party cross-check may not be used as evidence.** It already
  uses this adjustment, so it will agree with itself. Only the candidate model's
  own error counts.
- **M4 — a single-election pass is reported as a single-election pass.** No
  claim that the component is validated in the candidate model on the strength
  of 88 seats. Today's independent work improved by 1.46 SE on one election and
  degraded by 2.52 SE on six.
- **M5 — the Victorian forecast must not move by more than 2 seats** in any
  party's median without stopping to report it. This is a seat-level
  redistribution of swing, not a change in the statewide total.
