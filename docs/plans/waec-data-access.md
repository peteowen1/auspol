# How to get Western Australian results (found 2026-08-21, fetcher not yet built)

**Eight state general elections are reachable — 1996, 2001, 2005, 2008, 2013,
2017, 2021, 2025 — with full distributions of preferences, party affiliations
and booth-level results.** This records the access chain so nobody repeats the
search; the fetcher itself is not written.

## The chain

The WAEC site looks dead from outside: `results.elections.wa.gov.au` does not
resolve, `/results` 404s, and the 2025 election page contains no results
content at all. The path runs through the Drupal site instead.

1. **The results app** is at
   `https://www.elections.wa.gov.au/elections/state/sgelection` (hash-routed;
   the URL alone reveals nothing).
2. Its page loads
   `/modules/custom/elections/shared/js/config-loader.js`, which fetches
   **`/api/elections-config`**.
3. That returns the data host: **`https://eis.waec.wa.gov.au/api`**.
4. The endpoint paths are in
   `/modules/custom/elections/sg_elections/js/application.min.js`.

**It was found via the WA open data catalogue**, not the WAEC site: a polling
places dataset carried a link to `/elections/state/sgelection#/sg2017/...`,
which is the only place the app's address appears.

**`/api/elections-config` also returns a Google Maps API key belonging to the
WAEC. Do not record, commit or use it.** `external/` is gitignored, which is
the only reason the fetched copy is not in the repository.

## Endpoints

Base `https://eis.waec.wa.gov.au/api`, no key, no auth:

| path | gives |
|---|---|
| `/sgElections` | all 8 elections, with `ElectionName` such as `sg2025` |
| `/sgElections/{e}/LAElectedMembers` | declared members, plus all 61 electorates |
| `/sgElections/{e}/{code}/results` | **the whole electorate**, see below |
| `/sgElections/{e}/{code}/candidates` | candidates |
| `/sgElections/{e}/LAResultsByParty` | statewide by party |
| `/sgElections/{e}/LAVoteSummary` | vote summary |

`/{code}/results` returns everything needed in one call:

- **`resultsFullDistribution`** — every exclusion round, with
  `PREFERENCE_LEVEL`, `DISTRIBUTION_LEVEL`, `BALLOT_PAPER_NAME` and an
  **exhausted** count. 135 rows for Albany 2025 alone.
- `resultsCandidates` — with `PARTY_AFFILIATION`, which is what
  `classify_party()` needs.
- `results2CP`, and `resultsPollingPlace` at booth level.

## Before using any of it

- **Check the voting system per election.** Western Australia's Legislative
  Assembly is full preferential now, but the corpus already contains one
  jurisdiction where mixing systems silently corrupted a flow matrix: adding
  compulsory-preferential Queensland transfers to optional-preferential NSW
  made it 0.194 of log score WORSE. The `resultsFullDistribution` rows carry an
  exhausted count, so an election where ballots exhaust is detectable directly
  rather than assumed — check it and refuse, do not trust the era.
- **59 districts × 8 elections is 472 calls.** Cache them, and be polite about
  rate.
- **The 61 electorates include non-district entries.** Filter on
  `ElelctorateType == "District"` — note the spelling, which is theirs.

## What it would be worth

Queensland took the flow matrix from 746 exclusion events to 1,496 and One
Nation's from 18 to 198, and that alone moved Victoria's One Nation median from
5 seats to 9. Western Australia adds up to eight more elections, and One Nation
has contested there since 1997.

It would also give up to **seven more backtest pairs**, against the ten the
whole corpus currently has — which is the constraint every measurement in this
repo keeps running into.
