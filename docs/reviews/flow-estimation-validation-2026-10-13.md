# Flow estimation from results: validation (2026-10-13)

Script: `scripts/estimate_flows_from_results.R` (check codes FR1-FR5). Spec: `docs/plans/flow-estimation-from-results-2026-10-13.md`. Output: `output/flows-estimated.csv`. Run with 300 bootstrap replicates, seed 20261013.

## Result in one line

**FAIL.** Greens and One Nation cells in the plan's test set: estimator mean absolute error 9.02 points on 31 cells (Greens 20, One Nation 11), borrowing the nearest earlier election's actual flows 4.85 points. Bar: under 5 points and no worse than borrowing.

## Seat accounting and sources (FR1)

What the numbers are: counts of seats; `final_alp_lnp` seats whose final two are Labor and Coalition, `used` those with a count taken, `no_count` decided on first preferences, `key_seats` used seats that also have transfers (answer key). Higher `used` means more evidence.

| election | final_alp_lnp | final_other | used | no_count | key_seats | source |
|---|---|---|---|---|---|---|
| fed2001 | 145 | 5 | 145 | 0 | 129 | official (aec); archive agrees on 150/150 seats (>0.5% diff: 0) |
| fed2004 | 146 | 4 | 146 | 0 | 111 | official (aec); archive agrees on 144/150 seats (>0.5% diff: 6) |
| fed2007 | 147 | 3 | 147 | 0 | 124 | official (aec); archive agrees on 148/150 seats (>0.5% diff: 2) |
| fed2010 | 142 | 8 | 142 | 0 | 69 | official (aec); archive agrees on 121/124 seats (>0.5% diff: 3) |
| fed2013 | 139 | 11 | 139 | 0 | 111 | official (aec); archive agrees on 146/150 seats (>0.5% diff: 4) |
| fed2016 | 133 | 17 | 133 | 0 | 62 | official (aec); archive agrees on 148/150 seats (>0.5% diff: 2) |
| fed2019 | 136 | 15 | 136 | 0 | 38 | official (aec); archive agrees on 149/151 seats (>0.5% diff: 2) |
| fed2022 | 124 | 27 | 124 | 0 | 97 | official (aec); archive agrees on 150/151 seats (>0.5% diff: 1) |
| fed2025 | 115 | 35 | 115 | 0 | 86 | official (aec); archive agrees on 146/150 seats (>0.5% diff: 4) |
| nsw2003 | 79 | 14 | 79 | 0 | 0 | archive |
| nsw2007 | 72 | 21 | 72 | 0 | 0 | archive |
| nsw2011 | 66 | 27 | 66 | 0 | 26 | archive |
| nsw2015 | 76 | 17 | 76 | 0 | 76 | archive |
| nsw2019 | 74 | 19 | 74 | 0 | 74 | archive |
| nsw2023 | 71 | 22 | 71 | 0 | 71 | archive |
| qld2001 | 64 | 25 | 54 | 10 | 0 | archive |
| qld2004 | 81 | 8 | 78 | 3 | 0 | archive |
| qld2006 | 82 | 7 | 76 | 6 | 0 | archive |
| qld2009 | 83 | 6 | 83 | 0 | 0 | archive |
| qld2012 | 71 | 18 | 71 | 0 | 0 | archive |
| qld2015 | 82 | 7 | 82 | 0 | 0 | archive |
| qld2017 | 65 | 28 | 65 | 0 | 0 | archive |
| qld2020 | 85 | 8 | 85 | 0 | 85 | archive |
| qld2024 | 85 | 8 | 85 | 0 | 84 | archive |
| sa2002 | 40 | 7 | 40 | 0 | 0 | archive |
| sa2006 | 42 | 5 | 42 | 0 | 0 | archive |
| sa2010 | 42 | 5 | 42 | 0 | 0 | archive |
| sa2014 | 43 | 4 | 43 | 0 | 0 | archive |
| sa2018 | 32 | 15 | 32 | 0 | 0 | archive |
| sa2022 | 41 | 6 | 41 | 0 | 0 | archive |
| sa2026 | 13 | 34 | 13 | 0 | 12 | official (ecsa) first prefs; final counts replayed from transfers |
| vic2002 | 80 | 8 | 80 | 0 | 0 | archive |
| vic2006 | 80 | 8 | 80 | 0 | 23 | archive |
| vic2010 | 81 | 7 | 81 | 0 | 23 | archive |
| vic2014 | 81 | 7 | 81 | 0 | 27 | archive |
| vic2018 | 75 | 13 | 75 | 0 | 26 | archive |
| vic2022 | 74 | 14 | 74 | 0 | 34 | archive |
| wa2001 | 46 | 11 | 46 | 0 | 0 | archive |
| wa2005 | 50 | 7 | 50 | 0 | 40 | archive |
| wa2008 | 49 | 10 | 49 | 0 | 43 | archive |
| wa2013 | 50 | 9 | 50 | 0 | 41 | archive |
| wa2017 | 56 | 3 | 56 | 0 | 42 | archive |
| wa2021 | 58 | 1 | 58 | 0 | 44 | archive |
| wa2025 | 50 | 7 | 50 | 0 | 32 | archive |

## Answer-key integrity (FR2)

What the numbers are: votes the tracker sends to Labor (or the Coalition) divided by the votes the seat counts say they gained, summed over key seats; 1.000 is exact.

| election | key_seats | alp_ratio | lnp_ratio | skipped_major_exclusions | seats_dropped_incomplete |
|---|---|---|---|---|---|
| fed2001 | 129 | 1.000 | 1.000 | 0 | 16 |
| fed2004 | 111 | 0.990 | 0.982 | 0 | 35 |
| fed2007 | 124 | 0.990 | 0.983 | 0 | 23 |
| fed2010 | 69 | 0.988 | 0.976 | 0 | 67 |
| fed2013 | 111 | 0.991 | 0.987 | 0 | 28 |
| fed2016 | 62 | 0.988 | 0.983 | 0 | 70 |
| fed2019 | 38 | 0.985 | 0.976 | 0 | 98 |
| fed2022 | 97 | 0.991 | 0.987 | 0 | 27 |
| fed2025 | 86 | 0.989 | 0.985 | 0 | 29 |
| nsw2011 | 26 | 0.973 | 0.959 | 0 | 10 |
| nsw2015 | 76 | 1.000 | 1.000 | 0 | 0 |
| nsw2019 | 74 | 0.950 | 0.874 | 0 | 0 |
| nsw2023 | 71 | 0.974 | 0.908 | 0 | 0 |
| qld2020 | 85 | 1.000 | 1.000 | 0 | 0 |
| qld2024 | 84 | 1.000 | 1.000 | 0 | 1 |
| sa2026 | 12 | 1.000 | 1.000 | 0 | 1 |
| vic2006 | 23 | 1.000 | 0.994 | 0 | 19 |
| vic2010 | 23 | 0.998 | 0.987 | 0 | 15 |
| vic2014 | 27 | 1.000 | 0.999 | 0 | 11 |
| vic2018 | 26 | 1.000 | 1.000 | 0 | 10 |
| vic2022 | 34 | 0.999 | 1.000 | 0 | 30 |
| wa2005 | 40 | 1.000 | 1.000 | 0 | 5 |
| wa2008 | 43 | 1.000 | 1.000 | 0 | 5 |
| wa2013 | 41 | 1.000 | 1.000 | 0 | 9 |
| wa2017 | 42 | 1.000 | 1.000 | 0 | 14 |
| wa2021 | 44 | 1.000 | 1.003 | 2 | 14 |
| wa2025 | 32 | 1.000 | 1.000 | 0 | 18 |

## Per election and class (FR4)

What the numbers are: percent of the class's first preferences ending with Labor. `key` is read from the published distributions, `est` is the shrunk estimate from results only, `raw` the unshrunk fit, `borrow` the nearest earlier election's actual flow, `err` = estimate minus key (closer to zero is better), `cov` whether the key lies inside the 90% interval, `w` the weight on the data (1 = all data, 0 = all prior).

| election | party | seats | key_a | est_a | raw_a | borrow_a | err_a | berr_a | key_e | est_e | cov | w | prior |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| fed2004 | GRN | 111 | 77.4 | 87.6 | 87.8 | 69.2 | 10.2 | -8.3 | 0.0 | 0.0 | FALSE | 0.99 | fed2001 |
| fed2004 | IND | 57 | 49.8 | 40.9 | 40.6 | 53.0 | -8.9 | 3.2 | 0.0 | 0.0 | FALSE | 0.98 | fed2001 |
| fed2004 | ONP | 56 | 48.4 | 40.8 | 40.3 | 47.2 | -7.6 | -1.2 | 0.0 | 0.0 | TRUE | 0.92 | fed2001 |
| fed2004 | OTH | 99 | 60.2 | 57.6 | 57.1 | 61.5 | -2.6 | 1.4 | 0.0 | 0.0 | TRUE | 0.89 | fed2001 |
| fed2004 | OTH_RIGHT | 107 | 38.4 | 27.5 | 26.7 | 59.4 | -10.8 | 21.1 | 0.0 | 0.0 | FALSE | 0.97 | fed2001 |
| fed2007 | GRN | 124 | 77.2 | 83.5 | 83.8 | 77.4 | 6.3 | 0.2 | 0.0 | 0.0 | FALSE | 0.95 | fed2004 |
| fed2007 | IND | 61 | 53.8 | 47.4 | 46.9 | 49.8 | -6.4 | -4.0 | 0.0 | 0.0 | FALSE | 0.82 | fed2004 |
| fed2007 | ONP | 29 | 49.8 | 43.4 | 25.7 | 48.4 | -6.4 | -1.4 | 0.0 | 0.0 | FALSE | 0.22 | fed2004 |
| fed2007 | OTH | 107 | 62.6 | 59.7 | 59.1 | 60.2 | -2.9 | -2.4 | 0.0 | 0.0 | TRUE | 0.43 | fed2004 |
| fed2007 | OTH_RIGHT | 123 | 42.5 | 36.3 | 35.7 | 38.4 | -6.2 | -4.2 | 0.0 | 0.0 | FALSE | 0.79 | fed2004 |
| fed2010 | GRN | 69 | 77.8 | 81.1 | 81.2 | 77.2 | 3.3 | -0.5 | 0.0 | 0.0 | FALSE | 0.98 | fed2007 |
| fed2010 | IND | 31 | 53.5 | 45.6 | 43.8 | 53.8 | -7.9 | 0.3 | 0.0 | 0.0 | FALSE | 0.83 | fed2007 |
| fed2010 | ONP | 14 | 53.9 | 45.8 | 37.0 | 49.8 | -8.1 | -4.1 | 0.0 | 0.0 | FALSE | 0.31 | fed2007 |
| fed2010 | OTH | 44 | 63.1 | 64.7 | 70.2 | 62.6 | 1.6 | -0.5 | 0.0 | 0.0 | TRUE | 0.27 | fed2007 |
| fed2010 | OTH_RIGHT | 62 | 42.0 | 32.3 | 30.1 | 42.5 | -9.7 | 0.6 | 0.0 | 0.0 | FALSE | 0.82 | fed2007 |
| fed2013 | GRN | 111 | 77.4 | 83.6 | 83.7 | 77.8 | 6.2 | 0.4 | 0.0 | 0.0 | FALSE | 0.98 | fed2010 |
| fed2013 | IND | 42 | 56.0 | 55.6 | 56.2 | 53.5 | -0.4 | -2.5 | 0.0 | 0.0 | TRUE | 0.76 | fed2010 |
| fed2013 | ONP | 12 | 50.4 | 49.0 | 30.8 | 53.9 | -1.4 | 3.5 | 0.0 | 0.0 | TRUE | 0.21 | fed2010 |
| fed2013 | OTH | 55 | 61.5 | 69.7 | 74.6 | 63.1 | 8.1 | 1.6 | 0.0 | 0.0 | FALSE | 0.57 | fed2010 |
| fed2013 | OTH_RIGHT | 111 | 48.7 | 42.8 | 42.8 | 42.0 | -5.9 | -6.7 | 0.0 | 0.0 | FALSE | 0.99 | fed2010 |
| fed2016 | GRN | 62 | 77.6 | 80.8 | 81.1 | 77.4 | 3.2 | -0.3 | 0.0 | 0.0 | FALSE | 0.93 | fed2013 |
| fed2016 | IND | 38 | 57.7 | 54.3 | 53.4 | 56.0 | -3.4 | -1.7 | 0.0 | 0.0 | FALSE | 0.68 | fed2013 |
| fed2016 | ONP | 13 | 50.9 | 50.9 | 51.1 | 50.4 | 0.1 | -0.5 | 0.0 | 0.0 | TRUE | 0.74 | fed2013 |
| fed2016 | OTH | 46 | 61.6 | 65.1 | 67.5 | 61.5 | 3.5 | -0.1 | 0.0 | 0.0 | TRUE | 0.61 | fed2013 |
| fed2016 | OTH_RIGHT | 60 | 42.5 | 39.5 | 37.6 | 48.7 | -3.0 | 6.2 | 0.0 | 0.0 | TRUE | 0.83 | fed2013 |
| fed2019 | GRN | 38 | 78.5 | 86.1 | 86.3 | 77.6 | 7.7 | -0.8 | 0.0 | 0.0 | FALSE | 0.98 | fed2016 |
| fed2019 | IND | 20 | 57.7 | 55.4 | 55.0 | 57.7 | -2.3 | 0.0 | 0.0 | 0.0 | TRUE | 0.87 | fed2016 |
| fed2019 | ONP | 13 | 38.8 | 34.3 | 33.4 | 50.9 | -4.5 | 12.0 | 0.0 | 0.0 | FALSE | 0.95 | fed2016 |
| fed2019 | OTH | 33 | 61.2 | 59.7 | 59.0 | 61.6 | -1.5 | 0.4 | 0.0 | 0.0 | TRUE | 0.72 | fed2016 |
| fed2019 | OTH_RIGHT | 38 | 40.7 | 31.9 | 31.1 | 42.5 | -8.8 | 1.8 | 0.0 | 0.0 | FALSE | 0.94 | fed2016 |
| fed2022 | GRN | 97 | 78.6 | 89.3 | 89.8 | 78.5 | 10.8 | -0.1 | 0.0 | 0.0 | FALSE | 0.96 | fed2019 |
| fed2022 | IND | 46 | 56.7 | 57.5 | 57.5 | 57.7 | 0.8 | 1.0 | 0.0 | 0.0 | TRUE | 0.80 | fed2019 |
| fed2022 | ONP | 96 | 42.1 | 27.3 | 23.9 | 38.8 | -14.8 | -3.3 | 0.0 | 0.0 | FALSE | 0.77 | fed2019 |
| fed2022 | OTH | 80 | 58.7 | 59.1 | 58.6 | 61.2 | 0.4 | 2.5 | 0.0 | 0.0 | TRUE | 0.81 | fed2019 |
| fed2022 | OTH_RIGHT | 97 | 41.9 | 37.8 | 37.0 | 40.7 | -4.2 | -1.2 | 0.0 | 0.0 | TRUE | 0.79 | fed2019 |
| fed2025 | GRN | 86 | 79.4 | 95.1 | 95.2 | 78.6 | 15.6 | -0.9 | 0.0 | 0.0 | FALSE | 0.99 | fed2022 |
| fed2025 | IND | 53 | 60.7 | 64.2 | 64.6 | 56.7 | 3.5 | -4.0 | 0.0 | 0.0 | TRUE | 0.95 | fed2022 |
| fed2025 | ONP | 86 | 33.5 | 13.9 | 12.2 | 42.1 | -19.5 | 8.7 | 0.0 | 0.0 | FALSE | 0.94 | fed2022 |
| fed2025 | OTH | 51 | 54.3 | 59.7 | 59.8 | 58.7 | 5.5 | 4.4 | 0.0 | 0.0 | TRUE | 0.91 | fed2022 |
| fed2025 | OTH_RIGHT | 85 | 42.3 | 35.6 | 35.2 | 41.9 | -6.7 | -0.4 | 0.0 | 0.0 | FALSE | 0.95 | fed2022 |
| nsw2011 | GRN | 26 | 34.2 | 38.7 | 38.7 | 77.8 | 4.5 | 43.6 | 52.8 | 43.7 | FALSE | 1.00 | fed2010 |
| nsw2011 | IND | 19 | 20.1 | 18.9 | 18.8 | 53.5 | -1.2 | 33.4 | 60.8 | 61.2 | TRUE | 1.00 | fed2010 |
| nsw2011 | OTH | 4 | 9.6 | 11.5 | 10.9 | 63.1 | 1.9 | 53.5 | 86.0 | 67.7 | TRUE | 0.99 | fed2010 |
| nsw2011 | OTH_RIGHT | 25 | 11.6 | 0.1 | 0.0 | 42.0 | -11.5 | 30.4 | 54.3 | 72.7 | FALSE | 1.00 | fed2010 |
| nsw2015 | GRN | 76 | 46.0 | 54.2 | 54.6 | 34.2 | 8.2 | -11.8 | 44.7 | 34.0 | FALSE | 0.98 | nsw2011 |
| nsw2015 | IND | 31 | 24.7 | 21.0 | 21.0 | 20.1 | -3.7 | -4.6 | 58.8 | 63.2 | FALSE | 0.97 | nsw2011 |
| nsw2015 | OTH | 76 | 16.1 | 0.5 | 0.0 | 9.6 | -15.6 | -6.4 | 70.3 | 84.8 | FALSE | 0.95 | nsw2011 |
| nsw2015 | OTH_RIGHT | 76 | 13.6 | 6.7 | 6.2 | 11.6 | -6.9 | -2.0 | 54.5 | 66.2 | FALSE | 0.92 | nsw2011 |
| nsw2019 | GRN | 74 | 52.4 | 60.2 | 60.9 | 46.0 | 7.9 | -6.4 | 38.1 | 30.3 | FALSE | 0.95 | nsw2015 |
| nsw2019 | IND | 27 | 23.3 | 14.8 | 14.3 | 24.7 | -8.4 | 1.4 | 57.9 | 68.2 | FALSE | 0.95 | nsw2015 |
| nsw2019 | ONP | 10 | 14.3 | 8.1 | 7.6 | 31.9 | -6.2 | 17.6 | 64.9 | 74.5 | FALSE | 0.98 | nsw2015 |
| nsw2019 | OTH | 66 | 17.9 | 18.8 | 18.9 | 16.1 | 0.9 | -1.9 | 73.2 | 64.2 | TRUE | 0.97 | nsw2015 |
| nsw2019 | OTH_RIGHT | 31 | 12.2 | 0.3 | 0.0 | 13.6 | -11.9 | 1.4 | 58.8 | 74.9 | FALSE | 0.98 | nsw2015 |
| nsw2023 | GRN | 71 | 57.1 | 69.1 | 69.9 | 52.4 | 12.0 | -4.7 | 33.3 | 22.7 | FALSE | 0.95 | nsw2019 |
| nsw2023 | IND | 35 | 29.6 | 23.6 | 23.7 | 23.3 | -6.1 | -6.4 | 50.5 | 57.3 | TRUE | 0.74 | nsw2019 |
| nsw2023 | ONP | 15 | 15.7 | 6.2 | 5.9 | 14.3 | -9.5 | -1.4 | 57.3 | 70.1 | FALSE | 0.96 | nsw2019 |
| nsw2023 | OTH | 68 | 19.6 | 13.9 | 13.5 | 17.9 | -5.7 | -1.6 | 68.2 | 65.8 | FALSE | 0.92 | nsw2019 |
| nsw2023 | OTH_RIGHT | 14 | 11.3 | 0.4 | 0.0 | 12.2 | -11.0 | 0.8 | 55.7 | 68.9 | FALSE | 0.97 | nsw2019 |
| vic2006 | GRN | 23 | 75.0 | 77.4 | 78.7 | 77.4 | 2.4 | 2.4 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| vic2006 | IND | 11 | 50.4 | 49.8 | 45.5 | 49.8 | -0.6 | -0.6 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| vic2006 | OTH | 10 | 55.0 | 60.2 | 69.6 | 60.2 | 5.1 | 5.1 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| vic2006 | OTH_RIGHT | 23 | 40.3 | 38.4 | 37.2 | 38.4 | -1.9 | -1.9 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| vic2010 | GRN | 23 | 75.4 | 75.0 | 77.6 | 75.0 | -0.4 | -0.4 | 0.0 | 0.0 | FALSE | 0.00 | vic2006 |
| vic2010 | IND | 17 | 56.6 | 50.4 | 42.6 | 50.4 | -6.2 | -6.2 | 0.0 | 0.0 | FALSE | 0.00 | vic2006 |
| vic2010 | OTH | 7 | 65.4 | 55.0 | 55.0 | 55.0 | -10.3 | -10.3 | 0.0 | 0.0 | FALSE | 0.00 | vic2006 |
| vic2010 | OTH_RIGHT | 21 | 50.0 | 40.3 | 39.7 | 40.3 | -9.8 | -9.8 | 0.0 | 0.0 | FALSE | 0.00 | vic2006 |
| vic2014 | GRN | 27 | 80.2 | 81.9 | 83.9 | 75.4 | 1.7 | -4.8 | 0.0 | 0.0 | TRUE | 0.77 | vic2010 |
| vic2014 | IND | 19 | 56.8 | 55.2 | 48.0 | 56.6 | -1.6 | -0.3 | 0.0 | 0.0 | TRUE | 0.16 | vic2010 |
| vic2014 | OTH | 16 | 65.4 | 64.5 | 58.6 | 65.4 | -0.9 | 0.0 | 0.0 | 0.0 | TRUE | 0.13 | vic2010 |
| vic2014 | OTH_RIGHT | 23 | 52.5 | 49.2 | 46.9 | 50.0 | -3.4 | -2.5 | 0.0 | 0.0 | FALSE | 0.28 | vic2010 |
| vic2018 | GRN | 26 | 79.6 | 80.2 | 81.1 | 80.2 | 0.6 | 0.6 | 0.0 | 0.0 | FALSE | 0.00 | vic2014 |
| vic2018 | IND | 14 | 51.2 | 56.8 | 49.5 | 56.8 | 5.7 | 5.7 | 0.0 | 0.0 | FALSE | 0.00 | vic2014 |
| vic2018 | OTH | 14 | 62.1 | 65.4 | 60.9 | 65.4 | 3.3 | 3.3 | 0.0 | 0.0 | FALSE | 0.00 | vic2014 |
| vic2018 | OTH_RIGHT | 10 | 53.3 | 52.5 | 50.5 | 52.5 | -0.7 | -0.7 | 0.0 | 0.0 | FALSE | 0.00 | vic2014 |
| vic2022 | GRN | 34 | 79.5 | 86.7 | 86.8 | 79.6 | 7.2 | 0.1 | 0.0 | 0.0 | FALSE | 0.99 | vic2018 |
| vic2022 | IND | 25 | 54.8 | 53.8 | 53.9 | 51.2 | -1.0 | -3.7 | 0.0 | 0.0 | TRUE | 0.96 | vic2018 |
| vic2022 | ONP | 1 | 33.8 | 23.8 | 11.9 | 68.6 | -10.0 | 34.8 | 0.0 | 0.0 | TRUE | 0.79 | vic2018 |
| vic2022 | OTH | 34 | 61.1 | 53.7 | 53.3 | 62.1 | -7.3 | 1.0 | 0.0 | 0.0 | TRUE | 0.95 | vic2018 |
| vic2022 | OTH_RIGHT | 34 | 42.7 | 31.1 | 30.4 | 53.3 | -11.6 | 10.6 | 0.0 | 0.0 | FALSE | 0.97 | vic2018 |
| qld2020 | GRN | 85 | 74.9 | 84.0 | 84.1 | 78.5 | 9.0 | 3.5 | 0.0 | 0.0 | FALSE | 0.98 | fed2019 |
| qld2020 | IND | 44 | 49.2 | 49.7 | 48.6 | 57.7 | 0.5 | 8.5 | 0.0 | 0.0 | TRUE | 0.89 | fed2019 |
| qld2020 | ONP | 84 | 37.3 | 27.5 | 27.0 | 38.8 | -9.8 | 1.5 | 0.0 | 0.0 | FALSE | 0.96 | fed2019 |
| qld2020 | OTH | 62 | 54.1 | 53.9 | 51.4 | 61.2 | -0.2 | 7.1 | 0.0 | 0.0 | TRUE | 0.74 | fed2019 |
| qld2020 | OTH_RIGHT | 53 | 40.6 | 40.1 | 39.9 | 40.7 | -0.5 | 0.0 | 0.0 | 0.0 | TRUE | 0.69 | fed2019 |
| qld2024 | GRN | 84 | 75.9 | 87.3 | 87.4 | 74.9 | 11.4 | -0.9 | 0.0 | 0.0 | FALSE | 0.99 | qld2020 |
| qld2024 | IND | 27 | 46.1 | 46.6 | 43.9 | 49.2 | 0.4 | 3.0 | 0.0 | 0.0 | TRUE | 0.49 | qld2020 |
| qld2024 | ONP | 84 | 31.7 | 20.4 | 19.2 | 37.3 | -11.4 | 5.6 | 0.0 | 0.0 | FALSE | 0.94 | qld2020 |
| qld2024 | OTH | 37 | 55.6 | 55.0 | 55.2 | 54.1 | -0.6 | -1.5 | 0.0 | 0.0 | TRUE | 0.79 | qld2020 |
| qld2024 | OTH_RIGHT | 59 | 40.4 | 35.4 | 34.3 | 40.6 | -5.0 | 0.2 | 0.0 | 0.0 | TRUE | 0.83 | qld2020 |
| sa2026 | GRN | 12 | 82.9 | 99.2 | 100.0 | 79.4 | 16.2 | -3.5 | 0.0 | 0.0 | TRUE | 0.96 | fed2025 |
| sa2026 | IND | 5 | 59.4 | 95.3 | 100.0 | 60.7 | 35.9 | 1.3 | 0.0 | 0.0 | TRUE | 0.88 | fed2025 |
| sa2026 | ONP | 12 | 30.5 | 75.1 | 100.0 | 33.5 | 44.6 | 3.0 | 0.0 | 0.0 | TRUE | 0.63 | fed2025 |
| sa2026 | OTH | 11 | 60.5 | 14.7 | -0.0 | 54.3 | -45.8 | -6.3 | 0.0 | 0.0 | TRUE | 0.73 | fed2025 |
| sa2026 | OTH_RIGHT | 12 | 44.2 | 97.7 | 100.0 | 42.3 | 53.4 | -2.0 | 0.0 | 0.0 | FALSE | 0.96 | fed2025 |
| wa2005 | GRN | 40 | 69.2 | 77.4 | 73.7 | 77.4 | 8.2 | 8.2 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| wa2005 | IND | 20 | 54.7 | 49.8 | 59.0 | 49.8 | -4.9 | -4.9 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| wa2005 | ONP | 30 | 48.8 | 48.4 | 39.5 | 48.4 | -0.4 | -0.4 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| wa2005 | OTH | 8 | NA | 60.2 | 47.9 | 60.2 | NA | NA | 0.0 | 0.0 | NA | 0.00 | fed2004 |
| wa2005 | OTH_RIGHT | 40 | 40.6 | 38.4 | 36.4 | 38.4 | -2.2 | -2.2 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| wa2008 | GRN | 43 | 69.2 | 71.0 | 71.1 | 69.2 | 1.8 | -0.0 | 0.0 | 0.0 | TRUE | 0.92 | wa2005 |
| wa2008 | IND | 10 | 40.2 | 44.6 | 37.4 | 54.7 | 4.5 | 14.5 | 0.0 | 0.0 | TRUE | 0.58 | wa2005 |
| wa2008 | OTH | 3 | NA | 62.5 | 100.0 | 56.6 | NA | NA | 0.0 | 0.0 | NA | 0.14 | wa2005 |
| wa2008 | OTH_RIGHT | 39 | 38.6 | 41.1 | 41.5 | 40.6 | 2.5 | 2.0 | 0.0 | 0.0 | TRUE | 0.61 | wa2005 |
| wa2013 | GRN | 41 | 69.6 | 70.5 | 70.9 | 69.2 | 1.0 | -0.3 | 0.0 | 0.0 | TRUE | 0.78 | wa2008 |
| wa2013 | IND | 15 | 57.0 | 53.0 | 59.7 | 40.2 | -4.0 | -16.9 | 0.0 | 0.0 | TRUE | 0.66 | wa2008 |
| wa2013 | OTH_RIGHT | 30 | 35.7 | 40.5 | 48.2 | 38.6 | 4.9 | 2.9 | 0.0 | 0.0 | TRUE | 0.20 | wa2008 |
| wa2017 | GRN | 42 | 79.7 | 84.5 | 86.3 | 69.6 | 4.8 | -10.2 | 0.0 | 0.0 | TRUE | 0.89 | wa2013 |
| wa2017 | IND | 14 | 52.2 | 50.2 | 49.0 | 57.0 | -1.9 | 4.9 | 0.0 | 0.0 | TRUE | 0.85 | wa2013 |
| wa2017 | ONP | 19 | 42.0 | 50.6 | 49.5 | 61.5 | 8.6 | 19.4 | 0.0 | 0.0 | FALSE | 0.91 | wa2013 |
| wa2017 | OTH | 41 | 57.8 | 65.6 | 69.6 | 61.5 | 7.8 | 3.7 | 0.0 | 0.0 | TRUE | 0.51 | wa2013 |
| wa2017 | OTH_RIGHT | 40 | 39.5 | 10.4 | 3.4 | 35.7 | -29.2 | -3.9 | 0.0 | 0.0 | FALSE | 0.78 | wa2013 |
| wa2021 | GRN | 44 | 80.9 | 81.0 | 81.1 | 79.7 | 0.1 | -1.2 | 0.0 | 0.0 | TRUE | 0.97 | wa2017 |
| wa2021 | IND | 11 | 44.1 | 40.1 | 37.0 | 52.2 | -4.0 | 8.1 | 0.0 | 0.0 | TRUE | 0.80 | wa2017 |
| wa2021 | ONP | 26 | 50.8 | 74.4 | 81.1 | 42.0 | 23.6 | -8.8 | 0.0 | 0.0 | FALSE | 0.83 | wa2017 |
| wa2021 | OTH | 44 | 56.7 | 58.5 | 58.5 | 57.8 | 1.7 | 1.0 | 0.0 | 0.0 | TRUE | 0.94 | wa2017 |
| wa2021 | OTH_RIGHT | 34 | 35.1 | 27.6 | 26.7 | 39.5 | -7.5 | 4.4 | 0.0 | 0.0 | TRUE | 0.93 | wa2017 |
| wa2025 | GRN | 32 | 77.4 | 91.0 | 91.2 | 80.9 | 13.7 | 3.5 | 0.0 | 0.0 | FALSE | 0.98 | wa2021 |
| wa2025 | IND | 10 | 62.5 | 48.6 | 50.3 | 44.1 | -13.9 | -18.4 | 0.0 | 0.0 | FALSE | 0.73 | wa2021 |
| wa2025 | ONP | 20 | 37.2 | 31.2 | 29.7 | 50.8 | -6.0 | 13.6 | 0.0 | 0.0 | TRUE | 0.93 | wa2021 |
| wa2025 | OTH | 25 | 61.9 | 61.9 | 62.4 | 56.7 | -0.1 | -5.2 | 0.0 | 0.0 | TRUE | 0.91 | wa2021 |
| wa2025 | OTH_RIGHT | 31 | 35.7 | 2.3 | 0.0 | 35.1 | -33.4 | -0.6 | 0.0 | 0.0 | FALSE | 0.93 | wa2021 |

## Pass bar (FR5)

What the numbers are: mean absolute error of the Labor-flow share, in points; lower is better. Bar cells are Greens and One Nation with at least 5 key seats and 20,000 key first preferences.

| set | cells | est_MAE | borrow_MAE | raw_MAE | GRN_est | GRN_borrow | ONP_est | ONP_borrow | nGRN | nONP |
|---|---|---|---|---|---|---|---|---|---|---|
| plan test set | 31.00 | 9.02 | 4.85 | 11.03 | 7.25 | 4.71 | 12.24 | 5.11 | 20.00 | 11.00 |
| plus WA (supplementary) | 39.00 | 8.30 | 5.31 | 9.88 | 6.71 | 4.52 | 11.47 | 6.87 | 26.00 | 13.00 |

Estimator below 5 points: **FALSE**. Estimator no worse than borrowing: **FALSE**.

## Interval coverage (FR4)

What the numbers are: share of class cells where the key lies inside the 90% interval; 0.90 is calibrated, lower means over-confident. `bootstrap_shrunk` is the percentile interval of the shrunk bootstrap draws (the spec's interval); `posterior` is estimate +/- 1.645 sqrt(w) se (secondary).

| set | cells | cover_bootstrap_shrunk | cover_posterior | n_w_lt_0.1 | n_w_gt_0.9 |
|---|---|---|---|---|---|
| plan test set, all classes | 94 | 0.38 | 0.40 | 12 | 45 |
| plan test set, Greens/ONP bar cells | 31 | 0.16 | 0.16 | 3 | 23 |
| plan test set, w >= 0.5 | 73 | 0.41 | 0.40 | 0 | 45 |

## Per-election error, all classes with at least 20,000 key first preferences (FR4)

What the numbers are: mean absolute error of the Labor-flow share across classes, points; lower is better.

| election | classes | prior | est_MAE | borrow_MAE |
|---|---|---|---|---|
| fed2004 | 5 | fed2001 | 8.0 | 7.0 |
| fed2007 | 5 | fed2004 | 5.6 | 2.4 |
| fed2010 | 4 | fed2007 | 5.6 | 0.5 |
| fed2013 | 4 | fed2010 | 5.2 | 2.8 |
| fed2016 | 5 | fed2013 | 2.6 | 1.7 |
| fed2019 | 5 | fed2016 | 5.0 | 3.0 |
| fed2022 | 5 | fed2019 | 6.2 | 1.6 |
| fed2025 | 5 | fed2022 | 10.2 | 3.7 |
| nsw2011 | 3 | fed2010 | 5.7 | 35.8 |
| nsw2015 | 4 | nsw2011 | 8.6 | 6.2 |
| nsw2019 | 5 | nsw2015 | 7.1 | 5.7 |
| nsw2023 | 5 | nsw2019 | 8.9 | 3.0 |
| vic2006 | 2 | fed2004 | 2.2 | 2.2 |
| vic2010 | 2 | vic2006 | 5.1 | 5.1 |
| vic2014 | 3 | vic2010 | 2.3 | 2.5 |
| vic2018 | 3 | vic2014 | 3.2 | 3.2 |
| vic2022 | 4 | vic2018 | 6.8 | 3.8 |
| qld2020 | 5 | fed2019 | 4.0 | 4.1 |
| qld2024 | 5 | qld2020 | 5.8 | 2.3 |
| sa2026 | 2 | fed2025 | 30.4 | 3.3 |

## Exhaust on optional-preferential elections (FR4)

What the numbers are: mean absolute error of the exhaust share, points; lower is better. Cells: 17 (borrow available on 17).

| est | borrow |
|---|---|
| 9.9 | 14.6 |

## AE's estimates as a second reference (FR4)

What the numbers are: mean absolute error against the key on cells where AE published a value, points; lower is better.

| cells | AE | estimator | borrow |
|---|---|---|---|
| 44 | 11.1 | 7.6 | 4.2 |

## Dry run

The dry run (fed2022, nsw2023) is printed at the top of the script's log as FR3; see the dry-run section below.


## Reading the result (written after the run; numbers are from this run)

- **Fail on both clauses of the bar.** Mean absolute error 9.0 points against a 5-point bar, and borrowing the nearest earlier election's actual flows is better (4.9). The unshrunk fit alone is worse still (11.0), so shrinkage helped but could not rescue it. The bar, the method and the constants were not changed after seeing results.
- **The error is systematic, not noise.** Federal Greens are over-estimated in nearly every election (2004 +10, 2007 +6, 2013 +6, 2019 +8, 2022 +11, 2025 +16) and One Nation under-estimated (2022 -15, 2025 -20). Intervals cover the key in 38% of cells (16% on the bar cells) against a nominal 90%: the bootstrap measures sampling noise over seats, and the error here is bias that more seats would not remove. Likely cause (not tested): flows differ between seats (Greens voters in inner-city Labor seats send more to Labor than elsewhere), and with five correlated minor-party shares a single set of constant flows cannot separate them.
- **Where it looks fine, it is mostly the prior.** Victoria 2006-2018 and WA 2005 have pool weight 0 (the election-level spread estimate came out at zero), so the estimate equals the borrowed flows exactly; those rows say nothing about the estimator.
- **Small samples fail badly.** SA 2026 has 12 key seats (13 used): estimates sit on the 0 and 100 boundaries (Greens 99, Others 15 against key 83 and 61) and the bootstrap spread collapses there, so the shrinkage weight is high (0.96) when it should be low. The bootstrap SE is not trustworthy at a boundary.
- **Exhaust (NSW, optional preferential)**: mean absolute error 9.9 points against 14.6 for borrowing, on 17 cells; here the estimator beats borrowing, mainly because the NSW 2011 prior is federal (exhaust 0). This is not part of the bar.
- **AE comparison**: AE's hand-made numbers are 11.1 points from the key on 44 cells, the estimator 7.6, borrowing 4.2. AE's federal Greens figures run 79-86% (2013-2025) against a key of 77-80%, and AE's federal One Nation 26-40% (2019-2025) against a key of 34-42%, so key and AE disagree by a few points for a reason I have not resolved (see below).

## What is unverified

- **The answer key is my construction, not a published number.** The transfers files record each exclusion split by recipient party class, with exhausted votes left out. I follow each first preference through later exclusions assuming a class's pile has the composition of that class's bucket (own first preferences plus everything received). For compulsory elections the pile size is the sum transferred; for NSW and pre-2017 Queensland it is the smallest remaining candidate's votes plus an equal share of the class's received votes, never less than what was transferred. Checks that passed: tracked votes reaching Labor and the Coalition are within 2% of the seat counts for federal and within 0.5% for WA, Qld and Vic, but 2-13% off for nsw2019 and nsw2023 (the Coalition side); NSW 2011 exhausted votes tracked 146,489 against 142,597 published (2.7% high). Not checked: that the per-class attribution is right, only the totals.
- **The key disagrees with the commonly cited figures.** It puts the Greens at 77-80% to Labor in every federal election, where the plan quotes about 86% and AE 79-86%. One Nation is 34-54% in the key (34-42% from 2019), against AE's 26-40%. I could not find which is wrong; the key keeps votes that went to other minor parties first and then to the Coalition, which lowers Greens-to-Labor, and AE may count only the final transfer. If the key is biased, the 9.0 is too large; the Greens error then shrinks but the sign pattern would reverse.
- **Key integrity rule added before validation, not tuned on it.** A seat enters the key only if transfers to Labor and to the Coalition are each within max(5%, 300 votes) of that candidate's change in the seat count. I first tried 3%/100 votes, saw from raw files that ordinary rounding disagreement is about 200 votes, and loosened it. This drops many seats (`seats_dropped_incomplete` in the integrity table: for example fed2019 98, fed2016 70, fed2010 67, vic2022 30); the estimator uses every counted seat but the key only the kept ones, so the two are not computed on identical seats.
- **Seats with two Coalition (or two Labor) candidates** sit in one class; exclusions of the second candidate are skipped by the tracker (zero such skips in the final key seats except WA 2021: 2). Leakage from those candidates is not in the key.
- **Prior fallback**: when no earlier same-state election has a distribution, the prior is the federal election in the most recent strictly earlier year, not the same year as the plan says (same-year federal would be leakage for any election held after it, and the dated check was not worth the risk). A class the prior lacks, or holds on fewer than 3 seats, gets the vote-weighted mean of the prior's classes (flagged `(class mean)` in `prior_source`).
- **Source choice**: federal elections use the official AEC files (first preferences and final counts agree with the archive copy on all but 1-6 seats per election by more than 0.5%); every other election uses the uniform archive files, because the official state files are one row per party class and the optional-preferential tracker needs candidate rows. SA 2026 uses the official first preferences with final counts replayed from its transfers (no final-count file on disk). Qld 2017 and SA 2018/2022 are in the plan's test set but have no distribution on disk, so they are scored nowhere; Vic 2002, NSW 2003/2007, Qld 2001-2015 and SA 2002-2014 have estimates but no key. WA is reported separately (not in the plan's list) and is not in the pass-bar line.
- **Not run**: a rerun with a different seed (bootstrap size 300 only); an alternative estimator with seat-level heterogeneity, which the plan does not specify and which I did not add.

## Addendum (orchestrator, 2026-10-13): the answer key was biased; the official federal key reverses the verdict

The AEC publishes each party's two-party flow ("HouseTppFlowByStateByPartyDownload", raw in
`external/reference/aec/raw/tppflow/`, 2007-2025; 2004 returned 404). Column order differs by year (Labor first in
2010, 2013, 2025), so columns are mapped by header name. Against it, the estimator's federal flows to Labor:

| year | Greens AEC | Greens est | One Nation AEC | One Nation est |
|---|---|---|---|---|
| 2007 | 79.7 | 83.5 | 47.0 | 43.4 |
| 2010 | 78.8 | 81.1 | 45.2 | 45.8 |
| 2013 | 83.0 | 83.6 | 44.9 | 49.0 |
| 2016 | 81.9 | 80.9 | 49.5 | 51.0 |
| 2019 | 82.2 | 86.1 | 34.8 | 34.3 |
| 2022 | 85.7 | 89.3 | 35.7 | 27.3 |
| 2025 | 88.2 | 95.1 | 25.5 | 13.9 |

Mean absolute error vs the AEC: Greens 3.2, One Nation 4.3 (bar: 5). Borrowing the previous election's AEC flows
(2010-2025): Greens 2.1, One Nation 5.4; combined the two are about equal (3.8). The reconstructed key above put the
federal Greens at 77-80, 2-8 points below the AEC, so the FAIL verdict and the state numbers (same reconstruction)
are not reliable. Status: NOT A RESULT YET. Next: make the key reconstruction reproduce the AEC federal flows, then
re-validate the states on it.





## Revalidation on a corrected key (2026-10-13)

Script: `scripts/estimate_flows_from_results.R` (check codes FR1-FR8), answer key rebuilt in `scripts/flow_key_reconstruction.R`, official federal flows from `scripts/build_aec_tpp_flows.R` (`output/aec-tpp-flows.csv`). Estimator, constants and pass bar unchanged from the first run; 300 bootstrap replicates, seed 20261013. Tilt constants: exponent 0.75, evidence half-point 100,000 first preferences (calibrated on the federal Greens/One Nation gap to the AEC only; see FR6).

### Result in one line

**FAIL on the corrected key.** Plan test set, Greens and One Nation cells: estimator mean absolute error 6.22 points on 33 cells (Greens 20, One Nation 13), borrowing the nearest earlier election's actual flows 5.52 points. Bar: under 5 points and no worse than borrowing. First run (biased key) was 9.02 against 4.85.

### FR6 Answer key against the AEC's official federal flows

What the numbers are: percent of a party class's first-preference ballots that end with Labor rather than the Coalition, national, from the key we reconstruct and from the AEC's official table; gap = key minus AEC, in points, zero is perfect; within1 marks |gap| <= 1.

| year | party | key_votes | key | aec | gap | within1 |
|---|---|---|---|---|---|---|
| 2007 | GRN | 967,789 | 79.4 | 79.7 | -0.3 | TRUE |
| 2007 | IND | 276,370 | 44.8 | 45.4 | -0.6 | TRUE |
| 2007 | ONP | 32,650 | 46.4 | 47.0 | -0.6 | TRUE |
| 2007 | OTH | 137,335 | 59.4 | 61.1 | -1.7 | FALSE |
| 2007 | OTH_RIGHT | 388,640 | 37.5 | 38.9 | -1.4 | FALSE |
| 2010 | GRN | 1,458,998 | 78.8 | 78.8 | -0.1 | TRUE |
| 2010 | IND | 315,004 | 43.8 | 43.5 | 0.3 | TRUE |
| 2010 | ONP | 27,184 | 48.0 | 45.2 | 2.8 | FALSE |
| 2010 | OTH | 77,684 | 58.8 | 57.9 | 0.9 | TRUE |
| 2010 | OTH_RIGHT | 403,500 | 35.5 | 36.9 | -1.4 | FALSE |
| 2013 | GRN | 1,116,918 | 82.2 | 83.0 | -0.8 | TRUE |
| 2013 | IND | 186,230 | 56.5 | 57.0 | -0.5 | TRUE |
| 2013 | ONP | 22,046 | 51.1 | 44.9 | 6.2 | FALSE |
| 2013 | OTH | 127,491 | 61.7 | 61.1 | 0.6 | TRUE |
| 2013 | OTH_RIGHT | 1,268,059 | 43.7 | 43.7 | -0.1 | TRUE |
| 2016 | GRN | 1,385,650 | 82.0 | 81.9 | 0.1 | TRUE |
| 2016 | IND | 634,003 | 58.8 | 58.1 | 0.7 | TRUE |
| 2016 | ONP | 175,020 | 50.4 | 49.5 | 0.8 | TRUE |
| 2016 | OTH | 242,441 | 61.2 | 61.0 | 0.2 | TRUE |
| 2016 | OTH_RIGHT | 708,086 | 35.6 | 37.3 | -1.7 | FALSE |
| 2019 | GRN | 1,482,923 | 82.1 | 82.2 | -0.1 | TRUE |
| 2019 | IND | 528,910 | 59.4 | 60.1 | -0.7 | TRUE |
| 2019 | ONP | 438,587 | 34.3 | 34.8 | -0.5 | TRUE |
| 2019 | OTH | 268,350 | 60.6 | 60.2 | 0.4 | TRUE |
| 2019 | OTH_RIGHT | 798,385 | 33.1 | 33.8 | -0.7 | TRUE |
| 2022 | GRN | 1,795,985 | 85.1 | 85.7 | -0.5 | TRUE |
| 2022 | IND | 813,630 | 63.4 | 63.6 | -0.2 | TRUE |
| 2022 | ONP | 727,464 | 36.4 | 35.7 | 0.7 | TRUE |
| 2022 | OTH | 356,062 | 60.4 | 58.3 | 2.2 | FALSE |
| 2022 | OTH_RIGHT | 956,537 | 35.0 | 35.4 | -0.4 | TRUE |
| 2025 | GRN | 1,889,977 | 87.3 | 88.2 | -0.9 | TRUE |
| 2025 | IND | 1,176,937 | 66.2 | 66.9 | -0.8 | TRUE |
| 2025 | ONP | 991,814 | 22.9 | 25.5 | -2.6 | FALSE |
| 2025 | OTH | 363,859 | 60.3 | 56.5 | 3.8 | FALSE |
| 2025 | OTH_RIGHT | 784,109 | 38.7 | 35.2 | 3.5 | FALSE |

What the numbers are: summary of the gap over years for the two bar classes; lower is better.

| party | cells | within1 | mean_abs_gap | max_abs_gap |
|---|---|---|---|---|
| GRN | 7 | 7 | 0.40 | 0.92 |
| ONP | 7 | 4 | 2.04 | 6.23 |

### FR7 The check fails on a deliberately broken key

What the numbers are: the same comparison with the Labor and Coalition labels swapped in the 2022 distribution (the mistake a column-order error makes). Gap should be huge, so the check must fail here; points.

| party | key_swapped | aec | gap |
|---|---|---|---|
| GRN | 20.2 | 85.7 | -65.5 |
| ONP | 58.3 | 35.7 | 22.6 |

### FR8 What explains the gap

What the numbers are: gap to the AEC in points (zero is perfect) for four constructions of the key. prop = old proportional pile rule, tilt = choice model used now; alplnp = only seats whose real final two were Labor v Coalition (the first key's scope), all = every seat, with notional counts settled from the AEC division totals. diverged_seats = seats where the real count excluded Labor or the Coalition before the end.

| year | party | prop_alplnp | prop_all | tilt_alplnp | tilt_all | diverged_seats |
|---|---|---|---|---|---|---|
| 2007 | GRN | -3.5 | -3.4 | -0.4 | -0.3 | 3 |
| 2007 | ONP | 0.7 | -0.1 | 0.1 | -0.6 | 3 |
| 2010 | GRN | -2.9 | -2.6 | -0.4 | -0.1 | 8 |
| 2010 | ONP | 3.7 | 3.4 | 3.1 | 2.8 | 8 |
| 2013 | GRN | -5.8 | -5.4 | -1.1 | -0.8 | 11 |
| 2013 | ONP | 5.2 | 4.7 | 6.6 | 6.2 | 11 |
| 2016 | GRN | -4.5 | -3.9 | -0.4 | 0.1 | 17 |
| 2016 | ONP | 1.4 | 0.4 | 1.6 | 0.8 | 17 |
| 2019 | GRN | -5.5 | -4.8 | -0.7 | -0.1 | 15 |
| 2019 | ONP | 2.1 | 1.8 | -0.3 | -0.5 | 15 |
| 2022 | GRN | -7.1 | -5.8 | -1.4 | -0.5 | 27 |
| 2022 | ONP | 6.0 | 6.0 | 0.8 | 0.7 | 27 |
| 2025 | GRN | -7.9 | -6.5 | -1.8 | -0.9 | 35 |
| 2025 | ONP | 7.1 | 7.4 | -2.6 | -2.6 | 35 |

### Seat accounting and sources (FR1)

What the numbers are: counts of seats; `final_alp_lnp` seats whose final two are Labor and Coalition, `used` those with a count taken, `no_count` decided on first preferences, `key_seats` seats in the answer key (federal 2004-2025: all seats; others: used seats that have transfers and pass the integrity rule).

| election | final_alp_lnp | final_other | used | no_count | key_seats | source |
|---|---|---|---|---|---|---|
| fed2001 | 145 | 5 | 145 | 0 | 129 | official (aec); archive agrees on 150/150 seats (>0.5% diff: 0) |
| fed2004 | 146 | 4 | 146 | 0 | 150 | official (aec); archive agrees on 144/150 seats (>0.5% diff: 6) |
| fed2007 | 147 | 3 | 147 | 0 | 150 | official (aec); archive agrees on 148/150 seats (>0.5% diff: 2) |
| fed2010 | 142 | 8 | 142 | 0 | 150 | official (aec); archive agrees on 121/124 seats (>0.5% diff: 3) |
| fed2013 | 139 | 11 | 139 | 0 | 150 | official (aec); archive agrees on 146/150 seats (>0.5% diff: 4) |
| fed2016 | 133 | 17 | 133 | 0 | 150 | official (aec); archive agrees on 148/150 seats (>0.5% diff: 2) |
| fed2019 | 136 | 15 | 136 | 0 | 151 | official (aec); archive agrees on 149/151 seats (>0.5% diff: 2) |
| fed2022 | 124 | 27 | 124 | 0 | 151 | official (aec); archive agrees on 150/151 seats (>0.5% diff: 1) |
| fed2025 | 115 | 35 | 115 | 0 | 150 | official (aec); archive agrees on 146/150 seats (>0.5% diff: 4) |
| nsw2003 | 79 | 14 | 79 | 0 | 0 | archive |
| nsw2007 | 72 | 21 | 72 | 0 | 0 | archive |
| nsw2011 | 66 | 27 | 66 | 0 | 26 | archive |
| nsw2015 | 76 | 17 | 76 | 0 | 76 | archive |
| nsw2019 | 74 | 19 | 74 | 0 | 74 | archive |
| nsw2023 | 71 | 22 | 71 | 0 | 71 | archive |
| qld2001 | 64 | 25 | 54 | 10 | 0 | archive |
| qld2004 | 81 | 8 | 78 | 3 | 0 | archive |
| qld2006 | 82 | 7 | 76 | 6 | 0 | archive |
| qld2009 | 83 | 6 | 83 | 0 | 0 | archive |
| qld2012 | 71 | 18 | 71 | 0 | 0 | archive |
| qld2015 | 82 | 7 | 82 | 0 | 0 | archive |
| qld2017 | 65 | 28 | 65 | 0 | 0 | archive |
| qld2020 | 85 | 8 | 85 | 0 | 85 | archive |
| qld2024 | 85 | 8 | 85 | 0 | 84 | archive |
| sa2002 | 40 | 7 | 40 | 0 | 0 | archive |
| sa2006 | 42 | 5 | 42 | 0 | 0 | archive |
| sa2010 | 42 | 5 | 42 | 0 | 0 | archive |
| sa2014 | 43 | 4 | 43 | 0 | 0 | archive |
| sa2018 | 32 | 15 | 32 | 0 | 0 | archive |
| sa2022 | 41 | 6 | 41 | 0 | 0 | archive |
| sa2026 | 13 | 34 | 13 | 0 | 12 | official (ecsa) first prefs; final counts replayed from transfers |
| vic2002 | 80 | 8 | 80 | 0 | 0 | archive |
| vic2006 | 80 | 8 | 80 | 0 | 23 | archive |
| vic2010 | 81 | 7 | 81 | 0 | 23 | archive |
| vic2014 | 81 | 7 | 81 | 0 | 27 | archive |
| vic2018 | 75 | 13 | 75 | 0 | 26 | archive |
| vic2022 | 74 | 14 | 74 | 0 | 34 | archive |
| wa2001 | 46 | 11 | 46 | 0 | 0 | archive |
| wa2005 | 50 | 7 | 50 | 0 | 40 | archive |
| wa2008 | 49 | 10 | 49 | 0 | 43 | archive |
| wa2013 | 50 | 9 | 50 | 0 | 41 | archive |
| wa2017 | 56 | 3 | 56 | 0 | 42 | archive |
| wa2021 | 58 | 1 | 58 | 0 | 44 | archive |
| wa2025 | 50 | 7 | 50 | 0 | 32 | archive |

### Answer-key integrity (FR2)

What the numbers are: votes the tracker sends to Labor (or the Coalition) divided by the votes the seat counts say they gained, summed over key seats (federal: seats where the real count ended Labor v Coalition); 1.000 is exact.

| election | key_seats | alp_ratio | lnp_ratio | skipped_major_exclusions | seats_dropped_incomplete |
|---|---|---|---|---|---|
| fed2001 | 129 | 1.000 | 1.000 | 0 | 16 |
| fed2004 | 150 | 0.987 | 1.023 | 0 | 0 |
| fed2007 | 150 | 0.980 | 1.039 | 0 | 0 |
| fed2010 | 150 | 0.991 | 1.019 | 0 | 0 |
| fed2013 | 150 | 0.992 | 1.013 | 0 | 0 |
| fed2016 | 150 | 0.988 | 1.021 | 0 | 0 |
| fed2019 | 151 | 0.973 | 1.041 | 0 | 0 |
| fed2022 | 151 | 0.997 | 1.005 | 0 | 0 |
| fed2025 | 150 | 0.990 | 1.014 | 0 | 0 |
| nsw2011 | 26 | 0.973 | 0.959 | 0 | 10 |
| nsw2015 | 76 | 1.000 | 1.000 | 0 | 0 |
| nsw2019 | 74 | 0.950 | 0.874 | 0 | 0 |
| nsw2023 | 71 | 0.974 | 0.908 | 0 | 0 |
| qld2020 | 85 | 1.000 | 1.000 | 0 | 0 |
| qld2024 | 84 | 1.000 | 1.000 | 0 | 1 |
| sa2026 | 12 | 1.000 | 1.000 | 0 | 1 |
| vic2006 | 23 | 1.000 | 0.994 | 0 | 19 |
| vic2010 | 23 | 0.998 | 0.987 | 0 | 15 |
| vic2014 | 27 | 1.000 | 0.999 | 0 | 11 |
| vic2018 | 26 | 1.000 | 1.000 | 0 | 10 |
| vic2022 | 34 | 0.999 | 1.000 | 0 | 30 |
| wa2005 | 40 | 1.000 | 1.000 | 0 | 5 |
| wa2008 | 43 | 1.000 | 1.000 | 0 | 5 |
| wa2013 | 41 | 1.000 | 1.000 | 0 | 9 |
| wa2017 | 42 | 1.000 | 1.000 | 0 | 14 |
| wa2021 | 44 | 1.000 | 1.003 | 2 | 14 |
| wa2025 | 32 | 1.000 | 1.000 | 0 | 18 |

### Per election and class (FR4)

What the numbers are: percent of the class's first preferences ending with Labor. `key` is the corrected key, `est` the shrunk estimate from results only, `raw` the unshrunk fit, `borrow` the nearest earlier election's key, `err` = estimate minus key (closer to zero is better), `cov` whether the key lies inside the 90% interval, `w` the weight on the data (1 = all data, 0 = all prior).

| election | party | seats | key_a | est_a | raw_a | borrow_a | err_a | berr_a | key_e | est_e | cov | w | prior |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| fed2004 | GRN | 150 | 81.0 | 87.6 | 87.8 | 73.4 | 6.6 | -7.6 | 0.0 | 0.0 | FALSE | 0.99 | fed2001 |
| fed2004 | IND | 76 | 46.7 | 40.9 | 40.6 | 51.0 | -5.8 | 4.4 | 0.0 | 0.0 | FALSE | 0.98 | fed2001 |
| fed2004 | ONP | 77 | 44.7 | 40.6 | 40.3 | 44.2 | -4.1 | -0.5 | 0.0 | 0.0 | TRUE | 0.91 | fed2001 |
| fed2004 | OTH | 132 | 58.2 | 57.6 | 57.1 | 61.0 | -0.6 | 2.8 | 0.0 | 0.0 | TRUE | 0.87 | fed2001 |
| fed2004 | OTH_RIGHT | 140 | 32.5 | 27.7 | 26.7 | 59.4 | -4.8 | 26.9 | 0.0 | 0.0 | FALSE | 0.97 | fed2001 |
| fed2007 | GRN | 150 | 79.4 | 83.4 | 83.8 | 81.0 | 4.0 | 1.6 | 0.0 | 0.0 | FALSE | 0.86 | fed2004 |
| fed2007 | IND | 73 | 44.8 | 46.8 | 46.9 | 46.7 | 1.9 | 1.8 | 0.0 | 0.0 | TRUE | 0.58 | fed2004 |
| fed2007 | ONP | 35 | 46.4 | 43.2 | 25.7 | 44.7 | -3.2 | -1.7 | 0.0 | 0.0 | FALSE | 0.08 | fed2004 |
| fed2007 | OTH | 119 | 59.4 | 58.4 | 59.1 | 58.2 | -1.1 | -1.3 | 0.0 | 0.0 | TRUE | 0.19 | fed2004 |
| fed2007 | OTH_RIGHT | 149 | 37.5 | 34.3 | 35.7 | 32.5 | -3.2 | -5.0 | 0.0 | 0.0 | TRUE | 0.54 | fed2004 |
| fed2010 | GRN | 150 | 78.8 | 80.6 | 81.2 | 79.4 | 1.8 | 0.6 | 0.0 | 0.0 | FALSE | 0.65 | fed2007 |
| fed2010 | IND | 54 | 43.8 | 44.7 | 43.8 | 44.8 | 0.8 | 1.0 | 0.0 | 0.0 | TRUE | 0.18 | fed2007 |
| fed2010 | ONP | 21 | 48.0 | 46.2 | 37.0 | 46.4 | -1.8 | -1.6 | 0.0 | 0.0 | FALSE | 0.02 | fed2007 |
| fed2010 | OTH | 59 | 58.8 | 59.6 | 70.2 | 59.4 | 0.9 | 0.7 | 0.0 | 0.0 | FALSE | 0.02 | fed2007 |
| fed2010 | OTH_RIGHT | 124 | 35.5 | 36.2 | 30.1 | 37.5 | 0.7 | 1.9 | 0.0 | 0.0 | TRUE | 0.17 | fed2007 |
| fed2013 | GRN | 150 | 82.2 | 83.6 | 83.7 | 78.8 | 1.4 | -3.4 | 0.0 | 0.0 | TRUE | 0.98 | fed2010 |
| fed2013 | IND | 59 | 56.5 | 53.7 | 56.2 | 43.8 | -2.9 | -12.7 | 0.0 | 0.0 | TRUE | 0.79 | fed2010 |
| fed2013 | ONP | 15 | 51.1 | 43.8 | 30.8 | 48.0 | -7.3 | -3.1 | 0.0 | 0.0 | TRUE | 0.24 | fed2010 |
| fed2013 | OTH | 69 | 61.7 | 68.5 | 74.6 | 58.8 | 6.8 | -2.9 | 0.0 | 0.0 | TRUE | 0.61 | fed2010 |
| fed2013 | OTH_RIGHT | 150 | 43.7 | 42.7 | 42.8 | 35.5 | -1.0 | -8.1 | 0.0 | 0.0 | TRUE | 0.99 | fed2010 |
| fed2016 | GRN | 150 | 82.0 | 81.4 | 81.1 | 82.2 | -0.6 | 0.2 | 0.0 | 0.0 | TRUE | 0.77 | fed2013 |
| fed2016 | IND | 83 | 58.8 | 55.5 | 53.4 | 56.5 | -3.3 | -2.2 | 0.0 | 0.0 | FALSE | 0.35 | fed2013 |
| fed2016 | ONP | 15 | 50.4 | 51.1 | 51.1 | 51.1 | 0.8 | 0.8 | 0.0 | 0.0 | TRUE | 0.43 | fed2013 |
| fed2016 | OTH | 85 | 61.2 | 63.3 | 67.5 | 61.7 | 2.1 | 0.5 | 0.0 | 0.0 | FALSE | 0.29 | fed2013 |
| fed2016 | OTH_RIGHT | 136 | 35.6 | 40.3 | 37.6 | 43.7 | 4.7 | 8.1 | 0.0 | 0.0 | FALSE | 0.55 | fed2013 |
| fed2019 | GRN | 151 | 82.1 | 86.2 | 86.3 | 82.0 | 4.1 | -0.1 | 0.0 | 0.0 | FALSE | 0.97 | fed2016 |
| fed2019 | IND | 74 | 59.4 | 55.8 | 55.0 | 58.8 | -3.6 | -0.6 | 0.0 | 0.0 | TRUE | 0.80 | fed2016 |
| fed2019 | ONP | 59 | 34.3 | 34.8 | 33.4 | 50.4 | 0.5 | 16.1 | 0.0 | 0.0 | TRUE | 0.92 | fed2016 |
| fed2019 | OTH | 93 | 60.6 | 59.8 | 59.0 | 61.2 | -0.7 | 0.7 | 0.0 | 0.0 | TRUE | 0.61 | fed2016 |
| fed2019 | OTH_RIGHT | 151 | 33.1 | 31.6 | 31.1 | 35.6 | -1.5 | 2.5 | 0.0 | 0.0 | TRUE | 0.90 | fed2016 |
| fed2022 | GRN | 151 | 85.1 | 89.1 | 89.8 | 82.1 | 3.9 | -3.0 | 0.0 | 0.0 | FALSE | 0.91 | fed2019 |
| fed2022 | IND | 74 | 63.4 | 58.2 | 57.5 | 59.4 | -5.2 | -4.0 | 0.0 | 0.0 | FALSE | 0.61 | fed2019 |
| fed2022 | ONP | 149 | 36.4 | 28.3 | 23.9 | 34.3 | -8.1 | -2.1 | 0.0 | 0.0 | FALSE | 0.58 | fed2019 |
| fed2022 | OTH | 107 | 60.4 | 59.3 | 58.6 | 60.6 | -1.1 | 0.1 | 0.0 | 0.0 | TRUE | 0.63 | fed2019 |
| fed2022 | OTH_RIGHT | 151 | 35.0 | 35.4 | 37.0 | 33.1 | 0.4 | -1.9 | 0.0 | 0.0 | TRUE | 0.60 | fed2019 |
| fed2025 | GRN | 150 | 87.3 | 95.1 | 95.2 | 85.1 | 7.8 | -2.2 | 0.0 | 0.0 | FALSE | 0.98 | fed2022 |
| fed2025 | IND | 91 | 66.2 | 64.5 | 64.6 | 63.4 | -1.7 | -2.8 | 0.0 | 0.0 | TRUE | 0.90 | fed2022 |
| fed2025 | ONP | 147 | 22.9 | 14.8 | 12.2 | 36.4 | -8.1 | 13.5 | 0.0 | 0.0 | FALSE | 0.89 | fed2022 |
| fed2025 | OTH | 80 | 60.3 | 59.9 | 59.8 | 60.4 | -0.4 | 0.1 | 0.0 | 0.0 | TRUE | 0.84 | fed2022 |
| fed2025 | OTH_RIGHT | 135 | 38.7 | 35.2 | 35.2 | 35.0 | -3.5 | -3.7 | 0.0 | 0.0 | TRUE | 0.90 | fed2022 |
| nsw2011 | GRN | 26 | 34.7 | 38.7 | 38.7 | 78.8 | 4.0 | 44.1 | 52.7 | 43.7 | FALSE | 1.00 | fed2010 |
| nsw2011 | IND | 19 | 19.6 | 18.9 | 18.8 | 43.8 | -0.8 | 24.2 | 60.8 | 61.2 | TRUE | 1.00 | fed2010 |
| nsw2011 | OTH | 4 | 9.2 | 11.6 | 10.9 | 58.8 | 2.4 | 49.5 | 86.2 | 67.7 | TRUE | 0.99 | fed2010 |
| nsw2011 | OTH_RIGHT | 25 | 11.1 | 0.1 | -0.0 | 35.5 | -11.0 | 24.5 | 54.3 | 72.7 | FALSE | 1.00 | fed2010 |
| nsw2015 | GRN | 76 | 47.1 | 54.2 | 54.6 | 34.7 | 7.1 | -12.4 | 44.0 | 34.0 | FALSE | 0.98 | nsw2011 |
| nsw2015 | IND | 31 | 23.7 | 20.9 | 21.0 | 19.6 | -2.8 | -4.1 | 59.5 | 63.2 | TRUE | 0.96 | nsw2011 |
| nsw2015 | OTH | 76 | 14.8 | 0.5 | -0.0 | 9.2 | -14.2 | -5.5 | 71.9 | 84.9 | FALSE | 0.94 | nsw2011 |
| nsw2015 | OTH_RIGHT | 76 | 12.6 | 6.7 | 6.2 | 11.1 | -5.9 | -1.5 | 54.6 | 66.2 | FALSE | 0.91 | nsw2011 |
| nsw2019 | GRN | 74 | 54.6 | 60.3 | 60.9 | 47.1 | 5.6 | -7.5 | 36.4 | 30.2 | FALSE | 0.95 | nsw2015 |
| nsw2019 | IND | 27 | 22.0 | 14.8 | 14.3 | 23.7 | -7.2 | 1.7 | 58.5 | 68.3 | FALSE | 0.94 | nsw2015 |
| nsw2019 | ONP | 10 | 13.9 | 8.1 | 7.6 | 31.9 | -5.9 | 17.9 | 65.1 | 74.4 | FALSE | 0.98 | nsw2015 |
| nsw2019 | OTH | 66 | 15.7 | 18.8 | 18.9 | 14.8 | 3.1 | -0.9 | 75.1 | 64.3 | TRUE | 0.97 | nsw2015 |
| nsw2019 | OTH_RIGHT | 31 | 11.3 | 0.3 | 0.0 | 12.6 | -11.0 | 1.3 | 59.0 | 74.9 | FALSE | 0.98 | nsw2015 |
| nsw2023 | GRN | 71 | 59.7 | 69.0 | 69.9 | 54.6 | 9.3 | -5.1 | 31.5 | 22.7 | FALSE | 0.94 | nsw2019 |
| nsw2023 | IND | 35 | 28.6 | 23.2 | 23.7 | 22.0 | -5.5 | -6.6 | 50.8 | 57.5 | TRUE | 0.69 | nsw2019 |
| nsw2023 | ONP | 15 | 15.1 | 6.3 | 5.9 | 13.9 | -8.8 | -1.2 | 57.3 | 70.1 | FALSE | 0.95 | nsw2019 |
| nsw2023 | OTH | 68 | 16.9 | 13.7 | 13.5 | 15.7 | -3.2 | -1.2 | 70.4 | 66.0 | TRUE | 0.89 | nsw2019 |
| nsw2023 | OTH_RIGHT | 14 | 10.6 | 0.4 | 0.0 | 11.3 | -10.1 | 0.7 | 55.7 | 68.8 | FALSE | 0.96 | nsw2019 |
| vic2006 | GRN | 23 | 76.0 | 81.0 | 78.7 | 81.0 | 5.0 | 5.0 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| vic2006 | IND | 11 | 49.0 | 46.7 | 45.5 | 46.7 | -2.3 | -2.3 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| vic2006 | OTH | 10 | 54.7 | 58.2 | 69.6 | 58.2 | 3.5 | 3.5 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| vic2006 | OTH_RIGHT | 23 | 38.4 | 32.5 | 37.2 | 32.5 | -5.9 | -5.9 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| vic2010 | GRN | 23 | 76.1 | 76.0 | 77.6 | 76.0 | -0.1 | -0.1 | 0.0 | 0.0 | FALSE | 0.00 | vic2006 |
| vic2010 | IND | 17 | 55.2 | 49.0 | 42.6 | 49.0 | -6.2 | -6.2 | 0.0 | 0.0 | FALSE | 0.00 | vic2006 |
| vic2010 | OTH | 7 | 64.7 | 54.7 | 55.0 | 54.7 | -10.0 | -10.0 | 0.0 | 0.0 | FALSE | 0.00 | vic2006 |
| vic2010 | OTH_RIGHT | 21 | 48.7 | 38.4 | 39.7 | 38.4 | -10.2 | -10.2 | 0.0 | 0.0 | FALSE | 0.00 | vic2006 |
| vic2014 | GRN | 27 | 81.5 | 76.1 | 83.9 | 76.1 | -5.4 | -5.4 | 0.0 | 0.0 | FALSE | 0.00 | vic2010 |
| vic2014 | IND | 19 | 55.1 | 55.2 | 48.0 | 55.2 | 0.1 | 0.1 | 0.0 | 0.0 | FALSE | 0.00 | vic2010 |
| vic2014 | OTH | 16 | 64.5 | 64.7 | 58.6 | 64.7 | 0.2 | 0.2 | 0.0 | 0.0 | FALSE | 0.00 | vic2010 |
| vic2014 | OTH_RIGHT | 23 | 50.8 | 48.7 | 46.9 | 48.7 | -2.1 | -2.1 | 0.0 | 0.0 | FALSE | 0.00 | vic2010 |
| vic2018 | GRN | 26 | 80.8 | 81.5 | 81.1 | 81.5 | 0.6 | 0.6 | 0.0 | 0.0 | FALSE | 0.00 | vic2014 |
| vic2018 | IND | 14 | 49.4 | 55.1 | 49.5 | 55.1 | 5.7 | 5.7 | 0.0 | 0.0 | FALSE | 0.00 | vic2014 |
| vic2018 | OTH | 14 | 60.0 | 64.5 | 60.9 | 64.5 | 4.5 | 4.5 | 0.0 | 0.0 | FALSE | 0.00 | vic2014 |
| vic2018 | OTH_RIGHT | 10 | 53.4 | 50.8 | 50.5 | 50.8 | -2.7 | -2.7 | 0.0 | 0.0 | FALSE | 0.00 | vic2014 |
| vic2022 | GRN | 34 | 82.8 | 86.7 | 86.8 | 80.8 | 3.9 | -2.0 | 0.0 | 0.0 | FALSE | 0.99 | vic2018 |
| vic2022 | IND | 25 | 53.6 | 53.7 | 53.9 | 49.4 | 0.1 | -4.2 | 0.0 | 0.0 | TRUE | 0.96 | vic2018 |
| vic2022 | ONP | 1 | 35.0 | 23.8 | 11.9 | 68.6 | -11.2 | 33.6 | 0.0 | 0.0 | TRUE | 0.79 | vic2018 |
| vic2022 | OTH | 34 | 61.0 | 53.6 | 53.3 | 60.0 | -7.4 | -1.0 | 0.0 | 0.0 | TRUE | 0.95 | vic2018 |
| vic2022 | OTH_RIGHT | 34 | 37.3 | 31.1 | 30.4 | 53.4 | -6.3 | 16.1 | 0.0 | 0.0 | TRUE | 0.97 | vic2018 |
| qld2020 | GRN | 85 | 78.1 | 84.0 | 84.1 | 82.1 | 5.9 | 4.0 | 0.0 | 0.0 | FALSE | 0.98 | fed2019 |
| qld2020 | IND | 44 | 48.3 | 50.1 | 48.6 | 59.4 | 1.7 | 11.1 | 0.0 | 0.0 | TRUE | 0.87 | fed2019 |
| qld2020 | ONP | 84 | 33.6 | 27.4 | 27.0 | 34.3 | -6.2 | 0.7 | 0.0 | 0.0 | FALSE | 0.95 | fed2019 |
| qld2020 | OTH | 62 | 54.1 | 54.1 | 51.4 | 60.6 | -0.1 | 6.4 | 0.0 | 0.0 | TRUE | 0.70 | fed2019 |
| qld2020 | OTH_RIGHT | 53 | 40.5 | 37.5 | 39.9 | 33.1 | -3.0 | -7.4 | 0.0 | 0.0 | TRUE | 0.65 | fed2019 |
| qld2024 | GRN | 84 | 80.2 | 87.2 | 87.4 | 78.1 | 7.0 | -2.1 | 0.0 | 0.0 | FALSE | 0.97 | qld2020 |
| qld2024 | IND | 27 | 46.2 | 46.8 | 43.9 | 48.3 | 0.7 | 2.2 | 0.0 | 0.0 | TRUE | 0.34 | qld2020 |
| qld2024 | ONP | 84 | 26.9 | 20.9 | 19.2 | 33.6 | -6.0 | 6.7 | 0.0 | 0.0 | FALSE | 0.89 | qld2020 |
| qld2024 | OTH | 37 | 56.6 | 54.9 | 55.2 | 54.1 | -1.8 | -2.5 | 0.0 | 0.0 | TRUE | 0.67 | qld2020 |
| qld2024 | OTH_RIGHT | 59 | 38.8 | 36.1 | 34.3 | 40.5 | -2.7 | 1.6 | 0.0 | 0.0 | TRUE | 0.72 | qld2020 |
| sa2026 | GRN | 12 | 84.2 | 99.6 | 100.0 | 87.3 | 15.4 | 3.1 | 0.0 | 0.0 | TRUE | 0.97 | fed2025 |
| sa2026 | IND | 5 | 59.1 | 96.6 | 100.0 | 66.2 | 37.5 | 7.1 | 0.0 | 0.0 | TRUE | 0.90 | fed2025 |
| sa2026 | ONP | 12 | 29.3 | 74.2 | 100.0 | 22.9 | 44.9 | -6.5 | 0.0 | 0.0 | TRUE | 0.67 | fed2025 |
| sa2026 | OTH | 11 | 60.1 | 14.3 | -0.0 | 60.3 | -45.7 | 0.3 | 0.0 | 0.0 | TRUE | 0.76 | fed2025 |
| sa2026 | OTH_RIGHT | 12 | 45.0 | 97.9 | 100.0 | 38.7 | 52.9 | -6.3 | 0.0 | 0.0 | FALSE | 0.97 | fed2025 |
| wa2005 | GRN | 40 | 71.0 | 81.0 | 73.7 | 81.0 | 10.0 | 10.0 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| wa2005 | IND | 20 | 54.6 | 46.7 | 59.0 | 46.7 | -8.0 | -8.0 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| wa2005 | ONP | 30 | 48.5 | 44.7 | 39.5 | 44.7 | -3.7 | -3.7 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| wa2005 | OTH | 8 | NA | 58.2 | 47.9 | 58.2 | NA | NA | 0.0 | 0.0 | NA | 0.00 | fed2004 |
| wa2005 | OTH_RIGHT | 40 | 38.1 | 32.5 | 36.4 | 32.5 | -5.6 | -5.6 | 0.0 | 0.0 | FALSE | 0.00 | fed2004 |
| wa2008 | GRN | 43 | 70.4 | 71.1 | 71.1 | 71.0 | 0.7 | 0.6 | 0.0 | 0.0 | TRUE | 0.92 | wa2005 |
| wa2008 | IND | 10 | 38.9 | 44.6 | 37.4 | 54.6 | 5.7 | 15.7 | 0.0 | 0.0 | TRUE | 0.58 | wa2005 |
| wa2008 | OTH | 3 | NA | 62.5 | 100.0 | 56.6 | NA | NA | 0.0 | 0.0 | NA | 0.14 | wa2005 |
| wa2008 | OTH_RIGHT | 39 | 35.9 | 40.1 | 41.5 | 38.1 | 4.3 | 2.2 | 0.0 | 0.0 | TRUE | 0.61 | wa2005 |
| wa2013 | GRN | 41 | 70.1 | 70.8 | 70.9 | 70.4 | 0.7 | 0.3 | 0.0 | 0.0 | TRUE | 0.85 | wa2008 |
| wa2013 | IND | 15 | 56.4 | 54.6 | 59.7 | 38.9 | -1.8 | -17.5 | 0.0 | 0.0 | TRUE | 0.75 | wa2008 |
| wa2013 | OTH_RIGHT | 30 | 34.3 | 39.4 | 48.2 | 35.9 | 5.1 | 1.6 | 0.0 | 0.0 | TRUE | 0.29 | wa2008 |
| wa2017 | GRN | 42 | 81.3 | 84.4 | 86.3 | 70.1 | 3.1 | -11.2 | 0.0 | 0.0 | TRUE | 0.88 | wa2013 |
| wa2017 | IND | 14 | 50.8 | 50.2 | 49.0 | 56.4 | -0.5 | 5.6 | 0.0 | 0.0 | TRUE | 0.84 | wa2013 |
| wa2017 | ONP | 19 | 40.6 | 50.7 | 49.5 | 61.5 | 10.1 | 20.8 | 0.0 | 0.0 | FALSE | 0.90 | wa2013 |
| wa2017 | OTH | 41 | 56.9 | 65.4 | 69.6 | 61.5 | 8.5 | 4.6 | 0.0 | 0.0 | TRUE | 0.48 | wa2013 |
| wa2017 | OTH_RIGHT | 40 | 37.5 | 10.6 | 3.4 | 34.3 | -26.9 | -3.2 | 0.0 | 0.0 | FALSE | 0.77 | wa2013 |
| wa2021 | GRN | 44 | 82.1 | 81.1 | 81.1 | 81.3 | -1.0 | -0.8 | 0.0 | 0.0 | TRUE | 0.97 | wa2017 |
| wa2021 | IND | 11 | 43.1 | 39.8 | 37.0 | 50.8 | -3.3 | 7.7 | 0.0 | 0.0 | TRUE | 0.80 | wa2017 |
| wa2021 | ONP | 26 | 50.4 | 74.3 | 81.1 | 40.6 | 23.8 | -9.8 | 0.0 | 0.0 | FALSE | 0.83 | wa2017 |
| wa2021 | OTH | 44 | 55.8 | 58.4 | 58.5 | 56.9 | 2.6 | 1.0 | 0.0 | 0.0 | TRUE | 0.94 | wa2017 |
| wa2021 | OTH_RIGHT | 34 | 33.3 | 27.4 | 26.7 | 37.5 | -5.9 | 4.2 | 0.0 | 0.0 | TRUE | 0.93 | wa2017 |
| wa2025 | GRN | 32 | 79.2 | 91.0 | 91.2 | 82.1 | 11.9 | 2.9 | 0.0 | 0.0 | FALSE | 0.98 | wa2021 |
| wa2025 | IND | 10 | 62.0 | 48.2 | 50.3 | 43.1 | -13.8 | -18.9 | 0.0 | 0.0 | FALSE | 0.71 | wa2021 |
| wa2025 | ONP | 20 | 34.5 | 31.3 | 29.7 | 50.4 | -3.2 | 15.9 | 0.0 | 0.0 | TRUE | 0.92 | wa2021 |
| wa2025 | OTH | 25 | 61.4 | 61.7 | 62.4 | 55.8 | 0.3 | -5.6 | 0.0 | 0.0 | TRUE | 0.90 | wa2021 |
| wa2025 | OTH_RIGHT | 31 | 33.2 | 2.4 | 0.0 | 33.3 | -30.8 | 0.1 | 0.0 | 0.0 | FALSE | 0.93 | wa2021 |

### Pass bar (FR5)

What the numbers are: mean absolute error of the Labor-flow share, in points; lower is better; blend_MAE is a fixed 50/50 average of estimate and borrow (not tuned). Bar cells are Greens and One Nation with at least 5 key seats and 20,000 key first preferences. Federal rows use the reconstructed key; the next table scores federal against the AEC's official flows.

| set | cells | est_MAE | borrow_MAE | raw_MAE | blend_MAE | GRN_est | GRN_borrow | ONP_est | ONP_borrow | nGRN | nONP |
|---|---|---|---|---|---|---|---|---|---|---|---|
| plan test set | 33 | 6.22 | 5.52 | 8.56 | 3.98 | 4.98 | 5.50 | 8.13 | 5.56 | 20 | 13 |
| federal only (2004-2025) | 16 | 4.01 | 3.63 | 7.13 | 2.47 | 3.79 | 2.34 | 4.23 | 4.92 | 8 | 8 |
| states only (NSW, Vic, Qld, SA) | 17 | 8.31 | 7.31 | 9.91 | 5.40 | 5.78 | 7.61 | 14.37 | 6.59 | 12 | 5 |
| plus WA (supplementary) | 41 | 6.00 | 5.97 | 7.77 | 4.30 | 4.88 | 5.22 | 7.93 | 7.27 | 26 | 15 |

Estimator below 5 points: **FALSE**. Estimator no worse than borrowing: **FALSE**.

What the numbers are: federal estimator error against the AEC's OFFICIAL national flows, points; lower is better; borrow = previous election's official flows (2010 onward), est_MAE_same_cells is the estimator on those same cells, blend_MAE a fixed 50/50 average of estimate and borrow (not tuned).

| cells | est_MAE | GRN_est | ONP_est | borrow_cells | est_MAE_same_cells | borrow_MAE | blend_MAE | GRN_borrow | ONP_borrow |
|---|---|---|---|---|---|---|---|---|---|
| 14 | 3.32 | 2.99 | 3.66 | 12 | 3.25 | 3.75 | 1.87 | 2.06 | 5.43 |

What the numbers are: the per-year cells behind that row, percent to Labor; err = estimate minus AEC, berr = borrow minus AEC (zero is perfect).

| year | party | aec_votes | aec | est | err | borrow_aec | berr | w |
|---|---|---|---|---|---|---|---|---|
| 2007 | GRN | 967,789 | 79.7 | 83.4 | 3.8 | NA | NA | 0.86 |
| 2007 | IND | 275,136 | 45.4 | 46.8 | 1.3 | NA | NA | 0.58 |
| 2007 | ONP | 32,650 | 47.0 | 43.2 | -3.8 | NA | NA | 0.08 |
| 2007 | OTH | 121,521 | 61.1 | 58.4 | -2.8 | NA | NA | 0.19 |
| 2007 | OTH_RIGHT | 405,688 | 38.9 | 34.3 | -4.7 | NA | NA | 0.54 |
| 2010 | GRN | 1,458,998 | 78.8 | 80.6 | 1.7 | 79.7 | 0.8 | 0.65 |
| 2010 | IND | 312,496 | 43.5 | 44.7 | 1.1 | 45.4 | 1.9 | 0.18 |
| 2010 | ONP | 27,184 | 45.2 | 46.2 | 1.0 | 47.0 | 1.8 | 0.02 |
| 2010 | OTH | 80,192 | 57.9 | 59.6 | 1.8 | 61.1 | 3.3 | 0.02 |
| 2010 | OTH_RIGHT | 403,500 | 36.9 | 36.2 | -0.7 | 38.9 | 2.0 | 0.17 |
| 2013 | GRN | 1,116,918 | 83.0 | 83.6 | 0.6 | 78.8 | -4.2 | 0.98 |
| 2013 | IND | 181,380 | 57.0 | 53.7 | -3.4 | 43.5 | -13.5 | 0.79 |
| 2013 | ONP | 22,046 | 44.9 | 43.8 | -1.1 | 45.2 | 0.3 | 0.24 |
| 2013 | OTH | 132,341 | 61.1 | 68.5 | 7.4 | 57.9 | -3.2 | 0.61 |
| 2013 | OTH_RIGHT | 1,268,059 | 43.7 | 42.7 | -1.0 | 36.9 | -6.8 | 0.99 |
| 2016 | GRN | 1,385,650 | 81.9 | 81.4 | -0.6 | 83.0 | 1.1 | 0.77 |
| 2016 | IND | 631,045 | 58.1 | 55.5 | -2.6 | 57.0 | -1.0 | 0.35 |
| 2016 | ONP | 175,020 | 49.5 | 51.1 | 1.6 | 44.9 | -4.6 | 0.43 |
| 2016 | OTH | 245,399 | 61.0 | 63.3 | 2.3 | 61.1 | 0.1 | 0.29 |
| 2016 | OTH_RIGHT | 708,086 | 37.3 | 40.3 | 3.0 | 43.7 | 6.5 | 0.55 |
| 2019 | GRN | 1,482,923 | 82.2 | 86.2 | 3.9 | 81.9 | -0.3 | 0.97 |
| 2019 | IND | 526,767 | 60.1 | 55.8 | -4.3 | 58.1 | -2.0 | 0.80 |
| 2019 | ONP | 438,587 | 34.8 | 34.8 | -0.0 | 49.5 | 14.8 | 0.92 |
| 2019 | OTH | 270,493 | 60.2 | 59.8 | -0.3 | 61.0 | 0.8 | 0.61 |
| 2019 | OTH_RIGHT | 798,385 | 33.8 | 31.6 | -2.2 | 37.3 | 3.5 | 0.90 |
| 2022 | GRN | 1,795,985 | 85.7 | 89.1 | 3.4 | 82.2 | -3.5 | 0.91 |
| 2022 | IND | 812,669 | 63.6 | 58.2 | -5.4 | 60.1 | -3.5 | 0.61 |
| 2022 | ONP | 727,464 | 35.7 | 28.3 | -7.4 | 34.8 | -0.9 | 0.58 |
| 2022 | OTH | 357,023 | 58.3 | 59.3 | 1.1 | 60.2 | 1.9 | 0.63 |
| 2022 | OTH_RIGHT | 956,537 | 35.4 | 35.4 | 0.0 | 33.8 | -1.6 | 0.60 |
| 2025 | GRN | 1,889,977 | 88.2 | 95.1 | 6.9 | 85.7 | -2.5 | 0.98 |
| 2025 | IND | 1,163,504 | 66.9 | 64.5 | -2.5 | 63.6 | -3.3 | 0.90 |
| 2025 | ONP | 991,814 | 25.5 | 14.8 | -10.7 | 35.7 | 10.2 | 0.89 |
| 2025 | OTH | 377,292 | 56.5 | 59.9 | 3.4 | 58.3 | 1.7 | 0.84 |
| 2025 | OTH_RIGHT | 784,109 | 35.2 | 35.2 | -0.0 | 35.4 | 0.2 | 0.90 |

### Interval coverage (FR4)

What the numbers are: share of class cells where the key lies inside the 90% interval; 0.90 is calibrated, lower means over-confident. `bootstrap_shrunk` is the percentile interval of the shrunk bootstrap draws (the spec's interval); `posterior` is estimate +/- 1.645 sqrt(w) se (secondary).

| set | cells | cover_bootstrap_shrunk | cover_posterior | n_w_lt_0.1 | n_w_gt_0.9 |
|---|---|---|---|---|---|
| plan test set, all classes | 94 | 0.46 | 0.48 | 19 | 36 |
| plan test set, Greens/ONP bar cells | 33 | 0.24 | 0.27 | 6 | 18 |
| plan test set, w >= 0.5 | 67 | 0.55 | 0.51 | 0 | 36 |

### Per-election error, all classes with at least 20,000 key first preferences (FR4)

What the numbers are: mean absolute error of the Labor-flow share across classes, points; lower is better.

| election | classes | prior | est_MAE | borrow_MAE |
|---|---|---|---|---|
| fed2004 | 5 | fed2001 | 4.4 | 8.4 |
| fed2007 | 5 | fed2004 | 2.7 | 2.3 |
| fed2010 | 5 | fed2007 | 1.2 | 1.2 |
| fed2013 | 5 | fed2010 | 3.9 | 6.0 |
| fed2016 | 5 | fed2013 | 2.3 | 2.4 |
| fed2019 | 5 | fed2016 | 2.1 | 4.0 |
| fed2022 | 5 | fed2019 | 3.8 | 2.2 |
| fed2025 | 5 | fed2022 | 4.3 | 4.4 |
| nsw2011 | 3 | fed2010 | 5.3 | 30.9 |
| nsw2015 | 4 | nsw2011 | 7.5 | 5.9 |
| nsw2019 | 5 | nsw2015 | 6.6 | 5.9 |
| nsw2023 | 5 | nsw2019 | 7.4 | 3.0 |
| vic2006 | 2 | fed2004 | 5.4 | 5.4 |
| vic2010 | 2 | vic2006 | 5.2 | 5.2 |
| vic2014 | 3 | vic2010 | 2.5 | 2.5 |
| vic2018 | 3 | vic2014 | 3.6 | 3.6 |
| vic2022 | 4 | vic2018 | 4.4 | 5.8 |
| qld2020 | 5 | fed2019 | 3.4 | 5.9 |
| qld2024 | 5 | qld2020 | 3.6 | 3.0 |
| sa2026 | 2 | fed2025 | 30.2 | 4.8 |

### Exhaust on optional-preferential elections (FR4)

What the numbers are: mean absolute error of the exhaust share, points; lower is better. Cells: 17 (borrow available on 17).

| est | borrow |
|---|---|
| 9.6 | 14.7 |

### AE's estimates as a second reference (FR4)

What the numbers are: mean absolute error against the corrected key on cells where AE published a value, points; lower is better.

| cells | AE | estimator | borrow |
|---|---|---|---|
| 44 | 10.5 | 5.5 | 4.7 |

### Reading the result (written after the run; every number is from the tables above)

- **What was wrong with the key.** The first key assumed that every ballot in an excluded candidate's pile flows like the pile's average. A pile is a mix: the Greens pile holds Greens ballots plus ballots that arrived from smaller parties, and those do not flow alike, so the average drags every class toward the middle. FR8 isolates it: with the old proportional rule the federal Greens sit 3.4 to 7.9 points below the AEC and One Nation up to 7.4 above, growing as more minor parties crowd the count (2007 to 2025). Restricting to seats whose real final two were Labor v Coalition, the first key's scope, changes the Greens by only 0.1 to 1.4 points (2025: -7.9 against -6.5 with every seat), so the notional counts and the dropped seats are minor. They were not the cause.
- **The fix, and how far it gets.** The federal key now follows each ballot class through the AEC's candidate-level distributions for all 150 seats, with a fitted "tilt" so that, for example, Greens ballots in a mixed pile go to Labor more than the pile average (`scripts/flow_key_reconstruction.R`). Result against the AEC (FR6): **Greens within 1 point in all 7 elections (largest gap 0.9, mean 0.4); One Nation within 1 point in 4 of 7 (mean 2.0): 2010 +2.8 and 2013 +6.2 (27,184 and 22,046 first preferences nationally, so a handful of ballots) and 2025 -2.6 (991,814 first preferences).** The independents class is within 1 point in all 7 years; Others and the right-wing minors miss by up to 3.8 and 3.5 in 2025. So the stated target (1 point in every year for Greens and One Nation) is met for the Greens and not for One Nation. The remaining One Nation gap is where the tilt of a rare origin cannot be pinned down; I did not force it by fitting a separate constant per class.
- **The match is partly by construction.** Two constants (tilt exponent 0.75, evidence half-point 100,000 first preferences) were chosen from nine variants tried (uniform exponent 0, 0.5, 0.75, 1; four evidence-weighted settings; one fit pooled across elections) to minimise the federal Greens and One Nation gap to the AEC. So the federal key agreeing with the AEC is an in-sample result for those two numbers. FR7 shows the check is not blind: with Labor and Coalition swapped, the Greens key is 20.2 against the AEC's 85.7 and the check fails.
- **Verdict on the pass bar (corrected key, plan test set): still FAIL, much closer.** Estimator 6.22 points against 5.52 for borrowing (first run 9.02 against 4.85). Split: federal reconstruction key 4.01 against 3.63 (under 5, but not better than borrowing); states 8.31 against 7.31. The state One Nation cell is dominated by SA 2026 (12 key seats, estimate 74.2 against key 29.3, +44.9). Taking SA 2026 out of the 17 state cells by hand (a post-hoc, descriptive cut, not a result) leaves the estimator at 5.4 and states are still worse than borrowing once NSW 2011 (whose "borrow" is a federal election with no exhaust) and SA 2026 are both set aside (est 5.5 against borrow 5.1 on 14 cells).
- **Federal against the AEC's official flows, the key-independent test.** Estimator 3.32 points on 14 Greens/One Nation cells (Greens 2.99, One Nation 3.66); borrowing the previous election's official flows 3.75 on 12 cells (Greens 2.06, One Nation 5.43); a fixed 50/50 average of the two 1.87. On this key the federal estimator passes both clauses of the bar (below 5; 3.25 against 3.75 on the same 12 cells), but it loses on the Greens (over-estimated 3.4 to 6.9 points in 2019, 2022, 2025) and is better on One Nation overall (3.66 over 7 cells against 5.43 over 6) but unevenly: exact in 2019 where borrowing is 14.8 out, then 7.4 low in 2022 (borrowing 0.9) and 10.7 low in 2025 (borrowing 10.2 high).
- **Recommendation: blend, do not use the estimator alone.** Borrowing wins for Greens (stable year to year), the estimator wins for One Nation and for classes whose flows move between elections; a fixed 50/50 average is the best of the three on the federal official key (1.87) and on the plan test set (3.98 against 6.22 and 5.52). Caution on the blend: 50/50 is a default weight, not a fitted one, but it was first computed in this run and is scored on the same cells that motivated it; treat it as a candidate to confirm on a later election, not a validated rule.
- **Intervals remain badly over-confident**: the key lies inside the 90% interval in 46% of all plan-test cells and 24% of Greens/One Nation cells (first run 38% and 16%). The remaining error is bias, not sampling noise.
- **Exhaust (NSW, Qld before 2017)**: estimator 9.6 points against 14.7 for borrowing on 17 cells (first run 9.9 against 14.6); not part of the bar.
- **AE's hand-made numbers** against the corrected key: AE 10.5, estimator 5.5, borrowing 4.7 on 44 cells (first run 11.1, 7.6, 4.2).

### What is unverified (revalidation)

- **State keys have no official table to check against.** They use the same tilt model and constants as the federal key, but only the federal result is measured. If the state keys carry a bias like the federal proportional-rule bias (Greens 3 to 8 points low), the state estimator errors above are overstated for the Greens and the verdict for the states could move toward the estimator; if they carry the One Nation overshoot, the reverse. The state keys moved by +1 to +4 points on the Greens relative to the first run (for example Qld 2020 74.9 to 78.1, Qld 2024 75.9 to 80.2), the direction and rough size of the federal correction.
- **The state tracker works on party-class buckets, not candidates.** Federal could be tracked by candidate from the AEC files; the state transfer files only give the recipients' party class, so a state pile is a class bucket mixing all candidates of that class. The tilt is fitted per election on those buckets (88 Victorian seats against 150 federal); thin elections give a noisier tilt and the evidence-weighted exponent shrinks it. Not tested: whether the state tilt matches the federal tilt.
- **Federal notional counts are settled from division totals, not tracked ballots.** In 3 to 35 seats a year the real count excluded Labor or the Coalition before the end; for those I split the mass still held by non-major candidates between Labor and the Coalition so that the division's total two-party result (AEC division file, all vote types) is reproduced, tilting by each origin's Labor:Coalition odds. 2004 has no AEC division file on disk: its totals are the AEC final counts for 146 seats and `output/seat-tpp-estimates.csv` (an estimate) for 4.
- **One federal fix is sample-specific**: the Greens and One Nation targets are the AEC's national class totals; the AEC's own state-by-party tables (also in `output/aec-tpp-flows.csv`) were not used to check the key state by state.
- **Estimator unchanged and still trained on Labor v Coalition seats only**, while the federal key now covers all seats (as the AEC does). FR8 says the scope difference is worth under 1.4 points for the Greens, so the estimator's own over-estimate of the Greens (3 to 7 points in 2019-2025) is not a key artefact.
- **Priors changed with the key**: `output/flows-estimated.csv` was rewritten by this run, so estimates for elections without a published distribution now borrow from the corrected keys. Federal 2001 and Qld/NSW/SA/WA keys use the class-level tracker; fed2001 has no AEC table to check.
