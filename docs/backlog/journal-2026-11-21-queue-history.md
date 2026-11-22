# Queue item text moved verbatim from NEXT-STEPS.md (21 Nov 2026, hub slimming)

Each item below is the full text as it stood on 21 Nov 2026 before it was cut to its open state in the queue.
The live parts stay in `docs/NEXT-STEPS.md`; this file is history.

## SHIPPED 15 Nov (PR #241

- SHIPPED 15 Nov (PR #241, merged 10:23am; publishes with the 16 Nov 4:30am daily run): vic2026 Liberal card known, Labor
  above the Greens (VEC registered cards); Brunswick open, keeps learned flows. Live in the 16 Nov 4:30am run
  (43741480657: `HTV1 ... labor_above=87 open=1`, `HTV14`). Also SHIPPED 15 Nov (PR #242): `AUSPOL_HTV_LABELS=hybrid` (card shares learn from the cards; open share). OPEN: the 13 UNKNOWN
  card rows (counted 15 Nov: fed2007/2010/2019, nsw2015, qld2012, sa2010/2014/2022, wa2001/2005/2008/2017/2025) still train
  on their results; each dated card found moves one to its card. Source: `external/reference/htv/coalition-card-order-researched.csv`.
  Every row was open-web searched 6 Nov; the remaining route is Wayback captures of the commissions' card pages and PDFs, dated
  before polling day. 15 Nov: the Internet Archive went offline mid-search. Its index does hold Feb 2014 ECSA document
  downloads in the form `edocman/?task=document.download&id=N`, so retry sa2014 ids 687 and 710-756 in that form, then ECSA
  2022 and WAEC 2017/2025. PARKED 15 Nov until after 28 Nov (the archive kept dropping; the whole card-label change was
  -0.0001 SE 0.0002, so these rows cannot move vic2026). Done when: 0 UNKNOWN rows, or each says where it was searched.

## IN FLIGHT 9 Nov (Pete chose the levers)

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

## OPEN, NIGHT MODEL (before 28 Nov)

- OPEN, NIGHT MODEL (before 28 Nov). Live defaults: `pair_cal` v2 (11 Nov) and the night class split (14 Nov, PR #239;
  restated PASS after the Forde replay fix, PR #240). OPEN: see the class split run in the 25 Nov dress rehearsal
  (NW23/NW24 lines; Daily Eight 25 Nov). Preregs: `plans/prereg-night-pair-cal-2026-11-11.md`,
  `plans/prereg-night-class-split-2026-11-14.md`; history in `backlog/journal-2026-11-11-queue-history.md`.
  Mirani qld2024 traced 11 Nov: (1) FIXED, classify_party() filed bare codes (LNP/ALP/LIB/KAP in the qld/sa/vic2006-10
  booth 2CP files) as OTH, so the counted pair was never matched (qld2024 half-count log loss 0.2296 -> 0.1668).
  (2) `cand_ref` (by-candidate booth reference, Pete's choice) FAILED its prereg 11 Nov and stays OFF (7f921437):
  Monash 2025 got worse (moving Broadbent's Liberal votes left the new Liberal with no reference). Mirani still wrong at
  full count. The COPY version (Pete's choice) PASSED 11 Nov (sim -0.033, real -0.0017, both ~1 SE;
  Mirani and Monash carry it), kept OFF as an option: weak evidence (design chosen after the move run). Live use needs
  candidate names in the night booth table. Pete chose 11 Nov: ON for 28 Nov if switchers exist; they do (7 of 112
  returning same-seat candidates changed class: Caulfield, Frankston, Lara, Laverton, Morwell, Mulgrave, Werribee).
  DONE 11 Nov: the website source defaults `cand_ref` to "copy" (`R/night_runner.R:697`). Replays now write
  every step and take `--resume=1` (9300e7df); since 12 Nov a resume with different flags or AUSPOL_* settings stops (NRC3,
  `<prefix>.settings.txt` beside the partial files).
  History: `backlog/journal-2026-11-11-queue-history.md`.
  Also open: statewide draws shrink by the national mean counted, not the seat's; projection sd floors at 0.26;
  `--tcp-own-fp` built, OFF (needs flow uncertainty in the draws; `plans/prereg-flow-sd-2026-10-31.md` REFUSED).

## OPEN, FLOW MEANS in non-classic contests

- OPEN, FLOW MEANS in non-classic contests (31 Oct, Melbourne/Monash fed2025): Liberal -> Labor-over-Greens is 60.4 in
  EVERY seat checked (Melbourne, Monash, Wills, Cooper); in 2025 the Liberal how-to-vote put the Greens last and Labor
  won Melbourne on it. 17 Nov: SIZED. Melbourne got 79.3% (AEC), and that miss is the night's one wrong call
  (`reviews/night-called-rule-real-nights-2026-11-17.md`). The "labor_above" share (vic2026 live 61.7%, `HTV14`) pools
  17 elections led by sa2026 59.7, fed2019 59.0, wa2025 57.4; Victoria's own labor_above cells are 66.8 (2010), 67.8
  (2014), 57.1 (2018, 2 seats); federal pooled 69-70% 2016-22, 79% 2025. Pete chose "Prereg + screen it": `AUSPOL_HTV_JUR_SHRINK=1`
  (off; prereg `plans/prereg-htv-jur-shrink-2026-11-17.md`, committed 736e9e90 before any score; vic2026 61.7 -> 64.0).
  REFUSED 17 Nov 11:30pm (35 elections: +0.0002, SE 0.0002; vic2014 +0.0044, vic2022 +0.0023; DECISIONS). Still
  open, after 28 Nov: Melbourne fed2025 is a SEAT-level effect (Liberal voters follow the card harder where the
  Greens are the threat); trace which vic2014 seats the per-state arm hurt before designing that one. Melbourne also: afternoon GRN 47.5 vs actual 39.5 (ALP 21.7 vs 31.3). Idea: seat-level
  how-to-vote cards as a flow input: DONE (`AUSPOL_HTV_FLOW`; `AUSPOL_HTV_CARD_P=0.67` mixes both Liberal cards for
  vic2026; `AUSPOL_HTV_RECENCY_HL` SHIPPED 1 Nov). The card-day row is under "Dated, cannot move".
  Box Hill (our ALP 0.86 vs Sportsbet 0.25) traced to the proportional One Nation fill: `reviews/boxhill-trace-2026-11-01.md`,
  walked with Pete 10 Nov: no change to the One Nation spread (DECISIONS 2026-11-10); the fill itself stays open here.
  Evidence: `reviews/night-replay-real-feed-2026-10-31.md`, `reviews/night-replay-fed-2026-10-30.md`.

## OPEN, DATED (final snapshot 25-27 Nov

- OPEN, DATED (final snapshot 25-27 Nov is the one that ships, per Pete 27 Oct; earlier weekly ones from ~3 Nov are
  for watching only, not the forecast): vic2026 salience snapshots. 11 Nov snapshot (to 11 Nov): 734 candidates, 733
  fetched, 526 linked to the Carroll scale (148 batches) -- linking works now the campaign has started. 26 Oct snapshot fetched, 0 of 101 batches linkable. All 500 candidates fetched
  18 Oct (window to 6 Oct), but that is before the campaign: nobody's search interest is rising yet (Premier 1.1 in the
  last 8 weeks vs 9.3 before), so batches cannot be linked and `jump` is not comparable with the backtests' polling-day
  values. Each refresh is ONE command since 13 Nov: `bash scripts/salience_vic2026_snapshot.sh <window end>` (all four steps
  on one date, anchor checked against leaders.csv; tested 13 Nov on the cached 11 Nov window: byte-identical corpus), then stage 9.
  The steps it runs: `AUSPOL_SALIENCE_TO=<date> Rscript scripts/fetch_salience_vic2026_full.R` (~100 requests,
  resumable; anchor Ben Carroll since 4 Nov: Allan was replaced as Premier 28 Jul 2026 and her series linked 0 of 101
  batches; check the anchor against `leaders.csv` before each snapshot), then the LADDER (ships 13 Nov, DECISIONS):
  `AUSPOL_SALIENCE_TO=<date> Rscript scripts/fetch_salience_vic2026_ladder.R` (~100 requests, ~12 min, 2 passes; read
  VJ6 link quality afterwards: 11 Nov gave shared peak median 56, 0 steps over 1.5x; batch factors on the last 8 weeks:
  no representative between 0 and 0.5 in the ladder, 24 of 148 under 0.5 in their own batch, all near-zero rises), then `scripts/build_vic2026_salience_jump.R`
  with the SAME `AUSPOL_SALIENCE_TO` (without it the builder falls back to 6 Oct and finds 0 batches)
  (output/vic2026-salience-jump.csv), then `scripts/link_vic2026_salience.R`. Connected to the live forecast 13 Nov
  (0646dbc8); the 15 Nov local run prints `XG5 salience corpus found for vic2026: 546 of 616 seat-classes matched`.

## Night source, dry run detail (moved from the queue 21 Nov, midnight)

  DRY RUN 21 Nov 11am (`deciding-runs/20261121-night-rehearsal/`: raw pages, logs, JSON), 2022 pages under today's 2026 state:
  fetch 87 districts / 174 pages, then one cycle OK in 68 s (87 of 88 seats updated, parse 17 s, simulate 40 s); `NW23` and
  `NW24` both printed, so the class split runs on the website source. THE WEBSITE COMMAND (the runbook below is the feed's and
  stops on `NW9!` without `--turnout`):
  `Rscript scripts/fetch_vec_web_snapshot.R --index=<results page> --out=<dir>/web --every=<s>` beside
  `Rscript scripts/night_loop.R --every=60 --source-type=web --source=<dir>/web --archive=<dir>/archive --state=<night-state-vic-2026.rds> --ref=output/booths-vic2026-ref.csv --council-lean=output/council-fp-2022.csv --turnout=output/council-district-stats-2022.csv --enrolment=external/reference/vec/2026/enrolment/enrolment-2026.csv --places=external/reference/vec/2026/voting-locations/places-2026.csv --out=<json> --upload-key=auspol/night/vic2026.json`
  (the rehearsal added `--allow-unmatched=1` only because 2022 has no Narracan page; never on the night).
  ONE COMMAND since 21 Nov: `bash scripts/night_vic2026.sh <results index URL> <work dir> [--upload] [--every=90]` runs both
  with those flags (downloads the state into the work dir; upload is OFF unless `--upload`; a fetcher that dies stops the
  loop at once with `NV8!`). Rehearsal: add `--dry-2022 --max-cycles=1` (tested 21 Nov: one cycle, rc 0; a wrong index
  gives `NV8!` in 4 s). The 25 Nov rehearsal should use it, without `--upload`. Found: (a) the index
  must be the page that links every district's result page (2022: `.../2022-state-election-results`, 87 links; its
  `/results-by-district` child links none); (b) FIXED, the fetcher followed the page's read-aloud link (`//other-host/...`) as
  a VEC path, HTTP 500; (c) FIXED (Pete chose "4 at a time"): one snapshot took 297 s one page at a time; `--parallel=4`
  (now the default) takes 85 s for discovery + 174 pages (about a minute a snapshot once discovery is done), pages
  identical, cycle result identical; a 404, a dead host and a page holding a NUL byte each cost that one page. Exactly 4:
  groups of four on plain connections (the first build ran up to 40 streams and took 8 s; review, 21 Nov).

## By-election de-swing rebuild pair, the two failed nights (moved from the queue 22 Nov, once the pair was scored)

- SHIPPED 19 Nov (PR #260, Pete's override): by-election de-swing `AUSPOL_BYELECTION_DESWING=1`. Live 20 Nov 4:42am forecast
  (1404a0f): Werribee ALP 42% / ONP 30% / LIB 28%; `BYS1` also moved nsw2027 Kiama (ALP -1.0, LNP +5.4), not measured. OPEN: the
  prereg rebuild pair HAS NOT RUN (two failed nights). 20 Nov: the task fired at 5:56pm after the machine slept. 21 Nov 1:02am:
  both arms died in 15 s at stage 0 (`BK2!`, no BludgerTrack XML): the chain's fill went one level into `external/`, so the
  worktrees lacked 15,012 gitignored files (polls 4,090, vec 4,321, nsw 5,888, byelections 590, htv 93, wikipedia 30).
  FIXED 21 Nov 9:30am in `deciding-runs/20261122-bys-rebuilds/chain.ps1`: the fill recurses, and a preflight opens every
  main `external/` file at its worktree path and refuses the arm on any gap. Smoke-tested (`-SmokeOnly`: 38,647 files, 0
  missing, the stage-0 poll builder rc 0, worktree removed clean, `SMOKE-OK`). Both old worktrees removed (junctions first).
  Task `auspol-bys-rebuilds` registered for 22 Nov 1am (wakes the machine, waits for 4 GB, refuses after 4am).
  OPEN, DATED 22 Nov morning: read the marker in that folder; on `DONE`, from this checkout:
  `Rscript scripts/score_byelection_deswing.R C:/dev/auspol-wt-rb0/output C:/dev/auspol-wt-rb1/output`, then
  `scripts/compare_rebuild_scores.R` on the two `pooled-backtest.csv` files; report to Pete against the prereg criteria. Before removing either
  worktree, unlink every path in `junctions-<arm>.txt` first (memory `worktree-junctions-delete-through`).
  Known: a worktree rebuild writes stage-0 files such as `bludgertrack_polls.csv` through the junctions into this checkout's `external/`.

## De-swing result, the by-election person finding, and the 0.30 spread note (moved from the queue 22 Nov, 12:20pm)

The third item below was already out of date when moved: the 0.30 spread change was made and reverted on 22 Nov, and the One Nation direct model replaced it (see `plans/prereg-onp-direct-model-2026-11-22.md`).

- SHIPPED 19 Nov (PR #260, Pete's override): by-election de-swing `AUSPOL_BYELECTION_DESWING=1`. Live 20 Nov 4:42am forecast
  (1404a0f): Werribee ALP 42% / ONP 30% / LIB 28%; `BYS1` also moved nsw2027 Kiama (ALP -1.0, LNP +5.4), not measured.
  DONE 22 Nov: the prereg rebuild pair ran 1:00am to 4:26am (both rc 0) and PASSES all four criteria, so the switch stays
  "1" (plan RESULT section; evidence in `deciding-runs/20261122-bys-rebuilds/`; the two failed nights are in the journal).
  Both rebuild worktrees removed 22 Nov (53 junctions each unlinked first; main `external/` 38,651 files before and after).
- OPEN (Pete to decide before or after 28 Nov): a candidate's own earlier general-election vote overwrites their by-election
  result. CAUSE PROVEN 22 Nov on Murray nsw2019: Helen Dalton ran as an independent in 2015 (18.2%), as Shooters at the Oct
  2017 by-election (31.5%) and won as Shooters in 2019 (40.3%). `own_prev_substitute()` (`R/candidate_returns.R`, called as
  `.own_x()` in every harness and `fit_seats_full.R`) replaces the class cell with `personal_prior_vote()`'s value, 18.2 x the
  non-sitting minor-switcher rate 0.230 = 4.18, whatever the half blend put there (0, 15.7 and 31.5 in all give 4.18).
  Predicted 4.0%. LIVE vic2026, same step: Werribee Paul Hopper took 14.6% as an independent at the Feb 2025 by-election
  and stands for The West Party (OTH); value used 1.63, published OTH primary 4.7%. (An earlier note here said 13.6%: that
  was the whole OTH class at the by-election, not Hopper.) Mulgrave Ian Cook 18.8 against 18.0 (small).
  BUILT 22 Nov behind `AUSPOL_BYELECTION_PERSON` ("0" in `published_flags.R`): the person gets the same half blend,
  `plans/prereg-byelection-person-2026-11-22.md`. Live walk: Werribee One Nation 30% to 57%, Labor 42% to 23%; Mulgrave
  barely moves; no other seat moves. 79 historical restanders counted. Pete chose "score it tonight" (22 Nov).
  OPEN, DATED 23 Nov morning: task `auspol-byp-rebuilds` runs the pair at 1am (commit e5f8ed58, smoke-tested, refuses
  after 4am; machine must stay on and logged in). Read the marker in `deciding-runs/20261123-byp-rebuilds/`; on `DONE`:
  `Rscript scripts/score_byelection_deswing.R C:/dev/auspol-wt-rb0/output C:/dev/auspol-wt-rb1/output`, then
  `scripts/compare_rebuild_scores.R` on the two `pooled-backtest.csv` files; report against the plan's four criteria (the
  leave-one-election-out clause is the one that matters) and ask Pete ship or not. Copy both `published-predictions.csv`
  files out, then unlink every path in `junctions-<arm>.txt` before removing a worktree.
- OPEN (Pete's call, asked 22 Nov): One Nation's seat spread is too wide at Victoria's level (`AUSPOL_ONP_CV` 0.365; a walk at 0.30
  moves One Nation 14.9 to 12.7 seats). Census columns add nothing beyond the Senate allocation. `reviews/onp-demographics-and-spread-2026-11-22.md`.
