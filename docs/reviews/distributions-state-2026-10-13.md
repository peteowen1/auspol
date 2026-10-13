# State distributions of preferences: Vic 2006, NSW 2011, SA 2010 and 2014 (2026-10-13)

Script: `scripts/fetch_state_distributions.R` (sections `vec`, `nswec`, `ecsa`; check codes `DD1x` Victoria,
`DD2x` NSW, `DD3x` SA; "SQ" is taken by `fit_seats_full.R`). Re-running it fetches nothing already on disk
(Penrith's PDF is retried each run, see NSW). Raw downloads sit under `external/reference/{vec,nswec,ecsa}/raw/<election>/`;
outputs under `external/elections/` (gitignored with the rest of that folder).

Result in one line: Victoria 2006 and NSW 2011 are fully parsed and checked. SA 2010 and 2014 could not be done, because the
commission publishes no count-by-count distribution for either election.

Schema of the new `*-transfers.csv` files is the existing one (`election, seat, round, from, to, votes`; `from` and `to` are
`classify_party()` classes; `round` is the k-th exclusion; exhausted votes are left out, as in the existing NSW file). Beside each is a
`-detail` file with every field the source has (candidate names, party text, votes distributed, progressive totals, exhausted votes),
plus `-candidates`, `-checks` and, for NSW, `-countsheets` (every cell of every countsheet, long format).

## Victoria 2006 (VEC)

- Source: VEC blob archive, `https://itsitecoreblobvecprd01.blob.core.windows.net/public-files/historical-results/state2006/`
  (container listing saved as `container-listing-state2006.xml`). Per district `state2006distribution<district>district.html` and
  `state2006result<district>district.html` (party of each candidate, first preferences, the "after distribution" table and the
  two-candidate-preferred table). 176 pages, all ending in `</html>`. `scripts/fetch_preferences_vic_historical.R` says state2006 is not
  in the archive; that header is wrong.
- Seats: 88 of 88 districts accounted for. 49 have a distribution (524 transfer rows after class aggregation, 331,148 votes moved). 39 have
  a stub page (heading and candidate names, no counts) because the winner held over 50% of first preferences. For all 39 I checked
  that the leader holds more than 50% and is the elected member named on the page.
- Checks, over the 49 seats with a distribution:
  - Every transfer row sums to the page's own row total (parser stops otherwise): 49 of 49.
  - First preferences on the distribution page equal the result page: 47 of 49. Bendigo East and Kilsyth differ by a few votes because the
    distribution page uses rechecked first preferences and the result page the first count. Their replayed final totals still match the
    result page's after-distribution table.
  - Replaying the transfers gives the last two candidates' totals in the page's own FINAL TOTAL row: 49 of 49.
  - Replay against the result page's "results after distribution" table: 48 of 49. Morwell is the exception: the result page lists three
    candidates (Northe 12,521, Parker 5,240, Jenkins 15,141) while the distribution page's FINAL TOTAL row has the last two (Northe 17,173,
    Jenkins 15,729). The VEC's two pages disagree on where the count stopped; I used the distribution page.
  - Published two-candidate-preferred (TCP) table: comparable in 37 seats (the other 12 had a different pair). Maximum difference 531 votes
    (Ivanhoe), 19 seats differ by more than 50. Cause: the page states its TCP figures are first-count figures and the distribution uses
    rechecked votes. Not a parse error, but it means "matches the TCP" means "within a recheck", not exactly equal.
- Party classes agree with the existing `vec-2010-vic-transfers.csv` conventions (CEC and Family First to OTH_RIGHT, People Power and
  Socialist Alliance to OTH, Nationals to LNP, blank party to IND).
- Files: `vec-2006-vic-transfers.csv`, `-transfers-detail.csv`, `-candidates.csv`, `-checks.csv`.
- Problem to know: only 49 seats carry transfers, so a flow estimate from this file rests on those 49 (compare 43 for vic2010).

## New South Wales 2011 (NSWEC)

- Source: `https://pastvtr.elections.nsw.gov.au/SGE2011/`. The HTML preferential count page `la/la_dop-<District>.htm` is an empty stub for
  every district (identical 8.7 KB shell, no table; Balmain kept as `stub-la_dop-Balmain.htm`). The counts are in the PDF it links to,
  `laPDF/<District>.pdf`, one countsheet per district. District list from `la_landing.htm` (93 names). Also fetched for each district the
  post-election-night first-preference page (`la_post_election_night-*.htm`, gives party code and full party name) and the post-election-night
  TCP page. 92 PDFs plus 93 + 93 HTML pages, all complete (`%%EOF` / `</html>`).
- The PDF text order is scrambled, so the parser reads words by position (`pdftools::pdf_data`): numbers go to the column whose right edge is
  nearest, candidates by row; the excluded candidate of each count is read from the header and cross-checked.
- Seats: 93 of 93 accounted for. 92 PDFs parsed. 50 of those have no exclusion (winner on first preferences, count 1 only). 42 have transfers
  (525 rows after class aggregation, 190,832 votes moved, exhausted excluded). The 93rd, **Penrith**, has no usable PDF: the server returns a
  76-byte pointer text (`dir="/var/www/.../file_repository" fileid="19501"`) instead of the file. Penrith needs no distribution anyway: Ayres holds 54.00% of
  first preferences (5 candidates).
- Checks, all passed for the 42 seats with transfers (0 problems):
  - First preferences equal the NSWEC post-election-night page, candidate by candidate: 92 of 92, and sum to the printed Total Formal.
  - Each excluded candidate's accumulated votes equal the "votes distributed" in the header; the excluded candidate is the lowest left.
  - Transfers plus exhausted votes equal votes distributed, every count; progressive totals equal previous total plus transfer for every
    continuing candidate.
  - The commission's footer "NAME will be elected" is the leader of the last count and holds more than half of the votes still in it: 92 of 92.
    The green ELECTED cell never disagreed.
  - TCP page: 30 seats comparable (final two equal the TCP pair), maximum difference 50 votes, none over 50. 11 seats have a final count with
    three or more candidates left, so no pair to compare (see below). Balmain's TCP page shows zeros (the commission suspended the TCP count; the sheet's
    note says the TCP pair was invalid). The remaining 50 are first-preference winners with nothing to distribute.
- Caveat for flow estimation: 61 sheets say "a full distribution of preferences was not undertaken". For the 50 first-preference winners that is moot.
  For 11 of the 42 seats with transfers the count stopped as soon as one candidate passed 50% with three or more candidates still in it
  (Auburn, Bankstown, Charlestown and others in `nswec-2011-nsw-checks.csv`, column `partial_distribution`). The exclusions that did happen are
  real and exact; the exclusions that would have come later are simply absent. Small parties excluded late are therefore under-represented.
- Preliminary status: Balmain's sheet is stamped "Current as at 2/04/2011"; the sheets carry the commission's declared result (footer), not necessarily a later recount.
- Party classes: Greens to GRN, Labor and Country Labor to ALP, Liberal and Nationals to LNP, Christian Democratic Party, Family First and
  Shooters and Fishers to OTH_RIGHT, other registered parties to OTH, unaffiliated to IND. Class assigned from the full party name on the FP page. One
  unaffiliated candidate per sheet is printed with no party line (Auburn); the parser records a blank party and the class is IND.
- Files: `nswec-2011-nsw-transfers.csv`, `-transfers-detail.csv`, `-countsheets.csv`, `-candidates.csv`, `-checks.csv`.
- Seat names use the commission's spelling with spaces (e.g. "Blue Mountains", "Ku-ring-gai"). Seven 2011 districts have no 2015 namesake
  (Burrinjuck, Marrickville, Menai, Murray-Darling, Murrumbidgee, Smithfield, Toongabbie), as expected from the 2013 redistribution.

## South Australia 2010 and 2014 (ECSA): not possible

- Source checked: `https://www.ecsa.sa.gov.au/elections/past-state-election-results?view=article&id=655:...` (index, saved) and the 89 district
  result pages it links (46 for 2010, 43 for 2014; all fetched, all complete). Every 2014 page has exactly two tables: first preferences and the
  final two-candidate-preferred (TCP) figures. Every 2010 page has four tables, of which two are candidate tables (first preferences, TCP);
  the rest are totals and footnotes (Port Adelaide 2010 has a differently laid out two-table page). No page contains a table with exclusions,
  transfers or counts (scan for "Excluded", "Transfer", "Distribution of preferences", "Count N" found nothing).
- Also checked and found without distributions: the 2014 House of Assembly state summary page, the ECSA document that web search returned
  as "Result of the Transfer and Distribution of Preferences" (id=568, not a House of Assembly distribution), the old ECSA publication paths for
  election reports (404), and the Wikipedia 2014 House of Assembly results page (no exclusion tables). `ecsa.sa.gov.au/election2010` redirects to a 404 page.
- Conclusion: for South Australia these are TCP-only elections as published. Writing `ecsa-2010-sa-transfers.csv` or
  `ecsa-2014-sa-transfers.csv` from the TCP table would invent rounds, so neither file was written. What exists instead: the first-preference and TCP
  tables as `ecsa-2010-sa-firstprefs-tcp.csv` (45 districts) and `ecsa-2014-sa-firstprefs-tcp.csv` (43 districts), and a per-page inventory
  `ecsa-2010-2014-sa-page-inventory.csv`.
- Gaps in what the index lists: the 2010 index lists 46 of 47 districts (Norwood is absent: article id 802 is missing from the index).
  The 2014 index lists 43 of 47: Davenport, Fisher, Frome and Giles have no `2014-state-election-results-<name>` page (Davenport and Fisher
  appear as by-election pages, Frome as a page titled 2009, Giles only as a polling-place page). Not chased, because no page has a distribution.
- The existing SA harness already takes flows from federal 2016, so no SA state transfers are assumed by the code today.
- Not tried: the ECSA's own election reports for 2010 and 2014 (URLs not found), Wayback captures of `ecsa.sa.gov.au/election2010`, and a request to ECSA.
  The Wikipedia 2022 SA results pages do carry per-seat distribution tables, so Wikipedia pages for 2010 and 2014 may too for seats where it was needed; I looked at the
  2014 page only (no match for "excluded" or "distribution of preferences"). Those would be unofficial, so not used.

## Problems and loose ends

- Penrith 2011 PDF is broken on the commission's server (76-byte pointer file); harmless for the file, see above. The script retries it each run.
- The VEC archive's pages disagree with each other in three places (Bendigo East, Kilsyth: first-count v rechecked; Morwell: the result page stops one count earlier). All
  are recorded in `vec-2006-vic-checks.csv`.
- The VEC TCP table differs from the distribution by up to 531 votes in 19 seats because the commission's TCP figures are pre-recheck.
- Distribution coverage is partial for flow estimation by construction: 49 of 88 Victorian seats and 42 of 93 NSW seats had anything to distribute.
- No existing file under `R/`, `scripts/`, `tests/` or `.github/` was changed. Nothing was committed.
