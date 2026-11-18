# Essendon: why the independent class is 85% (trace, 18 Nov 2026)

Our boldest lone call on the 17 and 18 Nov benchmark captures: Independent 0.848 in Essendon. Sportsbet, TAB,
AE Forecasts and The Swing Is On all favour someone else (Sportsbet's Yildiz price on 18 Nov, $7.50, margin removed: 9.5%; the only book pricing him).

Trace: `AUSPOL_TRACE_SEAT=Essendon AUSPOL_OUT_SUFFIX=-traceess AUSPOL_N_SIMS=2000 Rscript scripts/fit_seats_full.R`,
published configuration, 18 Nov. It reproduces the published point forecast exactly (IND 22.38). The run's outputs
were moved out of `output/` after the run.

## The independent class is three people

The VEC list has three independents in Essendon: Oscar Yildiz, Ava Adams and Anab Mohamud. The model forecasts
one `IND` class and simulates it as one candidate, so the 22.4% is all three combined, and the class gets
preferences and wins as if one person held it.

## Where the 22.4% comes from (first preferences, %)

| Stage | IND | What moved it |
|---|---|---|
| Last time (vic2022) | 0.00 | no independent stood |
| Own-vote substitute | 13.92 | Yildiz's 23.5 in Pascoe Vale 2018 x cross-seat carry 0.592 (`AUSPOL_CROSS_SEAT_VOTE`, n = 354 cross-seat cases) |
| Base, then One Nation fill | 10.95 | the base shrinks as One Nation's 14.5 is fitted in |
| Before the trees (`base_pred`) | 11.46 | |
| After the xgb trees | 22.59 | **+13.24**, below |
| Final | 22.38 | small later adjustments |

The trees' +13.24, largest contributions:

| Feature | Value | Contribution (points) |
|---|---|---|
| `jump` (search-interest rise) | 0.875 | +4.04 |
| `n_cand_now` (candidates in the class) | 3 | +3.74 |
| `council_pct` (best council vote of the class) | 45.9 (Ava Adams, Moonee Valley 2024) | +2.32 |
| `seat_outperf` | NA | +1.23 |
| `council_elected` | 1 | +0.95 |
| `own_prev_pcv` | 13.92 | +0.53 |

Other classes: Labor 19.8, Liberal 22.2, Greens 17.3, One Nation 14.8. A four-way race at 17-22% each, which is
why a 22.4% class that collects preferences wins 85% of simulations.

## What this means

- About 7 of the tree's 13 points come from the class having three candidates (`n_cand_now`) and from Ava Adams'
  council vote. Both are correct for predicting the class TOTAL. But the class total is not one person's vote: if
  Yildiz polls his carried ~14 and the other two split the rest, no single independent leads, and the seat goes to
  whoever leads among Labor, Liberal and Greens.
- The same structure is in 25 of 88 seats (two or more independents). Essendon is the only one where it decides the
  favourite; Kew (3 independents, class 27.5%) is at 0.19 and Footscray (4, 17.7%) at 0.12.
- `jump` 0.875 is the class's search-interest rise; not checked here whose name drives it (Yildiz or a namesake).

Not changed: nothing; this is a trace.

## Backtest check (same day): the over-call is real in seats with several independents

`output/published-predictions.csv` (13 Nov build, 35 pairs, 19,616 rows), independent-class rows only. "Expected" is
the sum of our win probabilities, "won" is how often the class actually won; equal is calibrated. z is
(won - expected) / sqrt(sum p(1-p)), treating seats as independent.

| Rows where we gave the independents 20%+ | Seat-elections | Elections | Expected wins | Won | z |
|---|---|---|---|---|---|
| One independent standing | 74 | 31 | 55.0 | 56 | +0.32 |
| Two or more independents | 45 | 21 | 29.9 | 23 | **-2.61** |

So the single-independent case is calibrated and the several-independents case over-calls by about 7 wins in 45
(23%). Across every election, the top independent held 77% of the class's vote in seats with two or more (577 seats).

Two real examples of the mechanism (first preferences):

- **Waite, SA 2022:** Labor 26.6 (won), Liberal 25.9, Sam Duluk (IND) 19.7, Heather Holmes-Ross (IND) 14.6. The two
  independents together were 34.3, the most of anyone; we gave the class 0.70. Split, neither came close.
- **Monash, federal 2025:** Liberal 31.8 (won), Labor 20.3, Deb Leonard (IND) 17.1, Russell Broadbent (IND) 10.2.
  Together 27.3; we gave the class 0.61.

Not every loss is this: Mildura 2022 (Cupper led on primaries and lost on preferences) and Wentworth 2019 (Phelps
alone) are other misses. Scripts: `%TEMP%/multi_ind_bt.R`, `%TEMP%/ex.R` (this session).
