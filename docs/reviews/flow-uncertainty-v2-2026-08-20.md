# Flow uncertainty is real and measured. The only test available cannot see it.

Run 2026-08-20 against
[../plans/prereg-flow-uncertainty-v2.md](../plans/prereg-flow-uncertainty-v2.md),
committed before anything was scored.

**Verdict: KEEP A. The Brier difference is +0.03 SE.** Not adopted — and the
reason is the test, not the idea.

## The uncertainty is real and is now quantified

Across **10 full-preferential elections** (7 federal, 3 Victorian), the flow to
Labor varies:

| source | elections | mean | **sd between elections** | range |
|---|---:|---:|---:|---|
| Greens | 10 | 78.9 | **2.00** | 75.9–82.2 |
| Others | 10 | 54.7 | 3.70 | 47.2–58.7 |
| Other-right | 10 | 34.8 | 3.81 | 29.6–41.5 |
| Independents | 10 | 50.7 | 4.36 | 46.1–59.5 |
| **One Nation** | 8 | 36.3 | **10.38** | 20.1–50.2 |

The model treats every one of these as a **constant**. For the Greens that is
almost exactly right — a 2-point spread over a decade. For One Nation it is not:
their flow has ranged from **20% to 50%**, and they are the party whose seat
count is the most disputed number in the forecast.

## The result, and why it says nothing

| | arm A | arm B (flow uncertainty) |
|---|---:|---:|
| accuracy over 166 district-elections | 145 | 145 |
| Brier | 0.08879 | 0.08879 |

**Paired difference +0.00000, +0.03 SE.** One seat of 166 moved by more than
0.01 in probability; the largest single move was 0.0105.

The reason is immediate once looked for:

| election | total votes transferred | **One Nation's share of them** |
|---|---:|---:|
| VIC 2014 | 368,997 | **0.00%** |
| VIC 2018 | 422,118 | **0.00%** |
| VIC 2022 | 1,016,053 | **0.91%** |

**The party carrying almost all the flow uncertainty transferred no votes in two
of the three test elections and 0.9% in the third.** Perturbing a flow by 10
points does nothing when there is nothing flowing. What the test actually
measured is the effect of the *other* parties' uncertainty — Greens 2.00,
Others 3.70 — and those are small because those flows genuinely are stable.

So this is not evidence that flow uncertainty does not matter. It is evidence
that **Victoria's own history cannot test the case that matters**, in the same
way it could not test the One Nation allocation.

## Q5 fired, for a different reason than anticipated

The plan pre-committed that if the architecture absorbed the noise, that was a
valid finding not to be worked around. It did not — the noise reached the
simulation fine. What blocked it was the **corpus**: the test elections have no
One Nation to speak of.

That distinction matters, because the fix is different. An architectural
absorption would need the architecture changed. A corpus gap needs a corpus with
One Nation in it, and Victoria 2026 is the first Victorian election that will
have one.

## Where this leaves the forecast

The live model applies One Nation's flow — **33.7%**, the mean of the last five
observed — as an exact number, to a party polling near 20% statewide. On the
historical spread, a one-standard-deviation error in that single figure is
**10.4 points**, which is the difference between One Nation's preferences
splitting 26/74 and 46/54.

**Nothing in the published forecast expresses that.** It is a known unknown
stated as known, it is measured now rather than assumed, and no available
backtest can price it.

The honest options, neither taken here:

1. **Ship it unmeasured** on the strength of the measured spread, accepting that
   it cannot be validated before the election. This project's discipline refuses
   that, and refused it today for the seat-swing port on the same grounds.
2. **State it as a limitation on the page** — that the One Nation seat range
   assumes a preference flow known to vary by 10 points between elections.
   Honest, costs nothing, and does not pretend to a precision the model lacks.

Option 2 is a presentation change rather than a model change, and is recorded
for Pete rather than made unilaterally.
