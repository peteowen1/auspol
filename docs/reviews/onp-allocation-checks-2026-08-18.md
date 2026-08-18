# The One Nation allocation survives both pre-registered checks

Run 2026-08-18 against
[../plans/prereg-onp-allocation-vic.md](../plans/prereg-onp-allocation-vic.md),
committed as `19d772a` before the run.

## Check 1 — does the ordering replicate across states? **PASS**

Form C (`ONP ~ Greens share`) refit on each state's 2025 federal divisions
separately, then applied to Victoria's 38. Criterion fixed in advance: the
Greens coefficient must be **negative in all three** of NSW, Queensland and
Western Australia.

| state | divisions | intercept | GRN coef | applied to VIC, MAE |
|---|---:|---:|---:|---:|
| NSW | 46 | 6.709 | **−0.1190** | 2.169 |
| QLD | 30 | 11.484 | **−0.3645** | 2.965 |
| WA | 16 | 8.751 | **−0.1192** | 2.574 |
| VIC (own fit) | 38 | 6.834 | −0.0968 | 2.114 |

Uniform baseline on Victoria: 2.267.

**All three are negative.** Every state independently agrees One Nation is
weakest where the Greens are strongest — which is the property the SA-fitted
form lacked and the reason it had One Nation winning Richmond.

Two things worth noting beyond the pass:

- **NSW transfers almost as well as Victoria's own fit** (2.169 against 2.114),
  which is what a real relationship looks like rather than a local artefact.
- **Queensland's slope is three times steeper** (−0.3645) and transfers worst
  (2.965). The direction replicates; the magnitude does not. That is an
  argument for using Victoria's own coefficient, which is what the model does,
  and against treating the slope as a national constant.

## Check 2 — does the magnitude transfer? **PASS, narrowly**

Criterion: SA 2026's relative spread and Victorian federal One Nation's, each
normalised to their own mean, within **1.5×** on interquartile range.

| source | statewide mean | relative IQR | relative range |
|---|---:|---:|---|
| SA 2026 state | 22.97% | 0.440 | 0.396 – 1.632 |
| VIC 2025 federal | 5.57% | 0.620 | 0.184 – 2.500 |

**Ratio 1.41×**, inside the 1.5 bar but not comfortably.

The direction is the expected one and matters: **the spread is wider at a lower
statewide level.** One Nation at 5.6% varies far more between seats, relatively,
than One Nation at 23%. Since Victoria is forecast at 20.9% — much closer to
SA's 22.97% than to the federal 5.57% — taking the spread from SA is both the
better-matched and the more conservative choice.

## Decision

Per the rule fixed in advance: **both pass, so the construction stands** —
order from the Victorian federal fit, magnitude quantile-mapped onto SA's
observed spread — **and the seat probabilities publish with the 0.122 MAE
caveat stated**.

That caveat is not a formality. The ordering beats a uniform allocation by
0.122 MAE, which is real and small. **Trust the One Nation seat total more than
any individual One Nation seat.**

## What is still not tested, and cannot be

Nothing here validates the *combination*. Order comes from Victorian federal
2025, magnitude from SA 2026, and no election has ever paired a large One
Nation vote with Victorian state boundaries. That is the whole reason the
construction is assembled from two sources, and it is untestable before
28 November 2026.
