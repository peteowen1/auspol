# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before this rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30.

## 2026-10-15 afternoon (READ FIRST)

- PUBLISHED 15:33 the full rebuild with census blanking + pollster archive + WA/NT screened port
  (snapshot `20261015-1317-20697de-from1`; publish log `deciding-runs/publish-20261015-1317.log`). AEF-7 0.2669 vs AEF
  0.2825. The port cost +0.0007 pooled (0.3340 -> 0.3347, 35 pairs / 2,931 seats), all from NT: nt2020 0.648 -> 0.826,
  nt2016 and nt2024 improved (-0.062, -0.075); non-WA/NT +0.0002. Pete chose to ship it for parity.
- DONE 2026-10-16 surge flag leak: `AUSPOL_SURGE_SOURCE="none"` shipped, Pete confirmed "Keep N" (DECISIONS;
  `reviews/surge-flag-arms-2026-10-16.md`). Revisit T only with more elections where a forecast rise is real.
- MERGED 2026-10-16 (6a04b3d; not yet in the published forecast) the live vic2026 bug: unheld vic2026 votes read
  as 0 flagged ALP/LNP/GRN/IND/OTH_RIGHT as surging. Live, same inputs and seed, old -> new: `surging: none`;
  20 seat-party cells in 8 seats move > 0.05 pts, largest Narracan ONP 76.4 -> 67.6 (LNP 23.6 -> 32.4), Pakenham
  ONP 79.0 -> 77.5, Box Hill ALP 83.8 -> 82.6; expected seats LNP +0.11, ONP -0.11; P(LNP majority) 0.086 ->
  0.088, P(ALP majority) 0.028 unchanged. Reaches the site with the next daily run (cron 20:00 UTC, runs `dev`).
- OPEN check tonight's daily run (first with 629fc35's validation-check fixes; DECISIONS 2026-10-15) concludes clean (no "Run finished with problems") and reads the new release.
- OPEN FFD1 is fitted on the gap FF1 checks (passes by construction; Pete's call, 15 Oct). Validate it when a
  second federal cycle has firms that both name and fold One Nation.

## Still open from 14-15 Oct (collapsed 15 Oct evening; history in DECISIONS and `plans/overnight-2026-10-14.md`)

- DONE 2026-10-16 (INERT, no score moved) the seat-spread leak: `sd_within` was read from a later anchor seat file
  in 5 harnesses (vic2022 and sa2018 read their own result). Fixed by merging `seat-spread-tf` (3b73f5d;
  `AUSPOL_SEAT_SPREAD_SRC="derived"`, `prev_seat_swing()` from our archive TCP swings, `SSP1` per pair). Measured
  by full rebuild: anchor (snapshot `20261016-0932-f9197a6-from1`) vs derived (`20261016-1102-f9197a6-from1`)
  are byte-identical on all 35 elections, though `SSP1` shows each run read its own source. Reason:
  `simulate_seat_contests()` ignores `seat_sd` whenever `level_sd` is given, and level_sd is on by default
  (`backtest_candidate_nsw.R:123`). The leak never reached a score; the fix stays so it cannot if level_sd is
  ever switched off. `seat_sd` is dead in the shipped config: a candidate for removal, not tuning.
- OPEN small: `AUSPOL_PARTY_COR` is out of NT with no recorded reason (out of WA by design: cor(ALP, IND) flips sign
  there, MODEL-REGISTRY); NT prints BNT4/BNT5 twice.
- OPEN same one-run lag, older: the seat-poll weight is fitted on the PREVIOUS rebuild's output/forecasts.csv
  (R/seat_poll_blend.R:67; DECISIONS 2026-09-29), so stage 6 uses last run's predictions to weight seat polls. The
  spread fix's compare-and-rerun pattern (scripts/compare_spread_tables.R) could cover it too.
- OPEN census builder traps found doing it: (1) build_census_features.R stops on NT (CF2!); the regeneration used a
  scratch copy that drops NT before the check. (2) Run without a base, the vintage builder's source B labels
  qld2017/sa2018 rows from ANOTHER election's reaggregation as "on election boundaries"; their previous
  name-matched rows were kept. Fix both before the next census regeneration.

**State:** 35 scored single-member elections. AEF-7 seat log loss 0.2669 (published 15 Oct 15:33) vs AEF 0.2825;
pooled 0.3347 over 2,931 seats. Tas/ACT on the Hare-Clark path: pooled 0.496 vs naive 0.974. Training rule P4;
scoring each election x sqrt(votes). Leak fixes shipped: conserve, MP slopes, census publication date.

**Open work, in order:**
- OPEN sa2018 +0.025 from the new inputs: LNP -0.3 pts broadly where IND/GRN rose; which input not isolated (screen
  sa2018 with salience off). nsw2019's +0.026 is Barwon alone (SEAT-REGISTRY). Lead (15 Oct): under the leaking
  surge flag, sa2018 IND (SA-Best, +13.9 actual) was "surging" from its own result; read the surge arms first.
- OPEN wa2017 / wa2013 regressions: the size spread recovered -0.035 / -0.033 of them; Hillarys (defector
  over-carry) and Churchlands (retired IND) are traced in SEAT-REGISTRY, and the defector carry line is closed.
  Remaining: the WA 2017 swing seats (Murray-Wellington, Pilbara, Jandakot, Southern River, Kingsley). TRACED 16
  Oct (Sonnet, read-only; scratchpad `wa2017/`): all five won by ALP at our P 0.09-0.19, 10.4 of wa2017's 25.1
  nats; all five sitting LNP members who lost. Statewide: level-pred ALP 36.4 vs actual 42.2, but published seat
  mean ALP 41.2 (right) and LNP 40.2 vs 36.9 (3.3 high; the 36.4 -> 41.2 lift not traced). A 2-pt TPP level fix
  would take ~3 of the 10.4 nats (rough arithmetic, not simulated). Seat-specific: metro Southern River (ALP
  swing +20.7 vs ours +8.3, z 2.3), Jandakot (xgb adds +2.6 LNP); base_pred is the main stage, xgb nudges LNP up
  in all five. **Structural lead: Pilbara and Murray-Wellington had Liberal AND National candidates against each
  other, merged into one LNP class (n_cands 2)**, so a fragmented right (Grylls 27.3 + Alchin 15.3, ONP 11.4,
  SFF 9.6) reads as LNP 55.9 TPP while ALP won on 31.0. SIZED 16 Oct (Sonnet, published-predictions.csv, 35
  pairs): 191 Lib-v-Nat seats (WA 99) = 6.5% of seats, 9.7% of seat log loss; mean 0.499 vs 0.323 elsewhere
  (paired by election +0.136, SE 0.092); Coalition-lost ones 1.03 (n 74). "Pilbara pattern" (Coalition lost
  though Lib+Nat primary beat the winner's) 32 seats, 22 WA, 4.9% of loss (incl. wa2008 Kalgoorlie IND at the
  1e-6 floor, 13.8). Ceiling ~5% of pooled loss. Next if pursued: three-cornered flag + Lib/Nat primary split as
  features, screened on WA/fed/Vic with quick_arm. DECIDED 16 Oct (Pete, after walking 5 seats): **two candidates**,
  not a feature (PETE-ASKED-FOR 2026-10-16). Step 1 DONE (scratchpad libnat2.R, published-predictions.csv): the
  6-10 point Coalition over-call in the 4 walked seats was SELECTION (they were picked as the worst losses). Mean
  Coalition primary error (ours - actual) split seats +0.13 to +0.62 vs +0.42 in one-candidate seats (2,656), all
  within SE; so the split problem is the count (Nat->Lib leakage), not the primary. Side lead: WA over-calls the
  Coalition everywhere (+2.49 in 284 one-candidate seats). PREREG committed:
  `plans/prereg-lib-nat-two-candidates-2026-10-16.md` (`AUSPOL_COALITION_SPLIT`; f = 71.2% pooled time-forward).
  BUILT 16 Oct (default off; six harnesses, NT, live; tests pass). PLUMBING FAILED -> STOPPED, nothing scored
  (`reviews/lib-nat-plumbing-2026-10-16.md`): unsplit seats byte-identical (pass), Albany wa2013 0.975 -> 0.868
  (pass), Bass fed2019 0.083 -> 0.026 (FAIL, limit 0.01). Cause: a seat with no earlier split gets the pooled
  junior fraction 0.27; Bass's National took 1.4%. Pete: amend. Amendment 1 (ridge predictor of the split from
  pre-election facts, 33c031c): Bass 0.083 -> 0.053, FAIL again; no pre-election fact separates Bass (1.4%) from
  Lyons (15.7%). Pete OVERRODE the Bass clause 17 Oct (prereg "Override 1"). 1k screens (23 elections, 191 split seats,
  `reviews/lib-nat-plumbing-2026-10-16.md`): S -0.0521 (SE 0.0273), S2 (f by state, Amendment 2, Pete's pick)
  -0.0578 (SE 0.0277); every refusal passes; Victoria's 18 split seats WORSE under both (+0.18 to +0.21, ~1.6 SE).
  Live Ripon (only vic2026 split seat) Coalition 0.145 -> 0.079 under S2 (limit 15 pts, passes). IN FLIGHT: 20k
  deciding run on S2 (`deciding-runs/*-coalition-split-state/`). OPEN for Pete after it: ship despite Victoria?
- OPEN (finding 17 Oct, not acted on): WA's Coalition over-call is a statewide LEVEL miss, not seat-level. Mean
  Coalition primary error (ours - actual) in one-candidate seats: NT +3.61 (SE 1.08), WA +2.46 (0.34), Qld +0.98,
  NSW +0.45, fed +0.05, SA -0.82, Vic -0.87; WA by election 6 of 7 positive (wa2005 +4.68, wa2001 +3.42, wa2017
  +3.27). A jurisdiction bias in the level model is the lead; `screen_level_share.R` first.
- OPEN cleanup, needs Pete's OK (deletes): 5 leftover worktrees, all fully merged into dev, no uncommitted files,
  no junctions: `.claude/worktrees/agent-a7e42b05226bb2717` (seat-spread-tf), `agent-aed05f6924c0664ff` (cov-tf),
  scratchpad `wt-conserve`, `wt-party`, `wt-surge-live`. Recommend `git worktree remove` each + delete branches.
- OPEN NT seat layer: over-confidence fixed by the size spread (20k: nt2016 0.80, nt2020 0.65, nt2024 1.07, from
  0.99/0.81/1.41); still weak, and new parties start at zero share.
- OPEN qld2017: One Nation / Katter seats given ~0 (emergence); qld2012 Katter polled inside Others.
- DONE 2026-10-16 statewide party correlation leak: SHIPPED OFF (`AUSPOL_PARTY_COR="off"`, see DECISIONS; the
  leak was worth L - I -0.0006, SE 0.0007). REBUILT (not published) at d7e2883 with K=3 + correlation off:
  snapshot `20261016-1846-d7e2883-from1` vs `20261016-1102-f9197a6-from1`: 35 elections, 2,931 seats, 0.3372 ->
  0.3356 (-0.0016, SE 0.0014); AEF-7 -0.0001 (SE 0.0004); none worse by 0.02 (worst nt2016 +0.0125). nsw2019
  -0.0439 is ONE seat: Barwon (SFF won) 0 -> 1 sim in 20,000, i.e. off the 1e-6 floor (-3.91 log units); without
  it pooled is about -0.0003, so the bundle is neutral. PUBLISHED 16 Oct 19:02 by Pete (`shipped-models` assets
  08:02Z; `deciding-runs/publish-20261016-1846.log`): PA5 0.3356, AEF-7 ours 0.2657 vs AEF 0.2825. OPEN: read the
  next daily Forecast refresh's conclusion.
- OPEN (hazard for arms, not live) pooled-fits audit 2026-10-16 (Sonnet, read-only) beyond
  `reviews/pooled-fits-inventory-2026-10-13.md`: the statewide correlation above was the only live one (now off). LEAVE-ONE-OUT but
  OFF at published flags, so any arm switching them on measures a leaked number: `fit_xgb_primary_sd.R:108`
  (`AUSPOL_XGB_PRIMARY_SD`), `fit_flow_drift.R` model (`AUSPOL_FLOW_CELL_SD`), `fit_insurgency_risk.R:33`
  (`AUSPOL_INSURGENCY_SHRINK`), `party_positions(exclude=)` in `R/reentry_prior.R:288` (non-"majors" re-entry),
  `xgb-primary-v6-oof-predictions.csv` (static-cache arm). `state_swing_adjustment()` (R/state_swing_prior.R:73,
  LOO) has no caller: dead code. Checked clean: projection mix + fundamentals (TF via `AUSPOL_FUND_TIME_FORWARD`,
  fed:975), shrink 0.01.
- DONE 2026-10-16 party-class and live candidate-list errors (merged 28421e9; candidacies rebuilt f9197a6):
  Anning's Conservative National Party (48 fed2019), Liberals for Forests (7 fed2004) were LNP, Progressive
  Labour (2 fed2004) was ALP; vic2026 Ripon's garbled third Coalition row split; nsw2027 Castle Hill's presumed
  Hodges dropped. Full rebuild vs arm N: seat log loss 0.3377 -> 0.3372 (-0.0004, SE 0.0006), 35 elections.
  fed2019 +0.0071: the mislabel had added 0.27 pts of LNP per seat in a year the Coalition beat its polls
  (Longman 0.39 of the +1.08 seat-sum). Correctness fix, kept. Still open from it: Lib-vs-Nat contests are one
  LNP class in the simulator (`R/parties.R:35`), ~240 real seat-elections; see the WA 2017 item.
- OPEN (lead, NOT a result) sitting non-major members (Sonnet, 16 Oct; scratchpad `minor-mp/`): published-path
  signed error (actual - ours) +0.36 pts, SE 1.11 (clustered on election), n 84 sitting minor/IND members in 29
  elections: no overall over-call. Traeger/Hill/Maiwar 2024 (-11.8/-9.2/-11.4) are tail cases; Hill and Maiwar
  were rising, not falling. Hints only: falling own vote -3.8 (SE 3.9, n 9); trend slope +0.26 (SE 0.17, n 35,
  ex-WA); **leader-seat bonus on a sitting minor member -7.8 (SE 4.1, n 4: Buderim qld2017 +7.87 bonus -> -16.0,
  Traeger +3.01 -> -11.8, Melbourne 2022 +3.1, 2025 -6.4)**. One feature only (trend), exact-name matching, so per
  CLAUDE.md this is a to-do, not a refusal. If pursued: shrunk "falling own vote" term, and re-check the leader
  bonus for minor-role leaders (n 7, se 3.4 in the qld2024 table).
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
  posts, the stronger version, not tried.
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
  cut ALP 55.8 -> 49.8). Traced 2026-10-16 (Sonnet, read-only, hand-reproduced not replayed): **4 of 5 are the
  seat-poll blend** (`seat_poll_blend_apply`, R/seat_poll_blend.R:556) pulling ONE poll at a fitted weight ~0.87
  while the xgb layer was within ~2 pts: Parkes 2022 (YouGov MRP, LNP 47.3 -> 36.9, actual 49.3), New England 2022
  (53.8 -> 46.4, actual 52.5), Dawson 2022 (45.9 -> 34.8, actual 43.3), McMahon 2025 (Compass poll summing to 80,
  IND 4.9 -> 28.4 at IND-direct weight 0.864; P(Bowen) 0.254). Poll "Others" lumps land in one class
  (`.seat_poll_known_class_map` ~:895 splits only when ONP/OTH_RIGHT >= half the lump). Traeger 2024 is separate:
  Katter's falling own-seat trend (66 -> 59 -> 49) carried flat in base_pred, xgb nudged up, leader bonus +3.0
  (n 7). Already tried and refused: public-only sources (DECISIONS 2026-10-07, fed2022 +0.0389, teal signal
  lost) and precision-scaled blend (2026-10-09, +0.0000). Untried: splitting a poll's "Others" lump by our own
  class expectations instead of the >= half rule; a weight per election rather than one pooled weight (DECISIONS
  2026-10-07 "open"). Note renormalising McMahon's 80-sum poll would make IND worse (41/80 = 51), not better.
- OPEN speed (`reviews/fast-iter-profile-2026-10-11.md`): read-set cache keys for defectors, personal prior vote,
  departed slope, salience (~25 s of a 54 s vic run); seat-poll memo keys on every switch.
- OPEN small: `fit_minor_defector_conserve()` (R/candidate_returns.R:1750) has a hard `min_n = 8L` cliff (below 8
  cases: no fit, full transfer), against the shrinkage rule; and its call site (:1005) catches EVERY error and keeps
  the full transfer, so a real failure reads like a thin fit. (The old PPV1! fixture noise is gone: 0 lines in the
  whole local suite and in CI run 38720936369, checked 2026-10-16.)
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
