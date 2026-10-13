# Defector carry: no overall bias; federal leans over, from the xgb layer (2026-10-14, measured)

**Status: OPEN, small. The first version of this review (+3.0 pts over-call, 13 of 18) was WRONG: it came from
`output/defector-cases-all.csv`, a one-off file from 2026-09-09 with no committed builder, which predates the 13 new
elections and matched only 18 of its 29 cases by name. Retracted the same morning.**

## How it was measured

`scripts/diag_defector_overcarry.R` rebuilds the cases with `fit_defector_discount()`'s own definition
(R/candidate_returns.R): a Labor/Liberal/National candidate with at least 10% at the previous election who stands
under a non-major label in the same seat (or its renamed successor) at the next. Losing candidates count; `was_mp`
marks sitting members. Each case is joined to `output/forecasts.csv` (published as-at path, run 4e03af5) on
election, seat and the defector's class; a class with two candidates in the seat is dropped. Writes
`output/defector-overcarry.csv`.

59 cases over 27 elections; 52 scored. Dropped: fed2007 Corio and Lyons, wa2001 Pilbara, wa2005 Vasse, wa2008
Nedlands (no as-at prediction), nt2020 Fong Lim and Johnston (two candidates in the class).

## Result

Over-call = final predicted primary minus actual, percentage points; positive means we gave the defector too much.
SE is across cases.

| slice | n | mean over-call (SE) | median | over-called | base_pred mean | old party mean |
|---|---|---|---|---|---|---|
| all | 52 | -0.35 (1.49) | +0.27 | 27 | -2.03 | -1.36 |
| sitting members | 34 | +0.36 (1.86) | +1.26 | 18 | -1.84 | -1.79 |
| losing candidates | 18 | -1.69 (2.53) | -0.03 | 9 | -2.41 | -0.53 |
| federal | 6 | **+6.81 (3.72)** | +5.93 | 5 | +0.76 | -7.32 |
| state | 46 | -1.28 (1.58) | -0.27 | 22 | -2.40 | -0.58 |

## Reading

- **No overall bias.** The misses are large in BOTH directions: over-called fed2010 Ryan +23.6, nt2016 Arnhem
  +17.9, qld2017 Pumicestone +14.9, wa2017 Hillarys +7.3; under-called nt2020 Arnhem -30.3, qld2012 Dalrymple
  (Knuth) -25.2, vic2018 Melton -21.6, nt2024 Blain -18.7, nsw2023 Kiama -12.4. The problem is spread, which the
  carry rate cannot fix; which defectors hold up is the open question.
- **Federal leans over, and the xgb layer adds it**: base_pred +0.76, final +6.81 over 6 cases (1.8 SE, thin).
  xgb lifts Dobell 10.0 -> 18.2 (actual 12.2), Tangney 12.0 -> 17.7 (11.9), Monash 18.7 -> 24.9 (27.3), Calare
  28.7 -> 39.6 (39.5). Right on two, wrong on two; not a fix candidate at n=6.
- wa2017 Hillarys is a tail case, not a pattern. Its SEAT-REGISTRY note about WA's higher own-carry (0.693) still
  stands: raising it would make Hillarys worse.
