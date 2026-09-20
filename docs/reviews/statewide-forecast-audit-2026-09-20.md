# The day-before statewide forecast, audited for every scored pair

2026-09-20 13:40, `scripts/audit_statewide_forecast.R` (rerun after any
change to the trend, the mix or the folding). Written as the input to the
walk-through with Pete that `NEXT-STEPS.md` model item (0) asks for: since
the backtests became predictive throughout, the statewide level the seats
swing toward is the biggest lever in the ledger, and these are the cycles
where it misses. Run with the Nationals fold in place but before its
anchoring refinement, so the WA rows will move a little on the rerun.

**Mean |miss| over Labor, Coalition and Greens first preferences, points,
lower is better; `ALP miss` is forecast minus actual (negative = Labor
under-forecast).**

| pair | mean abs miss | ALP miss | polls in cycle | trend TPP | fundamentals TPP | anchored TPP |
|---|--:|--:|--:|--:|--:|--:|
| wa2001 | 3.60 | +4.33 | 44 | 51.1 | 51.3 | |
| wa2017 | 3.14 | -7.04 | 45 | 51.1 | 49.6 | 50.6 |
| fed2019 | 2.83 | +2.19 | 204 | 52.8 | 50.4 | |
| wa2005 | 2.64 | +1.66 | 64 | 49.8 | 56.3 | |
| nsw2023 | 2.26 | -4.83 | 32 | 54.2 | 46.5 | 52.0 |
| qld2020 | 2.17 | -4.17 | 18 | 51.0 | 54.8 | |
| fed2013 | 2.03 | +1.72 | 382 | 47.2 | 51.5 | |
| wa2008 | 1.96 | +3.30 | 64 | 52.1 | 48.0 | |
| qld2024 | 1.94 | -2.88 | 30 | 46.1 | 47.1 | |
| fed2010 | 1.86 | +1.29 | 293 | 52.3 | 55.0 | |
| vic2018 | 1.73 | -3.13 | 59 | 54.2 | 56.0 | |
| vic2014 | 1.66 | -0.70 | 68 | 53.6 | 52.6 | |
| fed2025 | 1.57 | -3.03 | 448 | 51.7 | 53.6 | |
| fed2016 | 1.29 | -1.46 | 312 | 50.2 | 48.2 | |
| fed2007 | 1.28 | +0.91 | 234 | 55.2 | 50.0 | |
| sa2026 | 1.18 | -1.53 | 15 | 61.4 | 51.0 | |
| vic2022 | 1.15 | -1.41 | 36 | 56.9 | 50.1 | |
| wa2013 | 1.06 | +0.05 | 30 | 43.0 | 47.0 | |
| sa2022 | 1.05 | -2.14 | 11 | 53.2 | 52.1 | |
| nsw2019 | 1.03 | -0.51 | 53 | 49.3 | 52.2 | |
| fed2022 | 0.80 | +1.63 | 303 | 53.4 | 50.2 | |
| wa2025 | 0.45 | +0.30 | 15 | 57.0 | 55.9 | |

The day-before mix weight is 0.72 on the trend everywhere (the mix table
has one weight per horizon, not per region).

## Three cycles to walk, one row each

**wa2017** (Labor -7.0): the polls had Labor's two-party at 51.1 the day
before against a 55.5 result; the fundamentals said 49.6. Both sources
missed a landslide the same way, so no mix weight fixes it. The polls
themselves are the question: 45 in the cycle, and the final-week ones are
in the anchor's file. Question for Pete: do we treat WA polls as a known
under-reader of Labor landslides (2017 and 2021 both), or is 2017 a one-off?

**nsw2023** (Labor -4.8): the trend had Labor 54.2 (actual 54.3) and the
fundamentals 46.5, a Coalition win from twelve years of Coalition
incumbency; the 0.72/0.28 mix lands at 52.0. This is the clearest case of
the fundamentals prior being wrong late in a long incumbency. Question: is
"years in office" the right sign for a state government after twelve
years, or does the fundamentals model need a term that flips it? The
leave-one-out fit already includes this election's own answer in the
other 41.

**fed2019** (Labor +2.2): the polling failure. Trend 52.8, fundamentals
50.4, actual 48.5. Every published forecast missed it; the only lever here
is the width, not the level, and the FP_EXTRA_SD term already carries it.
Question: whether to add a "polling error is correlated within a cycle"
term to the seat simulation so a miss like this moves all seats together
(it already partly does through the shared statewide draw).

## The TCP MAE gap is the same miss (added 15:20, ledger v42)

Two-candidate-preferred MAE on the ledger's definition (seats where the
side named the actual final two; points, lower is better), ours vs AEF,
with the mean signed error of our named candidate (negative = we had
them too low):

| pair | n ours | n AEF | ours | AEF | gap | our signed mean |
|---|--:|--:|--:|--:|--:|--:|
| nsw2023 | 77 | 83 | 6.36 | 4.32 | **+2.04** | **-2.02** |
| fed2022 | 136 | 141 | 3.24 | 2.96 | +0.28 | +0.66 |
| qld2024 | 88 | 87 | 3.32 | 3.08 | +0.24 | +0.55 |
| vic2022 | 69 | 73 | 3.15 | 3.06 | +0.09 | +1.10 |
| fed2025 | 133 | 132 | 4.17 | 4.13 | +0.03 | +0.07 |
| wa2025 | 48 | 47 | 4.25 | 4.26 | -0.01 | -0.06 |
| sa2026 | 35 | 37 | 4.08 | 4.52 | -0.44 | -1.42 |
| all | 586 | 600 | 3.99 | 3.63 | +0.36 | +0.02 |

nsw2023 alone is 157 of the 211 seat-points of gap. Its ten worst seats
(Parramatta +16, Heathcote +15, Kogarah -14, Auburn -14, Granville -12,
Canterbury -12, Port Stephens -12, Lismore -12, Heffron -11, Wallsend
-10) are Labor too low across western Sydney and the Hunter, which is the
statewide Labor -4.8 above wearing a seat mask. So the roadmap's TCP item
(final-two flow for excluded-party cells) is not where the TCP gap is;
the nsw2023 statewide walk is.

## What this audit does not say

It does not decompose the seat-level miss beyond the statewide one (that is
the worst-seats pass in `SEAT-REGISTRY.md`), and it says nothing about the
Coalition/Nationals fold's anchoring refinement, which was being smoked
while it ran.
