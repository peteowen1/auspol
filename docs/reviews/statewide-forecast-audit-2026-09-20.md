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

## Calibration by band: the log-loss gap is six near-certain seats (added 15:35)

Favourite's stated win probability against how often the favourite won,
660 ledger seats (roadmap item 5). Both sides are calibrated band by band;
the one difference is the top band.

| band | ours n | ours hit (mean p) | AEF n | AEF hit (mean p) |
|---|--:|--:|--:|--:|
| 0.40-0.60 | 48 | 0.56 (0.54) | 53 | 0.55 (0.53) |
| 0.60-0.80 | 91 | 0.66 (0.71) | 112 | 0.67 (0.71) |
| 0.80-0.95 | 166 | 0.87 (0.89) | 142 | 0.87 (0.89) |
| 0.95+ | 354 | **0.98** (0.98) | 352 | **1.00** (0.99) |

Six of our 95%+ favourites lost; one of AEF's did (Bateman wa2025, which
both missed). Log loss per seat, ours vs AEF (lower is better):

| pair | seat | we said | AEF said | winner | ours | AEF |
|---|---|--:|--:|---|--:|--:|
| fed2022 | Tangney | LNP 0.951 | 0.916 | ALP | 3.10 | 2.48 |
| fed2025 | Braddon | LNP 0.950 | 0.848 | ALP | 4.00 | 2.04 |
| nsw2023 | Parramatta | LNP 0.964 | 0.717 | ALP | 3.33 | 0.33 |
| qld2024 | Maryborough | ALP 0.951 | 0.938 | LNP | 3.08 | 2.90 |
| qld2024 | South Brisbane | GRN 0.984 | 0.836 | ALP | 4.39 | 1.82 |
| wa2025 | Bateman | LNP 0.958 | 0.964 | ALP | 3.17 | 3.43 |

Net 8.1 log-loss points against AEF from these six, against a total gap of
6.1 (0.0092 x 660); the other 654 seats are ahead of AEF by 2.0. Two are
the state-swing group (Tangney, Braddon: a WA and a Tasmanian swing the
federal model did not carry), Parramatta is the nsw2023 statewide miss
again, South Brisbane is a Greens seat lost on Labor preferences flowing
the other way. **The ledger is decided in the tails**: the question is not
the mean forecast in these seats but why the simulation gave the loser
under 5% when AEF gave 8-28%. Ties to the open variance items (majors'
floor-seat variance, NSW `seat_sd`) and to the state-deviation term for
federal pairs.

## nsw2023 walked end to end (16:10, `scratchpad/walk_nsw2023.R`)

**The polls the trend saw**, last month (Labor two-party as published, then
first preferences): Newspoll 52.0 (36/37), Freshwater 53.0 (39/37), Morgan
52.5 and 53.5, Resolve 52.5 (38/38), Freshwater 53.0 (37/37), Newspoll
54.5 (38/35). 32 polls in the cycle, the last dated 21 March.

**The trend at the cutoff**: Labor 36.5 (band 34.2-38.9), Coalition 34.7,
Greens 10.6, Other 16.1; two-party 54.2. **The count: Labor 37.0,
Coalition 35.4, two-party 54.3.** The trend was right to half a point.

**The fundamentals said 46.5**, a Coalition win. The row: Labor in
opposition 12 years, Labor governing federally (`fed_aligned = 1`), prior
two-party 48.0. Ridge fit on 61 elections, lambda 2.89, intercept 50.6;
contributions in points of Labor two-party:

| feature | value | beta (per sd) | points |
|---|--:|--:|--:|
| is_incumbent | 0 | +2.61 | -3.11 |
| fed_aligned | 1 | -2.43 | -3.22 |
| govt_years | 0 | -3.43 | +3.13 |
| opp_years | 12 | +0.67 | +1.90 |
| prev1 | 48.0 | +2.43 | -0.97 |
| prev_avg | 49.0 | +0.38 | -0.23 |

Leave-one-out 46.5 (in-sample 48.1). The corpus's own long-opposition
cases say the opposite of the fit: after 8+ years out, Labor's swing was
nsw1995 +1.5, nsw2019 +2.3, nsw2023 +6.3, sa2002 +0.6, wa2001 +8.1,
wa2017 +12.8, wa1993 -3.1, mean +4.1; the ridge gives `opp_years` +1.9
and cancels it with `fed_aligned` -3.2 (state Labor punished for federal
Labor governing).

**The mix at one day**: w(trend) = 0.72, fitted on 42 elections where the
trend's day-before MAE is 1.75 and the fundamentals' 2.69 (mix 1.64, LOO
1.66). Projection 0.72 x 54.2 + 0.28 x 46.5 = **52.0**.

**The anchoring then moved first preferences to hit 52.0**: Labor 36.5 ->
32.1 (actual 37.0), Coalition 34.7 -> 36.8 (35.4). The whole nsw2023 miss
(-4.8 Labor, +1.4 Coalition) is this step; the trend itself would have
scored 0.5 and 0.7.

Three questions, in order of leverage:

1. **`fed_aligned`** is the largest negative and the shakiest theory (a
   federal-drag term fitted across 61 elections of mixed vintage). Its
   leave-one-out value is not known; a pre-registered arm drops it and
   scores the 42 mix elections on day-before MAE.
2. **The anchoring takes 4.4 points off Labor and gives the Coalition 2.1**
   for a 2.1-point two-party move: the asymmetry already seen on wa2001.
   Why not a symmetric split, or a move in proportion to each party's band?
3. **The 0.72 weight** is the 42-election optimum and is not the problem on
   its own; a fundamentals model that is less wrong on long oppositions is.

## What this audit does not say

It does not decompose the seat-level miss beyond the statewide one (that is
the worst-seats pass in `SEAT-REGISTRY.md`), and it says nothing about the
Coalition/Nationals fold's anchoring refinement, which was being smoked
while it ran.
