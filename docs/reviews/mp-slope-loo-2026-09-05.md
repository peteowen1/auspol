# The sitting-member slope tier was mis-transcribed, and one of its four values was invented

2026-09-05. Pete: *"let's make sure all our learnings are actually in our
model."* Checking whether one could be shipped found that the learning itself
had been recorded wrong.

`scripts/fit_mp_slope.R` (new, committed) re-derives the tier from
`output/candidacies.csv`, leave-one-election-out, over **18 pairs and 6
jurisdictions**.

## The tier is real

Member versus also-ran, refitting with each target election's own pair removed:

| | mean | sd | range |
|---|--:|--:|---|
| member slope | 0.931 | 0.011 | 0.918 – 0.964 |
| also-ran slope | 0.809 | 0.022 | 0.769 – 0.862 |
| **gap** | **0.122** | 0.024 | **positive in 18 of 18 folds** |

Eighteen of eighteen, out of sample. The idea is sound and is worth shipping.

## But the shipped numbers are not the fitted ones

`AUSPOL_MP_SLOPE` ships `c(IND = 0.954, OTH_RIGHT = 0.954, GRN = 0.994,
ONP = 0.610)`. Refitted per class, with the counts printed beside them:

| class | n members | fitted member | fitted also-ran | **shipped** | verdict |
|---|--:|--:|--:|--:|---|
| IND | 43 | **0.912** | 0.766 | 0.954 | **0.042 too high**, ~2.7 LOO sd |
| OTH_RIGHT | 11 | 0.931 | 0.536 | 0.954 | close; the gap here is the largest of any class |
| GRN | 17 | 1.000 | 1.023 | 0.994 | **no gap at all** — the tier does nothing for Greens |
| ONP | **0** | — | 0.617 | 0.610 | **fabricated**: no sitting ONP member has ever re-contested |

Three separate faults, none visible in any aggregate metric:

1. **IND is over-raised.** 0.954 against a fitted 0.912. That is the direction
   that hurts when a sitting independent loses, and it is exactly what the
   Victorian measurement showed — see below.
2. **GRN should not be in the tier.** Its member slope (1.000) and its also-ran
   slope (1.023) are indistinguishable, so a separate member value asserts a
   distinction the data does not contain.
3. **ONP's value came from zero observations.** 0.610 is the ONP *also-ran*
   slope (0.617) transcribed into the member row. It has never fired, because
   no One Nation member has ever personally re-contested in this corpus — but
   South Australia elected four in March 2026, so it is about to become live,
   and it would fire with a number that was never measured.

## What Victoria showed, and why it now makes sense

Ported to `backtest_candidate_vic.R` and measured (`shrink=0.10`, screened):

| arm | vic2018 | vic2022 | pooled |
|---|--:|--:|---|
| baseline | 0.3464 | 0.2572 | 90.4%, Brier 0.0789 |
| defector discount only | 0.3464 | 0.2572 | identical — a clean no-op |
| MP tier (shipped values) | 0.3464 | **0.2601** | 89.8%, Brier 0.0795 |

The entire cost is two seats, both sitting independents who **lost** to the
Nationals in 2022:

| seat | our call, base → tier | p(winner), base → tier | log-loss cost |
|---|---|--:|--:|
| Shepparton (Sheed) | LNP → **IND** | 0.561 → 0.489 | +0.136 |
| Mildura (Cupper) | LNP → LNP | 0.672 → 0.616 | +0.086 |

At the fitted 0.912 rather than the shipped 0.954, both move less. This is not
evidence against the tier; it is evidence against the value.

## The leakage, stated plainly

The original fit pooled "531 returning non-major candidacies across 10 election
pairs" and the tier was then scored on **fed2025, one of those pairs**. The
reported gain 0.3663 → 0.3597 is therefore partly in-sample and should not be
quoted as an out-of-sample result. It was not caught at the time because the
fit lived in a scratchpad script that was never committed, so it could not be
re-run, inspected, or refitted with the target held out.

`scripts/fit_mp_slope.R` exists so that cannot recur: the LOO slopes are
written to `output/mp-slope-loo.csv` and `output/mp-slope-by-class.csv`, and
every count is printed beside every slope.

## How many cases this touches

The tier is a targeted change and has to be judged on its targets. Seat-classes
it applies to, per harness:

| harness | pairs | targeted seat-classes |
|---|--:|--:|
| federal | 6 | 41 |
| NSW | 1 | 9 |
| Victoria | 2 | 9 |
| SA | 1 | 4 |
| WA | 6 | 8 (two pairs have **zero** — an identical result there is a guaranteed no-op, not a finding) |
| **total** | | **71** |

At 5 of 78 Victorian seats, `n/k` is 15.6, so an election-wide aggregate cannot
resolve this change either way. The pooled 71 targeted cases are the primary
metric.

## The diagnostic that made this checkable

`BV1m` was added to the Victorian harness: it prints the tier values and the
number of seat-classes they applied to, unconditionally. It is what proved
vic2018's byte-identical arm was a genuine null (4 seat-classes, all safe
seats) rather than the "experiment that never ran" failure. The other four
harnesses still lack the equivalent print.

## Open

- Refit-and-remeasure with the LOO values (IND 0.912, OTH_RIGHT 0.931, GRN and
  ONP dropped from the tier) on all five harnesses.
- `fit_seats_full.R` — the published forecast — passes neither `same_mp` nor
  `major_discount` (lines 545, 605, 607), so none of this reaches Victoria 2026
  until it is wired there too.
- The tier's values belong in `docs/CONSTANTS.md`, sourced from
  `scripts/fit_mp_slope.R`.
