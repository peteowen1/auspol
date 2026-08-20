# Scoping: distribution-of-preferences data

Written 2026-08-18. Nothing downloaded beyond four test pages.

## Why this is the blocking item

The seat rebuild needs a preference flow matrix estimated from data, not a
scalar per party with a fallback. The current best attempt uses 16 SA districts
from Wikipedia: 97 exclusion events across 28 conditional cells, most at n ≤ 2,
and **49 transfers in an 88-seat Victorian trial resolved to no observed cell
at all**. Nothing downstream can be evaluated until this is fixed.

Evidence and the failed trial:
[../reviews/onp-allocation-sa-2026-08-17.md](../reviews/onp-allocation-sa-2026-08-17.md).

## Victoria 2022 — available, candidate-level, confirmed end to end

**This is the acquisition to do.** Verified by fetching real pages, not
inferred.

Per-district distribution pages are **server-rendered static HTML**:

```
https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/
  results-by-district/{district}-district-results/{district}-results-distribution
```

The page carries one table giving every exclusion by name with the exact
ballots transferred to each remaining candidate:

```
                                          | LE HURAY | LUCAS | CHAU | MENADUE | HIBBINS | EMILSEN | TOTAL
Total first preference votes              |     1263 | 12198 |10421 |     449 |   14286 |     626 | 39243
Transfer of 449 ballot papers of
  MENADUE, Alan (1st excluded candidate)  |       89 |    77 |   94 |         |     107 |      82 |   449
Progressive Total                         |     1352 | 12275 |10515 |         |   14393 |     708 | 39243
```

**This is candidate-level, which is exactly what the rebuild needs** and what
the SA data (parsed into five party classes) is not. It resolves the collapsing
problem recorded as a structural gap: a real ballot's Legalise Cannabis, Animal
Justice, Family First, Freedom, Victorian Socialists and independent candidates
are each excluded separately here, with their own destinations.

Verified working on two districts of different sizes — Prahran (6 candidates,
10 table rows) and Morwell (9 candidates, 22 rows). Vote figures appear
uncommaed in the markup (`>14286<`), so a plain regex parse is enough. No
JavaScript, no browser automation.

Candidate-to-party mapping comes from the sibling results page, already
verified in earlier scoping:
`.../{district}-district-results`.

**Cost: 88 districts x 2 pages = 176 fetches**, plus a parser. Roughly an hour.

## Victoria 2018 — RESOLVED 2026-08-20, and 2014 with it

**The section below is superseded.** Both elections are now fetched by
`scripts/fetch_preferences_vic_historical.R`.

The URLs below were never going to work, because the results are not on the
main VEC site at all. They live in an **Azure blob archive**, linked from a
single line of markup on the 2018 page:

```
itsitecoreblobvecprd01.blob.core.windows.net/public-files/historical-results/state2018/
```

`state2014` is in the same archive; `state2010`, `state2006` and `state2022`
are not (checked). Each district has a results page and a
`distribution{slug}district.html` page, so first preferences, parties, the
elected member and the exclusion sequence are all available.

Validated to **0.00 points** on every major party against the anchor's own
`prior-results.csv`, both years, with Greens preference flows of 79.8% (2014)
and 81.0% (2018).

The lesson worth keeping: **"every URL variant 404s" meant the wrong site was
being searched, not that the data was gone.** The original investigation tried
patterns under `vec.vic.gov.au` and concluded unavailability; the answer was a
`blob.core.windows.net` link in the page source.

### Superseded: the original note


Every URL variant tried returns 404:

- `/2018-state-election/results-by-district/prahran-district-results/prahran-results-distribution`
- `/2018-state-election-results/results-by-district/...`
- `/2018-state-election/results-by-district/prahran-district-results`

2018 sits on an older system — consistent with the anchor's own scraper
(`analysis/fetch_election_data_vic.py`) needing Selenium and an iframe for the
2018 URL. Needs separate investigation; **not** a blocker for a first matrix.

## South Australia — SOLVED 2026-08-18, and no browser was needed

The results site is an Angular app whose every path returns the same
1,566-byte shell, so this was written up as needing browser automation. It does
not. **Reading the app's own JS bundle gives a clean public JSON API**, no key,
no auth:

```
base   https://apim-ecsa-production.azure-api.net/results-display/
routes ElectionDates
       HAStatic/{electionDate}          e.g. HAStatic/2026-03-21   (157 KB)
       HAChange/{electionDate}/{n}      e.g. HAChange/2026-03-21/0 (2.3 MB)
```

`HAChange` carries **`finalDistribution` for all 47 districts** — every round,
the named excluded candidate, and the exact `voteChange` to each remaining
candidate. `HAStatic` carries candidate→party. The two use different
`candidateId` numbering, so join on normalised name within district.

Yield: **294 exclusion events across all 47 districts**, against 97 across 16
from the Wikipedia sample this work had been stuck on.

**Lesson worth keeping: "the site is a JavaScript app" is not the same as "the
data is unreachable".** Reading the bundle for its API base took minutes; the
plan written before doing so budgeted for browser automation and treated South
Australia as deprioritised because of it. Check the bundle before concluding a
SPA needs a browser.

## Licence — still unresolved, and now it matters more

No copyright, Creative Commons or terms-of-use statement appears anywhere on
the VEC results pages, and `vec.vic.gov.au/copyright` returns 404. "No
statement found" is not a licence. This is already an item awaiting Pete
alongside the anchor's poll data and the repo-public decision, and committing
VEC-derived data to the repo — the approved plan — brings it forward.

## Recommended order

1. **Fetch and parse Victoria 2022** (88 districts). Gives a candidate-level
   matrix in the target jurisdiction.
2. **Estimate the flow matrix from it**, conditioned on survivors, and report
   cell coverage — the same way the SA attempt did, so the thinness is visible.
3. **Only then** decide whether SA or Victoria 2018 is worth the extra effort,
   from measured coverage gaps rather than in advance.

Do not build simulation code before step 2. The matrix determines whether the
rest is worth writing, and the SA attempt has already shown what happens when
it is assumed rather than measured.
