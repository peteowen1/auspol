# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before this rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30.

## 2026-10-07 (READ FIRST): where things stand, next session's priorities

**Pete's priorities for next session, in order:** (1) fix the top primary misses; (2) get the NSW 2027
election onto ITG. **Work fast:** screen every tweak at share level (seconds) and with a low-sim,
affected-harnesses-only arm (`scripts/quick_arm.R`, minutes) before any full 20k run; a full stage-6
run is only for the shipping decision (memory `screen-fast-before-full-runs`).

**Published** (`shipped-models` 2026-10-06 11:13 UTC; live forecast rerun 11:16 UTC): AEF-7 ledger
**0.2742** vs AE Forecasts 0.2825 (681 seats). Kennedy seat-poll split (PR #94) and the majors re-entry
carry, post-xgb (PR #95; live Narracan Labor 4.4% -> 11.6%). Artifact:
https://claude.ai/artifact/3YAUawbwdQBn96Bi5nqF4A (v59 changelog; winner-primary column fixed).

**Merged to `main` (PR #96, 2026-10-07), NOT YET PUBLISHED** (Pete runs stage 9): new-independent
shrink, capped (`AUSPOL_NEW_IND_SHRINK="1"`, prereg passed: changed cells 1,200 -> 1,035, 4 SE; ledger
0.2741); the ledger winner-primary column fix (was showing base_pred: Goldstein 3.1 vs published 27.1);
`AUSPOL_DEFECTOR_STATE` code (off). `output/` holds the matching state (ledger 0.2741).

**1. Top primary misses** (AEF-7, ours vs AEF; `reviews/vic-ind-overcall-2026-10-06.md`):
- Major-party winners under-called 8-11 points where we hand the share to independents/minors:
  Bankstown nsw2023, Malvern vic2022, McMahon fed2025 (IND seat-poll weight), Kalkallo vic2022, Chifley,
  Dawson, New England, Parkes. Over-calls: Traeger qld2024 (Katter's party 66.4 vs 49.3), Nicholls
  fed2022 (LNP 55.3 vs 44.2).
- Departed independents' class vote carried ~0.6 to an unrelated new person (Pascoe Vale, Waite, Kavel;
  real retention 0.08-0.42). Next fix to screen.
- Unknown new independents outside Victoria are a mix of a few strong (Pittwater) and many weak
  (Bankstown 2.7): a single factor fails both ways; needs a candidate signal (seat polls, salience).
- Defectors keep either ~25-30% or ~70-100% of their vote and nothing separates the groups yet
  (`reviews/state-defectors-2026-10-06.md`); Kiama 2023 is the live example. Pilbara 2001 is
  unforecastable time-forward.
- Climate 200 flag adds +7 in Sandringham/Bellarine (learned from 21 federal rows).
**2. NSW 2027 on ITG** (`reviews/nsw2027-green-opv-2026-10-07.md`, ~1-2 weeks): refresh the trend (stops
2026-08-23); measure One Nation flows from NSW data (Green: 11.7% Labor / 26.1% Coalition / 62.2% exhausted;
ours 25.5% Labor, federal-based); boundaries (2027 redistribution unchecked); provisional candidates; a NSW
live seat script; generalise `scripts/build_forecast_json.R` (hard-wired to vic2026); the ITG page.

**Refused today** (recorded in `docs/plans/` and DECISIONS): general re-entry prior; majors carry via
stage-1 retrain; state defector rate; per-jurisdiction others scale; class-by-jurisdiction calibration;
uncapped new-independent shrink.

**Loose ends:** `scripts/quick_arm.R` was mid-build at wrap-up on branch
`worktree-agent-a7292a0ea2f74a3eb` (uncommitted files in `.claude/worktrees/agent-a7292a0ea2f74a3eb`):
merged to dev 2026-10-07 (73d4bf8), NOT yet reviewed or on main: review it in the next PR. Usage: `Rscript scripts/quick_arm.R "AUSPOL_X=1" --pairs=vic2022,...` (~70 s per election with the baseline cached; ~7 min for all 22 cold; verdicts matched the full runs). Profile: setup+fitting is ~80% of a harness run, simulation ~20% -- caching harness setup is the next speedup. vic2026 Trends fetch at 121 files (two memory-watchdog kills; resumable,
`AUSPOL_SALIENCE_SLEEP=15 Rscript scripts/fetch_salience_vic2026_full.R`); worktree branches of refused
arms kept for reference.

## 2026-09-27 to 2026-10-05: archived sessions

Verbatim in `backlog/journal-2026-09-27-to-10-05.md` (newest first; handover detail in `HANDOVER-2026-10-05.md`).
Everything still open from them is folded into the standing sections below; nothing live is left only in the journal.
- 2026-10-05 handover: departed-hold refused; Pete's open asks are item 8 above.
- 2026-10-04 morning and overnight: salience arm C dropped, zero-order LATE shipped, PR #89 merged, candidacies.csv uploaded. Live: branches `departed-rate-refit` and `fed-timing-resume-fixed` unmerged (Model open, Hygiene); scenario tool build not started (Model open).
- 2026-10-03 evening and 01:40: v61 zeroing, v59/v60 shipped. Live: re-entry prior undecided, overcalled independents, simulation-noise revival of zeroed cells (all Model open).
- 2026-09-30 (five sections, v53 to v56) and 2026-09-29 (five sections, v47 to v52): ledger version history and refused arms. Live: seat polls PARKED, no leader bonus for early WA/fed2007-10 (Model open); corrections learn from the previous rebuild (Hygiene).
- 2026-09-28 (three sections, v44 to v46) and 2026-09-27: statewide-level arms refused. Live: `min_n` cliffs and seat context phase 2 (Model open); ITG page items (Data and infra).

## Where things stand (2026-09-20 17:40)

**Ledger v42** (660 AEF-7 seats, predictive throughout, 20,000 sims; lower
is better): seat log loss **0.2943 vs AEF 0.2851**, weighted primary RMSE
5.15 vs 5.42, TCP MAE 3.99 vs 3.63, accuracy 87.7% vs 86.8%. Public copy:
https://github.com/peteowen1/auspol/releases/download/shipped-models/aef7-ledger.html
History v38-v42 and the held-for-Pete decisions: DECISIONS 2026-09-20.
v43 (phantom-vote fix alone) REFUSED 0.3022; local `output/` ledger files
are v43's until the next rebuild, release and artifact are v42.

**Next model arm, pre-registered, unbuilt**:
`plans/prereg-anchor-implied-tpp-2026-09-20.md` (anchor to the draws' own
implied two-party + zero the phantom vote, one change behind
`AUSPOL_ANCHOR_IMPLIED`; smoke nsw2023, all WA, federal; rebuild v44
decides). Run the rebuild and `check_like_ci.R` one at a time: the memory
watchdog kills background wrappers below ~5 GB free.

**Live forecast**: `forecast-latest` release daily 06:00 Melbourne, mirrored
to R2 for inthegame.blog/politics/ (live). 20 Sep run pending on v42 models.

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
  gap + fundamentals). OPEN: the anchoring arm above; wa2017 and fed2019
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
- **Re-entry prior (`AUSPOL_REENTRY`, prereg 2026-09-07) was never decided and is OFF**: why Richmond 2022
  Liberals got 0.0 (actual 18.8; a re-entry cell, not standing 2018). Rebuild from stage 1 (~40 min), test in
  `base_pred` AND xgb (`reviews/reentry-prep-2026-10-03.md`). Request register: NOT DONE.
- **Overcalled independents, NOT DONE** (Pascoe Vale: Sue Bolton polled 4.19, called 18.42, because the 2018
  independent class gap was carried onto her though nobody of that class re-stood; also Geelong, Sandringham,
  Kavel 2026, Shepparton; walk in `reviews/overcalled-independents-walk-2026-10-03.md`). Fix idea: stop
  carrying a class gap onto a candidate when none of that class's earlier candidates re-stand, in `base_pred`
  AND xgb. Bigger overcalls with a permitted successor (Geelong, Morwell, Mildura, Kavel, Finniss) are a
  separate item, not started; departed-hold refused.
- **Simulation noise revives zeroed parties** (`R/seat_sim.R:1229`, `v <- base_v + shift + rnorm(K, 0, sd_cell)`):
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
- ITG page: a seat map (regions are in the JSON now), per-seat cards, a forecast-over-time chart, and
  `build_page.R:263` still takes the pendulum rows from the retired `simulate_seats()`.
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
