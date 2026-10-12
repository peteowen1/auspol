# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before this rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30.

## 2026-10-12 HANDOFF (READ FIRST)

**Morning 2026-10-12 (Pete):**
- FLOWS: tf2 SHIPPED on dev (Pete). `AUSPOL_FLOW_TF=1`, `AUSPOL_FLOW_RATE_HL=2`, `AUSPOL_FLOW_MODEL_TAG=tf2`;
  rebuild stage 4c trains them; `promote_rebuild.R` ships the vic2026 model + manifest; `forecast.yaml` requires
  them. **ORDER MATTERS: publish a rebuild (AUSPOL_PUBLISH=1) BEFORE merging to main**, or the daily forecast job
  fails on the missing tf2 files (it fails loudly, yesterday's forecast stays live).
- LEVEL BLEND: 20-day decay stays (Pete dislikes hard caps; the window's edge is ~1 SE). The real finding: k sits at
  its grid FLOOR in both modes, so the blend weight is 0.89-1.00 and the trend is effectively discarded. OPEN, NEXT
  BUILD: one poll-weighting model (age via a fitted random walk, sample size, pollster record, relevance incl.
  federal polls' state breakdowns for state elections; no cut-offs). `reviews/poll-weighting-inventory-2026-10-12.md`.
- Worktree ab43fc4 (poll-sample fetch): KEEP (Pete: re-review); verdict in that review; run
  `check_poll_coverage.R`, review, commit. Worktree a1a95ec `zero-order-late`: nothing to commit (its 41 by-election
  rows are identical in dev's gitignored copy); removal needs its `external`/`output` links deleted first (blocked
  as destructive; Pete's call). Branch `worktree-agent-a4181ce1235917bd7` deleted.
- PR #120: MERGED 2026-10-12 13:54 (head 08d8aa4, CI pass) after the publish rebuild
  (`deciding-runs/rebuild-20261012-tf2-publish.log`, EXIT=0): all 22 seat log loss 0.3170 (was 0.3201 at the
  pre-tf2 rebuild), AEF-7 ledger 0.2736 vs AEF 0.2825; tf2 vic2026/nsw2027 models + manifest on `shipped-models`
  (12:59). First daily `forecast.yaml` run on main with tf2: UNCHECKED.
- POLL-LEVEL PREREG: size check STOPPED it before any arm (amendment in
  `plans/prereg-poll-level-centring-2026-10-12.md`): clustered SE 0.15-0.42 > 0.10, and with w=1.00 the trend arms
  cannot move the shipped level. Pete chose "make the trend replace the blend": REFUSED, all three arms
  (`plans/prereg-responsive-trend-2026-10-12.md`); the blend stays. A faster walk only reaches the blend (2.305 vs
  2.315) and costs accuracy 90 days out; firm-equal centring does nothing. Poll weighting stays OPEN (Pete wants
  "a LOT better"): what is left is what the blend can carry (sample size, federal polls' state breakdowns) and the
  shared misses, not the trend.
- PR #121 MERGED 2026-10-12 17:09 (0.4.97, CI pass on 0cbc52e) after the stage-5 publish rebuild
  (`deciding-runs/rebuild-20261012-fedr15-publish.log`: all 22 0.3171, AEF-7 0.2739 vs 0.2825). First daily run
  with the federal breakdowns: 07:00 13 Oct, UNCHECKED.
- LEADER RATINGS (Pete, 2026-10-12): as a model input REFUSED (`plans/prereg-leader-approval-miss-2026-10-12.md`;
  open: drift from months out, needs horizon scoring). On the pages: `leaders` key in the page JSON, PR #122 MERGED
  17:27 (0.4.98); `leader-ratings.csv` on shipped-models. First published JSON with it: 07:00 13 Oct, UNCHECKED.
  The CHART is the blog's: briefed inthegame-blog-86 (not yet confirmed taken). Daily refresh: forecast.yaml
  refetches vic2026_opinion, nsw2027_opinion, fed2028_leaders each run (never fatal; first run 07:00 13 Oct, UNCHECKED:
  look for "LK1k refreshed" in the log). Local `fetch_statewide_poll_samples.R` still never refetches a cached page.
- FEDERAL BREAKDOWNS IN THE BLEND: SHIPPED r = 0.15 (Pete, 2026-10-12). Deciding run seat-neutral (+0.0001, SE
  0.0001). `output/fed-state-breakdowns.csv` built at rebuild stage 5b, published, downloaded by `forecast.yaml`
  (fails loudly without it). ORDER: publish a rebuild BEFORE merging to main. The source page is refetched by hand
  (`fetch_statewide_poll_samples.R`); FK3! warns when the newest federal breakdown is over 45 days old.

- OWN POLL SOURCE SHIPPED 2026-10-13 (PR #124, 0.4.100; published 00:14): the trend reads our Wikipedia scrape layered
  over AE. Live Vic One Nation 12.6 -> 18.1 seats (AE's swapped RedBridge row corrected). First daily run with it:
  07:00 13 Oct, UNCHECKED (look for PM1/PZ1 lines and no "live poll pages not refreshed" warning).
  NEXT WORKSTREAM (Pete): move off AE entirely; five dependencies listed in PETE-ASKED-FOR. Worktree
  `.claude/worktrees/layered-run` (9 GB, the deciding-run copy) is safe to delete: Pete's call.
  2026-10-13 progress (`reviews/ae-dependence-audit-2026-10-13.md`): Poll Bludger posts fetched (1,890, final 90 days
  of every election) and BludgerTrack poll tables parsed (fed2025/fed2028/vic2026); rule extractor finds 40 of 98
  AE-carrying final-month polls, 9% off by > 2 points held out. OPEN: (a) layer BludgerTrack's tables in for
  fed2025/fed2028/vic2026 (they also carry Essential's undecided, which Wikipedia folds into Others); (b) language-model
  extraction of the posts (the stronger version, not tried); (c) sub-state/upper-house section fix (2026-10-13) moves
  sa2026: re-score at the next publish rebuild.

**Needs Pete:**
1. DONE 2026-10-13: own poll source step 2 shipped (PR #124).
2. DONE 2026-10-11: branches `fed-timing-resume-fixed` (b21fb77) and `instrument-backtest-fed-timing` (ae91f62) deleted, PR #33 closed.
3. Three built, OFF, prereg-never-written experiment branches from 2026-10-06 were untracked until now:
   `worktree-agent-a6d092f16127ab44a` (`AUSPOL_XGB_CLASS_JUR_CAL`), `worktree-agent-a9cb9eebe64bafa28`
   (`AUSPOL_OTHERS_SCALE_JUR`), `worktree-agent-ad78f1dffe2279a6a` (`AUSPOL_SALIENCE_STATE`, 785 lines): prereg and
   screen, or close.

**Overnight 2026-10-12 (autonomous, Pete asleep) -- status as it moves:**
- Flow-only score `scripts/score_flows_oracle.R` built and run on all 22: result is Needs-Pete item 0.
- Review findings fixed (c1419ea): a flow arm with a missing tag or mismatched half-life now stops at startup and
  in the override, instead of silently scoring the pooled table or the leaky all-data model.
- `build_page.R` no longer runs the retired `simulate_seats()`: pendulum rows come from the seat file (same 83
  rows; tie order is decided after the merge, so the page is unchanged). Full page build not run locally: the
  staleness guards refuse until the next `run_all.R` (poll data re-fetched 2026-10-11).
- Worktrees removed: a83f23, a9339e, afe07d, ab6831 (its untracked prereg was an older copy of dev's) and a4181c
  (its NSW 2023 JSON commit is fully on dev as e0f4551). Branches deleted except `worktree-agent-a4181ce1235917bd7`
  (needs `git branch -D`: content on dev, not an ancestor). KEPT for Pete: ab43fc4 (uncommitted poll-sample work, 3
  files, +301/-124), a1a95ec `zero-order-late` (merged branch; 4 modified reference CSVs, +41 by-election rows).
- Full local rebuild at shipped flags (01:15-01:53, no publish; log `deciding-runs/rebuild-20261012-decay20.log`):
  all 22 seat log loss 0.3201 (2,120 seats; 6 floor seats carry 12.2%), AEF-7 ledger 0.2710 vs AEF 0.2825, primary
  RMSE like for like 4.771 vs 5.711. Earlier rebuilds: 28-day window 0.3172 / 0.2682, 10-day decay 0.3181. Not
  like-for-like (code moved), so a same-code deciding run DONE: `deciding-runs/20261012-0154-window28-vs-decay20/`
  (arm = 28-day window, base = shipped 20-day decay, all 22 at 20k; DONE, needs-Pete 0b). Stage-1 as-at models were CACHED (inputs
  unchanged): LEVEL_RECENT is off in stage 1, so the xgb layer never sees it.
- Seat registry: wa2001 Pilbara/Kimberley, wa2008 Kalgoorlie (three of the six zero-probability winners) PARKED with causes.
- `DECISIONS.md` 44,780 -> 39,078 chars (2026-09-19..28 archived to `backlog/journal-decisions-2026-09-19-to-09-28.md`).
- dev -> main: PR #120, every commit reviewed (Sonnet, 4 passes; findings fixed), `check_like_ci` clean, CI PASS on 6a82da4.
  NOT merged: Pete merges.
- OPEN, small: test fixtures print `PPV1! minor-to-minor conserve fit FAILED ... object 'votes' not found` 6 times
  per test run (synthetic corpus lacks `votes`; R/candidate_returns.R:984). Pre-existing, tests pass; noise that
  could hide a real PPV1 failure.

**Decided 2026-10-11 23:40:** the decay20 deciding run (`deciding-runs/20261011-1854-decay20/`, DONE, all 22, 20k
sims): shipped 20-day decay vs no blend, seat log loss 0.3163 -> 0.3110, -0.0053 (SE 0.0037), better by >1 SE; AEF-7
subset -0.0022 (SE 0.0028). The shipped half-life stands. `shipped-models` scoreboard still describes the 28-day run.

**Shipped 2026-10-11 evening (all reviewed, `check_like_ci` clean, on dev, NOT yet on main):**
- Local deciding-run launcher `scripts/deciding_run.ps1` + `quick_arm.R --reuse` per-harness canary (merge 644467e).
- Own poll source step 1: every election parsed or a recorded reason; fetch hardened (404 vs failure, `</html>`
  check, lost tables fail the run); two-way coverage (merge 89cd605).
- Source scour of Bonham, Poll Bludger, ABC, Antony Green, Wikipedia: `reviews/source-scour-2026-10-11.md`.
- vic2026 Wikipedia poll page re-fetched 20:30: the 2-8 Oct RedBridge/Accent poll (Coal 30, ALP 24, ON 24, GRN 16,
  n=1,008) is now in OUR source; AE's file still ends 2026-09-26, so the live forecast does not have it. 9 Oct copy
  kept at `raw/archive/vic2026_opinion.2026-10-09.html`. No refresh flag yet: archive-then-rerun by hand.
- Earlier today (PR #119): `screen_level_share.R` (~10 s, all 22; `--ref=decay:20` after the next full rebuild),
  `quick_arm.R` defaults to AEF-7, cross-seat cache 106 -> 53 s. Reports: `reviews/fast-iter-*-2026-10-11.md`.

**Live model:** `AUSPOL_IND_PERSON` (PR #116) and `AUSPOL_LEVEL_RECENT=decay`, half-life 20 days (Pete's decision,
unmeasured at 20 days until tonight's run). Last measured seat log loss (lower is better), all 22: 28-day window
0.3172; 10-day decay 0.3181; no blend 0.3239. `shipped-models` scoreboard describes the 28-day run. `output/` holds
the 10-day decay run (c633fd8).

**Refused (built, off; do not re-run without a new idea):** the two-way person rule and its linear variant
(Fowler 2022, Barker 2019); the never-stood "typical level" half (2026-10-09). Earlier: statewide poll weighting,
seat-poll precision blend, typical-vote / dedicated / mixture independent models (`plans/prereg-ind-typical-2026-10-09.md`).

**Queue, ranked:**
1. OPEN: Liberal<->One Nation flows (`reviews/lnp-onp-flows-by-election-2026-10-11.md`). (a) ON->Lib live median
   64.3% vs 69-75% since 2024. Recency weighting: screen 5.60 -> 4.96 pts flow error at 2 y half-life, but the
   inference-only arm (`AUSPOL_FLOW_RATE_HL=2`) was +0.0022 log loss on AEF-7 (1.2 SE worse; sa/qld better, fed2025
   worse). Retrained trees (`fit_xgb_flows_tf.R`, `AUSPOL_FLOW_TF=1`): tf0 +0.0060, tf2 +0.0025 (both within 1 SE);
   fed2025 worse in every version (+0.023 to +0.031): WALKED, its flows got more accurate; the old flows were offsetting
   a 4.6-point Labor primary under-call. NEXT: a flow-only score (seat outcomes from ACTUAL primaries + predicted flows). (b) Lib->ON varies
   54-85% by election and moves statewide together; draw it once per simulation, not per seat. (c) no past Liberal
   card orders for ON vs ALP on disk; collect only if (a)/(b) leave a gap. Liberal 2026 card not published.
2. OPEN: re-score Richmond/Footscray/Brunswick/Preston/Pascoe Vale 2022 after AUSPOL_LEVEL_RECENT; shrink the
   person-rule slope toward the ratio carry (Pete, 2026-10-11); test recency/relevance-weighted fits.
3. OPEN: nomination day **9 November 2026, 12 noon** (VEC-confirmed; Wikipedia's 13 Nov is a superseded draft):
   refit successor rates on the final candidate list (`build_departed_successors.R` chain), rerun the live forecast.
4. OPEN: miss-table seats traced but not fixed: Malvern 2022 (O'Brien under-called in base_pred), Bankstown 2023
   (xgb cut ALP 55.8 -> 49.8); Parkes, New England, Dawson 2022, Traeger 2024, McMahon 2025 not yet traced.
5. OPEN, speed (`reviews/fast-iter-profile-2026-10-11.md`): read-set cache keys for defectors, personal prior vote,
   departed slope, salience (~25 s of a 54 s vic run); seat-poll memo keys on every switch; reuse-and-resimulate.
6. OPEN, cleanup: `dev` -> `main` PR (17 files; review the diff first); `docs/DECISIONS.md` is 44,168 chars, past
   40,000 (load `hub-slimming`); merged agent worktrees (`agent-a9339ef...`, `agent-afe07d...` and four older ones);
   a `--refresh` flag for the poll scraper that archives automatically; `backtest_candidate_fed.R` writes all 7
   pairs only at the end (mostly moot under quick_arm's one-election processes).

**Corrections from this session:** I first said the decay20 deciding run would refresh the scoreboard (it does not);
and that the poll scraper was Python (it is R). Three of five Haiku scour agents died on large pages and were rerun
on Sonnet (memory `haiku-dies-on-web-pages`).

**Running jobs when memory is short:** Claude Code reaps background shells below ~4 GB available. Run stage 6
harness by harness in the foreground, then `AUSPOL_REBUILD_FROM=7`; `AUSPOL_REBUILD_SLOTS=1` caps parallelism.

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
