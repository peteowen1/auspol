# State-level sitting-member defectors: why the model barely carries their vote (2026-10-06)

Diagnosis only. Nothing in R/, scripts/ or output/ was changed. Scripts and raw tables:
`scratchpad/defectors/{cases,walk,rates,k}.R` and `cases.csv`, `fitcases.csv`.

## 1. Case table

Each row is a person who held the seat for ALP/LNP/NAT at the previous election and stands under another label at the next one.
Shares are primary-vote percent (`pcv`). "Realised carry" = new share / old share (higher = kept more of their vote).
"Shipped rate" = the sitting-member rate the model applied at that target (`discount_mp`, mode 2, state target = pooled all-level median).
Good = predicted IND/new-class value close to actual, and shipped rate close to realised carry. `base_pred` = stage 1 input; `xgb` = `xgb_pred_seat` where forecasts.csv has the row.
`n/a` = forecasts.csv has no row for that election (it holds fed2010+ and wa2013+ only).

| pair | seat | person | old class, old % | new class, new % | realised carry | shipped rate | base_pred new class | xgb new class | actual share |
|---|---|---|---|---|---|---|---|---|---|
| wa2001 | Pilbara | Graham | ALP 63.8 | IND 54.6 | 0.86 | none (0 earlier cases) | n/a (caller: 0.0) | n/a | n/a |
| wa2005 | Vasse | Masters | LNP 29.7 (UNCONFIRMED: corpus value looks low for a sitting member) | IND 20.6 | 0.69 | none (1 case) | n/a | n/a | n/a |
| wa2008 | Nedlands | Walker | LNP 51.9 | IND 22.8 | 0.44 | none (4 cases, gate is 5) | n/a | n/a | n/a |
| wa2008 | Kalgoorlie (was Murchison-Eyre 2005) | Bowler | ALP 51.8 | IND 34.0 | 0.66 | none; also never matched (other seat) | n/a (caller: 0.9) | n/a | n/a |
| wa2008 | Morley (was Ballajura) | D'Orazio | ALP 56.2 | IND 16.0 | 0.29 | none; also never matched (seat renamed) | n/a | n/a | n/a |
| wa2017 | Hillarys | Johnson | LNP 64.3 | IND 20.1 | 0.31 | 0.272 | 19.8 | 22.1 | 20.1 |
| vic2018 | Morwell | Northe | LNP 44.4 | IND 19.6 (class 28.2 with others) | 0.44 | 0.292 | 26.2 | 28.8 | 28.2 |
| qld2020 | Whitsunday | Costigan | LNP 32.2 | OTH 9.4 | 0.29 | 0.313 | 11.4 | 14.6 | 14.2 |
| sa2022 | Kavel | Cregan | LNP 48.1 | IND 50.5 | 1.05 | 0.302 | 27.1 | 27.8 | 50.5 |
| sa2022 | Narungga | Ellis | LNP 46.5 | IND 32.5 | 0.70 | 0.302 | 33.6 | 36.2 | 40.8 |
| sa2022 | Waite | Duluk | LNP 45.2 | IND 19.7 | 0.43 | 0.302 | 22.4 | 24.9 | 34.2 |
| nsw2023 | Kiama | Ward | LNP 53.6 | IND 38.8 | 0.72 | 0.374 | 23.0 | 30.6 (29.8 seat) | 38.8 |
| sa2026 | MacKillop | McBride | LNP 62.3 | IND 14.8 | 0.24 | 0.435 | 25.4 | 31.1 | 15.0 |
| sa2026 | Black | Speirs | LNP 50.1 | IND 14.1 | 0.28 | 0.435 | 18.5 | 19.7 | 13.9 |

Notes on the table.
- Cases found by person-matching `output/candidacies.csv` (surname + given name, `align_person_keys`), same seat, or a different seat for prior members with 20%+. Non-sitting losers are in `cases.csv`; they are not the problem here.
- Cross-seat matches that are NOT the same person and are excluded above: Williams Leslie/Leigh (nsw), McDonald Jim/James (qld), Robinson Mark/Matthew (qld), Williams Gabrielle/Gayle (vic). A loose given-name match produces false cross-seat defectors.
- wa2005 Vasse, wa2008 base_pred/xgb for the WA 2001-2008 rows are NOT in forecasts.csv. `output/wa-shares-wa2001.csv` is dated 2026-09-17 and shows Pilbara IND 17.6 (= 0.282 x 63.8 less slope). That file predates the time-forward fit, so it is the old behaviour, not what the rebuild produces.
- Morwell is not a miss: the IND class is 26.2 base and 29.6 xgb against 28.2 actual.

## 2. Walks

### Pilbara 2001 (Graham, ALP 63.8 -> IND 54.6)

1. `personal_prior_vote("wa1996","wa2001")` returns `own_prev_pcv = NA` for IND, ALP, LNP and ONP. I ran it; the output is printed in `walk.R`.
2. Why: the harness (`scripts/backtest_candidate_wa.R:401-411`) calls `fit_defector_discount("wa2001")`. That fit is time-forward (`fit_pairs_for()`, `R/time_forward.R:14-19`, called at `R/candidate_returns.R:1115`). No pair in `all_election_pairs()` is dated before February 2001, so n = 0. The log says it: `BW0d! only 0 defector case(s) (need >=5); no discount applied` (`s1_wa.log:21`).
3. The harness then keeps `.defect <- NULL` (line 408-411). In `personal_prior_vote()` the whole defector block is gated on `!is.null(major_discount)` (`R/candidate_returns.R:842`), so it is skipped: no carry, no transfer.
4. Cross-seat credit cannot help: `CSV1! wa2001: no earlier cross-seat cases`, and it only credits earlier non-major results (`R/cross_seat_vote.R:30,94`).
5. Nomination zeroing does not zero IND (an independent is nominated; the zeroed seats list at `s1_wa.log:31` does not include Pilbara).
6. Result: IND base is the 1996 IND class share (about 0), and ALP keeps the full 63.8 because nothing was transferred out (`TR1 wa2001: 3 applied` are other rows).
7. History: the 2026-09-17 file shows Pilbara IND 17.6, so the old full-sample fit carried 0.282 x 63.8. The time-forward change (prereg 2026-09-28) removed it. This is a regression for the earliest target in each jurisdiction, not a mechanism bug.

Responsible lines: `R/candidate_returns.R:1115` (time-forward pair filter) with `:1143` (min_n gate returns NULL), and `scripts/backtest_candidate_wa.R:408-411`.

### Kalgoorlie 2008 (Bowler, ALP in Murchison-Eyre 2005 -> IND in Kalgoorlie 2008)

Three separate gaps, each enough on its own.
1. No rate: `BW0d! only 4 defector case(s) (need >=5)` (`s1_wa.log`, around line 98). The four are fed2007 x2, wa2001, wa2005. One short of the cliff; the cliff is exactly what the global instructions say not to use.
2. No match: the defector block merges on `(.s, .k)` = same normalised seat and same person (`R/candidate_returns.R:849`, `:741`). Bowler's 2005 seat is "murchison-eyre", his 2008 seat "kalgoorlie". `seat_rename_map()` (`R/names.R:352`) lists only Denison, Batman, Melbourne Ports, Frome. `scripts/fetch_retirements.R:450` already records "stood in and won Kalgoorlie instead" but nothing reads it.
3. Cross-seat credit refuses him by design: it credits only an earlier NON-major result ("a major-party vote is the party's (McBride)", `R/cross_seat_vote.R:22-24`).
4. The 2008 prior is also replaced by the notional on new boundaries (`SNP1 wa2008`), which has no person identity.

Result: the IND class gets only the generic share. The caller reports 0.9. D'Orazio (Ballajura -> Morley) fails the same way.

### Kiama 2023 (Ward, LNP 53.6 -> IND 38.8)

1. Person found: `personal_prior_vote("nsw2019","nsw2023", major_discount = 0.272)` returns `IND own_prev_pcv 20.04, prev_party LNP, transfer 20.04`. The 0.272 passed in is overridden in mode 2 by `fit_defector_discount()$discount_mp` = 0.374 (`R/candidate_returns.R:546-562`; `DF2 two-rate defector: member 0.374`, `s1_nsw_2023.log:54`). 0.374 x 53.59 = 20.04.
2. Which fit: `DEF-L nsw2023 ... fed est 0.172 n=5; state est 0.440 n=9 w 0.72 shrunk 0.421 -> using state (mode 2: pooled) 0.374` (`s1_nsw_2023.log:49`). Mode 2 means: a federal target gets its own shrunk federal rate, but a STATE target ignores the state estimate and takes the all-level pooled median (`R/candidate_returns.R:1171-1185`, `hit <- if (.dbl == "2" && tl == "state") mp`). So a state target is charged a rate pulled down by 5 federal cases (median 0.17) even though the state estimate from 9 earlier cases is 0.44 and the realised carry here is 0.72.
3. Transfer: `remove_transferred_votes` takes 20.04 out of LNP. But `AUSPOL_DEFECT_CONSERVE=1` (line 886-895) leaves the other 33.5 points with LNP on purpose. Result LNP base 30.2.
4. After the slope step IND base is 23.0 (actual 38.8) and LNP 30.2 (actual 12.0). ALP actually rose to 34.4.
5. xgb layer: IND +7.7 to 30.6, LNP -0.1 to 30.1 (`forecasts.csv`). It repairs part of IND and none of LNP.
6. Nothing zeroed or shrank it: the miss is the rate (0.374 vs 0.724) and the conserve rule.

Old plus new class: predicted 23.0 + 30.2 = 53.2, actual 38.8 + 12.0 = 50.8. The pair total is right; the split is wrong. That fits "defector keeps a share of the personal vote" but not "the rest stays with the old party".

## 3. Rate comparison

Realised carry of a sitting member who goes from a major to a non-major, with n and level. All state cases (n = 12): 0.24, 0.28, 0.29, 0.31, 0.43, 0.44, 0.44, 0.69, 0.70, 0.72, 0.86, 1.05 (median 0.44). Federal (n = 7): median 0.21.

Shipped rate vs realised, time-forward, state targets where a rate existed (n = 9 cases; `rates.R`):

| target | cases | realised | shipped |
|---|---|---|---|
| nsw2023 | Ward | 0.72 | 0.374 |
| qld2020 | Costigan | 0.29 | 0.313 |
| sa2022 | Waite / Ellis / Cregan | 0.43 / 0.70 / 1.05 | 0.302 |
| sa2026 | McBride / Speirs | 0.24 / 0.28 | 0.435 |
| vic2018 | Northe | 0.44 | 0.292 |
| wa2017 | Johnson | 0.31 | 0.272 |

- Mean (realised minus shipped) = +0.16 across the nine: the shipped rate is biased low for state sitting members.
- Mean absolute error of the carry: 0.243 shipped, 0.237 with a state rate shrunk toward the pooled median with 3 pseudo-cases (`(n_state x state_median + 3 x pooled)/(n_state + 3)`); bias falls to +0.05.
- Mean absolute error barely moves because the cases split into two groups: 0.24-0.31 (McBride, Speirs, Costigan, Johnson) and 0.70-1.05 (Ward, Graham, Cregan, Ellis). Nothing in this table separates them. Prior share does not (Graham 63.8 carried 0.86, Johnson 64.3 carried 0.31). The existing comment at `R/candidate_returns.R:681-684` says the same: scandal/disendorsement versus principled resignation is not in any column. UNCONFIRMED: tenure, whether the seat had a prior independent class, and whether the person was disendorsed were not tested here.
- Time-forward estimability per target (state sitting-member cases available, state median / shrunk with k = 3):

| target | state n | state median | shrunk k=3 | shipped |
|---|---|---|---|---|
| wa2001 | 0 | none | none | none |
| wa2005 | 1 | 0.86 | 0.855 | none |
| wa2008 | 2 state (4 incl. fed) | 0.77 | 0.725 | none |
| nsw2023 | 9 | 0.44 | 0.424 | 0.374 |
| vic2018 | 4 | 0.57 | 0.449 | 0.292 |
| wa2017 | 3 | 0.69 | 0.482 | 0.272 |
| sa2026 | 10 | 0.57 | 0.536 | 0.435 |

So a time-forward shrunk state rate is estimable for every target except wa2001, which has no earlier evidence in the corpus at all and cannot be fixed by any time-forward rate. Three of the earliest targets (wa2001, wa2005, wa2008) get nothing only because of the `min_n = 5` cliff.

An earlier amendment (mode 2, 2026-10-05) turned the state rate off because Hillarys wa2017 moved 21.7 -> 43.9 against actual 20.1 with the n=3 state estimate. The k=3 shrink above gives Hillarys 0.482 (not 0.644), which is the same direction and still the wrong answer for that case; this is the cost of a bimodal population, not a bug in the shrinkage.

## 4. Proposal (ONE fix)

Replace the sitting-member defector rate for STATE targets with a state-level rate partially pooled toward the all-level pooled median (k = 3 pseudo-cases), with no `min_n` cliff (use the pooled value, and the shrunk value when n_state is 1 to 4), and apply it to a person matched in ANY seat of the same state's previous election (strict surname + full given name), not only the same seat. One function pair changes: the `hit <- ...` line at `R/candidate_returns.R:1185` plus the min_n gate at `:1143`, and the `(.s, .k)` merge at `:849` for the cross-seat match.

Stage changed: base_pred, so stage 1 (the as-at xgb models retrain on it). Not a post-xgb patch.

Expected per case, base_pred only (not measured end to end; UNCONFIRMED until run):

| case | now | after | actual |
|---|---|---|---|
| Kiama IND | 23.0 | about 25.7 (0.424 x 53.6 = 22.7 carried) | 38.8 |
| Kalgoorlie IND | about 0.9 | about 37.6 (0.725 x 51.8), if Bowler is matched across seats | 34.0 |
| Pilbara IND | 0.0 | no change (n = 0, not estimable time-forward) | 54.6 |
| Morley | 0 | about 40 (0.725 x 56.2) against actual 16.0, a new over-prediction | 16.0 |

The honest size: this closes the bias (+0.16 to +0.05) and fixes the structural gap at Kalgoorlie, but it does not fix Kiama, Pilbara or Kavel (carry above 0.7) while also over-predicting McBride-type cases. The bimodal spread needs a discriminating feature that is not in the corpus. The pooled primary measure is log loss and share RMSE across the 22 pairs; it needs the prereg and a state-only check before it ships.

Separate, not the proposal: `AUSPOL_DEFECT_CONSERVE=1` left 33.5 points at Kiama's LNP and the actual was 12.0. The prior arm "0" was refused as a pooled result (2026-09-17 prereg); a state-sitting-member-only slice was not reported there.

## 5. Unconfirmed

- Pilbara and Kalgoorlie model values (0.0, 0.9) are the caller's; forecasts.csv has no wa2001-2008 rows and I did not run a harness. Pilbara's 17.6 vs 0.0 is inferred from the stale 2026-09-17 shares file.
- Whether Pilbara IND is zeroed or just near zero: no line printed.
- wa2005 Vasse prior of 29.7 (a sitting member that low is suspicious; Masters' history not verified).
- Which of the 12 state cases were disendorsed or scandal-driven.
- Morley: D'Orazio is the same person per the name match; the Ballajura-to-Morley seat link was not verified.
