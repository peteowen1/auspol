# Does the points-based swing break for small shares? (floor at zero)

2026-10-30. **Nothing changed.** Read-only investigation. Scratch scripts are in
`C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\d9620856-015e-4f5d-8963-ed4e84fea399\scratchpad\agentC\`
(`b.R` = item 1 and the real-path check, `c.R` and `d.R` = item 2). Inputs: `output/forecasts.csv`
(31 elections, 17,010 class-seat rows; the brief said 35, the file has 31) and `output/candidacies.csv`
(35 election pairs have a predecessor, used for the oracle).

Question: `dev_slope()` computes `pmax(0, level_now + slope * (seat_prev - level_prev))`. Mildura vic2026, Labor
6.51 in 2022, statewide Labor 36.66 -> 24.47: the raw value is 24.47 + 0.922 x (6.51 - 36.66) = -3.3, floored to
0.00; the trees then lift it to 4.32. A proportional form (6.51 x 24.47/36.66) gives 4.34 and a logit-shift form
with the same 0.922 slope gives 4.39 (hand arithmetic, not run through the model; the true Mildura answer is
unknown). Is this a real, general defect and do the trees already repair it?

## 1. How often the floor bites in the published backtest, and what the trees do

Definitions: a cell is one class in one seat in one election. "Floored" = `base_pred` below 0.05 while the class
got votes (`actual_share` > 0); 171 of the 179 are exactly 0.00. Errors are `actual - prediction` in vote-share
points (bias: positive = under-predicted; lower |bias| and lower RMSE are better).

Cells where the class stood, and how many were floored, by class (% = floored / stood, n beside it):

| class | cells that stood | floored | % floored |
|---|---:|---:|---:|
| ALP | 2,618 | 8 | 0.3% |
| LNP | 2,618 | 0 | 0.0% |
| GRN | 2,569 | 1 | 0.0% |
| OTH | 1,273 | 152 | 11.9% |
| OTH_RIGHT | 2,077 | 7 | 0.3% |
| ONP | 812 | 1 | 0.1% |
| IND | 1,319 | 10 | 0.8% |
| all | 13,286 | 179 | 1.3% |

Error before the trees (base) and after (xgb) on the floored cells; bias and RMSE in share points, lower is better:

| group | n | mean actual | mean base | mean xgb | bias base | bias xgb | RMSE base | RMSE xgb |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| all floored | 179 | 3.18 | 0.00 | 1.04 | 3.18 | 2.15 | 4.31 | 3.27 |
| OTH | 152 | 2.74 | 0.00 | 0.93 | 2.74 | 1.81 | 3.39 | 2.46 |
| IND | 10 | 5.13 | 0.00 | 1.58 | 5.13 | 3.55 | 7.60 | 6.23 |
| ALP | 8 | 7.66 | 0.00 | 3.30 | 7.66 | 4.36 | 8.29 | 4.91 |
| OTH_RIGHT | 7 | 1.87 | 0.01 | 0.05 | 1.87 | 1.82 | 1.97 | 1.91 |
| ONP + GRN (1 each) | 2 | 13.7 | 0.00 | 0.84 | 13.7 | 12.8 | 14.4 | 13.9 |
| class had NO share in the seat last time | 165 | 2.91 | 0.00 | 0.96 | 2.91 | 1.95 | 3.83 | 2.88 |
| class HAD a share last time (the swing-form case) | 14 | 6.37 | 0.00 | 1.91 | 6.37 | 4.47 | 8.02 | 6.23 |
| comparison: every other stood cell (base >= 0.05) | 13,107 | 19.86 | 19.94 | 20.09 | -0.08 | -0.23 | 5.06 | 4.79 |

Reading it:

- The floor is rare: 1.3% of stood cells (179 of 13,286). Nearly all of it is OTH.
- 165 of the 179 (92%) are cells where the class had **no** share in the seat last time. That is a class appearing
  from nowhere, not the swing form. Only **14 cells** are a prior seat share that the additive swing drove to zero.
- The trees repair part but not all: bias 3.18 -> 2.15 (about a third), and 20 of the 179 still sit under 0.05
  after the trees. By size of the actual share the bias repair runs from 63% (actual under 1 point, n = 21) down
  to 21% (actual over 10 points, n = 8).
- A looser cut, `base_pred` under 0.5 and the class HAD a share last time: n = 38 of 11,164 cells (0.34%), mean
  last-time share 5.05, actual 4.25, base 0.23, xgb 1.22, RMSE 5.82 -> 4.60. Same story.
- Elections with most floored cells (n): fed2019 32, fed2016 30, fed2022 28, fed2013 26, wa2013 18, fed2025 17,
  nsw2011 11, qld2024 10. Mostly federal OTH.

## 2. Oracle comparison of the swing FORM (true statewide levels, no model)

ORACLE CHECK: the true statewide levels of both elections are used on purpose, so this isolates the form of the
swing, not the poll trend. Population: 12,473 class-seat cells that stood in both the earlier and the later
election, 35 election pairs, all classes. Level = class votes / all votes statewide (from `candidacies.csv`); a
seat renamed between elections drops out. Arms, all with deviation slope 1 unless stated:

- a: `pmax(0, last + (level_now - level_prev))`, additive
- b: `last x level_now / level_prev`, proportional
- c: logit shift (every seat's logit moved by the statewide logit change)
- d: average of a and b
- h5, h10, h20: smooth blend `w*a + (1-w)*b`, `w = last/(last+k)`, k = 5, 10, 20 (k chosen by hand, in-sample)
- g: **direction-aware**: a when the class level rises, c when it falls (identical when the level is flat, so no jump)
- gb: same with b instead of c when falling

Pooled RMSE of seat share in points (lower is better) and bias (actual minus prediction):

| arm | RMSE | bias |
|---|---:|---:|
| a additive | 5.27 | -0.08 |
| b proportional | 7.35 | -0.42 |
| c logit | 5.56 | -0.26 |
| d mean(a,b) | 5.80 | -0.25 |
| h5 | 5.47 | -0.22 |
| h10 | 5.67 | -0.27 |
| h20 | 5.95 | -0.32 |
| g (a if rising, c if falling) | 5.08 | not computed |
| gb (a if rising, b if falling) | 5.01 | not computed |

RMSE by last-time share band and by whether the class level falls or rises (points; lower is better; n = cells):

| last-time share | direction | n | a additive | b proportional | c logit |
|---|---|---:|---:|---:|---:|
| < 5 | falling | 1,033 | 3.21 | 3.06 | 3.06 |
| < 5 | rising | 1,854 | 4.45 | 6.91 | 5.71 |
| 5-10 | falling | 862 | 2.95 | 2.71 | 2.71 |
| 5-10 | rising | 1,571 | 3.59 | 6.14 | 4.56 |
| 10-20 | falling | 709 | 5.20 | 4.52 | 4.55 |
| 10-20 | rising | 882 | 4.57 | 8.37 | 6.19 |
| 20-40 | falling | 1,485 | 6.27 | 5.77 | 5.77 |
| 20-40 | rising | 1,245 | 5.87 | 12.89 | 6.43 |
| > 40 | falling | 1,883 | 7.08 | 6.41 | 6.75 |
| > 40 | rising | 949 | 6.29 | 10.30 | 6.58 |
| all | falling | 5,972 | 5.64 | 5.13 | 5.27 |
| all | rising | 6,501 | 4.90 | 8.92 | 5.81 |

Bias of the additive form a (actual minus prediction, points; positive = prediction too low, near zero is good):

| last-time share | falling | rising |
|---|---:|---:|
| < 5 | +1.27 | +0.58 |
| 5-10 | +0.44 | -0.06 |
| 10-20 | -0.25 | -0.78 |
| 20-40 | +0.10 | +0.37 |
| > 40 | -1.29 | -1.08 |

So: **additive wins when the class is rising; proportional or logit wins in every share band when it is falling**,
by 0.15 to 0.7 RMSE points (0.34 to 0.68 outside the top band; n above). Proportional explodes when the class
rises (12.89 at 20-40; 28.3 RMSE, n = 399, when the level more than doubles). The pooled loser (proportional) is a
rising-level failure, which is why the one-formula tests in item 3 rejected it.

The floor in the oracle: additive is exactly 0 in 81 of 12,473 cells (0.65%); those cells had mean actual 3.2
against mean last 3.9. RMSE there (points, lower is better, n = 81): additive 4.40, proportional 2.50, logit 2.60
(classes: OTH_RIGHT 33, IND 16, OTH 11, ONP 10, ALP 10, GRN 1). The clearest win for a bounded form, but 0.65% of cells.

Paired test against a: mean squared-error gain in points squared (positive = better than a), election-clustered SE,
n = 35 elections:

| arm vs a (slope 1) | mean MSE gain, all cells | election-mean gain | SE | elections better than a |
|---|---:|---:|---:|---:|
| b proportional | -26.3 | -38.4 | 18.8 | 5 of 35 (count from the earlier run; not in the final output) |
| c logit | -3.18 | -3.73 | 1.52 | 12 of 35 |
| h5 | -2.20 | -2.72 | 1.36 | 14 of 35 |
| h10 | -4.37 | -5.54 | 2.68 | 13 of 35 |
| g direction-aware | +1.93 | +2.68 | 0.61 | 30 of 35 |
| gb (b when falling) | +2.63 | +3.88 | 0.88 | 32 of 35 |

With a single class-agnostic deviation slope s applied to both arms (a proxy: the real model uses per-class and
per-seat slopes). RMSE in points, lower is better:

| slope | additive | direction-aware g | g vs a election-mean MSE gain (SE) | elections better |
|---:|---:|---:|---:|---:|
| 1.0 | 5.27 | 5.08 | +2.68 (0.61) | 30 of 35 |
| 0.9 | 5.07 | 4.95 | +1.60 (0.49) | 24 of 35 |
| 0.8 | 5.04 | 5.00 | +0.59 (0.39) | 15 of 35 |

The gain shrinks as the slope shrinks, because a slope below 1 already pulls seats toward the level and away from the
floor. At the repo's real slopes (0.55-0.99 by class) most of the oracle gain may be gone. UNVERIFIED: not run with
the real slopes.

## The published path: is the real base_pred biased for small falling shares?

Real `forecasts.csv` numbers (not oracle), cells that stood both times, n = 11,164. Direction is the TRUE level
change, used only to bucket cells. Bias = mean(actual - prediction) and RMSE, points; lower |bias| and RMSE are better:

| last share | direction | n | bias base | bias xgb | RMSE base | RMSE xgb |
|---|---|---:|---:|---:|---:|---:|
| < 5 | falling | 830 | -0.05 | +0.01 | 2.82 | 2.62 |
| < 5 | rising | 1,651 | +0.38 | +0.37 | 4.47 | 4.08 |
| 5-10 | falling | 806 | -0.61 | -0.68 | 3.27 | 2.99 |
| 5-10 | rising | 1,406 | -0.59 | -0.39 | 3.62 | 3.34 |
| 10-20 | falling | 669 | -1.09 | -1.19 | 4.99 | 4.58 |
| 10-20 | rising | 809 | -0.99 | -0.64 | 4.51 | 4.28 |

The real base_pred has **no bias for small shares when the class falls** (-0.05, n = 830). The oracle's +1.27 for the
same band is not in the published numbers, because the real model uses class slopes below 1 and conditional slopes
that keep small shares off the floor. The floor is a tail problem (item 1), not a general bias.

## 3. Has the repo already tried this?

- `docs/plans/prereg-growth-ratio-features-2026-10-18.md` (REFUSED 2026-10-18: minor-class seat RMSE +0.031, SE
  0.012; `DECISIONS.md:88`). **Not the same question.** It added two xgb features (`growth_ratio`, `ratio_dev`) so
  the trees could learn where growth lands. It left the base alone. Its "component tests" paragraph is relevant: on
  stood-both-times cells with the actual level, every one-formula rule lost to the shipped linear slope (RMSE
  linear 4.99-5.09, uniform 5.27, proportional 6.40, logit 5.35, growth-ratio slope 5.52). That matches the pooled
  rows above (a 5.27, b 7.35, c 5.56). It did NOT split by whether the level rises or falls, and did not test a
  direction-aware hybrid.
- `docs/reviews/swing-shape-2026-08-25.md`: uniform vs proportional on 2,878 district-party observations, 12 pairs:
  uniform won (MAE 3.724 vs 3.970). Pooled, no direction split.
- `docs/plans/prereg-swing-shape-by-magnitude.md` (REFUSED 2026-08-25): hypothesis that proportional wins for large
  swings came out reversed, proportional worst in the top decile of |statewide swing| (uniform MAE 4.776, proportional
  6.591). Consistent with this review (proportional is bad when a class rises a lot), but it pooled up and down moves,
  so it never looked at the falling half where proportional wins.
- `docs/reviews/new-party-fill-proportional-vs-uniform-2026-10-28.md`, `prereg-close-proportional-2026-09-28.md`:
  different questions (filling a new party's vote), not seat swing.
- `docs/NEXT-STEPS.md:207` lists logit, proportional and growth-ratio slopes as REFUSED: one-formula versions.
- Not found: any test of a direction-aware base, or of the floor as such. UNVERIFIED beyond a grep for
  `proportional|logit|growth_ratio|ratio_dev` in docs (61 files, 139 hits); I read the four above, not the rest.
  Per CLAUDE.md, those refusals were of one-formula versions, not the strongest version, so they do not close this.

## 4. Verdict

**The additive points form is wrong in one specific, narrow way, and the trees only partly repair it.**

1. The floor is small. 1.3% of stood cells (179 of 13,286) in the published backtest, 92% of them classes appearing
   with no last-time share (a different problem). Only 14 cells are the Mildura case (a prior seat share driven to
   zero by additive swing). The trees repair about a third of the bias on those cells (3.18 -> 2.15, RMSE 4.31 ->
   3.27) and 20 of the 179 are still near zero. The published number is not fully repaired, but the group is tiny, so
   fixing it moves published RMSE in the third decimal. A fix matters mainly for features that read `base_pred`
   itself (its trees' top contribution at Mildura is `base_pred`, +2.33 at 0): they get a real number instead of a
   0.00 for a seat the class demonstrably contests.
2. The oracle shows a broader, real asymmetry. When a class FALLS, proportional or logit beats additive in all five
   share bands (e.g. 10-20 band: 4.52 vs 5.20, n = 709). When it RISES, additive wins by a lot. A direction-aware form
   (additive up, logit down, equal at zero change, so continuous) lowers pooled RMSE 5.27 -> 5.08 at slope 1, better
   in 30 of 35 elections (election-mean MSE gain 2.68, SE 0.61).
3. With a damping slope of 0.9 the gain roughly halves (+1.60, SE 0.49, 24 of 35); at 0.8 it nearly vanishes (+0.59,
   15 of 35); and the published base_pred shows about zero bias for small falling shares. At the real per-class,
   per-seat slopes the size of any gain on the real base is UNVERIFIED.

**Fix the data supports**: a hybrid by direction, not a cliff. Keep `level_now + slope x (seat_prev - level_prev)` when
the class level rises. Use the logit shift, `logit(level_now) + slope x (logit(seat_prev) - logit(level_prev))`, when it
falls. It is continuous at zero change, strictly positive (the floor disappears), and for Mildura gives 4.39 against
the trees' 4.32. Sized: at most about 0.1 pooled RMSE points at the repo's real slopes (my estimate, UNVERIFIED),
concentrated in small seats of falling classes; close to nothing in the published seat numbers, since the trees carry
most of it. If Pete wants it tried: a pre-registered arm through `scripts/quick_arm.R` with the real slopes, tested in
BOTH `base_pred` and the xgb layer, with the 14-38 floored cells as the named-target primary and all 22 pairs as the
guard. Do not ship on this oracle check.
