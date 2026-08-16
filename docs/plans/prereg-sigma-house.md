# Pre-registration: estimating the house-effect prior

Written 2026-08-16, **before** the grid is run and committed before any result
is seen. Same procedure as [prereg-szc-v2.md](prereg-szc-v2.md), which settled
`szc_sd_pts`.

## The constant

`sigma_house_pts = 3` — the prior standard deviation on **one pollster's**
house effect, in percentage points. It says how far a single firm is expected
to sit from the truth, where `szc_sd_pts` says how far they may all sit
together.

Hand-set at 3 and never estimated. It appears in three places that must move
together: `fit_trend()`, `estimate_trend_sigmas()` and `estimate_cycle_sigmas()`.

## Why this one may behave differently from `szc`

`szc` turned out to be a step function — everything below 1 identical,
everything above identical — because it governs an aggregate. This governs
individual effects directly, so a smooth response is more likely, and the
risk of a runaway is real: a very loose prior lets a pollster absorb genuine
movement as "bias", flattening the trend.

**V5 is therefore a live constraint, not a formality.** It requires
`max |house effect| < 5` on validation cycles and currently reads 3.98. A
looser prior pushes directly on it.

## Criterion, grid and rule — fixed now

**Primary:** held-out mean absolute error from `projection_loo`,
leave-one-election-out, 195 election-horizon pairs. The same criterion used
for the mix weight and for `szc_sd_pts`.

**Grid:** `sigma_house_pts` in {1, 2, 3, 5, 8}. Spans "pollsters are nearly
unbiased" through the incumbent to "a pollster may be badly off". Chosen now.

**Decision rule:**

1. Compute held-out MAE at each grid value.
2. **The incumbent 3 wins ties and near-ties.** Adopt another value only if it
   beats 3 by **more than 0.02 MAE**, the same bar used for `szc`.
3. Any adopted value must **pass every existing pre-registered check**,
   V5 included. A value that lowers held-out error while letting a single
   pollster's fitted bias exceed 5 points is **rejected** — that bound was
   written against actual results and outranks an average.
4. **Interval coverage (B2/B3) must still pass.**
5. If several qualify within 0.02 of each other, take the **smallest** — a
   tighter prior concedes less of the trend to house effects.

## What is not a criterion

Not whether the fitted house effects look plausible by eye. Not agreement with
`szc_sd_pts`'s answer. Not whether the Victorian two-party figure moves in a
direction I find comfortable.

## Expected outcome

Genuinely unsure, which is the point of registering it. Two plausible results:
the grid is flat and 3 stands, or a tighter value wins because 3 already
concedes too much to house effects. If a looser value wins on MAE but breaks
V5, rule 3 rejects it and that tension is itself the finding — it would mean
held-out accuracy and the V5 bound disagree, and V5 would need re-examining on
its own evidence rather than being quietly relaxed.
