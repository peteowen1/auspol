# Greens over-call trace, 2026-10-26 (read-only)

Scripts: scratchpad/grn-trace/{shap,dbg,base,lvl,hi}.R. Saved SHAP table: R.rds (same folder).

## Method / reproduction check
- Models: output/xgb-primary-asat/<pair>.ubj plus -m2, -m3 (seed ensemble K=3, averaged). Features: output/xgb-primary-v6-features.csv (mtime 21 Oct 16:01, models 16:21), columns = feat_cols.txt, base_margin = base_pred (mode 2: base_pred is also a feature).
- Reproduced GRN xgb_pred for all 2,620 forecasts.csv GRN rows: exact (0.0000) for qld2024, fed2025, fed2022; vic2022 max diff 0.68 on some OTHER cell (nomination-zeroed, not checked which). Northcote reproduces 38.0. All five seats match the doc's xgb column (44.1, 48.6, 42.7, 38.0, 25.6).
- SHAP: predict(predcontrib=TRUE) with the margin set; contributions = tree adjustment on top of base_pred (BIAS ~ base_pred). Mean over 3 models. Sum of contributions equals pred - base to 1.1 max (ensemble BIAS differences).

## BASE (additive: base = level_pred + slope*(seat_prev - level_prev))
Points; base_err = base - actual (positive = over-called). actual_level = my own votes/total from candidacies.csv (approx, not the official number). lvl_err = level_pred - actual_level. dev_err = base_err - lvl_err (error in the seat's gap above the statewide level).

| seat | seat_prev | level_prev | level_pred | actual_level | lvl_err | implied slope | base | actual | base_err | of which dev_err |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| South Brisbane qld2024 | 37.9 | 9.5 | 11.9 | 9.9 | +2.0 | 0.94 | 38.7 | 34.7 | +3.9 | +2.0 |
| Melbourne fed2025 | 49.6 | 12.3 | 12.6 | 12.2 | +0.4 | 0.86 | 44.6 | 39.5 | +5.1 | +4.7 |
| Griffith fed2025 | 34.6 | 12.3 | 12.6 | 12.2 | +0.4 | 0.95 | 33.8 | 31.7 | +2.2 | +1.8 |
| Northcote vic2022 | 39.5 | 10.7 | 12.2 | 11.5 | +0.7 | 0.90 | 38.0 | 30.0 | +8.0 | +7.3 |
| Griffith fed2022 (control) | 23.7 | 10.4 | 12.0 | 12.3 | -0.3 | 0.97 | 24.9 | 34.6 | -9.7 | -9.5 |

- Swing is ADDITIVE on the level, slope ~0.86-0.97 (GRN same 0.994 / new 0.880, then renormalised). A statewide level error passes through 1:1, not magnified. Level error matters only in South Brisbane (half of its miss; Qld 2024 Greens level was 2 points over-predicted). In the other three it is under 0.7.
- So the base miss is mostly the seat's own gap above statewide (dev_err) falling back: Melbourne (-10 vs prior), Northcote (-9.5), Griffith 2025 (-3), SB (-3.2). Not a systematic base bias: across all 34 base>30 rows base is UNDER by 0.87 on average (level +1.0 over, dev -1.9 under); regression of actual dev on dev_prev for dev_prev>15 (n=52): slope 0.90 (se 0.12), intercept 3.0 (se 2.9), so slope 1 is not rejected. Base is unbiased on average in strong seats; these four are the idiosyncratic misses.
- Northcote: tree adjustment sums to 0.0, so its +8 is all base. No own_prev (new candidate, same_i=0), GRN new slope 0.88. Why the Greens fell 9.5 below the dev the model carried is NOT confirmed (I did not check candidate history; a prior-election personal/by-election vote is a hypothesis only).
- Melbourne's implied slope 0.856 is lower than 0.994 (renormalisation/other terms in the harness; not traced).
- Could not confirm: the exact harness code path that shrinks Melbourne's slope; actual_level is approximate.

## TREES (top 8 contributions, points; value in brackets; hi = 34 GRN cells with base>30)
Tree adjustment (pred - base): SB +5.4, Melbourne +4.1, Griffith25 +8.8, Northcote 0.0, Griffith22 +0.7.

South Brisbane: own_prev_pcv +3.43 [37.9], historic_elected_i +1.40, same_mp_i +1.24, is_incumbent_party_i +0.94, dev_prev -0.90 [28.4], party_GRN +0.47, level_prev +0.32.
Melbourne 25: own_prev_pcv +3.34 [49.6], dev_prev -2.72 [37.4], jump +1.96 [0.46], same_mp_i +1.17, historic_elected_i +0.90, is_incumbent_party_i +0.88, level_pred -0.35.
Griffith 25: own_prev_pcv +3.64 [34.6], jump +1.60 [0.06], same_mp_i +1.45, historic_elected_i +1.14, ballot_pos_min +0.72, is_incumbent_party_i +0.71, base_pred -0.57, dev_prev -0.41.
Northcote 22: party_GRN +0.70, jump +0.67, dev_prev -0.48, seat_prev_pcv +0.36, base_pred -0.75, n_cand_now -0.24 (all small).
Griffith 22 (control): own_prev_pcv +0.87 [23.7], jump +0.67, is_incumbent_party_i -0.34, base_pred -0.54, ballot_pos_min +0.27.

Typical contribution (mean over the 34 base>30 cells / all 2,620 GRN cells): own_prev_pcv +1.75 / +0.03; historic_elected_i +0.67 / +0.09; jump +0.63 / +0.01; is_incumbent_party_i +0.34 / -0.24; same_mp_i +0.31 / -0.11; dev_prev -0.62 / -0.07. Mean tree adjustment in the 34 cells +3.15 versus actual-minus-base +0.87.

own_prev_pcv is NA for 2,272 of 2,620 GRN cells (candidate with no prior run). By own_prev band (all GRN): 20-30 n=22 contrib +1.16, tree adj +2.84, base residual +2.96 (about right); 30-40 n=12 +2.62, +5.75, +2.65; 40+ n=9 +3.07, +4.76, +1.73. On the 32 cells with own_prev>25: mean base residual +2.26, mean tree adj +4.78, so the trees overshoot by about 2.5 points.

## Verdict
1. Layer: three of four over-calls (South Brisbane, Melbourne, Griffith 2025) are mostly the TREES stacking on a base that was already 2-5 points high; in Griffith 25 the trees add 8.8 points to a base that was only 2.2 over (tree-stage over-call 11.0). Northcote is entirely BASE (trees 0).
2. Driver in the trees: a "returning Green incumbent" bundle: own_prev_pcv + same_mp_i + historic_elected_i + is_incumbent_party_i = +7.0 (SB), +6.3 (Melbourne), +6.9 (Griffith 25). own_prev_pcv alone is +3.3 to +3.6, near its maximum (rule of thumb: ~+3 for any own_prev above 30). Griffith 22 has own_prev 23.7 and gets +0.87, so it is a roughly monotone step in own_prev, not a seat-specific signal. jump adds +1.6 to +2.0 in Melbourne and Griffith 25 (jump also non-zero in Northcote/Griffith 22, so not distinctive).
3. Why wrong: the base already carries incumbency (GRN same/same_mp slope 0.994, i.e. near-full retention of the seat's gap). The trees add an incumbent bonus on top, learned from a handful of strong Green MP seats (Melbourne, Newtown, Balmain, Brunswick, Richmond) that rose through 2010-2022. In 2024/25 those seats fell back; the bonus averages +2.5 too high on the 32 cells with own_prev>25 even over all elections. Counter-term dev_prev (-0.4 to -2.7) mean-reverts only partly.
4. Control: the same story does NOT run inversely. Griffith 2022 was a seat-specific surge (+9.7 vs base) that no tree feature saw (jump 0.02, own_prev small contribution). It is a base miss that is not explainable by the incumbent-bundle, so it does not support the bundle being wrong in a symmetric way; it argues for a surge/salience signal, not a dampener.
5. Not one feature: no single term explains all four. Honest summary: trees (incumbent bundle, own_prev_pcv lead) for 3 seats; base dev fall-back for Northcote and half of Melbourne.

## Candidate fix (not built)
Shrink the tree correction toward the base for GRN cells where own_prev_pcv > ~25-30 (partial pooling by the cell's own precision, no cliff), or drop the redundant incumbency flags (historic_elected_i, is_incumbent_party_i, same_mp_i) from the GRN cell's tree inputs and test; screen with quick_arm on AEF-7 and all 22 time-forward (the earlier 2026-10-24 review found a plain shrink toward base did not lower share error; this isolates the bundle rather than all corrections). Needs the base_pred AND xgb layer test per CLAUDE.md. Not confirmed: n of training rows with own_prev>25 visible to each as-at model (not counted).

## Follow-up: is the sitting-member overshoot general? (2026-10-26, all parties; appended)

Script `scratchpad/inc_overshoot.R` (session e7e809d4): forecasts.csv joined to xgb-primary-v6-features.csv on
pair/seat/party/base/actual (17,010 of 17,010). Overshoot = tree push minus (actual - base), points; SE clustered on
election.

| group | cells | elections | overshoot | SE | elections over |
|---|--:|--:|--:|--:|--:|
| GRN sitting MP, own previous vote 25+ | 21 | 12 | +1.90 | 1.84 | 7 |
| IND sitting MP, 25+ | 60 | 24 | -0.49 | 1.34 | 12 |
| ONP/OTH/OTH_RIGHT sitting MP, 25+ | 15 | 9 | -4.79 | 2.62 | 4 |
| ALP sitting / not | 950 / 1,670 | 30 / 31 | +0.55 / +0.62 | 0.69 / 0.48 | 18 / 20 |
| LNP sitting / not | 914 / 1,706 | 30 / 31 | +0.79 / +0.82 | 0.45 / 0.42 | 20 / 21 |

Reading: not a general sitting-member double count. The Greens case is within 1 SE once clustered. The majors' +0.6 to
+0.8 is the same with or without a sitting MP, so it is the seat-layer majors over-call (renormalisation), which
`AUSPOL_LEVEL_CONSERVE` targets. `own_prev_pcv` is NA for every major-party row.
