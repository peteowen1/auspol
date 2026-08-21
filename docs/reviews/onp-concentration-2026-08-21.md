# The federal record brackets South Australia's concentration. It does not second-source it.

Measured 2026-08-21. **Nothing changed.** `scripts/onp_concentration.R`.

This was run to put a second observation behind the number the Victorian One
Nation seat count now rests on: how concentrated its vote is across seats. It
does not deliver one, and the reason is worth more than the attempt.

## What was measured

One Nation's district-level first-preference spread across **15 federal
state-elections** where it contested five or more divisions and polled 3%+:

| | statewide | CV | SD, points |
|---|---:|---:|---:|
| federal median | ~6% | **0.482** | **2.53** |
| federal range | 3.8–8.9% | 0.232–0.523 | 1.20–4.64 |
| **South Australia 2026** | **22.9%** | **0.334** | **7.65** |

The model uses **0.327**, taken from South Australia.

## Why this is not a second observation

Federal One Nation polls 4–9%. Victoria is forecast near 20%. Carrying a
concentration across that gap requires knowing what stays fixed as a party
grows, and **the two obvious answers disagree by a factor of 4.4**:

| if the invariant is… | implied CV for SA at 22.9% |
|---|---:|
| the SD in points (additive) | **0.110** |
| the CV (multiplicative) | **0.482** |
| **what SA actually did** | **0.334** |

South Australia sits **between them**. So the federal record neither confirms
nor contradicts it — the extrapolations bracket the observation, which is a
weaker statement than it first appears but not a useless one:

- **South Australia is not an extreme choice.** Under either scaling rule it
  falls inside, and it sits comfortably within the federal CV distribution's
  10th–90th percentile (0.309–0.522).
- **It is at the LOW end of that distribution**, against a federal median of
  0.482 and Victoria's own federal-2025 reading of **0.514**. Taken naively that
  says the model may be under-concentrating One Nation, and therefore
  understating its seats.
- **Taken naively is the error.** Victoria's federal 0.514 comes with an SD of
  2.97 points at a 5.8% mean. Applying that CV at 20% implies an SD above 10
  points, which is larger than anything ever observed.

## What this leaves

**South Australia 2026 remains the only reading at the level Victoria is
forecast to reach**, and that is why the model uses it — not because one
election is enough, but because the alternatives require a scaling assumption
the data cannot settle.

The honest bound on the concentration is roughly **0.11 to 0.48**, and that is
enormous in seat terms: concentration decides how many seats One Nation leads,
and leading is most of winning. A model at 0.11 would give it almost no seats;
one at 0.48 would give it a great many.

**The next thing worth doing is sizing that**, by running the seat model at both
ends of the bound and reporting what One Nation's range does. That converts an
unquantified assumption into a stated sensitivity, which is what should be on
the page beside its seat number. Not done here.

## A correction to how this was framed going in

This was proposed as putting "a second observation behind the concentration".
It cannot: an observation at 6% is not an observation of the same quantity as
one at 23% unless the scaling is known, and it is not. The framing assumed the
answer would transfer, which is the same mistake as reading a conversion rate
off four seats — measured at the wrong scale rather than the wrong sample size.
