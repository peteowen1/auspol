# The day-before statewide level lags the late polls (screen, 2026-10-10)

A SCREEN, not a result: nothing was pre-registered and nothing ships from it.

## How it was found

Chasing the Labor-v-Greens two-candidate over-call (Richmond, Footscray, Brunswick, Preston, Pascoe Vale
vic2022: Labor's TCP 5-8 points high, AEF within a point in most). The how-to-vote card fix
(`AUSPOL_HTV_FLOW`, 2026-09-18) is in, so it is not the flow table any more. It is the Liberal PRIMARY: under
by 3.7 points on average across ALL 88 seats (base_pred already +2.8), because the day-before statewide forecast
had the Coalition at 31.4 against 34.5 (`BV0` line, stage-6 log). In seats where Liberal preferences went to the
Greens, too little flows, so Labor's TCP is high. The polls were right: the last 28 days averaged 34.1; the trend
was held down by September-October readings (Morgan, Resolve 27.5-28) and did not follow the late rise.

## The screen

`scripts/screen_trend_vs_avg28.R`: for each of the 22 elections, the shipped day-before forecast
(`forecast_statewide_or_oracle()`, time-forward, 20,000 draws) against a plain mean of the polls fielded in the
28 days before polling day, on ALP/LNP/GRN, scored on the actual statewide share (candidacies).

Mean absolute error, points (lower is better):

| scope | elections | trend | 28-day average | paired diff (SE, clustered on election) | average better in |
|---|---|---|---|---|---|
| all 22 | 22 | 1.90 | 1.73 | -0.17 (0.26) | 15 |
| without WA | 16 | 1.55 | 1.29 | -0.26 (0.13) | 14 |
| without WA, ALP | 16 | 2.08 | 1.59 | -0.49 (0.27) | 10 |
| without WA, LNP | 16 | 1.79 | 1.32 | -0.46 (0.27) | 8 |
| without WA, GRN | 16 | 0.78 | 0.96 | +0.18 (0.16) | 7 |
| federal only | 7 | 1.71 | 1.40 | -0.31 (0.22) | 7 |

WA is excluded POST HOC, for a data reason: WA polls report the Nationals separately, so the poll file's LNP
column there is Liberals only (the v42 finding) and the plain average is wrong by construction (wa2013 45.5 vs
53.2 actual). The trend already folds NAT into the class. A fix would have to do the same before averaging.

## What it does and does not say

The trend lags the late polls on the majors; the plain average is noisy where polls are few (2-6 in most state
elections) and slightly worse on the Greens. Earlier refusals measured the trend on held-out polls across the
whole campaign (`reviews/poll-lag-2026-08-19.md`; per-cycle volatility +0.2%), not on the day-before level that
every seat inherits, so this does not contradict them. A fix needs pre-registering and judging on seat log loss
over all 22 elections, not on this screen.
