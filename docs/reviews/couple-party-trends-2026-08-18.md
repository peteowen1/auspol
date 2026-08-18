# Do not couple the party trends. The sum is a symptom of an "Others" bias.

Run 2026-08-18 against
[../plans/prereg-couple-party-trends.md](../plans/prereg-couple-party-trends.md).
**No coupling was built.** Sizing the effect first, per the rule about sizing
before building, answered the question and the answer is don't.

## What the sum-to-100 failure actually is

Fitted shares sum to 100 only by luck — 94.1 for NSW 2027, which failed its
structural check and halted the daily pipeline. The pre-registered plan was to
couple the party fits so shares sum by construction.

Measured across **54 completed cycles** where the recorded results are
themselves complete, comparing each cycle's fitted endpoint against the actual
result:

| | mean FP MAE |
|---|---:|
| as fitted | **2.519** |
| renormalised to 100 | 2.849 |

**Renormalising makes first preferences worse by 0.33 points.** That is the
whole finding in one line: if scaling every party up to reach 100 hurts, the
shortfall is not spread evenly.

## Where the shortfall sits

| party | n | mean fitted | mean actual | bias |
|---|---:|---:|---:|---:|
| **OTH** | 54 | 7.80 | 11.41 | **−3.60** |
| LNP | 54 | 42.22 | 43.33 | −1.11 |
| ONP | 6 | 3.47 | 3.46 | +0.01 |
| GRN | 33 | 8.57 | 8.47 | +0.10 |
| ALP | 54 | 40.29 | 39.95 | +0.33 |

Mean |sum − 100| is 4.10 points and **"Others" accounts for 3.60 of it.**
Every other party is close to unbiased.

## Why that kills the pre-registered plan

A sum-to-100 constraint forces the deficit to be shared. It would take a
3.6-point shortfall that belongs to one party and redistribute it across four
that are already right — which is exactly what renormalising does, and exactly
why renormalising costs 0.33 MAE.

**The structural check was correct that something is wrong. It was wrong about
what.** The sum is a symptom; the disease is a bias in one party's trend.

Per decision rule 3, fixed in advance: a coupling that costs more than 0.02 MAE
is rejected, and it is worth recording that the independent fit is better
despite being structurally untidy. That is the outcome.

## What the bias does and does not reach

- **The published two-party figure: nothing.** Correcting the 3.6 points moves
  Victoria's two-party number by **−0.012**. "Others" flows to Labor at 48.9%,
  almost exactly even, so moving vote into it barely shifts the split.
- **The published first preferences: directly.** The page prints Others at
  11.1, and history says this model under-calls that party by about 3.6 points
  at a cycle endpoint.
- **The seat model: mostly not.** `fit_seats_full.R` scales the minor field to
  the forecast total and renormalises each seat, so a level error in OTH is
  largely absorbed.

## What to do instead

Not coupling. The candidate follow-up is the **"Others" trend itself** — why a
residual bucket that has grown for decades is fitted below its eventual value
at almost every cycle endpoint. Plausible causes, none tested:

1. The prior anchors OTH to the previous election while the real level drifts up.
2. Polls under-report minor parties, and the house-effect model cannot separate
   a bias shared by every firm from the truth.
3. Minor-party vote rises during a campaign, and the walk is too slow to follow.

Cause 2 is the interesting one, because a bias common to all pollsters is
invisible to a sum-to-zero house-effect constraint **by construction** — the
same structure that makes house effects identifiable is what hides an
industry-wide miss.

That deserves its own pre-registration. It is a bigger claim than a drifting
sum, and it would move a published number rather than tidying one.
