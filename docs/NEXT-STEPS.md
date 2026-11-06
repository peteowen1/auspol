# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before the 2026-09-19 rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`;
closed items of 7-19 Oct, verbatim: `backlog/journal-2026-10-07-to-2026-10-15.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30; slimmed 2026-10-19.

## NEEDS PETE

- CLOSED 4 Nov, NOT SHIPPING (told Pete): poll weighting by type, company and age. All six arms refused on 38
  elections (`plans/prereg-poll-lean-2026-11-02.md`; DECISIONS 2026-11-04). OPEN triggers: (a) after nominations close
  9 Nov, condition One Nation's anchor/blend on how many seats it stands in; (b) after vic2026, re-test sponsor lean
  (first completed election with party-commissioned polls labelled). Seat-poll side PARKED 5 Nov (told Pete;
  `AUSPOL_SEAT_POLL_FIRM_FLOOR` stays "0"; see "Seat polls: PARKED").
- **Status 6 Nov 12:15pm.** main = dev 0.4.139 (PRs #195, #197, #198, #199 merged 6 Nov). Shipped 6 Nov: `AUSPOL_STATEWIDE_ENDPOINT="party"`,
  `AUSPOL_DEPARTED_POOL="1"` (clause override), `AUSPOL_BUCKET_SPLIT_SRC="minor-class-shares-resid-v2.csv"`; rebuild published 10:58am
  (pooled seat log loss 0.3256 -> 0.3224, 2,931 seats; nsw2019 +0.052 is Murray alone at the log-loss floor). OPEN: read the next daily
  forecast run's conclusion, the first with all three live. OPEN: machine has a kernel pool leak (2-3 GB free at noon 6 Nov); reboot,
  then `scripts/scheduled_rebuild.ps1` (02:00, waits for 8 GB) for the next rebuild. `output/candidacies.csv` (vic2006 winners) ships with
  the 10 Nov nominations rebuild. OPEN: VEC feed access details; Pete waits to 7 Nov, then sends the chase (Gmail draft saved 5 Nov).
  Run `scripts/refresh_local_poll_inputs.sh` before ANY local forecast run.
- CLOSED FOR NOW (Pete 6 Nov ~5:20pm; built, off, reopen only with a new design walk): class split REFUSED twice 6 Nov (A0 +0.0022; A1 on the `sal` predictions +0.0016,
  SE 0.0011; seats the class won +0.328 each). Pete 6 Nov 3:05pm: keep off, fix predictions first; screen REFUSED 6 Nov 2:58pm: all 35 +0.0022 SE 0.0013; class-won seats +0.415, others -0.0052; prereg RESULT)
  (Pete walked it 6 Nov 1:15pm, chose "Split now"): **two candidates of one minor class counted separately**,
  `AUSPOL_CLASS_SPLIT`, extending the Coalition split. Prereg `plans/prereg-class-split-2026-11-06.md` (primary: the 84 seats with
  2+ of one minor class at 5%+; guards prediction-defined). Walkthrough `reviews/two-candidates-one-class-2026-11-06.md`. Does not
  reach the live forecast until vic2026 per-candidate predictions exist (after the 10 Nov nominations rebuild).
  Reviewed 6 Nov (Sonnet): 0 Important. Pre-existing, open: a final two of one class (LNP|LNP since 17 Oct, now also
  IND|IND) leaves the second side empty in the TCP tables (`R/tcp_scenarios.R` setdiff, `fit_seats_full.R:2166`); display only.
  If the screen passes: deciding run `powershell.exe -File scripts\deciding_run.ps1 -Arm "AUSPOL_CLASS_SPLIT=1" -Label class-split -At 02:00`
  (20k, all 35), then `Rscript scripts/score_class_split.R <run>/cache/<base key> <run>/cache/<arm key> 20000` (keys: `_key.rds` in each).
- OPEN, PARTLY DONE 6 Nov (`AUSPOL_MC_EXTRA=sal`: independents' RMSE 7.86 -> 7.57; not shipped, the bucket split it feeds is
  unchanged at 1.314; not rerun since the OTH_RIGHT key fix): the per-candidate model gives a newcomer independent the generic 4-8% beside a sitting member
  (Jones 4.8 vs 12.1, Holmes-Ross 4.3 vs 14.6, Leonard 7.6 vs 17.1). Table in the walkthrough doc.
- OPEN, blocked on the item above: `AUSPOL_POLL_SERIES_CLASS=name` (SA-Best, Katter, UAP, FF classed by full name). 20k on 7 pairs a tie
  (-0.0028, SE 0.0038); sa2018 +0.037 of which Morphett +0.031. `plans/prereg-poll-series-class-2026-11-06.md`, last section.
- **Election-night live model, map https://github.com/peteowen1/auspol/issues/148.** History, DONE list and replay evidence:
  `backlog/journal-2026-11-05-election-night.md` (moved verbatim 6 Nov); plan `plans/election-night-booth-model.md`. Runbook:
  `gh release download forecast-latest -p night-state-vic-2026.rds -D output`, then `night_runner.R --state=output/night-state-vic-2026.rds
  --ref=output/booths-vic2026-ref.csv --council-lean=output/council-fp-2022.csv`. Live page https://inthegame.blog/politics/live
  (find my seat live, #166 closed 5 Nov). OPEN, in order:
  1. SharePoint live-feed fetch (VEC access details due 4 Nov, chase 7 Nov); the Actions backup's live source waits on it.
  2. 10 Nov: in ITG `politics/night-maps/`, `python -I build-booths-2026.py <State2026MediaFilePollingLocationsV2.xml>`, commit
     `booths-vic2026.json`; check the popup at 390/1280 px and the 38 Narracan-only 2018 names against the 2026 polling places.
  3. Navbar link; the "called" rule (99% with 10% counted is a placeholder).
  4. 25 Nov trial (no 2CP): with real 2026 centre names, compare each counted early centre with its own 2022 upper-house lean,
     re-test `--early-partial=1` (off; it made the approximated replay worse), and take the expected early total from the
     VEC's published attendance. Upper-house model designed, not built (`plans/upper-house-night-model.md`).
  Dated: the Esri key (basemaps + geocoding, pay-as-you-go off) expires 27/10/2027.
- 28 Oct: value-odds page https://claude.ai/artifact/GdrpxSB7zkY1xEvJvU3TKx (readiness, seat click-through, our
  probabilities against Sportsbet/TAB/Betfair). Built from scratchpad scripts, not the repo: it does not refresh.
  Contested-seat research, all committed: `reviews/contested-seats-vic2026-2026-10-28.md` (hub),
  `new-party-fill-proportional-vs-uniform-2026-10-28.md` (proportional One Nation fill supported, 4 elections),
  `contested-seats-light-checks-2026-10-28.md` (agent's sign error corrected at the top; other-right lead pooled over
  20 elections is -0.040, SE 0.015: small), `live-walk-contested-seats-2026-10-28.md` (xgb cut to the eastern Liberals
  0.1-1.6, not 3). Branch checks `ind-overcall-1025` and `mp-slope-shrink-1025`: both PASS `check_like_ci.R` 28 Oct.
  Still open from it: One Nation spread pooling (needs code: spread fixed to SA 2026 by the `sa_ratio` quantile map in `fit_seats_full.R`);
  Hastings/Cranbourne recheck after nominations (9 Nov); re-entry inflated bases (other classes over-called -2.9,
  SE 0.84, where a party re-entered; Narracan Greens is the live case).

- F16 `AUSPOL_ROW_SHIFT_EXACT` NOT PASSED 29 Oct (DECISIONS). OPEN: F18 `AUSPOL_NOM_ZERO_PRE_XGB` (off): walk 1 done
  29 Oct (predictions 1, 2, 4 pass; 3 a finding in Morwell, to walk with Pete); walk 2 on the VEC final list. Dead-party
  `AUSPOL_LEVEL_DEAD_PARTY` (337f4cd) PARKED: its screen says not worth it; do not merge.
- F8 RN is dead (arm N worse). F8 arm N's netting costs 579 s per harness run: cache it to disk before any rerun.
  (Departed arm B `mean`: DEAD, departed-origin closed 27 Oct. Width A0/A1: see the pipeline-audit section.)

- OPEN, DATED (Tue 27 Oct, 3, 10, 17 and Fri 27 Nov): vic2026 benchmark capture. Built and run 22 Oct (all four
  sources, `docs/benchmarks/vic2026/2026-10-22/`). Each date: `Rscript scripts/snapshot_benchmarks.R`, plus the GES
  Chrome step (`scripts/ges_read_calls.js`; plan Amendment 1), rerun the script, commit the calls folder, rerun
  `scripts/build_data_registry.R`. Scorer BUILT 23 Oct: `Rscript scripts/score_benchmarks_vic2026.R --results=<csv>`
  (`district, winner, status`; winner as the VEC prints the party) once every district is declared; `--dry-run` passes
  its known answer now (ours 88/88 against its own favourites). Still to build: the VEC 2026 results file itself.
  Roy Morgan dropped 21 Oct (no seat winners) (`plans/external-benchmark-vic2026-2026-10-20.md`).

- Builds from 26 Oct branches (local; `mp-slope-shrink-1025` SHIPPED 30 Oct, `ind-overcall-1025` merged into dev 30 Oct).
  One quick_arm screen at a time:
  - `ind-overcall-1025` `7252acb`, merged into dev 30 Oct (`016ed0c3`): `AUSPOL_IND_GAP_RESTAND` (off). The SHARE
    version is NOT built, on Pete's call 30 Oct: it changes nothing, since the base already holds a re-stander's own
    vote (DECISIONS 2026-10-30). The yes/no arm REFUSED on AEF-7 30 Oct (moved seats +0.0014, SE 0.0007; prereg
    RESULT). Fitted-rate follow-up CLOSED 30 Oct (Pete): measured carry 0.357 on 513 seat-elections vs 0.33-0.38
    shipped (`reviews/ind-gap-carry-walk-2026-10-30.md`). Idea only: below-level seats carry ~0 (moves < 1 pt). OPEN: trace the 52 seat-elections where
    the leader re-stands but no own vote showed in the base (first Corio fed2007, Kiama nsw2023), with the harness discounts.
    (4 Nov: where "52" came from is not recorded in the walk review or its rows file; rebuild the definition first.)
    Shepparton is a true re-stand (Sheed 29.4 in 2022, VEC). Prereg `plans/prereg-ind-gap-restand-2026-10-25.md` (on that branch).
  - `prereg-offbranches-1025` `ee80497`: preregs for XGB_CLASS_JUR_CAL (merges clean), OTHERS_SCALE_JUR
    (identical to the refused pooled arm at every AEF-7 target on cached history), SALIENCE_STATE (needs two as-at
    retrains; blanks for fed/WA/vic2026 rows are a jurisdiction marker risk). (Departed-rate refit: built and NOT shown
    5 Nov, DECISIONS. Federal breakdowns in the trend: tied, left off 5 Nov, DECISIONS.)
- OPEN, 26 Oct decisions not yet built: hunt the real primaries for two-candidate-only seat polls (Fowler 2022
  Laidlaw, Pittwater 2023 Freshwater, Cowper and New England 2016) into `hand_keyed_primaries.csv`; if none found,
  try inferring the primary from the two-candidate split (J4 30 Sep is the refused relative). Prereg a shrunk,
  time-forward "seat polls under-call new independents" term (5 of 10 polled new independents under-called by
  9-22 points: Mayo, Warringah, Kooyong, Mackellar, Mount Gambier). Seat polls already reach new independents:
  mean miss 23.4 before the blend, 11.6 published, 10 seats (Wakehurst published 30.0, not 13.7).
- OPEN (review nit, 30 Oct, not blocking): the shipped MP-slope pool's tau^2 is inflated where one OTH_RIGHT member
  slope of -23.1 (n 1, se ~11) enters the DerSimonian-Laird sum: qld2015, sa2014, vic2014 get tau^2 ~0.57 (0 at most
  targets), so IND there keeps w 0.99 instead of pooling (`output/mp-slope-pooled.csv`; `R/mp_slope_pool.R:79-83`).
  The all-35 screen ran on this table. CORRECTED 5 Nov: not a variance artifact (sigma is already pooled); the one
  OTH_RIGHT seat sat almost on the statewide level, so its slope blows up (-23.1, z ~2.2) and supplies 4.6 of Q 5.4.
  Visible effect: the n-1 GRN member keeps w 0.63 (1.23 vs mu 0.92). A fix is a choice (robust tau^2, or no ratio for
  seats near the level), PARKED: live vic2026 unaffected (tau^2 0), old targets only, needs its own screen.
- OPEN, NIGHT MODEL (before 28 Nov). DONE 31 Oct: surge fade ON, flow floor 0.01, median ON, surge mixture OFF;
  surge-off replays settle it (Wentworth 2022 called 7:45pm with no patch; median within 0.001 on all three nights).
  Still wrong: draws with a different final pair are never corrected (Melbourne and Monash 2025); statewide draws
  shrink by the national mean counted, not the seat's; projection sd floors at 0.26.
  Fix 2 (each draw's flow from its own primaries) built, OFF (`--tcp-own-fp`): mixed on the three nights; needs flow
  uncertainty in the draws first. Melbourne and Monash 2025 are not night defects: the AEC withdrew its wrong-pair
  count, and from primaries alone the model is certain because flows are fixed (`AUSPOL_FLOW_SD=0`):
  `plans/prereg-flow-sd-2026-10-31.md`: REFUSED 31 Oct (moves no seat by more than 0.021).
- OPEN, FLOW MEANS in non-classic contests (31 Oct, Melbourne/Monash fed2025): Liberal -> Labor-over-Greens is 60.4 in
  EVERY seat checked (Melbourne, Monash, Wills, Cooper); in 2025 the Liberal how-to-vote put the Greens last and Labor
  won Melbourne on it. Melbourne also: afternoon GRN 47.5 vs actual 39.5 (ALP 21.7 vs 31.3). Idea: seat-level
  how-to-vote cards as a flow input. FOUND 31 Oct: the card mechanism already exists (`AUSPOL_HTV_FLOW`, R/htv_flow.R).
  BUILT 31 Oct (Pete): `AUSPOL_HTV_CARD_P=0.67` mixes both Liberal cards for vic2026 until it is published (live walk:
  Footscray ALP 0.72 -> 0.64, Pascoe Vale 0.56 -> 0.50); recency-weighted card rows `AUSPOL_HTV_RECENCY_HL` SHIPPED 1 Nov at "8"
  (`plans/prereg-htv-recency-2026-10-31.md` RESULT: 35 elections at 20k, -0.0001). OPEN, DATED: the day the Victorian Liberals publish their card, add a
  `vic2026,ALL,<greens_above_labor>,<source>` row to `external/reference/htv/liberal-alp-grn-order.csv` (the mix then stops).
  Review nits: duplicate region refused and the night `htv_card` test added (1 Nov). Timed 1 Nov: a night update with the
  card mix takes 23.9 s vs 11.4 s (20k sims): fine at a minutes cadence, and gone once the card row is added. CLOSED.
  Box Hill (our ALP 0.86 vs Sportsbet 0.25) traced to the proportional One Nation fill: `reviews/boxhill-trace-2026-11-01.md`,
  to walk with Pete (Box Hill, Ashwood, Glen Waverley).
  Evidence: `reviews/night-replay-real-feed-2026-10-31.md`, `reviews/night-replay-fed-2026-10-30.md`.
- OPEN, REPLAY METHOD: federal and vic2022 replay on real nights (`scripts/night_replay_feed.R`,
  `scripts/night_replay_vec.R`); the other state replays are still simulated (one block per seat, clock = 6pm + 4h x
  step). Calls at 0.99 need 20,000 sims. Tally Room "returned" times are post-recheck, not night times.
- NARROWED 4 Nov, FLOWS: `output/flows-estimated.csv` putting Greens -> Labor 3-7 points above the AEC's official federal
  flow (fed2019 86.16 v 82.21, fed2022 89.07 v 85.66, fed2025 95.06 v 88.19) is the estimator's KNOWN bias: it failed
  its own bar on 13 Oct (Greens 3-16 points above the answer key; `reviews/flow-estimation-validation-2026-10-13.md`).
  Federal rows reach nothing: federal flows come from the AEC's official table, and only `output/flows-state-blend.csv`
  (via `state_blend_flows()`, the QLD and SA backtest harnesses) reads the estimates, for QLD 2001-2017, SA 2002-2022,
  NSW 2003/2007, Vic 2002 and WA 2001, blended at w 0.5-0.79 with earlier published flows (sa2022 Greens 81.3).
  OPEN, small: whether the estimator's Greens bias also shifts those state blends; a backtest-only question.
- OPEN: Vic 2026 Edge Board (https://claude.ai/artifact/8U33eGJMiAbpZFSW2dsfQu) builder now in the repo:
  `scripts/build_edge_board_vic2026.R [capture.csv] [out_dir]` (EDGE_RUN=<suffix> picks our run) writes both board datasets;
  checked 1 Nov against the published files (same selections, prices, bookie probabilities, columns; seat panel identical).
  The board's 12:07am `-boardmain` run files are gone from output/, so a refresh needs a fresh suffixed fit_seats_full.R run
  and a new Sportsbet capture first. Seat panel, filters and links shipped 1 Nov 12:25pm.
- OPEN from the 1 Nov sa2026 absent votes: the 8 Cheltenham rows reach `output/candidacies.csv` with the vic2006 rebuild
  (Data and infra); Newland +1,047 and Black +26 untraced; add build_retiring_mp_cases.R to rebuild stage 0 (low value,
  its reader is off).
- OPEN from the 30 Oct walks (https://claude.ai/artifact/USv8sffhF1zbYagBGwjdQ3, `reviews/walks-wa2017-fed2019-2026-10-30.md`):
  WA seat layer ~5 pts above the statewide Labor level (36.4 -> 41.2) yet 5-15 short in the swing seats. PARTLY TRACED
  4 Nov (wa2017 seat means over 59 seats, actual ALP 41.9): level-pred 36.4 -> base_pred 38.9 (+2.5) -> xgb_pred_seat
  41.7 (+2.8; partly `forecasts.csv` rescaling five classes to 100 with no One Nation rows, sums 95.1 -> 100.1) ->
  published 41.3, One Nation's seat mean 4.2 vs its 7.7 level (actual 5.1). So the seat layer recovers most of a 5.8-point
  statewide miss ON AVERAGE. By previous Labor share there is no band bias (prev <30: our swing +13.0 v actual +14.0,
  n 29; 30-40: +6.6 v +8.4, n 11; >=40: +9.2 v +8.5, n 19); the misses are seat-specific: Southern River +8.3 v +20.7,
  Geraldton +4.1 v +16.6, Bunbury +7.1 v +15.4, Wanneroo +5.5 v +14.7, Kimberley +8.9 v +18.1. Next: what those five share;
  fed2019 shared miss (38% of margin error): is the correlated statewide draw wide enough? (4 Nov: needs each harness to
  write its statewide draw quantiles per election; then coverage of the 35 actual levels is one table. `output/fp-coverage.csv`
  is from 19 Aug and predates the shipped `AUSPOL_LEVEL_SD`.) Idea only: a per-person
  trend for Cupper (under-called every time). Closed Mildura checks (tree cut, swing floor refused, One Nation fill
  proportional; recheck the fill after vic2026 counts) are in DECISIONS 30 Oct and `backlog/journal-2026-10-30-to-31.md`.

- OPEN, Pete: returning independents. Both arms REFUSED 25 Oct (`plans/prereg-ind-return-2026-10-25.md`); the
  x0.61 multiplicative minor-field scale (a live-only train/serve split) was fixed by `AUSPOL_MINOR_ADDITIVE=1`,
  SHIPPED 25 Oct live only (DECISIONS). Still open: Mildura 25.6 vs Cupper's 33.9 (One Nation's fill takes the
  rest); live `FST1!` (no candidate-model split for vic2026); Kew and Hawthorn, where the bookies price independents
  far above us; Benambra (a NEW independent succeeding Hawkins).

- OPEN (bucket split, SHIPPED 6 Nov; DECISIONS): `minor-class-shares-resid-v2.csv` is built in `rebuild_forecasts.sh` (cached when
  current). Still open: give it vic2026 rows after nominations (`FST1!`), then v3 as its own screen. `backlog/overnight-2026-11-04.md` item 3.

## 2026-10-18 pipeline audit (READ FIRST; `reviews/pipeline-overwrite-audit-2026-10-18.md`, Sonnet, read-only)

20 findings where work is overwritten, doubled or ignored, or live and backtest diverge. Spot-checked in code 18 Oct.
Closed from it (journal): rules review (standard decision rule now heads `PRE-REGISTRATION-RULES.md`), seat-poll
TCP-consistency check, arm H shipped, heavy-tail arm T REFUSED 19 Oct, F21 surge_h fixed. Closed 18-21 Oct
(`backlog/journal-2026-10-16-to-2026-10-22.md`): F1-F3 shipped, F4 net-out shipped and published, F5 and F9 refused,
contest features / contest base / partial-contest arm A refused, first-term fill refused, seat context published.
- OPEN, from the 22 Oct old-election fill diagnosis (the `AUSPOL_TRAIN_DECAY_H=4` test of it REFUSED 25 Oct,
  half-life stays 8; DECISIONS, `plans/prereg-train-decay-4-2026-10-22.md`): Greens over-called in high-Greens seats by the trees (Melbourne, Griffith, Northcote);
  retiring Labor members about -2.0 (n 34); Dickson's published stage moved a correct tree LNP figure +5.5.
- OPEN, REWRITE BEFORE RUNNING: width arms A0/A1 (`plans/prereg-harness-sw-draws-2026-10-19.md`) were written for
  `AUSPOL_HARNESS_SW_DRAWS=1`; what ships is `=net` (F4), so they test a superseded setting. The question they carry
  stands: is the statewide spread `AUSPOL_FP_EXTRA_SD` 2.419 (fitted on the scored elections, a mild leak) too wide
  for states? Rewrite as `net` arms with a time-forward value before any screen.
- 25-26 Oct night screens: all refused, not passed or left off (verbatim in `backlog/journal-2026-10-25-to-2026-11-04.md`;
  results appended to each prereg). Departed arm B (`mean`) will not run (departed-origin closed 27 Oct, Pete).
- OPEN, DATED (final snapshot 25-27 Nov is the one that ships, per Pete 27 Oct; earlier weekly ones from ~3 Nov are
  for watching only, not the forecast): vic2026 salience snapshots. 26 Oct snapshot fetched, 0 of 101 batches linkable. All 500 candidates fetched
  18 Oct (window to 6 Oct), but that is before the campaign: nobody's search interest is rising yet (Premier 1.1 in the
  last 8 weeks vs 9.3 before), so batches cannot be linked and `jump` is not comparable with the backtests' polling-day
  values. Each refresh: `AUSPOL_SALIENCE_TO=<date> Rscript scripts/fetch_salience_vic2026_full.R` (~100 requests,
  resumable; anchor Ben Carroll since 4 Nov: Allan was replaced as Premier 28 Jul 2026 and her series linked 0 of 101
  batches; check the anchor against `leaders.csv` before each snapshot), then `scripts/build_vic2026_salience_jump.R`
  (output/vic2026-salience-jump.csv). Local runs DO use a vic2026 salience corpus (live walk log: XG5 43 cells,
  31 surge seats); the CI publish does not have one yet (DS3 falls back to flat surge_h), so the surge double count
  (`AUSPOL_SURGE_LEVEL`) reaches the published forecast only once a corpus reaches CI.
- OPEN F8, F10, F12-F15, F17, F19 (F5, F7, F9 REFUSED; F16 NOT PASSED 29 Oct; F18 walk 1 done; IND override shipped as arm H): post-xgb tables fitted
  on residuals the shares no longer carry, HTV overwriting xgb flows, and the rest of the audit's list
  (`reviews/pipeline-overwrite-audit-2026-10-18.md`). (F20 and its `AUSPOL_MINOR_DEFECT` gap: DONE 23 Oct, journal.)

## 2026-10-17 (READ FIRST)

Shipped and published that day (Lib/Nat split `AUSPOL_COALITION_SPLIT=1`, 15 Oct full rebuild, surge flag "none",
party-cor off) and the phantom-votes arm REFUSED: all in the journal and DECISIONS.
- OPEN, bigger than composition spread C (parked, `reviews/composition-spread-2026-10-17.md`) or the refused error
  distribution E (`AUSPOL_ERROR_DIST`), and the place to try width + tails together: errors are HEAVY-TAILED everywhere (0.57% of non-IND-seat cells miss by 4+ sim
  sds, ~100x a bell curve; kurtosis 20). A fat-tailed per-cell error (fitted time-forward) is the general fix for
  floor seats. NB the seat-poll form of it (arm T, mixture on model error) was REFUSED 19 Oct (-0.0004, SE 0.0052).
- MEASURED, PARKED per-class level bias (17 Oct, scratchpad levelcorr.R): statewide level over-predicts the Greens in
  23 of 35 elections (formal-weighted -0.73); all-class time-forward correction loses (1.402 -> 1.426), GRN alone
  helps slightly (prereg-poll-level-centring arm C, never run). Revisit GRN alone when more elections are in.
- OPEN FFD1 is fitted on the gap FF1 checks (passes by construction; Pete's call, 15 Oct). Validate it when a
  second federal cycle has firms that both name and fold One Nation.

## Still open from 14-15 Oct (collapsed 15 Oct evening; history in DECISIONS and `plans/overnight-2026-10-14.md`)

**Open work, in order:**
- OPEN sa2018 +0.025 from the new inputs: LNP -0.3 pts broadly where IND/GRN rose; which input not isolated (screen
  sa2018 with salience off). nsw2019's +0.026 is Barwon alone (SEAT-REGISTRY). Lead (15 Oct): under the leaking
  surge flag, sa2018 IND (SA-Best, +13.9 actual) was "surging" from its own result; read the surge arms first.
- OPEN wa2017 / wa2013 regressions: Hillarys and Churchlands traced in SEAT-REGISTRY; Lib/Nat two-candidate part SHIPPED
  17 Oct. The WA 2017 swing-seat lift is now traced in NEEDS PETE ("OPEN from the 30 Oct walks", 4 Nov).
- OPEN (finding 17 Oct, not acted on): WA's Coalition over-call is a statewide LEVEL miss, not seat-level. Mean
  Coalition primary error (ours - actual) in one-candidate seats: NT +3.61 (SE 1.08), WA +2.46 (0.34), Qld +0.98,
  NSW +0.45, fed +0.05, SA -0.82, Vic -0.87; WA by election 6 of 7 positive (wa2005 +4.68, wa2001 +3.42, wa2017
  +3.27). A jurisdiction bias in the level model is the lead; `screen_level_share.R` first.
- OPEN NT seat layer: over-confidence fixed by the size spread (20k: nt2016 0.80, nt2020 0.65, nt2024 1.07, from
  0.99/0.81/1.41); still weak, and new parties start at zero share.
- OPEN qld2017: One Nation / Katter seats given ~0 (emergence); qld2012 Katter polled inside Others.
- OPEN (hazard for arms, not live) pooled-fits audit 2026-10-16 (`reviews/pooled-fits-inventory-2026-10-13.md` and
  after): LEAVE-ONE-OUT but OFF at published flags, so any arm switching them on measures a leaked number:
  `fit_xgb_primary_sd.R:108` (`AUSPOL_XGB_PRIMARY_SD`), `fit_flow_drift.R` (`AUSPOL_FLOW_CELL_SD`),
  `fit_insurgency_risk.R:33` (`AUSPOL_INSURGENCY_SHRINK`), `party_positions(exclude=)` in `R/reentry_prior.R:288`,
  `xgb-primary-v6-oof-predictions.csv` (static-cache arm). (`state_swing_adjustment()`, dead code: DELETED 25 Oct on
  Pete's yes, DECISIONS.)
- OPEN (lead, NOT a result) sitting non-major members (Sonnet, 16 Oct; scratchpad `minor-mp/`): published-path
  signed error +0.36 pts, SE 1.11, n 84 sitting minor/IND members in 29 elections: no overall over-call. Hints only:
  falling own vote -3.8 (SE 3.9, n 9); trend slope +0.26 (SE 0.17); **leader-seat bonus on a sitting minor member
  -7.8 (SE 4.1, n 4: Buderim qld2017, Traeger, Melbourne 2022/2025)**. One feature only, so a to-do, not a refusal.
  If pursued: shrunk "falling own vote" term; re-check the leader bonus for minor-role leaders (n 7, se 3.4).
- OPEN Hare-Clark candidate-level count loses on zero-probability new independents (needs a heavier tail).
- OPEN fed2007 Newspoll gaps (Jul 2005-Apr 2006, Jul-Sep 2006, Jul-Nov 2007) and Nielsen/Galaxy archives.
- OPEN fed2028 live forecast build (decided 13 Oct; 8-11 days).
- OPEN SEAT-REGISTRY entries for the new worst seats (DATA/MODEL/POLL registries: regenerated 4 Nov, `f453b62b`, `14f55eba`).

## 2026-10-11 to 2026-10-12: still open (collapsed 15 Oct)

Shipped and merged (PRs #119-#125). **ORDER still matters: publish a rebuild (AUSPOL_PUBLISH=1) BEFORE merging to main**
whenever a change adds a file `forecast.yaml` downloads. Refused, built and off (do not rerun without a new idea):
leader ratings as a model input, trend-replaces-blend, poll-level centring, the two-way person rule, statewide poll
weighting by track record, seat-poll precision blend, typical-vote independent models.

- Poll weighting (Pete wants "a LOT better"): statewide lean by company, sponsor, method and age CLOSED 4 Nov (all six arms
  refused; top of this file). Federal breakdowns in the state trend: built, tied, left off 5 Nov (Pete). `reviews/poll-weighting-inventory-2026-10-12.md`.
- OPEN move off AE (`reviews/ae-dependence-audit-2026-10-13.md`): (b) language-model extraction of the Poll Bludger
  posts, the stronger version, not tried.
- OPEN leader ratings: drift from months out needs horizon scoring. (The blog chart is DONE: inthegame-blog PRs #890
  and #895, "The leaders" in `politics/_forecast-body.qmd`.)
- CORRECTED 5 Nov: the breakdowns did NOT stop. BludgerTrack still publishes them (refetched 5 Nov, newest fieldwork
  25 Oct, raw `external/reference/polls/pollbludger/raw/bludgertrack/fed2028-current-2026-11-05.xml`; branch
  `fed-breakdowns-trend-1105` builds the union, 704 polls). OPEN, small: feed BludgerTrack's state rows into
  `output/fed-state-breakdowns.csv` so the shipped blend stops decaying (FK3 trips ~20 Nov). Wikipedia's part: deleted the sub-national
  sections from the fed2028 page on 24 Oct (revision 1381724607, "excessive detail"; checked 5 Nov). The last
  pre-deletion revision (1381712590, saved as `raw/fed2028_opinion-oldid1381712590.html`) parses to the same 471 polls
  as ours, so nothing was added after 6 Oct either. Adding `fed2028_opinion` to the CI fetch would lose rows (PM2!).
  `build_fed_state_breakdowns.R` now refuses to write fewer or older polls than on disk (FK2!, proven on a broken
  input). Live effect: the blend's federal share (`AUSPOL_LEVEL_FED_R` 0.15) decays with no new data; FK3 (45 days)
  would trip ~20 Nov.
- OPEN fed2025 vs AEF (0.377 vs 0.303; Pete asked 18 Oct): base_pred minor-party growth as flat points tested and
  REFUSED (logit, proportional, growth-ratio slopes all worse; `prereg-growth-ratio-features` RESULT; journal has the
  numbers). Remaining: fed2025 drifted 0.318 (30 Sep) -> 0.377 across many changes (a snapshot bisect would separate
  leak-fix costs); 15 Labor wins called Coalition (Labor primary under-called ~10 pts in the marginals: Bennelong
  32.9 vs 45.4); 4 independents favoured who lost (Wannon, Monash, McMahon, Cowper). Live lead: a seat-type term
  (urban/regional) on the minor deviation slope, time-forward.
- OPEN statewide flow shocks, GENERAL (17 Oct, scratchpad flowvar.R, 13 transfers files, 32 elections): 0.32-0.59 of
  the variation in the flows that decide seats is BETWEEN elections (LNP->ONP 0.59, ONP->LNP 0.42, GRN->ALP 0.39,
  OTH_RIGHT->LNP 0.32); the count draws each flow's noise per seat. NEXT (needs memory; after the CE deciding run):
  per-event residuals against the SHIPPED flow model (extend scripts/score_flows_oracle.R), then prereg one shared
  draw per simulation per flow, sized time-forward and shrunk. Liberal-to-ON varies 54-85% by election.
- OPEN re-score Richmond/Footscray/Brunswick/Preston/Pascoe Vale 2022 after AUSPOL_LEVEL_RECENT; shrink the
  person-rule slope toward the ratio carry (Pete, 2026-10-11).
- OPEN miss-table seats traced but not fixed: Malvern 2022 (O'Brien under-called in base_pred), Bankstown 2023 (xgb
  cut ALP 55.8 -> 49.8). Traced 16 Oct (Sonnet): **4 of 5 are the seat-poll blend** (`seat_poll_blend_apply`,
  R/seat_poll_blend.R:909; weight from `seat_poll_weight()` at :738) pulling ONE poll at a fitted weight ~0.87 (Parkes 2022, New England 2022, Dawson 2022,
  McMahon 2025). Poll "Others" lumps land in one class (`.seat_poll_known_class_map` :1341 splits only when
  ONP/OTH_RIGHT >= half the lump). Traeger 2024 separate (Katter's falling trend carried flat; leader bonus +3.0).
  Already refused: public-only sources (2026-10-07), precision-scaled blend (2026-10-09). Untried: splitting a poll's
  "Others" lump by our own class expectations; a weight per election rather than one pooled weight.
- OPEN speed (`reviews/fast-iter-profile-2026-10-11.md`): read-set cache keys for defectors, personal prior vote,
  departed slope, salience (~25 s of a 54 s vic run); seat-poll memo keys on every switch.

**Running jobs when memory is short:** Claude Code reaps background shells below ~4 GB available. Run stage 6
harness by harness in the foreground, then `AUSPOL_REBUILD_FROM=7`; `AUSPOL_REBUILD_SLOTS=1` caps parallelism. A
full rebuild outlives the session when started with `Start-Process "C:\Program Files\Git\bin\bash.exe"` (not
`bash.exe` from PATH in PowerShell, which is WSL's).

Tools: misses via `scripts/biggest_misses.R` / skill `biggest-misses` (never `forecasts.csv`).

## 2026-10-07 to 2026-10-08: archived handoffs

Verbatim in `backlog/journal-2026-10-07-to-10-08.md`. Still OPEN from them:
- OPEN: NSW 2027 page, blog side: seat pages need an election switch in inthegame-blog's `politics/seat.qmd` (still
  Victoria-only 23 Oct; `politics/nsw.qmd:43` has `seatPage: false`; data on R2 since PR #107). Owned by the `inthegame-blog` session.
- OPEN: fed2025 seat polls deserved weight ~0.13 and got 0.55; no pre-election signal found yet. Worst case McMahon,
  Camenzuli (IND) published 29.0, actual 9.8: ONE poll, Compass Polling 8 Apr 2025 (opt-in SMS link, n=1,003, IND 41);
  base_pred 6.0 and xgb 4.9 were both under, so the 29 is the seat-poll step (AUSPOL_SEAT_POLL_IND_MAP). ROOT: the
  seat-poll weight uses age, sample size and kind, NOT the pollster's record, method or agreement with other polls.
  DONE 18 Oct: every seat poll classified (`external/reference/polls/seat-polls/poll_methods.csv`,
  `reviews/seat-poll-methods-2026-10-18.md`). PARKED 5 Nov (told Pete): the by-method/sponsor/pollster weight prereg
  waits with "Seat polls: PARKED" under Model, open (arms S, T, U refused; one or two earlier polled elections). Dirty pollster
  labels: checked 23 Oct, NOT reaching the model. The blend takes the firm from `poll_methods.csv`'s `pollster_clean`
  (`R/seat_poll_blend.R:174`; "YouGo (MRP)" -> YouGov, "44%" -> uComms, sponsors -> unknown), and the "44%" duplicate of
  uComms Brisbane 20 Mar 2025 has no fieldwork date, so `:89` drops it. Raw `seat_polls.csv` labels are cosmetic.
- Not doing, by decision: the in-browser simulator (~40 h); the 2.5-point knots already feel live. Revisit if Pete wants two sliders at once.

## 2026-09-27 to 2026-10-05: archived sessions

Verbatim in `backlog/journal-2026-09-27-to-10-05.md` (handover detail in `HANDOVER-2026-10-05.md`). Live from them
is folded into the sections below (Model open, Hygiene, Data and infra); nothing live is left only in the journal.

## Dated, cannot move

- **9 November 2026, 12 noon: nominations close; the VEC's Candidates set-up file lands Tue 10 Nov.** PREPPED
  30 Oct: `scripts/fetch_vec_candidates.R --file=<State2026MediaFileCandidatesV2.xml> --year=2026` then
  `build_candidacies.R` (`docs/PIPELINE.md` section E; proven on the 2022 file, 731 of 731 matched with the same
  class; dry run of the build and of `AUSPOL_NOM_LIVE=1` passed on a stand-in list; Daily Eight item on 10 Nov).
  Then `build_candidacies.R` writes vic2026 rows so
  `candidate_returns(vic2022, vic2026)` and the flow model's `dest_same`
  features go live; rerun the three salience scripts named in
  `published_flags.R` (`victoria_salience_dryrun.R` proves the path on
  vic2022); revisit candidate-count weighting once counts are facts.
- **The day Liberal how-to-vote cards are published**: add
  `vic2026,ALL,<TRUE/FALSE>,<source>` to
  `external/reference/htv/liberal-alp-grn-order.csv` (~8 points of 2CP in
  inner-Melbourne ALP-v-GRN seats). Until then `AUSPOL_HTV_CARD_P=0.67` mixes both cards (31 Oct; see FLOW MEANS above).
- **Nomination-day procedure**: `docs/PIPELINE.md` section D. Upload `candidacies.csv` to the `shipped-models`
  release (CI downloads it from there), then set `AUSPOL_NOM_LIVE` to "1" in `published_flags.R`. The gate is
  MANUAL by Pete's choice and never opens on date alone. Also wire the live candidate split into
  `fit_seats_full.R` (`fit_minor_candidates.R` on vic2026 rows; v44's bucket split is backtest-only).
- **10 Nov, after the VEC list (NEEDS PETE before it reaches the forecast)**: per-candidate predictions for vic2026,
  `AUSPOL_MC_LIVE=vic2026` (`PIPELINE.md` E step 5; built and checked 6 Nov on the pre-nomination list). Wiring them into
  the live bucket split changes the published path (a vic2026 row in the shipped file + `forecast.yaml` fetching it).
- **28 November 2026**: election night.

## Model, open (triaged 2026-09-19; nothing here blocks Victoria)

- **(0) The day-before statewide forecast** decides the ledger; every
  seat inherits its miss. Evidence, all in
  `reviews/statewide-forecast-audit-2026-09-20.md`: per-pair audit
  (`scripts/audit_statewide_forecast.R`); the log-loss gap to AEF is six
  95%+ favourites that lost (calibration by band otherwise identical,
  roadmap item 5 DONE); the TCP gap is nsw2023; nsw2023 walked end to end
  (trend right, Labor's fall = phantom vote + published/implied two-party
  gap + fundamentals). The anchor-implied arm was REFUSED 27-28 Sep (22 pairs, t -0.77;
  `backlog/journal-2026-09-27-to-10-05.md:526`; `AUSPOL_ANCHOR_IMPLIED` "0"). OPEN: wa2017 and fed2019
  still to walk with Pete (questions in the review). Refused arms:
  `prereg-fundamentals-drop-fed-aligned`, `prereg-phantom-minor-vote`.

- **NSW variance / floor seats**: per-cell fat tails already SHIP (`AUSPOL_ERROR_DIST=1`, `scripts/published_flags.R`,
  17 Oct; excess kurtosis 2.8-18 by class). Pete (26 Oct): first count floor seats (winner under 1%) under the
  shipped config on all 22; build a seat-level variance multiplier only if they remain.
- **One Nation in Victoria**: polls ~25%, Nepean by-election 24.5%,
  concentration fitted on one election (sa2026). `AUSPOL_ONP_CONC_SD` fixes
  sa2026 but regresses vic2022 (IND coupling); MacKillop's boundary mismatch.
  Not shipped. The Victorian ONP level sits 0.03 inside the poll-tracking
  bound (WATCH; analogue WA 2017 says trends OVER-state such surges).
- **Demographic axis**: real (permutation control) but one coefficient is an
  order of magnitude too small; a level interaction needs its own prereg.
  Parked by Pete.
- **`base_margin` scoped arm** (away from ALP, or to sa2026/wa2021-shaped
  cases): the full form refused at seat level (+0.004) despite primary gains.
- **State-deviation**: v2 refused 2026-09-19 (one landslide behind the
  state-election term). Reopens with Tasmanian state results in the corpus
  (7 of the 12 worst state-years are TAS/ACT/NT).
- **Overcalled independents**: the `ind-overcall-1025` re-stand arm REFUSED 30 Oct (see "Builds from 26 Oct branches"). Successor overcalls
  (Morwell, Mildura, Kavel, Finniss) are a separate item, not started; departed-hold refused.
- **Scenario tool** (hold the party exactly at X, others give way by regression: Pete's choices): build NOT
  started, about 40-50 h (a guess); stage 1 is brute-force `AUSPOL_FORCE_FP` runs, also the test oracle
  (`plans/scenario-tool-scoping-2026-10-03.md`). Request register: NOT DONE.
- **Early WA pairs and fed2007/2010 get no leader-seat bonus** (as-at predictions start at fed2010): extend
  the as-at corpus back if the data allows.
- **Seat polls: PARKED** after arms S, T, U refused; the weight is fitted on one or two earlier polled
  elections. Resume only with a source adding earlier polled elections. Change seats beyond the statewide miss
  (Parramatta, Heathcote): walk examples with Pete before any rule.
- **Time-forward fits still use `min_n` cliffs**: `R/split_slope.R:395,416` sit in `fit_conditional_slopes()`,
  which the shipped config never calls (`AUSPOL_FIT_SLOPES=0`). Live: `fit_major_departed_slope()` falls back to 1.0
  below 40 seats (fed2007, fed2010, sa2010, wa2001, wa2005, wa2008). `AUSPOL_SLOPE_SHRINK` shrinks toward 1, not the
  pooled slope, refused 29 Sep. `AUSPOL_DEPARTED_POOL` SHIPPED 6 Nov (no cliff for the departed slope; DECISIONS); the
  `fit_conditional_slopes()` cliffs above remain, unshipped code.
- **Teal/independent under-call** (Curtin, Goldstein, Mackellar, Wakehurst):
  PARKED by Pete. Overall we lead AEF on independents (36 winners: 16.7 vs
  19.7 log loss). Wave term blocked (`reviews/wave-term-blocked-2026-09-07.md`).
- **Final-two flow for excluded-party cells** (roadmap item 3): DEMOTED,
  the TCP gap is item (0) (audit review). Calibration by band: DONE.
- Smaller known limits: intra-Coalition seats have no TCP class (2 of 660, AEF has the
  same limit; zero vic2026 seats affected today); Orange/Wagga `own_prev_pcv` NA for
  by-election winners (needs a feature, fallback fill refused); the statewide
  covariance pools every era; WA has no surge-v2 hazard.

## Harness and pipeline hygiene
- DONE 6 Nov (cache added, skip logic tested on 5 cases) `rebuild_forecasts.sh` pre-stage `fit_minor_candidates.R` (v2, added 6 Nov for the shipped bucket
  split file) costs 6.4 min every full rebuild (7:21:28-7:27:54) and its output was byte-identical to the tracked copy. Cache it:
  skip when `output/minor-class-shares-resid-v2.csv` is newer than `output/candidacies.csv`, the audit file it reads, the script
  and every `R/*.R` it load_all()s (memo key = everything it reads). Do NOT edit the script while a rebuild runs (bash reads it as it goes).
- OPEN (speed, CORRECTED 6 Nov 12:40pm) stage 4 (`fit_xgb_primary_asat.R`) 1,664 s for 31 models on a full retrain. The "287 s before"
  I compared it with was `driver.log` of 19 SEP (22 elections, ensemble 1); not the kernel leak. Cost per model grows with the corpus:
  `xgb.cv` uses ONE FOLD PER EARLIER ELECTION (sa2026: 34 folds, 401 rounds, 142 s; sa2010: 4 folds, 1 s), times `AUSPOL_XGB_ENSEMBLE=3`
  training. Its skip-if-current cache only helps when base_pred is unchanged, which a model change never is. Options, each a model
  change needing a screen: cap CV at ~5 grouped folds (est. ~5x faster on late targets; changes nrounds), or fit targets in parallel
  processes (memory). Stage 3 (533 s) not yet broken down the same way; time it from its own log before guessing again.
- Both branches below RECREATED 25 Oct on Pete's yes (local only, not pushed).
- Branch `fed-timing-resume-fixed` (b21fb77, unmerged, NOT through the review gate or `check_like_ci`): fixes
  the federal `PARTY_COR` loop leak (a full fed run simulates every pair with the LAST pair's matrix; dormant
  at published defaults because `AUSPOL_FORECAST_MODE=1` skips the matrix; live for fed with FORECAST_MODE=0),
  adds per-pair timing and an opt-in resume cache (`AUSPOL_FED_RESUME=1`). Ran live: outputs byte-identical.
  Untested: more than one pair, a kill mid-run. `FLOW_SD` has the same loop leak, unfixed (dormant,
  `AUSPOL_FLOW_SD_BY_SOURCE` default 0). Also `instrument-backtest-fed-timing` (ae91f62), paused.
- Main-tree `R CMD build` failed after ~6 min once (2026-10-04) while the fresh-clone check passed. Likely
  cause, unproven: the junctions in `.claude/worktrees/*/output` and `/external` into the main tree. Remove
  with `cmd /c rmdir` (never a recursive delete) before running the check in the main tree; the
  `zero-order-late` worktree's `.wt-orig` folders then get renamed back.
- Diagnosed, not built: widening simulated variance for the majors' floor
  seats (`sd_override` into the WA harness); WA personal-vote transfer helps
  Pilbara and hurts WA overall (one seed).

## Data and infra

Closed 2026-09-19/20 (DATA-REGISTRY, DECISIONS): poll snapshot + zero-byte
guard, empty-column dictionary failure, vic2022 VEC-official TCP truth,
Tasmanian primaries table and state-swing prior rows, district-to-region
table on the blog page, To Do reminders (9 Nov, HTV row, VEC email).

- OPEN (5 Nov): `output/candidacies.csv` has `elected` NA on all 459 vic2006 rows, so vic2010 gets no departed-member
  or sitting-member flags. Builder FIXED on dev (winners from `vec-2006-vic-tcp-basis.csv`, BC7v; ALP 55, LNP 32, IND 1).
  Dry run: only vic2006 `elected` (459 rows), vic2010 `historic_elected` (4 -> 79 returning) and the 8 pending sa2026
  absent-vote rows change. SCREENED 5 Nov (1,000 sims, baselines on old vs rebuilt inputs via AUSPOL_QUICK_SRC_OUTPUT,
  output/ untouched): vic2010 seat log loss 0.2281 -> 0.2335 (+0.0054, seat SE 0.0021, WORSE; Gippsland East: Ingram now
  flagged sitting, lost; Ballarat West, Brunswick not traced), sa2026 0.2368 -> 0.2364. KEPT (Pete, 5 Nov: correct data;
  the backtest trees are frozen as-at models trained before the fix). It lands with the 10 Nov nominations rebuild.
  OPEN: re-measure vic2010 after the next full rebuild retrains the trees.

Still open:
- Federal results as a correlated signal for state seat lean: needs
  seat-boundary matching (`external/reference/boundaries/` has CED 2016).
- GDELT parked (needs a GCP project); Census 2006/2001 have no bulk pack.
- OPEN: ITG page: a seat map (regions are in the JSON now), per-seat cards, a forecast-over-time chart.

## Awaiting Pete

Nothing (departed-rate answered 29 Oct, census 27 Oct; DECISIONS).
