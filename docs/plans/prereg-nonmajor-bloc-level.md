# Pre-registration: forecasting the national independent vote

Written 2026-09-05, **before the decisive seat-level run**. Committed before
running, per `CLAUDE.md`.

## The defect this addresses

In forecast mode `IND` has no national poll series, so it is folded into `OTH`
and its national level is derived from the PRIOR election's ratio within that
bucket. It is therefore **structurally pinned and cannot grow**. Independents
went 5.54% -> 7.52% nationally in 2025 (+36%); the model forecast 5.23%.

That error is applied to every independent in every seat, and those are the
seats where this model loses seat log loss to AE Forecasts. Measured
substitution of the national IND level (local sim, fed2025):

| IND level | seat log loss |
|---|--:|
| 5.23 (pinned, ours) | 0.3587 |
| 6.50 | 0.3327 |
| 7.52 (true) | 0.3225 |

So the national level is the single largest lever available, worth up to
0.036 of seat log loss.

## What is proposed

Predict the national IND vote from **pre-election observables only**:

- `n_seats` — the number of divisions with an independent nominated. Known at
  nomination close.
- `sum_jump` — aggregate Google Trends salience of independent candidates
  (`output/salience-v6.csv`), summed over that election's IND candidates.
  Campaign-period search interest, available before polling day.

Fitted as `ind_nat ~ n_seats + sum_jump` over federal elections 2007-2025.

## What is already measured (disclosed, not hidden)

These numbers exist before this document and are why it is being written:

| model | LOO RMSE | 2025 error |
|---|--:|--:|
| n_seats + sum_jump | 0.43 pts | −0.83 |
| n_seats + mean_jump | 0.97 | −1.63 |
| baseline (predict the mean) | 2.31 | — |
| in-sample R² for sum_jump model | 0.984 | |

## Criterion, fixed now

**Primary: seat-level log loss on fed2025**, forecast mode, published config,
against the pinned-baseline arm. Adopt only if the arm using the predicted
national IND level beats the pinned arm.

The seat metric is primary, not the national RMSE, because the national level
is a means and the seat forecast is what ships. A national RMSE improvement
that does not reach the seats is not a result.

**The prediction must be leave-one-election-out.** fed2025's own result may
never enter the fit that forecasts fed2025.

## Refusals, named in advance

- **R1 — the year confound.** `cor(sum_jump, year) = 0.906` and
  `sum_jump ~ year` has R² 0.821. **If `ind_nat ~ n_seats + year` performs as
  well as `ind_nat ~ n_seats + sum_jump` on LOO RMSE, this is refused** —
  salience would be carrying nothing beyond "independents have risen over
  time", and a time trend fitted on 7 points is not a forecasting model.
- **R2 — n = 7.** Seven elections against three parameters. Any in-sample R²
  is uninformative here and is not evidence for anything. Only LOO counts,
  and even LOO leaks trend between adjacent elections. If the LOO advantage
  over baseline is under 2x, refuse.
- **R3 — do no harm to the other classes.** The same mechanism must not
  degrade `OTH_RIGHT` or `OTH`. A generic trend extrapolation was already
  tried and REFUSED for exactly this: it moved OTH_RIGHT 5.79 -> 7.56 when
  OTH_RIGHT actually fell, and seat log loss worsened 0.3588 -> 0.3627. If
  the fitted bloc split worsens either class's national error versus pinning,
  refuse for that class and apply it only to IND.
- **R4 — the published forecast does not move as part of this experiment.**
  Victoria 2026 is a separate, deliberate decision after the result is read.
- **R5 — direction.** If the predicted IND level comes out BELOW the pinned
  level, that is a signal the fit is unstable, not a forecast. Refuse rather
  than apply a downward correction to a floor-bounded minor vote.

## What this cannot see

- Seven observations. This cannot distinguish "salience predicts independents"
  from "independents rose and so did Trends coverage" with any confidence, and
  R1 is the only guard against that.
- It says nothing about WHICH seats independents win, only how many votes they
  get nationally. The seat-level distribution is a separate mechanism, and the
  measured remaining deficit to AE Forecasts is concentrated in seats that
  changed hands — which this does not address.
- fed2025 is one election. A win here is not a general result.

## What a win would and would not license

A win licenses shipping a predicted national IND level in forecast mode,
behind a flag, and re-running the other four harnesses. It does NOT license
turning it on for the published Victoria forecast, which is R4.
