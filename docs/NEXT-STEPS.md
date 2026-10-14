# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before this rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30.

## 2026-10-14 HANDOFF (READ FIRST) -- overnight log: `plans/overnight-2026-10-14.md`

**Done 14 Oct:** PUBLISHED the full-inputs rebuild (AEF-7 0.2657 vs AEF 0.2825) + nsw2027 tables (6f2be85).
Daily forecast of 13 Oct 23:39 UTC CRASHED (fit_scorecard.R: unnamed pollster from qld2006_main table 6 broke
pollster_lean()); fixed c6dd914, re-run dispatched by Pete's OK (run 38514019777, SUCCEEDED). Same log has two NON-blocking
validation failures, not investigated: fit_federal.R `abs(agg_after) < 1`, fit_nsw.R `!e$at_bound`.
CI red twice from my pushes, both fixed (Tas poll sums; duplicate check code); check_like_ci.R now copies the
git-tracked tree so it sees what CI sees (8d7b36d). Cleanup: 15 worktrees removed, 10,058 old backtests archived.
Defector line CLOSED (reviews/defector-overcarry-2026-10-14.md). Seat-size spread (`AUSPOL_SIZE_SD`) SHIPPED and
published 07:35 UTC: pooled 0.3418 -> 0.3337, AEF-7 0.2662 vs AEF 0.2825 (reviews/seat-size-spread-2026-10-14.md).

**Resolved with Pete 14 Oct evening:** dev -> main merged (PR #125, four Sonnet reviewers, no blocking findings; CI pass). kill-by-name incident -- the cross-repo runtime log shows every R command
from 14:20 to 15:40 UTC belonged to auspol (this session's agents and its rebuild); pannaverse only ran `gh` CI
watches, so no other repo's job is known to have died (commands under 30 s are not logged). Decisions: thin-cycle
CONFIRMED; HC defector SHIPPED; post-election census rows BLANKED (214 backtest rows); pollster archive screened
(fed2007 0.3339 -> 0.3338) and SHIPPED. Census and archive reach the scoreboard on the next full rebuild.
- OPEN Hare-Clark harness (backtest_hare_clark.R) does not source harness_defaults.R: only AUSPOL_HC_DEFECTOR reads
  its published value; every other switch runs at its inline default there.
- OPEN (review gate, non-blocking) nsw2011/nsw2015 and sa2014/sa2018 seat-spread fall back to a LATER election's
  prev_swing (2023nsw.txt, 2022sa.txt; printed BN0s / BS1s!): a post-polling-day input, small; same compromise as Qld.
- IN FLIGHT 15 Oct: WA/NT never wired screened_slopes() (ran conditional-only, printing BW1c!/BNT1c!), which is why
  AUSPOL_HONOUR_DEPARTED and AUSPOL_DEPARTED_SUCCESSOR never reached them. Ported on branch wa-nt-screened-slopes
  (plans/overnight-2026-10-15.md). AUSPOL_PARTY_COR stays out of WA by design (cor(ALP, IND) flips sign there,
  MODEL-REGISTRY); for NT it is unexplained. NT prints BNT4/BNT5 twice.
- DONE 15 Oct (verified): mp-slope-by-class.csv is time-forward for the live targets -- scripts/fit_mp_slope.R:42
  keeps only elections with counted votes, so vic2026/nsw2027 never enter it.
- DONE 15 Oct (code; first exercised by the 15 Oct rebuild): spread-table lag -- it cannot be fitted before stage 6
  (it is fitted on stage 6's own shares), so stage 7 compares the refit with the table stage 6 read
  (scripts/compare_spread_tables.R, SPZ2) and reruns stages 6-7 once if any scored target's factor moved > 0.02 (Pete).
  As-at checkpoints now go to .partial files, renamed at the end.
- DONE 15 Oct: census PUBLICATION rule applied to output/census-features.csv. 2021 release date confirmed by the ABS;
  2016/2011 days unconfirmed, but no election sits within a month of either June date. LOOKAHEAD now means
  published after polling day (also blanks 9 fed2022, 4 wa2017, 2 nt2016, 8 qld2012 rows). Changed pairs exactly
  fed2022, sa2022, wa2017, nt2016, qld2012; everything else byte-identical.
- OPEN same one-run lag, older: the seat-poll weight is fitted on the PREVIOUS rebuild's output/forecasts.csv
  (R/seat_poll_blend.R:67; DECISIONS 2026-09-29), so stage 6 uses last run's predictions to weight seat polls. The
  spread fix's compare-and-rerun pattern (scripts/compare_spread_tables.R) could cover it too.
- OPEN census builder traps found doing it: (1) build_census_features.R stops on NT (CF2!); the regeneration used a
  scratch copy that drops NT before the check. (2) Run without a base, the vintage builder's source B labels
  qld2017/sa2018 rows from ANOTHER election's reaggregation as "on election boundaries"; their previous
  name-matched rows were kept. Fix both before the next census regeneration.
- OPEN next FULL rebuild (stages 1-9, ~3 h) to carry the census blanking and pollster archive into the published
  models and scoreboard.

**State:** 35 scored single-member elections (vic2010, wa2021, nsw2011/2015, qld2012/2015/2017, sa2010/2014/2018,
nt2016/2020/2024 new). AEF-7 seat log loss 0.2662 (published 14 Oct, size spread on) vs AEF 0.2825. Tas/ACT on the Hare-Clark path with polls: pooled
0.525 vs naive 0.974. Training rule P4; scoring each election x sqrt(votes). Leak fixes shipped (conserve, MP slopes).

**Open work, in order:**
- OPEN check the 15 Oct daily run uses the spread (look for SZD1 in its log) and succeeds.
- OPEN, NEEDS PETE (diagnosed 15 Oct): two daily-run validation failures. Neither script's outputs are read by
  anything (grep of R/, scripts/, workflows), so no forecast is affected, but every run has ended "with problems"
  since 8 Oct, which hides a new failure. NSW (`fit_nsw.R:149`, failing since 13 Oct; NL3 before that): the pooled
  walk for GRN (0.015 pts) and SFF (0.0005) hits its lower bound -- their NSW polls barely move; the same file
  already accepts a bound hit for thin parties because shrinkage makes it safe. Federal (`fit_federal.R:399`, since
  13 Oct, the own poll source): poll-weighted folded-ONP gap -1.57 vs |.| < 1, driven by Freshwater 2025 (-2.16),
  whose side of the comparison is 4 named polls (SE ~1.1) that only exist in our source; Essential dropped out.
  Recommendation: state both tolerances in standard errors (visible amendment, original clause kept), and treat a
  bound hit as shrink-toward-default as fit_nsw.R's thin-party path already does.
- OPEN sa2018 +0.025 from the new inputs: LNP -0.3 pts broadly where IND/GRN rose; which input not isolated (screen
  sa2018 with salience off). nsw2019's +0.026 is Barwon alone (SEAT-REGISTRY).
- OPEN wa2017 / wa2013 regressions: the size spread recovered -0.035 / -0.033 of them; Hillarys (defector
  over-carry) and Churchlands (retired IND) are traced in SEAT-REGISTRY, and the defector carry line is closed.
  Remaining: the WA 2017 swing seats (Murray-Wellington, Pilbara, Jandakot, Southern River, Kingsley).
- OPEN NT seat layer: over-confidence fixed by the size spread (20k: nt2016 0.80, nt2020 0.65, nt2024 1.07, from
  0.99/0.81/1.41); still weak, and new parties start at zero share.
- OPEN qld2017: One Nation / Katter seats given ~0 (emergence); qld2012 Katter polled inside Others.
- OPEN Hare-Clark candidate-level count loses on zero-probability new independents (needs a heavier tail).
- OPEN fed2007 Newspoll gaps (Jul 2005-Apr 2006, Jul-Sep 2006, Jul-Nov 2007) and Nielsen/Galaxy archives.
- OPEN fed2028 live forecast build (decided 13 Oct; 8-11 days).
- OPEN registries regenerated after the final rebuild (DATA/MODEL/POLL); SEAT-REGISTRY entries for the new worst seats.

## 2026-10-11 to 2026-10-12: still open (collapsed 15 Oct)

Shipped and since merged to main (PRs #119-#125): tf2 flows, 20-day level decay, federal state breakdowns in the
blend (r = 0.15), leader ratings on the pages, own poll source layered over AE. The 14 Oct daily run
(38514019777) confirms tf2 models loaded, `LK1k refreshed fed2028,nsw2027,vic2026`, `PZ1` layering and `PM1 5118
published`. **ORDER still matters: publish a rebuild (AUSPOL_PUBLISH=1) BEFORE merging to main** whenever a change
adds a file `forecast.yaml` downloads. Refused, built and off (do not rerun without a new idea): leader ratings as a
model input, trend-replaces-blend (all three arms), poll-level centring (stopped at the size check), the two-way
person rule, statewide poll weighting by track record, seat-poll precision blend, typical-vote independent models.

- OPEN poll weighting (Pete wants "a LOT better"): what the blend can still carry is sample size and the federal
  breakdowns; the trend arms cannot move a blend at weight 0.89-1.00. `reviews/poll-weighting-inventory-2026-10-12.md`.
- OPEN move off AE (`reviews/ae-dependence-audit-2026-10-13.md`): (b) language-model extraction of the Poll Bludger
  posts, the stronger version, not tried. (c) re-scoring sa2026, vic2014, qld2020, fed2022 is carried by the 15 Oct
  full rebuild.
- OPEN leader ratings: drift from months out needs horizon scoring; the blog chart was briefed to
  inthegame-blog-86 (not confirmed taken).
- OPEN local `fetch_statewide_poll_samples.R` never refetches a cached page; the federal breakdown page is refetched
  by hand (FK3! warns past 45 days).
- OPEN Liberal <-> One Nation flows (`reviews/lnp-onp-flows-by-election-2026-10-11.md`): (b) Lib->ON varies 54-85% by
  election and moves statewide together; draw it once per simulation, not per seat. (c) no past Liberal card orders
  for ON vs ALP on disk; collect only if (b) leaves a gap.
- OPEN re-score Richmond/Footscray/Brunswick/Preston/Pascoe Vale 2022 after AUSPOL_LEVEL_RECENT; shrink the
  person-rule slope toward the ratio carry (Pete, 2026-10-11).
- OPEN miss-table seats traced but not fixed: Malvern 2022 (O'Brien under-called in base_pred), Bankstown 2023 (xgb
  cut ALP 55.8 -> 49.8); Parkes, New England, Dawson 2022, Traeger 2024, McMahon 2025 not yet traced.
- OPEN speed (`reviews/fast-iter-profile-2026-10-11.md`): read-set cache keys for defectors, personal prior vote,
  departed slope, salience (~25 s of a 54 s vic run); seat-poll memo keys on every switch.
- OPEN small: test fixtures print `PPV1! minor-to-minor conserve fit FAILED ... object 'votes' not found` 6 times per
  test run (synthetic corpus lacks `votes`; R/candidate_returns.R:984); noise that could hide a real PPV1 failure.
- OPEN `docs/DECISIONS.md` is 42,305 chars, past 40,000 (load `hub-slimming`).
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
- OPEN: `AUSPOL_UPSET_FLOOR` is the one switch with an unexplained registry gap. Audit sentinel drift goes to issue #109.
- OPEN: fed2025 seat polls deserved weight ~0.13 and got 0.55; no pre-election signal found yet.
- OPEN: 120 `AUSPOL_*` names read in code but unregistered, classified 2026-10-12 (`reviews/unregistered-switches-2026-10-12.md`):
  33 MODEL / 24 RUN / 18 DIAG / 45 DEAD. Act on: live vs backtest MP-slope tier differs (live keeps a party only at
  n_member >= 8, harnesses keep any); ~20 harness-only model switches to register or delete.
- Not doing, by decision: the in-browser simulator (~40 h); the 2.5-point knots already feel live. Revisit if Pete wants two sliders at once.

## 2026-09-27 to 2026-10-05: archived sessions

Verbatim in `backlog/journal-2026-09-27-to-10-05.md` (newest first; handover detail in `HANDOVER-2026-10-05.md`).
Everything still open from them is folded into the standing sections below; nothing live is left only in the journal.
- 2026-10-05 handover: departed-hold refused; Pete's open asks are item 8 above.
- 2026-10-04 morning and overnight: salience arm C dropped, zero-order LATE shipped, PR #89 merged, candidacies.csv uploaded. Live: branches `departed-rate-refit` and `fed-timing-resume-fixed` unmerged (Model open, Hygiene); scenario tool build not started (Model open).
- 2026-10-03 evening and 01:40: v61 zeroing, v59/v60 shipped. Live: re-entry prior undecided, overcalled independents, simulation-noise revival of zeroed cells (all Model open).
- 2026-09-30 (five sections, v53 to v56) and 2026-09-29 (five sections, v47 to v52): ledger version history and refused arms. Live: seat polls PARKED, no leader bonus for early WA/fed2007-10 (Model open); corrections learn from the previous rebuild (Hygiene).
- 2026-09-28 (three sections, v44 to v46) and 2026-09-27: statewide-level arms refused. Live: `min_n` cliffs and seat context phase 2 (Model open); ITG page items (Data and infra).

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
