# Pre-registration v2: preference flows are treated as exact, and now we can measure how wrong that is

Written 2026-08-20, **before anything is fitted or scored**. Committed before running.

Supersedes [prereg-flow-uncertainty.md](prereg-flow-uncertainty.md), which was
recorded as **blocked** because the flow matrix rested on one election and the
candidate model had never been backtested. Both are now false.

## The defect, now quantified

The seat model applies preference flows as **constants** — one number per source
party, identical in all 20,000 simulation draws. Across **10 full-preferential
elections** (7 federal, 3 Victorian) the flow to Labor varies:

| source | elections | mean | **sd between elections** | range |
|---|---:|---:|---:|---|
| Greens | 10 | 78.9 | **2.00** | 75.9–82.2 |
| Others | 10 | 54.7 | 3.70 | 47.2–58.7 |
| Other-right | 10 | 34.8 | 3.81 | 29.6–41.5 |
| Independents | 10 | 50.7 | 4.36 | 46.1–59.5 |
| **One Nation** | 8 | 36.3 | **10.38** | 20.1–50.2 |

**The Greens flow is nearly a constant and the model is right to treat it as
one. One Nation's is not** — it has ranged from 20% to 50%, and it belongs to
the party whose seat count is the most disputed number in the forecast.

`ALP` and `LNP` appear in the data with large spreads but are excluded from this
work: a major party is only excluded in an unusual seat, so those figures are
noise rather than a flow anyone relies on.

## Voting systems do not mix

NSW uses **optional** preferential voting and exhausts about 12% of ballots;
federal, Victoria, SA and WA are **full** preferential with no exhaustion. The
spreads above are computed on full-preferential elections only. NSW transfers
must not be pooled with them, and the NSW backtest is therefore a **secondary**
check here, not the primary one.

## The change under test

Each simulation draw perturbs the flow matrix by a per-source-party offset drawn
from `N(0, sd)` with the sd measured above — **not fitted, not tuned**, taken
from the between-election spread of actual results. Flows are clamped to
[5, 95].

## What is measured

The two Victorian backtests, which are full-preferential and are the state being
forecast:

- **VIC 2014 → 2018**, 88 districts
- **VIC 2018 → 2022**, 78 districts

and **NSW 2023** as a secondary check, reported but not decisive because its
voting system differs.

Arms: **A** as published, **B** with flow uncertainty, **S** a single temperature
fitted leave-one-election-out. Metrics: Brier, log score, calibration slope,
winner accuracy.

## Decision rule, fixed now

- **Adopt B** if the Brier improvement over A exceeds **2 SE** of the paired
  per-seat difference **pooled over both Victorian pairs**, and it clears Q1.
- **Keep A** otherwise.

## Refusals

- **Q1 — the shrinkage control again.** Adding any noise to an overconfident
  model improves its calibration. B must beat a plain temperature, or its
  structure is doing nothing and the honest fix is the temperature. This is the
  refusal that killed the independent-emergence work and it applies unchanged.
- **Q2 — no per-party tuning.** The sds are the measured between-election
  spreads. If One Nation's 10.38 produces a worse result it is reported, not
  shrunk until it helps.
- **Q3 — the one-way ratchet.** Report the effect on Victoria's One Nation
  expected seats. Widening the flow of a party that is behind lets it cross
  thresholds it otherwise could not; if expected seats rise by more than
  **1.5**, stop and report.
- **Q4 — a Victorian win does not license a federal claim, or vice versa.**
  Report both, decide on Victoria.
- **Q5 — the statewide anchoring may absorb this entirely, and that is a valid
  outcome.** An earlier sensitivity found a 1 sd flow shift moved the two-party
  projection by 0.88 points and Victorian seats by **zero**, because
  `simulate_seat_contests()` uses only `statewide_draws[s, ] - centre`. If the
  same happens here, the finding is that flow uncertainty cannot reach the seat
  outcomes through the current architecture — which is worth knowing and must
  not be worked around by moving the noise somewhere it does show up.

## What this cannot see

Whether the **central** flow estimates are right. This is spread only. And the
sds are between-election variation, which bundles genuine change over time with
measurement differences between commissions — no attempt is made to separate
them.
