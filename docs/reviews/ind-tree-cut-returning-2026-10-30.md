# Do the trees over-cut returning, well-known independents? (2026-10-30)

Question: the xgb layer pulled Ali Cupper (Mildura vic2026) from base 25.13 to 21.26. On past elections, for rows like her, does the tree move reduce error or over-cut?

Data (all existing time-forward output, nothing refit): `output/forecasts.csv` (17,010 rows; 2,620 are class IND, 31 elections), `output/published-predictions.csv` (`ours`, matched on all 2,620 IND rows), `output/candidacies.csv` (22,358 rows). Script: `scratchpad/agentA/ind.R` (outside the repo).

How "same person" was decided: surname plus first initial, same seat, in the previous election of the same jurisdiction, parsed from the `name` field (the `surname` and `given` columns are blank on 10,334 rows). 244 IND rows matched a prior candidate; 191 of those were IND last time (the other 53 were a different party class last time, e.g. Cupper ran ALP in 2010, and are excluded). Sitting = `elected` TRUE last time. Unverified: a surname plus initial match can join two different people; seat renames are missed (false negatives only). The forecast cell is the IND class in the seat: where `n_candidates` is above 1, `actual_share` is the class total, while "prev" is the lead candidate's own vote last time.

Signed error = actual_share minus prediction (positive means we were too low). Cupper's own rows: vic2014 base 22.2 / xgb 21.5 / actual 26.3; vic2018 base 28.3 / xgb 31.2 / actual 39.6; vic2022 base 33.9 / xgb 42.6 / actual 41.2. vic2026 is not in forecasts.csv.

## 1. Same person, IND last time, by previous share and outcome last time

Mean signed error ("bias", points; 0 is good), RMSE (points; lower is good), tree move = xgb minus base (points; negative means the trees cut). SE is the standard error of the mean xgb signed error, row-level, not clustered. "elec" is the number of distinct elections.

| slice | n | elec | tree move | bias base | bias xgb | bias ours | SE (xgb) | RMSE base | RMSE xgb | RMSE ours |
|---|---|---|---|---|---|---|---|---|---|---|
| lost last time, prev < 10 | 111 | 25 | +0.39 | -0.17 | -0.56 | -0.76 | 0.31 | 2.88 | 3.25 | 3.33 |
| lost last time, prev 10-20 | 16 | 10 | +0.76 | +0.78 | +0.02 | -0.15 | 1.70 | 7.21 | 6.57 | 6.13 |
| lost last time, prev 20-30 | 11 | 8 | +2.45 | -2.92 | -5.36 | -4.74 | 2.35 | 10.48 | 9.15 | 8.59 |
| lost last time, prev > 30 | 3 | 3 | -1.52 | -2.96 | -1.44 | -2.78 | 6.70 | 7.92 | 9.59 | 8.97 |
| sitting last time, prev 20-30 | 5 | 4 | +5.99 | +4.42 | -1.57 | +0.18 | 4.70 | 9.80 | 9.52 | 9.59 |
| sitting last time, prev > 30 | 45 | 20 | +2.66 | +2.23 | -0.43 | +0.93 | 1.12 | 7.26 | 7.46 | 6.93 |
| all same-person IND | 191 | 27 | +1.19 | +0.39 | -0.80 | -0.55 | 0.40 | 5.61 | 5.61 | 5.37 |

(No sitting rows with prev under 20 exist.)

## 2. Contrast: new independents (no prior candidacy found), by base size

Same units. "d abs err" is the mean of (absolute xgb error minus absolute base error), points; negative means the trees helped; SE in brackets.

| slice | n | elec | tree move | bias base | bias xgb | bias ours | RMSE base | RMSE xgb | RMSE ours | d abs err (SE) |
|---|---|---|---|---|---|---|---|---|---|---|
| new, base >= 15 | 75 | 22 | -0.19 | -0.12 | +0.06 | +0.35 | 11.48 | 10.17 | 9.64 | -1.31 (0.41) |
| new, base >= 25 | 28 | 14 | +0.42 | +1.99 | +1.57 | +2.20 | 12.39 | 10.52 | 10.53 | -1.91 (0.83) |
| new, base < 15 | 2,301 | 31 | +0.49 | +0.90 | +0.42 | +0.36 | 4.88 | 4.26 | 3.88 | -0.25 (0.04) |
| all IND | 2,620 | 31 | +0.53 | +0.81 | +0.28 | +0.25 | 5.37 | 4.78 | 4.45 | -0.27 (0.04) |

The trees clearly help new large independents (base >= 15: RMSE 11.5 to 10.2, n = 75). ("all IND" includes the same-person rows.)

## 3. The Cupper-shaped slice: same person, IND last time, lost last time, previous own share >= 20 (n = 14, 11 elections)

Shares are per cent of first preferences. Prev = the candidate's own share last time. Last column: positive means the trees were too low.

| election | seat | candidate | cands in class | prev | base | xgb | ours | actual | actual - xgb |
|---|---|---|---|---|---|---|---|---|---|
| fed2019 | Cowper | Robert OAKESHOTT | 2 | 26.29 | 25.31 | 29.27 | 29.80 | 25.87 | -3.4 |
| fed2019 | Grey | Andrea BROADFOOT | 2 | 27.74 | 25.50 | 21.27 | 23.41 | 6.88 | -14.4 |
| fed2025 | Bradfield | Nicolette BOELE | 2 | 20.89 | 22.60 | 30.74 | 31.57 | 31.14 | +0.4 |
| fed2025 | Cowper | Caz HEISE | 2 | 26.26 | 26.02 | 36.08 | 33.17 | 30.17 | -5.9 |
| nsw2011 | Newcastle | John TATE | 3 | 24.09 | 28.27 | 30.21 | 26.87 | 15.12 | -15.1 |
| nsw2011 | Orange | John DAVIS | 1 | 23.65 | 22.47 | 22.27 | 21.74 | 16.03 | -6.2 |
| nsw2015 | Tamworth | Peter DRAPER | 2 | 37.58 | 28.36 | 25.39 | 26.29 | 35.03 | +9.6 |
| nsw2023 | Wollondilly | Judy HANNAN | 1 | 20.12 | 23.64 | 34.23 | 30.71 | 25.94 | -8.3 |
| nt2024 | Nelson | Beverley RATAHI | 1 | 29.62 | 32.20 | 28.33 | 28.22 | 14.56 | -13.8 |
| qld2015 | Maryborough | Christopher FOLEY | 2 | 30.17 | 26.65 | 22.68 | 27.67 | 22.23 | -0.5 |
| sa2014 | Mitchell | Kris HANNA | 1 | 28.03 | 27.20 | 24.72 | 24.11 | 18.36 | -6.4 |
| vic2010 | Gippsland East | Craig INGRAM | 1 | 38.42 | 36.44 | 38.81 | 36.95 | 25.31 | -13.5 |
| vic2018 | Mildura | Ali CUPPER | 2 | 21.28 | 28.29 | 31.22 | 30.42 | 39.60 | +8.4 |
| wa2013 | Kwinana | ADAMS | 1 | 22.96 | 18.36 | 18.43 | 19.92 | 24.10 | +5.7 |

Slice totals (n = 14; SE of the xgb bias 2.24 row-level, 2.57 clustered on election, 11 elections), in points; bias closer to 0 and RMSE lower is good:

| metric | base | xgb | ours |
|---|---|---|---|
| mean signed error (actual minus prediction) | -2.93 | -4.52 | -4.32 |
| RMSE | 9.98 | 9.25 | 8.68 |

Mean tree move is +1.60 points (a rise, not a cut). Only 5 of the 14 rows had a cut of 2 points or more; 6 had any cut. Excluding Cupper's own row the mean xgb signed error is -5.51. Mean actual 23.6 against mean previous share 26.9, mean base 26.5, mean xgb 28.1. Slope of (actual - base) on tree move, through the origin: 0.76 (SE 0.49, p = 0.14), so the moves were about three quarters right but cannot be told from "all right" or "no use". The actual came in below xgb in 10 of 14 rows; above by more than 5 in 3 (Tamworth, Mildura 2018, Kwinana).

### Where the trees cut hard (same-person IND, base >= 20)

Tree cut of 2 points or more versus the rest, same-person IND rows with base >= 20. Points; bias closer to 0 and RMSE lower is good; d abs err negative means the trees helped.

| slice | n | tree move | bias base | bias xgb | RMSE base | RMSE xgb | d abs err (SE) |
|---|---|---|---|---|---|---|---|
| tree cut >= 2 | 12 | -3.54 | -2.99 | +0.56 | 10.00 | 9.86 | -0.12 (1.11) |
| tree cut < 2 or raised | 52 | +4.12 | +1.96 | -2.16 | 7.34 | 7.13 | -0.05 (0.57) |

When the trees cut a large returning independent, base was too high by 3.0 on average and the cut took the mean error to +0.6 (xgb closer than base in 7 of 12 rows). Across all IND with base >= 20, regardless of person: cut >= 2 rows (n = 26) base bias -4.99 to xgb -0.50; other rows (n = 96) base +1.59 to xgb -1.66.

## 4. Verdict

In the Cupper-shaped slice the trees are not over-cutting. Evidence is thin (n = 14 rows, 11 elections, bias SE 2.2 to 2.6), but it points the other way: the trees on average RAISED these candidates (+1.6), and the actual still came in below the xgb prediction (mean -4.5, about 2 SE, so suggestive and not decisive). Returning independents who lost last time with 20+ per cent mostly fade (mean actual 23.6 against a previous 26.9), and the trees cut RMSE in the slice (9.98 to 9.25). Where the trees cut a big returning independent by 2+ points (n = 12), they moved the mean error from -3.0 to +0.6, so the cut is right on average, with n too small to be sure (d abs err -0.12, SE 1.11). Cupper's own three rows were all under-called (vic2018 by 8.4 points after the trees, vic2014 by 4.8, vic2022 by 1.4 after a large tree lift), which is one person's history and not a slice finding.

Fix the data supports: none that offsets the cut. Any shrunk correction fitted to this slice would push DOWN (about 2.6 to 3.7 points, from n/(n+k) shrinkage with k = 10 to 3 on a mean of -4.5), the opposite of the concern, and at SE 2.2-2.6 on 14 rows it is not strong enough to ship. The one open idea is a per-person signal (Cupper's own share rising 15.2, 21.3, 32.7, 33.9 across her four runs), which this slice did not test and which needs the full corpus. Nothing was built.

Not checked: whether the vic2026 live row's features (council_elected, surge_h) have past analogues in these rows; alternative name-matching rules; seat-renamed returners.
