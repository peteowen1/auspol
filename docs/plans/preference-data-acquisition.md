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

## Victoria 2018 — not available at that pattern

Every URL variant tried returns 404:

- `/2018-state-election/results-by-district/prahran-district-results/prahran-results-distribution`
- `/2018-state-election-results/results-by-district/...`
- `/2018-state-election/results-by-district/prahran-district-results`

2018 sits on an older system — consistent with the anchor's own scraper
(`analysis/fetch_election_data_vic.py`) needing Selenium and an iframe for the
2018 URL. Needs separate investigation; **not** a blocker for a first matrix.

## South Australia — harder than Victoria, and mostly redundant

ECSA's results site (`result.ecsa.sa.gov.au`) is an Angular single-page app.
Every path probed — `/results/ha`, `/api/results`, and two others — returns the
**identical 1,566-byte shell**, so the 200 status is client-side routing rather
than data. Extracting it means either driving a browser or reverse-engineering
the JS bundle to find the real endpoint.

Given Victoria 2022 delivers 88 candidate-level districts in the actual target
jurisdiction, SA is no longer the priority it was when it was the only source.
The 16 Wikipedia districts already parsed remain useful as an out-of-state
check on whatever Victoria yields.

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
