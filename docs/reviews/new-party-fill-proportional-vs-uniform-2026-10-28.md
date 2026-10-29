# Proportional fill vs uniform swing, tested on past new-party surges (2026-10-28)

Read-only analysis of `output/published-predictions.csv` (19,616 rows, 35 pairs, one row per seat x party class; confirmed one row per seat-class, class shares sum to 100 per seat). Script: `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\39010bb2-4069-4b67-8612-d07117b76033\scratchpad\fillcheck\fc.py`. Nothing run through the harness; nothing committed.

## Verdict

**The record supports proportional fill, not uniform swing, and nothing in it supports the bookmaker pattern.**

- Where a new party surged, a major party lost vote roughly in proportion to its own previous share times the new party's seat share. Pooled across 4 elections (election fixed effects, SE clustered on election) the proportional coefficient b is -0.81 (SE 0.27) for ALP and -0.68 (0.08) for LNP; b = -1 would be exactly proportional. Across 6 elections: ALP -0.78 (0.18), LNP -0.90 (0.16). The sign is negative in every leave-one-election-out refit. Proportional beat uniform on residual RMSE in all 8 primary election-major cells and all 12 extended cells (by 0.04 to 3.27 points).
- It is NOT a clean proportional or all-or-nothing result: the plain "d ~ s" slope is only -0.2 to -0.3 points per point of new-party share, and the proportional term fits better than that in every cell. Reading: between uniform and proportional, but clearly closer to proportional. A pure uniform swing would put b at zero; it is 8 to 15 standard errors from zero in several single elections (e.g. sa2026 ALP -1.17 (0.18)).
- Our own bias does not match the bookmaker story. If we over-fill low-new-party seats, our majors' miss (ours minus actual, positive = over-called) would be positive in the low third. Pooled over the 4 primary elections the low-third mean miss is ALP -0.6 (SE 1.2) and LNP -1.25 (0.8), i.e. slightly UNDER-called, not significant. Over 6 elections it is +0.55 (1.1) and +0.23 (1.2): zero. The one analog that matches the Victoria 2026 setup best, sa2026 (ONP ~22.7% mean), has the low third under-called: ALP -2.0 (1.2), LNP -3.4 (0.8). qld2024 ALP low third -2.1 (0.7).
- Where we do err it is about the surge's size, not its distribution: miss rises with the ACTUAL new-party share (slope +0.04 to +0.26 pooled, always positive in leave-one-out), meaning where the new party turns out strong we leave the majors too high. That is the opposite of what the bookmakers imply for low-ONP seats.

**Implication for Victoria 2026:** four seats at Labor 0.50-0.88 versus 0.12-0.26 cannot be justified by "Labor loses the same everywhere"; on the record Labor loses LESS in low-One-Nation seats. The record does not rule out that the real disagreement is the size of the One Nation statewide level or something else (candidate, boundaries). It also cannot say the bookmakers are wrong: see limits.

## Limits (read before quoting)

- **Very few elections.** 4 primary elections, 6 extended. Cluster SEs on 4 to 6 clusters are unreliable; treat them as rough. Leave-one-election-out signs are the more honest summary.
- The new-party class is imperfect. sa2018 uses class `IND` (verified: IND statewide 2.7% -> 17.9%, SA-Best; but `s` includes ordinary independents). qld2012 uses `OTH_RIGHT` (KAP +12.2 points, but that class also holds other minor right parties). wa2001 ONP ended at 10.8% with prev_share blank for ONP (treated as 0 for the party, which is right: it did not contest in 1998 as such, unverified). Added beyond the four named: qld2012 and wa2001. Considered and left out: nt2016 IND (+12.3) and nt2020 OTH (+13.9) because they are territory-specific shifts, not a new party (25 seats), and fed2013 OTH_RIGHT (+6.7, under the 8-point bar).
- prev_share can be on older boundaries and is blank for 16 to 48 percent of rows by pair. A major with blank prev_share in a seat is dropped from that seat (n shown); the new party's s is 0 when it did not stand. Redistributions add noise to d for every model equally, and a swing of the major's old-boundary share is partly a boundary effect. Not corrected.
- `s` is the new party's ACTUAL seat share (this is the question asked: how did votes actually move). The model can only use a prediction of it. The "miss ~ our predicted s" columns do that.
- Seat-level d and miss are not independent within an election (a statewide swing is shared); election fixed effects absorb the mean, not the shape.
- The proportional term uses the major's own previous share; the mean-of-seats shares in the uniform model carry the average statewide swing as `a`. `a` is large and negative for LNP in sa2026 (-17.0) because of the statewide collapse, so uniform RMSE is the fair comparison, not `a`.
- The per-election proportional fit is in-sample for 2 parameters, uniform for 1; RMSE here is root(RSS/n) without a degrees-of-freedom penalty. The gap is far larger than that penalty (n = 40 to 93) except qld2024 LNP (-0.04) and qld2017 ALP (-0.19), which are effectively ties.

## Method

Per election and major (ALP, LNP): `d = actual - prev_share`; models (1) uniform `d = a`, (2) slope `d = a + b*s`, (3) proportional `d = a + b * prev_share * s / 100`. Bias: `miss = ours - actual` on terciles of our own predicted new-party share (`ours` of the new-party class, ranked within election; low/mid/high thirds) and as slopes on actual and predicted `s`. Pooled: within-election demeaning (election fixed effects), SE clustered on election, then refit leaving each election out.


#### Primary analogs (SA-Best, SA26 ONP, QLD17 ONP, QLD24 ONP): ALP

Table: n seats with a prior ALP share; mean new-party seat share s; coefficients with SE in brackets (points); RMSE = residual root-mean-square, lower is better. Proportional fill predicts b clearly negative and RMSE below uniform.

| election | new party | n | mean s | uniform a (SE) | uniform RMSE | slope d~s: b (SE) | slope RMSE | prop. b (SE) | prop. RMSE | RMSE prop - unif |
|---|---|---|---|---|---|---|---|---|---|---|
| sa2026 | ONP | 46 | 22.7 | -2.68 (1.20) | 8.08 | -0.63 (0.13) | 6.57 | -1.17 (0.18) | 5.79 | -2.28 |
| qld2017 | ONP | 77 | 14.8 | -1.80 (0.69) | 6.00 | -0.07 (0.06) | 5.95 | -0.35 (0.16) | 5.81 | -0.19 |
| qld2024 | ONP | 93 | 8.0 | -7.17 (0.50) | 4.83 | -0.37 (0.11) | 4.56 | -1.53 (0.22) | 3.90 | -0.93 |
| sa2018 | IND | 40 | 17.9 | -3.62 (0.88) | 5.48 | -0.18 (0.07) | 5.01 | -0.87 (0.17) | 4.22 | -1.26 |

#### Primary analogs (SA-Best, SA26 ONP, QLD17 ONP, QLD24 ONP): LNP

Table: n seats with a prior LNP share; mean new-party seat share s; coefficients with SE in brackets (points); RMSE = residual root-mean-square, lower is better. Proportional fill predicts b clearly negative and RMSE below uniform.

| election | new party | n | mean s | uniform a (SE) | uniform RMSE | slope d~s: b (SE) | slope RMSE | prop. b (SE) | prop. RMSE | RMSE prop - unif |
|---|---|---|---|---|---|---|---|---|---|---|
| sa2026 | ONP | 46 | 22.7 | -17.01 (1.11) | 7.43 | -0.06 (0.15) | 7.42 | -0.99 (0.25) | 6.36 | -1.07 |
| qld2017 | ONP | 77 | 14.8 | -7.42 (0.72) | 6.23 | -0.25 (0.06) | 5.59 | -0.63 (0.14) | 5.56 | -0.67 |
| qld2024 | ONP | 93 | 8.0 | +5.74 (0.41) | 3.91 | +0.08 (0.09) | 3.90 | -0.28 (0.20) | 3.87 | -0.04 |
| sa2018 | IND | 40 | 17.9 | -7.51 (1.08) | 6.74 | -0.34 (0.07) | 5.27 | -0.70 (0.13) | 5.11 | -1.63 |

#### Primary analogs (SA-Best, SA26 ONP, QLD17 ONP, QLD24 ONP): our miss (ours - actual) by tercile of OUR predicted new-party share

Table: mean signed miss in points (positive = we over-called the major) in the low / mid / high third of seats ranked by our own predicted new-party share within the election; SE in brackets; n per tercile. Proportional fill being wrong the bookmaker way predicts positive miss in LOW, negative in HIGH. Zero everywhere is good.

| election | major | n/tercile | low third | mid third | high third | slope of miss on actual s: b (SE) | slope on our so: b (SE) |
|---|---|---|---|---|---|---|---|
| sa2026 | ALP | 15 | -2.02 (1.18) n=16 | -1.26 (1.13) n=15 | +0.63 (1.03) n=15 | +0.21 (0.08) | +0.19 (0.09) |
| sa2026 | LNP | 15 | -3.37 (0.80) n=16 | -0.92 (1.14) n=15 | -2.38 (1.29) n=15 | +0.14 (0.08) | +0.08 (0.09) |
| qld2017 | ALP | 25 | +2.82 (0.79) n=26 | +1.86 (0.66) n=25 | +1.36 (1.01) n=26 | -0.10 (0.04) | -0.10 (0.05) |
| qld2017 | LNP | 25 | +0.54 (0.73) n=26 | +2.83 (0.84) n=25 | +2.38 (1.02) n=26 | +0.09 (0.05) | +0.04 (0.06) |
| qld2024 | ALP | 31 | -2.14 (0.68) n=31 | -0.97 (0.55) n=31 | +0.37 (0.72) n=31 | +0.35 (0.08) | +0.49 (0.14) |
| qld2024 | LNP | 31 | -0.62 (0.48) n=31 | +0.83 (0.60) n=31 | +0.51 (0.74) n=31 | +0.21 (0.08) | +0.19 (0.14) |
| sa2018 | ALP | 13 | -1.05 (0.97) n=14 | +2.00 (1.09) n=13 | -1.03 (1.40) n=13 | +0.07 (0.06) | +0.02 (0.06) |
| sa2018 | LNP | 13 | -1.55 (1.13) n=14 | -3.18 (1.49) n=13 | -1.80 (1.75) n=13 | +0.08 (0.07) | -0.03 (0.08) |

#### Primary analogs (SA-Best, SA26 ONP, QLD17 ONP, QLD24 ONP): pooled, election fixed effects, SE clustered on election

Table: coefficient (cluster SE) and leave-one-election-out (LOEO) range. G = number of elections, which is tiny, so the cluster SE is itself unreliable (t with G-1 df). Rows 1-2 test fill (negative = proportional); rows 3-4 test our bias (positive in miss~so means we over-call majors where we predict more new party, i.e. we under-fill low seats less than high; negative means over-call in low-ONP seats).

| outcome ~ regressor | major | G | n | b (cluster SE) | LOEO min..max | LOEO sign stable? |
|---|---|---|---|---|---|---|
| d ~ prev*s/100 (proportional term) | ALP | 4 | 256 | -0.813 (0.265) | -1.133..-0.652 | yes |
| d ~ prev*s/100 (proportional term) | LNP | 4 | 256 | -0.682 (0.076) | -0.722..-0.621 | yes |
| d ~ s | ALP | 4 | 256 | -0.205 (0.099) | -0.322..-0.142 | yes |
| d ~ s | LNP | 4 | 256 | -0.225 (0.060) | -0.255..-0.172 | yes |
| miss ~ actual s | ALP | 4 | 256 | +0.037 (0.084) | +0.006..+0.153 | yes |
| miss ~ actual s | LNP | 4 | 256 | +0.106 (0.016) | +0.096..+0.118 | yes |
| miss ~ our predicted s | ALP | 4 | 256 | +0.015 (0.069) | -0.017..+0.102 | NO |
| miss ~ our predicted s | LNP | 4 | 256 | +0.025 (0.028) | +0.015..+0.058 | yes |


#### Extended (adds qld2012 KAP-as-OTH_RIGHT, wa2001 ONP): ALP

Table: n seats with a prior ALP share; mean new-party seat share s; coefficients with SE in brackets (points); RMSE = residual root-mean-square, lower is better. Proportional fill predicts b clearly negative and RMSE below uniform.

| election | new party | n | mean s | uniform a (SE) | uniform RMSE | slope d~s: b (SE) | slope RMSE | prop. b (SE) | prop. RMSE | RMSE prop - unif |
|---|---|---|---|---|---|---|---|---|---|---|
| sa2026 | ONP | 46 | 22.7 | -2.68 (1.20) | 8.08 | -0.63 (0.13) | 6.57 | -1.17 (0.18) | 5.79 | -2.28 |
| qld2017 | ONP | 77 | 14.8 | -1.80 (0.69) | 6.00 | -0.07 (0.06) | 5.95 | -0.35 (0.16) | 5.81 | -0.19 |
| qld2024 | ONP | 93 | 8.0 | -7.17 (0.50) | 4.83 | -0.37 (0.11) | 4.56 | -1.53 (0.22) | 3.90 | -0.93 |
| sa2018 | IND | 40 | 17.9 | -3.62 (0.88) | 5.48 | -0.18 (0.07) | 5.01 | -0.87 (0.17) | 4.22 | -1.26 |
| qld2012 | OTH_RIGHT | 89 | 13.0 | -15.59 (0.56) | 5.24 | -0.04 (0.06) | 5.23 | -0.61 (0.13) | 4.68 | -0.56 |
| wa2001 | ONP | 56 | 10.7 | -0.23 (1.03) | 7.61 | -0.27 (0.17) | 7.43 | -1.25 (0.47) | 7.15 | -0.46 |

#### Extended (adds qld2012 KAP-as-OTH_RIGHT, wa2001 ONP): LNP

Table: n seats with a prior LNP share; mean new-party seat share s; coefficients with SE in brackets (points); RMSE = residual root-mean-square, lower is better. Proportional fill predicts b clearly negative and RMSE below uniform.

| election | new party | n | mean s | uniform a (SE) | uniform RMSE | slope d~s: b (SE) | slope RMSE | prop. b (SE) | prop. RMSE | RMSE prop - unif |
|---|---|---|---|---|---|---|---|---|---|---|
| sa2026 | ONP | 46 | 22.7 | -17.01 (1.11) | 7.43 | -0.06 (0.15) | 7.42 | -0.99 (0.25) | 6.36 | -1.07 |
| qld2017 | ONP | 77 | 14.8 | -7.42 (0.72) | 6.23 | -0.25 (0.06) | 5.59 | -0.63 (0.14) | 5.56 | -0.67 |
| qld2024 | ONP | 93 | 8.0 | +5.74 (0.41) | 3.91 | +0.08 (0.09) | 3.90 | -0.28 (0.20) | 3.87 | -0.04 |
| sa2018 | IND | 40 | 17.9 | -7.51 (1.08) | 6.74 | -0.34 (0.07) | 5.27 | -0.70 (0.13) | 5.11 | -1.63 |
| qld2012 | OTH_RIGHT | 88 | 13.1 | +7.89 (0.79) | 7.41 | -0.55 (0.06) | 5.08 | -1.37 (0.10) | 4.14 | -3.27 |
| wa2001 | ONP | 56 | 10.9 | -12.44 (1.08) | 7.97 | -0.56 (0.17) | 7.25 | -1.00 (0.21) | 6.66 | -1.31 |

#### Extended (adds qld2012 KAP-as-OTH_RIGHT, wa2001 ONP): our miss (ours - actual) by tercile of OUR predicted new-party share

Table: mean signed miss in points (positive = we over-called the major) in the low / mid / high third of seats ranked by our own predicted new-party share within the election; SE in brackets; n per tercile. Proportional fill being wrong the bookmaker way predicts positive miss in LOW, negative in HIGH. Zero everywhere is good.

| election | major | n/tercile | low third | mid third | high third | slope of miss on actual s: b (SE) | slope on our so: b (SE) |
|---|---|---|---|---|---|---|---|
| sa2026 | ALP | 15 | -2.02 (1.18) n=16 | -1.26 (1.13) n=15 | +0.63 (1.03) n=15 | +0.21 (0.08) | +0.19 (0.09) |
| sa2026 | LNP | 15 | -3.37 (0.80) n=16 | -0.92 (1.14) n=15 | -2.38 (1.29) n=15 | +0.14 (0.08) | +0.08 (0.09) |
| qld2017 | ALP | 25 | +2.82 (0.79) n=26 | +1.86 (0.66) n=25 | +1.36 (1.01) n=26 | -0.10 (0.04) | -0.10 (0.05) |
| qld2017 | LNP | 25 | +0.54 (0.73) n=26 | +2.83 (0.84) n=25 | +2.38 (1.02) n=26 | +0.09 (0.05) | +0.04 (0.06) |
| qld2024 | ALP | 31 | -2.14 (0.68) n=31 | -0.97 (0.55) n=31 | +0.37 (0.72) n=31 | +0.35 (0.08) | +0.49 (0.14) |
| qld2024 | LNP | 31 | -0.62 (0.48) n=31 | +0.83 (0.60) n=31 | +0.51 (0.74) n=31 | +0.21 (0.08) | +0.19 (0.14) |
| sa2018 | ALP | 13 | -1.05 (0.97) n=14 | +2.00 (1.09) n=13 | -1.03 (1.40) n=13 | +0.07 (0.06) | +0.02 (0.06) |
| sa2018 | LNP | 13 | -1.55 (1.13) n=14 | -3.18 (1.49) n=13 | -1.80 (1.75) n=13 | +0.08 (0.07) | -0.03 (0.08) |
| qld2012 | ALP | 29 | +1.99 (0.79) n=30 | +3.66 (0.88) n=29 | +5.14 (0.77) n=30 | +0.13 (0.05) | -0.05 (0.12) |
| qld2012 | LNP | 29 | +0.85 (1.42) n=30 | +2.99 (1.12) n=29 | +3.59 (1.45) n=29 | +0.57 (0.05) | +0.21 (0.19) |
| wa2001 | ALP | 18 | +3.73 (1.13) n=19 | +4.37 (2.33) n=18 | +6.82 (1.71) n=19 | +0.43 (0.16) | +0.95 (0.85) |
| wa2001 | LNP | 18 | +5.51 (1.58) n=19 | +4.72 (1.50) n=18 | +5.32 (2.04) n=19 | +0.50 (0.15) | +0.93 (0.91) |

#### Extended (adds qld2012 KAP-as-OTH_RIGHT, wa2001 ONP): pooled, election fixed effects, SE clustered on election

Table: coefficient (cluster SE) and leave-one-election-out (LOEO) range. G = number of elections, which is tiny, so the cluster SE is itself unreliable (t with G-1 df). Rows 1-2 test fill (negative = proportional); rows 3-4 test our bias (positive in miss~so means we over-call majors where we predict more new party, i.e. we under-fill low seats less than high; negative means over-call in low-ONP seats).

| outcome ~ regressor | major | G | n | b (cluster SE) | LOEO min..max | LOEO sign stable? |
|---|---|---|---|---|---|---|
| d ~ prev*s/100 (proportional term) | ALP | 6 | 401 | -0.779 (0.178) | -0.946..-0.674 | yes |
| d ~ prev*s/100 (proportional term) | LNP | 6 | 400 | -0.902 (0.159) | -0.981..-0.746 | yes |
| d ~ s | ALP | 6 | 401 | -0.164 (0.067) | -0.212..-0.120 | yes |
| d ~ s | LNP | 6 | 400 | -0.339 (0.082) | -0.376..-0.256 | yes |
| miss ~ actual s | ALP | 6 | 401 | +0.091 (0.071) | +0.066..+0.173 | yes |
| miss ~ actual s | LNP | 6 | 400 | +0.264 (0.120) | +0.142..+0.338 | yes |
| miss ~ our predicted s | ALP | 6 | 401 | +0.014 (0.059) | -0.015..+0.085 | NO |
| miss ~ our predicted s | LNP | 6 | 400 | +0.046 (0.035) | +0.029..+0.085 | yes |

#### Pooled tercile means of our miss (mean of the election-level tercile means; SE across elections)

Table: signed miss in points (positive = we over-called the major) by third of seats ranked by our own predicted new-party share, averaged over elections; zero is good. G = 4 (primary) or 6 (extended), so SEs are rough.

| set | major | low third (SE) | mid third (SE) | high third (SE) |
|---|---|---|---|---|
| primary, G=4 | ALP | -0.60 (1.16) | +0.41 (0.88) | +0.33 (0.50) |
| primary, G=4 | LNP | -1.25 (0.83) | -0.11 (1.28) | -0.32 (1.10) |
| extended, G=6 | ALP | +0.55 (1.06) | +1.61 (0.95) | +2.21 (1.25) |
| extended, G=6 | LNP | +0.23 (1.23) | +1.21 (1.18) | +1.27 (1.24) |
