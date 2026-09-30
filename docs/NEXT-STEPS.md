# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before this rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30.

## 2026-09-30 09:40 (read this first)

**PUBLISHED 10:48: v52 = rebuild-V52** (0.2717 vs AEF 0.2851; RMSE 4.17; PR #72). Was: v52 = rebuild Y2 (demographic correction for Labor + Greens, leader-seat
bonus, `level_pred` leak fix): RMSE 4.2065 -> 4.1924, ledger 0.2753 ->
0.2726 (AEF 0.2851), accuracy 88.9%. **Not yet published.** Local `output/`
was overwritten by the refused arm Z; restore rebuild `rebuild-V52` launched
09:33 (published config, full). Reviewed (no blockers).

Next, in order:
1. Score rebuild-V52 against Y2 (it learns its corrections from Z's
   forecasts.csv, see 3), `check_like_ci.R`, regenerate
   `docs/MODEL-REGISTRY.md`, PR, merge; Pete publishes
   (`AUSPOL_REBUILD_FROM=8 AUSPOL_PUBLISH=1 bash scripts/rebuild_forecasts.sh`).
2. Anchor alone (no proportional rescale): arm Z bundled both and was refused
   on pooled log loss while winning RMSE and the ledger.
3. PIPELINE: the demographic, leader-seat and seat-poll corrections learn from
   the PREVIOUS rebuild's `output/forecasts.csv`, so a rebuild's result depends
   on the one before it. Make them read this run's as-at predictions.
4. NSW 2023 seat polls: Wikipedia's "Electoral district polling" section was
   missed by `fetch_seat_polls.R` (0 rows); AEF used a Parramatta poll (+2.35).
5. Departed member: blend toward the same booths' federal vote (Parramatta,
   Wakehurst, Richmond, Mulgrave); prereg on top of v52.

## 2026-09-29 18:00

**Published 18:15: ledger v51** = rebuild R, the statewide time-forward leak fix
(0.2719 -> 0.2760 vs AEF 0.2851; nsw2023 better, vic2022 and fed2019 worse;
RESULT in `plans/prereg-statewide-time-forward-2026-09-29.md`). Snapshot
`output/rebuild-R/`; fresh v51 (weight refit on its own predictions) `output/rebuild-R2/`, ledger 0.2753. **Local `output/` was rebuild U's (REFUSED), not
v51's** -- RESTORED 20:21, matches rebuild R2 exactly.

Refused 18:40: public-only seat polls, arms S and T (snapshots
`output/rebuild-{S,T}/`). T passed fed2025 by 2.1 SE; fed2022 failed because
its weight rests on 9 fed2019 polls (0.45 -> 0.67).

Refused since: dropping `fed_aligned`, retested time-forward (all its gain is
nsw2023; the term is real). nsw2023's remaining statewide gap is the
fundamentals' honest error.

IN FLIGHT 22:40: rebuild W, the permutation control for AUSPOL_DEMO_RESID=2 (rebuild V passed criteria 1-2: RMSE 4.2065 -> 4.2052, ledger 0.2753 -> 0.2720). `plans/prereg-demographic-labor-greens-2026-09-29.md`.

Open, in order:
1. DONE 21:13: v51 republished with its fresh seat-poll weight (rebuild R2, 0.2753; the
   release carries R's stale-weight 0.2760). Local `output/` IS R2's now:
   `AUSPOL_REBUILD_FROM=8 AUSPOL_PUBLISH=1 bash scripts/rebuild_forecasts.sh`
   (Pete). PRs #70 and #71 merged; `main` = `dev`.
2. Seat polls: PARKED. Three arms refused (S, T, U). The open problem is the
   weight, fitted on one or two earlier polled elections. Resume only with a
   source adding earlier polled elections. "Independent" = Pete's allowlist.
3. Change seats beyond the statewide miss (Parramatta, Heathcote): walk
   examples with Pete before any rule.
4. PR #743 (inthegame-blog): its politics sentence quotes v50; update to v51
   (RMSE 4.88 vs 5.42, accuracy 88.3% vs 86.8%, log loss 0.276 vs 0.285)
   before merging. Review of that part unconfirmed.

## 2026-09-29 17:00

**Published: ledger v50** (0.2719 vs AEF 0.2851; accuracy 88.9%; primary
RMSE 4.89; TCP MAE 3.79, the one measure AEF leads at 3.63). `main` = PR #69.
Snapshots: `output/rebuild-{K,L,M,N,P,Q,R}/` (P = v50; Q = refused MRP split,
its harness files moved to `rebuild-Q/harness/`).

**IN FLIGHT when the session closed: rebuild R** (full, launched 16:57,
`output/rebuild-R.log`), the statewide time-forward leak fix
(`plans/prereg-statewide-time-forward-2026-09-29.md`, `ac2bc1d`). First thing
next session:
1. Check `output/rebuild-R.log` reached "stage split"; snapshot to
   `output/rebuild-R/`; `Rscript scripts/compare_rebuilds.R output/rebuild-P output/rebuild-R`
   plus the per-ledger-election table; report nsw2023's FS1 line (was trend
   54.17, projection 52.03, Labor primary 32.1 vs actual 37.0).
2. A leak fix ships whatever it scores: RESULT section in the prereg, v51
   changelog entry, then Pete publishes (`AUSPOL_REBUILD_FROM=8 AUSPOL_PUBLISH=1`).
   Local `output/` is rebuild R's once it finishes, so do not publish before
   scoring it.
3. Review + PR dev -> main for 7766034..ac2bc1d.

Open after that, in order:
1. nsw2023: the remaining statewide drag is the fundamentals themselves
   (46.2 vs actual ~54.3), not a leak -- retest dropping `fed_aligned`
   time-forward (audit #1).
2. Seat polls: direct-poll weight on INDEPENDENT polls only (commissioned
   Climate 200 / uComms polls wrecked McMahon and Bullwinkel in the refused
   split).
3. Change seats beyond the statewide miss (Parramatta ~10, Heathcote ~9
   points seat-specific): walk examples with Pete before any rule.
4. PR #743 (inthegame-blog) carries the v50 sentence plus another session's
   AFL work: Pete or that session merges it.

## 2026-09-29 12:15 (read this first)

**Built: ledger v49** (0.2812 vs AEF 0.2851; all-22 pooled 0.3268; primary
RMSE 4.96; TCP MAE 3.68). **Published release is still v48** until
`AUSPOL_REBUILD_FROM=8 AUSPOL_PUBLISH=1 bash scripts/rebuild_forecasts.sh`
runs (Pete; blocked for Claude as a production deploy). That publish also
uploads `seat-swing-port-vic2026.csv`; until then the nightly forecast
(which runs from `dev`, the default branch) prints `SP2!!` and runs unported.
Local `output/` = rebuild M = v49; snapshots in `output/rebuild-{K,L,M}/`.
PR #68 (dev -> main) open. Blog sentence quotes v45/v46: update to v49.

Open, in order (retest list: `reviews/refused-arms-retest-audit-2026-09-29.md`):
1. Calibration temperature (+2.85 SE on the 21 Aug model) remeasured on v49.
2. Complete the 2025 no-prior divisions (Bendigo, Wannon, Nicholls,
   Goldstein, Mackellar, Brisbane) so the port's seats stop resting on a
   few fringe booths; shrink the port by booth coverage.
3. Departed-member side features with the completed retirement data
   (Parramatta, Heathcote, Camden).
4. Federal seat polls (7,054 rows) as a seat-level feature.
5. 9 Nov: live candidate split (v44's bucket split is backtest-only).

## 2026-09-29 00:50 (read this first)

**Published: ledger v47** (0.2840 vs AEF 0.2851; all-22 pooled 0.3214;
primary RMSE 4.99). Local `output/` is rebuild K's = v47. The blog sentence
still quotes v45/v46 (log loss 0.282, RMSE 4.98): update to 0.284 / 4.99 /
87.x% on the next blog touch. pannaverse is running a ~3 h job from 00:43;
check memory before the next rebuild. Open: (1) nsw2023 statewide Labor
miss with the Newspoll state data; (2) the two-candidate margin (AEF 3.63 vs
3.90); (3) 9 Nov live candidate split.

## 2026-09-29 00:30

Still published: **ledger v46** (0.2822 vs AEF 0.2851). Local `output/` is
rebuild J's (refused). Refused since v46, each in its prereg with numbers:
sitting-member shift (G), margin fill (H), margin from one source (I, a
tie; margin work stopped), slope shrinkage toward 1 (J: early elections
better, ledger 0.2878). Open, in order:
1. Refit the hardcoded `SHIP_SAME/SHIP_NEW` slopes (`R/split_slope.R:330`)
   time-forward; ONP returning-candidate cells use them in 4 ledger
   elections (fitted on every election, a remaining leak).
2. nsw2023 statewide Labor miss (-4.8) with the Newspoll state breakdowns.
3. Two-candidate margin (the one measure AEF leads: 3.63 vs 3.85).
4. 9 Nov: live candidate split.

## 2026-09-28 late

**Published: ledger v46** (0.2822 vs AEF 0.2851; all-22 pooled 0.3193;
primary RMSE 4.95). Local `output/` holds rebuild G's files (REFUSED: the
sitting-member shift); the release carries v46.

**Measurement trap found:** `output/forecasts.csv` `xgb_pred` is RAW model
output, not rescaled per seat (sums 78.7-113.2, mean 97.8); the simulation
and ledger use rescaled shares. Use `xgb_pred_seat` (added) for any residual
analysis. Today's D and G group residuals carried the artefact; their
verdicts (ledger-based) stand.

Open, in order: (1) finish seat context phase 2 (margin, previous swing;
first-term flags' definition); (2) shrinkage instead of `min_n` cliffs in
the time-forward fits; (3) nsw2023 statewide Labor miss with the Newspoll
state data; (4) 9 Nov live candidate split.

## 2026-09-28 evening

**Ledger v45 PUBLISHED 18:23** (manifest git 79515af): seat log loss
**0.2815** vs AEF 0.2851 (first time ahead), primary RMSE 4.98 vs 5.42,
TCP MAE 3.86 vs 3.63. **All-22-election pooled 0.3193** (v44's 0.3072 was
flattered by hindsight). Measure every change against BOTH numbers.
v45 = v44 + every constant inside base_pred time-forward
(`AUSPOL_TIME_FORWARD_FITS`, `R/time_forward.R`).

Measured and OFF today (each recorded in its prereg): anchor-implied,
exhaust (twice), others-bucket size, proportional closure, candidate
bucket total, shrunk blend (audit pass, rebuild fail 0.2893), departed-member
xgb features (0.2902; the miss is in base_pred).

IN FLIGHT 22:40: rebuild W, the permutation control for AUSPOL_DEMO_RESID=2 (rebuild V passed criteria 1-2: RMSE 4.2065 -> 4.2052, ledger 0.2753 -> 0.2720). `plans/prereg-demographic-labor-greens-2026-09-29.md`.

Open, in order:
1. **base_pred sitting-member effect** on the COMPLETED retirement data
   (`external/reference/retirements/retirements.csv`, 393 rows, 30
   elections): incumbent party +1.93 under-called when the member stays,
   -1.00 when they retire; retired and lost-preselection look alike (n 9).
2. Replace the `min_n` cliffs in the time-forward fits with shrinkage
   (early pairs now snap to slope 1.000 below 40 rows).
3. 9 Nov: wire the candidate split live (`fit_minor_candidates.R` v3 exists).
4. Newspoll/DemosAU data (`external/reference/polls/`): federal-in-state
   signal for state elections; crosstabs x census (design with Pete).
5. Blog PR **#747** (v45 numbers) awaits Pete's merge.

## 2026-09-28 (read this first)

**Ledger v44 PUBLISHED 14:45** (`shipped-models`, manifest git c5e8337):
seat log loss **0.2881** vs AEF 0.2851, weighted primary RMSE 5.04 vs 5.42,
accuracy 88.0% vs 86.8%. Two changes: the `state_poll_dev` LEAK removed
(it used the actual national swing) plus fed2025 Newspoll state rows; the
others bucket split by the per-candidate model (`AUSPOL_BUCKET_SPLIT=cand_naive`)
in all six harnesses. Live Victoria now anchors its level like the backtests
(`AUSPOL_LIVE_LEVEL_ANCHOR=1`, Labor ~35 -> ~31 seats from the 29 Sep run).

IN FLIGHT 22:40: rebuild W, the permutation control for AUSPOL_DEMO_RESID=2 (rebuild V passed criteria 1-2: RMSE 4.2065 -> 4.2052, ledger 0.2753 -> 0.2720). `plans/prereg-demographic-labor-greens-2026-09-29.md`.

Open, in order:
1. **9 Nov**: wire the candidate split into LIVE `fit_seats_full.R` once
   the VEC candidate list exists (`fit_minor_candidates.R` on vic2026 rows).
2. Federal-in-state polling as a second signal for state elections (route 2);
   crosstabs x census for seats (route 3, design with Pete on real rows).
   Data fetched: `external/reference/polls/` (Newspoll quarterly, DemosAU).
3. The others bucket's TOTAL is still too small/large by ~2 (size arms
   refused: `prereg-others-bucket-size`, `prereg-close-proportional`).
4. `build_page.R:263` still reads `simulate_seats()` for the pendulum.
5. Blog PR **#747** (politics-only benchmark sentence, v44 numbers) awaits
   Pete's merge; #743 now also carries match-chains work.

## 2026-09-27

v42 KEPT (Pete). No model freeze: keep improving to 28 Nov, each change a
ledger version. Production fixes: 21 Sep publish failure (`fit_seats.R`
sprintf) fixed and the retired two-party model removed from `run_all.R`
(refresh run 36321725267 green); history `built_at` drift fixed; ITG page's
false "beats the benchmark on log loss" claim corrected, blog PR #743
awaiting Pete's merge (the merge was blocked for me). Open for the page:
`build_page.R:263` still takes pendulum rows from `simulate_seats()`; seat
map, per-seat cards, forecast-over-time chart.

Statewide-level arms 27-28 Sep, all measured on the 22-pair audit and left
OFF (results appended to each prereg): `AUSPOL_ANCHOR_IMPLIED` (t -0.77),
`AUSPOL_ANCHOR_EXHAUST` (NSW units bug is real; nsw2023 better, nsw2019
worse), `AUSPOL_OTHERS_SCALE` (t -0.96; small-n weight flaw at fed2007).
The unpolled "others" bucket is the common thread: too big in 17 of 22
(mean |size error| 2.01) and split badly by last election's mix (3.39).
The SPLIT is a design-with-Pete item on real rows.

**Parity gap found 2026-09-28, not yet fixed**: live `fit_seats_full.R`
takes its statewide LEVEL from the raw trend endpoints (`state_mean`,
line ~522); its two-party anchoring moves only the draws, whose mean
`simulate_seat_contests()` subtracts (`R/seat_sim.R:970`). The backtests'
level is the ANCHORED mean (`forecast_statewide_or_oracle`). So the ledger
scores a fundamentals pull production does not apply. Size today: ~0.04
points of Labor first preference (trend implies 48.02, projection 47.98),
but it varies by cycle.

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
- ITG page: a seat map (regions are in the JSON now) and per-seat cards.

## Awaiting Pete

- **The repo is ALREADY public** (found 2026-09-27; this item used to ask
  whether to make it so). `docs/plans/product-features.md` names competitors
  and the scorecard names pollsters: is that fine as it stands?
- The four improvement-quiz questions (`ANCHOR-MODEL.md`, "Honest
  assessment"); two now have measured answers.
- Market odds or seat polls as an exogenous input for new independents: a
  different kind of input, Pete's call.
- Centre Alliance / SA-BEST class (OTH vs IND).
