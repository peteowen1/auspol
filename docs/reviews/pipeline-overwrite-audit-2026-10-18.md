# Pipeline overwrite audit, 2026-10-18

Read-only static audit. Question: where is work done by one step later overwritten,
replaced, ignored or applied twice by another, so which logic actually reaches the
published numbers. No R was run; every claim below is from reading the code on disk
(HEAD `c560620`, working tree clean when checked) or from files already in `output/`.
Anything I could not confirm from code is marked **UNVERIFIED** with where I looked.

How to read the labels: (a) value computed then replaced, (b) adjustment undone by a
later renormalisation or clamp, (c) the same correction applied twice, (d) computed but
never read, (e) published path and backtest path differ, (f) a switch read in one place
and cancelled elsewhere. "Vic" means the published Victorian forecast
(`scripts/fit_seats_full.R`).

---

## Part 1. Share-flow maps

### 1A. Published path: `scripts/fit_seats_full.R` (execution order)

The seat x class share matrix is `mat22` (the 2022 baseline), then `shares`.
"Fate" says whether a later step keeps, rescales, replaces or ignores what the step wrote.

| # | Step | file:line | Switch = shipped value | Reads / writes | Fate downstream |
|---|---|---|---|---|---|
| 1 | Baseline `mat22` from VEC 2022 first prefs (+ Narracan supplementary), rows to 100 | fit_seats_full.R:357-358 | none | writes `mat22` | modified by 5, 6, 7 |
| 2 | Statewide prior `a22` (vote-weighted raw 2022 share) | fit_seats_full.R:359 | none | writes `a22` | **never updated** after 5-7, see F11 |
| 3 | Trend, projection, `state_mean` (rescaled to 100) | fit_seats_full.R:457-625 (`state_mean` 612/621) | LIVE_LEVEL_ANCHOR=0, LEVEL_RECIPE=live | writes `state_mean`, `pj` | `state_mean` drives 8 and xgb features; `pj` mean is cancelled, see F14 |
| 4 | `level_recent_apply`: pull ALP/LNP/GRN level toward recent polls | fit_seats_full.R:627 | LEVEL_RECENT=decay | rewrites `state_mean` | feeds 8 and live xgb `level_pred`; NOT in training `level_pred`, see F12 |
| 5 | By-election prior blended into `mat22` (half weight) | fit_seats_full.R:1002 | BYELECTION_PRIOR=blend | rewrites `mat22` rows | `a22` not updated; `.own_prev` computed before it (line 983) |
| 6 | `remove_transferred_votes(mat22, .own_prev)` | fit_seats_full.R:1008 | none | moves a returning person's vote between classes | feeds xgb `seat_prev_pcv` (not how training defined it), see F11 |
| 7 | Departed-origin routing | fit_seats_full.R:1009-1026 | DEPARTED_ORIGIN=0 | off | none |
| 8 | `dev_slope` per class (screened slopes, MP tier, major slopes, departed decay, successor hold) | fit_seats_full.R:1215-1247 (loop 1218) | DEV_SLOPE_MODE=screened, HONOUR_DEPARTED=1, MAJOR_DEPARTED=1, MAJOR_SLOPE=1, DEPARTED_SUCCESSOR=1 (forces hold on, line ~875) | writes `shares` for every class except ONP | ONP overwritten by 9; everything else becomes xgb `base_margin` |
| 9 | One Nation: `onp_target = state ONP x onp_ratio`, other classes scaled to fill | fit_seats_full.R:1288-1304 | ONP_FIX=1, ONP_CV=0.365 | **overwrites** the ONP column | passed to xgb as base only; any ONP re-entry fill (1261) is overwritten (the log says so) |
| 10 | Re-entry prior, post-swing fill | fit_seats_full.R:1255-1264 | REENTRY=majors | writes fill cells | rescaled by 9 |
| 11 | `new_ind_shrink_apply` | fit_seats_full.R:1329 | NEW_IND_SHRINK=1 | lowers nameless first-time sole IND; freed share pro rata | base for xgb. Post-xgb switch: trees never trained on it, rely on `base_margin` pass-through |
| 12 | **xgb live**: `xgb_primary_predict_live` | fit_seats_full.R:1333; R/xgb_primary_override.R:225-451 | XGB_PRIMARY_LIVE=1, BASE_MARGIN=2 | takes `shares` as `base_margin` AND `base_pred` feature; **replaces every cell** with margin + trees; rows rescaled to 100 | everything before is only a starting point |
| 13 | `ind_person_apply(stage="final")` | fit_seats_full.R:1345; R/ind_person.R:150-190 | IND_PERSON=final, DIR=lower | **sets** a person-matched IND cell to carry x record when that is lower than the xgb value | overwrites the xgb value by design |
| 14 | `seat_swing_port_apply` | fit_seats_full.R:1353; R/seat_swing_port.R:219-234 | SEAT_SWING_PORT=2 | ALP +adj, LNP -adj (row sum preserved) | fed_swing is also an xgb feature, see F8 |
| 15 | `seat_poll_blend_apply` | fit_seats_full.R:1361; R/seat_poll_blend.R:624-712 | SEAT_POLL_BLEND=1, IND_WEIGHT=1; PRECISION/FIRM_FLOOR/GROUPS/SIZEVAR/ALLPOLLS/SPLIT_ALL all 0 | pulls polled cells by `w` (0.461 for Vic), whole row rescaled (709) | for Vic touches ONE cell, see F6 |
| 16 | `demographic_residual_apply` (ALP, GRN) | fit_seats_full.R:1370; R/demographic_residual.R:204-329 | DEMO_RESID=2 | adds adj, then whole-row rescale to original total (316) | attenuated ~40% on ALP, see F7 |
| 17 | `leader_seat_apply` | fit_seats_full.R:1381; R/leader_seat.R | LEADER_SEAT=1 | `.shift_cell` (exact, row total preserved) | applied after the poll blend |
| 18 | `departed_fed_apply` | fit_seats_full.R:1387 | DEPARTED_FED=0 | off | none |
| 19 | `blend_salience_shares` | fit_seats_full.R:1401; R/salience_surge.R:394-440 | SALIENCE_BLEND=1 | `(1-p)x + p*mu`, row rescaled | inert for Vic until the salience corpus exists (nominations close 9 Nov); see F5 |
| 20 | `zero_unnominated_live` | fit_seats_full.R:1419 | NOM_ZERO=2, NOM_ZERO_ORDER=late, NOM_LIVE=auto | zeroes classes with no candidate | no-op until a nomination list exists (UNVERIFIED which mode `auto` picks; not read) |
| 21 | Statewide draws: per-party normal(state_mean, sd), renormalise, shift ALP/LNP so two-party = `target` per draw, renormalise | fit_seats_full.R:1508-1572 | PARTY_COR=off, FP_SD_MODE=additive (FP_EXTRA_SD 2.419, line 163) | writes `sw_draws` | simulator subtracts the column means, so only the SPREAD survives, see F14 |
| 22 | Flows: `xgb_flow_conditional_override_for(shares)` then `htv_flow_override` | fit_seats_full.R:1716-1725 | XGB_FLOWS=1, HTV_FLOW=1 | per-seat conditional rows | HTV overwrites the xgb ALP:GRN split on LNP-excluded rows, see F13 |
| 23 | `simulate_seat_contests`: `level_sd` x size factor x composition factor (`size_sd_apply`), empirical error z, surge draw, count, 1% shrink | fit_seats_full.R:1730; R/seat_sim.R:1029-1500; R/size_sd.R:99-140 | SIZE_SD=1, COMPOSITION_SD=1, ERROR_DIST=1, SHRINK=0.01, SURGE_H=0 (hazard overrides when corpus exists) | win probabilities | final |

### 1B. Federal harness: `scripts/backtest_candidate_fed.R` (execution order)

| # | Step | line | Gate | Difference from published |
|---|---|---|---|---|
| 1 | Forecast statewide, `level_recent_apply` | 1345-1348 | FORECAST_MODE | live uses `trend_as_at` + the same blend; training `level_pred` has no blend |
| 2 | `dev_slope` per class (own-prev, slopes) | 1415-1425 | screened | same code, but `.defect` is **fitted** (783-800) vs frozen 0.282 live, see F3 |
| 3 | Re-entry fill | 1443 | REENTRY=majors | same |
| 4 | Zero IND where none nominated (oracle) | 1465 | `!FORECAST_MODE` only | not used in forecast mode |
| 5 | Departed-hold renorm | 1473 | | same |
| 6 | `new_ind_shrink_apply` | 1481 | | same position |
| 7 | `ind_typical`/`ind_person` base, `xgb_primary_override` (cached as-at predictions + BASE_DELTA re-prediction), `ind_typical`/`ind_person` final, `ind_mixture` | 1484-1489 | | the xgb step is a **cache lookup**, not the live trees |
| 8 | `state_poll_pool_apply`, `seat_poll_blend_apply` | 1496-1499 | only if XGB_PRIMARY=1 | state pool is federal-only |
| 9 | education (off), `demographic_residual_apply`, `leader_seat_apply`, `state_deviation_apply` | 1507-1545 | only if XGB_PRIMARY=1 | state deviation is federal-only |
| 10 | `zero_unnominated` | 1550 | NOM_ZERO | NOT gated by XGB_PRIMARY, so it is in stage-1 `base_pred` |
| 11 | `blend_salience_shares` in the simulation loop | 1789 | surge-v2 only, **not gated by XGB_PRIMARY** | in stage-1 `base_pred`, see F5 |
| 12 | `zero_unnominated_at("late")` | 1829 | | second zeroing |
| 13 | Simulate with `statewide_draws = X$sw_draws` | 1884 | | the federal harness matches the published construction; the other six do not, see F4 |
| 14 | `seat_share_rmse(X$shares)` -> sharedetail | 1936-1941 | | `pred_share` = final shares after steps 8-12 |

### 1C. Rebuild stages and who reads what (`scripts/rebuild_forecasts.sh`)

| Stage | Output | Read later by | Stale-input risk |
|---|---|---|---|
| 1 (xgb off; REENTRY, NEW_IND_SHRINK, DEPARTED_SUCCESSOR, IND_PERSON, LEVEL_RECENT forced to 0) line 239 | `sharedetail` `pred_share` = `base_pred` | stage 2 pool, stage 3 features | includes salience blend and nomination zeroing, see F5 |
| 3 `build_level_pred.R` -> `level-pred.csv` | `level_pred` training feature | stage 4, 5 | uses `forecast_statewide_for` (no level_recent) |
| 4 / 5 as-at and final xgb models | `xgb-primary-asat-predictions.csv` | stage 6 harnesses; **every post-xgb correction table** (seat-poll weight, IND weight, demographic, leader bonus, state pool) via `current_seat_predictions()` (R/seat_predictions.R:16-21) | those tables are fitted to a prediction that is not what they are applied to, see F8 |
| 5b `level-recent.csv` (line 252) | level blend constants | stage 6, live | built after stages 3-5 |
| 6 harnesses | sharedetail, allprobs | stage 7 | reads stage-7 spread tables from the PREVIOUS run (handled by the SPZ rerun, lines ~305-330) |
| 7 spread tables `spread-by-size`, `spread-by-composition`, `error-quantiles` | read by stage 6 and live | | refit from stage-6 shares; the rerun guard compares table contents, so this one is handled |
| 9 promote | shipped `seat-poll-blend`, `demo-resid`, `leader-seat`, `seat-swing-port`, models | daily CI (`.github/workflows/forecast.yaml:169-217`) | live numbers use tables frozen at promote time, see F17 |

---

## Part 2. Findings

Each finding gives the two code locations and the value lost or doubled.

### F1 (e) Live xgb is served a different statewide level than it was trained on, for 3 of 7 classes. HIGH for Vic.

* Serving: `R/xgb_primary_override.R:271` sets `level_pred := state_mean[[party]]` and falls back to **0** for any class not in `state_mean`.
* `state_mean` has five names only. Proof: `output/statewide-level-vic-2026.csv` (written at fit_seats_full.R:~660) holds LNP 28.95, ALP 24.57, GRN 13.55, ONP 21.45, OTH 11.47. No IND, no OTH_RIGHT, and OTH is the whole others bucket.
* Training: `scripts/build_level_pred.R:85` (`forecast_statewide_for` over IND, OTH, OTH_RIGHT too). `output/level-pred.csv` for vic2022: IND 6.84, OTH 6.34, OTH_RIGHT 6.09.
* So live IND `level_pred` is 0 (trained on about 7), OTH_RIGHT 0 (about 6), OTH 11.5 (about 6). `dev_prev` and the level change the trees see are wrong for exactly the classes with the largest errors (IND share RMSE about 7.2).
* The comment at R/xgb_primary_override.R:272-278 says training and serving "finally agree". They do not for these classes.
* The backtests cannot see it: the harnesses read the cached as-at predictions built from `level-pred.csv`, never the live feature builder. The draws do handle the bucket (`DRAW_BUCKET_FIX`, fit_seats_full.R:1485-1492), so someone knew the bucket matters; the xgb path was missed.
* Size: UNVERIFIED (needs a live run comparing IND/OTH cells with `level_pred` set from the bucket split). Direction: IND, OTH_RIGHT cells likely pushed down, OTH up.

### F2 (e/f) `AUSPOL_MINOR_DEFECT_BASE_PRED=1` is shipped but the published script never reads it. MEDIUM-HIGH for Vic.

* Shipped: `scripts/published_flags.R:271` ("SHIPPED 2026-09-18, reaching base_pred"). Read by all seven harnesses (fed:820, vic:535 and the others; `grep -c` = 1 each).
* Published: `scripts/fit_seats_full.R:983-984` builds `.own_prev` with `major_discount` only; the comment at lines 977-982 says the arm "was REFUSED ... base_pred stays byte-identical". That comment predates the 2026-09-18 ship.
* Only `.own_prev_xgb` (line 993) carries the minor discount, so for a minor-to-minor switcher the live xgb `own_prev_pcv` **feature** is discounted while the `base_margin` is not. Training (stage 1 under published flags) had both discounted.
* fit_seats_full.R:939-944 names five Vic cases (Frankston, Broadmeadows, Lara, Werribee, Sydenham). Whether each is a sitting member (no discount) or not (about 0.276): UNVERIFIED.
* `docs/MODEL-REGISTRY.md:126` shows "yes" for fit_seats because the generator matches the name in a comment. The registry cannot find this class of gap (see F20).

### F3 (e) Defector discount: published uses a frozen 0.282; every harness fits it. MEDIUM for Vic.

* Published: `scripts/fit_seats_full.R:932` `.defect <- 0.282`.
* Harness: `scripts/backtest_candidate_vic.R:502` calls `fit_defector_discount(.eb)`; `R/candidate_returns.R:1117-1127` documents 0.282 as "a frozen snapshot ... never refreshed" that this function replaced.
* The fitted version also carries DEFECT_POOLED=2, DEFECT_BY_LEVEL=2, DEFECT_CONSERVE=1 (published_flags.R:214-229, read inside R/candidate_returns.R). fit_seats_full.R mentions none of them (`grep -c` = 0). Registry shows `AUSPOL_DEFECT_POOLED` as NO everywhere because it is read inside `R/`.
* Value lost: whatever `fit_defector_discount("vic2026")` returns minus 0.282, on any major-party MP re-standing as an independent. Number: UNVERIFIED (not run).

### F4 (e) Six of seven harnesses score a different statewide spread than ships. HIGH for backtest calibration.

* Published: `fit_seats_full.R:1508-1572` builds `sw_draws` from per-party `state_sd = sqrt(trend_sd^2 + 2.419^2)` (lines 163, 571) and forces the two-party result to a projected distribution, then passes `statewide_draws = sw_draws`.
* Federal harness: `backtest_candidate_fed.R:1026,1884` passes `statewide_draws = X$sw_draws`. Same construction.
* vic, nsw, qld, sa, wa, nt: `grep -c statewide_draws` = 0 in every file. They pass `party_sd = psd` where `psd` is a flat `AUSPOL_PARTY_SD` default 1.5 (vic:853, nsw:960, qld:944, sa:1123, wa:711, nt:741), independent per party, no anchoring.
* The harness's own comment (vic:845-852) records that the realised statewide sd is 2.33, so 1.5 is 1.6x too tight, and says fit_seats_full uses a per-party sd. `R/forecast_mode.R:9` still says "No harness does", which is stale for federal.
* Effect: seat log loss and calibration for 16 of 23 pairs (all of AEF-7 except fed2022 and fed2025) describe a tighter statewide swing than the published forecast. Size: UNVERIFIED. The statewide shift is common to every seat, so it moves seat correlation and tail probabilities most.
* Related: with `PARTY_COR=off` the published path's correlation comes only from renormalisation and the ALP/LNP shift (lines 1518, 1569-1571); the harnesses have none.

### F5 (c/e) The salience point blend is in the training base, then applied again after the trees. MEDIUM-HIGH for Vic from 9 Nov, and for every salience backtest.

* Gated steps (so stage-1 `base_pred` excludes them): vic:779-786, fed:1496-1498, 1519, 1525, 1536, each with the comment "at stage 1 it would enter base_pred and count twice".
* NOT gated: `blend_salience_shares` (vic:900, fed:1789) and nomination zeroing (fed:1550, 1829). Stage-1 `sharedetail` `pred_share` is `X$shares` at the end (fed:1936-1941), so `base_pred` (scripts/fit_xgb_primary_v6.R:313) includes the blend.
* Stage 6: the cached xgb prediction (trees on a base that already includes the pull) then gets `blend_salience_shares` again (vic:900). `xgb_base_ref_write(shares)` records the reference at the xgb call point, BEFORE the blend (R/xgb_primary_override.R:45), and `base_new <- base_old + delta` (R/xgb_base_delta.R:172) keeps the training-time pull inside `base_old`. So the harness pulls twice.
* Live: `base_margin` is pre-blend (fit_seats_full.R:1333), blend once after the trees (1401). So live and backtest differ, and the live trees see a `base_pred` lower than they were trained on for those cells.
* Third copy of the same hazard: the xgb features `jump`, `governed`, `permit`, `surge_h`, `is_recipient` (R/xgb_primary_override.R, feature list in `output/xgb-primary-v6-final-cols.json`), and the simulator draw (`surge_h`, seat_sim.R:1470-1500). ARCHITECTURE.md already documents the blend-plus-draw pair as a measured double count that was kept; it does not mention the trees or the training base.
* Inert for Vic today (no corpus, `.hz` NULL, line 1084), so the published forecast will change structurally on 9 Nov when the hazard switches on. Size: affects cells with `p_hat > 0.001` only. UNVERIFIED.

### F6 (a/f) Seat-poll blend: IND override discards MRP; and for Vic the whole quality machinery is inert. MEDIUM.

* Override: `R/seat_poll_blend.R:660-668`. `tb$poll[ik$row] <- ik$poll` replaces the all-poll weighted cell with the direct-only mean (`.ind_direct_cells`, line 1033); `wvec[ik$row] <- w$w_ind`. MRP polls never vote on an IND cell that has a direct poll, so MRP and per-group floors never touch it. The matching `w_ind` is fitted on direct polls only (line 1060 on), so fit and use agree; the loss is the MRP information.
* Floors and decay only set RELATIVE weights between polls in one cell (`.seat_poll_cell_weights`, line 310: `0.5^(days/H) / (sv + floor)` inside a weighted mean). The pull size is `w` (class-blind) or `w_ind`, independent of age or precision, because `PRECISION_BLEND=0` (published_flags.R:679).
* Vic proof: `output/seat-poll-blend-vic2026.csv` holds ONE cell, Hawthorn LNP direct 41, n_polls 1, `wsum` 3.1e-06. The source row (`external/reference/polls/seat-polls/seat_polls.csv`) is Freshwater, client "Liberal Party", fieldwork 14-16 Aug 2025, n=1147, so about 14 months before the election. With one poll in the cell the floors, decay and sponsor groups change nothing, and that stale party-commissioned poll pulls the LNP cell 46% of the way to 41 (`w` = 0.461).
* Dead work under the shipped mode (d): `seat_poll_weights_split` (called unconditionally at seat_poll_blend.R:557-558; `w_direct`/`w_mrp` only read in mode 2), `vm` (precision blend off), `firm_mult` (line 411; FIRM_FLOOR off). Computed, written to the shipped table, never read.

### F7 (b) Demographic correction is partly renormalised away. MEDIUM.

* `R/demographic_residual.R:298` adds adj to ALP and GRN; line 316 (and 233 for the cached path) rescales the WHOLE row to the original total, so the corrected cells shrink along with everyone else.
* Delivered ALP change for adj `a` on a cell of share `A` with GRN adj `g`: `(100a - A(a+g)) / (100 + a + g)`. With A = 40 and g = 0 that is 60% of `a`. GRN (share about 12) keeps about 88%.
* The elastic net was fitted to the raw cell residual (line 83), so the fit assumes full delivery. Compare `R/leader_seat.R` `.shift_cell`, written because the same whole-row rescale handed back only part of the leader bonus (comment above it: +2.45 kept +1.32).
* Magnitude from `output/demo-resid-vic2026.csv`: mean |adj| ALP 0.47, GRN 0.39 points (max 1.42 and 2.38). So the loss is about 0.2 points on an average ALP cell. Small, systematic, and cheap to fix. (`seat_swing_port` is symmetric, +adj/-adj, so it is not affected.)

### F8 (c) Post-xgb corrections are fitted to raw xgb residuals and stacked. MEDIUM.

* All of these fit on `actual - xgb_pred_seat` from the stage-4 as-at file, via `current_seat_predictions()` (R/seat_predictions.R:16-21): seat-poll weight (seat_poll_blend.R:488, 350, 247), IND weight (1062), demographic (demographic_residual.R:129), leader bonus (leader_seat.R:90). The swing port fits on TPP swing (seat_swing_port.R:1-40).
* They are applied to shares that have since changed: `new_ind_shrink` (IND), `ind_person` (IND), re-entry (majors), `level_recent` (ALP/LNP/GRN), departed-successor hold. None of those is in `xgb_pred_seat`, so e.g. the poll weight `w` is regressed on a gap (`poll - pred`) larger than the gap left after the port and IND steps.
* Sequential overlap, each fitted without removing the previous: `fed_swing` is an xgb feature (`xgb-primary-v6-final-cols.json`) AND the port re-applies federal swing (fit_seats_full.R:1353); the port (ALP/LNP), the demographic ALP correction and the poll pull all chase the same ALP seat residual; the leader bonus and demographic step are applied AFTER the poll blend (lines 1361, 1370, 1381), so a polled seat is pulled to its poll and then corrected again on top.
* Partial protection: leader bonus and demographic fits demean within election (`r - median(r)`; z-scored features), which removes the level part. The seat-specific double count is what remains. Size: UNVERIFIED; the shipped ledger measured the stack as a whole, so the net is calibrated, but the parts are not separately identified.

### F9 (c) Tail widening is applied by four devices fitted separately. MEDIUM.

* `fit_error_distribution.R:35` standardises errors by `sdm x size_f` only. The sim multiplies the same z by `sdm x size_f x composition_f` (R/size_sd.R:111,136; seat_sim.R:1441). Composition heteroscedasticity (IND-heavy seats) is therefore inside the z tails AND in the factor.
* z is rescaled to RMS 1 over all cells, so low-composition seats are drawn too wide relative to their own error and high-composition seats get both.
* Other layers on the same tail: `level_sd` (a + b sqrt(p(1-p))), size factor, 1% `shrink`, surge draw. ARCHITECTURE.md's own falsifiable prediction ("if per-cell variance is right, best shrink goes to zero") has not been re-run since SIZE, COMPOSITION and ERROR_DIST shipped (10-14 to 10-17): I found no re-sweep in `docs/NEXT-STEPS.md` or the two 10-17 preregs (grep). UNVERIFIED beyond that grep.

### F10 (e) Sitting-member slope table differs. LOW-MEDIUM.

* Published: `fit_seats_full.R:917-924` reads `output/mp-slope-by-class.csv` (pooled, no shrinkage, `n_member >= 8` cliff, GRN dropped): IND 0.939, OTH_RIGHT 0.960.
* Harnesses: `AUSPOL_MP_SLOPE_FILE` default `output/mp-slope-by-target.csv` (vic:481): time-forward and shrunk; for vic2022 IND 0.946, OTH_RIGHT 1.000, GRN 1.05. The published flags state the harness table is the shipped one (published_flags.R:716).
* A `vic2026` row does not exist (the panel holds completed elections), which is probably why live used the by-class file. Difference is small today; it is a cliff that CLAUDE.md says should be shrinkage.

### F11 (e) Live xgb features are built from a modified baseline; training used the raw one. LOW-MEDIUM.

* Serving `seat_prev_pcv := mat22[s,p]` (R/xgb_primary_override.R:269): `mat22` after the by-election half-blend (fit_seats_full.R:1002) and transferred-vote removal (1008).
* Training: `fit_xgb_primary_v6.R:172` takes raw candidacy `pcv` from the previous general election.
* `a22` (fit_seats_full.R:359) is never recomputed after those edits, so `level_prev` and `dev_slope`'s `level_prev` describe the raw table while the seats are the edited one. The harnesses do the same (vic:560 after `sa` at ~412), so this is parity, not a gap; effect is a few hundredths of a point of statewide level.

### F12 (e) `level_recent` reaches live `level_pred`, not training `level_pred`. LOW-MEDIUM.

* `level_recent_apply` is called only in `forecast_statewide_or_oracle` (R/forecast_statewide.R:381), the fed harness (fed:1348) and fit_seats_full.R:627. `build_level_pred.R:85` calls `forecast_statewide_for`, which does not. Training and the cached stage-6 features therefore have no blend; live `level_pred` (R/xgb_primary_override.R:271) has it.
* Size depends on the fitted blend weight (UNVERIFIED; `level-recent.csv` constants not evaluated). Its shift on ALP/LNP/GRN is exactly what the trees' `level_pred - level_prev` reads.

### F13 (a) How-to-vote override replaces the xgb flow model's ALP:GRN split. MEDIUM when it fires; inert for vic2026 today.

* `fit_seats_full.R:1718-1725`: xgb flow rows first, then `htv_flow_override`. `R/htv_flow.R:123-131` rewrites ALP and GRN on every `LNP|...` key to `tot * share`, one fitted scalar per card order, keeping only the total.
* The HTV gain was measured "base_pred-only" (published_flags.R:158-164: 2CP error 6.19 -> 5.08, log loss 0.2945 -> 0.2938), before the xgb flow rows existed. Whether HTV still adds anything on top of seat-specific xgb flows: UNVERIFIED (not found in the docs I read).
* `htv_flow_override` copies the `sd` attribute through (htv_flow.R:134), so the flow sd now describes values that were replaced.

### F14 (d/f) The statewide MEAN machinery is cancelled; only the SPREAD survives. MEDIUM (understanding, not a bug).

* R/seat_sim.R:1029 `centre <- colMeans(statewide_draws)`; 1232 and 1409 apply `statewide_draws - centre`. So the draws' mean never moves a seat. Everything that shifts the mean is erased: the ALP/LNP shift `d` mean (fit_seats_full.R:1551-1572), `pj$mean`, `AUSPOL_ANCHOR_IMPLIED`, `AUSPOL_ANCHOR_EXHAUST`, `AUSPOL_CLOSE_PROPORTIONAL` (when it only changes draws), `AUSPOL_FLOW_SHIFT` (the comment at fit_seats_full.R:~190 already admits this one).
* What survives: `pj$sd` (fixes the two-party spread through `target`, line 1551) and the per-party sds. Seat means come only from `state_mean` through `dev_slope` and the xgb features. So the fundamentals projection's mean (`fund_now`, `mix`, `days_out`) contributes nothing to the seat means in the published path; it matters only through `pj$sd`.
* This is consistent with LEVEL_RECIPE=live and LIVE_LEVEL_ANCHOR=0 (published_flags.R:661, 739), so I do not rate it a defect. It does mean a switch such as `AUSPOL_ANCHOR_IMPLIED=1` can look inert for a structural reason.

### F15 (a) Deliberate overwrites worth knowing about (design, not defects).

* ONP: `fit_seats_full.R:1304` overwrites the ONP column; `dev_slope` excludes ONP (1218) and any re-entry fill for ONP is overwritten (the log line says so). The result is only a `base_margin` for xgb.
* `ind_person` "final" sets the xgb IND value for person-matched cells (R/ind_person.R:150-190) when lower. The cross-seat credit (`AUSPOL_CROSS_SEAT_VOTE=1`) can only raise the base, so together they end at carry x record whenever that is lower.
* `AUSPOL_NOTIONAL` / `AUSPOL_STATE_NOTIONAL`: published_flags.R:56-58 says they do not touch Vic; the "no-op under XGB_PRIMARY=1" wording at line 56 predates `BASE_MARGIN=2` and is stale.
* `TRAIN_DEMEAN=1` (published_flags.R:714) subtracts each election-class mean residual from the xgb label, so the trees deliberately cannot move a class's statewide level. The level therefore comes from `state_mean` (and F1/F12 matter because it also goes in as a feature).

### F16 (b) Smaller renormalisation losses. LOW.

* `seat_poll_blend_apply` (seat_poll_blend.R:708-709): polled cells are pulled, cells the poll does not name are not, then the whole row is rescaled. Net change is zero only if the poll classes cover the same mass as our classes; otherwise the pull is diluted. For Hawthorn only LNP is pulled (a poll reports only `LIB` 41), so the other classes shrink pro rata.
* `blend_salience_shares` (salience_surge.R:~436) rescales the whole row after raising one cell.
* `state_poll_pool_apply` (federal only) rescales to the original total in the same way as F7.

### F17 (e) Daily CI runs on tables frozen at the last stage-9 publish. MEDIUM for "what is published".

* `.github/workflows/forecast.yaml:169-217` downloads `seat-poll-blend-vic2026.csv`, `demo-resid-vic2026.csv`, `leader-seat-vic2026.csv`, `seat-swing-port-vic2026.csv`, `level-recent.csv`, `spread-by-*.csv`, `error-quantiles.csv`. `seat_poll_blend_table` (R/seat_poll_blend.R:552 onward) uses the file instead of recomputing when `.has_seat_predictions()` is false, which is the CI case.
* So a new seat poll, or any refit, does not reach the published numbers until a rebuild is promoted. On disk now these tables are stamped 2026-10-17 23:15. Pete's CLAUDE.md already names the published-vs-deployed risk; this is a concrete instance.

### F18 (e) Stage-1 base includes nomination zeroing; pre-nomination live does not. LOW (time-limited).

* Nomination zeroing is not in `post_xgb_switches()` (R/new_ind_shrink.R:40-47) and not gated by XGB_PRIMARY (fed:1550), so stage-1 `base_pred` has exact zeros for classes with no candidate. Live before nominations has none, so the trees see cells they were trained to treat as zero. Goes away on 9 Nov.

### F19 (c) Two state-signal corrections stacked (federal backtest only). LOW for Vic.

* `state_poll_pool_apply` (fed:1497) then `state_deviation_apply` (fed:1537): both shift ALP/LNP by a state-level signal. Fitted separately. Not in the published path or any state harness.

### F20 (meta) The model registry cannot detect most of the above.

* `scripts/build_model_registry.R` greps for the switch NAME in the entry-point files. `AUSPOL_MINOR_DEFECT_BASE_PRED` shows "yes" for fit_seats (a comment), `AUSPOL_DEFECT_DISCOUNT` shows "yes" (a hardcoded constant), `AUSPOL_DEFECT_POOLED` shows "NO" everywhere (read in `R/`). It also cannot see a constant that replaced a fit (F3) or a table swap (F10). A row marked "yes" should mean "reaches the same function with the same value".

---

## Part 3. Ranking

Impact is on the published Vic forecast first, then on backtest scores. "Verified" = I confirmed both code locations by reading; "size" is UNVERIFIED for every item because nothing was run.

| Rank | ID | Cat | Reaches published Vic? | Reaches backtest scores? | Confidence it is real | Size known? |
|---|---|---|---|---|---|---|
| 1 | F1 | e | Yes, now, IND/OTH/OTH_RIGHT cells | No (harness never builds the live feature) | High (file contents match code) | No |
| 2 | F4 | e | Not the numbers; the calibration claims behind them | Yes, 16 of 23 pairs (5 of 7 AEF-7 pairs) | High | No |
| 3 | F5 | c/e | From 9 Nov | Yes, every salience pair | Medium-high (needs a stage-1 file to confirm the base includes the blend) | No |
| 4 | F2 | e | Yes, now, up to 5 seats | No | High | No |
| 5 | F3 | e | Yes, any departing major MP | No | High | No |
| 6 | F8 | c | Yes, sequential stack | Yes (measured as a whole) | Medium (overlap is structural; magnitude unknown) | No |
| 7 | F7 | b | Yes, every seat (0.2 pt ALP) | Yes | High (arithmetic) | Partly (adj sizes known) |
| 8 | F6 | a/f | Hawthorn LNP only | Federal and state pairs with polls | High | Partly (w = 0.461) |
| 9 | F9 | c | Yes | Yes | Medium | No |
| 10 | F13 | a | When cards publish | Yes (pairs with a card table) | Medium | No |
| 11 | F17 | e | Yes (staleness) | No | High | No |
| 12 | F12 | e | Yes | No | High that it exists | No |
| 13 | F10 | e | Yes, small | No | High | Small |
| 14 | F11, F16, F18, F19 | | low | | | |
| n/a | F14, F15 | d/f | understanding, not defects | | | |

## What I checked and found NOT to be a problem

* `new_ind_shrink` and `ind_person` do not overlap: the first needs no earlier row anywhere, the second needs one (R/new_ind_shrink.R header, R/ind_person.R:44).
* `seat_swing_port` is symmetric (ALP +adj, LNP -adj), so no whole-row dilution (seat_swing_port.R:229-234).
* `leader_seat_apply` uses the exact row-preserving `.shift_cell`.
* `seat_poll_weight` and `seat_poll_ind_weight` are fitted on the same poll aggregate they are applied to (decayed mean; direct-only for IND).
* `level_recent`: stage 1 sets it to 0 and stage 3 `level_pred` has none, so the pair is consistent at training; the mismatch is only live (F12).
* The spread-table lag (stage 7 refit read by stage 6) is handled by the SPZ rerun in rebuild_forecasts.sh.
* `htv_flow_override` preserves the `sd` attribute; `TRAIN_DEMEAN` is a deliberate pass-through of the level.

## Suggested order of work (for Pete to decide, not done here)

1. F1: build the live `level_pred` for IND/OTH/OTH_RIGHT the way `build_level_pred.R` does (bucket split), or print the live feature table next to a training row for each class. One run, no refit needed to see the size.
2. F2 and F3: make `fit_seats_full.R` call the same fitters as the harnesses (two lines each), and delete the stale comments.
3. F4: decide which spread is the intended one, then give all seven harnesses the published construction (`statewide_draws_as_at`) and rescore AEF-7.
4. F5: gate `blend_salience_shares` and nomination zeroing by `XGB_PRIMARY` like the other post steps, or add them to `post_xgb_switches()`; then check stage-1 `base_pred` no longer contains them.
5. F7: replace the whole-row rescale in `demographic_residual_apply` with the `.shift_cell` approach.

## Verification (2026-10-18, after the audit; Sonnet read-only agents per batch, Opus spot-checks)

Three Haiku-high verifiers died of autocompact thrashing on the large R files; reruns on Sonnet (40-line read cap).
Opus spot-checked F1-F4, F7, F10, F17, F20 in code. Line numbers above have drifted 10-20 lines in
`R/seat_poll_blend.R` and `scripts/fit_seats_full.R` since the audit.

| ID | Verdict | Size where readable | Status |
|---|---|---|---|
| F1 | REAL | live level_pred IND 0 / OTH_RIGHT 0 / OTH 10.35 vs split 3.36 / 4.08 / 2.90 | FIXED 04b4180 (AUSPOL_LIVE_LEVEL_SPLIT) |
| F2 | REAL | unmeasured | OPEN, live |
| F3 | REAL | live 0.282 hardcoded vs fitted in every harness | OPEN, live |
| F4 | REAL | 16 of 23 pairs scored with flat PARTY_SD 1.5 | OPEN, scoring |
| F5 | REAL | inert for vic2026 until a salience corpus exists | OPEN, harness |
| F6 | OVERSTATED | IND override real but no Vic IND cell; Vic: Hawthorn LNP, one Liberal-paid Aug 2025 poll, w 0.461 | IN PROGRESS (seat-poll prereg) |
| F7 | REAL | demo adj ALP mean 0.47 (max 1.42), GRN 0.39 (max 2.38); ~60% delivered on an ALP 40 cell | OPEN |
| F8 | REAL | structural; unmeasured | OPEN |
| F9 | REAL | structural; unmeasured | OPEN |
| F10 | REAL | live MP slopes IND 0.939 / OTH_RIGHT 0.960 vs harness vic2022 0.946 / 1.000 | OPEN, small |
| F11 | REAL | unmeasured | OPEN |
| F12 | REAL | training level_pred has no level_recent blend; live does (20-day decay) | OPEN |
| F13 | REAL, narrower | HTV override inert for Vic today (no cards) | OPEN |
| F14 | REAL | structural note (only draw spread reaches seats) | NOTE |
| F15 | REAL | design note | NOTE |
| F16 | REAL | one Vic cell | with F6 |
| F17 | REAL | CI reads tables frozen at last publish (0-2 days old now) | NOTE |
| F18 | REAL, narrower | backtest harness only | OPEN |
| F19 | REAL | federal harness only; double-count unmeasured | OPEN |
| F20 | REAL | registry matches names in comments (`build_model_registry.R:46`) | OPEN, tooling |

Also: `published_flags.R:731` comment says the level decay is 10-day; 20 days ships and was decided (DECISIONS 2026-10-12).
