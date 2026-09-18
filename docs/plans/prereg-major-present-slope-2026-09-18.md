# Pre-registration: majors regress to the statewide level even when the member stays

Written 2026-09-18 evening, immediately after the departed-member slope
shipped, before any run under this switch.

## The measurement

base_pred residual (actual minus predicted, points) for ALP/LNP cells
whose sitting member did NOT depart (re-stood, or the class did not hold
the seat), by predicted share, 23 pairs, deciding-run stage-1 files:

| predicted share | n | mean residual | SE |
|---|---|---|---|
| 0-15 | 138 | +3.44 | 0.48 |
| 15-25 | 586 | +0.76 | 0.19 |
| 25-35 | 987 | +0.33 | 0.14 |
| 35-45 | 1091 | +0.55 | 0.14 |
| 45-55 | 735 | +0.08 | 0.17 |
| 55+ | 320 | -1.56 | 0.30 |

A major far below its statewide level comes back toward it (New England
ALP 13.1 predicted, 18.6 actual; Mallee ALP 15.1 vs 16.8), and one far
above falls toward it. That is a slope below 1 on the deviation, which
majors never had (`default = 1`).

## The rule

`fit_major_departed_slope()` also fits `slope_present`: the same
through-origin regression on the rows where `mp_departed` is FALSE, per
class, leave-target-out, min 40 rows. `conditional_slopes(major_present=)`
applies it to every ALP/LNP cell that is not departed. Gated by
`AUSPOL_MAJOR_SLOPE` (default "0"); independent of `AUSPOL_MAJOR_DEPARTED`.

## Criterion, in order

1. **Primary**: mean absolute base_pred error on the ~3,855 non-departed
   major cells, before vs after, all six harnesses at
   `AUSPOL_XGB_PRIMARY=0`; must fall by more than one clustered SE
   (cluster = cell).
2. **Do-no-harm**: pooled seat log loss over 23 pairs not worse by more
   than one SE (cluster = pair). Note this touches almost every seat, so a
   small per-cell gain can still move the pooled number either way; the
   pooled number is the guard, not the target.
3. **Secondary**: the departed cells (already shipped) must not regress;
   the 0-15 and 55+ bands specifically; the two named seats.

Unacceptable-win clause: the fitted slope should sit near 0.85-0.95. A
fitted value below 0.75 for a class means the fit is confounded (the
departed rows leak in, or the level definition differs from the
harness's) and the arm is not run until that is understood.

## Result, 2026-09-18 18:30 (base_pred only, 20,000 sims, on top of the shipped departed tier)

Fitted, leave-target-out: ALP 0.94-0.95, LNP 0.89-0.90 (n ~1,800 per
class), inside the pre-registered 0.85-0.95 window.

| metric | before (arm M) | after | delta | SE |
|---|---|---|---|---|
| non-departed major cells (n=3855), mean abs error | 3.579 | 3.530 | **-0.049** | 0.013 |
| of which predicted 0-15 (n=135) | | | -0.770 | (bias -3.28 -> -1.81) |
| of which predicted 55+ (n=319) | | | -0.202 | (bias +1.55 -> +0.32) |
| of which 35-55 (n=1846) | | | +0.05 | |
| departed cells (n=365) | 4.659 | 4.590 | -0.069 | 0.026 |
| pooled seat log loss | 0.2951 | 0.2957 | -0.0012/pair | 0.0019 |
| accuracy | 0.8878 | 0.8902 | | |

10 of 23 pairs better on log loss. New England ALP 12.7 -> 14.0 (actual
18.6), Mallee ALP 15.9 -> 16.9 (16.8). Other classes unchanged.

**Verdict: criterion 1 met at 3.8 SE, do-no-harm met (pooled +0.0006,
inside one SE), SHIPPED.** Caveat recorded from the SHAP read on Northern
Tablelands: the as-at xgb layer had already learned part of this
regression-to-mean through the `base_pred` feature, so the full rebuild
(which retrains it on the new base_pred) is the number that counts.
