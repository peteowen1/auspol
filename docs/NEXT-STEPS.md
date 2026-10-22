# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before the 2026-09-19 rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`;
closed items of 7-19 Oct, verbatim: `backlog/journal-2026-10-07-to-2026-10-15.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30; slimmed 2026-10-19.

## NEEDS PETE

- OPEN, DATED (Tue 27 Oct, 3, 10, 17 and Fri 27 Nov): vic2026 benchmark capture. Built and run 22 Oct (all four
  sources, `docs/benchmarks/vic2026/2026-10-22/`). Each date: `Rscript scripts/snapshot_benchmarks.R`, plus the GES
  Chrome step (`scripts/ges_read_calls.js`; plan Amendment 1), rerun the script, commit the calls folder, rerun
  `scripts/build_data_registry.R`. Still to build: `scripts/score_benchmarks_vic2026.R` (after the VEC declares).
  Roy Morgan dropped 21 Oct (no seat winners) (`plans/external-benchmark-vic2026-2026-10-20.md`).

- DONE 19 Oct 11:47: full rebuild from 3 published (surge_h leak fix + PRs #127/#128), 4139 s, no `!!`. AEF-7 seat log
  loss 0.2657 -> 0.2635 (AEF 0.2825, n=681); primary RMSE 4.729 -> 4.579; TCP MAE 3.76 -> 3.65 (AEF 3.63). Pooled 0.3267
  over 2931 seat-elections. Snapshot `output/snapshots/20261019-1147-185957d-from3`.
- OPEN (the command; see the second-stop line below): F7 screen (demographic correction in full, `AUSPOL_DEMO_RESID_FULL=1`,
  off). `Rscript scripts/quick_arm.R "AUSPOL_DEMO_RESID_FULL=1" --pairs=all --sims=1000 --slots=1 --no-reuse`, then
  the scratchpad scorer score_f7.R on its two cache keys (`plans/prereg-demo-resid-full-2026-10-19.md`). The 18 Oct
  attempt was stopped by the memory watchdog.
- OPEN: F7 screen stopped by the memory watchdog a SECOND time 19 Oct (~07:45, at the compile step; a citiusverse
  export held ~5 GB). Not restarted; rerun only on Pete's word, with the machine otherwise idle.

## 2026-10-18 pipeline audit (READ FIRST; `reviews/pipeline-overwrite-audit-2026-10-18.md`, Sonnet, read-only)

20 findings where work is overwritten, doubled or ignored, or live and backtest diverge. Spot-checked in code 18 Oct.
Closed from it (journal): rules review (standard decision rule now heads `PRE-REGISTRATION-RULES.md`), seat-poll
TCP-consistency check, arm H shipped, heavy-tail arm T REFUSED 19 Oct, F21 surge_h fixed.
- OPEN F1 (live, now): `R/xgb_primary_override.R:271` serves level_pred = 0 for IND and OTH_RIGHT (state_mean has only
  ALP/LNP/GRN/ONP/OTH) and the whole others bucket to OTH; training used per-class levels. Train/serve mismatch.
- OPEN F2 (live): `AUSPOL_MINOR_DEFECT_BASE_PRED="1"` ships but `fit_seats_full.R` never applies it (comment only, :979).
- OPEN F3 (live): `fit_seats_full.R:932` hardcodes the defector discount 0.282; every harness fits it time-forward.
- DONE F4 (scores): switch `AUSPOL_HARNESS_SW_DRAWS` built (304b662; OFF byte-identical on vic2022/wa2025, ON
  sd(ALP-LNP) 3.68 vic2022 / 4.24 wa2025 vs 2.12 flat). Screen REFUSED 19 Oct: targeted 25 elections +0.0017 (SE
  0.0014), all seats +0.0011 (SE 0.0009, WORSE), worse in 18 of 25; switch stays "0". OPEN for Pete: live forecast uses
  the wide draws, so either state backtests flatter what ships or FP_EXTRA_SD 2.419 is too wide for states
  (`plans/prereg-harness-sw-draws-2026-10-19.md` RESULT). Amendment 1 arm B (`=net`, seat sd net of the draws' variance)
  screened -0.0006 (SE 0.0008) on 32 elections, fed -0.0016 (SE 0.0011), state -0.0000: the double count is what cost
  +0.0017, and the LIVE forecast still carries it (draws + full seat sd). Live port built OFF (`AUSPOL_SW_NET_LIVE`, 08af39d; vic2026 walk:
  totals unchanged, favourites 88/88 unchanged, favourite prob +1.3 pts mean). 20k deciding run DONE 19 Oct 16:19
  (`deciding-runs/20261019-1414-f4-net`): -0.0014 (SE 0.0006) over 31 elections, LOO holds, AEF-7 -0.0021; clause 4
  refuses (sa2014 +0.0043, wa2021 +0.0024, each >2 own SE). SHIPPED on Pete's override, PR #129 merged 19 Oct;
  PUBLISHED 19 Oct 17:25 (rebuild from 6, `deciding-runs/publish-20261019-1700.log`): pooled 0.3267 -> 0.3242 (2,931
  seat-elections), AEF-7 0.2635 -> 0.2614 (AEF 0.2825); net-out applied in all 32 elections with draws. First live
  daily Forecast run with AUSPOL_SW_NET_LIVE=1: success, 2026-10-19T23:28Z (ran ~3.5 h late).
- DONE F5, REFUSED 20 Oct: `AUSPOL_SALIENCE_BLEND_ONCE=1` at 20k, target seats +0.0002 (SE 0.0012), all seats
  +0.0001 (SE 0.0006), leave-one-out 0/18; under-calls the 2022 teals. Switch stays "0"
  (`plans/prereg-salience-blend-once-2026-10-19.md`).
- DONE partial-contest arm A, REFUSED 20 Oct at the 1k screen: nsw2023/sa2022/nsw2019 never moved; qld2015 +0.0207
  (One Nation packed into 11 seats, Lockyer 49 vs 27). Arm B not built (`plans/prereg-partial-contest-2026-10-19.md`).
- DONE contest features in the trees (`AUSPOL_XGB_CONTEST`, stands_i + level_contested), REFUSED 20 Oct at 20k:
  target seats +0.0041 (SE 0.0020) worse, all seats +0.0036 (SE 0.0017), leave-one-out 0/31, 5 elections worse. The
  trees moved nsw2023's new-to-seat One Nation cells DOWN (~3.1 -> 2.9 vs actual 9.7): they fit a residual on
  base_pred (~1.5) and will not add +8. Switch stays "0" (`plans/prereg-contest-features-2026-10-20.md`).
- DONE contest base (`AUSPOL_CONTEST_BASE`, new-to-seat One Nation base_pred toward its vote where it stands),
  REFUSED 20 Oct at 20k: target seats +0.0036 (SE 0.0023), all seats +0.0025 (SE 0.0016), leave-one-out 0/27; the 317
  seats it acts on +0.0022 (SE 0.0017). Shares improved (nsw2023 new-to-seat RMSE 8.07 -> 5.65) but new-to-seat
  One Nation rarely wins, so seat calls do not. Partial-contest line closed for seat calls
  (`plans/prereg-contest-base-2026-10-20.md`). IND/OTH/OTH_RIGHT not attempted: many parties share one level.
- DONE first-term members: the +4.0 was +1.84 within-election (SE 0.81); the flag was blank in 25 of 35 elections.
  Rebuilt from our corpus (97.3% vs the seat file), 41 by-elections added, `build_seat_context.R` now in the rebuild
  (it was stale at 24 of 35, so the SHIPPED incumbent/retiring fill missed 11 elections). The fill arm REFUSED 20 Oct
  (+0.0001, SE 0.0009). Pete 20 Oct "Ship the fix": the refreshed seat context goes out with the next publish
  (pooled +0.0014, SE 0.0014; the 11 elections -0.0073, the other 24 +0.0040) (`plans/prereg-first-term-fill-2026-10-20.md`).
- DONE the arm rebuild's SPZ3 failure (20 Oct): not a non-share-only fit. Shares were byte-identical between the two
  stage-6 passes; in pass 1 sa2010 and sa2022 got the same file tag (`a24d75e`), and since SA's file names carry no
  election, sa2010 overwrote sa2022's results and the pass-1 tables took sa2022 from a 19 Oct run. The tag was a
  weighted character sum, not a hash: now md5 in all seven harnesses, and SA refuses (BS0!) to overwrite another
  election's file. No other collision among the SA files on disk; the published forecast was not affected.
- OPEN, from the same diagnosis: Greens over-called in high-Greens seats by the trees (Melbourne, Griffith, Northcote);
  retiring Labor members about -2.0 (n 34); Dickson's published stage moved a correct tree LNP figure +5.5.
- OPEN (Pete): the 28 old notes in the ledger page's notes store now duplicate `docs/aef7-seat-notes.csv` under "Your
  notes"; clear them only on his yes.
- DONE F9, REFUSED 19 Oct: `AUSPOL_ERROR_DIST_COMP=1` at 20k -0.0001 (SE 0.0001), within 1 SE; screen at 1k had
  said -0.0005 (tail arm, floor artefact). Switch stays "0". Result in `plans/prereg-error-dist-composition-2026-10-19.md`.
- Width arms A0/A1 (`AUSPOL_FP_EXTRA_SD` 0 / 1.2) pre-registered, not yet run.
- OPEN, DATED (from ~2 Nov, weekly; final snapshot 25-27 Nov): vic2026 salience snapshots. All 500 candidates fetched
  18 Oct (window to 6 Oct), but that is before the campaign: nobody's search interest is rising yet (Premier 1.1 in the
  last 8 weeks vs 9.3 before), so batches cannot be linked and `jump` is not comparable with the backtests' polling-day
  values. Each refresh: `AUSPOL_SALIENCE_TO=<date> Rscript scripts/fetch_salience_vic2026_full.R` (~100 requests,
  resumable; anchor now Jacinta Allan, was Daniel Andrews), then `scripts/build_vic2026_salience_jump.R`
  (output/vic2026-salience-jump.csv). Not yet wired into the live forecast.
- OPEN F5-F20: salience/nomination zeroing applied twice in harnesses, demographic correction rescaled away (~60%
  delivered), post-xgb tables fitted on residuals the shares no longer carry, IND override (being fixed: seat-poll
  prereg), CE error z standardised without the composition factor, HTV overwriting xgb flows, registry greps comments.

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
  there, MODEL-REGISTRY); NT prints BNT4/BNT5 twice.
- OPEN same one-run lag, older: the seat-poll weight is fitted on the PREVIOUS rebuild's output/forecasts.csv
  (R/seat_poll_blend.R:67; DECISIONS 2026-09-29), so stage 6 uses last run's predictions to weight seat polls. The
  spread fix's compare-and-rerun pattern (scripts/compare_spread_tables.R) could cover it too.
- OPEN census builder traps found doing it: (1) build_census_features.R stops on NT (CF2!); the regeneration used a
  scratch copy that drops NT before the check. (2) Run without a base, the vintage builder's source B labels
  qld2017/sa2018 rows from ANOTHER election's reaggregation as "on election boundaries"; their previous
  name-matched rows were kept. Fix both before the next census regeneration.

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
  `xgb-primary-v6-oof-predictions.csv` (static-cache arm). `state_swing_adjustment()` (R/state_swing_prior.R:73) has no caller: dead code.
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
- OPEN leader ratings: drift from months out needs horizon scoring; the blog chart was briefed to
  inthegame-blog-86 (not confirmed taken).
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
- OPEN: NSW 2027 page, blog side: seat pages need an election switch in ITG's `seat.qmd` (data on R2 since PR #107). Owned by the `inthegame-blog` session.
- OPEN: scenario-job straggler (one matrix job per run crawls on the runner's network). Pete 2026-10-09: leave open. Untried: per-step timeout plus re-run; fewer, fatter jobs.
- OPEN: fed2025 seat polls deserved weight ~0.13 and got 0.55; no pre-election signal found yet. Worst case McMahon,
  Camenzuli (IND) published 29.0, actual 9.8: ONE poll, Compass Polling 8 Apr 2025 (opt-in SMS link, n=1,003, IND 41);
  base_pred 6.0 and xgb 4.9 were both under, so the 29 is the seat-poll step (AUSPOL_SEAT_POLL_IND_MAP). ROOT: the
  seat-poll weight uses age, sample size and kind, NOT the pollster's record, method or agreement with other polls.
  DONE 18 Oct: every seat poll classified (`external/reference/polls/seat-polls/poll_methods.csv`,
  `reviews/seat-poll-methods-2026-10-18.md`). NEXT: prereg seat-poll weights by method and sponsor (+ per-pollster
  reliability, consensus down-weight), time-forward, shrunk by group size, scored on seat-poll seats. Dirty pollster
  labels to fix in the scraper: sponsors in the pollster column (Climate 200, Sky News, Industry Association,
  Internal polling), 56 unnamed fed2016 polls, "44%" (a duplicated uComms Brisbane row), "YouGo (MRP)".
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
  gap + fundamentals). OPEN: the anchor-implied arm (`plans/prereg-anchor-implied-tpp-2026-09-20.md`, `AUSPOL_ANCHOR_IMPLIED`, still "0"; v44 scored other changes, no verdict on this arm found in DECISIONS); wa2017 and fed2019
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
- **Time-forward fits still use `min_n` cliffs** (early pairs snap to slope 1.000 below 40 rows), and the
  hardcoded `SHIP_SAME/SHIP_NEW` slopes (`R/split_slope.R:330`) were fitted on every election (a remaining
  leak). Partial-pool instead (shrinkage rule). Unconfirmed whether either was since done: not in DECISIONS.
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
- Branch `fed-timing-resume-fixed` (b21fb77, unmerged, NOT through the review gate or `check_like_ci`): fixes
  the federal `PARTY_COR` loop leak (a full fed run simulates every pair with the LAST pair's matrix; dormant
  at published defaults because `AUSPOL_FORECAST_MODE=1` skips the matrix; live for fed with FORECAST_MODE=0),
  adds per-pair timing and an opt-in resume cache (`AUSPOL_FED_RESUME=1`). Ran live: outputs byte-identical.
  Untested: more than one pair, a kill mid-run. `FLOW_SD` has the same loop leak, unfixed (dormant,
  `AUSPOL_FLOW_SD_BY_SOURCE` default 0). Also `instrument-backtest-fed-timing` (ae91f62), paused.
- The seat-poll, demographic and leader-seat corrections learn from the PREVIOUS rebuild's
  `output/forecasts.csv`, so a rebuild's result depends on the one before it; make them read this run's
  as-at predictions (queued 2026-09-30, not confirmed done).
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
