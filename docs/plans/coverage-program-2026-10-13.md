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

## Status log

- 2026-10-13 ~11:15: track C done (`reviews/scoping-tas-nt-act-2026-10-13.md`): recommends NT first (fits the
  single-member path; polls very thin), then one Hare-Clark engine for ACT (every-ballot files) and Tas (best polls,
  weakest historical data). Dates and seat history partly from memory; NTEC site blocked the fetcher.
- 2026-10-13 11:10: wave 1 launched; publish rebuild on today's poll fixes running (`deciding-runs/rebuild-20261013-pollfixes-publish.log`).
