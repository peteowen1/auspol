# The surge is refused, and the top end cannot be fixed from vote history

2026-08-25. Against `docs/plans/prereg-insurgency-surge.md`, committed before
the mechanism was implemented.

## Verdict: REFUSED on the pre-registered gate

| criterion | result | |
|---|---|---|
| 1. no reliability bucket outside its 95% CI | 2 of 7 outside | **FAILS** |
| 2. ≥50 seats above 0.99 **and** top bucket's outcome CI covers what was said | 394 seats ✓; said 99.7% vs CI [94.7, 98.4] | **FAILS** |
| 3. pooled log not worse by >0.02 | **0.4135** vs incumbent 0.4233 | passes |
| **refusal gate: the eight named misses must move** | **mean P = 0.0054**, threshold 0.01 | **REFUSE** |

The surge beats flat `shrink = 0.10` on log score and matches it on Brier
(0.0907 vs 0.0905) and accuracy (88.1% vs 88.0%). It is refused anyway, because
the seats it was built for did not move.

## Four mechanisms, nine seats, none fixed

P(we gave the party that actually won):

| seat | baseline | flat `shrink` | per-seat | surge | actual |
|---|---:|---:|---:|---:|---|
| Denison | 0 | 0.0000 | 0.0000 | 0.0000 | IND (Wilkie) |
| Lyne | 0 | 0.0000 | 0.0000 | 0.0004 | IND (Oakeshott) |
| Melbourne | 0 | 0.0296 | 0.0494 | 0.0352 | GRN (Bandt) |
| Fairfax | 0 | 0.0002 | 0.0002 | 0.0000 | OTH_RIGHT (Palmer) |
| Indi | 0 | 0.0000 | 0.0000 | 0.0004 | IND (McGowan) |
| New England | 0 | 0.0542 | 0.0948 | 0.0000 | LNP (Joyce) |
| Warringah | 0 | 0.0084 | 0.0030 | 0.0060 | IND (Steggall) |
| Curtin | 0 | 0.0020 | 0.0008 | 0.0016 | IND (Chaney) |
| Fowler | 0 | 0.0000 | 0.0000 | 0.0000 | IND (Dai Le) |

Best mean is per-seat shrink at 0.0165. **Four of nine remain exactly zero under
the surge.**

## Why it is structural rather than a tuning problem

| | |
|---|---|
| winners polling **zero** at the previous election | 2 of 9 |
| winners polling under 5% | 2 of 9 |
| median gain the winner needed | **+26.3 pts** |
| median lead they had to overturn | **46.1 pts** |
| range of gains required | +13.3 to +41.6 |
| beyond +2 SD of the measured surge (>27.8) | **4 of 9** |

Chaney went 7.7% → 29.5% against a 46.5-point lead; Dai Le went **0.0%** →
29.5% against 54.5 points. The surge is `N(+15.6, 6.1)` because that is what
surges *average*. These nine are the extreme tail. Sizing the surge to catch
them would inflate every other seat's uncertainty — which is exactly what broke
the mid-range in the per-seat shrink arm.

**And several winners did not exist in the prior election's data at all.**
Steggall, Chaney and Dai Le were new candidates. A mechanism keyed on the
strongest *existing* non-major surges a Green from 8% to 24%, which does not
elect them. The model has no column for a candidate who was not there last time.

## What has now been tried, and measured, on the top end

- **flat `shrink`** — caps every seat at `1 - s/2` (0.9598 measured), charging
  672 low-risk seats for a risk carried by a few dozen.
- **wider `seat_sd`** — measured across 1.0–2.0 in
  `seat-calibration-2026-08-22.md`: "barely matters". Symmetric widening cannot
  flip a 30-point margin.
- **per-seat `shrink`** on a good risk model (out-of-sample AUC 0.878) — lifted
  the ceiling and kept the confident band calibrated, but broke the mid-range:
  buckets outside CI went 0 of 6 to 2 of 7.
- **surge mixture** — refused here.

**The conclusion is that vote history cannot see these events**, and that is a
finding rather than a failure of any one mechanism. `P(surge)` fitted on vote
history has out-of-sample AUC **0.326** — worse than random and inverted.

## The salience corpus has two problems, found while checking this

Pete asked whether Google Trends had actually been backtested. It has not been
backtested the way the claim implied.

**Sized properly, the federal signal is real:**

| election | AUC | SE | 95% CI | above chance |
|---|---:|---:|---|---:|
| 2019 | 0.823 | 0.142 | [0.55, 1.00] | 2.3 SE |
| 2022 | 0.854 | 0.089 | [0.68, 1.00] | 4.0 SE |
| 2025 | 0.964 | 0.053 | [0.86, 1.00] | 8.8 SE |
| pooled | ~0.87 | 0.055 | [0.76, 0.98] | 6.7 SE |

But:

1. **No state election has ever been tested.** The corpus is `fed2019`,
   `fed2022`, `fed2025` only. The live target is Victoria.
2. **Only three of six available federal pairs were used.** Vote data runs back
   to `fed2007`. There is no builder script and
   `output/ind-candidacies.csv` is **untracked**, so the corpus is not
   reproducible and the cutoff has no recorded reason. **Four of the nine hard
   seats — Denison, Lyne (2010), Indi, Fairfax (2013) — are in the missing
   elections.**
3. Only **63 of 299** candidacies (21%) have a fetched Trends response.
4. It predicts **breakout (≥20% of first preferences), not winning a seat.**

**Fetching the remaining federal candidacies barely helps**: SE moves 0.055 →
0.051. There are only 21 breakouts in the whole federal corpus, and the
positives bind, not the negatives. **More positives means more elections.**

## Next

Extend the candidacy corpus, with a tracked builder script:

- **fed2007–fed2016**, which the AEC publishes candidate-level and which
  contains four of the nine hard seats.
- **Victoria 2022 is already on disk** —
  `external/elections/vec-2022-vic-candidates.csv`, 731 candidates with names
  and first preferences, **119 of them independents**. No acquisition needed.
- **NSW 2023** (9 independent wins), **Victoria 2018**, **SA 2026** need
  equivalent files from their commissions.

That roughly triples the positive count and, for the first time, tests whether
the signal transfers to a state election — which is what the Victorian forecast
actually depends on.
