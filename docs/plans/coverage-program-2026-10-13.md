# Coverage program: every election since 2000, our own polls, new jurisdictions (2026-10-13)

Pete, 2026-10-13: *"whats our main projects a) full election projections for all since 2010 at last (ideally since
2000) - and conseqiently all polls since then as well which flows to b) our own poll data formation from wiki/pb etc
and comparing to AE c) scoping out new states tas/nt/act"*. Priority: 2010 on essential, 2000-2009 nice to have.
Source order for polls (Pete): Wikipedia (main article and any separate opinion-polling page) first, Poll Bludger
second, AE as a comparison.

## Where we start

Scored now (23 pairs, `all_election_pairs()`): fed 2007-2025 (7), WA 2001-2025 (7), Vic 2014/2018/2022, NSW
2019/2023, Qld 2020/2024, SA 2022/2026. Missing since 2000: fed 2001/2004; Vic 2002/2006/2010; NSW 2003/2007/2011/2015;
Qld 2001-2017 (7); SA 2002-2018 (5); Tas, NT, ACT (none). Poll sources: `docs/POLL-REGISTRY.md`.

## Wave 1: inventories (running 2026-10-13, Sonnet agents, read-only)

| track | output | done means |
|---|---|---|
| A results | `docs/reviews/coverage-results-inventory-2026-10-13.md` | every election 2000+ (fed + 5 mainland states) has a row: what results are on disk, what a harness needs, where the rest can be downloaded (checked live), effort |
| B Wikipedia polls | `deciding-runs/wiki-poll-pages-2026-10-13.csv` + `docs/reviews/wiki-poll-pages-2026-10-13.md` | every election 2000-2028, all nine jurisdictions: every article holding voting-intention tables, under any title, with table and row counts |
| C Tas/NT/ACT | `docs/reviews/scoping-tas-nt-act-2026-10-13.md` | systems, data, polls, what the model needs, effort, recommendation |
| B Poll Bludger | `external/reference/polls/pollbludger/raw/days/` (orchestrator) | every post since 2004 fetched raw, not only final 90 days |

## Wave 2 (after wave 1): build, in this order unless the inventories say otherwise

1. Polls for every 2010+ election: Wikipedia scraper over the discovered pages, Poll Bludger extraction where Wikipedia
   lacks, comparison to AE; registry rerun.
2. Results data for missing 2010+ elections (NSW 2011/2015, Qld 2012/2015/2017, SA 2010/2014/2018, Vic 2010), then the
   harness pairs (all six harnesses, CLAUDE.md "a fix to one harness is a fix to all of them").
3. 2000-2009 the same way, if the sources allow.
4. Tas/NT/ACT per track C's recommendation (NT single-member fits the current model; Tas and ACT are Hare-Clark).

## Decisions (Pete, 2026-10-13)

- Flows where no preference distribution exists: **estimate from that election's own results** (seat first
  preferences against two-candidate results), not borrowed from another election.
- Inputs missing before ~2016 (census 2006/2011, older leaders): **complete the data**, so old elections run the full
  published model.

- **Naming and source rule (Pete, later 2026-10-13):** AEF = AE Forecasts (modelling site; moving off it), AEC =
  Australian Electoral Commission (official). Results come from the commissions first (AEC, NSWEC, VEC, ECQ, ECSA,
  WAEC); the AEF archive (`external/elections/archive/`) is a cross-check and a flagged last-resort filler only.
  Federal flows: the AEC's official two-party flow tables replace AEF's `preference-estimates.csv`. States: the
  commission's distributions where published, else the estimate from official results.

## Wave 2a: data gathering (launched 2026-10-13 ~11:35, Sonnet, new files only while the rebuild runs)

| agent | output |
|---|---|
| AE archived results -> our schema, cross-checked | `scripts/build_archived_results.R`, `external/elections/archive/` |
| distributions: VEC 2006, NSWEC 2011, ECSA 2010/2014 | raw + parsed transfers, `docs/reviews/distributions-state-2026-10-13.md` |
| distributions: AEC 2001, ECQ 2004-2017 | raw + parsed, `docs/reviews/distributions-aec-ecq-2026-10-13.md` |
| census 2006/2011 by electorate | `docs/reviews/census-2006-2011-2026-10-13.md` + fetched raw |
| leaders file pre-2019 | `docs/reviews/leaders-backfill-2026-10-13.md` + proposed rows |

## Status log

- 2026-10-13 ~12:45: wave 2b running.
  - Wikipedia scraper extended to every election 2000+ incl. Tas/NT/ACT (old 34 pages byte-identical; new pages
    gave 67 poll rows); older table layouts (vic2006, qld2006/2009, sa2006, nt2016, tas2014-2021) handed to a
    parser agent (must keep the old pages identical).
  - Flow estimator: design `plans/flow-estimation-from-results-2026-10-13.md`; build + validation agent running
    (answer key = published distributions; pass bar fixed in the plan). Note: statewide flows today come from AE's
    `preference-estimates.csv`, another AE dependency this replaces.
  - Polling days 2000+: 31 of 38 remembered dates checked against Wikipedia infoboxes, all agree; 7 unchecked
    (qld2012, qld2015, sa2002, tas2025, nt2001/2005/2008; Wikipedia rate-limited). Moving them into
    `R/election_dates.R` is deferred to the first new pair, behind a byte-identical check on existing scores
    (many functions read the full list to find "the previous election").
  - Next for me: Poll Bludger extraction over all posts once the parser agent finishes (both read the wiki table).
- 2026-10-13 ~12:20: wave 2a complete.
  - Publish rebuild on the poll fixes: pooled seat log loss 0.3173 -> 0.3178 (+0.0005, SE 0.0014); vic2018 +0.0249
    over the 0.02 guard (its own level moved 0.15 at the scraper fix; via retrained models). Pete: KEEP (bug fixes).
  - AEC 2001 (150 divisions, transfers balanced) + ECQ first prefs 2004-2015 (`scripts/fetch_aec2001_ecq.R`,
    `reviews/distributions-aec-ecq-2026-10-13.md`): all winners match the AE archive; ECQ has NO preference rounds
    any year, TCP only partial 2004/2012 -> Qld flows must be estimated (Pete's decision). KAP class drifts OTH/OTH_RIGHT.
  - Distributions (`scripts/fetch_state_distributions.R`, `reviews/distributions-state-2026-10-13.md`): Vic 2006 done
    (49 seats, replay matches 49/49), NSW 2011 done from PDF countsheets (42 seats; 11 stopped at a majority). SA
    2010/2014: ECSA pages have no distributions -> estimate.
  - Leaders backfill: 45 proposed rows, 21 elections (`deciding-runs/leaders-backfill-proposed-2026-10-13.csv`,
    `reviews/leaders-backfill-2026-10-13.md`); 6 elections lack a pre-election revision; needs a supplement path
    because `fetch_leaders.R` overwrites hand rows.
  - Poll Bludger: every post fetched (4,934 of 4,935; 2011-08-06 one post missing from its day page).
- 2026-10-13 ~11:50: census done (`reviews/census-2006-2011-2026-10-13.md`): 7 G01 features; 2006 and 2011 DataPacks
  at CED and SED fetched (`external/reference/abs/raw/`, no login). **Finding, live in backtests:** older pairs carry a
  2016 or 2021 census vintage (fed2007 rows = 2016, `output/census-features.csv`), and the shipped
  `AUSPOL_DEMO_RESID=2` reads all seven columns, so its backtest gain on pre-2016 pairs includes look-ahead (the live
  forecast is unaffected: vic2026 uses 2021). Fix = the census preceding each election (2006 for 2007-2010, 2011 for
  2011-2015), then re-measure DEMO_RESID. Mapping: federal CEDs direct; state SEDs need reaggregation where boundaries
  moved (older boundary files not on disk). 2001-2002 elections: 2001 census, deferred (nice-to-have range).
- 2026-10-13 ~11:45: archived results ingested (`scripts/build_archived_results.R`, `external/elections/archive/`,
  148 files; check `reviews/archived-results-check-2026-10-13.md`): 28 elections cross-checked, 1,986 of 2,635 seats
  exact on every party class, 5 winner mismatches of 2,542 (nsw2015 Prospect an archive error: Labor won it, from
  memory; the other 4 are labels: Shooters as OTH, IND as OTH). fed2010 archive has 124 of 150 seats. Use: first
  preferences for elections we lack; official files win where both exist.
- 2026-10-13 ~11:40: track B done (`reviews/wiki-poll-pages-2026-10-13.md`, `deciding-runs/wiki-poll-pages-2026-10-13.csv`,
  178 rows): dedicated polling pages exist only for fed 2010+, Tas 2025, NT 2020, SA 2026, Vic 2026, NSW 2027, Qld
  2028, ACT next; everything else is in the main article. 14 elections with Wikipedia polls never fetched (Vic 2006,
  Qld 2006/2009, SA 2006, Tas 2010-2025, NT 2020 ...). No table at all: fed 2001, NSW 2003/2007/2019, Vic 2002, Qld
  2001/2004, SA 2002, WA 2001, Tas 2002/2006, NT 2001-2012, ACT most; prose only: fed 2004/2007, NSW 2015 -> Poll
  Bludger is the source there. Scraper run waits for the rebuild (load_polls reads the wiki table mid-rebuild).
- 2026-10-13 ~11:30: track A done (`reviews/coverage-results-inventory-2026-10-13.md`): first preferences and 2CP for
  nearly every election since 2001 already on disk in AE's clone (`analysis/Archived/elections/results_*.csv`, 74
  files, unread by our code; checked). Real gap: preference distributions (none for NSW 2003/2007, Vic 2002, Qld
  2001-2015; NSW and Qld were optional preferential). Harness blockers: NSW/SA need a seat-file fallback (anchor seat
  files 2019+), Vic hard-codes the previous transfers file. Order: vic2010, qld2017/2015/2012, sa2018/2014/2010,
  nsw2015, fed2004, nsw2011, then 2000-2009. Decisions put to Pete: flows where no distribution exists; features
  missing before 2016 (census 2016/2021 only, leaders file 2019+).
- 2026-10-13 ~11:15: track C done (`reviews/scoping-tas-nt-act-2026-10-13.md`): recommends NT first (fits the
  single-member path; polls very thin), then one Hare-Clark engine for ACT (every-ballot files) and Tas (best polls,
  weakest historical data). Dates and seat history partly from memory; NTEC site blocked the fetcher.
- 2026-10-13 11:10: wave 1 launched; publish rebuild on today's poll fixes running (`deciding-runs/rebuild-20261013-pollfixes-publish.log`).
- 2026-10-13 ~13:30: Poll Bludger read by Sonnet (17-agent workflow), `reviews/pb-llm-extraction-2026-10-13.md`:
  fed/NSW/Vic agree with AE on almost every poll with primaries (12 off > 2 of ~270) and confirm 277 of 558 AE-only
  polls (rules: 78). WA not usable yet (Liberal/National split convention). Not in the model yet. Wikipedia scraper
  unfrozen (fed2010 +4 Morgan polls; level screen 2.059). Flow key fix agent still running.
- 2026-10-13 ~13:50: official results 2000s (`reviews/official-results-2000s-2026-10-13.md`): VEC 2006 (88/88), ECSA
  2006 (47/47), ECSA 2002 (45/47), ECQ 2001 (89/89), VEC 2002 two-party only; all within 10 votes of the AEF archive,
  no winner differences. Still AEF archive (flagged): NSW 2003/2007 (NSWEC online starts 2011; Parliament sources
  block scripts), Vic 2002 first preferences, SA 2002 Adelaide/Ashford.
  vic2010 checklist (`reviews/add-pair-vic2010-checklist-2026-10-13.md`): found that `R/htv_flow.R` reads every
  `*-transfers.csv`, so today's vec-2006 / nswec-2011 / aec-fed-2001 files already feed the (time-forward) how-to-vote
  flow fit for every later election. Baseline rebuild on today's data running (`deciding-runs/rebuild-20261013-
  baseline-today.log`), to measure today's unmeasured changes against the 11:00 publish and to fix the baseline
  before vic2010 is added.
- 2026-10-13 ~15:00: (c) Hare-Clark prototype (`scripts/hare_clark_count.R`, `reviews/hare-clark-prototype-2026-10-13.md`)
  reproduces the official ACT 2020 count exactly in all 5 electorates (182 counts; one 0.000002-vote residual in
  Kurrajong). 2020 ballot files now only on the Wayback Machine (copy stored). Ties, bulk exclusion and mixed-value
  parcels untested by 2020. Forecast route sketched: reweight real ballots to simulated candidate shares; estimate
  8-11 sessions ACT, 4-6 more for Tas (no ballot files).
  Poll Bludger batch 2 (22 agents) scored: vic2010 30/34 AEF-only polls confirmed, nsw2011 22/27, nsw2015 49/68,
  qld2012 21/24, sa2014 12/17; accuracy as batch 1 except fed2004 (6 off > 2). Not yet in pb_llm_polls.csv (rebuild
  reading it).
- 2026-10-13 ~15:15: vic2010 bundle (Pete: fetch Trends first; one rebuild for vic2010 + census + leaders):
  plumbing committed locally (59a953c, not pushed until the rebuild publishes); candidacies gain official VEC 2006
  (459) and vic2010 winners; seat-context and retirement-derived rebuilt by hand; leaders supplement (44 rows);
  vic2010 salience fetched and merged (266 rows, nearly all zero); Poll Bludger batch 2 in pb_llm_polls.csv (1,040
  rows, 745 stated). Waiting on census-by-vintage, then one rebuild. Baseline for comparison:
  `deciding-runs/rebuild-20261013-baseline-today-from5.log` (pooled 0.3207; Barwon 2019 at the floor, seat registry).
  NSW dated forecast history shipped (70db9c8, ITG request).
