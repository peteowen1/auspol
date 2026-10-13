# Official seat-level results for the 2000s elections (2026-10-13)

Why this matters: the coverage program wants every 2000-2009 election scored, and our only seat-level copy of most of them was the AEF archive (AE Forecasts, a modelling site we are moving off). Per the naming and source rule in `docs/plans/coverage-program-2026-10-13.md`, results come from the commission first and the AEF archive is a cross-check and a flagged last-resort filler.

Everything below is produced by `scripts/fetch_official_results_2000s.R` (check-code prefix `KQ`; run one section or all: `vec`, `nswec`, `ecsa`, `ecq`, `xcheck`). Raw downloads are under `external/reference/<commission>/raw/<election>/`; parsed files are in `external/elections/` in the schema of that commission's existing files (`firstprefs`: seat, party class, votes; `tcp`: seat, party class, votes) with a `-detail` file beside each that keeps every field the source has. The cross-check table is `deciding-runs/official-results-2000s-xcheck-2026-10-13.csv`.

How to read the cross-check columns: "seats compared" = seats present in both the new official file and the AEF archive; "exact" = seats whose sorted candidate vote list is identical (party labels ignored, because the archive and `classify_party()` disagree on OTH, OTH_RIGHT and IND for some small parties); "max diff" = largest single-candidate vote difference in a seat (lower is better); "winner mismatches" = seats where the top two-candidate count goes to a different party class (lower is better).

## Skipped: official files already exist in `external/elections/`

| election | existing official files |
|---|---|
| fed 2001 | `aec-fed-2001-firstprefs/tcp/transfers.csv` |
| fed 2004 | `aec-fed-firstprefs/tcp.csv` (fed2004 rows) and `external/reference/aec/fed2004-*` |
| Qld 2004, 2006, 2009 (and 2012, 2015) | `ecq-<year>-qld-firstprefs.csv` (2004 and 2012 also have `-tcp.csv`) |
| WA 2001, 2005, 2008 | `waec-<year>-wa-firstprefs.csv`, `waec-wa-winners.csv`, `waec-wa-transfers.csv` |
| NSW 2011 (out of range) | `nswec-2011-nsw-*` (candidates, countsheets, transfers; no firstprefs file) |

## Per election

### Vic 2006 (VEC) - DONE
- Source: VEC blob archive `.../public-files/historical-results/state2006/state2006result<district>district.html`, 88 pages already on disk from `scripts/fetch_state_distributions.R` (not refetched; each page checked for its closing `</html>`).
- Format: HTML, one page per district; first preference table, "Results after distribution of preferences", "Two candidate preferred vote".
- Parsed: 88 of 88 seats; candidate votes sum to the page's Formal Votes figure in 88 of 88. Files: `vec-2006-vic-firstprefs.csv`, `-firstprefs-detail.csv`, `-tcp.csv`, `-tcp-detail.csv`, `-tcp-basis.csv`.
- Two-candidate basis (important): where the after-distribution table is exactly two candidates (36 seats) it is the final rechecked count and is used. In the other 52 seats the only two-candidate figure on the page is the "Two candidate preferred vote" table, which the page says is based on first-count figures, so it understates the final count (by up to 1,604 votes in Lara; winners unchanged). `vec-2006-vic-tcp-basis.csv` says which basis each seat uses. Two seats are single-class finals (Rodney, Liberal v National), so the file has one row per finalist, not per class.
- Cross-check against AEF: 88 compared, 86 exact on candidate votes, max diff 10 votes (South-West Coast); 71 exact if party class must also agree (the rest differ only in OTH vs OTH_RIGHT labelling). Two-candidate: 88 winners compared, 0 mismatches, 71 exact on votes, max diff 1,604 (first-count seats, as above). Ferntree Gully is the check that mattered: the first-count table has Labor ahead by 30 votes, the rechecked final (and AEF) has the Liberal ahead by 27; the official file uses the final.
- Problems: none beyond the first-count basis.

### Vic 2002 (VEC) - PARTIAL (two-party-preferred only; first preferences not found)
- Source: VEC "Report to Parliament on the 2002 State election", https://www.vec.vic.gov.au/-/media/ed23702c5dab40338a19978fadc93470.pdf (125 pages), Figure 30: district two-party-preferred votes, Labor v Liberal/National. Raw: `external/reference/vec/raw/2002/`.
- Parsed: 88 of 88 districts into `vec-2002-vic-tcp.csv` (ALP and LNP rows). This is the two-party-preferred count (the report says it was made by a special count where Labor or the Coalition was not in the final two), not always the candidate two-candidate-preferred count.
- No official candidate first preferences: the report has candidate names, districts and parties (Appendix 12) but no district vote counts. The VEC site holds historical results only from 2006 on (container listing, checked live); the data.vic.gov.au 2002 datasets are Legislative Council province results. So 2002 first preferences still rely on the AEF archive.
- Cross-check against AEF (only districts where the AEF final two were Labor v Liberal/National; 8 archive districts had other finals and are excluded, and 5 of the remaining 80 did not match by district name): 75 seats' winners compared, 0 mismatches, 69 exact on votes, max diff 483 (Preston). Seats where AEF's final two were not ALP v LNP (Mildura: independent v Liberal) are excluded because the two counts answer different questions.

### NSW 2007 and NSW 2003 (NSWEC) - NOT OBTAINED
- NSWEC's own site holds state results only from 2011 (`pastvtr.elections.nsw.gov.au` lists SGE2011 and SGE2015; `SGE2003/` and `SGE2007/` return 404, checked live). NSWEC's page "NSW State election results 1856 - 2007" only links to the Parliament of NSW's Antony Green database page. That page loads but carries no download link in its HTML (the links are not exposed to a scripted client), and the Parliamentary Library 2007 analysis PDFs (`parliament.nsw.gov.au/researchpapers/Documents/...`) answered 403 / a bot-challenge page. Recorded and not worked around; the HTML responses I saved by mistake were deleted.
- Result: both elections still rely on the AEF archive (`archive/2003nsw-*`, `archive/2007nsw-*`). A person could download the Parliament database or the 2007 analysis PDF in a browser and drop it into `external/reference/nswec/raw/2007/`.

### SA 2006 and SA 2002 (ECSA, Jaensch vol. 1) - DONE (first preferences complete for 2006, 45 of 47 for 2002)
- Source: ECSA publishes "History of South Australian elections 1857-2006: House of Assembly, Volume 1" by Dean Jaensch (PDF, 7 MB), https://www.ecsa.sa.gov.au/component/edocman/1857-2006-house-of-assembly-v1-by-dean-jaensch/download?Itemid=0 . Raw: `external/reference/ecsa/raw/2006/jaensch-1857-2006-house-of-assembly-v1.pdf` (plus the extracted text). This is the Commission's published record compiled by an academic, not ECSA's own polling-place files (ECSA's site has those only for 2010 on), so it is the best official-channel source rather than a primary count.
- Format: PDF, one block per district: enrolled/voted/formal/informal, candidates with party code, votes and percent, and "Result after preferences" (two finalists) where first preferences did not give a majority.
- SA 2006: 47 of 47 districts, candidate votes equal the printed formal vote in 46; Stuart differs by 1 vote (kept, flagged). 41 TCP rows over 21 districts (two-candidate counts exist only where a distribution was needed; the other districts were won on first preferences). Cross-check: 47 compared, 46 exact, max diff 1 vote (Stuart); 40 exact if party class must agree (the rest: AEF files unnamed no-party candidates as OTH, we class them IND). TCP: 20 seats compared, 0 winner mismatches, 20 of 20 exact on votes.
- SA 2002: 45 of 47 districts. Adelaide and Ashford are left out because the printed candidate votes do not sum to the printed formal vote (short by 90 and 50 votes); the printed percentages show the cause is a typo in the book (Adelaide: Lomax-Smith printed 8,125 but 40.4 percent of 20,333 is 8,215, which is exactly the AEF archive figure). These two seats stay on the AEF archive. 56 TCP rows over 28 districts. Cross-check: 45 compared, 45 exact on candidate votes (max diff 0); 17 exact with party class (labelling only: Liberal/National/Family First classes). TCP: 28 compared, 1 winner mismatch (Hammond: Peter Lewis, official party code CLIC, our class OTH; AEF says IND; same candidate and same votes, a label difference), 27 exact on votes, max diff 18 (Schubert).
- Problems: one finalist name misspelt between tables (Norwood, Ciccarelo) matched on seat plus party code and reported; Liberal v National finals are kept as two rows (Chaffey, others).

### Qld 2001 (ECQ) - DONE for first preferences; two-candidate count partial
- Source: ECQ "2001 Statistical Returns", https://www.ecq.qld.gov.au/__data/assets/pdf_file/0017/2654/2001-Statistical-Returns.pdf (236 pages, 9.7 MB; found by search, the zip routes the earlier agent tried do not exist for 2001). Raw: `external/reference/ecq/raw/2001/`.
- Format: PDF tables. Table 1.3 gives, per district, every candidate's first preference votes by party code, the two finalists' votes, informal votes and the winning party. The text order of the lines varies by page, so each result line is tied to its district by (formal votes, informal votes) from Table 1.2, never by the name next to it; three stray independent-candidate fragments (Brisbane Central, Ipswich) are reattached by that same sum.
- Parsed: 89 of 89 districts, candidate votes equal the printed formal vote in 89 of 89. Files: `ecq-2001-qld-firstprefs.csv`, `-firstprefs-detail.csv` (adds informal votes and both finalists' votes), `ecq-2001-qld-tcp-winner.csv` (winner party and winner votes, 89 seats), `ecq-2001-qld-tcp.csv` (full two-row finals, only the 10 districts with exactly two candidates).
- Limit: the table does not print the loser's party, and under optional preferential voting the loser need not be second on first preferences, so I did not guess it; every district has both finalists' vote totals in the detail file but a two-row TCP only exists for the 10 two-candidate districts.
- Cross-check against AEF: 89 compared, 88 exact on candidate votes, max diff 4 votes (Keppel); 64 exact with party class (labelling: our class puts One Nation/City Country Alliance candidates in OTH_RIGHT where the archive says OTH). TCP winners: 89 compared, 0 mismatches, 89 of 89 exact on the winner's count.

### WA 2001 / 2005 / 2008 - SKIPPED (official files exist, see above)

## Final table: which elections now have official results

Columns: first preferences = official candidate first preferences by district; two-candidate = official two-candidate-preferred count.

| election | first preferences | two-candidate | still relying on AEF archive for |
|---|---|---|---|
| Vic 2006 | official, 88/88 (VEC) | official, 88/88 (36 final, 52 first-count) | nothing |
| Vic 2002 | no | official two-party-preferred only, 88/88 | candidate first preferences: the VEC publishes no 2002 district counts online (report has none) |
| NSW 2007 | no | no | everything: NSWEC online only from 2011; Parliament database and library PDFs blocked to scripts |
| NSW 2003 | no | no | everything (same reason) |
| SA 2006 | official, 47/47 (ECSA, Jaensch) | official where a distribution was needed (20 seats) | two-candidate counts for seats won on first preferences (none exist) |
| SA 2002 | official, 45/47 | official where needed (28 seats) | Adelaide and Ashford (book typos) |
| Qld 2001 | official, 89/89 (ECQ) | winner's count 89/89; full pair 10/89 | loser's party in 79 districts (not printed) |
| WA 2001, 2005, 2008 | already official (WAEC) | transfers/winners files exist | nothing new |
| fed 2001, fed 2004 | already official (AEC) | already official | nothing new |
| Qld 2004, 2006, 2009 | already official (ECQ) | partial (2004) | unchanged from before |

## What the new files need before a harness uses them

- Party classes in these files come from `classify_party()` on the party text or code the source prints, so they will differ from the archive's labels for small parties (OTH vs OTH_RIGHT vs IND). The vote numbers are the cross-checked part.
- Not registered yet: `docs/DATA-REGISTRY.md` is generated; rerun `scripts/build_data_registry.R` when these files are accepted (I did not touch existing scripts).
