# Pre-registration: replace the hardcoded `party_sd = 1.5` with the measured value

Written 2026-08-25, **before** any backtest arm was run. Committed before fitting.

## What this is, and what it is not

This is **not** a grid search over a free parameter. `party_sd` is the assumed
standard deviation of the statewide first-preference forecast error. It is a
quantity the repo can measure directly, and it has never been measured — all
four backtest harnesses carry

```r
psd <- setNames(rep(1.5, length(parties)), parties)
```

with no derivation anywhere. `scripts/fit_seats_full.R:464` already uses a
per-party `state_sd` and falls back to 1.5 only when that is `NA`, so the
harnesses and the published model disagree about the single number that sets how
wide every seat forecast is.

`docs/CONSTANTS.md` lists `party_sd` as "can come from data". This is that.

## The measurement

`output/inclusion-floor.csv` holds fitted-vs-actual statewide first preferences
per (region, year, party) from the trend model at the shipped inclusion floor of
8. Restricted to scorable, finite rows: **139 party-cycles across 33 election
cycles**.

| | sd of (fitted − actual) |
|---|---:|
| assumed in all four harnesses | **1.50** |
| realised, all parties | **2.33** |
| realised, majors (ALP/LNP) | 2.37 |
| realised, minors | 2.31 |

By region: NSW 2.71 (n=29), QLD 2.63 (n=16), WA 2.58 (n=26), VIC 2.19 (n=34),
SA 1.92 (n=14), FED 1.87 (n=20).

**Cluster note.** First preferences sum to 100 within a cycle, so the 139 rows
are **33 independent observations**, not 139. The sd estimate itself is a spread,
not a mean, so clustering does not bias it; but its own uncertainty must be
quoted on 33. At n=33 the sd of an sd estimate is roughly `sd/sqrt(2(n-1))` =
2.33/8.0 = **0.29**. So the realised value is 1.50 + 2.9 SE. **The gap between
1.50 and 2.33 is not a sampling artefact.**

## The change

Set `party_sd = 2.33` in all four harnesses. Not per-party and not per-region:
majors and minors are within 0.06 of each other, which is a fifth of one SE, and
the per-region n (14 to 34 rows, so 3 to 8 cycles) cannot support six separate
estimates. **A single pooled value is what the data supports.**

## Criterion

Because this replaces a fabricated number with a measured one, the burden is
reversed. The measurement is the justification. The backtest is a check that
adopting the honest value does not break something, **not** a search for the
value that scores best.

**ADOPT unless it degrades.** Specifically, adopt if, across all four harnesses
(SA 2026, Vic 2018→2022, Vic 2014→2018, NSW 2023) at 5,000 sims with the
currently-shipped fixes (`fallback_smooth = 0.60`, `flow_sd = 3.65`,
`elastic_over = 1.5`) and **`shrink = 0`**:

1. **Calibration slope moves toward 1** in at least 3 of 4 harnesses, and moves
   away from 1 by more than 0.20 in none.
2. **Seat accuracy** falls by no more than 1 seat in any single harness, and the
   total across the four does not fall at all.
3. **Log score** does not worsen by more than 0.05 in any harness.

## Refusal — what would disqualify a winner

Named in advance, per CLAUDE.md, because two of the last three experiments were
refused on grounds invented after the results were seen.

- **If widening `party_sd` improves the slope but the improvement comes entirely
  from seats becoming uninformative** — i.e. mean |P − 0.5| collapses while
  accuracy holds — that is not calibration, it is hedging. Refuse if mean
  |P − 0.5| falls by more than 0.10 across the four harnesses combined.
- **If the four South Australian One Nation seats gain probability while
  accuracy elsewhere falls**, the change is buying the seats this session has
  been staring at with a general loss of resolution. Refuse.
- **If a harness's slope crosses 1 and overshoots to above 1.5**, that harness
  is now under-confident and a single pooled value is the wrong shape. Report it
  and do not adopt without a second measurement per region.

## What the criterion cannot see

- **Whether 1.5 was compensating for something else.** If widening `party_sd`
  fixes the slope, that is consistent with two stories: the statewide
  uncertainty was genuinely too narrow, or some *other* source of error was
  being absorbed by an over-confident statewide draw and now shows up
  differently. The backtest cannot distinguish them.
- **`shrink` becomes redundant, or does not.** If `party_sd = 2.33` alone fixes
  the slope, `shrink = 0.10` should be re-examined as a published constant — it
  was already shown wrong for 2 of 4 harnesses. That is a separate decision and
  is **not** pre-registered here.
- **The trend model's own error is not the only statewide error.** The measured
  2.33 is the trend model's fitted-vs-actual gap on completed elections, where
  the polls are known. A live forecast at a horizon carries more. So **2.33 is a
  floor, not the answer** — the true forward-looking value is larger and this
  change is conservative in the right direction.
- Nothing here touches (b) seat-level or (c) flow-rate uncertainty, which were
  the other two channels asked about.

## Arms to run

| tag | party_sd | shrink |
|---|---|---|
| baseline | 1.50 | 0 |
| B | 2.33 | 0 |
| C | 2.33 | 0.10 |

Arm C is informational for the `shrink` question and is **not** part of the
adoption criterion above.
