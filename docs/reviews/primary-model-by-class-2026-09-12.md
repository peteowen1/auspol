# The primary model, class by class: what works, what doesn't, and why

**2026-09-12.** Written to answer Pete's questions: where does each of
ALP/LNP/GRN/ONP/IND/OTH struggle most, which seats predict worst for them, why,
can we fix it -- and should the classes have separate models.

Everything here is leave-one-pair-out over 13,352 cells and 22 pairs, and every
seat-level number is against a baseline run at the SAME git SHA. Where a stale
baseline is quoted it says so.

---

## 1. What works, and where

Two changes were built. **They behave differently and should be judged
separately**, which only became visible by running the 2x2 on South Australia.

### The SD model (`AUSPOL_XGB_PRIMARY_SD`) -- the surge's replacement

Predicts the per-cell primary SD instead of firing a hazard at one candidate.
Seat log loss against matched baselines:

| pair | seats | baseline | SD model | delta | |
|---|---|---|---|---|---|
| nsw2019 | 93 | 0.4113 | **0.3479** | **-0.063** | big win |
| sa2026 | 47 | 0.5492 | **0.5226** | **-0.027** | helps |
| fed2022 | 150 | 0.3346 | 0.3333 | -0.001 | helps |
| vic (3 pairs) | 239 | 0.2392 | 0.2404 | +0.001 | flat |
| qld2024 | 93 | 0.3254 | **0.3196** | **-0.006** | helps |
| nsw2023 | 88 | 0.2740 | 0.2796 | +0.006 | hurts |

**Seat-weighted so far: -0.0104 over 710 seat-elections**, five of seven
measured pairs improving. Net positive and no longer carried by one
jurisdiction. qld2020 and WA's seven pairs outstanding.

The nsw2019 result is the clearest evidence the mechanism is right:
accuracy identical (86/93), **Brier essentially unchanged (0.0655 -> 0.0652)**,
log loss down 15%. Brier caps the cost of a confident miss and log loss does
not, so a gain that appears in one and not the other is a gain in the
overconfident tail -- exactly what widening is supposed to buy.

**Where it does NOT help, and why that is correct.** Victoria has zero
independent-held seats, so a model that widens non-major uncertainty has
nothing to act on. A claimed gain there would be more suspicious than none.

**Where it hurts.** nsw2023, and the harness's own IND/non-IND split localises
it: the nine independent wins improve (Brier 0.1848 -> 0.1693) while the other
79 seats degrade (0.0811 -> 0.0843). Restricting to IND only made it slightly
WORSE (0.2803), which rules out "irrelevant minor classes" as the cause. The
real mechanism: **widening an independent raises their win probability in every
seat they contest, not only the ones they win**, and they lose most of them.

### The v7 primary model -- jurisdiction-split, NOT yet shippable

| | seats | baseline | v7 | delta |
|---|---|---|---|---|
| federal, 7 pairs | 1,036 | 0.30099 | **0.28789** | **-0.013** |
| sa2026 | 47 | 0.5492 | 0.6202 | **+0.071** |

Seven federal pairs improved, none regressed. South Australia regressed hard
and lost two seats of accuracy. **That split is unexplained and is the main
open question.** A hypothesis worth testing: SA's salience corpus is thin (173
governed candidates, 79% exactly zero), so the salience features are noisier
there than anywhere else.

---

## 2. Should the classes have separate models?

**Already answered for one split, and the answer was yes.** `v7e` fits
poll-anchored (ALP/LNP/NAT/GRN/ONP) and candidate-driven (IND/OTH/OTH_RIGHT)
separately and beat the single model 3.8710 vs 3.8746 RMSE, with the two groups
behaving very differently (within-group RMSE 4.10 vs 3.49).

**Whether to split further is NOT yet tested.** The mechanism that made the
first split work is specific: the objective is squared error in points of vote,
so a single model spends its tree budget where the variance is. Labor and
Liberal residuals run ~5 points; independents sit near zero. That argument
applies again inside each group, but with force that has to be measured:

- **ALP vs LNP separately.** Weak prior. Their error profiles are nearly
  identical (RMSE 4.82 and 5.11, bias -0.14 and -0.26, both 0% systematic), and
  they are mirror images of the same two-party contest -- a feature that
  predicts one predicts the other. Cheap to test, low expected gain.
- **GRN and ONP separately.** Stronger prior, for a concrete reason: they are in
  the poll-anchored group but are NOT two-party. GRN RMSE 2.58 and ONP 3.02
  against ALP/LNP's ~5, so they contribute little to the pooled objective and
  will be under-served by it -- the same argument that justified the first
  split, one level down. **ONP is also the only class with a correctable bias
  (see below), which a dedicated model could absorb.**

**Recommended test**: three groups rather than two -- majors (ALP/LNP/NAT),
polled-minors (GRN/ONP), candidate-driven (IND/OTH/OTH_RIGHT). One run.

---

## 3. Where each class struggles

### Error by class, points of primary vote

| class | cells | mean actual | RMSE | bias | RMSE / mean |
|---|---|---|---|---|---|
| LNP | 2,050 | 38.7 | 5.11 | -0.26 | 0.13 |
| ALP | 2,050 | 37.1 | 4.82 | -0.14 | 0.13 |
| **IND** | 2,050 | **4.2** | **4.67** | -0.07 | **1.11** |
| OTH_RIGHT | 1,689 | 4.9 | 3.25 | -0.14 | 0.66 |
| ONP | 1,506 | 3.6 | 3.02 | **+0.32** | 0.84 |
| GRN | 2,050 | 10.1 | 2.58 | -0.04 | 0.26 |
| OTH | 1,957 | 2.2 | 1.86 | +0.30 | 0.84 |

**In absolute points the majors are worst; relative to what they poll,
independents are far worst** -- the error is larger than the quantity being
predicted. That is the class to work on, and it is where the SD model and the
salience work have been aimed.

### Is any of it a correctable bias? Mostly no -- with one exception

Conditioning on the ACTUAL result shows every class badly low at the top (IND
-10.4 at 35+, ONP -18.6, OTH_RIGHT -10.7). **That table is misleading and
should not be acted on**: under squared loss the optimal forecast is the
conditional mean, so cells that turned out high were always going to be
under-predicted. Shrinkage toward the mean is correct behaviour.

The decision-relevant cut conditions on what we PREDICTED, which is what a
forecaster actually has in advance:

| class | pred 2-5 | 5-10 | 10-20 | 20-35 | 35+ |
|---|---|---|---|---|---|
| ALP | | +0.66 | +0.10 | -0.05 | -0.23 |
| GRN | -0.11 | 0.00 | -0.11 | -0.13 | +1.48 |
| IND | -0.33 | -0.24 | -1.23 | +0.85 | -1.45 |
| LNP | | | +0.15 | -0.06 | -0.41 |
| **ONP** | **+0.26** | **+0.67** | **+1.05** | **+1.41** | |

**The model is calibrated conditional on its own prediction, and there is no
level bias to correct -- except One Nation.** ONP drifts monotonically upward
with the prediction: the more we forecast, the more we over-forecast, reaching
+1.41 at the 20-35 band. That is a real, fixable, systematic error.

### By jurisdiction, RMSE

| class | fed | nsw | qld | sa | vic | wa |
|---|---|---|---|---|---|---|
| ALP | 4.54 | 5.24 | 3.97 | **6.73** | 4.29 | 5.74 |
| GRN | 2.70 | 2.03 | 2.52 | 2.11 | 2.47 | 2.65 |
| IND | 4.34 | 5.70 | **3.02** | 5.49 | 5.22 | 5.17 |
| LNP | 4.85 | **6.37** | 3.61 | 6.06 | 4.25 | 6.07 |
| **ONP** | 2.45 | 2.63 | 3.80 | **8.55** | -- | 2.32 |
| OTH | 1.39 | 2.51 | 1.47 | 3.10 | 1.86 | 2.67 |
| OTH_RIGHT | 2.91 | **5.62** | 2.96 | 2.68 | 2.37 | -- |

Two outliers dominate:

- **One Nation in South Australia: 8.55 against 2.32-3.80 everywhere else.**
  This is the sa2026 breakthrough -- four seats won -- and it is the single
  worst class-jurisdiction cell in the model. It is also where the v7 primary
  regressed, so the two findings are probably the same problem.
- **The minor right in NSW: 5.62.** The Shooters, Fishers and Farmers winning
  Orange, Barwon and Murray in 2019.

### The worst individual cells, and what they have in common

| class | worst miss | predicted | actual |
|---|---|---|---|
| IND | wa2001 Pilbara | 13.9 | 54.6 |
| IND | fed2010 Lyne (Oakeshott) | 7.5 | 47.8 |
| IND | nsw2019 Wagga Wagga | 12.4 | 46.1 |
| OTH_RIGHT | nsw2019 Orange | 6.6 | 56.2 |
| LNP | fed2013 New England | 22.6 | 54.2 |
| LNP | nsw2019 Orange | 55.3 | 25.8 |
| ONP | sa2026 Narungga | 18.9 | 37.5 |
| GRN | fed2007 Flinders | **25.1** | **8.5** |

**Nearly every large miss is the same event seen from two sides.** Orange 2019
appears twice: the minor right under-predicted by 49.6 and the Coalition
over-predicted by 29.4. New England 2013 is Tony Windsor's retirement. Lyne
2010 is Rob Oakeshott. These are seats where a single popular local figure
arrives or departs, and the model has no feature that sees it coming.

**The Greens' two worst cells are the opposite failure and point at a residual
bug**: fed2007 Flinders and Fisher were OVER-predicted by 16 points each, both
with `jump_pctile` at 1.00 and 0.96. High salience with no real campaign behind
it -- the same false-positive class the zero-inflation fix removed for most
cells, surviving here. Worth a look.

---

## 4. What to check next, in order

1. **One Nation in South Australia.** Worst class-jurisdiction cell (8.55), the
   only correctable bias in the model (+1.41 and rising), and the place the v7
   primary regressed. Three separate findings pointing at one cell is the
   strongest signal in this document.
2. **Finish the SD model across qld and wa**, then pool all 22 pairs. The
   current tally (-0.0106 over 617 seats) is positive but incomplete.
3. **Explain the v7 primary's federal/SA split** before shipping it anywhere.
   Seven-for-seven federally against +0.071 in SA is not a result to average.
4. **Test the three-way class split** (majors / GRN+ONP / candidate-driven).
   One run, and the mechanism that justified the first split applies again.
5. **Demographics.** Still the oldest unmet request, and the per-seat misses
   above -- a local figure arriving or departing -- are exactly what no current
   feature sees. Census packs are on disk, unconnected.

### What NOT to do

- **Do not correct the apparent bias at the top of each class's range.** It is
  regression to the mean and correcting it would make the model worse.
- **Do not add a fourth variant of the SD class list.** It has had two
  adjustments already; a third chosen after seeing a pair regress is fitting the
  configuration to the test set.
