# One Nation: do demographics and past voting add to the seat allocation? (22 Nov 2026)

Pete, 22 Nov: "Screen but also improve if there were issues with the initial implementation; demos and past voting
should help a lot with One Nation I think."

Share-level screen only, from files on disk (`output/published-predictions.csv` of the 13 Nov rebuild,
`output/census-features.csv`, the Senate-by-seat tables). No harness run: the AEF-7 `quick_arm` screen first
proposed was NOT run, because the share-level answer made it unnecessary. Linear models only (7 census columns, 4
Senate class shares); trees were not tried. Scripts and the walk's files: `deciding-runs/20261122-onp-spread-walk/`.

## 1. Demographics do predict where One Nation polls

Correlation with the seat's One Nation vote (log, within election), 10 elections with a One Nation vote of 3%+:
Year 12 completion -0.56 to -0.93; the previous federal Senate One Nation share +0.70 to +0.94; our forecast
+0.73 to +0.92 (two exceptions below). The Senate share and the census columns carry the same information.

## 2. After the Senate allocation there is nothing consistent left for them to add

Seats with no One Nation history (the path all 88 Victorian seats take), 6 elections, 267 seats. RMSE in points on
the seat primary, leave-one-election-out, every model rescaled to our own level; lower is better:

| Model | RMSE | Elections better than ours (of 6) |
|---|---|---|
| Ours (rank on the Senate vote) | 3.84 | |
| Direct: Senate share | 3.85 | 2 |
| Direct: Senate share + Year 12 | 3.85 | 4 |
| Direct: Senate share + 7 census columns | 3.99 | 4 |
| Direct: 7 census columns only | 4.11 | 3 |
| Correction of our miss: 7 census columns | 3.93 | 1 |
| Correction of our miss: Senate + Year 12 | 3.86 | 1 |

Time-forward (4 elections with an earlier one to fit on): ours 2.68, direct Senate + Year 12 2.75, 7 census 3.31.
Over all 10 elections and both forms of correction (in points, as the 15 Sep test; relative to the party's level,
the fix that test's write-up proposed), a pair-wise cross-validated ridge shrinks every coefficient to zero.

Why: the sign of the leftover relationship flips between elections. Our miss against Year 12: qld2017 +0.42, sa2026
+0.33, wa2017 +0.48, but fed2019 -0.68, fed2022 -0.26, qld2020 -0.64. That is not a demographic effect. It is the
SPREAD being wrong in opposite directions (next section): where we spread the vote too widely, low-education seats
come in under our number and it looks like "education matters less than we assumed", and the reverse.

The 15 Sep test (`plans/prereg-demographic-axis-2026-09-15.md`) found a real signal because it ran before the
Senate-rank allocation shipped (26 Oct). That allocation absorbed it.

## 3. What the screen did find: the spread is too wide when One Nation is high

Spread of the seat vote in no-history seats, ours divided by actual (log scale; 1.00 is right, above 1 = our top
seats too high and our bottom seats too low):

| Election | One Nation level | Ratio |
|---|---|---|
| sa2026 | 20.3 | 1.44 |
| qld2017 | 20.1 | 1.37 |
| wa2017 | 8.8 | 1.36 |
| fed2019 | 6.7 | 0.71 |
| qld2020 | 4.7 | 0.58 |
| fed2022 | 4.1 | 0.83 |

Actual spread (sd / mean) over all seats One Nation contested: sa2026 0.33 (47 of 47 seats), qld2017 0.28 (61 of
93, so selective), wa2017 0.28 (35 of 59). The backtests' time-forward law gave 0.371 and 0.374 for sa2026 and
qld2017. The live forecast forces `AUSPOL_ONP_CV=0.365` (delivered 0.379); that constant (Pete's call, 9 Sep) pooled
South Australia's own 0.346 UP toward a corpus-typical 0.479, and the corpus is mostly elections where One Nation
polled under 10%. The only elections at Victoria's level sit below it, not above.

Not checked: what "previously compressed to 0.283" on the live log's allocation line refers to.

## 4. Live walk: `AUSPOL_ONP_CV=0.30` (delivers 0.318, about South Australia's actual 0.33)

One run of `fit_seats_full.R`, 20,000 simulations, against this morning's baseline run. Not ship evidence by
itself; it sizes the change.

| | Published (0.365) | 0.30 |
|---|---|---|
| One Nation expected seats | 14.9 | 12.7 |
| Coalition | 40.2 | 42.4 |
| Labor | 25.4 | 25.4 |
| Greens | 7.1 | 7.0 |
| One Nation primary, top 5 seats | 34.6 | 32.4 |
| One Nation primary, bottom 5 seats | 6.9 | 8.9 |
| Seats with One Nation on 30+ | 13 | 9 |

73 seat-party win probabilities move by 0.03 or more, every One Nation one downward (Morwell 0.48 to 0.29, Narracan
0.52 to 0.36, Hastings 0.57 to 0.41, Ripon 0.56 to 0.43, Benambra 0.25 to 0.14). Favourite changes: Hastings,
Narracan, Ripon, Sunbury, Wendouree (One Nation to Liberal), Carrum (One Nation to Labor), Bentleigh and Essendon
(Labor to Liberal). It moves us toward the bookmakers (One Nation 12.9 and 13.6), which is not evidence for it.

## Also seen (backtest only, does not touch Victoria)

wa2001: our One Nation forecast is unrelated to the result (r 0.03) although the Senate share correlates 0.94; the
rule was not applied (`ONN1! no earlier election to fit the spread on`). wa2025: r 0.29 against the Senate's 0.78,
35 of 41 seats keep their own history path.

## 5. Pete's version: model the seat vote directly, with shrinkage (same morning)

Pete, after section 4: "forcing the spread is way more hacky than just modelling using features like previous
senate, previous vote, demos, using shrinkage as needed". Tested: log seat vote (relative to the election) on log
Senate share (relative) and Year 12, the Senate slope partially pooled across elections (`lme4`, a random slope by
election), and a term letting the slope depend on the party's level. 703 seats, 9 elections, leave-one-election-out,
rescaled to our level. Script `onp_hier.R` in the walk folder. A full Bayesian fit (`brms` is installed) was NOT run;
it would give the same point estimates plus a posterior on the slope for the simulation.

| | Ours (rank + forced spread) | One pooled slope | Shrunk slope + Year 12 | ... + level term |
|---|---|---|---|---|
| RMSE, points (lower is better) | 3.53 | 3.48 | 3.44 | 3.45 |
| Mean distance of the spread ratio from 1.00 | 0.24 | 0.23 | 0.20 | 0.20 |
| Elections better than ours (of 9) | | 6 | 6 | 6 |

Spread ratio at the two high-level elections: sa2026 ours 1.34, model 0.91; qld2017 ours 1.36, model 1.15.
Full fit: Senate slope 0.39 (SE 0.05), Year 12 -0.150 per sd (SE 0.015, t -10), level term -0.014 (SE 0.079, nothing).
So section 2's "census adds nothing" is too strong: on the no-history subset with a rank-like Senate term it was a
tie, but with the Senate share entering by value at a slope well under 1, Year 12 carries its own weight. No-history
seats only, model against ours: better in fed2019 (2.82 v 3.71), sa2026 (3.45 v 3.90), qld2017 (6.59 v 6.79), wa2017;
worse in qld2020 (3.31 v 2.26), wa2025, fed2022.

What it implies for Victoria at a level of 20.4: spread 0.347, top five seats 34.8, bottom five 9.8, 12 seats on
30+. Published (forced 0.365): 0.379, 34.6, 6.9, 13. Forced 0.30: 0.318, 32.4, 8.9, 9. The model keeps the top of
the published forecast and lifts the bottom; forcing 0.30 cuts the top by 2 points, which the model does not support.

Consequence: the 0.30 change (commit 72cce539, Pete's call at 9:40am on my recommendation) was reverted on `dev`
(4a3e818d) before any PR. Not built yet: this model in the forecast path. It replaces the rank allocation and the
forced spread in `fit_seats_full.R` and the six harnesses, so it needs a switch, a live walk and a rebuild pair.
