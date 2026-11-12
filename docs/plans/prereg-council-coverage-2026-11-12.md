# Pre-registration: council history coverage and the stale overlap table (12 Nov 2026)

Written before the rebuild that measures it. Not to be edited after; amendments go below as visible additions.

## What changes

Three corrections to `output/council-history.csv`, the input of the xgb council features (`AUSPOL_XGB_COUNCIL`, shipped):

1. **Stale overlap table.** `output/lga-district-overlap.csv` was built 8 Oct, before nsw2007/11, qld2009/12/15,
   sa2006/10/14 and vic2006 joined the corpus, and nothing in the rebuild refreshed it. No candidate there could match a
   council, yet the seats were marked covered, so every one read "never stood" (nsw2011: 71 elected councillors).
   Now rebuilt in stage 3 when older than `candidacies.csv` or its script.
2. **Coverage per council, not per state-year.** A seat is covered by a council election year only if a council
   overlapping it (the matching rule's 5%) has councillor results that year. A seat with no overlap rows is NA.
3. **Queensland 2008 council results** (on disk since October, parsed but excluded): mayors for ~73 councils,
   councillors for 5. Covered only where those 5 overlap, by rule 2.

Diff against the 8 Oct-overlap history (22,200 candidacies, same keys): feature changes nsw2011 122, qld2009 18,
qld2012 15, qld2015 25, qld2017 5, fed2010 6, fed2013 5, fed2016 2; coverage to NA 185 (Fairfield/Cabramatta,
Wollongong, Lindsay/Penrith, Geraldton, abolished seats with no boundaries); coverage to covered 285 (qld2009 198,
fed2010 87). vic2026 (live) unchanged.

## How it is measured

One rebuild from stage 3 (`scripts/scheduled_rebuild.ps1 -From 3`), committed code, against the 10 Nov snapshot
`output/snapshots/20261110-0929-82329b06-from1`. Code since then has also moved (classify_party bare codes,
4e98e9f6), so the CONTROL is every election this change cannot reach: if those are byte-identical in seat
probabilities, the comparison isolates this change; if not, the other change is named and sized first.

## Criteria (all 35 elections, published path)

1. GUARD: pooled seat log loss (35 elections) not worse by more than 1 SE (SE clustered on election).
2. GUARD: primary-share RMSE on all cells not worse by more than 0.02 points.
3. REPORTED, not decisive: per-election log loss for nsw2011, qld2009, qld2012, qld2015; squared error on the cells
   whose council features changed.

## Decision rule

This is a data correction: the old input was wrong (a missing lookup read as a measurement). If both guards hold, it
ships; no improvement is required. If a guard fails, it does not ship and goes to Pete with the elections and cells
that drove it.

## Would make an apparent pass unacceptable (named in advance)

- Any control election not byte-identical without an explanation.
- The live vic2026 forecast moving by more than 2 points of win probability in any seat, unexplained (its features
  are unchanged; only the trained trees move).

## Amendment 1 (13 Nov 2026, after the rebuild; the clauses above are unedited)

Rebuild `deciding-runs/20261112-1829-rebuild/` DONE 6:24am, snapshot `output/snapshots/20261113-0622-d938ce20-from3`.

- Guard 1 PASS: pooled log loss 0.3166 -> 0.3175 (+0.0009, SE 0.0018; 2,931 seats, 35 elections).
- Guard 2 PASS: share RMSE 4.0771 -> 4.0837 (+0.0067, n 19,616).
- Control: fed2007, wa2001, wa2005 and wa2008 (every election before qld2009, the first changed training election) are
  byte-identical. Every later election moves because its as-at trees train on changed rows; that explains the moves.
- Reported: nsw2011 -0.0640 RMSE, qld2012 +0.0416, qld2015 -0.2092 (qld2009 is not a scored pair). Worse by more than 0.02
  log loss: wa2013 +0.035 (Churchlands, Albany), sa2018 +0.023 (Morphett), wa2017 +0.022 (Labor 2-6 points lower across seats).
- Live clause BREACHED: the scorer's SC4 was vacuous (the rebuild does not rerun the live forecast), so the live forecast
  ran three times at HEAD d938ce20, seed 42: 10 Nov files, 10 Nov files plus new production trees, and all new files.
  Max move 5.3 points (Footscray), 32 party-seat rows over 2 points; the new trees alone give 5.1 and 29 rows, and the
  other 189 rebuild files at most 1.5. Outputs in `deciding-runs/20261112-council-scoring/live-walk/` (gitignored).
- Pete, 13 Nov: "Ship it". The breach is recorded here rather than the clause being reread.
