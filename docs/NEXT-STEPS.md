# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before the 2026-09-19 rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`;
closed items of 7-19 Oct, verbatim: `backlog/journal-2026-10-07-to-2026-10-15.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30; slimmed 2026-10-19.

## NEEDS PETE

- **Status 23 Nov, 11pm.** main 0.4.202 (PR #272: MRP seat pattern). Live (10:35pm, run 45162697096): MRP seat pattern ON (July
  YouGov MRP in; Pete shipped on the 7-election screen), by-election person rule ON, One Nation MODELLED allocation ON (Pete's
  override), final_twos in the forecast file. Search interest off. Dated: 25 Nov
  both night rehearsals (check the night file's final_twos on the test key); 26 Nov venues recheck; 27 Nov inthegame-blog#1262 + benchmark capture.
  Rebuild worktrees `C:/dev/auspol-wt-rb0`, `-rb1`, `-rbm`, `-rbr`, `-rbb` (junction lists in their deciding-runs folders): unlink before removing.
- OPEN, after 28 Nov: One Nation allocation. The modelled version is LIVE on Pete's override of its refusal (23 Nov, DECISIONS);
  the rank rule with retrained trees stays off. Score both on vic2026 once results are in.
- OPEN, 15 Nov full review (`reviews/FABLE-FULL-REVIEW-2026-11-15.md`, "Pick up from here" is the work list; DECISIONS
  2026-11-15). A1-A6, B1 shipped (seen live 17 Nov); C1 traced 16 Nov (item below). PARKED, trigger after 28 Nov
  (checked 21 Nov): C2 score the 14-day forecast (days), C3 validation stages off the publish path (edits the publish
  workflow a week out), C4 (after 28 Nov by its own text), C5 local run 6.5 min vs 79 s; A7 (1)-(2) below.
- OPEN, model, found 15 Nov (same review, item A7; each needs Pete before shipping): (1) a standing class whose adjusted
  2022 share is below its statewide fall is clipped to 0 at the base (Kew Other-right still 0%; 123 of 19,616 backtest rows);
  (2) Evelyn's Michelle O'Brien carries Michael O'Brien's "elected" flag (`given_stem()` is two letters, `R/names.R:249`;
  needs a retrain). SIZED 22 Nov: the only wrong flag of 69 in vic2026 (the other 7 without a full-name match are by-election
  winners or Will/William Fowles); she is forecast 6.2% (Family First 5.3% there in 2022), 0.26% to win, Vallence 97%, so it
  cannot move the seat. In past state elections 3 of 1,824 flagged rows join two different people (Jack/Jason O'Brien
  qld2012, Matthew/Mark Robinson qld2024, Gayle/Gabrielle Williams vic2022); a full-first-name rule must keep the nickname
  pairs it would otherwise break (Joe/Joseph Kelly, Steve/Stephen McGhie). Stays after 28 Nov; (3) TRACED 16 Nov (C1, `SMN1` log line per stage in `fit_seats_full.R`;
  DECISIONS 2026-11-16): the xgb trees take the minor total 9.32 -> 12.59, and 2.7 of that is the live candidate
  count (`AUSPOL_LIVE_N_CAND=0` gives 9.88). No change: on the 35 published backtests minors are UNDER-called
  (signed -0.69 / -1.47 / -2.66 points per class at 1 / 2 / 3+ candidates; 29 of 35 pairs under on the seat
  total). Labor's +0.3 is the One Nation fill (22.39 -> 22.81). (1) and (2) at the post-election review unless
  Pete asks sooner.
- OPEN, PARKED until after 28 Nov: 13 UNKNOWN how-to-vote card rows (fed2007/2010/2019, nsw2015, qld2012,
  sa2010/2014/2022, wa2001/2005/2008/2017/2025) still train on their results; each dated card found moves one to its card.
  Source: `external/reference/htv/coalition-card-order-researched.csv`. Route: Wayback captures of the commissions' card
  pages and PDFs, dated before polling day; retry sa2014 ids 687 and 710-756 as `edocman/?task=document.download&id=N`,
  then ECSA 2022 and WAEC 2017/2025. Cannot move vic2026 (the whole card-label change was -0.0001, SE 0.0002).
  Done when: 0 UNKNOWN rows, or each says where it was searched. What shipped 15 Nov (PR #241 Brunswick open card, PR #242
  `AUSPOL_HTV_LABELS=hybrid`) and the search history: `backlog/journal-2026-11-21-queue-history.md`.
- SHIPPED 14 Nov, arm SPL (Pete's override, "Build per-side, ship live"): paid SEAT polls lose a lean toward the sponsor's
  side, each side shrunk to zero (`AUSPOL_SEAT_POLL_PAID_LEAN=1`, `plans/prereg-seat-paid-lean-2026-11-14.md`). Backtest
  neutral; live today unchanged (Hawthorn's paid poll is 15 months old). OPEN after 28 Nov: score it on vic2026.
- **FIXED on `dev`, 24 Nov 2:45am (to `main` with the next PR): the night BACKUP (GitHub runner) vs the VEC site's limit.**
  Run 45179140374 (parallel 2, every 90 s): refused (HTTP 999) on every page for 45 min, 0 snapshots. Run 45189369953
  (parallel 1, every 300 s, cooldown): 110-124 of 174 pages a snapshot, different districts each time: a per-window
  limit. Fix: the fetcher keeps a snapshot's pages and retries the missing ones after `--retry-pause` (backup 120 s x 6;
  laptop unchanged 5,15,30), cools down only on a wholesale refusal (`VWF7!`); backup defaults parallel 1, every 300.
  Run 45199291224 on `dev`: PASSED, 4 of 4 snapshots complete (174 pages, ~10.5 min apart), 4 uploads to the test key.
  It saw no refusals, so the two-minute retry is proven only on a local server that mimics the limit. Laptop path
  unaffected throughout (HTTP 200 at 12:51am). Archives: `deciding-runs/20261123-mrp-pattern/rehearsal*`.
- OPEN, DATED 23 Nov and 25 Nov, NIGHT BACKUP (on `main` 0.4.196, PR #265): if the laptop dies on the night, Actions >
  "Election-night backup", key `auspol/night/vic2026.json`, source `web`, index = the results index URL, minutes 330. Passed on the
  2022 pages (run 44984447331, 2 cycles, 4-5 min refresh). TO DO: after the 26 Nov venues recheck, if any bundled file changed,
  `bash scripts/publish_night_inputs.sh --upload` (23 Nov 8:45pm: the uploaded bundle matches all 18 local files); 25 Nov one `web-2022` run of 45-60 min, pass = no snapshot
  ends in `VWF3!`. Done when: both are run. UNTESTED: the live key, a 330-minute run. Detail: `backlog/journal-2026-11-21-queue-history.md`.
- OPEN, NIGHT SOURCE (before 28 Nov): the VEC REFUSED the feed (11 Nov); the night runs on the VEC WEBSITE
  (`R/vec_web.R`, `scripts/fetch_vec_web_snapshot.R`, `night_cycle(source_type = "web")`, `cand_ref = "copy"`). Still open:
  (1) the 2026 results index URL is only known on the night (the fetcher takes --index); (2) ASSUMED (Pete, 17 Nov;
  DECISIONS): the pages fill in during the count, as the VEC's first reply implied; draft not sent. Re-download the VEC venues spreadsheet the week of the election and rerun
  `scripts/build_vec_places_2026.R` + the geocoder (23 Nov, Daily Eight). Built/done detail moved 15 Nov to
  `backlog/journal-2026-11-11-queue-history.md`.
  VENUES, 21 Nov: the VEC reissued the spreadsheet ("correct as at 20th Nov 12:00pm"); saved raw in
  `voting-locations/raw-20261121-1140/` and rebuilt: 1,852 election-day centres (was 1,851: Warrandyte / Ringwood Heights
  added, none removed), 310 early centres (same). Gippsland East / Bundalaguah moved venue (Primary School, 627 -> Myrtlebank
  Hall, 795 Maffra-Sale Road) but keeps its 2022 booth's map position by name: move its dot by hand. Geocoder: 0 new
  requests, 359 of 359 placed (run it as plain `python`; `-I` hides the user-installed shapely). Night cycle passes on the
  new list. Rechecked 22 Nov 12:25pm and 23 Nov 10:55pm: same file link, same `Last-Modified` (20 Nov 02:02 GMT, unchanged). The
  blog's `booths-vic2026.json` was rebuilt 23 Nov 3:23pm with all 1,852 centres. Next check: 26 Nov (item below).
  DRY RUN 21 Nov passed on the 2022 pages (one cycle 68 s, 87 of 88 seats, class split on); REPEATED 22 Nov 1:44pm on `main` 0.4.195 with
  the one command: rc 0 in 3 min 5 s, 174 pages for 87 districts, JSON of 88 seats written (312 KB), nothing uploaded; REPEATED 3:37pm on `dev` 044c2c5c with `--upload-key=auspol/night/test-vic2026.json`: rc 0, uploaded (`NWU3`), test file stamped 20261122_153733. ON `main` since 0.4.193, THE
  NIGHT COMMAND: `bash scripts/night_vic2026.sh <results index URL> <work dir> [--upload] [--every=90]` (fetcher 4 pages at
  a time + loop with every website flag; upload OFF unless `--upload`; a dead fetcher stops the loop, `NV8!`). Rehearsal
  (25 Nov, no `--upload`): add `--dry-2022 --max-cycles=1`. The index must be the page linking every district's result
  page (2022: `.../2022-state-election-results`; its `/results-by-district` child links none). UNTESTED: the 2026 index
  and page layout, `--upload` to the LIVE key (the test key works from the laptop and from the runner, 22 Nov), a keyboard Ctrl+C. Long-hand commands and findings, verbatim:
  `backlog/journal-2026-11-21-queue-history.md` ("Night source, dry run detail").
- IN FLIGHT 9 Nov (Pete chose the levers): first-time-independent under-call (70 of 649 single first-timers took 15%+ and
  we gave them about a third of it; 442 took under 5%, so no blanket lift). Six levers in
  `reviews/newcomer-independents-walk-2026-11-09.md` (last section). Lever 1 REFUSED twice, stays off
  (`AUSPOL_NEW_IND_SHRINK_SIGNAL`). Lever 2 SHIPPED 9 Nov (PR #211, `AUSPOL_NEW_IND_LIFT=1`). Next levers: the spread signal
  term; council data gaps. Qld 2008 is on disk but PARTIAL (councillors for 5 councils), so coverage must become per council,
  not per state-year (`build_council_history.py:218`), before it is added; the 2014 de-amalgamation elections (Noosa,
  Douglas, Livingstone, Mareeba) need fetching. OPEN for Pete: betting odds as an input (he leans no; four elections of
  odds on disk). Seat-poll weight for new INDs PARKED (vic2026 has one seat poll). `AUSPOL_MC_EXTRA=sal` has no route to
  the forecast that helps (DECISIONS 2026-11-07). Numbers and history: `backlog/journal-2026-11-21-queue-history.md`.
- OPEN, TCP error vs AEF: goal met (ledger 3.654 vs AEF 3.727, n 667, PR #205); history moved verbatim 12 Nov to
  `backlog/journal-2026-11-11-queue-history.md`. Still open: seat flow persistence for the states (needs state TCP
  histories). PARKED, trigger "before `AUSPOL_UPSET_FLOOR` is turned on" (now "0"): the upset-floor fit drops reused
  elections under REBUILD_ONLY (fix spec in the journal). Low: `fit_nsw.R`/`fit_federal.R`/`fit_vic.R` read same-year flows.
- **Election-night live model, map https://github.com/peteowen1/auspol/issues/148.** History, DONE list and replay evidence:
  `backlog/journal-2026-11-05-election-night.md` (moved verbatim 6 Nov); plan `plans/election-night-booth-model.md`. Runbook:
  `gh release download forecast-latest -p night-state-vic-2026.rds -D <dir>`, then the fetcher and loop exactly as written
  under NIGHT SOURCE ("THE NIGHT COMMAND"; the feed-era three-flag command that stood here stops on `NW9!`). Live page https://inthegame.blog/politics/live
  (find my seat live, #166 closed 5 Nov). OPEN, in order (1-2 done 18 Nov):
  3. Navbar link: BUILT 18 Nov on inthegame-blog branch `feat/politics-live-nav-2`, PR #1239 (264d638f, Politics menu
     "Victoria 2026: election night live"); 27 Nov a session merges its PR into `dev`, then `dev`→`main`. "Called" rule 0.99 with 10% counted CONFIRMED 17 Nov on the real fed2022/fed2025/vic2022 nights
     (`reviews/night-called-rule-real-nights-2026-11-17.md`): one wrong call, Melbourne fed2025 (a Liberal-flow
     miss, not the final-pair defect: see FLOW MEANS); the gate blocks Fowler 2022 and Mildura 2022 (called at 0.3% and 0.9% counted).
  4. 25 Nov trial (no 2CP): with real 2026 centre names, compare each counted early centre with its own 2022 upper-house lean,
     re-test `--early-partial=1` (off; it made the approximated replay worse), and take the expected early total from the
     VEC's published attendance. Upper-house model designed, not built (`plans/upper-house-night-model.md`).
  Dated: the Esri key (basemaps + geocoding, pay-as-you-go off) expires 27/10/2027.
- OPEN, from the 28 Oct contested-seat research (evidence and the value-odds page, which does not refresh:
  `reviews/needs-pete-evidence-2026-11-08.md`): One Nation spread pooling is AFTER 28 Nov only (spread stays as is for
  vic2026, DECISIONS 2026-11-10; fixed to SA 2026 by the `sa_ratio` quantile map in `fit_seats_full.R`); re-entry inflated
  bases (other classes over-called -2.9, SE 0.84; Narracan Greens is the live case).


- OPEN, DATED 27 Nov: seat-page independents note (inthegame-blog #1243 + #1246) is on its dev only. Reaches prod via
  my cherry-pick branch off its `main` (ITG's rule), with the navbar #1239. Done when: the note's code is on inthegame.blog
  (it shows only at 10%+ independent; since search interest went off on 19 Nov no seat qualifies, so no page shows it yet).
  BUILT 21 Nov: DRAFT inthegame-blog PR #1262 (`feat/politics-night-prod`, into `main`): c3e41729, 28f51c5c, d38e702f and
  the navbar 264d638f cherry-picked onto its `main` (21 added lines, 2 files; built with merge-tree + commit-tree, the
  shared checkout untouched). ITG agreed 21 Nov and lists it as the 27 Nov merge in place of #1239. ITG reviewed and
  design-checked it 21 Nov at head 84d9e8d5 (0 important; PASS at 400/760/desktop); its check of the live forecast: the
  note shows on 0 of 88 seats (highest unsplit independent total Macedon 5.6%, against the 10% bar). On 27 Nov: mark it
  ready, check its render run is green, merge, close #1239 (same nav commit). Any new commit to the branch: tell ITG.
- OPEN, DATED Thu 26 Nov: VEC venues recheck (off Pete's Daily Eight, 23 Nov). Compare the spreadsheet's `Last-Modified` with
  `raw-20261121-1140/headers-xlsx.txt` (20 Nov 02:02 GMT); only if it moved: save raw, `scripts/build_vec_places_2026.R`, the geocoder,
  `bash scripts/publish_night_inputs.sh --upload`, and hand ITG a rebuilt booth file. Done when: checked and, if moved, all four done.
- OPEN, DATED (Fri 27 Nov, the capture of record): vic2026 benchmark capture. 17 Nov done: 6 sources (TAB not
  saved: Chrome blocked the download on api.beta.tab.com.au; Betfair has no Victorian markets). On 27 Nov, if the TAB
  download is blocked again, check Chrome's download prompt for that site first. Leads from X (23 Nov): a 16 Nov 4CP
  calculator post https://x.com/NotTurnbull/status/2122215843228684574 (calculator unnamed; if it is not Jago's, add it
  as reported-only, never scored); the 20 Nov Greens odds post is Sportsbet/TAB, already captured. Each date: `Rscript scripts/snapshot_benchmarks.R`, plus the GES
  Chrome step (`scripts/ges_read_calls.js`; plan Amendment 1), rerun the script, commit the calls folder, rerun
  `scripts/build_data_registry.R`. Scorer BUILT 23 Oct: `Rscript scripts/score_benchmarks_vic2026.R --results=<csv>`
  (`district, winner, status`; winner as the VEC prints the party) once every district is declared; `--dry-run` passes
  its known answer now (ours 88/88 against its own favourites). Results file BUILT 17 Nov: on the night,
  `Rscript scripts/build_vec_results_2026.R --source=<web snapshot root>` (reads each page's "Elected member" block;
  undeclared districts written `pending`; VRS3!/VRS4! proven on broken snapshots), then the scorer on its output.
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
- OPEN, NIGHT MODEL (before 28 Nov). Live defaults: `pair_cal` v2 (11 Nov), the night class split (14 Nov, PR #239, #240),
  and on the website source `cand_ref = "copy"` (`.night_cand_ref_cfg()`, `R/night_runner.R`; Pete 11 Nov: on for 28 Nov, 7 returning candidates
  changed class). Class split SEEN on the website source in the 21 Nov dry run (NW23/NW24; NIGHT SOURCE item); the 25 Nov
  rehearsal repeats it on the final state (Daily Eight 25 Nov). Replays take `--resume=1`; a resume with different flags or
  AUSPOL_* settings stops (NRC3). Also open: Mirani qld2024 still wrong at full count; statewide draws shrink by the
  national mean counted, not the seat's; projection sd floors at 0.26; `--tcp-own-fp` built, OFF (needs flow uncertainty
  in the draws; `plans/prereg-flow-sd-2026-10-31.md` REFUSED). Preregs: `plans/prereg-night-pair-cal-2026-11-11.md`,
  `plans/prereg-night-class-split-2026-11-14.md`. History (Mirani trace, the two `cand_ref` preregs):
  `backlog/journal-2026-11-21-queue-history.md`, `backlog/journal-2026-11-11-queue-history.md`.
- OPEN, FLOW MEANS in non-classic contests, after 28 Nov: Liberal -> Labor-over-Greens is one pooled share in every seat
  (vic2026 live 61.7%, `HTV14`); Melbourne fed2025 got 79.3% (AEC), and that miss is the night's one wrong call
  (`reviews/night-called-rule-real-nights-2026-11-17.md`). The per-state shrink `AUSPOL_HTV_JUR_SHRINK` was REFUSED 17 Nov
  (`plans/prereg-htv-jur-shrink-2026-11-17.md`; DECISIONS). Open: it is a SEAT-level effect (Liberal voters follow the card
  harder where the Greens are the threat); trace which vic2014 seats the per-state arm hurt before designing that one.
  Also open: the proportional One Nation fill behind Box Hill (our ALP 0.86 vs Sportsbet 0.25,
  `reviews/boxhill-trace-2026-11-01.md`; no change to the One Nation spread, DECISIONS 2026-11-10). Evidence:
  `reviews/night-replay-real-feed-2026-10-31.md`, `reviews/night-replay-fed-2026-10-30.md`; the sized numbers by state:
  `backlog/journal-2026-11-21-queue-history.md`.
- OPEN, REPLAY METHOD: federal and vic2022 replay on real nights (`scripts/night_replay_feed.R`,
  `scripts/night_replay_vec.R`); the other state replays are still simulated (one block per seat, clock = 6pm + 4h x
  step). Calls at 0.99 need 20,000 sims. Tally Room "returned" times are post-recheck, not night times.
- OPEN, small, backtest-only: the flow estimator's Greens -> Labor bias DOES shift the state blends (sized 21 Nov 1am).
  Against the answer keys (`flows-key-table.csv`), Greens estimates run high on 23 of 27 real keyed elections (fed2001 +11.1,
  nsw2023 +9.3, qld2024 +7.0, wa2025 +11.9, sa2026 +15.4 on 12 seats; vic2006-18 excluded: se 0 copies, not estimates).
  Time-forward mean bias x the blend's w gives +2.7 to +5.6 points (mean +4.2) on all 15 blended Greens rows (nsw2003/07,
  qld2004-17, sa2002-22, vic2002). Readers: the QLD and SA harnesses only; vic2026 untouched. NEXT, after the rebuild pair
  finishes (memory): screen a de-biased blend file on qld/sa pairs (memory `screen-an-input-file-change`). Trigger: after 28 Nov.
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
- CLOSED 23 Nov: vic2026 search interest stays OFF for the election (Pete, after the final snapshot's walk; DECISIONS).
  Snapshot to 21 Nov in `output/salience-v6.csv` (733 rows); walk in `deciding-runs/20261123-salience-walk/`. Score it after 28 Nov.
- OPEN F8, F13, F17, F19 (F5, F7, F9 REFUSED; F10 and F12 SHIPPED, DECISIONS 30 Oct / `AUSPOL_LIVE_LEVEL_PRED_TREND`;
  F14, F15 were design notes, no task; F16 NOT PASSED 29 Oct; F18 walk 1 done; IND override shipped as arm H): post-xgb
  tables fitted on residuals the shares no longer carry (F8; arms R and N exhausted), HTV overwriting xgb flows (F13: no
  longer inert, `AUSPOL_HTV_CARD_P` is live for vic2026, so measure it), and the rest of the audit's list
  (`reviews/pipeline-overwrite-audit-2026-10-18.md`). (F20 and its `AUSPOL_MINOR_DEFECT` gap: DONE 23 Oct, journal.)

## Open from 17 Oct

Trigger for every item in this section and the three below it (to "Dated, cannot move"): the post-election review
after 28 Nov. None blocks vic2026 (triaged 15 Nov).

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

- OPEN leader ratings: drift from months out needs horizon scoring.
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

- OPEN, DATED 24 Nov (checked in-session 10:13am): MRP seat pattern, live since 23 Nov 10:35pm. Each daily run, the `SMN1
  seat-poll blend` line should move party averages by tenths, not points; from 0.4.203 the run log also shows
  `SPM4 vic2026 ... cells kept` (renamed from SPMA, which `run_all.R` filtered out: its codes must end in a digit).
  Points would mean seat deviations blended as levels: roll back with
  `deciding-runs/20261123-mrp-pattern/shipped-before-mrp-seat-poll-blend-vic2026.csv`. `FJ9!` naming the switch is expected
  until the next rebuild. Done when: the 24 Nov scheduled run passes this. Detail: DECISIONS 2026-11-23.
- **After 28 Nov: the 35-election deciding run for the MRP pattern**, which Pete chose to ship without
  (`deciding_run.ps1 -Arm "AUSPOL_SEAT_POLL_MRP_PATTERN=1" -Base "AUSPOL_SEAT_POLL_MRP_PATTERN=0"`). The baseline must pin
  the switch off now that it ships. Record the result in `plans/prereg-mrp-seat-pattern-2026-11-23.md`.

- **28 Nov, once vic2026 has votes in `candidacies.csv`**: set `MC_LIVE_EL=""` in `rebuild_forecasts.sh` (the live
  bucket split row, SHIPPED 10 Nov; the fit stops with `MC0!` otherwise).
- OPEN (idea, 6 Nov, from Griffith/Ryan 2022): a state -> federal carry of a party's own strength in the overlapping state
  booths (the Greens held Maiwar and South Brisbane before winning Griffith and Ryan; polls and model both missed by 6-8
  points). Booth transposition exists (`seat_swing_port_3c.R`, `PollingPlaceID`); size it on the corpus before building.
  Same idea, other direction: federal results as a correlated signal for state seat lean (needs seat-boundary matching;
  `external/reference/boundaries/` has CED 2016). Trigger: after 28 Nov.
- **28 November 2026**: election night.

## Model, open (triaged 2026-09-19; nothing here blocks Victoria)

Trigger: the post-election review after 28 Nov, unless an item names its own.

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

- **NSW variance / floor seats**: per-cell fat tails already SHIP (`AUSPOL_ERROR_DIST=1`, 17 Oct). COUNTED 22 Nov (Pete's 26 Oct ask;
  13 Nov rebuild, 35 elections, 2,931 seats): 21 seats (0.72%) gave the winner under 1%, 19.8% of pooled seat log loss; 16 of 21
  winners are IND or minor-right, and 99%+ favourites lost 5 of 776, so these are emergence misses, not narrow width (my read; Pete
  told 22 Nov, no decision asked). Detail: `backlog/journal-2026-11-21-queue-history.md` ("Floor seats"). Trigger: post-election review.
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
- Branch `fed-timing-resume-fixed` (b21fb77, unmerged, NOT through the review gate or `check_like_ci`): fixes
  the federal `PARTY_COR` loop leak (a full fed run simulates every pair with the LAST pair's matrix; dormant
  at published defaults because `AUSPOL_FORECAST_MODE=1` skips the matrix; live for fed with FORECAST_MODE=0),
  adds per-pair timing and an opt-in resume cache (`AUSPOL_FED_RESUME=1`). Ran live: outputs byte-identical.
  Untested: more than one pair, a kill mid-run. `FLOW_SD` has the same loop leak, unfixed (dormant,
  `AUSPOL_FLOW_SD_BY_SOURCE` default 0). Also `instrument-backtest-fed-timing` (ae91f62), paused. Both refs are on
  origin (checked 22 Nov). Trigger: after 28 Nov.
- Diagnosed, not built: widening simulated variance for the majors' floor
  seats (`sd_override` into the WA harness); WA personal-vote transfer helps
  Pilbara and hurts WA overall (one seed).
- OPEN (after 28 Nov): 17 remote branches still hold lines not in `main` (18 fully merged ones deleted 21 Nov, Pete's
  yes). Per branch, `git merge-tree --write-tree origin/main origin/<b>` then diff against `main`: keep, land or
  delete with Pete's yes. Only `agent/issue-40-sonnet` adds nothing. Not sized: `dev-2026-10-07-unreviewed`.
- OPEN, trigger after 28 Nov: poll weighting by type, company and age, CLOSED 4 Nov, not shipping (told Pete; DECISIONS 2026-11-04).
  All six arms refused on 38 elections (`plans/prereg-poll-lean-2026-11-02.md`). Re-test sponsor lean after vic2026 (the
  first completed election with party-commissioned polls labelled); recheck seat-count conditioning on nsw2027's list. Seat-poll side
  PARKED 5 Nov (`AUSPOL_SEAT_POLL_FIRM_FLOOR` stays "0"; see "Seat polls: PARKED").
- OPEN (after 28 Nov), #192: keep every published forecast, not one per day. Today R2 has one seat-level file per day
  (`scripts/publish_forecast_history.sh`; a same-day republish replaces it). Done when: each publish adds a dated parquet
  to a `predictions-history` release and the previous one is still there. Needs a workflow edit (a session, not the worker).

## Data and infra

- OPEN (5 Nov): `output/candidacies.csv` has `elected` NA on all 459 vic2006 rows, so vic2010 gets no departed-member
  or sitting-member flags. Builder FIXED on dev (winners from `vec-2006-vic-tcp-basis.csv`, BC7v; ALP 55, LNP 32, IND 1).
  Dry run: only vic2006 `elected` (459 rows), vic2010 `historic_elected` (4 -> 79 returning) and the 8 pending sa2026
  absent-vote rows change. SCREENED 5 Nov (1,000 sims, baselines on old vs rebuilt inputs via AUSPOL_QUICK_SRC_OUTPUT,
  output/ untouched): vic2010 seat log loss 0.2281 -> 0.2335 (+0.0054, seat SE 0.0021, WORSE; Gippsland East: Ingram now
  flagged sitting, lost; Ballarat West, Brunswick not traced), sa2026 0.2368 -> 0.2364. KEPT (Pete, 5 Nov: correct data;
  the backtest trees are frozen as-at models trained before the fix). LANDED in the 10 Nov 7:34am rebuild (sitting IND
  members in `mp-slope-by-class.csv` 84 -> 87). OPEN: re-measure vic2010 after the next full rebuild retrains the trees.

Still open:
- OPEN: ITG page: a seat map (regions are in the JSON now), per-seat cards, a forecast-over-time chart.

