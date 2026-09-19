# Pre-registration: the projection mix has no horizon under 30 days

Written 2026-09-20 01:30, before refitting anything. Found while decomposing
the first honest ledger (v39, `AUSPOL_FORECAST_MODE=1` everywhere).

## The finding

`output/projection-mix.csv` is fitted at horizons 30, 90, 180, 365 and 730
days, and `projection_params()` interpolates with `rule = 2`, so every
horizon below 30 days gets the 30-day weight: **trend 0.60, fundamentals
0.40**. The backtests forecast the statewide as at the DAY BEFORE the
election, so they mix a trend that has seen every poll of the campaign
40/60 with a fundamentals prior that has seen none of them.

NSW 2023, from `forecast_statewide_for("nsw", 2023, ...)`:

| | two-party (Labor) |
|---|--:|
| trend as at 24 Mar 2023 (32 polls) | 54.17 |
| fundamentals, leave-one-out | 46.51 |
| projection at "horizon 1" (weight 0.60/0.40) | 51.11 |
| actual | 54.3 |

That 3-point two-party shortfall became Labor first preferences of 31.3
against a 90-day poll mean of 36.5 and an actual 37.0, and every Labor
seat in the state inherited it: nsw2023 Labor winners are under by 7.55
points on average in v39 against AE Forecasts' 1.55, and nsw2023 is the
single worst election in the ledger by delta primary (+2.53 per seat).
WA 2017 shows the same mechanism at a smaller size (trend 51.05,
fundamentals 49.57, projection 50.46, actual 55.5; the polls were also
wrong there). Queensland 2024 barely moves (46.13 vs 47.10).

## The fix

Fit the mix at horizons **1, 7 and 14** days as well (`HORIZONS` in
`scripts/fit_projection.R`; `build_projection_data()` already accepts any
grid). Nothing else changes: same trend, same fundamentals, same
leave-one-election-out weight fit, same interpolation. The daily forecast
refits this table every run and is at horizon ~69 today, so the live number
does not move until the last month of the campaign, when it should.

## Prediction, written before the refit

`w(1)` will come out above 0.9 (a trend that has seen the final polls is
close to the result in every election the corpus holds; the 2019 federal
polling failure is the exception and is one of 42). The backtests then take
the trend almost whole at the day before. Expected on the AEF-7 ledger:
nsw2023 Labor winners' mean miss from -7.55 toward -2; pooled seat log loss
from 0.3012 toward the 0.28s; weighted primary RMSE from 5.22 toward 4.9.
fed2025 (where the trend itself over-called Labor's opponents) may worsen
slightly.

## Criterion

Primary: AEF-7 pooled seat log loss (660 seats) falls by more than 0.005
(the previous plan's realised effects were 0.002 to 0.006; this mechanism
is an order of magnitude larger where it bites, so the bar is set above
noise and well below the prediction). Secondary: weighted primary RMSE
falls. Do-no-harm: no ledger pair's seat log loss worsens by more than
0.010. Unacceptable win: any pair whose gain comes with `w(1)` fitted below
`w(30)` (the weight must rise toward the election, which is the existing
P1 check in `fit_projection.R` extended to the new grid).

## Not a tuned parameter

The mix weight is fitted leave-one-election-out on 42 elections; adding
grid points does not touch the fitting rule. This plan exists so the
before/after is on record, not because a choice is being made after
seeing a number.

## Refit, 01:45 (before the ledger rebuild)

`scripts/fit_projection.R` with horizons 1, 7, 14 added, 42 elections each:

| horizon | w (trend) | held-out MAE mix | trend only | fundamentals only |
|--:|--:|--:|--:|--:|
| 1 | 0.72 | 1.66 | 1.75 | 2.69 |
| 7 | 0.68 | 1.82 | 1.94 | 2.69 |
| 14 | 0.66 | 1.77 | 1.96 | 2.69 |
| 30 | 0.60 | 1.85 | 2.18 | 2.69 |

**The prediction of w(1) above 0.9 was wrong.** Even the day before, a
28% fundamentals weight beats the trend alone held out, because the corpus
holds elections where the final polls missed (2019 federal, WA 2017) and
the fundamentals pulled the right way. The mix's P1-P3 checks pass on the
new grid. NSW 2023's day-before two-party moves 51.1 -> 52.0 (trend 54.2,
actual 54.3); Labor's statewide first preference 31.3 -> 32.2 against
37.0. So this closes about a third of the NSW statewide gap, not all of
it; the rest is a fundamentals prior that was simply wrong for that
election (46.5 two-party, a Coalition win, from twelve years of Coalition
incumbency), and no leave-one-out fit will remove it. The seat-level
remainder (Labor winners under by ~2.7 beyond the statewide) is a
separate item. Ledger rebuild launched 01:47.
