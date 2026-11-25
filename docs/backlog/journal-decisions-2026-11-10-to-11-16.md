# DECISIONS 2026-11-10 to 2026-11-16, moved verbatim 25 Nov 2026 (newest first)

- **2026-11-16 The vic2026 seats' minor total (12.5 against the level's 11.0) is left as is: traced to the trees seeing the real candidate count, the direction past results support.** `SMN1` (mean seat share after each stage of `fit_seats_full.R`): the trees move IND+OTH+OTH_RIGHT 9.32 -> 12.59; with `AUSPOL_LIVE_N_CAND=0` 9.88. On `output/published-predictions.csv` (35 pairs) minor classes are under-called, more so with more candidates (-0.69, -1.47, -2.66 points at 1, 2, 3+; SE ~0.8, clustered on pair). Review item C1 (`reviews/FABLE-FULL-REVIEW-2026-11-15.md`). Claude's call, reported to Pete; no number changes.

- **2026-11-15 `AUSPOL_LIVE_N_CAND=1` SHIPPED (Pete: "Ship it", after a live walk): the live trees get the real number of candidates per class and seat.**
  `R/xgb_primary_override.R:322` served `n_cand_now = 1` for every live row ("unknown pre-nomination") while every training
  and backtest row carries the real count; nominations closed 9 Nov and 110 of vic2026's 616 seat-classes have more than one
  candidate. Walk, constant 1 against real counts, same polls and seed, 20,000 sims: expected seats ALP 24.53 -> 23.34, LNP
  39.72 -> 39.03, ONP 14.90 -> 15.77, IND 1.48 -> 2.16; P(LNP majority) 30.1% -> 27.9%; win probability moves by more than 5
  points in 23 cells (12 seats), largest Essendon IND 39.8% -> 84.7%. Known cost, accepted: the three minor classes' seat
  means add to 12.5 against the polls' 11.0 (were 9.8). Live only; no backtest number moves. Evidence and the rest of that
  session's findings: `reviews/FABLE-FULL-REVIEW-2026-11-15.md` (item A7). Same day, also from that review, Pete chose: leave
  `AUSPOL_LIVE_LEVEL_PRED_TREND=1` (re-walked at a 0.9-point gap: one cell over 2 points); relabel the site's two-party line
  as implied from primaries and add the polls' own figures; show the forecast's level in the party tiles; list the
  `fit_nsw.R` noise-limit failure as known until after 28 Nov. The last three are NOT built yet.
- **2026-11-15 "Revisit candidate-count weighting once nominations close" is CLOSED, not rescreened: it was built as the class split, which stays OFF.**
  The 22 Aug remedy (`reviews/candidate-count-weighting-blocked-2026-08-22.md`) became `AUSPOL_CLASS_SPLIT`, REFUSED twice on
  35 elections on 6 Nov (+0.0022 SE 0.0013; with search interest +0.0016 SE 0.0011), and Pete closed it pending a new design.
  The backtests already used each election's real nominations, so the VEC's final list adds nothing to that verdict; a rescreen
  would read the same per-candidate predictions (`minor-candidate-oof-resid-v2.csv`, unchanged by the 9 Nov newcomer lift,
  which acts on seat shares) and the prereg's one rescreen is used. Live size, from `minor-candidate-oof-resid-v2-live.csv`:
  75 of 88 vic2026 seats have a minor class with 2+ candidates (109 seat-classes), median junior 2.6 points, largest 7.4; only
  Kew's class reaches 15% (IND 21.9, junior 2.8). Told Pete 15 Nov.

- **2026-11-15 The Liberal card shares train on the CARD where a dated card exists, not on each election's own result; open cards get their own share (Pete: ship as a correctness fix on a tie).**
  `AUSPOL_HTV_LABELS=hybrid`: card label per election and seat; seats with no dated card keep the result label; open share
  partial-pooled. 18 elections with a card row: -0.0001 (SE 0.0002), none moved more than 0.003. The pure-card arm tied
  (+0.0014, SE 0.0017) but failed its guard: nothing before 2013 has a dated card, so vic2010 lost its training (+0.032).
  Live: Labor-above 62.1% -> 61.7%, Brunswick (open card, registered 12 Nov) 57.1%. `plans/prereg-htv-card-labels-2026-11-15.md`.
- **2026-11-15 vic2026 Liberal card known from the VEC's registered cards: Labor above the Greens (PR #241).** 6 of 7 inner-Melbourne
  cards read; Brunswick open. Ends the 0.67 card mix; Pascoe Vale Labor 0.347 -> 0.426, Northcote 0.163 -> 0.205.
- **2026-11-14 On election night, two candidates of one minor class are counted separately from their counted figures (Pete: "Ship for 28 Nov").**
  Prereg PASSED on fed2022/fed2025/vic2022 replays: pooled night log loss -0.0076 (SE 0.0096), no night worse by >0.005; Monash's
  winner 0.005 -> 0.469. Gain mostly Monash (without it +0.0018, SE 0.0012). Pre-election split stays OFF (6 Nov). `plans/prereg-night-class-split-2026-11-14.md`.
  Restated 14 Nov night after a federal replay fix (PR #240: names case-folded; 8 divisions a night had lost their 2CP
  count, Forde among them): pooled -0.0084 (SE 0.0095), without Monash +0.0011 (SE 0.0010), still PASS; the live
  `.NIGHT_PAIR_CAL` refit is identical. Forde's cost was the missing count, not the split (prereg addendum).
- **2026-11-14 Paid SEAT polls lose a lean toward their sponsor's side, each side shrunk to zero on its own (Pete: "Build per-side, ship live"; an override of an unvalidated backtest).**
  Hindsight: fed2025 Coalition-paid +4.7 net, Labor/Greens +2.6, Climate 200 -0.5. Time-forward no variant beat zero on fed2025 (only 6
  older Labor/Greens-side polls to learn from). Placebo 18/20; live: Hawthorn's Liberal-members poll 41 -> 37.7 only. Score on vic2026.
  `plans/prereg-seat-paid-lean-2026-11-14.md` (amendment 3).
- **2026-11-13 Party- and advocacy-paid statewide polls count x0.64 and lose a shrunk lean toward their sponsor (Pete, 13 Nov: "Ship it").**
  12 paid polls since 2025 vs same-time independent polls: lean +0.24 (SE 0.55) -> ~0; extra noise -> factor 1.248. Placebo
  18/20; no scored election has a paid poll before its cutoff, so it is first scored on vic2026. `plans/prereg-paid-poll-correction-2026-11-13.md`.
- **2026-11-13 vic2026 salience is linked by a LADDER of similar-loudness queries, not the Premier (Pete, 13 Nov: "Ship it").**
  Beside the Premier the median batch representative peaked at 1 (0-100), so linked rises came in 5 steps; the ladder (49
  queries of 5, 2 shared per step, two passes) gives 229 distinct values among 238 positive jumps, 561 candidates linked.
  Batch factors use the representative's last-8-weeks level (whole-window levels made one Morwell batch 30x too loud).
  Live vs anchor: 4 favourites change (Cranbourne ONP 56% -> ALP 67%, Essendon ALP -> IND 40%, Bentleigh and Eltham LNP ->
  ALP ~51%); Mornington IND 24% -> 1%; expected seats move under 1. No outcome exists to score it against.
  `scripts/fetch_salience_vic2026_ladder.R`, `scripts/build_vic2026_salience_jump.R` (VJ6/VJ7).
- **2026-11-13 Council-history coverage fix ships, although the live forecast moves up to 5 points (Pete, 13 Nov).**
  Both prereg guards pass (35-election log loss +0.0009, SE 0.0018; share RMSE +0.0067). Live vic2026 moves up to 5.3
  points (Footscray ALP 53% -> 48%, favourite to GRN; Melton ONP -> LNP; ALP 26.8 -> 26.1 expected seats), all from the
  retrained production trees (other rebuild files at most 1.5). That breached the prereg's "over 2 points, unexplained"
  clause, so it went to Pete. `plans/prereg-council-coverage-2026-11-12.md` amendment 1.
- **2026-11-12 vic2026 salience ships now; its coarse anchor scale is fixed before the final snapshot (Pete, 12 Nov 10:40pm).**
  With/without on the live forecast: 12 of 88 favourites change, all close seats (Hawthorn IND 0.007 -> 0.346, Benambra
  IND 0.001 -> 0.274; expected seats ALP 26.8 -> 24.9, ONP 14.7 -> 15.8, IND 0.1 -> 1.3). Known defect: linked values come
  in ~5 steps of 0.0607 (17 candidates with raw rises 2.3-32.1 share 0.182). `reviews/salience-vic2026-live-walk-2026-11-12.md`.
- **2026-11-12 vic2026 salience goes into the live forecast RANK-MAPPED, not raw (Pete, 12 Nov).** Each jump is divided by
  the anchor's (Ben Carroll) rise, and his is small, so the 11 Nov snapshot ran ~20x the backtest scale (p90 0.168 vs vic2022
  0.0079); each candidate keeps their vic2026 rank, mapped onto the backtest corpus within sign. Built on branch
  `salience-vic2026-link` (`scripts/link_vic2026_salience.R`); not merged until the live with/without walk.
- **2026-11-12 "Lighthouse" and "Lighthouse/Growth Intelligence Centre" are one firm: one pollster page (Pete, 12 Nov).** One poll each, a day apart
  (25 and 26 Oct 2026), so the "method changed" note was false. `SAME_FIRM` in `scripts/build_pollster_pages.R`; pages only, the forecast
  is unaffected (both under 3 polls, pooled house effect). "Lonergan" 2013-16 vs "Lonergan Research" 2022 stay two linked pages.
- **2026-11-12 Night: cand_ref "copy" stays ON for 28 Nov; pair_cal still passes (Pete, 12 Nov).** The vic2022 replays and
  the cand_ref scorer matched booth tables by exact district name ("South Westcoast", "Albertpark"; 25 of 87), fixed
  264cc306/5963c174. Rerun: pair_cal pooled -0.00212 (SE 0.00143; was -0.00175), PASS; cand_ref simulated -0.0317
  (SE 0.0263, 30 targets), real -0.0017, vic2022 -0.0006, but its "vic2022 identical" clause now fails: vic2022 has two
  class-switchers the bug hid (Nuske, Doukas). Clause voided as resting on the bug (prereg Amendment 1).
  `deciding-runs/20261112-vic2022-names/`.
- **2026-11-12 The anchor's NSW 2007 Labor/Coalition swap is corrected on load; it never reached the forecast.**
  `load_eventual_results()` applies `EVENTUAL_RESULT_FIXES` (EVR1; `AUSPOL_EVENTUAL_FIXES`, shipped "1"). Screen with the
  fix off vs on, all 35 elections, 1,000 sims: byte-identical in 35 of 35 (the switch printed in all 42 harness runs each
  way). Why: every forecast fit of the statewide fundamentals uses the `@TPP` target, which the file has right; the only
  per-party fit (`build_level_components.R`) feeds the retired `fit_xgb_primary_v6.R`. It corrects displayed figures
  (pollster final-poll errors, scorecard, party pages).
- **2026-11-12 Poll columns by full party name (`AUSPOL_POLL_SERIES_CLASS=name`) NOT SHIPPED (Pete, 12 Nov).** All 35
  elections at 20,000 sims: seat-winner log loss 0.3089 -> 0.3114, +0.0025 (SE 0.0016, worse by more than 1 SE), share
  squared error on 6,807 moved cells +15%; AEF-7 a tie (-0.0009, SE 0.0031). Worst sa2018 +0.076, fed2013 +0.016,
  vic2022 +0.016. Stays "code". `deciding-runs/20261111-0747-poll-series-class-all35-r2/results.txt`;
  `plans/prereg-poll-series-class-2026-11-06.md` RESULT.
- **2026-11-10 One Nation seat spread unchanged before 28 Nov (walk of Box Hill, Ashwood, Glen Waverley with Pete).**
  Senate-rank spread vs seat regressions, out of sample: Senate alone 3.44 points RMSE (308 seat-elections, 5 elections),
  trees on 11 inputs 3.23, gaining only on qld2017 and worse on qld2020/qld2024/nsw2023. On Victoria all three
  alternatives sit within ~2 points of ours in the eastern seats (Box Hill 9.7 ours vs 11.0-11.6). Box Hill's gap to the
  bookmakers is the proportional fill, not One Nation's share. `scripts/explore_onp_seat_regression.R` (de7e7071).
  ADDED 11 Nov (ITG review): those figures came from a join that missed 44 of 308 multi-word seats and gave them a
  made-up 0 for previous Greens/minor right/One Nation. Rerun with the join fixed (all 308 joined, guarded by OSR0):
  Senate alone 3.44 (unchanged), trees on 11 inputs 3.19 (was 3.23), still gaining only on qld2017 (5.27 -> 3.89) and
  worse on qld2020 (2.65 -> 3.07) and qld2024 (2.94 -> 3.07); Box Hill ridge 11.4 vs ours 9.8. Decision unchanged.
- **2026-11-10 Preston: One Nation disendorsed Franco Guardiani (ABC, 10 Nov); he stays on the ballot as One Nation. No
  change.** We have One Nation at 16.7% there and Labor at 0.964 to win (Greens 0.026); a cut to his vote moves no
  seat call. The model has no column for disendorsement or scandal (`R/candidate_returns.R:729`).

- **2026-11-10 Queue audit closures.** "Move off AE (b)": the language-model extraction of Poll Bludger posts WAS built
  (`AUSPOL_POLL_PB`, 45df5117; `reviews/pb-llm-extraction-2026-10-13.md`), so the item is done. Moved here from the queue
  as a standing not-doing: the in-browser simulator (~40 h); the 2.5-point knots already feel live; revisit if Pete wants
  two sliders at once.
- **2026-11-10 Local check skips the tests inside R CMD check (Pete: go).** `check_like_ci.R` passes `--no-tests`;
  the in-check copy was a subset of half one (4,964 vs 5,083 passed, FAIL 0 both). Full forced check 559 s -> 396 s.
  CI unchanged; `--with-check-tests` restores them (and bypasses the unchanged-package skip). Merge 8c7cbcf9.
- **2026-11-10 vic2026 gets its own minor-party bucket split from the VEC list (Pete: "Ship it").** Was the vic2022
  mix (`FST1!` fallback); now IND 0.27, OTH_RIGHT 0.24, OTH 0.50. Walk on the live forecast: 0 favourites changed, max
  win-probability move 0.4 points (Ashwood ALP), max share move 0.23 (Kew LNP). Built by `rebuild_forecasts.sh`
  (`MC_LIVE_EL`); `PIPELINE.md` section E step 5.
- **2026-11-10 F18 SHIPPED: non-standing parties zeroed before the trees too (`AUSPOL_NOM_ZERO_PRE_XGB="1"`; Pete: "Switch it on").** Walk 2 on the VEC final list: 47 untouched seats identical, 40 of 41 affected under 1 point, Mildura LNP 46.3 -> 50.2 walked. `plans/prereg-nom-zero-pre-xgb-2026-10-25.md`.
- **2026-11-10 Nomination gate live for vic2026 (PR #212, merged 7:11am).** 734 VEC candidates; 40 cells zeroed (IND 32, OTH_RIGHT 8), no favourite changed.
