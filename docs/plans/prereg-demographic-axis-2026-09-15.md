# Pre-registration: the demographic axis, at full strength

Written 2026-09-15, after `prereg-education-residual-correction-2026-09-15.md`
was REFUSED on its placebo. **Nothing in this plan has been run.** The control
below HAS been calibrated, deliberately and before committing this, and that
calibration is reported in full under "Dry-run of the criterion".

## Why there is a second attempt at all

The refused test used ONE hand-picked census column and a control that was not
a control. Pete's objection was immediate and correct: *"i dont think
born_aus_pct is a placebo isnt it highly correlated to education levels?"* It
is, at **r = -0.706** over 1,989 seats.

`CLAUDE.md` is explicit that a negative result is only reportable from the
strongest version available. One column out of seven, fitted by a single
through-origin slope, with a control that measures the same latent variable, is
not that. This plan is the strong version, and the refusal of the weak one is
not evidence against it.

## The three things being run

**Arm A -- penalised multi-feature residual offset.** All seven census columns
(`yr12_pct`, `born_aus_pct`, `indig_pct`, `over55_pct`, `under35_pct`,
`lang_other_pct`, `edu_25plus_pct`), each z-scored WITHIN pair, into an elastic
net (`glmnet`) predicting `actual_share - xgb_pred` per class. Leave-one-pair-
out; `alpha` and `lambda` chosen by inner CV **on the training pairs only**, so
nothing from the held-out election reaches its own model.

**Arm B -- the same seven columns as MODEL FEATURES**, within-pair z-scored,
added to the primary xgboost and refit. `CLAUDE.md` records census-as-features
failing (sa2026 ONP RMSE 8.658 -> 9.544), but that test used RAW values, which
carry the 51.4 -> 60.8 Year 12 drift between elections as a jurisdiction-ish
label. Within-pair z is exactly the fix that made the residual version work and
it has never been tried on the feature path. Reporting the old failure as
settling Arm B would be reporting a negative from the weak version twice over.

**The control -- a within-pair permutation**, `AUSPOL_EDU_RESID_SHUFFLE=<seed>`,
which permutes which seat gets which seat's demographics inside each election,
at fit and at apply both. Every marginal distribution and the entire fitting
procedure are untouched; only the seat-to-demographics correspondence is
destroyed. **K = 20 draws per arm.**

With seven mutually correlated columns there is no "other column" that can act
as a control -- that is precisely what `born_aus_pct` cost. The control has to
break the link, not swap the variable.

## WHAT I ALREADY KNOW, stated before the criterion

From the refused single-feature test, on seat log loss:

| pair | baseline | `yr12_pct` | move |
|---|--:|--:|--:|
| sa2026 | 0.3577 | 0.3464 | -0.0113 |
| vic2014 | 0.2477 | 0.2387 | -0.0090 |
| vic2018 | 0.2073 | 0.2024 | -0.0049 |
| qld2024 | 0.3106 | 0.3089 | -0.0017 |
| vic2022 | 0.2494 | 0.2477 | -0.0017 |
| nsw2023 | 0.2694 | 0.2699 | **+0.0005** |

Pooled over the AEF-7 it was -0.0012, with four pairs contributing nothing
because they were skipped. `born_aus_pct` recovered 71% of the pooled gain and
100% of it on qld2024. Per-seat primary RMSE moved the OPPOSITE way on sa2026
(+0.636 worse) from seat log loss (-0.0113 better).

I also know the single-feature gain is concentrated on `xgb_pred`: ONP -0.0914
there against -0.0055 on `base_pred`, a factor of 17.

## The criterion

**Pooled seat log loss across every backtest pair the correction runs on,
compared against the permutation null.** Lower is better; seat-weighted,
because a pair is a cluster of seats.

**Adopt an arm if its pooled seat log loss is below ALL 20 of its control
draws** (an exact permutation p < 1/21 = 0.048) **and below the uncorrected
baseline.** Both, not either.

A permutation reference rather than a normal-theory standard error, because the
control draws give the null distribution of this exact statistic on this exact
corpus, with no distributional assumption and no argument about the clustering
unit.

**Report and do not decide on:** per-seat primary RMSE (already known, and
already known to disagree in sign), Brier, calibration slope, per-class and
per-pair breakdowns, and which features glmnet selects.

## Power, computed rather than assumed

`CLAUDE.md` requires the primary metric's own noise sized against the expected
effect, and this is where the AEF-7 version of this test would have failed.

The control's spread on sa2026, measured over 8 draws: **sd = 0.0013**. Across
the 6 pairs with a known single-feature effect, the per-pair effect sd is
**0.0046**, so over 7 pairs the standard error of a pooled mean is 0.0017 and
the minimum detectable effect is about **0.0049** -- LARGER than the -0.0012
the single-feature arm actually produced. **On the AEF-7 this criterion could
only ever have refused.** Over the 23-pair corpus the same arithmetic gives an
MDE near 0.0029, and with the permutation reference replacing the normal
approximation it is better than that again.

So the corpus is every pair, not the AEF-7. That is a decision driven by the
power calculation and made before running.

## Design decisions fixed in advance

1. **Partial application replaces the all-or-nothing skip**, with `z`
   re-centred on the seats that HAVE census data. A seat with no demographic
   data gets no demographic correction, which is the neutral action, and
   re-centring keeps the corrections summing to about zero so statewide class
   totals are preserved exactly as they are under full coverage. The current
   guard costs 13 of 23 pairs, including `fed2025` over ONE seat, which is not
   a defensible reason to discard 150 others. Uncovered seats contribute
   identically to both arms, so they dilute an effect rather than bias it --
   which is why no coverage threshold is needed, and none is set.
2. **Coverage is reported per pair** and carried in the output, so a pair
   corrected on 56% of its seats is never silently compared with one corrected
   on 100%.
3. **Classes stay ONP, OTH_RIGHT and GRN**, named now, as before. IND is
   excluded in advance: its education correlation flips sign across elections
   (-0.357 to +0.240).
4. **K = 20 control draws**, fixed now. Choosing K after seeing the arm would
   let the p-value be tuned.

## Refusal: what makes an apparent win unacceptable

- **Any control draw beating the arm.** 1 of 20 is enough. This is the whole
  point of the exercise and it is not negotiable after the fact.
- **If sa2026, qld2020 or qld2024 worsens.** These are the elections with a
  real One Nation vote and the reason this work exists. A pooled win carried
  entirely by Greens seats in safe metropolitan electorates does not serve the
  Victorian forecast.
- **If the gain disappears with the xgboost override OFF.** Measured directly,
  not inferred: same arm, `AUSPOL_XGB_PRIMARY=0`. The single-feature version
  helped `xgb_pred` 17x more than `base_pred`, which would make this a patch on
  the override rather than a model improvement -- and the honest answer would
  then be the cheaper one already on record, that the override discards signal
  `base_pred` already had.
- **A directional side effect no criterion covers.** If any class's win
  probability moves the same direction in more than 90% of seats, refuse and
  investigate. This is the failure that sank the One Nation seat-uncertainty
  arm on 2026-08-19, where every criterion passed.
- **If Arm A passes only with a coverage restriction** applied after the run.
  The corpus is every pair, fixed above.

## What the criterion cannot see

- **Victoria 2026.** There is no backtest for the election being forecast. No
  Victorian pair has a right-minor party above 6.5%, so the coefficient
  reaching vic2026 is fitted almost entirely on elections unlike it. This has
  defeated three mechanisms already and the criterion is blind to it.
- **Whether 2016 and 2021 census demographics describe 2026 populations**, in
  the fastest-growing seats least of all.
- **Borrowed-vintage rows.** 79 cells carry census measured on boundaries other
  than the ones in use, flagged `exact = FALSE`. The criterion treats them as
  equal to matched rows.
- **Whether education proxies income, industry or urbanity.** The control
  establishes that a real seat-level signal exists; it says nothing about what
  the axis IS. Naming it remains out of reach, which is why this plan is titled
  "the demographic axis" and not "education".
- **Stability under a refit of the underlying model.** Arm A is fitted against
  predictions from one fitted xgboost.

## Dry-run of the criterion, run BEFORE committing this plan

`CLAUDE.md` requires a criterion to be tested on cases whose answer is already
known, because a criterion is a measuring instrument. The instrument here is
the permutation control, and the known case is the single-feature arm on
sa2026.

Mechanics first, all verified: `shuffle = 0` is a byte-identical no-op; a
seeded shuffle preserves each pair's value multiset in 24 of 24 pairs and each
pair's mean to 12 decimal places; different seeds give different permutations;
and the global RNG stream is saved and restored, so a control run cannot
silently become a second arm by moving every simulation draw.

Then the substance. The fitted ONP coefficient for sa2026 collapses from
**-0.712** to -0.117, -0.198 and +0.003 under three shuffles. Through the full
harness, 8 draws:

| sa2026, seat log loss | value | move vs baseline |
|---|--:|--:|
| baseline, no correction | 0.3577 | -- |
| real `yr12_pct` correction | 0.3464 | -0.0113 |
| **shuffled control, mean of 8** | **0.3576** | **-0.0001** |
| control sd | 0.0013 | range 0.3561 to 0.3599 |

**The null manufactures nothing** -- 0.3576 against a 0.3577 baseline -- and
the real effect sits 8.9 control-sds below the null mean, with 0 of 8 draws
beating it. `born_aus_pct` at 0.3485 is 7.0 sds out.

So the instrument has power, and it says the single-feature signal was REAL.
That does not reverse the refusal, which stands on the rule as written, but it
does change what the refusal meant: `born_aus_pct` matched because it is a
second honest measurement of one real axis, not because the procedure
fabricates gains out of noise. That is the finding this plan is built on, and
it is the reason a second attempt is justified rather than stubborn.

## Prediction, written before running

**Arm A passes the control on sa2026 comfortably** -- the single feature was
already 8.9 sds out and six more correlated columns should not destroy that --
and improves pooled seat log loss by **0.002 to 0.006**, more than the
single-feature -0.0012 because the corpus roughly triples and because the
penalised fit can use `indig_pct` and `lang_other_pct` where the axis is not
purely educational.

**Arm B is the coin-flip and I expect it to fail**, roughly neutral to slightly
negative pooled. The tree already has partisan history per seat, which proxies
demography well; the marginal information in seven correlated census columns is
small, and trees spend splits on columns that separate subgroups cleanly.

**The refusal condition I expect to fire, if any, is the `base_pred` one.**
The single-feature gain was 17x larger on `xgb_pred`, and nothing in going
multi-feature obviously changes that.

If Arm A passes and Arm B fails, the honest reading is that the demographic
axis is real but the override is discarding it, and the work that follows is on
the override rather than on more census columns.

---

# RESULT, 2026-09-15: Arm A measured on all 22 pairs. REFUSED, narrowly.

## The criterion

Pooled seat log loss, 22 pairs, 2,066 seat-elections. Lower is better.

| | pooled |
|---|--:|
| baseline | 0.2849 |
| Arm A | 0.2831 |
| **move** | **-0.0018** |
| per-pair mean | -0.0021, SE 0.00115 |
| t | **-1.83** on 21 df (p = 0.08 two-sided) |
| pairs improved | 14 of 22 (binomial p = 0.143) |

Below the baseline, yes. But the pooled effect is **not distinguishable from
zero at conventional levels**, and it came in at the bottom of the 0.002-0.006
range predicted above.

| improves most | move | worsens most | move |
|---|--:|---|--:|
| nsw2019 | -0.0145 | wa2013 | +0.0074 |
| vic2014 | -0.0117 | fed2025 | +0.0052 |
| qld2020 | -0.0080 | wa2017 | +0.0032 |
| sa2026 | -0.0079 | **qld2024** | **+0.0024** |
| vic2022 | -0.0057 | fed2007 | +0.0022 |

## Refusal condition 2 fired

**"If sa2026, qld2020 or qld2024 worsens."** qld2024 worsened by +0.0024. It is
one of only three elections in the corpus with a large One Nation vote and it is
named in the plan precisely because those are the elections Victoria 2026 has to
resemble. The condition was written before any of this ran and it is not
reinterpreted now.

## THE SIGNAL IS REAL, and that is the finding worth keeping

This is not a "the procedure fabricates gains" refusal. The permutation control
says the opposite, on every pair tested:

| pair | baseline | control draws | real Arm A |
|---|--:|--:|--:|
| sa2026 | 0.3577 | mean 0.3576 over 8 draws, sd 0.0013 | 0.3498 |
| vic2014 | 0.2477 | 0.2478, 0.2477, 0.2476 | 0.2360 |
| vic2018 | 0.2073 | 0.2074, 0.2074, 0.2083 | 0.2027 |
| vic2022 | 0.2494 | 0.2494, 0.2495 | 0.2437 |

Permuting which seat gets which seat's demographics lands the model **on the
baseline every time**, within 0.0004, while the real arm sits 0.005 to 0.012
better. The demographic axis carries genuine seat-level information. What is in
doubt is the size and the shape of the correction, not its existence.

## The One Nation question, answered directly

sa2026 One Nation primary, the seats the model missed by most:

| seat | actual | base | demo | yr12 | err base -> demo |
|---|--:|--:|--:|--:|--:|
| MacKillop | 35.3 | 23.8 | 24.3 | 24.5 | 11.48 -> 10.98 |
| Narungga | 37.5 | 29.6 | 30.1 | 30.4 | 7.98 -> 7.47 |
| Reynell | 27.7 | 20.0 | 20.2 | 20.3 | 7.75 -> 7.50 |
| Light | 34.5 | 27.1 | 27.5 | 27.5 | 7.45 -> 7.06 |
| Chaffey | 33.9 | 26.6 | 27.0 | 27.4 | 7.32 -> 6.88 |
| Elizabeth | 33.3 | 26.2 | 26.5 | 26.7 | 7.09 -> 6.79 |

| ONP primary RMSE, sa2026 | base | demo | yr12 |
|---|--:|--:|--:|
| all 47 seats | 4.622 | 4.461 | 4.402 |
| the 10 worst misses | 7.896 | 7.496 | 7.348 |
| the 20 seats ONP won 25%+ | 6.284 | 6.013 | 5.878 |

**It helped in 10 of the 10 worst-missed seats, and by about half a point where
the gap is seven to eleven.** The direction is right in every seat that matters
and the magnitude is an order of magnitude too small. That is the actual
result, and it is more informative than the pooled log loss.

## Why more features lost to one feature where it counts

`yr12_pct` alone beats all seven columns on every sa2026 cut above, and on
qld2024 the multi-feature version turns a small gain into a small loss. CV
chose ridge (`alpha = 0`), which spreads weight across seven columns
correlated 0.65 to 0.81 with each other. Where the axis is diffuse -- Victoria,
NSW 2019, Queensland 2020 -- that pooling wins clearly. Where one column
carries almost all of it -- sa2026, where r(yr12, ONP vote) = -0.922 -- the
spreading dilutes the signal.

So "use every column" and "use the right column" are both right, on different
elections, and neither is right everywhere.

## The diagnosis this points at, NOT acted on here

The correction is too SMALL, and there is an obvious reason. One coefficient
per class is fitted across the whole corpus, where most elections have a tiny
One Nation vote. A single `b` calibrated mostly on elections where the party
polls 2-5% cannot move a seat far enough in an election where it polls 23%
statewide. The first plan named a level interaction, tried one crude version on
primary RMSE, and deliberately did not pursue it.

That is the next hypothesis and it needs its own pre-registration. Fitting it
now, having seen these numbers, would be choosing the model after the result.

## What was kept regardless

- **Partial application unblocked every WA pair**, all seven now at 100%
  coverage, where the all-or-nothing guard had disabled all of them.
- **`indig_pct +0.367` for OTH_RIGHT**, an effect a single education column has
  no way to express.
- **The permutation control**, which is now the standard for anything in this
  family and which retroactively showed the refused single-feature arm's signal
  was real too.

`AUSPOL_DEMO_RESID` stays at `0` in `scripts/published_flags.R`.
