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

Not checked: whether backtests over-call the independent class in seats with several independents (the outcome
check that would size this). Not changed: nothing; this is a trace.
