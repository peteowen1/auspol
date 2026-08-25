# `party_sd` resolves at last, and the answer is: it does not matter

2026-08-26. Against `docs/plans/prereg-party-sd-from-data.md`, and superseding
`party-sd-void-2026-08-25.md`, which reported the same question as VOID because
its criteria had no power.

## Verdict: TIE, 11 of 17, p = 0.332

Pre-registered bar: 13 of 17 to adopt, 8 or fewer to refuse, **9 to 12 declared
a tie in advance**.

| harness | pairs won by 2.33 |
|---|---:|
| WA | 4 of 7 |
| federal | 3 of 6 |
| Victoria | 2 of 2 |
| SA | 1 of 1 |
| NSW | 1 of 1 |
| **total** | **11 of 17** |

Mean per-pair log delta **−0.00459** (sd 0.01081, SE 0.00262, t = −1.75). Real
in sign, negligible in size, not separable from zero.

## What changed since yesterday

Nothing about the measurement. `party_sd = 1.50` still has no derivation
anywhere in the repo, and the realised statewide first-preference error over 139
party-cycles in 33 independent cycles is still **2.33**, still 2.9 SE away.

What changed is that `backtest_candidate_wa.R` added **seven pairs**, taking the
set from 10 to 17. On 17 clusters a sign test can reach p ≈ 0.049 at 13 of 17;
on the four clusters the earlier criteria were written against it bottomed out
at p = 0.125 no matter how cleanly the arms separated. **The question is now
decidable, and it decides against the change mattering.**

## It caught a false positive, which is the point

Measured on the federal corpus alone, `party_sd = 2.33` improved the log score
in **4 of 4** elections. That reads as a consistent effect and it would have
passed clause 3 of the original pre-registration. Across all seventeen pairs it
is 11 of 17 — a coin flip with a slight lean.

**Adopting on the federal-only evidence would have been adopting noise**, and
the only reason that did not happen is that the earlier experiment failed for a
different reason and was recorded as void rather than quietly shelved.

## Two costs that argue against adopting even the lean

- **Accuracy falls.** WA 87.3% → 86.7% (wa2005 loses two seats); fed2025 loses
  one. Pooled federal accuracy is unchanged at 87.9%.
- **Slopes drift further from 1 nearly everywhere.** Victoria 2018→2022 3.207 →
  3.398, NSW 1.553 → 1.604, WA 2005 1.829 → 2.970.

So the honest shape is a very slight scoring gain bought with a small resolution
cost.

## Decision

**`party_sd` stays at 1.50.** Not because 1.50 is right — it is undrived, and
2.33 is what the data says — but because changing it buys nothing measurable and
costs a little resolution.

That distinction is worth keeping: *"we measured it and it did not matter"* is a
different fact from *"nobody checked"*, and the second is what was true this
morning.

## What this does not settle

- **Whether the statewide draw is the right shape at all.** This tested one
  scalar against another. Per-party and per-region values were refused in
  advance on sample-size grounds (n = 14 to 34 rows, 3 to 8 cycles per region)
  and remain untested.
- **The forward-looking value.** 2.33 is the trend model's fitted-vs-actual gap
  on completed elections, where the polls are known. A live forecast at a
  horizon carries more, so 2.33 is a floor rather than an estimate.
- **Whether 17 pairs are 17 independent draws.** WA 1996 and federal 2025 are
  thirty years apart with different party systems; the sign test treats them as
  exchangeable and they are not.
