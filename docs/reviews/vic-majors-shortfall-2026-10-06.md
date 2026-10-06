# Why the Victorian majors come in about 3 points above the forecast (2026-10-06)

Measurement only. No code in `R/`, `scripts/` or `output/` was changed and no harness was run.
Scripts (scratch, not committed): `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\599330fc-0de9-4609-8538-29a34fc021fd\scratchpad\vicmajors\{a..h}.R`.

## Bottom line

- The gap is NOT one layer. Two things add it, in different elections: the statewide level is too low for the majors in all three (2.2 to 3.9 points), and in vic2022 the seat layer pulls a further 3.2 points off the majors.
- The seat-level xgb correction moves share from the majors to Independents and right-of-centre minors in every Victorian election (ALP -1.9, -0.7, -2.0 points vs base_pred on seat average). Independents are the class that absorbs it: over-called by 1.56 points a seat (SE 0.31, n=264), at every prior-strength, including candidates with no previous result.
- That xgb shift is a general behaviour (ALP down about 1 point in fed, nsw too, where it HELPS). A blanket "undo the shift" does not generalise (section 5). So no safe fix is proven.

## Data and definitions

- `output/forecasts.csv` (`built_at` 2026-10-06 00:42:42, 528 rows per election, 88 seats, all rows have actual and base_pred). Stage-6 published shares: `output/snapshots/20261006-1503-ef0db08-from6/backtest-vic-sharedetail-...a1b7778...csv` (1,672 rows; ONP rows in vic2022 folded into OTH_RIGHT to match forecasts.csv; 0 rows missing after the join, actual shares agree with forecasts.csv except on the 6 seats noted in unconfirmed).
- Signed error = actual minus forecast, in share points; positive = under-called. Seat averages are unweighted means over the 88 seats (vote-weighted statewide was not available per seat).
- "Level" = `output/level-pred.csv` (stage-one statewide share, vic rows). "Audit forecast" = `output/statewide-forecast-audit.csv` (the anchored statewide forecast).
- Layers: `base` = `base_pred`; `xgb raw` = `xgb_pred`, which does NOT sum to 100 (97.4, 97.7, 100.1 per seat on average); `xgb seat` = `xgb_pred_seat`, renormalised to 100; `published` = stage-6 `pred_share` after seat-poll blend, port and zeroing.
- Your quoted +3.07 / +1.23 / +2.69 do not match any layer here. Raw xgb gives +5.54 / +2.40 / +5.30 (these equal the figures in `major-party-error-2026-10-06.md` section 2.3) and published gives +3.79 / +0.71 / +5.39. I could not reproduce the three numbers; see unconfirmed.

## 1. Layer decomposition of the majors' (ALP + LNP) shortfall

Seat-average error of the two majors summed, in share points, actual minus forecast; zero is good, positive means the majors were under-called.

| Layer | vic2014 | vic2018 | vic2022 | Mean |
|---|---|---|---|---|
| Statewide level (level-pred) | +3.86 | +2.23 | +2.16 | +2.75 |
| Audit forecast (anchored statewide) | +1.95 | -0.40 | +0.89 | +0.81 |
| base_pred | +1.99 | -0.66 | +1.99 | +1.11 |
| xgb_pred raw | +5.54 | +2.40 | +5.30 | +4.41 |
| xgb_pred_seat (renormalised) | +3.48 | +0.45 | +5.18 | +3.04 |
| Published (stage 6) | +3.79 | +0.71 | +5.39 | +3.30 |

Reading it: the published error splits exactly into (actual minus level) plus (level minus published seat average).

| Piece | vic2014 | vic2018 | vic2022 |
|---|---|---|---|
| Statewide level miss | +3.86 | +2.23 | +2.16 |
| Seat layer departing from the level (level minus published) | -0.07 | -1.53 | +3.23 |
| Published error | +3.79 | +0.71 | +5.39 |

So: vic2014 is all statewide level; vic2018 the seat layer partly cancels the level miss; vic2022 is level plus a 3.2 point seat-layer drop in the majors. base_pred is the least-biased layer for the majors (mean +1.11); the xgb layer is what moves it to +3.0 (renormalised) or +4.4 (raw). Seat-poll blend, port and zeroing change the majors by 0.0 to 0.3 points (xgb seat to published). Renormalisation is worth 1.5 to 2.4 points of the raw xgb figure in 2014 and 2018, none in 2022.

## 2. Which class takes the share

Mean signed error per seat by class, published shares, points (negative = the class was over-called; SE clustered on seat within an election, n=88 each; pooled row n=264 seats). Zero is good.

| Class | vic2014 | vic2018 | vic2022 | Pooled (se) | Pooled base_pred |
|---|---|---|---|---|---|
| ALP | +1.87 | +3.35 | +1.45 | +2.22 (0.25) | +0.55 |
| LNP | +1.92 | -2.64 | +3.94 | +1.07 (0.31) | +0.56 |
| GRN | -1.47 | -0.58 | +0.47 | -0.53 (0.16) | -1.44 |
| IND | -1.01 | -0.74 | -2.93 | -1.56 (0.31) | -0.15 |
| OTH | +0.08 | +0.12 | -1.80 | -0.53 (0.13) | -0.06 |
| OTH_RIGHT (incl. ONP) | -1.40 | +0.49 | -1.41 | -0.77 (0.16) | +0.45 |

IND is the largest absorber (and the only class that is over-called in all three elections by more than 0.7), then OTH_RIGHT, GRN and OTH about equally. Greens are over-called by base_pred (-1.44) and the xgb layer corrects that; IND and OTH_RIGHT are the reverse, base_pred is about right and the xgb layer makes them worse.

What the xgb seat layer does relative to base_pred (mean over seats of xgb_pred_seat minus base_pred, points):

| Region | ALP | LNP | GRN | IND | OTH | OTH_RIGHT |
|---|---|---|---|---|---|---|
| vic | -1.52 | -0.41 | -0.89 | +1.17 | +0.47 | +1.18 |
| fed | -1.07 | -0.53 | -0.62 | +0.92 | +0.51 | +0.79 |
| qld | +0.34 | -0.02 | -0.98 | +0.60 | +0.54 | -0.48 |

Same direction in fed; there it helps (fed majors error +, base -1.82 to xgb -0.21), in Victoria it overshoots.

## 3. Which seats

Seats ranked by the majors' summed shortfall (actual minus published, points), top 5 per election; n=88 each, spread of the per-seat shortfall (SD) 4.4, 6.5, 4.7.

| Rank | vic2014 | vic2018 | vic2022 |
|---|---|---|---|
| 1 | St Albans +10.7 | Lowan +12.0 | Shepparton +18.6 |
| 2 | Gippsland East +10.0 | Bass +11.6 | Richmond +14.0 |
| 3 | Albert Park +9.8 | Sandringham +10.1 | Nepean +13.9 |
| 4 | Eltham +9.6 | Bentleigh +8.9 | Northcote +13.2 |
| 5 | South-West Coast +9.1 | Melbourne +8.8 | Werribee +13.1 |

Common threads (n per group; SE in brackets; mean shortfall points):

| Group | n seat-elections | Mean shortfall | SE |
|---|---|---|---|
| Held by ALP or LNP last time | 230 | +2.96 | 0.38 |
| No previous result (redistributed, or my seat-name join failed) | 24 | +5.33 | 0.64 |
| Held by the Greens | 6 | +6.03 | 1.39 |
| Held by an independent / other | 4 | +6.68 | 4.20 |

- Not rural-versus-metro: both appear; top lists are mostly Liberal-held eastern and bayside Melbourne seats (Eltham, Bentleigh, Sandringham, Brighton, Kew, Malvern) plus a few country seats. Metro/regional is NOT tested (no field in the registry).
- Strongest correlate in vic2022: the model's own predicted majors share. Seats with the lowest predicted majors share carry the biggest shortfall (+7.70 / +5.41 / +2.98 by tercile; vic2014 +3.4 / +5.1 / +2.8; vic2018 +2.2 / +0.6 / -0.7). Within-election correlation of shortfall with predicted majors: -0.48 in vic2022, -0.15 in vic2018, +0.08 in vic2014. That is, the model gives minors too much where it already gives them a lot. Actual-on-predicted slope of majors total in vic2022 is 0.78 (1.0 is calibrated); vic2014 1.06, vic2018 0.91.
- Candidate count and change in field size vs last time: within-election correlation with shortfall is -0.09 to +0.14 and no consistent sign (seats with 6 or fewer candidates +2.3, with more than 6 about +4.2, partly because fields are bigger in vic2022). Previous Greens or independent share: no stable relation (correlations -0.04 to +0.31).

## 4. Two walked examples (vic2022, the top two)

Columns are class shares in points: base_pred, xgb seat (renormalised), published, actual. Positive final column = under-called.

Shepparton (shortfall +18.6; an independent-held seat, sitting member Suzanna Sheed, 38.4% last time):

| Class | base | xgb seat | published | actual | actual - published |
|---|---|---|---|---|---|
| ALP | 7.6 | 6.6 | 6.0 | 8.0 | +1.9 |
| GRN | 4.9 | 3.0 | 2.0 | 2.6 | +0.5 |
| IND (Sheed) | 38.7 | 41.8 | 42.3 | 29.4 | -12.9 |
| LNP (O'Keeffe) | 37.1 | 35.6 | 36.0 | 52.6 | +16.7 |
| OTH | 3.0 | 3.3 | 3.4 | 1.2 | -2.2 |
| OTH_RIGHT | 8.7 | 9.7 | 10.3 | 6.2 | -4.0 |

The xgb layer raised the incumbent independent from 38.7 to 41.8 (+3.1) and she fell to 29.4. This is a single seat-specific miss, not a systematic mechanism; it is also the whole of an 18.6-point row. base_pred already carried most of it (shortfall 15.9).

Richmond (shortfall +14.0; Greens 34.2% and ALP last time):

| Class | base | xgb seat | published | actual | actual - published |
|---|---|---|---|---|---|
| ALP | 37.9 | 35.2 | 37.6 | 32.8 | -4.8 |
| GRN | 34.6 | 34.1 | 34.7 | 34.7 | 0.0 |
| IND | 9.6 | 9.2 | 9.3 | 1.1 | -8.3 |
| LNP (Moon) | 0.0 | 2.5 | 0.0 | 18.8 | +18.8 |
| OTH | 12.2 | 12.3 | 11.8 | 11.6 | -0.2 |
| OTH_RIGHT | 5.8 | 6.6 | 6.7 | 1.2 | -5.5 |

Here the cause is a Liberal candidate standing for the first time in a seat where the Liberals did not stand in 2018: base_pred gives 0.0 (the class was absent last time), the xgb layer lifted it to 2.5, and the published value is zeroed to 0.0 again. Actual 18.8. The independent and right-of-centre classes, carried forward from 2018, took the share the Liberal would have drawn. Only one such row in the three elections (the only major with base 0.0 who stood): worth 18.8 points on one seat = 0.2 of the 5.39 statewide mean in vic2022, so this is not the systematic cause. Nepean 2022 (rank 3, typical metro: published ALP 29.8, LNP 37.1, IND 9.0, OTH_RIGHT 8.3 vs actual 32.6, 48.1, 2.5, 4.9) shows the common pattern: IND -6.5, OTH_RIGHT -3.4, OTH -2.4 absorbed the LNP gain of +11.0.

## 5. Mechanism checks

1. Nomination zeroing (class standing now vs last time). Every class row with no candidate (`n_candidates` missing: 247 rows) has published share 0.00 on average 0.03 to 0.22, and exactly one row each of OTH, IND, OTH_RIGHT, GRN, LNP in vic2022 has a nonzero share with no candidate recorded, and each of those five also has a nonzero actual (the seat-name join fails for one seat in vic2022, so the candidate record is missing, not the class zeroed). No row with a candidate recorded has an actual of zero. Zeroing is complete in the as-at table for Victoria; this is not the mechanism.
2. Micro-party fields. Per candidate, single-candidate classes are over-called most: IND with 1 candidate predicted 7.9 vs actual 4.4 (n=99), OTH 4.5 vs 3.0 (n=97), OTH_RIGHT 4.7 vs 3.5 (n=74); with 3 or more candidates the per-candidate error is about 0 or positive. The over-call lies in the single, named, usually well-known candidate, not in crowded fields.
3. Independents by previous share (published error, points, negative = over-called): none last time -1.64 (n=114, se 0.37), 0 to 5 -0.66 (n=93), 5 to 15 -3.07 (n=41, se 0.59), over 15 -2.35 (n=15, se 1.92). In vic2022 all four are -2.4 to -3.1. The over-call is not confined to sitting independents, and is largest for mid-strength ones.
4. Greens trajectory. Greens are over-called in base_pred (-1.44) and the xgb layer fixes it to -0.53 pooled; vic2022 is +0.47. Not a cause.
5. Is the pattern Victorian? IND mean error (xgb seat) by region: vic -1.32, fed +0.35, nsw +0.34, qld -0.11, sa -0.03, wa +0.08. Yes, IND over-call is Victorian in this table. By election within Victoria, base_pred gets IND nearly right (-0.14, +0.25, -0.55) and the xgb layer takes it to -0.67, -0.49, -2.76.
6. Redistributed seats: the no-previous-result group shortfall is +5.33 vs +2.96 (24 vs 230 seat-elections); partly my join, see unconfirmed.

## 6. Proposal (one), and why it is not yet safe

Proposed arm: an independent-class calibration inside the xgb layer, `IND_final = base_IND + w * (xgb_IND - base_IND)` with `w` fitted time-forward on earlier elections and shrunk toward 1 for jurisdictions with little history; the freed share goes back to ALP and LNP in proportion to their predicted shares. Where: after the as-at xgb prediction in `R/xgb_primary_override.R`, in `xgb_primary_predict_live()` for the published forecast and in the as-at table builder for the backtests, so it reaches the xgb layer; it does not touch `base_pred`, which is already about right for IND.

Expected size, upper bound if the IND over-call were removed completely: vic2022 majors error 5.39 to about 2.5; pooled Victoria mean 3.30 to about 1.7. Live vic2026: not estimable here. The live seat averages (`seat-primary-ranges-vic-2026-ind.csv`) have ONP at 20.9% and majors at 54.0%, a different regime from 2014-2022, and I did not compare them to a live statewide level.

Why it is a proposal, not evidence: I tested the cruder version, "rake each class's seat average back to its base_pred average" (not time-forward, computed with the same pipeline numbers): vic2022 majors error falls to +2.31 and squared error to 14.2 from 17.5, but across all 18 elections squared error rises by 0.22 on average (se 0.32, better in 7 of 18). Worst: wa2025 +2.5, qld2024 +2.2, fed2013 +2.1. The general xgb shift is useful elsewhere, so a Victoria-only correction is the only thing the Victoria evidence supports, and the earlier review showed per-jurisdiction scales collapse to the pooled one at 3 elections. So the arm must be pre-registered and scored on all 18, with the IND-only change measured separately; Victoria's 3 elections cannot carry it alone.

## 7. Unconfirmed

- Your +3.07 / +1.23 / +2.69 (the others-scale review's "before bucket scale" numbers) could not be reproduced from any of the layers above; I did not open the arm that produced them.
- Which of level-pred or the audit forecast feeds `state_mean` and the xgb `base_margin` in the as-at tables was not checked (level-pred is 1.5 to 2.9 points lower for the majors than the audit forecast). The level row is therefore not confirmed as the layer the seat model starts from.
- Statewide numbers here are unweighted seat averages, not enrolment-weighted. Actual statewide vs seat-average differ by up to 0.2 points (audit actual vs seat-average actual).
- Candidate/prior-result joins use `candidacies.csv` by exact seat name; 24 seat-elections (vic2022 mostly) had no join and sit in "no previous result". `n_candidates` is missing for one seat-election row of each class in vic2022 (one seat's name did not match); that seat was not examined.
- The vic2022 Richmond Liberal is reported from base_pred 0.0 and candidate name; I did not check 2018 nominations in `candidacies.csv` directly.
- `snapshots/...from6` sharedetail actual shares differ from forecasts.csv by up to 6.1 points on 6 rows (maximum absolute difference over all joined rows); I used forecasts.csv actuals everywhere.
- "Metro versus regional" is untested; no field exists.
- Live vic2026 effect of the proposal, the ONP regime, and whether the xgb shift behaves the same with ONP rows present, are untested.
- Standard errors for the pooled rows cluster on seat-election (no seat repeated within an election); 3 elections cannot give a trustworthy between-election SE and I did not claim one.

## Follow-up (2026-10-06): class-by-jurisdiction calibration built, not run

Branch `worktree-agent-a6d092f16127ab44a` (`d2c47c2`, unmerged): `AUSPOL_XGB_CLASS_JUR_CAL` (off), a
time-forward, shrunk post-xgb shift per (jurisdiction, class), wired at all three xgb paths, switch-0
byte-identical. Dry run on the published as-at table (an estimate, not a rebuild): mean squared error
+0.29 points^2 (SE 0.15); 11 of 18 elections shifted, only fed2022 better (-0.76), qld2024 +2.07,
fed2025 +1.38, fed2019 +0.95, nsw2023 +0.77; Victoria flat (vic2018 +0.03, vic2022 +0.08). Pooling
across jurisdictions shrinks the Victoria-only IND bias to ~0 (tau^2 0.02 at vic2022, 0 at vic2026), and
the shifts that fire (ALP, GRN, ONP) are taken back off the Coalition by renormalisation. Not run as an
arm. The Victorian majors shortfall stays open: what remains is the statewide level (calibrated noise)
and a per-seat IND over-call no pooled correction isolates.
