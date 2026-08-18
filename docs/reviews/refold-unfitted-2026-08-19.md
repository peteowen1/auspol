# Folding an unfitted party back into "Others" works, and for the right reason

Run 2026-08-19 against
[../plans/prereg-refold-unfitted.md](../plans/prereg-refold-unfitted.md),
committed before anything was built. `scripts/test_refold.R`.

**Adopted.** Total first-preference MAE **1.8617 → 1.8246**, a gain of
**0.0371** against a pre-registered bar of 0.02.

## The defect

When a party is polled but not fitted, `OTH` means two different things inside
one cycle: firms that break the party out report `OTH` excluding it, firms that
fold it in report `OTH` including it. The model fits one column across both and
reads part of the gap as a house effect. This is the remedy the
[inclusion-floor write-up](inclusion-floor-2026-08-19.md) said was unqueued.

`unfold_others()` already handles the opposite case and cannot help here:
imputing a party *out* of `OTH` needs a fitted trend, and an unfitted party has
none. Going the other way needs no model — the party's share is printed on
exactly the rows being corrected.

## Result

46 rows refolded across 12 cycles. Both arms fit the same parties on the same
cycles; only `OTH`'s values differ, so n is equal **by construction** — and the
script asserts that rather than assuming it, which is what went wrong in the
inclusion-floor run.

| | off | on | gain |
|---|---:|---:|---:|
| total FP MAE (139 rows) | 1.8617 | **1.8246** | **+0.0371** |
| `OTH` MAE (33 rows) | 2.5800 | 2.4238 | +0.1562 |
| the 12 refolded cycles (50 rows) | 1.6510 | 1.5479 | +0.1031 |

The whole gain is `OTH`, which is arithmetically exact: 0.1562 × 33 = 5.15
points of error removed, against 0.0371 × 139 = 5.16. Nothing else moves,
because nothing else is touched.

## The check that matters: is this a definition fix or just inflation?

Refolding always raises the `OTH` *inputs*, and usually the fitted endpoint with
them — though not always: `vic 2006` (7.26 → 6.98) and `vic 2018` (10.19 →
10.14) both move **down**, presumably a knock-on through the house-effect
estimates, and both got slightly worse. They sit inside the "below actual"
bucket below, whose mean does not surface them. `OTH` is also known to be fitted
low
(−1.02 on average, see [others-bias](others-bias-2026-08-18.md)). So an obvious
alternative explanation is that this helps for no better reason than pushing a
low number up, which would stop working the moment the bias reversed.

It is not that. Split by whether the fit was already below or above the actual:

| | n | mean fitted (off) | mean actual | mean raise | mean error change |
|---|---:|---:|---:|---:|---:|
| fit was **below** actual | 9 | 10.51 | 13.10 | +0.69 | **−0.630** |
| fit was **above** actual | 2 | 10.74 | 9.25 | +0.26 | **+0.257** |

**Where the fit was already too high, refolding made it worse.** Blanket
inflation would have helped everywhere. (Two rows inside the "below" bucket also
got worse, noted above — the bucket means are not unanimous.) It helps where the definition mismatch
was pushing `OTH` down and hurts where something else was pushing it up, which
is what a definition fix looks like and not what an artefact looks like.

Eleven rows is few, and two of them carry the "hurts" case. The direction is
right; the evidence for it is thin, and that is worth saying rather than
presenting a 9-vs-2 split as decisive.

## What it does to the published forecast: nothing

Predicted in the plan before the run, and confirmed. One Nation **is** fitted in
Victoria 2026 (18 polls against a floor of 8), so nothing in the live cycle is
refolded and the published numbers are unchanged.

To be precise, because the first draft of this section overstated it: Victoria's
*validation* cycles **are** touched — One Nation is refolded in 2018 and 2022,
moving their reported endpoint sums from 100.1 to 100.3 and 99.8 to 100.0. It is
only the live 2026 cycle that sees no change. This is a fix to historical fits,
not an improvement to what the page shows.

The biggest single beneficiaries:

| cycle | party | rows | fitted off → on | actual |
|---|---|---:|---|---:|
| SA 2022 | ONP | — | 12.5 → 14.4 | 15.2 |
| NSW 2023 | ONP | 7 | 15.3 → 16.9 | 18.0 |
| NSW 2019 | ONP | — | 8.0 → 9.2 | 15.5 |
| WA 2025 | ONP | — | 10.2 → 11.3 | 14.3 |

NSW 2023 — the cycle that started this — moves from 15.30 to 16.90 against an
actual of 17.96. Better, still short.

## Limits

- **Detection is arithmetic, not certain.** A row is treated as breaking the
  party out when its reported shares already sum to 97–103 *with* the party
  present. That is the same inference `folded_rows()` already makes in the
  other direction, and a poll that is simply a few points over on its totals
  would be misread.
- **Only 46 rows in 12 cycles.** The correction is narrow by design.
- **It does not close the NSW 2023 gap**, only narrows it. `OTH` is still 1.1
  short there, and the Morgan-versus-everyone-else difference in *total* minor
  vote (19.7 against 15.5) is a real house effect on the minor field that this
  does not address.
