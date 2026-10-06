# Why the nine worst "everyone else" over-calls are over-called (2026-10-06)

Diagnosis only. Nothing in `R/`, `scripts/` or `output/` was changed; no harness or rebuild was run.
Scratch scripts (not committed): `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\599330fc-0de9-4609-8538-29a34fc021fd\scratchpad\vicind\{a..o}.R`.

## Bottom line

- **The nine misses are three different mechanisms, not one.** No single fix covers them. In these nine seats the base prediction (`base_pred`) carries 117 of the 154 summed points of over-call (76%), the xgb correction adds 33 (21%), the stage-6 blend/zeroing adds 5 (3%). So "the xgb layer over-calls independents" is true of the Victorian average (it adds +1.25 per independent cell) but is NOT what made these nine.
- **Pascoe Vale, Waite, Kavel** (base layer): a departed independent's class vote is carried to a different, new person at about 0.6; the new person kept 0.08 to 0.42.
- **Sandringham, Bellarine** (xgb layer): the Climate 200 flag adds +7.2 and +6.5 points. The flag was learned from the 2022 federal teal wave. Across all 8 Victorian 2022 Climate 200 candidates it is NOT a net over-call (+2.0, SE 2.1), so removing it is not a fix.
- **Shepparton** (base layer, same person): a sitting independent assumed to keep 100% of 38.4% fell to 29.4%.
- **The one population large enough to measure** is the nameless single independent with no previous vote. In Victoria (n=75 contested cells, three elections) the base layer gives them about 6 points and they poll about 3 (+3.16, SE 0.31). That is 58% of the Victorian independent over-call, but it explains only Albert Park among the nine.
- State: all live. Nothing here is fixed.

## Data and method

- Published shares and actuals: `output/snapshots/20261006-2141-1c3f440-from6/` `backtest-vic-sharedetail-...a1d0fca...` (vic2014/18/22) and `backtest-sa-sharedetail-...a1d68e3...` (sa2026) and `...a1d69f9...` (sa2022). I read only that snapshot, never "newest in output/".
- As-at xgb predictions: I reloaded the three saved models per election (`output/xgb-primary-asat/<pair>.ubj`, `-m2`, `-m3`) on `output/xgb-primary-v6-features.csv` and averaged them. **Check: reproduces `output/xgb-primary-asat-predictions.csv` exactly (2,195 of 2,195 rows, max difference 6e-14).** The nine seats' "everyone else" totals from this table match your published figures (56.0, 32.2, 34.7, 20.7, 23.6, 28.1, 26.8, 66.3, 33.4).
- Per-feature contributions are xgboost's own `predcontrib` (additive points, ensemble-averaged). They exclude the renormalisation to 100 (xgb raw sums to about 97 to 100).
- "xgb" below is the as-at prediction renormalised to 100 per seat. "Over-call" = published minus actual, share points; **positive means over-called, zero is good**.
- A cell is one seat and one class (IND, OTH, OTH_RIGHT, ONP). "Contested" = published share above 0 or actual above 0. About half of all IND cells have no candidate (published 0, actual 0) and are left out of every contested figure; including them dilutes the mean (all 264 Victorian IND cells give +1.56, SE 0.31, matching the earlier review).

## 1. Per-seat decomposition

Everyone-else (ALP/LNP/GRN excluded) total share in points, each layer against the actual; the last three columns are how much each layer ADDED to the over-call (points; smaller is better). Ours and AEF are the published figures you gave.

| Seat | Ours | AEF | Actual | Base over | xgb adds | Stage 6 adds |
|---|---|---|---|---|---|---|
| Shepparton | 56.0 | 47.8 | 36.9 | +13.6 | +4.4 | +1.2 |
| Sandringham | 32.2 | 22.4 | 13.2 | +10.5 | +8.5 | +0.1 |
| Pascoe Vale | 34.7 | 12.9 | 17.8 | +16.6 | +0.4 | 0.0 |
| Malvern | 20.7 | 13.5 | 5.6 | +13.3 | +1.8 | -0.1 |
| Ashwood | 23.6 | 13.3 | 7.8 | +7.9 | +8.0 | -0.1 |
| Bellarine | 28.1 | 19.8 | 12.5 | +6.1 | +9.2 | +0.4 |
| Albert Park | 26.8 | 12.9 | 12.8 | +9.9 | +2.7 | +1.5 |
| Kavel (sa2026) | 66.3 | 46.0 | 45.5 | +19.0 | 0.0 | +1.8 |
| Waite (sa2026) | 33.4 | 23.0 | 16.0 | +19.9 | -2.4 | -0.2 |
| Sum of nine | | | | +116.8 | +32.6 | +4.6 |

(Pascoe Vale: AEF 12.9 is below the actual 17.8, so AEF under-called it; we over-called by 16.9.)

The cells doing the damage: candidate, class, then base / xgb / published / actual, share points.

| Seat | Biggest over-called cell(s) | base | xgb | pub | actual | Layer that made it | Kind of cell |
|---|---|---|---|---|---|---|---|
| Shepparton | SHEED, Suzanna (IND) | 38.7 | 41.8 | 42.3 | 29.4 | base +9.3, xgb +3.1 (own prior +2.7, jump +1.5, "has won" +1.4), stage 6 +0.5 | same person, sitting member |
| Shepparton | McGRATH (OTH_RIGHT, 3 cands) | 8.7 | 9.7 | 10.3 | 6.2 | base +2.5, xgb +1.0 (n_cand_now +2.2), stage 6 +0.6 | class of 3 minor right |
| Sandringham | MARTIN, Clarke (IND) | 9.2 | 18.1 | 18.1 | 7.2 | xgb +8.9: Climate 200 flag +7.2, n_cand_now +2.7 | endorsed, repeat candidate (10.3, 8.4, 6.9 in 2014/18/22) |
| Sandringham | ZMEGAC (OTH_RIGHT) | 6.7 | 8.6 | 8.7 | 3.6 | xgb +1.9 (n_cand_now +1.7) | class of 2 |
| Pascoe Vale | BOLTON, Sue (IND) | 19.0 | 18.5 | 18.6 | 4.2 | base | departed class leader, NEW person |
| Malvern | STEFANOPOULOS (IND) | 5.0 | 8.5 | 8.6 | 1.6 | base +3.4, xgb +3.5 (council_elected +1.4, jump +0.6) | own prior 0.3% only |
| Malvern | NATOLI (OTH), SCHMIDT (OTH_RIGHT) | 8.6, 5.3 | 6.8, 5.4 | 6.7, 5.3 | 2.5, 1.6 | base +6.2, +3.7 | class carried from 2018 Sustainable Australia / Animal Justice |
| Ashwood | SALOUMI (IND, 2 cands) | 4.8 | 10.5 | 10.5 | 2.6 | xgb +5.7 (n_cand_now +2.0, council_elected +1.7, council_pct +0.6) | new, 2 cands in class |
| Ashwood | GEYER (OTH_RIGHT, 2 cands) | 5.4 | 8.2 | 8.2 | 3.2 | xgb +2.8 (n_cand_now +1.7, jump +0.8) | class of 2 |
| Bellarine | FENTON, Sarah (IND) | 4.8 | 10.5 | 10.7 | 4.6 | xgb +5.7: Climate 200 flag +6.5 | endorsed, first run |
| Bellarine | MANUELL (OTH_RIGHT) | 5.5 | 8.6 | 8.8 | 3.2 | xgb +3.1 (n_cand_now +1.8) | class of 2 |
| Albert Park | DRAGWIDGE (IND) | 7.4 | 8.9 | 11.1 | 5.9 | base +1.5, xgb +1.5, stage 6 +2.2 | new, 1 cand |
| Albert Park | WESTWOOD (OTH) | 10.2 | 8.3 | 7.9 | 3.1 | base +7.1 | class carried from earlier Animal Justice / Sex Party |
| Kavel | SCHULTZ (IND) | 29.7 | 27.9 | 28.9 | 21.4 | base +8.3 | departed class leader (Cregan 50.5%), new person |
| Kavel | BAKER (OTH_RIGHT) | 6.1 | 8.7 | 10.9 | 1.9 | base +4.2, xgb +2.6, stage 6 +2.2 | class carried from 2018 Conservatives (2.9%) |
| Waite | GARGETT (IND) | 20.7 | 18.6 | 18.6 | 2.9 | base | departed class leaders (Duluk 19.7 + Holmes-Ross 14.6), new person |

## 2. Two walks

### Pascoe Vale 2022: a departed independent's class vote handed to a new person

1. What the model reads for the class "independent": the 2018 independents were Oscar Yildiz 23.5%, John Kavanagh 7.7%, Francesco Timpano 1.7% (class total 32.9; `candidacies.csv`). None stood in 2022. The 2022 independent is Sue Bolton, 4.19% actual, who has no 2018 row.
2. Features the base layer saw (`xgb-primary-features-v6.csv`): `same` FALSE, `same_mp` FALSE, `prior_leader_returns` FALSE, `own_prev_pcv` NA, `dev_prev` 26.8, `permit` 0, `jump` 0.
3. Base layer: the decay for a departed leader (nominal 0.38, `AUSPOL_HONOUR_DEPARTED=1`) fires, but the cell ends at 19.0, which is 0.58 of 32.9. That matches the existing note that the nominal 0.38 is effectively 0.6 to 0.7 after renormalising (`published_flags.R`, `departed-hold-sweep-2026-10-05.md`). Actual retention was 4.2 / 32.9 = 0.13.
4. xgb layer: moves it from 19.0 to 18.5 (largest: `dev_prev` -1.2, `base_pred` -0.9, `council_elected` +0.9). It already knew; it just does not move enough. Stage 6: 18.6.
5. Meanwhile the Liberals (base 10.7, actual 21.0) and Greens (17.0, actual 22.4) were under-called by the same amount the independent was over-called.

Where it is wrong: a person's vote went to a stranger. Match-on-the-person rule (memory `match-on-candidate-not-just-party`).

### Sandringham 2022: a funded-teal flag that did not mean what it meant in training

1. Clarke Martin, independent in 2014, 2018, 2022: 10.3%, 8.4%, 6.9% (falling). Base: 9.2. That alone is a 2-point over-call.
2. `c200` = 1 because `external/reference/climate200/endorsements.csv` lists Martin as Climate 200 backed for 2022 (source: Wikipedia). `n_cand_now` = 2 (Martin plus one tiny independent).
3. The as-at vic2022 model was trained on elections before November 2022. The only rows with `c200` = 1 in training are fed2022 (20 rows, the Mackellar / Goldstein / Kooyong wave) and fed2019 (1 row, Warringah). I did not check what those 21 rows scored, only that they are federal.
4. Contributions to Martin's prediction, points: intercept (base) +9.2, `c200` **+7.2**, `n_cand_now` +2.7, `margin` -0.9, `prev_swing` +0.8, `jump` -0.5. Prediction 18.1; actual 7.2.
5. What the actual 2022 Climate 200 state candidates did (class cell, points; same list):

| Seat | base | xgb | published | actual | over-call |
|---|---|---|---|---|---|
| Bellarine (Fenton, first run) | 4.8 | 10.5 | 10.7 | 4.6 | +6.1 |
| Benambra (Hawkins) | 19.6 | 22.0 | 22.4 | 31.7 | -9.3 |
| Brighton (Frederico) | 2.5 | 16.0 | 16.2 | 12.5 | +3.7 |
| Caulfield (Kaltmann) | 4.9 | 11.6 | 11.6 | 6.5 | +5.1 |
| Hawthorn (Lowe) | 5.2 | 16.5 | 17.9 | 20.0 | -2.1 |
| Kew (Torney) | 7.7 | 21.9 | 22.7 | 21.8 | +0.9 |
| Mornington (Lardner) | 8.1 | 23.4 | 24.6 | 23.9 | +0.7 |
| Sandringham (Martin) | 9.2 | 18.1 | 18.1 | 7.2 | +10.9 |
| Mean (n=8) | -8.3 vs actual | | | | +2.0 (SE 2.1) |

The flag moves the average from 8.3 points too low to 2.0 too high, and it is right for Kew, Mornington and Hawthorn. What separates the four over-calls (Sandringham, Bellarine, Caulfield, Brighton) from the four good ones is not in the features I have; I did not find it (unconfirmed). Removing the flag makes the Victorian 2022 independent error worse in RMSE (4.81 to 5.06 points).

### Shepparton 2022 (short)

A sitting independent with own prior 38.4% (won 2014 and 2018): base 38.7, xgb adds +3.1 from own prior, jump and "has won". Actual 29.4. The 2022 Shepparton loss to the Nationals is a single-seat incumbent erosion; nothing in the features can see it.

## 3. What the over-called cells share (counts across Victoria and South Australia)

Independent cells only, contested (published or actual above 0), five elections (vic2014, vic2018, vic2022, sa2022, sa2026), n=220; Victoria alone n=181. Over-call is published minus actual in points; SE is the standard error across cells (each seat appears once per election, so rows are independent seats). Positive = over-called, zero is good. "Base" and "xgb adds" columns show which layer carries it.

| Kind of independent cell | n | Base over | xgb adds | Published over | SE | Mean actual | Median actual |
|---|---|---|---|---|---|---|---|
| New, one candidate, no own prior, no departed leader | 93 | +1.92 | +0.30 | **+2.56** | 0.51 | 4.7 | 2.9 |
| &nbsp;&nbsp;of which Victoria | 75 | +2.40 | +0.43 | **+3.16** | 0.31 | 3.3 | 2.3 |
| New, 2 or more candidates in the class | 52 | -1.48 | +2.27 | +1.16 | 1.13 | 9.8 | 5.2 |
| Same person as last time | 55 | -1.42 | +1.91 | +0.84 | 0.96 | 12.4 | 7.4 |
| Climate 200 or Voices endorsed | 8 | -8.27 | +9.74 | +2.00 | 2.14 | 16.0 | 16.2 |
| Departed class leader (class prior 10 or more), new person | 12 | +5.91 | -0.86 | **+5.65** | 2.67 | 13.1 | 6.5 |
| All contested independent cells | 220 | +0.13 | +1.45 | +1.95 | 0.45 | 8.7 | 4.4 |

Notes on the table:

- "New, one candidate" is over-called in every Victorian election: vic2014 +2.44 (n=32, SE 0.51), vic2018 +4.54 (n=17, SE 0.55), vic2022 +3.16 (n=26, SE 0.48). South Australia shows nothing: sa2022 -0.70 (n=10, SE 4.06), sa2026 +1.02 (n=8, SE 0.93). So this is Victorian, on the small SA sample.
- Share of the Victorian 264-cell independent mean over-call of +1.56 that these 75 cells carry: 75 x 3.16 / 264 = 0.90, i.e. 58%.
- Base alone is roughly right for ALL independent cells together (+0.13) because the over-called new cells are offset by under-called strong cells (same person -1.42, endorsed -8.27, 2+ cands -1.48). The base layer is flat across types. The xgb layer then lifts the strong cells (good) but overshoots them: same person goes from -1.42 to +0.84, endorsed from -8.27 to +2.00, 2+ cands from -1.48 to +1.16. And it barely lowers the new single cells (+0.30).
- The departed-leader cell is the largest single over-call but n=12 and SE 2.67. It is the only one where the base layer is wrong by a full class-vote.
- Selection warning: the nine seats were picked for being the worst, so their cell means overstate the population over-call. The table above is the population, not the nine.
- Multi-candidate classes (OTH_RIGHT, n_cand_now +1.5 to +2.2 each in vic2022) carry extra over-call there: OTH_RIGHT with 2+ candidates in vic2022 +1.21 (n=68, SE 0.36) and n_cand_now is the largest xgb contribution after Climate 200 (mean +0.54 over all Victorian 2022 independent cells, +2.05 on cells with 2 or more candidates). Removing it improves vic2022 independent RMSE (4.81 to 4.56) and worsens South Australia (6.07 to 6.19, mean absolute error 2.78 to 3.08), so it is not a Victoria-wide rule.

## 4. The one proposal

**Lower the base prediction for a nameless, single, first-time independent in Victoria to what such candidates actually get, fitted time-forward with shrinkage.** Land it in `base_pred` (the independent class prior for a cell with no own prior vote and no departed leader), not as an xgb feature.

- Why this and not the others. It is the only mechanism with enough cells (75 in Victoria) and a consistent sign in all three elections (+2.44, +4.54, +3.16) to be measured; a fit using only vic2014 and vic2018 (mean +3.0) would have been available before vic2022 and would have been right to within 0.2. It is a base-layer bias, so it is the one the xgb layer cannot repair (it adds only +0.4 there).
- Test route. Stage 6 via `AUSPOL_XGB_BASE_DELTA=1` (the saved trees are frozen, so a base change reaches the final number additively, `R/xgb_base_delta.R`), with the per-cell delta written from a time-forward fit: shift = shrunk mean of (actual minus base) for earlier Victorian elections, weight tau^2 / (tau^2 + se^2), per class and jurisdiction, so SA, which shows 0, shrinks to about 0.
- Expected effect, from the table: Victorian new single independent cells -2.4 on the base layer (about -2.4 on the published figure given the frozen trees), so the Victorian independent mean over-call falls from +1.56 to about +0.9 (75 cells x 2.4 / 264 = 0.68). On the nine seats it helps only Albert Park Dragwidge by about 2.4 of 14 points; the other eight are other kinds of cell.
- Correctly-called cases at risk: the fix must not touch "same person", endorsed, 2+ candidates or departed-leader cells, which are under-called at base (-1.4, -8.3, -1.5) and use a different rule. Any version that lowers every independent cell would worsen those. I did not test that version.
- Not proposed, with reasons: (a) a Climate 200 feature change (net +2.0, SE 2.1 on 8 cells; the flag helps on average); (b) holding the departed-leader cell fixed, which `docs/reviews/departed-hold-sweep-2026-10-05.md` already measured and refused (fails the actual-weighted share RMSE guard); the Pascoe Vale / Waite / Kavel pattern is this refused arm's population, retention measured 0.13, 0.08, 0.42 against the 0.38 mean, so a per-cell rule keyed on whether the successor has any signal (as `permit` tries to) is the open question; (c) an xgb class-by-jurisdiction calibration, which failed because pooling shrank the Victoria-only effect to about 0.
- This does not remove the nine seats' misses. Even a perfect version of it moves about 2 points in one of them. Pascoe Vale and Waite are departed-leader cells; Sandringham, Bellarine, Ashwood are xgb cells (Climate 200 and `n_cand_now`); Malvern and Albert Park are over-carried minor-class priors in OTH and OTH_RIGHT (class carried from earlier Animal Justice / Sustainable Australia, base +6.2 and +7.1 on their biggest cells), which I did not size across the population.

## 5. Unconfirmed

- The as-at predictions are reloaded here and match `xgb-primary-asat-predictions.csv`. `output/forecasts.csv` (built 2026-10-06 00:42:42) differs from that file on 82 of 857 Victorian/SA 2022 rows, by up to 1.55 points. I used the as-at file because it is what the 21:41 snapshot's stage 6 consumed; I did not find why `forecasts.csv` differs.
- Albert Park Dragwidge gains +2.2 between xgb and the published figure and Kavel OTH_RIGHT gains +2.2. I did not identify the layer (seat-poll blend, port or zeroing). Averaged over all independent cells this stage adds only +0.16.
- Why base_pred gives a nameless independent about 5 to 7 points (the figure for Ashwood, Bellarine, Malvern and Albert Park before xgb is 4.8 to 7.4): I did not read `personal_prior_vote()` and `dev_slope()` line by line to see which term sets it; I read feature columns only.
- Bolton's own background and why `dev_prev` reads 26.8 rather than 32.9 for the Pascoe Vale class: not checked (likely seat-versus-statewide deviation; unconfirmed).
- What the 21 pre-2023 Climate 200 training rows scored, and what distinguishes the four over-called state candidates from the four good ones: not checked.
- Only Victoria (3 elections) and South Australia (2) are in the counts. Federal, NSW, Queensland and WA new single independents were not measured, so whether the bias is Victorian or general is unconfirmed (the earlier review found independent bias Victorian by seat-average, but at the xgb layer, not the base layer).
- The nine seats are selected on the outcome (the worst). The cell-kind table is the unselected population.
- "New, one candidate" is defined from features (`own_prev_pcv` missing, `dev_prev` below 10 or missing, `n_cand_now` 1) and is not a hand-checked list of candidates; some cells with a small own prior (Malvern 0.3%) sit in "same person".
- Contributions are additive points from the ensemble of 3 seeds; interactions between features are inside them. Reading "Climate 200 adds +7.2" is "this feature, given the others", not a counterfactual run.
