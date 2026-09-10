# GDELT news-mention feasibility scoping — 2026-09-10

Feasibility scoping only, per `docs/NEXT-STEPS.md`'s "Awaiting Pete" item:
*"News-article mention counts (GDELT) were the other candidate mechanism
raised earlier this session and are untried."* No fetcher built, no model
touched. Go/no-go input for a future decision.

## 1. What GDELT actually offers

| access path | key needed | historical reach | cost |
|---|---|---|---|
| **DOC 2.0 API** (`api.gdeltproject.org/api/v2/doc/doc`) | None | **Officially guaranteed: last 3 months only.** `STARTDATETIME`/`ENDDATETIME` docs state the date must be within the last 3 months; requests further back "may still return data, but it's not guaranteed." Users report it sometimes works back to 2017 unofficially. | Free |
| **BigQuery public dataset** (GKG 2.0 / Events / EventMentions tables) | GCP project + billing account | **Full archive from Feb 2015** (GKG 2.0 launch), 15-minute update cadence. Earlier GDELT 1.0 (1979–2015) exists but is a different, coarser event-based format, not suited to per-candidate mention counting. | Free tier: 1TB query processing/month. Real queries can be expensive — one documented example query scans 221GB, >20% of the free monthly quota, in a single run. |

**Sources:** [GDELT DOC 2.0 API Debuts](https://blog.gdeltproject.org/gdelt-doc-2-0-api-debuts/), [DOC & GEO 2.0 API Updates: Full Year Searching](https://blog.gdeltproject.org/doc-geo-2-0-api-updates-full-year-searching-and-more/), [Google BigQuery + GKG 2.0: Sample Queries](https://blog.gdeltproject.org/google-bigquery-gkg-2-0-sample-queries/), [GDELT Data page](https://gdeltproject.org/data.html)

## 2. Coverage vs. our actual 22 pairs

GKG 2.0's practical per-entity-mention window starts **February 2015**. Against our pairs:

| in-window (≥2015) | out-of-window (pre-2015) |
|---|---|
| fed2016, fed2019, fed2022, fed2025, nsw2019, nsw2023, qld2020, qld2024, sa2022, sa2026, vic2018, vic2022, wa2017, wa2021, wa2025 (~15) | fed2007, fed2010, fed2013, vic2014, wa2001, wa2005, wa2008, wa2013 (~7) |

So roughly two-thirds of our corpus is reachable, one-third structurally isn't — same shape of gap the Google Trends signal already has (it's anchored to whenever Trends' own usable window starts), not a new problem class.

## 3. Test case — hit an access wall, not fabricated

Tried the free DOC 2.0 API directly (no BigQuery credentials available in this environment) for two queries: `"Rob Priestly" Nicholls` (the named miss) and `"Monique Ryan"` (a working-Trends control, Kooyong). **Both returned HTTP 429 Too Many Requests immediately**, before any content was retrieved. This looks like the fetch infrastructure's shared IP is already rate-limited against GDELT's public endpoint, not a query-specific failure. **No real mention-count numbers were obtained for either case** — this is an honest wall, not a result.

Consequence: whether GDELT actually surfaces coverage for a genuinely local, non-teal independent (Priestly-type) rather than only already-prominent candidates (Ryan-type) is **untested**, not confirmed either way.

## 4. Real risk, unverified because of #3

General GDELT literature reports non-trivial noise: one academic audit puts per-field accuracy around 55% with ~20% record redundancy, and documents English-language/major-outlet bias in coverage. Australia is English-language (favorable), but a local suburban/regional independent is exactly the profile most likely to be under-indexed by a global news aggregator built from wire/syndicated content — the same "rural blind spot" this repo already found and documented for Google Trends (`docs/reviews/salience-rural-blind-spot-2026-09-07.md`). GDELT may replicate that blind spot rather than filling it, which would defeat the reason for trying it (Trends already fails on exactly the Priestly/Boele/Heise cases). This is a real risk, not confirmed, because #3 blocked empirical testing.

## 5. Build cost estimate, if pursued

- **DOC API path: not a viable foundation for backtesting.** Its 3-month guaranteed window makes it useless for scoring fed2016–vic2022 historically; the "unofficially works further back" behavior is not something to build a scored model on.
- **BigQuery path is the real option**, and needs Pete to provision a GCP project + billing (free tier likely sufficient with careful queries — partition-pruned by date, project only needed columns, avoid full-table scans per candidate). Rough shape: one query per (candidate, seat, date-window) across ~15 in-window pairs × however many flagged/rare candidates per pair (the existing salience corpus already restricts to a similar candidate subset) — bounded, not a full-corpus scan, if written carefully.
- Per this repo's own hard rule (the Trends refetch disaster, `C:\dev\CLAUDE.md`): **cache the raw per-article/day response, never just a derived count** — a second refetch is not guaranteed to be free or available later.

## Recommendation

**Worth pursuing only if Pete provisions BigQuery access, and only after a small manual test confirms real per-candidate signal exists for a known-hard case (Priestly-type) — not assumed from this scoping alone**, since the one empirical test available in this session was blocked by rate-limiting. Do not build a DOC-API-based fetcher; its historical reach is not reliable enough to backtest against. Not recommended as an immediate next build given: (a) the access wall left the core question (does GDELT actually see local independents Trends misses?) unanswered, (b) real infra setup cost (GCP+billing) is now on Pete, and (c) real risk it duplicates Trends' own blind spot rather than complementing it.
