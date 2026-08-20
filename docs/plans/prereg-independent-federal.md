# Pre-registration v4: the same three mechanisms, on 886 division-pairs instead of 88 seats

Written 2026-08-20, **before anything is refitted on federal data**. Committed
before running.

The **model is unchanged** from
[v3](prereg-independent-two-mechanism.md). Only the corpus and the
cross-validation change. Nothing else may move: if the structure is altered
here, the comparison to v3 is worthless.

## Why re-run

v3 was the best of three rounds and was still not adopted:

| | v1 | v2 | **v3** |
|---|---:|---:|---:|
| Brier vs A | 1.03 SE | 1.01 SE | **1.46 SE** |
| vs the temperature control | 0.66 SE | 0.65 SE | **1.06 SE** |
| calibration slope | 0.632 | 0.627 | **0.974** |

1.46 SE against a 2 SE bar is what a real effect looks like when there is not
enough data to prove it — **or** what noise looks like. Those are
indistinguishable at 88 seats, 9 sitting independents and **one** observed
non-recontest. The federal corpus resolves it either way.

## The corpus

Seven AEC elections, 2007–2025, giving **six consecutive pairs and 886 matched
division-pairs** (97% match rate):

| pair | matched | new | gone |
|---|---:|---:|---:|
| 2007→2010 | 147 | 3 | 3 |
| 2010→2013 | 150 | 0 | 0 |
| 2013→2016 | 147 | 3 | 3 |
| 2016→2019 | 143 | 8 | 7 |
| 2019→2022 | 150 | 1 | 1 |
| 2022→2025 | 149 | 1 | 2 |

Divisions are matched **by name**. Two limitations, stated now:

- **Boundaries move even when names do not.** A redistributed division's
  previous first preferences are not strictly its own. This adds noise and, for
  a badly redistributed seat, error. It is not corrected here because notional
  previous results on new boundaries are not in the repo; the effect is assumed
  to be noise rather than bias, and that assumption is recorded as an
  assumption.
- **Renamed divisions are dropped**, not tracked. 27 pair-observations of 913.

## What changes besides the corpus

**Leave-one-ELECTION-out replaces leave-one-seat-out**, for the model fit and
for the temperature control alike. With one election that was impossible; with
six pairs it is both feasible and strictly stronger, because it tests whether
parameters transfer across electoral environments rather than merely across
seats within one. It is also what the rest of this repo already uses — the
seat-swing predictors and the projection mix are both validated this way.

**Simulation count drops from 20,000 to 4,000 per seat.** 886 seats at 20,000
draws each is not tractable in one sitting. At 4,000 the Monte Carlo standard
error on a probability near 0.5 is about 0.008, an order of magnitude below the
effects being measured. Reported so the choice is visible, and the same count is
used for **every arm** so it cannot favour one.

## Everything else carries over verbatim

Three arms — **A** as published, **B** the three mechanisms, **S** the single
temperature. Brier, log score, calibration slope, winner accuracy. Truth is the
AEC's **`Elected`** column, never our own exclusion of the actual votes. Flow
matrices come from the **previous** election in each pair, never the one being
predicted, and that is asserted in code.

Decision rule: **adopt B** if the Brier improvement over A exceeds **2 SE** of
the paired per-seat difference, **and** the slope moves toward 1, **and** it
clears E1. Refusals **E1–E5**, **G1** and **H1–H3** unchanged.

## Added refusals for this corpus

- **J1 — federal is not Victoria.** A win here licenses adoption into the
  seat model, not a claim that the rates apply unchanged to a state election.
  Federal and state independent dynamics differ, and the corpus cannot see that.
  Report the per-election spread of the fitted parameters; if they vary wildly
  across the six pairs, say so rather than quoting a pooled number as settled.
- **J2 — 2022 must not carry the result alone.** It elected ten independents,
  far more than any earlier election, and it is the single most influential
  election in this corpus. **Report the leave-one-election-out result with 2022
  held out separately.** If the effect exists only when 2022 is in the training
  set, that is a finding about 2022, not about independents.
- **J3 — no boundary-change rescue.** If the result disappoints, redistributions
  are not to be invoked as the explanation and then corrected for until it
  improves. The limitation is stated above, in advance, and applies equally to
  every arm.
