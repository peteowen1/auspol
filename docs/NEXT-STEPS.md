# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before the 2026-09-19 rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`;
closed items of 7-19 Oct, verbatim: `backlog/journal-2026-10-07-to-2026-10-15.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30; slimmed 2026-10-19.

## NEEDS PETE

- **Status 30 Oct.** Published config is the 28 Oct stage-6 rebuild (3C shipped, PR #159; AEF-7 0.2639 vs AEF
  0.2825; snapshot `output/snapshots/20261028-1109-14111624-from6`). 30 Oct: MP-slope pool SHIPPED on `dev`
  (`AUSPOL_MP_SLOPE_POOL=1`, Pete over clause 3; DECISIONS); it reaches the published forecast when dev merges to
  main. The worker-started forecast and ops ran on time 30 Oct (04:30 run success, 08:58 cron skipped at its gate).
- **Election-night live model, map https://github.com/peteowen1/auspol/issues/148.** Plan and replays:
  `docs/plans/election-night-booth-model.md` (vic2022 seat log loss vs afternoon 0.2643: 0.1133 at 10% counted,
  0.0929 at 50%). Upper house designed, NOT built (`plans/upper-house-night-model.md`). DONE: VEC sign-up (#150),
  night runner (`R/night_runner.R`, `scripts/night_loop.R`), page PUBLISHED unlisted https://inthegame.blog/politics/live
  (ITG #1057, maps, TCP booth colours #1068, live booths #1069, 2026 booth builder #1070), per-booth results (#168),
  R2 upload tested to `auspol/night/test-vic2026.json` (`scripts/night_publish_r2.sh`), night state saved every forecast
  run and uploaded to `forecast-latest` (#169), break-glass Actions backup `.github/workflows/night-backup.yaml` (#170;
  inputs on release `night-inputs`). Night runbook: `gh release download forecast-latest -p night-state-vic-2026.rds -D
  output`, then `night_runner.R --state=output/night-state-vic-2026.rds`.
  OPEN, in order:
  2. SharePoint live-feed fetch (VEC access details from 4 Nov); the backup's source live waits on it.
  3. 10 Nov: in ITG `politics/night-maps/`, `python -I build-booths-2026.py <State2026MediaFilePollingLocationsV2.xml>`
     (expect ~88 districts, few "new" centres; refuses under 85 districts or half matched), commit `booths-vic2026.json`.
  3b. DONE 30 Oct: the night JSON writes `sn` per booth and `swing` per seat (`night_booth_results(conv, ref)`,
     `night_seat_swing()`, `R/night_runner.R`). Booth swings equal the page builder's `s` on all 1,325 vic2022 booths
     (max difference 0); the seat swing is like for like over matched booths (vs the builder's whole-district
     `dswing`: median gap 0.46 pts on 2022's redistribution). A damaged reference table drops the swing (NW14), not the booths.
  4. Navbar link; the "called" rule (99% with 10% counted is a placeholder); find my seat (#166).
  5. Trial 25 Nov (no 2CP); the upper-house model.
  Dated: the satellite basemap's Esri key (Pete's account, basemaps only, pay-as-you-go off) expires 27/10/2027.
- 28 Oct: value-odds page https://claude.ai/artifact/GdrpxSB7zkY1xEvJvU3TKx (readiness, seat click-through, our
  probabilities against Sportsbet/TAB/Betfair). Built from scratchpad scripts, not the repo: it does not refresh.
  Contested-seat research, all committed: `reviews/contested-seats-vic2026-2026-10-28.md` (hub),
  `new-party-fill-proportional-vs-uniform-2026-10-28.md` (proportional One Nation fill supported, 4 elections),
  `contested-seats-light-checks-2026-10-28.md` (agent's sign error corrected at the top; other-right lead pooled over
  20 elections is -0.040, SE 0.015: small), `live-walk-contested-seats-2026-10-28.md` (xgb cut to the eastern Liberals
  0.1-1.6, not 3). Branch checks `ind-overcall-1025` and `mp-slope-shrink-1025`: both PASS `check_like_ci.R` 28 Oct.
  Still open from it: One Nation spread pooling (needs code: spread fixed to SA 2026 at `fit_seats_full.R:781`);
  Hastings/Cranbourne recheck after nominations (9 Nov); re-entry inflated bases (other classes over-called -2.9,
  SE 0.84, where a party re-entered; Narracan Greens is the live case).

- F16 `AUSPOL_ROW_SHIFT_EXACT` NOT PASSED 29 Oct (DECISIONS). OPEN: F18 `AUSPOL_NOM_ZERO_PRE_XGB` (off): walk 1 done
  29 Oct (predictions 1, 2, 4 pass; 3 a finding in Morwell, to walk with Pete); walk 2 on the VEC final list. Dead-party
  `AUSPOL_LEVEL_DEAD_PARTY` (337f4cd) PARKED: its screen says not worth it; do not merge.
- OPEN, screens not yet run (one at a time, >= 6.5 GB free): width A0/A1; departed arm B. F8 RN is dead
  (arm N worse). F8 arm N's netting costs 579 s per harness run: cache it to disk before any rerun.

- OPEN, DATED (Tue 27 Oct, 3, 10, 17 and Fri 27 Nov): vic2026 benchmark capture. Built and run 22 Oct (all four
  sources, `docs/benchmarks/vic2026/2026-10-22/`). Each date: `Rscript scripts/snapshot_benchmarks.R`, plus the GES
  Chrome step (`scripts/ges_read_calls.js`; plan Amendment 1), rerun the script, commit the calls folder, rerun
  `scripts/build_data_registry.R`. Scorer BUILT 23 Oct: `Rscript scripts/score_benchmarks_vic2026.R --results=<csv>`
  (`district, winner, status`; winner as the VEC prints the party) once every district is declared; `--dry-run` passes
  its known answer now (ours 88/88 against its own favourites). Still to build: the VEC 2026 results file itself.
  Roy Morgan dropped 21 Oct (no seat winners) (`plans/external-benchmark-vic2026-2026-10-20.md`).

- Builds waiting for R (26 Oct, each on a LOCAL branch, not pushed). `mp-slope-shrink-1025` is in dev and SHIPPED
  30 Oct (DECISIONS). `ind-overcall-1025` passes `check_like_ci.R` (28 Oct), 3 commits not in dev. One quick_arm
  screen at a time:
  - `ind-overcall-1025` `7252acb`, merged into dev 30 Oct (`016ed0c3`): `AUSPOL_IND_GAP_RESTAND` (off). The SHARE
    version is NOT built, on Pete's call 30 Oct: it changes nothing, since the base already holds a re-stander's own
    vote (DECISIONS 2026-10-30). The yes/no arm REFUSED on AEF-7 30 Oct (moved seats +0.0014, SE 0.0007; prereg
    RESULT). Fitted-rate follow-up CLOSED 30 Oct (Pete): measured carry 0.357 on 513 seat-elections vs 0.33-0.38
    shipped (`reviews/ind-gap-carry-walk-2026-10-30.md`). Idea only: below-level seats carry ~0 (moves < 1 pt). OPEN: trace the 52 seat-elections where
    the leader re-stands but no own vote showed in the base (first Corio fed2007, Kiama nsw2023), with the harness discounts.
    Shepparton is a true re-stand (Sheed 29.4 in 2022, VEC). Prereg `plans/prereg-ind-gap-restand-2026-10-25.md` (on that branch).
  - `prereg-offbranches-1025` `ee80497`: preregs for XGB_CLASS_JUR_CAL (merges clean), OTHERS_SCALE_JUR
    (identical to the refused pooled arm at every AEF-7 target on cached history), SALIENCE_STATE (needs two as-at
    retrains; blanks for fed/WA/vic2026 rows are a jurisdiction marker risk), departed-rate-refit (10 conflicts;
    3 choices for Pete: fallback 0.38 / slope 1.0 / per-target rate; fit rows; which decision rule).
  - `fed-breakdowns-prereg-1026` `45e2bc4`: federal state breakdowns in the state trend. Reaches vic2022, nsw2023,
    qld2024, wa2025, sa2026 (qld2020/sa2022 trace). Pete added 90/180 days out as a second deciding metric:
    written as Amendment 1 (6a3d89c7, 27 Oct).
- OPEN, 26 Oct decisions not yet built: hunt the real primaries for two-candidate-only seat polls (Fowler 2022
  Laidlaw, Pittwater 2023 Freshwater, Cowper and New England 2016) into `hand_keyed_primaries.csv`; if none found,
  try inferring the primary from the two-candidate split (J4 30 Sep is the refused relative). Prereg a shrunk,
  time-forward "seat polls under-call new independents" term (5 of 10 polled new independents under-called by
  9-22 points: Mayo, Warringah, Kooyong, Mackellar, Mount Gambier). Seat polls already reach new independents:
  mean miss 23.4 before the blend, 11.6 published, 10 seats (Wakehurst published 30.0, not 13.7).
- OPEN (review nit, 30 Oct, not blocking): the shipped MP-slope pool's tau^2 is inflated where one OTH_RIGHT member
  slope of -23.1 (n 1, se ~11) enters the DerSimonian-Laird sum: qld2015, sa2014, vic2014 get tau^2 ~0.57 (0 at most
  targets), so IND there keeps w 0.99 instead of pooling (`output/mp-slope-pooled.csv`; `R/mp_slope_pool.R:79-83`).
  The all-35 screen ran on this table. A fix (drop near-zero-variance classes from the tau^2 sum) needs its own screen.
- OPEN, morning pages for Pete: (b) wa2017 and fed2019 day-before statewide walk-throughs, example rows. (a) Mildura
  DONE 30 Oct, https://claude.ai/artifact/JTt68EkaupnKVaoC3VRYib (`AUSPOL_TRACE_SEAT=<seat>` on `fit_seats_full.R`
  prints any seat's row after every stage, TRS0/TRS1). Raised, OPEN: the xgb trees cut Cupper 25.1 -> 21.0 unexplained
  (contributions done 30 Oct: base size -2.08, party_IND -1.45, own_prev +1.36). CHECKED 30 Oct, the cut is not an
  over-cut (`reviews/ind-tree-cut-returning-2026-10-30.md`): returning IND who lost last time with >= 20, n 14 in 11
  elections, trees RAISE them +1.6 on average and actual still falls below xgb in 10 of 14 (bias xgb -4.5, SE 2.6);
  where the trees cut a big returning IND by 2+ (n 12) error goes -3.0 -> +0.6. No offset supported. Cupper herself
  has been under-called every time (vic2018 ours 30.4 vs 39.6): one person, untested idea of a per-person trend.
  Labor's base floors at 0.00 in Mildura (6.5 in 2022, level -12.2 at slope 0.92), trees restore 4.3. CHECKED 30 Oct
  (`reviews/small-share-swing-floor-2026-10-30.md`, counts recomputed): the floor bites 179 of 13,286 stood cells
  (1.3%; 152 OTH; 165 had no share last time), trees repair part (RMSE 4.31 -> 3.27, mean actual 3.18 vs xgb 1.04).
  Oracle on true levels: a direction-aware base (points when a class rises, logit when it falls) beats points-only in
  30 of 35 elections (pooled RMSE 5.27 -> 5.08), shrinking at the real slopes. Pete: build and screen (30 Oct).
  BUILT 30 Oct, off: `AUSPOL_SWING_FORM=hybrid` (`dev_slope()`, post-xgb; prereg `plans/prereg-swing-form-hybrid-2026-10-30.md`).
  Screen: `Rscript scripts/quick_arm.R "AUSPOL_SWING_FORM=hybrid"` (AEF-7), then `--pairs=all`; dry-run check first:
  `AUSPOL_TRACE_SEAT=Mildura AUSPOL_SWING_FORM=hybrid AUSPOL_OUT_SUFFIX=-sw` on fit_seats_full.R, TRS0 ALP base 5.16.
  REFUSED on AEF-7 30 Oct (pooled +0.0036, SE 0.0028; worse in every share band; prereg RESULT). Stays off.
  The Mildura Labor 0.00 floor remains, and the trees repair it to 4.3; no further work planned.
  One Nation fill pro rata vs personal votes: CHECKED 30 Oct, keep proportional (`reviews/onp-fill-personal-vote-2026-10-30.md`:
  returning IND ratio 0.68 vs majors 0.76 in 7 surge seats, 3 elections, diff -0.13 SE 0.23; calm seats +0.06 SE 0.06).
  Thin (sa2026 is 5 of 7); recheck after vic2026 counts.

- OPEN, Pete: returning independents. Both arms REFUSED 25 Oct (`plans/prereg-ind-return-2026-10-25.md`); the
  x0.61 multiplicative minor-field scale (a live-only train/serve split) was fixed by `AUSPOL_MINOR_ADDITIVE=1`,
  SHIPPED 25 Oct live only (DECISIONS). Still open: Mildura 25.6 vs Cupper's 33.9 (One Nation's fill takes the
  rest); live `FST1!` (no candidate-model split for vic2026); Kew and Hawthorn, where the bookies price independents
  far above us; Benambra (a NEW independent succeeding Hawkins).

## 2026-10-18 pipeline audit (READ FIRST; `reviews/pipeline-overwrite-audit-2026-10-18.md`, Sonnet, read-only)

20 findings where work is overwritten, doubled or ignored, or live and backtest diverge. Spot-checked in code 18 Oct.
Closed from it (journal): rules review (standard decision rule now heads `PRE-REGISTRATION-RULES.md`), seat-poll
TCP-consistency check, arm H shipped, heavy-tail arm T REFUSED 19 Oct, F21 surge_h fixed. Closed 18-21 Oct
(`backlog/journal-2026-10-16-to-2026-10-22.md`): F1-F3 shipped, F4 net-out shipped and published, F5 and F9 refused,
contest features / contest base / partial-contest arm A refused, first-term fill refused, seat context published.
- OPEN, from the 22 Oct old-election fill diagnosis (the `AUSPOL_TRAIN_DECAY_H=4` test of it REFUSED 25 Oct,
  half-life stays 8; DECISIONS, `plans/prereg-train-decay-4-2026-10-22.md`): Greens over-called in high-Greens seats by the trees (Melbourne, Griffith, Northcote);
  retiring Labor members about -2.0 (n 34); Dickson's published stage moved a correct tree LNP figure +5.5.
- OPEN: width arms A0/A1 (`AUSPOL_FP_EXTRA_SD` 0 / 1.2) pre-registered, not yet run (needs the memory F7 needs).
  NOT RUN 25-26 Oct either: the night queue reached GRN_TREE_SHRINK by 00:59, and the next launch could not finish
  before the 03:15 F7 deciding run (memory sat at 3-7 GB from 20:30, so harness runs took about 2 minutes each).
- 25-26 Oct night screens (quick_arm, results appended to each prereg): One Nation new-seat rule arm A REFUSED (target
  log loss +0.0007, SE 0.0004); arm B NOT PASSED (-0.0088, SE 0.0090; the whole gain is qld2017; sa2026 clause 4a).
  B v A where both rules apply is +0.0012 (SE 0.0012), so no House-v-Senate difference is measurable. Surge-level all
  35 NOT PASSED (target -0.0016, SE 0.0036; LOO sign lost). F8 arm R all 35: +0.0003 (SE 0.0005), not shipped. F8 arm N
  WORSE on AEF-7 (+0.0003, SE 0.0002), stopped; its netting costs 579 s per harness run (cache it before any rerun).
  RN not run (it needs R and N to pass). GRN_TREE_SHRINK all 35, LEFT OFF 26 Oct (Pete, after the trace): the primary passes (Greens squared error
  -0.1247, SE 0.1133, 511 cells) but clause 3 refuses (vic2022 worse by 2.5 SE; leave-one-out above 1 SE in only 15 of 19
  drops); seat log loss is unchanged (-0.0000). Departed-origin arm A all 35 NOT PASSED (changed-cell share error
  +1.33, SE 2.56; Mount Gambier, Hillarys and Cabramatta outweigh Morwell). Its part 2 (the xgb feature, stage-4
  rebuild) CLOSED 27 Oct, not run (Pete agreed). Still not run: departed arm B
  (`mean`). Level-conserve (refused 29 Oct) and port 3C (shipped 28 Oct) are closed.
- OPEN, DATED (final snapshot 25-27 Nov is the one that ships, per Pete 27 Oct; earlier weekly ones from ~3 Nov are
  for watching only, not the forecast): vic2026 salience snapshots. 26 Oct snapshot fetched, 0 of 101 batches linkable. All 500 candidates fetched
  18 Oct (window to 6 Oct), but that is before the campaign: nobody's search interest is rising yet (Premier 1.1 in the
  last 8 weeks vs 9.3 before), so batches cannot be linked and `jump` is not comparable with the backtests' polling-day
  values. Each refresh: `AUSPOL_SALIENCE_TO=<date> Rscript scripts/fetch_salience_vic2026_full.R` (~100 requests,
  resumable; anchor now Jacinta Allan, was Daniel Andrews), then `scripts/build_vic2026_salience_jump.R`
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

- PROVEN 29 Oct: `seat_sd` is inert under the shipped `AUSPOL_LEVEL_SD` ("1.10,8.67"): same seed, seat_sd 3.5 vs 50,
  identical win probabilities; with level_sd off it moves (test-level_sd.R, 76a1008d). It stays as the flat-variance
  fallback. NB `AUSPOL_SEAT_SD_MULT` is NOT a seat_sd knob: it also scales level_sd (vic2022 at 50x: 0.2643 -> 1.3561).

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
- OPEN registries regenerated after the final rebuild (DATA/MODEL/POLL); SEAT-REGISTRY entries for the new worst seats.

## 2026-10-11 to 2026-10-12: still open (collapsed 15 Oct)

Shipped and merged (PRs #119-#125). **ORDER still matters: publish a rebuild (AUSPOL_PUBLISH=1) BEFORE merging to main**
whenever a change adds a file `forecast.yaml` downloads. Refused, built and off (do not rerun without a new idea):
leader ratings as a model input, trend-replaces-blend, poll-level centring, the two-way person rule, statewide poll
weighting by track record, seat-poll precision blend, typical-vote independent models.

- OPEN poll weighting (Pete wants "a LOT better"): federal state breakdowns preregistered 26 Oct (branch
  `fed-breakdowns-prereg-1026`; see "Builds waiting for R"). `reviews/poll-weighting-inventory-2026-10-12.md`.
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
  `reviews/seat-poll-methods-2026-10-18.md`). NEXT: prereg seat-poll weights by method and sponsor (+ per-pollster
  reliability, consensus down-weight), time-forward, shrunk by group size, scored on seat-poll seats. Dirty pollster
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

- **NSW variance / floor seats**: per-cell fat tails already SHIP (`AUSPOL_ERROR_DIST=1`, `published_flags.R:763`,
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
- **Surge v4 vs salience**: hazard AUC 0.936 vs 0.751 but over-dispersed;
  deciding seat-count test not run (`prereg-xgb-surge-parameters-v2`).
- **Overcalled independents**: building on `ind-overcall-1025` (see "Builds waiting for R"). Successor overcalls
  (Morwell, Mildura, Kavel, Finniss) are a separate item, not started; departed-hold refused.
- **Simulation noise revives zeroed parties** (`R/seat_sim.R:1455`, `v <- base_v + shift + rnorm(K, 0, sd_cell)`, or an equal-quantile draw when `has_eq`):
  written shares are 0, draws are not. Measure how often a revived cell places or wins before masking it;
  affects every harness number, so it needs a prereg. Unmeasured.
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
  pooled slope, and was refused 29 Sep (+0.0056, SE 0.0035). DECIDED 27 Oct (Pete): build a tau^2 arm toward
  the pooled slope; NOT built, no prereg yet (the MP-slope pool shipped 30 Oct is a different fit). The `SHIP_SAME/NEW`
  leak is DONE: `AUSPOL_SHIP_TIME_FORWARD=1` (v51) makes the fallback time-forward; the constants are opt-out only.
- **Seat context phase 2**: margin BUILT 28 Sep as arm `AUSPOL_SEAT_CONTEXT_MARGIN` (published "0"; `5e50f07`), no
  recorded verdict; previous swing not filled (r 0.875 vs the seat file); first-term fill refused (Oct 20 prereg).
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

Closed 2026-09-19/20 (DECISIONS; fast loop in `PIPELINE.md` C0): forecast
mode everywhere, time-forward folds, registry classified, zero-placeholder
audit, smoke loop + as-at cache + `tidy_output.R`, `out_path()`.

Still open:
- Both branches below RECREATED 25 Oct on Pete's yes (local only, not pushed).
- Branch `fed-timing-resume-fixed` (b21fb77, unmerged, NOT through the review gate or `check_like_ci`): fixes
  the federal `PARTY_COR` loop leak (a full fed run simulates every pair with the LAST pair's matrix; dormant
  at published defaults because `AUSPOL_FORECAST_MODE=1` skips the matrix; live for fed with FORECAST_MODE=0),
  adds per-pair timing and an opt-in resume cache (`AUSPOL_FED_RESUME=1`). Ran live: outputs byte-identical.
  Untested: more than one pair, a kill mid-run. `FLOW_SD` has the same loop leak, unfixed (dormant,
  `AUSPOL_FLOW_SD_BY_SOURCE` default 0). Also `instrument-backtest-fed-timing` (ae91f62), paused.
- The seat-poll, demographic and leader-seat corrections learn from the PREVIOUS rebuild's
  `output/forecasts.csv`, so a rebuild's result depends on the one before it; make them read this run's
  as-at predictions (queued 2026-09-30; the spread fix's compare-and-rerun pattern, `scripts/compare_spread_tables.R`,
  could cover it). Still live 23 Oct: `R/demographic_residual.R:213` and
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
- Federal results as a correlated signal for state seat lean: needs
  seat-boundary matching (`external/reference/boundaries/` has CED 2016).
- GDELT parked (needs a GCP project); Census 2006/2001 have no bulk pack.
- OPEN: ITG page: a seat map (regions are in the JSON now), per-seat cards, a forecast-over-time chart.
- OPEN: bare "LDP" -> OTH_RIGHT is in `classify_party()` (Pete, 25 Oct; 47 fed2007 + 4 vic2026 rows). Takes effect
  only after `build_candidacies.R` reruns and `candidacies.csv` is re-uploaded to `shipped-models`; fed2007 needs a
  screen (`quick_arm.R --pairs=fed2007`) after that rebuild.

## Awaiting Pete

Nothing (departed-rate answered 29 Oct, census 27 Oct; DECISIONS).
- OPEN, build: departed-rate fit restricted to cells the successor table does not name (Pete, 29 Oct; Amendment 1
  of `plans/prereg-departed-rate-screen-2026-10-25.md` on `prereg-offbranches-1025`), then its screen.
