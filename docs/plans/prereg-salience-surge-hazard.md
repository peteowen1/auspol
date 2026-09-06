# Pre-registration: salience as the per-seat surge hazard

Written 2026-08-26, **before any hazard model was fitted and before the fed2022
whole-seat fetch was run**. Committed before either.

## What is being proposed

`simulate_seat_contests()` already takes a per-seat `surge_h` vector. Its hazard
is currently **flat at 0.0508** for one reason: `P(surge)` fitted on vote history
came back **anti-predictive**, out-of-sample AUC **0.326** — the seats it rated
at 11.7% surged 0.0% of the time. Vote history cannot see an emergence, which is
the structural finding behind four refused mechanisms.

Google Trends salience can: **AUC 0.841, p = 0.005** on the strictest cut
(`docs/reviews/salience-emergence-2026-08-26.md`). So the proposal is
`surge_h[i] = f(salience_i)` — the same machinery, with the predictor it was
missing.

## What is explicitly REFUSED, in advance

**Salience share as a projected first preference.** It is tempting because it is
on a vote-share scale and sums to 100, and it is not good enough:

| | value |
|---|---|
| slope, independents | **0.34** |
| residual sd | **11.7 points** |
| Chaney overstated by | **52 points** |
| Scamps / Spender / Daniel overstated by | 35 / 31 / 26 |
| MAE vs assuming zero | 18.1 against 27.8 |

**Rank is reliable; magnitude is not.** An earlier claim of "within ~3 points"
was cherry-picked from Steggall and Ryan, the two cases that happened to land.
This clause exists so that the vote-share route cannot be revived later by
pointing at those two.

## The mapping

Fitted on `output/emergence-trends.csv`: logistic `won ~ log1p(ratio)`, slope
**+3.537** (SE 1.230, z 2.87, p 0.004).

**The intercept from that fit must NOT be shipped.** Group A was selected on
winning, so the design is case-control: the slope is unbiased, the intercept
reflects the sampling. It is recalibrated by the standard offset
`log((n1/n0) / (base/(1-base)))` to the measured base rate of a non-major
winning a seat, which is **to be computed from `output/candidacies.csv` and
stated in the result** — not assumed at 5% as in the exploratory run.

### The base rate, MEASURED 2026-08-26 — and it is not stationary

Computed from `output/candidacies.csv` as the pre-registration required, before
the hazard was fitted:

| population | wins / candidacies | rate |
|---|---|---:|
| all non-majors, federal | 70 / 5,259 | 1.33% |
| **non-majors polling ≥5%** | **70 / 1,635** | **4.28%** |
| independents only | 37 / 709 | 5.22% |

**4.28% is the matching rate**, because Group B was drawn from non-majors
polling at least 5%. The exploratory assumption of 5% was close but is now
replaced by a measurement.

**The trend is the more important finding, and this pre-registration did not
anticipate it.** By election: 0.27% (2007), 0.94% (2010), 0.57% (2013), 0.73%
(2016), 0.87% (2019), **2.00% (2022), 3.43% (2025)** — a twelvefold rise.

A single fixed intercept would therefore **understate the hazard in exactly the
elections that matter** and overstate it in the older ones. **Amendment, made
before fitting and visible as an addition:** the recalibration offset uses the
base rate of the election being predicted, not a pooled constant. This favours
neither direction of the criterion — it raises the hazard in 2022 and lowers it
in 2007–2016 — and the pooled-constant version will be reported alongside so
the choice can be checked.

Implied hazards at 5% (illustrative only, superseded by the above):

| ratio | P(non-major wins) |
|---:|---:|
| 0.00 | 2.1% |
| 0.50 | 8.4% |
| 1.00 | 20.1% |
| 5.00 | 92.5% |

`surge_h[i]` is that probability, clipped to `[0, 0.35]`. **The clip is
pre-registered here and will not be moved.**

## The corpus this must be fitted and scored on

**All 151 seats of fed2022, not the 9 already fetched.** Those nine were chosen
because something happened in them; fitting or scoring on them is selection on
the outcome, and would produce a number that cannot survive contact with a live
forecast. The fetch is a precondition, not an optimisation.

## Criterion

Federal 2022, 5,000 sims, against three comparators: flat-hazard surge
(`surge_h = 0.0508`), flat `shrink = 0.10`, and neither.

1. **The named misses must move.** North Sydney (Tink), Goldstein (Daniel),
   Fowler (Dai Le), Curtin (Chaney), Mackellar (Scamps), Kooyong (Ryan) — the
   model gave these 0.0000 to 0.0206. Their **mean P(actual winner) must exceed
   0.10**. This is the gate; the aggregate is secondary.
2. **Reliability preserved.** No probability bucket outside its own 95%
   binomial CI, matching flat `shrink`'s 0 of 6.
3. **Log score not worse** than the best comparator by more than 0.02 pooled.

## Refusal — what disqualifies a winner

- **If accuracy falls by more than 2 seats in fed2022.** Lifting six seats is
  worth little if it costs more elsewhere.
- **If any seat with zero salience gains probability.** The mechanism must do
  nothing where there is no signal; if it moves those seats, it is adding noise
  rather than information.
- **If the gain is confined to the six named seats** and the other ~145 are
  unchanged in log score, the result is a lookup table for cases already known,
  not a model. Report and do not adopt.
- **If a famous-but-doomed candidate is lifted above 0.25** — James Mathison in
  Warringah 2016 is the known case, 0.429 ratio on 11.4% of the vote. Some
  false-positive lift is acceptable and expected; a *confident* false positive
  is not.

## What the criterion cannot see

- **One election.** fed2022 is the teal wave; it is the most favourable possible
  test and cannot show whether the mechanism helps in a normal election.
  fed2019 and fed2025 follow if this passes, and the verdict is provisional
  until then.
- **Trends is a sample, and every figure here is a single pull.** The literature
  recommends replicate queries aggregated across days. Not done, and it is the
  largest untested assumption in the pipeline.
- **2010 is unmeasurable rather than null** — Oakeshott 0.000, Bandt 0.020.
  Anything fitted here should not be applied to elections before ~2013.
- **Nothing tests Victoria**, which is the live target, and no state election has
  had the corrected method applied at all.
- **The signal measures attention, and fame is attention.** No amount of fitting
  separates a famous no-hoper from a serious challenger on this input alone.
