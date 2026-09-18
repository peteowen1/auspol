# Pre-registration: a major party loses vote when its sitting member departs

Written 2026-09-18 evening, before any run under the switch. From the
worst-seat pass (Cabramatta, Parramatta, Northern Tablelands, Riverstone,
Monaro, Braddon all have a retiring major-party member) and then measured
across the whole corpus on the deciding run's stage-1 (base_pred only)
files.

## The measurement that motivates it

base_pred residual (actual minus predicted primary, points) for ALP and
Liberal/National classes, 23 pairs, by whether the sitting member re-stood:

| group | n | mean residual | SE |
|---|---|---|---|
| sitting member re-stood | 1567 | +0.56 | 0.12 |
| sitting member departed | 361 | **-2.77** | 0.35 |
| class had no sitting member | 2292 | +0.25 | 0.10 |

Negative in 19 of 22 pairs. The loss scales with the vote: by predicted
share band, under 35 +1.8, 35-45 -1.6, 45-55 -3.0, over 55 -6.1; a
regression gives residual = 7.8 - 0.223 x predicted share. That is the
shape of a slope below 1 on the deviation from the statewide level, which
is exactly what `dev_slope()` already does for IND/OTH_RIGHT/GRN/ONP via
`conditional_slopes()`. The major parties have no such tier: they get
`default = 1` regardless of who stands. `scratchpad/retire_cases.csv`.

## The rule

`fit_major_departed_slope(target)`: leave-target-out, for ALP and LNP
separately, `lm(actual_dev ~ 0 + prior_dev)` over seat/class rows where
the class held the seat and its member did not return under that label
(`mp_departed` in `candidate_returns()`), min 40 rows per class, else the
class keeps slope 1. `conditional_slopes()`/`screened_slopes()` apply it
through a new `major_departed` argument; every other row is unchanged.

## Switch

`AUSPOL_MAJOR_DEPARTED` (default "0"). One arm. No second arm declared:
the slope is fitted, not chosen.

## Criterion, in order

1. **Primary, targeted**: mean absolute base_pred error on the ~361
   departed-major cells, all six harnesses at `AUSPOL_XGB_PRIMARY=0`,
   before vs after. Must fall by more than one clustered SE (cluster =
   cell; these are 361 independent seats).
2. **Do-no-harm**: pooled seat log loss over all 23 pairs, same arms, not
   worse by more than one SE clustered by pair.
3. **Secondary**: the six named seats above; and the OTHER classes in the
   departed seats (the lost vote must land somewhere: check the opponent
   major's residual does not get worse).

What would make an apparent win unacceptable: a fitted slope that varies
wildly by target (print the per-target fitted values; if the range
exceeds 0.15 the fit is unstable and shrinkage toward 1 is needed before
shipping).

If met, ship in `published_flags.R` and let the full
`scripts/rebuild_forecasts.sh` decide the ledger number.

## Result, 2026-09-18 18:15 (base_pred only, 20,000 sims, all six harnesses)

Fitted slopes, leave-target-out: ALP 0.58-0.61, LNP 0.64-0.67 (n 150-190
per class per target), range under 0.04, stable.

| metric | before | after | delta | SE |
|---|---|---|---|---|
| departed-major cells (n=365), mean abs primary error, points | 5.371 | 4.659 | **-0.712** | 0.107 |
| same cells, mean bias (predicted minus actual) | +2.72 | +0.97 | | |
| non-departed major cells (n=3855), mean abs error | 3.580 | 3.579 | | |
| pooled seat log loss, 2,112 seat-elections | 0.2979 | 0.2951 | -0.0022/pair | 0.0022 |

14 of 23 pairs better on log loss. Other classes in the departed seats
unchanged (GRN 2.08 -> 2.11, IND 3.74 -> 3.74, opponent major 4.39 -> 4.46
for ALP-held, 3.79 -> 3.54 for LNP-held). Named seats: Parramatta 2.20 ->
1.47, Monaro 2.66 -> 1.98, Braddon 2.86 -> 2.38, Riverstone 0.91 -> 0.52,
Cabramatta unchanged (0.03: the ALP primary miss there does not change the
winner). A residual +1.0 bias remains on the departed cells, i.e. the
fitted slope is if anything conservative.

**Verdict: criterion met at 6.7 SE, do-no-harm met, SHIPPED**
(`AUSPOL_MAJOR_DEPARTED = "1"` in `published_flags.R`). The full
`rebuild_forecasts.sh` decides the ledger number.
