# Four fields we were not reading predict seat swing. Adopted.

Run 2026-08-19 against
[../plans/prereg-seat-swing-predictors.md](../plans/prereg-seat-swing-predictors.md),
committed before anything was measured. `scripts/test_seat_swing_predictors.R`.

**Adopted.** Out-of-sample seat-swing MAE **3.948 → 3.425**, a gain of **0.523**
against a pre-registered bar of 0.10.

## What was being ignored

`load_seats()` read five fields from the anchor's seat files and ignored six.
Four of the ignored ones are standard seat-level predictors the anchor had
already computed:

| field | Vic 2022 | NSW 2023 | 2026 |
|---|---:|---:|---:|
| `fTransposedFederalSwing` | 88 | 92 | 88 |
| `bRetirement` | 18 | 21 | 20 |
| `bSophomoreCandidate` | 21 | 13 | 22 |
| `bSophomoreParty` | 11 | 4 | 8 |

The seat model treated every seat's departure from the statewide swing as
**noise** — one common spread applied to all 88.

## Why this was testable when the last several things were not

Both halves were already in the repo and join cleanly on seat name:

- **Predictors** come from the file written *before* an election.
- **The outcome** — that election's actual per-seat two-party swing — is
  `fPreviousTppSwing` in the file written for the *following* cycle.

88 Victorian and 92 NSW seats: **180 seats across two elections in two states**,
which is what makes leave-one-election-out possible.

## Result

Fitted on all 180 seats, for signs:

| term | coefficient | t |
|---|---:|---:|
| transposed federal swing | **+0.708** | 8.5 |
| retirement | **−1.396** | −2.1 |
| sophomore candidate | **+2.559** | 3.0 |
| sophomore party | +1.609 | 1.2 |

Leave-one-election-out, the pre-registered criterion:

| held out | n | baseline MAE | model MAE | gain |
|---|---:|---:|---:|---:|
| Victoria 2022 | 88 | 3.351 | 3.138 | **+0.213** |
| NSW 2023 | 92 | 4.518 | 3.699 | **+0.819** |
| **pooled** | 180 | **3.948** | **3.425** | **+0.523** |

All four refusal conditions clear:

- **R1** — the gain is positive in **both** held-out elections. With only two,
  that is the difference between a predictor and a coincidence.
- **R2** — every sign is what psephology expects, and this was required in
  advance rather than observed after: a retiring member costs their party,
  first-term members gain, and a seat swinging federally swings the same way at
  state level.
- **R3** — residual spread falls from **5.089 to 3.996**.
- **R4** — Labor's median seat count moves by **+1**, against a bar of 3.

## The anchor that mattered most

Before believing any of it, the outcome column had to mean what I assumed.

- Victoria 2022 comes out at a mean seat swing of **−2.94**, against the known
  statewide result of −2.60 (Labor 57.60 → 55.00).
- NSW 2023 comes out at **+5.73** to Labor, in the year Labor took government
  after twelve years.

And after wiring it in, `S1` still reports **56 classic seats at zero swing
against 2022's actual 56**. The adjustment sums to zero across seats by
construction, so it redistributes the statewide swing rather than adding to it —
and the zero-swing baseline is where that would show up if it were wrong.

## What changed in the published forecast

| | before | after |
|---|---:|---:|
| Labor seats (median) | 39 | **40** |
| 90% range | 23–51 | 25–52 |
| chance of a Labor majority | 29.7% | **27.7%** |

The median rises by one while the majority chance *falls*, which looks
contradictory and is not: the distribution narrowed, so less of it sits above
the 45-seat threshold. That narrowing is the point — variance that was being
modelled as noise is now explained.

## What this does NOT reach, and it matters

**The candidate-level model is completely unchanged.** `fit_seats_full.R` does
not call `simulate_seats()`; it builds primary-vote shares and runs a
preference count, so a two-party swing adjustment does not enter it. Every
by-party number on the page — Greens 5, One Nation 3, independents 0 — is
exactly as before.

So the headline Labor seat count improves and the by-party breakdown does not.
Extending this to the candidate-level model means converting a two-party swing
into primary-vote shares, which is a real modelling question and not a wiring
job. Queued, not attempted.

Also unchanged, and worth saying plainly since three recent experiments were
about it: **this does nothing for One Nation or independents.** The outcome here
is two-party swing between Labor and the Coalition.

## Limits

- **Two elections.** Each leave-one-out fit trains on a single state.
- **`soph_party` is not significant** (t = 1.2). It is kept because the model
  was fixed before fitting; dropping a term for failing a test it was never
  required to pass is the selection this repo's discipline exists to prevent.
- **The transposed federal swing is itself modelled** by the anchor, not
  measured. If it is wrong, this inherits that — and it is by far the strongest
  term, so that dependency is real.
