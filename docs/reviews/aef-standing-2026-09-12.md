# Where we stand against AE Forecasts, 2026-09-12

All 22 pairs regenerated at `AUSPOL_N_SIMS=20000` with the salience percentile
fix in place and every other switch at its published default. Every pair carries
code tag `0d67b8d` and is minutes old -- no mixed arms, which is the failure this
table is most prone to.

**Pooled, 22 pairs, 2,050 seat-elections: 0.3065.**

## The seven AEF-comparable elections

| pair | n | ours | AEF | |
|---|---|---|---|---|
| wa2025 | 53 | **0.1916** | 0.3537 | **−0.162 ahead** |
| qld2024 | 93 | **0.3265** | 0.3578 | **−0.031 ahead** |
| vic2022 | 78 | **0.2478** | 0.2572 | −0.009 ahead |
| fed2025 | 150 | **0.2989** | 0.3025 | −0.004 ahead |
| nsw2023 | 88 | 0.2643 | **0.2138** | +0.051 behind |
| fed2022 | 150 | 0.3034 | **0.2353** | +0.068 behind |
| sa2026 | 47 | 0.5384 | **0.3525** | **+0.186 behind** |

**Ahead on four of seven. Pooled: ours 0.3016 against 0.2855, behind by 0.0161
(5.6%).** fed2022 was 0.3498 before today's percentile fix, so that gap roughly
halved.

## The deficit is entirely non-majors

Mean primary error on the winning candidate, 659 comparable seats:

| winner | seats | ours | AEF | gap |
|---|---|---|---|---|
| **ONP** | 4 | **13.75** | 10.97 | **+2.78** |
| **IND** | 36 | **8.31** | 5.74 | **+2.57** |
| GRN | 13 | 6.38 | 6.31 | +0.07 |
| LNP | 228 | **3.60** | 3.87 | −0.27 |
| ALP | 373 | **4.05** | 4.63 | −0.58 |

**Overall we beat AEF on primary accuracy, 4.23 against 4.50.** We are better on
Labor and the Coalition, level on the Greens, and worse on One Nation and
independents -- 40 seats of 659 carrying the whole gap.

## The two worst pairs, seat by seat

**fed2022** -- ten seats carry 52% of the pair's log loss. Seven of ten are
flagged `primary` or `both`, so it is the point estimate rather than the flows.

| seat | winner | our prob | AEF | our primary | AEF's | actual |
|---|---|---|---|---|---|---|
| Tangney | ALP | 0.013 | 0.084 | 25.2 | 34.3 | 38.1 |
| Ryan | GRN | 0.044 | 0.028 | 18.6 | 20.7 | 30.2 |
| Curtin | IND | 0.149 | 0.445 | 9.2 | 23.3 | 29.5 |
| Mackellar | IND | 0.177 | 0.280 | 11.3 | 23.0 | 38.1 |

**sa2026** -- ten seats carry **89%**, and the four One Nation seats alone are
15.4 of 25.3.

| seat | winner | our prob | AEF | our primary | AEF's | actual | why |
|---|---|---|---|---|---|---|---|
| MacKillop | ONP | 0.012 | 0.181 | 19.0 | 25.4 | 35.3 | both |
| Narungga | ONP | 0.017 | 0.092 | **19.7** | **18.4** | 37.5 | **flow/var** |
| Hammond | ONP | 0.025 | 0.128 | **18.9** | **18.8** | 27.4 | **flow/var** |
| Ngadjuri | ONP | 0.038 | 0.405 | 22.4 | 28.5 | 34.9 | both |

**Narungga and Hammond are the important rows.** AEF's primary was no better
than ours -- 18.4 against our 19.7, 18.8 against our 18.9 -- yet they gave the
winner five times the probability. Equally wrong about the vote, far less
confident about it. That is a variance failure on our side, not a point-estimate
one, and **`scripts/fit_xgb_primary_sd.R` already wants 6.0 points of spread on
Narungga** against the flat value it currently gets. It is switched off.

## Statewide forecast quality, and why sa2026 compounds

`level_pred` against what each class actually polled:

| | mean absolute error |
|---|---|
| fed2022 | **0.64 points** |
| sa2026 | **1.93 points** |

fed2022's national forecast was good, so its seat misses are purely
distributional -- we knew independents would poll 4.75 nationally and still gave
Curtin 9.2 against an actual 29.5.

sa2026 is wrong at both levels: One Nation under-forecast statewide by 2.64
points AND distributed too evenly. 17.3 predicted in MacKillop against 35.3 is
partly the statewide shortfall and mostly the flat distribution.

## What is actually wrong, in priority order

1. **One Nation in South Australia.** Worst class-jurisdiction cell in the model
   (RMSE 8.55 against AEF's 5.58), the only correctable bias (+1.41 and rising
   with the prediction), the pair where the v7 primary regressed, and now the
   single biggest contributor to the AEF gap. Needs the census join: the seats
   they won are rural and lower-income, the seats they lost are affluent urban,
   and we have no feature for either. Packs are on disk; `sed_code` needs mapping
   to seat names via `scripts/build_census_correspondence.R`.
2. **No state-level swing in federal elections.** Hasluck and Tangney were missed
   by 11.4 and 12.9 points on the Labor primary because 2022 was a 10-12 point
   Labor swing in Western Australia and `level_pred` carries only a national
   number. AEF had something state-aware. Check whether our poll data holds
   state breakdowns.
3. **Turn the SD model on for the cases it was built for.** Narungga and Hammond
   are exactly its target and it is off.
4. **Returning independents are under-called too.** Finniss: Lou Nicholson polled
   19.6% in 2022 and 18.5% in 2026, almost identical, and we predicted 16.6 and
   gave her 0.208 against AEF's 0.557. Not an emergence problem at all.

## Naming, agreed with Pete

Three quantities, one badly named column each:

| current | should be | what it is |
|---|---|---|
| `x` | `seat_prev_share` | the class's share IN THIS SEAT last time |
| `level_now` | `level_pred` / `level_actual` | holds a FORECAST under `AUSPOL_LEVEL_MODE="pred"` and the ACTUAL RESULT under `"now"` -- same name, opposite meanings |

`fit_xgb_primary_v6.R` keeps one name deliberately so the feature list and saved
models stay stable, but that optimises the plumbing at the cost of hiding
whether a column is a forecast or an answer. In a repo with three recorded
leakage incidents, one introduced while fixing another, that is the wrong
trade. Splitting them also makes the statewide forecast error above a standing
diagnostic rather than something computed ad hoc.

Touches the feature list, the saved models and `xgb_primary_predict_live()`, so
it is its own change.
