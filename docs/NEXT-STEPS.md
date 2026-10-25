# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before the 2026-09-19 rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`;
closed items of 7-19 Oct, verbatim: `backlog/journal-2026-10-07-to-2026-10-15.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30; slimmed 2026-10-19.

## NEEDS PETE

- OPEN, 25 Oct evening state (all switches below are on `dev`, default off, reviewed by Sonnet):
  1. One Nation new-seat rule + Senate ranking (`AUSPOL_ONP_NEWSEAT_RULE`, `AUSPOL_ONP_ORDER=senate_rank`): screens
     running (A, B, B v A, then all-pairs guards); Pete ships live if not worse by > 1 SE. Bendigo East overshoots in
     the live walk (ONP 0.69 vs market 0.29): trace before shipping. `plans/prereg-onp-newseat-rule-2026-10-25.md`.
  2. `AUSPOL_LIVE_LEVEL_PRED_TREND=1` SHIP DECIDED (Pete): flip in `published_flags.R` after the run queue's last
     launch (~02:15), before the 07:00 refresh; walk showed 0 change today.
  3. Sitting-member rule (`AUSPOL_RETURNING_MEMBER_RULE`): go/wait on the candidacies rebuild + retrain from stage 3
     (~2 h detached, after the F7 deciding run). 66 of 108 by-election winner names are from Wikipedia, unverified.
  4. F7 deciding run 03:15 26 Oct (`deciding-runs/20261025-1801-f7-demo-resid-full/`): Pete decides on its result.
  5. Delete `C:\dev\auspol-iso-decay4` (16 GB, decay4 done)? Pete's call.
  6. `dev` -> `main` PR: pre-PR review done (0 Important after fixes); needs full `check_like_ci.R` then open.
- OPEN, run queue (detached agent, one at a time, >= 6.5 GB, no launch after 02:15): One Nation arms; surge-level
  all pairs (AEF-7: guard -0.0016, SE 0.0011; primary within 1 SE); F8 arms N and RN (arm R AEF-7 +0.0008, SE
  0.0021); GRN_TREE_SHRINK; departed-origin A; width A0/A1; level-conserve (base/final/both); port 3C.
- OPEN, building (Opus worktrees, 25 Oct evening): F16 `AUSPOL_ROW_SHIFT_EXACT`, F18 `AUSPOL_NOM_ZERO_PRE_XGB`,
  dead-party level `AUSPOL_LEVEL_DEAD_PARTY` (nt2024 Territory Alliance carried at 14.8).
- FOUND 25 Oct, LIVE in backtests: nsw2019, sa2022 and vic2022 predict One Nation 0 in every seat it contested
  (party list from the previous election); fixed only under `AUSPOL_ONP_NEWSEAT_RULE=1`.

- OPEN, DATED (Tue 27 Oct, 3, 10, 17 and Fri 27 Nov): vic2026 benchmark capture. Built and run 22 Oct (all four
  sources, `docs/benchmarks/vic2026/2026-10-22/`). Each date: `Rscript scripts/snapshot_benchmarks.R`, plus the GES
  Chrome step (`scripts/ges_read_calls.js`; plan Amendment 1), rerun the script, commit the calls folder, rerun
  `scripts/build_data_registry.R`. Scorer BUILT 23 Oct: `Rscript scripts/score_benchmarks_vic2026.R --results=<csv>`
  (`district, winner, status`; winner as the VEC prints the party) once every district is declared; `--dry-run` passes
  its known answer now (ours 88/88 against its own favourites). Still to build: the VEC 2026 results file itself.
  Roy Morgan dropped 21 Oct (no seat winners) (`plans/external-benchmark-vic2026-2026-10-20.md`).

- OPEN: F7 screen (demographic correction in full, `AUSPOL_DEMO_RESID_FULL=1`, off).
  `Rscript scripts/quick_arm.R "AUSPOL_DEMO_RESID_FULL=1" --pairs=all --sims=1000 --slots=1 --no-reuse`, then the
  scorer on its two cache keys, `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\26f52d2d-b035-4f2a-b249-4b5e6d757448\scratchpad\score_f7.R`
  (`plans/prereg-demo-resid-full-2026-10-19.md`). Stopped by the memory watchdog 18 Oct and 19 Oct (~07:45, compile
  step; a citiusverse export held ~5 GB). Run only with the machine otherwise idle.
  22 Oct: Pete said go, NOT launched: 4.8 GB available of 31.5 with no large process (kernel paged pool 10.2 GB,
  non-paged 2.8 GB, up since 15 Oct: a leak only a reboot clears). Pete chose no reboot; run F7 after the next one.
  RAN 25 Oct 16:45-17:54 and needs PETE. The primary passes: ALP+GRN squared share error -0.0653 (SE 0.0499), 5,862 cells
  in 35 elections. The guard is flat: seat log loss -0.0001 (SE 0.0006, 2,931 seats); AEF-7 is -0.0020 (SE 0.0015).
  Two clauses refuse it. Leave-one-election-out fails without nsw2023 or fed2019, and qld2020 is worse by 2.15 of
  its own SE. The split is in the prereg's RESULT section. PETE OVERRODE both clause refusals (25 Oct evening): 20k deciding
  run scheduled 03:15 26 Oct, `deciding-runs/20261025-1801-f7-demo-resid-full` (code 5dd64ec). Read its marker next session.

- OPEN, Pete: returning independents. Both arms REFUSED 25 Oct (A-final; A-base under Amendment 1: target-seat log
  loss +0.0058, SE 0.0104, 0 of 33 leave-one-out; `plans/prereg-ind-return-2026-10-25.md`). Lead, untraced: the vic2022
  harness already has Mildura IND at 38.7 (actual 41.2) and the arm never touched it, so the vic2026 cut (33.9 -> 17.6
  via the x0.61 minor-field scale) may be a LIVE-path-only effect. TRACED 25 Oct: it is a train/serve split.
  `fit_seats_full.R:1251-1272` MULTIPLIES IND/OTH_RIGHT/OTH cells by forecast OTH / 2022 others (x0.61), so a big
  personal vote loses 39% of itself. The six state harnesses never take that path: each class gets its own statewide
  level from the bucket split (vic2022 log `FST1 ... IND 0.35`; `BV0` IND 5.7 forecast vs 5.5 actual) and moves by
  ADDITIVE `dev_slope()` (`backtest_candidate_vic.R:644-648`). Only `_fed.R` scales multiplicatively. SHIPPED 25 Oct,
  live only: `AUSPOL_MINOR_ADDITIVE=1` (federal screen neutral; fed harness stays on `_FED=0`; DECISIONS). Still open:
  Mildura 25.6 vs Cupper's 33.9 (One Nation's fill takes the rest); live `FST1!` (no candidate-model split for vic2026).
  Why it matters: Mildura (Cupper 33.9 in 2022 -> 17.6 published, cut by the x0.61 minor-field scale), Kew and
  Hawthorn; the bookies price independents there far above us. Not covered: Benambra (a NEW independent succeeding
  Hawkins), still OPEN.

## 2026-10-18 pipeline audit (READ FIRST; `reviews/pipeline-overwrite-audit-2026-10-18.md`, Sonnet, read-only)

20 findings where work is overwritten, doubled or ignored, or live and backtest diverge. Spot-checked in code 18 Oct.
Closed from it (journal): rules review (standard decision rule now heads `PRE-REGISTRATION-RULES.md`), seat-poll
TCP-consistency check, arm H shipped, heavy-tail arm T REFUSED 19 Oct, F21 surge_h fixed. Closed 18-21 Oct
(`backlog/journal-2026-10-16-to-2026-10-22.md`): F1-F3 shipped, F4 net-out shipped and published, F5 and F9 refused,
contest features / contest base / partial-contest arm A refused, first-term fill refused, seat context published.
- OPEN, decision for Pete (finding, 22 Oct): completing the incumbent/retiring fill for 11 OLD elections (nsw2011/15,
  nt, qld2012-17, sa2010-18) made the 24 untouched elections worse by +0.0040 (SE 0.0012) through retraining alone.
  CHECKED 22 Oct: the fill is NOT wrong in the 11 (absent members unflagged 26.2% vs 25.2% in the 24; flagged but
  standing 1 vs 2). AEF-7's +0.0038 is three upsets: Ipswich West qld2024 +1.89 (P(ALP) 0.141 -> 0.021; LNP primary
  39.6 -> 45.6 vs actual 33.5; LNP by-election winner died before the election, so an incumbent party with nobody
  sitting), Morwell vic2022 +0.79, Kalamunda wa2025 +0.45, of +2.61 total. By-election gains in general are not
  over-called: 16 of 22 held at the next general election, our mean P 0.64. Scratchpad fillcheck/{check,moved,revert}.R.
  Pete chose to test it: `AUSPOL_TRAIN_DECAY_H=4` (`plans/prereg-train-decay-4-2026-10-22.md`). quick_arm cannot
  screen it (the decay acts at stage 4 and quick_arm reuses cached tree predictions), so one isolated rebuild from
  stage 4 is SCHEDULED 01:00 23 Oct (Scheduled Task `auspol-decay4-rebuild`, at 883a773, ~45 min). It refuses to start
  below 8 GB available. Next session: read `deciding-runs/decay4-rebuild/STATUS`, then score per the prereg.
  REFUSED 23 Oct 01:00 as expected: "only 2989 MB available (needs 8000)" (kernel pool leak, see F7 above). That is
  memory, not the arm. Refused again 25 Oct 10:55 after the reboot: 6,609 MB available (paged pool fine at 0.9 GB, but
  ~23 GB committed with no process over 1 GB). `schtasks /run /tn auspol-decay4-rebuild` (~45 min) once 8 GB is free.
  RAN 25 Oct 14:31-16:14 and REFUSED. Primary (24 untouched elections, 2,267 seats): -0.0007 (SE 0.0011), within 1 SE.
  Guard (35 elections, 2,931 seats): +0.0001. Leave-one-election-out fails, vic2010 is worse by 2.9 SE, and the gain is
  the three upsets alone (+0.0001 without them). The 11 refilled elections are +0.0026 (SE 0.0014). Half-life stays at
  8. Result section in the prereg. `C:\dev\auspol-iso-decay4` (16 GB) can be deleted.
- OPEN, from the same diagnosis: Greens over-called in high-Greens seats by the trees (Melbourne, Griffith, Northcote);
  retiring Labor members about -2.0 (n 34); Dickson's published stage moved a correct tree LNP figure +5.5.
- OPEN (Pete): the 28 old notes in the ledger page's notes store now duplicate `docs/aef7-seat-notes.csv` under "Your
  notes"; clear them only on his yes.
- OPEN: width arms A0/A1 (`AUSPOL_FP_EXTRA_SD` 0 / 1.2) pre-registered, not yet run (needs the memory F7 needs).
- OPEN, DATED (from ~2 Nov, weekly; final snapshot 25-27 Nov): vic2026 salience snapshots. All 500 candidates fetched
  18 Oct (window to 6 Oct), but that is before the campaign: nobody's search interest is rising yet (Premier 1.1 in the
  last 8 weeks vs 9.3 before), so batches cannot be linked and `jump` is not comparable with the backtests' polling-day
  values. Each refresh: `AUSPOL_SALIENCE_TO=<date> Rscript scripts/fetch_salience_vic2026_full.R` (~100 requests,
  resumable; anchor now Jacinta Allan, was Daniel Andrews), then `scripts/build_vic2026_salience_jump.R`
  (output/vic2026-salience-jump.csv). Local runs DO use a vic2026 salience corpus (live walk log: XG5 43 cells,
  31 surge seats); the CI publish does not have one yet (DS3 falls back to flat surge_h), so the surge double count
  (`AUSPOL_SURGE_LEVEL`) reaches the published forecast only once a corpus reaches CI.
- OPEN F8, F10, F12-F19 (F5 and F9 REFUSED, F7 waiting above, IND override shipped as arm H): post-xgb tables fitted
  on residuals the shares no longer carry, HTV overwriting xgb flows, and the rest of the audit's list
  (`reviews/pipeline-overwrite-audit-2026-10-18.md`). F20 DONE 23 Oct: the model registry parses the code (comments
  and longer names no longer count) and lists each switch's `R/` readers. The one gap it found (harnesses never read
  `AUSPOL_MINOR_DEFECT`) FIXED 23 Oct: all seven harnesses gate the base_pred discount on it as `fit_seats_full.R:959`
  does (byte-identical at published flags; not run, memory).

## 2026-10-17 (READ FIRST)

Shipped and published that day (Lib/Nat split `AUSPOL_COALITION_SPLIT=1`, 15 Oct full rebuild, surge flag "none",
party-cor off) and the phantom-votes arm REFUSED: all in the journal and DECISIONS.
- PARKED composition spread (`reviews/composition-spread-2026-10-17.md`): C passed its 1k screen (all seats -0.0021,
  SE 0.0013) but taxes NSW and favourites; C2 lost. Pete: go to the error-distribution fix; C is its benchmark.
  Error distribution E REFUSED (`AUSPOL_ERROR_DIST`; every seat -0.0004, SE 0.0017). Open: width (C) + tails together.
- OPEN, bigger than either arm: errors are HEAVY-TAILED everywhere (0.57% of non-IND-seat cells miss by 4+ sim
  sds, ~100x a bell curve; kurtosis 20). A fat-tailed per-cell error (fitted time-forward) is the general fix for
  floor seats. NB the seat-poll form of it (arm T, mixture on model error) was REFUSED 19 Oct (-0.0004, SE 0.0052).
- MEASURED, PARKED per-class level bias (17 Oct, scratchpad levelcorr.R): statewide level over-predicts the Greens in
  23 of 35 elections (formal-weighted -0.73); all-class time-forward correction loses (1.402 -> 1.426), GRN alone
  helps slightly (prereg-poll-level-centring arm C, never run). Revisit GRN alone when more elections are in.
- OPEN FFD1 is fitted on the gap FF1 checks (passes by construction; Pete's call, 15 Oct). Validate it when a
  second federal cycle has firms that both name and fold One Nation.

## Still open from 14-15 Oct (collapsed 15 Oct evening; history in DECISIONS and `plans/overnight-2026-10-14.md`)

- OPEN `seat_sd` is dead in the shipped config (the seat-spread leak was inert: `simulate_seat_contests()` ignores it
  whenever `level_sd` is given; fix `AUSPOL_SEAT_SPREAD_SRC="derived"` merged): a candidate for removal, not tuning.
- OPEN small: `AUSPOL_PARTY_COR` is out of NT with no recorded reason (out of WA by design: cor(ALP, IND) flips sign
  there, MODEL-REGISTRY). (NT's two-meaning `BNT4` fixed 23 Oct: the nothing-scored exit is now `BNT6!`.)
- OPEN same one-run lag, older: the seat-poll weight is fitted on the PREVIOUS rebuild's output/forecasts.csv
  (R/seat_poll_blend.R:67; DECISIONS 2026-09-29), so stage 6 uses last run's predictions to weight seat polls. The
  spread fix's compare-and-rerun pattern (scripts/compare_spread_tables.R) could cover it too.
- OPEN census builder traps found doing it: (1) build_census_features.R stops on NT (CF2!); the regeneration used a
  scratch copy that drops NT before the check. (2) Run without a base, the vintage builder's source B labels
  qld2017/sa2018 rows from ANOTHER election's reaggregation as "on election boundaries"; their previous
  name-matched rows were kept. Fix both before the next census regeneration.
  Read 23 Oct, NOT fixed (needs a design call, nothing at risk now): `output/census-features.csv` IS the vintage
  file (identical to `census-features-vintage.csv`, 3,226 rows, 15 Oct 00:04), and the vintage builder reads it
  as its base (`build_census_features_vintage.R:248`). So the old builder should never write it again: run to its
  end it would overwrite the published table with boundary-vintage rows, including census taken after polling day.
  (1)'s `CF2!` currently stops it before that write (`build_census_features.R:284` unions in all 35 v6 pairs, and
  this builder has vintages for 18), so do not just patch the stop. The fix is to choose how a regeneration chains
  the two builders, e.g. the old one writes only a separate boundary file the vintage builder reads.
  wa2001/wa2005 are empty (0/57, 0/68) on purpose: no pre-2006 census on disk (Pete 14 Oct, `blank_census_lookahead.R`).

**State (15 Oct):** 35 scored single-member elections. AEF-7 seat log loss 0.2669 (published 15 Oct 15:33) vs AEF 0.2825;
pooled 0.3347 over 2,931 seats. Tas/ACT on the Hare-Clark path: pooled 0.496 vs naive 0.974. Training rule P4;
scoring each election x sqrt(votes). Leak fixes shipped: conserve, MP slopes, census publication date. Later publish
16 Oct: PA5 0.3356, AEF-7 0.2657 (DECISIONS).

**Open work, in order:**
- OPEN sa2018 +0.025 from the new inputs: LNP -0.3 pts broadly where IND/GRN rose; which input not isolated (screen
  sa2018 with salience off). nsw2019's +0.026 is Barwon alone (SEAT-REGISTRY). Lead (15 Oct): under the leaking
  surge flag, sa2018 IND (SA-Best, +13.9 actual) was "surging" from its own result; read the surge arms first.
- OPEN wa2017 / wa2013 regressions: Hillarys and Churchlands traced in SEAT-REGISTRY; the Lib/Nat two-candidate part
  SHIPPED 17 Oct (journal has the full trace). Remaining: the WA 2017 swing seats (Murray-Wellington, Pilbara, Jandakot,
  Southern River, Kingsley): all five won by ALP at our P 0.09-0.19; statewide level-pred ALP 36.4 vs actual 42.2
  but published seat mean ALP 41.2 (the 36.4 -> 41.2 lift not traced); Southern River ALP swing +20.7 vs ours +8.3.
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
  `xgb-primary-v6-oof-predictions.csv` (static-cache arm). `state_swing_adjustment()` (R/state_swing_prior.R:73) has no caller: dead code (re-confirmed 23 Oct). Its signal
  is now gone on 37 state-years too (DECISIONS 2026-10-23), so the variant route is closed. Pete to choose: delete
  (`git rm` is blocked for the session, so he runs it) or keep as `@keywords internal`; either way `devtools::document()`
  and the full `check_like_ci.R` after.
- OPEN (lead, NOT a result) sitting non-major members (Sonnet, 16 Oct; scratchpad `minor-mp/`): published-path
  signed error +0.36 pts, SE 1.11, n 84 sitting minor/IND members in 29 elections: no overall over-call. Hints only:
  falling own vote -3.8 (SE 3.9, n 9); trend slope +0.26 (SE 0.17); **leader-seat bonus on a sitting minor member
  -7.8 (SE 4.1, n 4: Buderim qld2017, Traeger, Melbourne 2022/2025)**. One feature only, so a to-do, not a refusal.
  If pursued: shrunk "falling own vote" term; re-check the leader bonus for minor-role leaders (n 7, se 3.4).
- OPEN Hare-Clark candidate-level count loses on zero-probability new independents (needs a heavier tail).
- OPEN fed2007 Newspoll gaps (Jul 2005-Apr 2006, Jul-Sep 2006, Jul-Nov 2007) and Nielsen/Galaxy archives.
- OPEN fed2028 live forecast build (decided 13 Oct; 8-11 days).
- OPEN registries regenerated after the final rebuild (DATA/MODEL/POLL); SEAT-REGISTRY entries for the new worst seats.

## 2026-10-11 to 2026-10-12: still open (collapsed 15 Oct)

Shipped and merged (PRs #119-#125). **ORDER still matters: publish a rebuild (AUSPOL_PUBLISH=1) BEFORE merging to main**
whenever a change adds a file `forecast.yaml` downloads. Refused, built and off (do not rerun without a new idea):
leader ratings as a model input, trend-replaces-blend, poll-level centring, the two-way person rule, statewide poll
weighting by track record, seat-poll precision blend, typical-vote independent models.

- OPEN poll weighting (Pete wants "a LOT better"): what the blend can still carry is sample size and the federal
  breakdowns; the trend arms cannot move a blend at weight 0.89-1.00. `reviews/poll-weighting-inventory-2026-10-12.md`.
- OPEN move off AE (`reviews/ae-dependence-audit-2026-10-13.md`): (b) language-model extraction of the Poll Bludger
  posts, the stronger version, not tried.
- OPEN leader ratings: drift from months out needs horizon scoring. (The blog chart is DONE: inthegame-blog PRs #890
  and #895, "The leaders" in `politics/_forecast-body.qmd`.)
- OPEN (by hand) the federal breakdown poll page is not auto-refreshed (FK3! warns past 45 days); live statewide pages are (17 Oct).
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
  R/seat_poll_blend.R:556) pulling ONE poll at a fitted weight ~0.87 (Parkes 2022, New England 2022, Dawson 2022,
  McMahon 2025). Poll "Others" lumps land in one class (`.seat_poll_known_class_map` ~:895 splits only when
  ONP/OTH_RIGHT >= half the lump). Traeger 2024 separate (Katter's falling trend carried flat; leader bonus +3.0).
  Already refused: public-only sources (2026-10-07), precision-scaled blend (2026-10-09). Untried: splitting a poll's
  "Others" lump by our own class expectations; a weight per election rather than one pooled weight.
- OPEN speed (`reviews/fast-iter-profile-2026-10-11.md`): read-set cache keys for defectors, personal prior vote,
  departed slope, salience (~25 s of a 54 s vic run); seat-poll memo keys on every switch.
- Needs Pete: three built, OFF, never-pre-registered experiment branches from 2026-10-06:
  `worktree-agent-a6d092f16127ab44a` (`AUSPOL_XGB_CLASS_JUR_CAL`), `worktree-agent-a9cb9eebe64bafa28`
  (`AUSPOL_OTHERS_SCALE_JUR`), `worktree-agent-ad78f1dffe2279a6a` (`AUSPOL_SALIENCE_STATE`, 785 lines): prereg and
  screen, or close. Also `departed-rate-refit` (unmerged since 2026-10-04).

**Running jobs when memory is short:** Claude Code reaps background shells below ~4 GB available. Run stage 6
harness by harness in the foreground, then `AUSPOL_REBUILD_FROM=7`; `AUSPOL_REBUILD_SLOTS=1` caps parallelism. A
full rebuild outlives the session when started with `Start-Process "C:\Program Files\Git\bin\bash.exe"` (not
`bash.exe` from PATH in PowerShell, which is WSL's).

Tools: misses via `scripts/biggest_misses.R` / skill `biggest-misses` (never `forecasts.csv`).

## 2026-10-07 to 2026-10-08: archived handoffs

Verbatim in `backlog/journal-2026-10-07-to-10-08.md`. Still OPEN from them:
- OPEN: NSW 2027 page, blog side: seat pages need an election switch in inthegame-blog's `politics/seat.qmd` (still
  Victoria-only 23 Oct; `politics/nsw.qmd:43` has `seatPage: false`; data on R2 since PR #107). Owned by the `inthegame-blog` session.
- OPEN: scenario-job straggler (one matrix job per run crawls on the runner's network). Pete 2026-10-09: leave open. Untried: per-step timeout plus re-run; fewer, fatter jobs.
- OPEN: fed2025 seat polls deserved weight ~0.13 and got 0.55; no pre-election signal found yet. Worst case McMahon,
  Camenzuli (IND) published 29.0, actual 9.8: ONE poll, Compass Polling 8 Apr 2025 (opt-in SMS link, n=1,003, IND 41);
  base_pred 6.0 and xgb 4.9 were both under, so the 29 is the seat-poll step (AUSPOL_SEAT_POLL_IND_MAP). ROOT: the
  seat-poll weight uses age, sample size and kind, NOT the pollster's record, method or agreement with other polls.
  DONE 18 Oct: every seat poll classified (`external/reference/polls/seat-polls/poll_methods.csv`,
  `reviews/seat-poll-methods-2026-10-18.md`). NEXT: prereg seat-poll weights by method and sponsor (+ per-pollster
  reliability, consensus down-weight), time-forward, shrunk by group size, scored on seat-poll seats. Dirty pollster
  labels: checked 23 Oct, NOT reaching the model. The blend takes the firm from `poll_methods.csv`'s `pollster_clean`
  (`R/seat_poll_blend.R:174`; "YouGo (MRP)" -> YouGov, "44%" -> uComms, sponsors -> unknown), and the "44%" duplicate of
  uComms Brisbane 20 Mar 2025 has no fieldwork date, so `:89` drops it. Raw `seat_polls.csv` labels are cosmetic.
- OPEN: 120 `AUSPOL_*` names read in code but unregistered, classified 2026-10-12 (`reviews/unregistered-switches-2026-10-12.md`):
  33 MODEL / 24 RUN / 18 DIAG / 45 DEAD. Act on: live vs backtest MP-slope tier differs (live keeps a party only at
  n_member >= 8, harnesses keep any); ~20 harness-only model switches to register or delete.
- Not doing, by decision: the in-browser simulator (~40 h); the 2.5-point knots already feel live. Revisit if Pete wants two sliders at once.

## 2026-09-27 to 2026-10-05: archived sessions

Verbatim in `backlog/journal-2026-09-27-to-10-05.md` (handover detail in `HANDOVER-2026-10-05.md`). Live from them
is folded into the sections below (Model open, Hygiene, Data and infra); nothing live is left only in the journal.

## NOW: the election-night booth model (Pete, 2026-09-19: option b)

Plan and both rehearsals: `docs/plans/election-night-booth-model.md`. Built:
2022 + 2018 booth data (`fetch_booths_vic2022.R`), matching + projection +
prior combination (`R/booth_projection.R`, tested), replay harness. Rehearsal
2: prior + projection beats both alone (major-share MAE 3.12 -> 1.25 at half
the night vote; leaders 68 -> 77 of 78). Seat-type swing pre-election is
PARKED (a new 2022 pattern no prior election teaches).
Next: re-simulate the preference count from posterior primaries (win
probabilities), chamber aggregation with the forecast's correlation, VEC
feed parser once the 2026 configuration is published (email drafted in the
plan, **Pete to send**; To Do reminder set).

## Dated, cannot move

- **9 November 2026, 12 noon: nominations close.** Same day: fetch the VEC
  candidate list; `build_candidacies.R` writes vic2026 rows so
  `candidate_returns(vic2022, vic2026)` and the flow model's `dest_same`
  features go live; rerun the three salience scripts named in
  `published_flags.R` (`victoria_salience_dryrun.R` proves the path on
  vic2022); revisit candidate-count weighting once counts are facts.
- **The day Liberal how-to-vote cards are published**: add
  `vic2026,ALL,<TRUE/FALSE>,<source>` to
  `external/reference/htv/liberal-alp-grn-order.csv` (~8 points of 2CP in
  inner-Melbourne ALP-v-GRN seats). Nothing announced as of 19 Sep.
- **Nomination-day procedure**: `docs/PIPELINE.md` section D. Upload `candidacies.csv` to the `shipped-models`
  release (CI downloads it from there), then set `AUSPOL_NOM_LIVE` to "1" in `published_flags.R`. The gate is
  MANUAL by Pete's choice and never opens on date alone. Also wire the live candidate split into
  `fit_seats_full.R` (`fit_minor_candidates.R` on vic2026 rows; v44's bucket split is backtest-only).
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

- **NSW variance / per-seat `seat_sd`** — design-with-Pete item: the 11 wrong
  nsw seats went to a different beneficiary every time, arguing for seat-level
  uncertainty over class widening; means a `src/seat_sim_core.cpp` change.
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
- **Surge v4 vs salience**: hazard AUC 0.936 vs 0.751 but over-dispersed;
  deciding seat-count test not run (`prereg-xgb-surge-parameters-v2`).
- **Overcalled independents, NOT DONE** (Pascoe Vale: Sue Bolton polled 4.19, called 18.42, because the 2018
  independent class gap was carried onto her though nobody of that class re-stood; also Geelong, Sandringham,
  Kavel 2026, Shepparton; walk in `reviews/overcalled-independents-walk-2026-10-03.md`). Fix idea: stop
  carrying a class gap onto a candidate when none of that class's earlier candidates re-stand, in `base_pred`
  AND xgb. Bigger overcalls with a permitted successor (Geelong, Morwell, Mildura, Kavel, Finniss) are a
  separate item, not started; departed-hold refused.
- **Simulation noise revives zeroed parties** (`R/seat_sim.R:1275`, `v <- base_v + shift + rnorm(K, 0, sd_cell)`):
  written shares are 0, draws are not. Measure how often a revived cell places or wins before masking it;
  affects every harness number, so it needs a prereg. Unmeasured.
- **Departed-rate refit**: branch `departed-rate-refit` (256f328, reviewed twice) never run on real data; its
  experiment needs the 4-step retrain. Overnight fallback (keep 0.38 with fewer than 3 informative earlier
  elections) was chosen on Pete's behalf; reversible (prereg addendum 2026-10-04).
- **Scenario tool** (hold the party exactly at X, others give way by regression: Pete's choices): build NOT
  started, about 40-50 h (a guess); stage 1 is brute-force `AUSPOL_FORCE_FP` runs, also the test oracle
  (`plans/scenario-tool-scoping-2026-10-03.md`). Request register: NOT DONE.
- **Early WA pairs and fed2007/2010 get no leader-seat bonus** (as-at predictions start at fed2010): extend
  the as-at corpus back if the data allows.
- **Seat polls: PARKED** after arms S, T, U refused; the weight is fitted on one or two earlier polled
  elections. Resume only with a source adding earlier polled elections. Change seats beyond the statewide miss
  (Parramatta, Heathcote): walk examples with Pete before any rule.
- **Time-forward fits still use `min_n` cliffs** (checked 23 Oct: `R/split_slope.R:395,416` return 1 / skip below
  n 40; the shrinkage arm `AUSPOL_SLOPE_SHRINK` is "0"). Partial-pool instead (shrinkage rule). The `SHIP_SAME/NEW`
  leak is DONE: `AUSPOL_SHIP_TIME_FORWARD=1` (v51) makes the fallback time-forward; the constants are opt-out only.
- **Seat context phase 2** (margin, previous swing; first-term flags' definition) was queued 2026-09-28; not
  confirmed built.
- **Teal/independent under-call** (Curtin, Goldstein, Mackellar, Wakehurst):
  PARKED by Pete. Overall we lead AEF on independents (36 winners: 16.7 vs
  19.7 log loss). Wave term blocked (`reviews/wave-term-blocked-2026-09-07.md`).
- **Final-two flow for excluded-party cells** (roadmap item 3): DEMOTED,
  the TCP gap is item (0) (audit review). Calibration by band: DONE.
- WA Nationals fold: SHIPPED v42, held for Pete (DECISIONS). Smaller:
  intra-Coalition seats have no TCP class (2 of 660, AEF has the
  same limit; zero vic2026 seats affected today); Centre Alliance/SA-BEST
  read as OTH not IND (Pete's call); Orange/Wagga `own_prev_pcv` NA for
  by-election winners (needs a feature, fallback fill refused); the statewide
  covariance pools every era; WA has no surge-v2 hazard.

## Harness and pipeline hygiene

Closed 2026-09-19/20 (DECISIONS; fast loop in `PIPELINE.md` C0): forecast
mode everywhere, time-forward folds, registry classified, zero-placeholder
audit, smoke loop + as-at cache + `tidy_output.R`, `out_path()`.

Still open:
- NB 23 Oct: neither branch below exists any more; only the commits b21fb77 and ae91f62 survive (unreferenced, so
  `git gc` can drop them). Pete: recreate the branch to keep the work, or let it go.
- Branch `fed-timing-resume-fixed` (b21fb77, unmerged, NOT through the review gate or `check_like_ci`): fixes
  the federal `PARTY_COR` loop leak (a full fed run simulates every pair with the LAST pair's matrix; dormant
  at published defaults because `AUSPOL_FORECAST_MODE=1` skips the matrix; live for fed with FORECAST_MODE=0),
  adds per-pair timing and an opt-in resume cache (`AUSPOL_FED_RESUME=1`). Ran live: outputs byte-identical.
  Untested: more than one pair, a kill mid-run. `FLOW_SD` has the same loop leak, unfixed (dormant,
  `AUSPOL_FLOW_SD_BY_SOURCE` default 0). Also `instrument-backtest-fed-timing` (ae91f62), paused.
- The seat-poll, demographic and leader-seat corrections learn from the PREVIOUS rebuild's
  `output/forecasts.csv`, so a rebuild's result depends on the one before it; make them read this run's
  as-at predictions (queued 2026-09-30). Still live 23 Oct: `R/demographic_residual.R:213` and
  `R/seat_poll_blend.R:728,791` read `output/forecasts.csv`; leader-seat (`R/leader_seat.R:119`) not checked.
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

Still open:
- VEC feed: 2026 configuration not yet published; **Pete to send the email**
  drafted in the booth-model plan.
- Federal results as a correlated signal for state seat lean: needs
  seat-boundary matching (`external/reference/boundaries/` has CED 2016).
- GDELT parked (needs a GCP project); Census 2006/2001 have no bulk pack.
- OPEN: ITG page: a seat map (regions are in the JSON now), per-seat cards, a forecast-over-time chart.
- Provisional candidate list (`output/candidacies.csv`, ABC + Wikipedia, uploaded to the `shipped-models`
  release): LDP (4 rows) is classed OTH, probably OTH_RIGHT; confirm.

## Awaiting Pete

- **The repo is ALREADY public** (found 2026-09-27; this item used to ask
  whether to make it so). `docs/plans/product-features.md` names competitors
  and the scorecard names pollsters: is that fine as it stands?
- The four improvement-quiz questions (`ANCHOR-MODEL.md`, "Honest
  assessment"); two now have measured answers.
- Market odds or seat polls as an exogenous input for new independents: a
  different kind of input, Pete's call.
- Centre Alliance / SA-BEST class (OTH vs IND).
