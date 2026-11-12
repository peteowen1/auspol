# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before the 2026-09-19 rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`;
closed items of 7-19 Oct, verbatim: `backlog/journal-2026-10-07-to-2026-10-15.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30; slimmed 2026-10-19.

## NEEDS PETE

- CLOSED 4 Nov, NOT SHIPPING (told Pete): poll weighting by type, company and age. All six arms refused on 38
  elections (`plans/prereg-poll-lean-2026-11-02.md`; DECISIONS 2026-11-04). OPEN triggers: (a) MOOT for vic2026
  (10 Nov: One Nation stands in all 88 seats, so no seat-count conditioning applies; recheck for nsw2027's list); (b) after vic2026, re-test sponsor lean
  (first completed election with party-commissioned polls labelled). Seat-poll side PARKED 5 Nov (told Pete;
  `AUSPOL_SEAT_POLL_FIRM_FLOOR` stays "0"; see "Seat polls: PARKED").
- **Status 12 Nov, 4:30pm.** main = dev as of PR #224 (0.4.158, merged 4:01pm): NSW 2007 fix, night stale warning, replay
  seat names, Lighthouse one page. dev and main CI green. Nothing running.
- OPEN, NIGHT SOURCE (before 28 Nov): the VEC REFUSED the feed (11 Nov); the night now runs on the VEC WEBSITE.
  BUILT 11 Nov: `R/vec_web.R` (page parser, 2026 + 2022 layouts; booth table identical to the feed path on vic2022's
  final count, every booth cell), `scripts/fetch_vec_web_snapshot.R` (index page -> each district's two voting-centre
  pages -> stamped folder + manifest + DONE; tested on the live Nepean pages), `night_cycle(source_type = "web")` with
  `--source-type=web --enrolment=external/reference/vec/2026/enrolment/enrolment-2026.csv --places=external/reference/vec/2026/voting-locations/places-2026.csv`, `cand_ref = "copy"` by default
  there (Pete). End to end on 2022's pages: 87 districts published, ~65 s a cycle (parse 21 s, simulate 35 s).
  STILL OPEN: (1) the 2026 results index URL is only known on the night (the fetcher takes --index); (2) whether the
  pages fill in during the count (draft question in Pete's Gmail, unsent); (3) DONE 11 Nov: the 2026 voting-centre list, `scripts/build_vec_places_2026.R` from the VEC venues spreadsheet
  (1,851 election-day centres, est. 1,603,331 ordinary votes; 310 early centres). Re-download the spreadsheet the week of the
  election (it changes: Change Log sheet) and rerun. Only 61 of 200 guest joint centres (JVC) match a 2022 booth name: if one
  never gets its own results row it stays a small uncounted placeholder. Same day, found and fixed: the night never matched
  "South-West Coast" (model, website) to "South West Coast" (`booths-vic2026-ref.csv`), so that seat's declaration votes had no
  reference and its turnout fell to the state rate; `.night_seat_names()` now puts every input's names into the model's.
  Checked on all 88 districts with the 2022 pages under the live 2026 configuration (87 updated; Narracan has no 2022 page); (4) DONE 11 Nov: dress rehearsal of fetcher + loop on the live Nepean pages (found and fixed: the loop never saw website snapshots; the website candidate list has no enrolment, now `external/reference/vec/2026/enrolment/enrolment-2026.csv`, pass it as --enrolment); (5) the ITG booths build
  (`C:/dev/inthegame-blog/politics/night-maps/build-booths-2026.py`) also assumed the feed.
- OPEN, check 13 Nov morning: council-history rebuild `deciding-runs/20261112-1829-rebuild/` (stage 3, scheduled 11:30pm,
  waits for 8 GB, never publishes). Score it against `output/snapshots/20261110-0929-82329b06-from1` by
  `plans/prereg-council-coverage-2026-11-12.md` (control: untouched elections byte-identical; guards: 35-election log
  loss within 1 SE, share RMSE within 0.02). Pass: PR to main, then stage 9 publish. Fail: to Pete with the elections.
- OPEN, check after the NEXT STAGE-9 PUBLISH (not the daily run: it downloads the 9 Nov `seat-poll-blend-vic2026.csv` from
  the shipped-models release, which still has the old Pakenham row; checked 12 Nov): Pakenham seat poll corrected 12 Nov. Fieldwork 4-8 Nov (Poll Bludger), and its client was
  the typo "TKR", which filed a Herald Sun poll as stakeholder-sponsored (`direct_stake`); now `direct_indep` via a `poll_methods.csv`
  row. Before (R2 `seat-probs-vic-2026.csv`, 12 Nov 8:49am): ONP 0.829, LNP 0.161, ALP 0.005. Done when the first file after that publish is compared and the move reported. The hand-keyed rows are
  permanent: Wikipedia's vic2026 page lists only Hawthorn (checked 12 Nov). Roy Morgan's 21-26 Oct SMS poll of Bass/Hastings/
  Morwell/Pakenham (release 10371) gives no per-seat primaries, so it cannot be keyed. NOTE: `fetch_seat_polls.R` never refetches a
  cached page, so a new Wikipedia vic2026 seat poll would be missed: re-download `raw/vic2026.html` by hand if one appears.
- IN FLIGHT 9 Nov (Pete chose the levers): first-time-independent under-call. Six levers mapped in
  `reviews/newcomer-independents-walk-2026-11-09.md` (last section). Lever 1 REFUSED twice, stays off
  (`AUSPOL_NEW_IND_SHRINK_SIGNAL`, `_SIGNAL_CAP`; `plans/prereg-new-ind-shrink-signal-2026-11-09.md`: capped -68 SE 76;
  uncapped 35-election log loss +0.0022, the base-level factor double counts the trees). Lever 2 SHIPPED 9 Nov (PR #211, published 9:50pm): `AUSPOL_NEW_IND_LIFT=1` (`R/new_ind_lift.R`; prereg `plans/prereg-new-ind-lift-2026-11-09.md`), additive +2.4 to +5.1 points fitted on earlier PUBLISHED shares (pre-lift column `ours_prelift`); 20k: sq err -790 SE 687, log loss +0.0000. Live: Ringwood, Williamstown ~3.5 -> ~7. Next levers: spread signal term; council data gaps. Checked 12 Nov: Qld 2008 IS on disk and parses clean (`parse_ecq_council.py --include-2008`: 422 rows, all checks pass) but is PARTIAL: mayors for ~73 councils, councillors for 5 (Townsville, Sunshine Coast, Cairns, Brisbane, Bundaberg). Adding it as-is would mark every qld2009 seat covered, so a 2009 candidate who stood for councillor elsewhere would read as never-stood: coverage must become per council (councils overlapping the seat that have councillor pages that year), not per state-year (`build_council_history.py:218`). Noosa 2014 (Bolton, the motivating case) is not on disk at all: the 2014 de-amalgamation elections (Noosa, Douglas, Livingstone, Mareeba) need fetching. OPEN for Pete: betting odds as an input (he
  leans no; four elections of odds on disk). Seat-poll weight for new INDs PARKED (vic2026 has one seat poll).
  Background: 70 of 649 single first-timers took 15%+
  and we gave them about a third of it (Mackellar 18.6 v 38.1, Shepparton vic2014 7.0 v 35.2); 442 took under 5%, so no
  blanket lift (`reviews/newcomer-independents-walk-2026-11-09.md`). CORRECTED 9 Nov: the "generic 4-8%" was the
  per-candidate side model, which reaches seats only via the class split (OFF). `AUSPOL_MC_EXTRA=sal` has no route to the forecast that helps (screened 7 Nov; DECISIONS 2026-11-07;
  `reviews/aef7-gap-and-sal-screen-2026-11-07.md` section 1). Refits take 73 s with `AUSPOL_MC_ROUNDS_FROM`.
- OPEN 7-8 Nov, TCP error vs AEF (Pete): NSW exhaustion SHIPPED (`plans/prereg-nsw-exhaust-tcp-2026-11-07.md`); ledger
  TCP headline scores both sides on the SAME seats: 3.654 vs AEF 3.727 (n 667), goal met (PR #205). 8 Nov on dev
  (PR #206): C++ engine applies exhaust (NSW stage 6 ~65 -> 11 min); exhaust rates made time-forward (leak fix,
  `AUSPOL_NSW_EXHAUST_TF`). nsw2011/2015/2019 now get no exhaustion from the anchor (no earlier rates); measured rates
  from NSWEC's pages (`scripts/build_nsw_exhaust_measured.R`, all 2015/2019/2023 pages ARE cached) are the off arm
  `AUSPOL_NSW_EXHAUST_SRC=measured` (+ `_MEAS_MAJORS=0`), SHIPPED 8 Nov. fed2025: seat flow persistence SHIPPED 8 Nov
  (`plans/prereg-seat-flow-persistence-2026-11-08.md`; fed2022/25 TCP -0.12 each, older federal worse). Its inputs are
  FROZEN in git; states not built (need state TCP histories).
  Low priority, pre-existing: `fit_nsw.R`/`fit_federal.R`/`fit_vic.R` read same-year flow rows; they feed no backtest.
  OPEN, pre-existing (review 8 Nov): `AUSPOL_REBUILD_ONLY` reuse (`reuse_check()`, `rebuild_forecasts.sh`) checks file age, not
  flags, so after a switch flip a rebuild that skips the affected harness silently reuses its old-config results.
  FIXED, on main since PR #211 (9 Nov): the fingerprint drops run-control vars (eb0a628f); the first REBUILD_ONLY after
  it reuses nothing (old tags). PARKED, same area: `apply_upset_floor.R` fits only files newer than
  `AUSPOL_STAGE6_START`, so under REBUILD_ONLY the upset-floor fit drops every reused election. INERT (checked 10 Nov):
  `AUSPOL_UPSET_FLOOR="0"` (`published_flags.R:324`), so stage 6b never runs. Trigger: fix before that switch is ever
  turned on. The fix must keep reused files' raw copies (stage 6 `rm -rf output/upset-floor-raw`; reused files are
  already mixed in place) and refresh a rerun file's raw copy when it is older than `AUSPOL_STAGE6_START`.
- **Election-night live model, map https://github.com/peteowen1/auspol/issues/148.** History, DONE list and replay evidence:
  `backlog/journal-2026-11-05-election-night.md` (moved verbatim 6 Nov); plan `plans/election-night-booth-model.md`. Runbook:
  `gh release download forecast-latest -p night-state-vic-2026.rds -D output`, then `night_runner.R --state=output/night-state-vic-2026.rds
  --ref=output/booths-vic2026-ref.csv --council-lean=output/council-fp-2022.csv`. Live page https://inthegame.blog/politics/live
  (find my seat live, #166 closed 5 Nov). OPEN, in order:
  1. SharePoint live-feed fetch: same blocker as the VEC feed item above (no reply to the 9 Nov chase); the Actions backup's live source waits on it.
  2. BLOCKED on the feed (item 1 gives the XML): in ITG `politics/night-maps/`, `python -I build-booths-2026.py <State2026MediaFilePollingLocationsV2.xml>`, commit
     `booths-vic2026.json`; check the popup at 390/1280 px and the 38 Narracan-only 2018 names against the 2026 polling places.
  3. Navbar link. "Called" rule TESTED 10 Nov on the 7 simulated replays (`reviews/night-called-rule-2026-11-10.md`):
     keep 0.99 with 10% counted; its 3 wrong calls (Melbourne, Monash 2025; Mirani 2024) survive any threshold, so the
     fix is the final-pair defect below. OPEN: confirm on the real fed2022/fed2025/vic2022 nights, after the replay seat-names fix above (vic2022 rerun).
  4. 25 Nov trial (no 2CP): with real 2026 centre names, compare each counted early centre with its own 2022 upper-house lean,
     re-test `--early-partial=1` (off; it made the approximated replay worse), and take the expected early total from the
     VEC's published attendance. Upper-house model designed, not built (`plans/upper-house-night-model.md`).
  Dated: the Esri key (basemaps + geocoding, pay-as-you-go off) expires 27/10/2027.
- OPEN, from the 28 Oct contested-seat research (evidence and the value-odds page, which does not refresh:
  `reviews/needs-pete-evidence-2026-11-08.md`): One Nation spread pooling (needs code; spread fixed to SA 2026 by the
  `sa_ratio` quantile map in `fit_seats_full.R`); Hastings/Cranbourne recheck DONE 10 Nov (no change; `reviews/contested-seats-vic2026-2026-10-28.md` last section); re-entry inflated
  bases (other classes over-called -2.9, SE 0.84; Narracan Greens is the live case).


- OPEN, DATED (Tue 27 Oct, 3, 10, 17 and Fri 27 Nov): vic2026 benchmark capture. Built and run 22 Oct (all four
  sources, `docs/benchmarks/vic2026/2026-10-22/`). Each date: `Rscript scripts/snapshot_benchmarks.R`, plus the GES
  Chrome step (`scripts/ges_read_calls.js`; plan Amendment 1), rerun the script, commit the calls folder, rerun
  `scripts/build_data_registry.R`. Scorer BUILT 23 Oct: `Rscript scripts/score_benchmarks_vic2026.R --results=<csv>`
  (`district, winner, status`; winner as the VEC prints the party) once every district is declared; `--dry-run` passes
  its known answer now (ours 88/88 against its own favourites). Still to build: the VEC 2026 results file itself.
  Roy Morgan dropped 21 Oct (no seat winners) (`plans/external-benchmark-vic2026-2026-10-20.md`).

- Builds from 26 Oct branches (`mp-slope-shrink-1025` SHIPPED 30 Oct and `ind-overcall-1025` both merged into dev; only
  `prereg-offbranches-1025` is unmerged).
  One quick_arm screen at a time:
  - `ind-overcall-1025` (`AUSPOL_IND_GAP_RESTAND`, off): REFUSED and closed 30 Oct (DECISIONS 2026-10-30;
    `reviews/ind-gap-carry-walk-2026-10-30.md`). OPEN: trace the 52 seat-elections where
    the leader re-stands but no own vote showed in the base (first Corio fed2007, Kiama nsw2023), with the harness discounts.
    (4 Nov: where "52" came from is not recorded in the walk review or its rows file; rebuild the definition first.)
    Shepparton is a true re-stand (Sheed 29.4 in 2022, VEC). Prereg `plans/prereg-ind-gap-restand-2026-10-25.md` (on dev).
  - `prereg-offbranches-1025` (`91bd2019` as of 11 Nov): preregs for XGB_CLASS_JUR_CAL (merges clean), OTHERS_SCALE_JUR
    (identical to the refused pooled arm at every AEF-7 target on cached history), SALIENCE_STATE (needs two as-at
    retrains; blanks for fed/WA/vic2026 rows are a jurisdiction marker risk). (Departed-rate refit: built and NOT shown
    5 Nov, DECISIONS. Federal breakdowns in the trend: tied, left off 5 Nov, DECISIONS.)
- OPEN, 26 Oct decisions not yet built: hunt the real primaries for two-candidate-only seat polls (Fowler 2022
  Laidlaw, Pittwater 2023 Freshwater, Cowper and New England 2016) into `hand_keyed_primaries.csv`; if none found,
  try inferring the primary from the two-candidate split (J4 30 Sep is the refused relative). Prereg a shrunk,
  time-forward "seat polls under-call new independents" term (5 of 10 polled new independents under-called by
  9-22 points: Mayo, Warringah, Kooyong, Mackellar, Mount Gambier). Seat polls already reach new independents:
  mean miss 23.4 before the blend, 11.6 published, 10 seats (Wakehurst published 30.0, not 13.7).
- OPEN, NIGHT MODEL (before 28 Nov). `pair_cal` v2 PASSED (pooled -0.00175, SE 0.00147; vic2022 +0.0028) and is the
  live night default, 11 Nov (prereg RESULT in `plans/prereg-night-pair-cal-2026-11-11.md`). Monash still ends wrong
  (Liberal ~0.005): the next lever is the model's own pair prior, not trust in the AEC. Found on the way: the federal replay dropped every pair the AEC later
  blanked (Monash among 15/21 seats), fixed 59dff525; earlier federal night numbers (the called-rule test) ran on the old filter.
  Mirani qld2024 traced 11 Nov: (1) FIXED, classify_party() filed bare codes (LNP/ALP/LIB/KAP in the qld/sa/vic2006-10
  booth 2CP files) as OTH, so the counted pair was never matched (qld2024 half-count log loss 0.2296 -> 0.1668).
  (2) `cand_ref` (by-candidate booth reference, Pete's choice) FAILED its prereg 11 Nov and stays OFF (7f921437):
  Monash 2025 got worse (moving Broadbent's Liberal votes left the new Liberal with no reference). Mirani still wrong at
  full count. The COPY version (Pete's choice) PASSED 11 Nov (sim -0.033, real -0.0017, both ~1 SE;
  Mirani and Monash carry it), kept OFF as an option: weak evidence (design chosen after the move run). Live use needs
  candidate names in the night booth table. Pete chose 11 Nov: ON for 28 Nov if switchers exist; they do (7 of 112
  returning same-seat candidates changed class: Caulfield, Frankston, Lara, Laverton, Morwell, Mulgrave, Werribee).
  To do: the live night cycle on the VEC website reader (`scripts/vec_web_booths.R` carries names) with
  `cand_ref = "copy"` passed through `night_cycle()` cfg. Replays now write
  every step and take `--resume=1` (9300e7df); since 12 Nov a resume with different flags or AUSPOL_* settings stops (NRC3,
  `<prefix>.settings.txt` beside the partial files).
  History: `backlog/journal-2026-11-11-queue-history.md`.
  Also open: statewide draws shrink by the national mean counted, not the seat's; projection sd floors at 0.26;
  `--tcp-own-fp` built, OFF (needs flow uncertainty in the draws; `plans/prereg-flow-sd-2026-10-31.md` REFUSED).
- OPEN, FLOW MEANS in non-classic contests (31 Oct, Melbourne/Monash fed2025): Liberal -> Labor-over-Greens is 60.4 in
  EVERY seat checked (Melbourne, Monash, Wills, Cooper); in 2025 the Liberal how-to-vote put the Greens last and Labor
  won Melbourne on it. Melbourne also: afternoon GRN 47.5 vs actual 39.5 (ALP 21.7 vs 31.3). Idea: seat-level
  how-to-vote cards as a flow input: DONE (`AUSPOL_HTV_FLOW`; `AUSPOL_HTV_CARD_P=0.67` mixes both Liberal cards for
  vic2026; `AUSPOL_HTV_RECENCY_HL` SHIPPED 1 Nov). The card-day row is under "Dated, cannot move".
  Box Hill (our ALP 0.86 vs Sportsbet 0.25) traced to the proportional One Nation fill: `reviews/boxhill-trace-2026-11-01.md`,
  walked with Pete 10 Nov: no change to the One Nation spread (DECISIONS 2026-11-10); the fill itself stays open here.
  Evidence: `reviews/night-replay-real-feed-2026-10-31.md`, `reviews/night-replay-fed-2026-10-30.md`.
- OPEN, REPLAY METHOD: federal and vic2022 replay on real nights (`scripts/night_replay_feed.R`,
  `scripts/night_replay_vec.R`); the other state replays are still simulated (one block per seat, clock = 6pm + 4h x
  step). Calls at 0.99 need 20,000 sims. Tally Room "returned" times are post-recheck, not night times.
- OPEN, small, backtest-only: does the flow estimator's known Greens -> Labor bias (3-7 points above the AEC federally)
  shift the QLD/SA/NSW/Vic/WA state blends in `output/flows-state-blend.csv`? Evidence: `reviews/needs-pete-evidence-2026-11-08.md`.
- OPEN: Vic 2026 Edge Board (https://claude.ai/artifact/8U33eGJMiAbpZFSW2dsfQu) builder now in the repo:
  `scripts/build_edge_board_vic2026.R [capture.csv] [out_dir]` (EDGE_RUN=<suffix> picks our run) writes both board datasets;
  checked 1 Nov against the published files (same selections, prices, bookie probabilities, columns; seat panel identical).
  The board's 12:07am `-boardmain` run files are gone from output/, so a refresh needs a fresh suffixed fit_seats_full.R run
  and a new Sportsbet capture first. Seat panel, filters and links shipped 1 Nov 12:25pm.
- OPEN from the 1 Nov sa2026 absent votes: the 8 Cheltenham rows reach `output/candidacies.csv` with the vic2006 rebuild
  (Data and infra); Newland +1,047 and Black +26 untraced; add build_retiring_mp_cases.R to rebuild stage 0 (low value,
  its reader is off).
- OPEN from the 30 Oct walks (https://claude.ai/artifact/USv8sffhF1zbYagBGwjdQ3, `reviews/walks-wa2017-fed2019-2026-10-30.md`;
  4 Nov trace in `reviews/needs-pete-evidence-2026-11-08.md`): wa2017 misses are seat-specific (Southern River, Geraldton,
  Bunbury, Wanneroo, Kimberley): what do those five share? fed2019: is the correlated statewide draw wide enough (needs
  each harness to write statewide draw quantiles, then coverage of the 35 actual levels)? Idea: a per-person trend for Cupper.

- OPEN, Pete: returning independents. Both arms REFUSED 25 Oct (`plans/prereg-ind-return-2026-10-25.md`); the
  x0.61 multiplicative minor-field scale (a live-only train/serve split) was fixed by `AUSPOL_MINOR_ADDITIVE=1`,
  SHIPPED 25 Oct live only (DECISIONS). Still open: Mildura 25.6 vs Cupper's 33.9 (One Nation's fill takes the
  rest); live `FST1!` (no candidate-model split for vic2026); Kew and Hawthorn, where the bookies price independents
  far above us; Benambra (a NEW independent succeeding Hawkins).

- OPEN (bucket split, SHIPPED 6 Nov; DECISIONS): `minor-class-shares-resid-v2.csv` is built in `rebuild_forecasts.sh` (cached when
  current). vic2026 rows SHIPPED 10 Nov (DECISIONS; `MC_LIVE_EL` in the rebuild). Still open: v3 as its own screen. `backlog/overnight-2026-11-04.md` item 3.

## 2026-10-18 pipeline audit (READ FIRST; `reviews/pipeline-overwrite-audit-2026-10-18.md`, Sonnet, read-only)

20 findings where work is overwritten, doubled or ignored, or live and backtest diverge. Closed items: journal
(`backlog/journal-2026-10-16-to-2026-10-22.md`). Open ones below.
- OPEN, from the 22 Oct old-election fill diagnosis (the `AUSPOL_TRAIN_DECAY_H=4` test of it REFUSED 25 Oct,
  half-life stays 8; DECISIONS, `plans/prereg-train-decay-4-2026-10-22.md`): Greens over-called in high-Greens seats by the trees (Melbourne, Griffith, Northcote);
  retiring Labor members about -2.0 (n 34); Dickson's published stage moved a correct tree LNP figure +5.5.
- OPEN, REWRITE BEFORE RUNNING: width arms A0/A1 (`plans/prereg-harness-sw-draws-2026-10-19.md`) were written for
  `AUSPOL_HARNESS_SW_DRAWS=1`; what ships is `=net` (F4), so they test a superseded setting. The question they carry
  stands: is the statewide spread `AUSPOL_FP_EXTRA_SD` 2.419 (fitted on the scored elections, a mild leak) too wide
  for states? Rewrite as `net` arms with a time-forward value before any screen.
- OPEN, DATED (final snapshot 25-27 Nov is the one that ships, per Pete 27 Oct; earlier weekly ones from ~3 Nov are
  for watching only, not the forecast): vic2026 salience snapshots. 11 Nov snapshot (to 11 Nov): 734 candidates, 733
  fetched, 526 linked to the Carroll scale (148 batches) -- linking works now the campaign has started. 26 Oct snapshot fetched, 0 of 101 batches linkable. All 500 candidates fetched
  18 Oct (window to 6 Oct), but that is before the campaign: nobody's search interest is rising yet (Premier 1.1 in the
  last 8 weeks vs 9.3 before), so batches cannot be linked and `jump` is not comparable with the backtests' polling-day
  values. Each refresh: `AUSPOL_SALIENCE_TO=<date> Rscript scripts/fetch_salience_vic2026_full.R` (~100 requests,
  resumable; anchor Ben Carroll since 4 Nov: Allan was replaced as Premier 28 Jul 2026 and her series linked 0 of 101
  batches; check the anchor against `leaders.csv` before each snapshot), then `scripts/build_vic2026_salience_jump.R`
  with the SAME `AUSPOL_SALIENCE_TO` (without it the builder falls back to 6 Oct and finds 0 batches)
  (output/vic2026-salience-jump.csv). Local runs DO use a vic2026 salience corpus (live walk log: XG5 43 cells,
  31 surge seats); the CI publish does not have one yet (DS3 falls back to flat surge_h), so the surge double count
  (`AUSPOL_SURGE_LEVEL`) reaches the published forecast only once a corpus reaches CI.
- OPEN F8, F13, F17, F19 (F5, F7, F9 REFUSED; F10 and F12 SHIPPED, DECISIONS 30 Oct / `AUSPOL_LIVE_LEVEL_PRED_TREND`;
  F14, F15 were design notes, no task; F16 NOT PASSED 29 Oct; F18 walk 1 done; IND override shipped as arm H): post-xgb
  tables fitted on residuals the shares no longer carry (F8; arms R and N exhausted), HTV overwriting xgb flows (F13: no
  longer inert, `AUSPOL_HTV_CARD_P` is live for vic2026, so measure it), and the rest of the audit's list
  (`reviews/pipeline-overwrite-audit-2026-10-18.md`). (F20 and its `AUSPOL_MINOR_DEFECT` gap: DONE 23 Oct, journal.)

## Open from 17 Oct

- OPEN, bigger than composition spread C (parked, `reviews/composition-spread-2026-10-17.md`) or error distribution E
  (`AUSPOL_ERROR_DIST`, refused then SHIPPED 17 Oct on Pete's override; see "NSW variance" under Model, open), and the place to try width + tails together: errors are HEAVY-TAILED everywhere (0.57% of non-IND-seat cells miss by 4+ sim
  sds, ~100x a bell curve; kurtosis 20). A fat-tailed per-cell error (fitted time-forward) is the general fix for
  floor seats. NB the seat-poll form of it (arm T, mixture on model error) was REFUSED 19 Oct (-0.0004, SE 0.0052).
- OPEN FFD1 is fitted on the gap FF1 checks (passes by construction; Pete's call, 15 Oct). Validate it when a
  second federal cycle has firms that both name and fold One Nation.

## Still open from 14-15 Oct (collapsed 15 Oct evening; history in DECISIONS and `plans/overnight-2026-10-14.md`)

**Open work, in order:**
- OPEN sa2018 +0.025 from the new inputs: LNP -0.3 pts broadly where IND/GRN rose; which input not isolated (screen
  sa2018 with salience off). nsw2019's +0.026 is Barwon alone (SEAT-REGISTRY). Lead (15 Oct): under the leaking
  surge flag, sa2018 IND (SA-Best, +13.9 actual) was "surging" from its own result; read the surge arms first.
- OPEN wa2017 / wa2013 regressions: Hillarys and Churchlands traced in SEAT-REGISTRY; Lib/Nat two-candidate part SHIPPED
  17 Oct. The WA 2017 swing-seat lift is now traced in NEEDS PETE ("OPEN from the 30 Oct walks", 4 Nov).
- OPEN NT seat layer: over-confidence fixed by the size spread (20k: nt2016 0.80, nt2020 0.65, nt2024 1.07, from
  0.99/0.81/1.41); still weak, and new parties start at zero share.
- OPEN qld2017: One Nation / Katter seats given ~0 (emergence); qld2012 Katter polled inside Others.
- OPEN (lead, NOT a result) sitting non-major members (Sonnet, 16 Oct; scratchpad `minor-mp/`): published-path
  signed error +0.36 pts, SE 1.11, n 84 sitting minor/IND members in 29 elections: no overall over-call. Hints only:
  falling own vote -3.8 (SE 3.9, n 9); trend slope +0.26 (SE 0.17); **leader-seat bonus on a sitting minor member
  -7.8 (SE 4.1, n 4: Buderim qld2017, Traeger, Melbourne 2022/2025)**. One feature only, so a to-do, not a refusal.
  If pursued: shrunk "falling own vote" term; re-check the leader bonus for minor-role leaders (n 7, se 3.4).
- OPEN Hare-Clark candidate-level count loses on zero-probability new independents (needs a heavier tail).
- OPEN fed2007 Newspoll gaps (Jul 2005-Apr 2006, Jul-Sep 2006, Jul-Nov 2007) and Nielsen/Galaxy archives.
- OPEN fed2028 live forecast build (decided 13 Oct; 8-11 days).

## 2026-10-11 to 2026-10-12: still open (collapsed 15 Oct)

Run-order and memory notes moved to `docs/PIPELINE.md` section F (11 Nov). Refused, built and off (do not rerun without a new idea):
leader ratings as a model input, trend-replaces-blend, poll-level centring, the two-way person rule, statewide poll
weighting by track record, seat-poll precision blend, typical-vote independent models.

- OPEN leader ratings: drift from months out needs horizon scoring. (The blog chart is DONE: inthegame-blog PRs #890
  and #895, "The leaders" in `politics/_forecast-body.qmd`.)
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
- OPEN speed (`reviews/fast-iter-profile-2026-10-11.md`): read-set cache keys for defectors, personal prior vote,
  departed slope, salience (~25 s of a 54 s vic run); seat-poll memo keys on every switch.

## 2026-10-07 to 2026-10-08: archived handoffs

Verbatim in `backlog/journal-2026-10-07-to-10-08.md`. Still OPEN from them:
- OPEN: NSW 2027 page, blog side: seat pages need an election switch in inthegame-blog's `politics/seat.qmd` (still
  Victoria-only 23 Oct; `politics/nsw.qmd:46` has `seatPage: false`; data on R2 since PR #107). Owned by the `inthegame-blog` session.
- OPEN: fed2025 seat polls deserved weight ~0.13 and got 0.55; no pre-election signal found yet. Worst case McMahon,
  Camenzuli (IND) published 29.0, actual 9.8: ONE poll, Compass Polling 8 Apr 2025 (opt-in SMS link, n=1,003, IND 41);
  base_pred 6.0 and xgb 4.9 were both under, so the 29 is the seat-poll step (AUSPOL_SEAT_POLL_IND_MAP). Polls are
  classified by method (`reviews/seat-poll-methods-2026-10-18.md`); the weight prereg is PARKED 5 Nov with "Seat polls:
  PARKED" under Model, open. Dirty raw pollster labels do not reach the model (checked 23 Oct). McMahon itself is called
  right since 8 Nov (Others-lump split, arm H, DECISIONS 2026-11-08); the weight question stands.

## 2026-09-27 to 2026-10-05: archived sessions

Verbatim in `backlog/journal-2026-09-27-to-10-05.md` (handover detail in `HANDOVER-2026-10-05.md`). Live from them
is folded into the sections below (Model open, Hygiene, Data and infra); nothing live is left only in the journal.

## Dated, cannot move

- Nominations DONE 10 Nov (VEC final list live, DECISIONS 2026-11-10). OPEN leftovers, NOT CHECKED 10 Nov: rerun the
  three salience scripts named in `published_flags.R` on the real list; revisit candidate-count weighting now counts are facts.
- **The day Liberal how-to-vote cards are published**: add
  `vic2026,ALL,<TRUE/FALSE>,<source>` to
  `external/reference/htv/liberal-alp-grn-order.csv` (~8 points of 2CP in
  inner-Melbourne ALP-v-GRN seats). Until then `AUSPOL_HTV_CARD_P=0.67` mixes both cards (31 Oct; see FLOW MEANS above).
- **28 Nov, once vic2026 has votes in `candidacies.csv`**: set `MC_LIVE_EL=""` in `rebuild_forecasts.sh` (the live
  bucket split row, SHIPPED 10 Nov; the fit stops with `MC0!` otherwise).
- SHIPPED 6 Nov evening (Pete, correctness on a tie; `AUSPOL_HTV_TABLE="researched"`; in the 7 Nov rebuild). Still OPEN: fill the 15 UNKNOWNs; an OPEN-card third state. Was: researched Coalition card order, `external/reference/htv/coalition-card-order-researched.csv`
  (36 elections, 48 rows, pre-election sources, raw pages under `htv/raw/`, local only; 15 UNKNOWN). Disagrees with the
  9-row `liberal-alp-grn-order.csv` on nsw2019 and nsw2023: Liberal cards were OPEN ("just vote 1"), not Greens-last, so
  under optional preferencing Liberal votes mostly exhaust. Next: an arm reading the researched file (OPEN needs a third
  state in `R/htv_flow.R`, not the TRUE/FALSE flag); fill the UNKNOWNs from the commissions' registered cards (sa2014 has an
  archive.org capture of ECSA's card page). Vic 2026: re-check when cards are lodged with the VEC.
- OPEN (idea, 6 Nov, from Griffith/Ryan 2022): a state -> federal carry of a party's own strength in the overlapping state
  booths (the Greens held Maiwar and South Brisbane before winning Griffith and Ryan; polls and model both missed by 6-8
  points). Booth transposition exists (`seat_swing_port_3c.R`, `PollingPlaceID`); size it on the corpus before building.
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

## Harness and pipeline hygiene
- OPEN (speed, CORRECTED 6 Nov 12:40pm) stage 4 (`fit_xgb_primary_asat.R`) 1,664 s for 31 models on a full retrain. The "287 s before"
  I compared it with was `driver.log` of 19 SEP (22 elections, ensemble 1); not the kernel leak. Cost per model grows with the corpus:
  `xgb.cv` uses ONE FOLD PER EARLIER ELECTION (sa2026: 34 folds, 401 rounds, 142 s; sa2010: 4 folds, 1 s), times `AUSPOL_XGB_ENSEMBLE=3`
  training. Its skip-if-current cache only helps when base_pred is unchanged, which a model change never is. Options, each a model
  change needing a screen: cap CV at ~5 grouped folds (est. ~5x faster on late targets; changes nrounds), or fit targets in parallel
  processes (memory). Stage 3 (533 s) not yet broken down the same way; time it from its own log before guessing again.
- Both branches below RECREATED 25 Oct on Pete's yes; by 10 Nov both refs were gone again (commits unreferenced), so
  RECREATED again 10 Nov at b21fb774 / ae91f62f (local only, not pushed).
- Branch `fed-timing-resume-fixed` (b21fb77, unmerged, NOT through the review gate or `check_like_ci`): fixes
  the federal `PARTY_COR` loop leak (a full fed run simulates every pair with the LAST pair's matrix; dormant
  at published defaults because `AUSPOL_FORECAST_MODE=1` skips the matrix; live for fed with FORECAST_MODE=0),
  adds per-pair timing and an opt-in resume cache (`AUSPOL_FED_RESUME=1`). Ran live: outputs byte-identical.
  Untested: more than one pair, a kill mid-run. `FLOW_SD` has the same loop leak, unfixed (dormant,
  `AUSPOL_FLOW_SD_BY_SOURCE` default 0). Also `instrument-backtest-fed-timing` (ae91f62), paused.
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
  the backtest trees are frozen as-at models trained before the fix). LANDED in the 10 Nov 7:34am rebuild (sitting IND
  members in `mp-slope-by-class.csv` 84 -> 87). OPEN: re-measure vic2010 after the next full rebuild retrains the trees.

Still open:
- Federal results as a correlated signal for state seat lean: needs
  seat-boundary matching (`external/reference/boundaries/` has CED 2016).
- OPEN: ITG page: a seat map (regions are in the JSON now), per-seat cards, a forecast-over-time chart.

## Awaiting Pete

Two walks, no decisions (departed-rate answered 29 Oct, census 27 Oct, Box Hill / Ashwood / Glen Waverley 10 Nov;
DECISIONS): Morwell (F18 walk 1, prediction 3), wa2017 and fed2019 (item (0)).
