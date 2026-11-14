# Decisions

One line each: the decision, the one fact behind it, a link. Newest first.
Created 2026-09-19 (the verse convention; auspol had none). Older decisions
live in the plans they came from (`docs/plans/prereg-*.md` RESULT sections).

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

- **2026-11-10 Standing notes moved out of NEXT-STEPS.md (queue audit: nothing a session could tick off).** Wording
  kept as it stood in the queue; reopen any of them by moving it back with a trigger.
  - F16 `AUSPOL_ROW_SHIFT_EXACT` NOT PASSED 29 Oct (DECISIONS). F18 `AUSPOL_NOM_ZERO_PRE_XGB` SHIPPED 10 Nov (DECISIONS).
    Dead-party `AUSPOL_LEVEL_DEAD_PARTY` (337f4cd) PARKED: its screen says not worth it; do not merge.
  - F8 RN is dead (arm N worse). F8 arm N's netting costs 579 s per harness run: cache it to disk before any rerun.
    (Departed arm B `mean`: DEAD, departed-origin closed 27 Oct. Width A0/A1: see the pipeline-audit section.)
  - OPEN (review nit, 30 Oct, not blocking): the shipped MP-slope pool's tau^2 is inflated where one OTH_RIGHT member
    slope of -23.1 (n 1, se ~11) enters the DerSimonian-Laird sum: qld2015, sa2014, vic2014 get tau^2 ~0.57 (0 at most
    targets), so IND there keeps w 0.99 instead of pooling (`output/mp-slope-pooled.csv`; `R/mp_slope_pool.R:79-83`).
    The all-35 screen ran on this table. CORRECTED 5 Nov: not a variance artifact (sigma is already pooled); the one
    OTH_RIGHT seat sat almost on the statewide level, so its slope blows up (-23.1, z ~2.2) and supplies 4.6 of Q 5.4.
    Visible effect: the n-1 GRN member keeps w 0.63 (1.23 vs mu 0.92). A fix is a choice (robust tau^2, or no ratio for
    seats near the level), PARKED: live vic2026 unaffected (tau^2 0), old targets only, needs its own screen.
  - MEASURED, PARKED per-class level bias (17 Oct, scratchpad levelcorr.R): statewide level over-predicts the Greens in
    23 of 35 elections (formal-weighted -0.73); all-class time-forward correction loses (1.402 -> 1.426), GRN alone
    helps slightly (prereg-poll-level-centring arm C, never run). Revisit GRN alone when more elections are in.
  - OPEN (hazard for arms, not live) pooled-fits audit 2026-10-16 (`reviews/pooled-fits-inventory-2026-10-13.md` and
    after): LEAVE-ONE-OUT but OFF at published flags, so any arm switching them on measures a leaked number:
    `fit_xgb_primary_sd.R:108` (`AUSPOL_XGB_PRIMARY_SD`), `fit_flow_drift.R` (`AUSPOL_FLOW_CELL_SD`),
    `fit_insurgency_risk.R:33` (`AUSPOL_INSURGENCY_SHRINK`), `party_positions(exclude=)` in `R/reentry_prior.R:288`,
    `xgb-primary-v6-oof-predictions.csv` (static-cache arm). (`state_swing_adjustment()`, dead code: DELETED 25 Oct on
    Pete's yes, DECISIONS.)
  - OPEN SEAT-REGISTRY entries for the new worst seats (DATA/MODEL/POLL registries: regenerated 4 Nov, `f453b62b`, `14f55eba`).
  - CORRECTED 5 Nov: the breakdowns did NOT stop. BludgerTrack still publishes them (refetched 5 Nov, newest fieldwork
    25 Oct, raw `external/reference/polls/pollbludger/raw/bludgertrack/fed2028-current-2026-11-05.xml`; branch
    `fed-breakdowns-trend-1105` builds the union, 704 polls). Feeding BludgerTrack's rows into the blend was REFUSED by
    Pete 5 Nov (DECISIONS; `--with-bt`, off), so the blend's federal share is decaying by choice; FK3 (~20 Nov) only warns. Wikipedia's part: deleted the sub-national
    sections from the fed2028 page on 24 Oct (revision 1381724607, "excessive detail"; checked 5 Nov). The last
    pre-deletion revision (1381712590, saved as `raw/fed2028_opinion-oldid1381712590.html`) parses to the same 471 polls
    as ours, so nothing was added after 6 Oct either. Adding `fed2028_opinion` to the CI fetch would lose rows (PM2!).
    `build_fed_state_breakdowns.R` now refuses to write fewer or older polls than on disk (FK2!, proven on a broken
    input). Live effect: the blend's federal share (`AUSPOL_LEVEL_FED_R` 0.15) decays with no new data; FK3 (45 days)
    would trip ~20 Nov.
  - **Demographic axis**: real (permutation control) but one coefficient is an
    order of magnitude too small; a level interaction needs its own prereg.
    Parked by Pete.
  - **`base_margin` scoped arm** (away from ALP, or to sa2026/wa2021-shaped
    cases): the full form refused at seat level (+0.004) despite primary gains.
  - **Time-forward fits still use `min_n` cliffs**: `R/split_slope.R:395,416` sit in `fit_conditional_slopes()`,
    which the shipped config never calls (`AUSPOL_FIT_SLOPES=0`). `fit_major_departed_slope()` no longer has its 40-seat cliff (`AUSPOL_DEPARTED_POOL` SHIPPED 6 Nov; DECISIONS). The
    `fit_conditional_slopes()` cliffs above remain, in unshipped code.
  - **Teal/independent under-call** (Curtin, Goldstein, Mackellar, Wakehurst):
    PARKED by Pete. Overall we lead AEF on independents (36 winners: 16.7 vs
    19.7 log loss). Wave term blocked (`reviews/wave-term-blocked-2026-09-07.md`).
  - Smaller known limits: intra-Coalition seats have no TCP class (2 of 660, AEF has the
    same limit; zero vic2026 seats affected today); Orange/Wagga `own_prev_pcv` NA for
    by-election winners (needs a feature, fallback fill refused); the statewide
    covariance pools every era; WA has no surge-v2 hazard.
  - GDELT parked (needs a GCP project); Census 2006/2001 have no bulk pack.
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
- **2026-11-08 "Independent X" labels classed IND (Pete: ship on correctness). SHIPPED 10 Nov (PR #213), published 9:33am: 35 elections 0.3168 -> 0.3166, AEF-7 0.2520 -> 0.2524.** 8 "Independent Liberal" by-election rows read as the Liberals collapsing to ~4%; fixed, the next Liberal primary is within a point in Melbourne 2014, Perth 2019, Werriwa 2007, Enfield 2022 (27 cells -60% squared error); seat log loss +0.0011 (SE 0.0011, 1k sims, 8 elections), Melbourne 2014 and Perth 2019 only.
- **2026-11-08 Miss-table seats of 16 Oct closed, superseded by arm H.** Parkes, New England, Dawson 2022, McMahon 2025, Malvern 2022, Bankstown 2023 now called right at 0.93-0.99, level with AEF; the Others-lump split shipped as `AUSPOL_SEAT_POLL_SPLIT_ALL="1"`. Primaries still 2-6 points low.
- **2026-11-07 Where we lose to AEF on AEF-7: nothing to ship.** IND/GRN widening refused, salience bias weak, by-election weight 0.5 stands. `reviews/aef7-gap-and-sal-screen-2026-11-07.md` section 2.
- **2026-11-08 By-election table completed (data correction, shipped on correctness).** 77 of 78 missing by-elections from Wikipedia; two review rounds caught 9 pages parsed from the wrong table (fixed: winner-named, most candidates). 35 elections -0.0040 (SE 0.0028), leave-one-out worst -0.0015, 14 elections slightly worse. Needs the full rebuild from stage 1. Merredin 2001: no page.
- **2026-11-08 Per-state statewide level correction CLOSED, not built (Pete: "with shrinkage, for each party").** Empirical-Bayes shrunk state bias per party, time-forward, 32 elections (`output/statewide-forecast-audit-8nov.csv`): mean |miss| Coalition 1.91 -> 1.95 (SE 0.18), Labor 2.40 -> 2.45, Greens 1.07 -> 1.18; toward the party mean also worse. WA's run of Coalition over-forecasts does not predict the next WA election. Rerun: `python scripts/check_state_level_bias.py`.
- **2026-11-08 Seat flow persistence SHIPPED in the federal harness (`AUSPOL_SEAT_FLOW_PERSIST="1"`; Pete: "ship", override of a screen refusal).** fed2022/2025 better (-0.0031, -0.0092; TCP -0.12 each), fed2013/16/19 worse; pooled -0.0004 (SE 0.0026). Per-seat shrinkage variant not better. `plans/prereg-seat-flow-persistence-2026-11-08.md`.
- **2026-11-08 Measured NSW exhaust for minor parties SHIPPED (`AUSPOL_NSW_EXHAUST_SRC="measured"`, `_MEAS_MAJORS="0"`; Pete: "Ship", over the 1.4-SE nsw2023 TCP guard).** 20k: pooled seat log loss -0.0034 (SE 0.0027), nsw2019 TCP -0.605, nsw2023 TCP +0.019 (SE 0.014). `plans/prereg-nsw-exhaust-measured-minors-2026-11-08.md`.
- **2026-11-08 NSW exhaust rates time-forward (`AUSPOL_NSW_EXHAUST_TF="1"`, leak fix, overnight; on dev in PR #206).** The harness read the anchor flow file at the target year, the target election's own row, which every other reader excludes. Leak-free: nsw2023 still gains (prereg TCP -0.324, SE 0.170); nsw2019's apparent gain was all leak. `plans/prereg-nsw-exhaust-tcp-2026-11-07.md` addition.
- **2026-11-08 Measured NSW exhaust for every class (`AUSPOL_NSW_EXHAUST_SRC=measured`) REFUSED at the screen.** nsw2019 -0.0038, nsw2023 +0.0044 seat log loss. The minors-only variant (post-hoc) is Pete's call after its 20k run. `plans/prereg-nsw-exhaust-measured-2026-11-08.md`.
- **2026-11-07 NSW exhaustion in the seat simulation (`AUSPOL_NSW_EXHAUST="1"`, Pete; anchoring half left off).** nsw2023 TCP MAE -0.345 (SE 0.171) in the 1k screen, seat log loss -0.0051 (SE 0.0006) at 20k; the 20k run lost its TCP files (fixed). `ANCHOR_EXHAUST` is inert under the live recipe. `plans/prereg-nsw-exhaust-tcp-2026-11-07.md`.
- **2026-11-07 `AUSPOL_MC_EXTRA=sal` closed: no route to the forecast helps (told Pete).** The shipped split reads `pred_naive`, which sal never touches (byte-identical on 35 of 35); switching to `cand_resid` is a seat tie with shares worse by >2 SE. `reviews/aef7-gap-and-sal-screen-2026-11-07.md`.
- **2026-11-07 Leader-seat bonus before the seat-poll blend (`AUSPOL_LEADER_BEFORE_BLEND="1"`, Pete; void clause overridden on a trace).** 20k on 35 elections -0.0002 (SE 0.0002), AEF-7 -0.0010 (SE 0.0010), Dickson 2025 Labor 0.07 -> 0.14; the 147 other fed2025 seats that move do so only through the state poll pool (proven with the pool off), net +0.0034. `plans/prereg-leader-before-blend-2026-11-06.md`.
- **2026-11-06 How-to-vote card order from the researched table (`AUSPOL_HTV_TABLE="researched"`, Pete: correctness fix on a tie).** 11 affected elections -0.0012 (SE 0.0029); NSW 2019/2023 were open tickets, not Greens-last; vic2010 -0.031, vic2014 +0.012. `plans/prereg-htv-researched-2026-11-06.md`.
- **2026-11-06 Class split rescreened on better predictions (search interest + Climate 200/Voices, `AUSPOL_MC_EXTRA=sal`): REFUSED again, stays OFF; Pete closed it for now (a new design would need its own walk).** 35 elections +0.0016 (SE 0.0011); seats the class won +0.328 each (was +0.415). The one rescreen the prereg allowed; a new design is Pete's call. `plans/prereg-class-split-2026-11-06.md` A1.
- **2026-11-06 Two-candidates class split (`AUSPOL_CLASS_SPLIT`) stays OFF; fix the per-candidate predictions first (Pete).** Screen of 35 elections: +0.0022 (SE 0.0013), both guards failed; it fixed Waite/Monash/Morphett but cost the 35 seats the class won (+0.415 each) because the junior fractions are poor (error 0.2-0.3). Rescreen after the newcomer under-call fix. `plans/prereg-class-split-2026-11-06.md` RESULT.
- **2026-11-06 Full rebuilds run from Task Scheduler at a quiet hour, not in the cloud (Pete).** `scripts/scheduled_rebuild.ps1` (PR #199): 02:00, waits for 8 GB free until 06:00, never publishes. Cloud (GitHub Actions) would need the ~19 GB of local inputs hosted first; not pursued.
- **2026-11-06 Three switches shipped (Pete, morning list items 1-3).** `AUSPOL_STATEWIDE_ENDPOINT="party"` (backtests read each party at its own last poll, as live does; 11 affected elections at 20k -0.0009, SE 0.0004); `AUSPOL_DEPARTED_POOL="1"` (clause override: the "no election worse by 2 SE" guard tripped on nsw2015 +0.0011 and qld2024 +0.00004; all 35 -0.0020, SE 0.0015; targeted -0.0081, SE 0.0052); `AUSPOL_BUCKET_SPLIT_SRC="minor-class-shares-resid-v2.csv"` (rebuilt by committed code each rebuild; a tie, shares -3%). Needs the full rebuild (level-pred + tree retrain). Preregs: `plans/prereg-statewide-endpoint-2026-11-06.md`, `plans/prereg-departed-slope-pool-2026-11-05.md`, `deciding-runs/20261105-0941-bucket-split-v2-rebuilt/`.
- **2026-11-05 Backtest preference flows dated by the target cycle, not 1969 (PR #193, 0.4.134).** `statewide_draws_as_at()` matched all 88 cycles (data.table name trap), so backtests read each target's own recorded flows; seat draws identical old vs fixed, only the two-party diagnostics move (nsw2023 implied 55.20 -> 53.97).
- **2026-11-05 Poll dates: a matched poll takes our fieldwork-midpoint date, not AE's (`AUSPOL_POLL_DATE_OURS=1`, Pete, as a correctness fix on a tie).** 82 of 2,214 matched polls were >7 days off (Resolve state polls ~2 weeks early); day-before FP error over 38 elections -0.003 (SE 0.004), live Victoria <= 0.01. `scripts/screen_poll_date_ours.R`.
- **2026-11-05 BludgerTrack federal state breakdowns NOT added to the blend (Pete).** +228 polls made qld2024, sa2026, wa2025 slightly worse (level RMSE 1.224 -> 1.231); live Victoria 0.04. Builder option `--with-bt`, off.
- **2026-11-05 Federal state breakdowns in the state trend (`AUSPOL_TREND_FED_R`) left OFF (Pete, on a tie).** 7 state elections: B2 day-before -0.003 (SE 0.008), 90/180 days +0.008 (SE 0.009), every arm 2-2.7 SE worse at 90 days; the time-forward weight came out 0 wherever fittable. Branch `fed-breakdowns-trend-1105`, `reviews/fed-breakdowns-trend-screen-2026-11-05.md` there.
- **2026-11-05 Departed-rate refit (`AUSPOL_DEPARTED_RATE=fit`, fitted on non-successor cells per Pete 29 Oct) NOT SHOWN at the AEF-7 screen; stays off, branch `departed-rate-fit-1105` not merged.** Fitted rate 0.21-0.23 vs the shipped 0.38, but seat log loss 0.2584 -> 0.2585 (+0.0001, SE 0.0003), four of seven elections worse, only nsw2023 better (-0.0019). `plans/prereg-departed-rate-screen-2026-10-25.md` RESULT (branch `prereg-offbranches-1025`).
- **2026-11-05 vic2006 winners recorded in candidacies.csv, kept despite a worse vic2010 backtest (Pete).** Seat log loss vic2010 0.2281 -> 0.2335 (+0.0054, seat SE 0.0021) on frozen as-at trees trained before the fix; correct data wins, re-measure after the next full rebuild. `scripts/build_candidacies.R` BC7v; NEXT-STEPS Data and infra.
- **2026-11-02 One Nation stays out of the recent-poll blend (`AUSPOL_LEVEL_RECENT_CLS="ALP,LNP,GRN"`; arm BLD NOT PASSED).** 35 elections on the shipped level: +0.0690 points worse (SE 0.0551), 20 worse and 11 better; polls over-state One Nation where it stands in few seats (NSW 2023 +1.12). `plans/prereg-poll-lean-2026-11-02.md` Amendment 1.
- **2026-11-04 New-independent breakout stays OFF (Pete).** Gated version passed amendment 2 as written but was net worse (AEF-7 seat log loss +0.0079, SE 0.0017; independent-won seats -0.073), and its new-independent flag is 0 for most state elections, so the screens mostly measured all independents. Revisit only with better pre-election signals. `plans/prereg-new-ind-breakout-2026-11-01.md`.
- **2026-11-04 Poll lean: all six arms REFUSED; nothing ships (told Pete).** Sponsor +0.0548 (SE 0.0199), method +0.0244 (SE 0.0161), everything together time-forward +0.0121 (SE 0.0293), 38 elections. Reopens: sponsor after vic2026; One Nation anchor conditioned on seats contested after 9 Nov. `plans/prereg-poll-lean-2026-11-02.md`.
- **2026-11-02 Company lean against results (arm REC) NOT PASSED; not wired.** 38 elections: -0.0154 points (SE 0.0216), 22 better and 15 worse with big swings both ways; a company's past lean is a weak guide to its next. `plans/prereg-poll-lean-2026-11-02.md`.
- **2026-11-02 Trend anchor strength stays as published (`AUSPOL_ANCHOR_SD_MULT="1"`; arm ANC NOT PASSED).** Picking the pin setting time-forward over 38 elections: day-before level error +0.0104 points (SE 0.0149); loosening it helps big surges (sa2026, qld2017) and hurts the small ones the polls over-stated (nsw2019, wa2017). So the 2 Nov S7 breach (Vic One Nation 19.52 vs 22.03) is measured behaviour, not a defect. `plans/prereg-poll-lean-2026-11-02.md`, `reviews/s7-onp-anchor-2026-11-02.md`.
- **2026-11-01 Card fit: the shipped coalition-split table is the only source when present (PR #184).** The forecast runner read a partial transfer set (35% vs the validated 37.9%). Same rule as the Coalition split, 17 Oct.
- 2026-11-01 New-independent breakout: Pete chose the evidence-tiered design, then (on finding R/breakout_mix.R, the same mechanism refused 6 Oct) a re-screen of the existing 47-feature mixture limited to new independents, and after the ungated wash a gated version at p >= 0.05. Incumbents SHOULD lose votes to a breakout (Pete; prereg amendment 1). plans/prereg-new-ind-breakout-2026-11-01.md.
- **2026-11-01 One Nation fill: middle version tested, not supported; proportional kept.** On the 4 past surges the pooled proportional coefficient is -0.97 (SE 0.13) for Labor, -1.07 for the Coalition (-1 = the shipped fill; a 50/50 blend ~ -0.5). `reviews/boxhill-trace-2026-11-01.md`.
- **2026-11-01 How-to-vote card rows recency-weighted (`AUSPOL_HTV_RECENCY_HL=8`), shipped on dev (prereg rule 3, overnight).** 35 elections at 20k: -0.0001 (SE 0.0000); moved seats -0.0053 (SE 0.0042); no election worse. `plans/prereg-htv-recency-2026-10-31.md` RESULT.
- **2026-10-23 to 2026-10-31: archived verbatim** in `backlog/journal-decisions-2026-10-23-to-10-31.md` (46 decisions: surge mixture off, sitting-member rule and census v2 rebuilds, One Nation Senate ordering, MP-slope pool, port 3C, minor field by points, switch registry MR4, and the refusals of swing-floor hybrid, level conservation, F7, F16, decay4, IND gap yes/no, returning independents). Checked 10 Nov, nothing live outside the queue: the unknown-candidate surge was kept off (Pete, 4 Nov; PETE-ASKED-FOR); the tau^2 departed slope pool SHIPPED 6 Nov (fe478b0b); the direction-aware swing floor is `AUSPOL_SWING_FORM=hybrid`, REFUSED 30 Oct (in the journal); per-cell fat tails and the new-independent seat-poll term are OPEN in `NEXT-STEPS.md`.
- **2026-10-15 to 2026-10-21: archived verbatim** in `backlog/journal-decisions-2026-10-15-to-10-21.md` (25 decisions: seat-poll blend arm H, live train/serve fixes F1-F3, Liberal v National as two candidates, width + tails (CE), statewide draws net of seat spread, surge_h leak fix kept, party correlation off, surge source none, seat context in the rebuild, harness md5 tags, WA/NT screened-slopes port, the 15 Oct external/elections incident, and the refusals of 19-20 Oct). Still live from that range, tracked in `NEXT-STEPS.md`: the NT seat layer (nt2020 not yet traced).
- **2026-10-08 to 2026-10-14: archived verbatim** in `backlog/journal-decisions-2026-10-08-to-10-14.md` (46 decisions: NSW 2027 build and what-if slider, seat-poll and statewide-poll weighting refusals, level decay and day-before blend, deciding-run tooling, flow recency arms, own poll source, scoring and training rules, leak fixes, census publishing, thin poll cycles, defector carry, size SD, poll archive). Still live from that range, tracked in `NEXT-STEPS.md` and not decided here: flow recency arms (`AUSPOL_FLOW_RATE_HL` / `AUSPOL_FLOW_TF`, built, none shipped, open) and the move off AEF for polls and flows (`PETE-ASKED-FOR.md` 2026-10-12/13 rows).
- **2026-10-03 to 2026-10-07: archived verbatim** in `backlog/journal-decisions-2026-10-03-to-10-07.md` (35 decisions: nomination zeroing v61 and its late order, departed successors, re-entry majors, new-independent shrink, seat-poll fixes). Every switch shipped there is still in `published_flags.R` and has been through the 15-21 Oct rebuilds. Standing from them: NSW 2027 polling day is 13 March 2027 (NSWEC Bulletin 2; the anchor's cycle file says 20 March); the departed-rate refit falls back to the control 0.38.
- **2026-09-29 to 2026-10-02: archived verbatim** in `backlog/journal-decisions-2026-09-29-to-10-02.md` (ledger v47-v60). STILL LIVE from them: the seat-poll weight is fitted on the PREVIOUS rebuild's `output/forecasts.csv` (`R/seat_poll_blend.R:67`), so a rebuild that moves earlier elections needs a second stage-6 pass -- the same one-run lag the spread table had (NEXT-STEPS). Standing from them: leak fixes v47 (minor-slope fallback), v49 (surge-v2 hazard), v51 (statewide fundamentals/trend mix) are time-forward; the seat-poll blend ships (v50); calibration temperature closed (no-go).
- **2026-09-19 to 2026-09-28: archived verbatim** in `backlog/journal-decisions-2026-09-19-to-09-28.md` (ledger v39-v46 history). Standing from them: backtests are predictive (`AUSPOL_FORECAST_MODE=1`); the daily forecast publishes unattended behind input guards; the data registry is not regenerated on CI; a poll-tracking breach is reported, not halted; the model is not frozen before 28 Nov; live statewide level anchored as the backtests are. Refused there: state-deviation v2, dropping `fed_aligned`, zeroing the phantom vote alone. Parked: seat-type swing pre-election.
