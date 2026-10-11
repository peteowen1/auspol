# Our own poll source, step 1: how much of AE Forecasts' poll file can Wikipedia replace?

Written 2026-10-11 (docs/PETE-ASKED-FOR.md, "Can polls come from our own source"). Step 1 of 2: build and measure a
Wikipedia poll source. Step 2, switching what the trend model reads, is Pete's decision and has NOT been started.
Nothing the forecast reads has changed: `external/aus-polling-analyser` is still the only input.

## The short answer

Wikipedia can replace AE's poll file for the recent elections that have a dedicated polling page, and for no others.
Over the 22 scored elections, in the final 30 days before polling day (what the forecast level reads):

- AE has 233 polls; Wikipedia has 141. 119 are the same poll in both (51% of AE's).
- Wikipedia has 17 polls AE lacks (2 of them election-day exit polls, which are not forecasts and should be dropped).
- AE has 114 polls Wikipedia lacks (101 with ALP and Coalition primaries).
- The gap is concentrated: fed2007 and fed2010 (38 of the 114), the three WA elections that only have Newspoll's quarterly
  summary (7), and the state elections whose Wikipedia article carries a handful of polls (vic2018, nsw2019, sa2022, wa2025, qld2020).
- Poll Bludger's per-poll tracker table fills two of the worst holes (nsw2019, vic2018) but nothing else: its tracker pages exist
  for only four elections (checked below).

Still live: every number here describes the data on disk today. Nothing is fixed upstream; the swap is not done.

## What was fixed in the scraper (`scripts/fetch_statewide_poll_samples.R`)

Before: 16 of the 22 elections had parsed polls; fed2007, fed2010, nsw2019 and the WA elections 2001 to 2013 had none.
After: 22 of 22 have at least one parsed poll, but fed2007 (1), wa2001 (1) and nsw2019 (1) only incidentally (see below).
The raw HTML was already cached, so the parser fixes needed no re-download; only wa2001 and wa2005 (never requested before) were fetched.

| problem | elections it hid | fix |
|---|---|---|
| Tables with no firm column; the firm is named in a footer row ("Polling conducted by Newspoll and published in The Australian") | fed2010, wa2008, wa2013, sa2010, sa2014 | firm read from the footer, recorded in a new column `firm_from` (`table_footer` or `column`); a table with no firm anywhere is still refused |
| Newspoll tables whose first header cell is blank, so there was no "Date" header to find | wa2013, sa2010, sa2014 | a blank-first-cell row reading "Primary vote / TPP vote" is taken as the header |
| "Date" label on the party row, with the "Primary vote / 2PP vote" group row above it | wa2008 | the group row is promoted to be the header |
| Newspoll quarterly rows ("Oct-Dec 2012") read as mid-December | all the Newspoll-quarterly tables | now the whole quarter (1 Oct to 31 Dec); the join compares against AE's mid-date as before |
| Party columns spelled "Lib", "Nat", "Gre" (older tables) not found by the case-sensitive lookup | fed2010 and every older table | lookup is case-insensitive |
| "March 2021" (month then year, no day) read as year-less and inferred into 2019 | nsw2023 page: a Redbridge poll landed in the nsw2019 final month | the year is carried over; tested |
| Year-less tables under a year heading ("Voting intention > 2025") were dated from the 2026 table and landed in 2027, tripping the STAT6 stop | fed2028 page, 39 rows (the run stopped after writing; now it finishes) | the year in the section heading wins |
| wa2001 and wa2005 were never requested | wa2001, wa2005 | added to the page list and election dates |

Checks: the script's own self-tests grew (quarter dates, "March 2021", the 2 - 4 Sep spacing, and three synthetic tables: headerless,
group-row-above, and the same table with the footer removed, which must be refused; all pass). Comparing old and new output for the
4,024 rows present in both: primaries unchanged in every row; 239 dates changed, all of them the fed2028 2025 table (2027 to 2025)
and two fed2022 rows ("Sep 2021" now ends on the 30th rather than the 15th).

## Elections Wikipedia cannot cover, with the evidence

All 24 dedicated "Opinion polling for the ... election" pages the scraper asked for and did not get were re-requested on 2026-10-11 and all
returned HTTP 404 (list in `external/reference/polls/statewide-samples/pages_manifest.csv`; the scraper marks any failed download as not found, so
this re-check matters). Wikipedia's own search for opinion-polling pages for fed2007, nsw2019, wa2008, wa2013 and wa2005/2001 returned no such page.
Pages that exist: fed2010 (covers 2007 to 2010), fed2013 onwards, vic2022, vic2026, nsw2027, qld2028, sa2026.

| election | what Wikipedia has | verdict |
|---|---|---|
| fed2007 | No polling table. The 2007 article has prose only. The fed2010 page's table starts after the election, plus one Newspoll (20-22 Nov 2007) | **Cannot cover.** 1 poll against AE's 234 (19 in the final 30 days) |
| fed2010 | One table: Newspoll only, fortnightly. The Roy Morgan section has no table; JWS "mega-poll" is prose | **Thin.** 66 polls against 293; 7 against 27 in the final 30 days |
| wa2001 | No polling section in the article. 1 Newspoll (7-8 Feb 2001) shows up in the wa2005 table | **Cannot cover** (1 against 44) |
| nsw2019 | No polling section at all in the article (zero mentions of any pollster). 1 poll (22 Mar 2019, Newspoll) sits in the nsw2023 article's table | **Cannot cover from Wikipedia.** Poll Bludger has 48 |
| wa2005, wa2008, wa2013 | Newspoll quarterly aggregates only (13 to 16 rows each), no individual polls and no Westpoll or others | **Thin** |
| wa2017 | One main-article table, 22 polls | Partial (16 of AE's 45 matched) |
| wa2025 | 7 polls; the last is 4 Feb 2025, polling day 8 Mar | **Thin** in the final month (0 against 2) |
| sa2022, qld2020, vic2018 | Main-article tables list a selection (5, 11, 22 polls against 11, 18, 59) | **Thin** |
| fed2013 onwards, vic2014, vic2022, nsw2023, qld2024, sa2026 | Dedicated page or full table | Usable; see the table |

The Wikipedia main-article tables for pre-2026 state elections look like editor-curated summaries, not complete lists. I could not check whether an
older revision of those articles had more rows (unconfirmed; I did not look at page histories).

## Coverage, per election, both directions

Counts of distinct polls per scored election, assigning each poll to the election whose window (previous polling day, this polling day] contains it,
not to the page it came from. "AE matched" is an AE poll the join paired with a Wikipedia row (same firm, within 4 days, ALP and Coalition primaries within 0.5).
"Wiki only" is a Wikipedia headline primary-vote poll with no AE partner; "AE only" is an AE poll with no Wikipedia partner. "Same poll, other base" counts
unmatched pairs that are the same poll once Wikipedia's undecided is removed (below); they are inside Wiki only and AE only, not extra. Final 30 days is polls
dated 30 days or fewer before polling day. Higher "matched" is better; lower "Wiki only" and "AE only" are better.

| election | Wiki polls | Wiki dates | AE polls | AE dates | AE matched | Wiki only | AE only | same poll, other base | final 30d: Wiki | AE | matched | Wiki only | AE only |
|---|---:|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fed2007 | 1 | 2007-11 to 2007-11 | 234 | 2004-10 to 2007-11 | 1 | 0 | 233 | 0 | 1 | 19 | 1 | 0 | 18 |
| fed2010 | 66 | 2008-01 to 2010-08 | 293 | 2007-12 to 2010-08 | 65 | 1 | 228 | 1 | 7 | 27 | 7 | 0 | 20 |
| fed2013 | 410 | 2010-08 to 2013-09 | 382 | 2010-08 to 2013-09 | 322 | 88 | 60 | 5 | 29 | 31 | 25 | 3 | 6 |
| fed2016 | 229 | 2013-09 to 2016-07 | 312 | 2013-09 to 2016-06 | 168 | 62 | 144 | 17 | 16 | 17 | 14 | 2 | 3 |
| fed2019 | 180 | 2016-07 to 2019-05 | 204 | 2016-07 to 2019-05 | 142 | 38 | 62 | 14 | 12 | 15 | 11 | 1 | 4 |
| fed2022 | 137 | 2019-08 to 2022-05 | 303 | 2019-06 to 2022-05 | 91 | 46 | 212 | 41 | 13 | 20 | 10 | 3 | 10 |
| fed2025 | 253 | 2022-05 to 2025-05 | 448 | 2022-05 to 2025-04 | 189 | 65 | 259 | 58 | 19 | 29 | 16 | 1 | 13 |
| wa2001 | 1 | 2001-02 to 2001-02 | 44 | 1997-05 to 2001-02 | 1 | 0 | 43 | 0 | 1 | 3 | 1 | 0 | 2 |
| wa2005 | 16 | 2001-09 to 2005-02 | 64 | 2001-04 to 2005-02 | 14 | 2 | 50 | 0 | 2 | 3 | 1 | 1 | 2 |
| wa2008 | 13 | 2005-12 to 2008-09 | 64 | 2005-04 to 2008-09 | 13 | 0 | 51 | 0 | 2 | 6 | 2 | 0 | 4 |
| wa2013 | 14 | 2009-03 to 2013-03 | 30 | 2008-09 to 2013-03 | 11 | 3 | 19 | 0 | 2 | 2 | 1 | 0 | 1 |
| wa2017 | 22 | 2013-12 to 2017-03 | 45 | 2013-11 to 2017-03 | 16 | 6 | 29 | 0 | 5 | 6 | 4 | 1 | 2 |
| wa2025 | 7 | 2023-05 to 2025-02 | 15 | 2022-02 to 2025-03 | 7 | 0 | 8 | 0 | 0 | 2 | 0 | 0 | 2 |
| vic2014 | 37 | 2010-12 to 2014-11 | 68 | 2010-12 to 2014-11 | 36 | 1 | 32 | 0 | 7 | 11 | 5 | 1 | 6 |
| vic2018 | 22 | 2015-03 to 2018-11 | 59 | 2015-01 to 2018-11 | 11 | 11 | 48 | 0 | 2 | 7 | 2 | 0 | 5 |
| vic2022 | 19 | 2020-09 to 2022-11 | 36 | 2020-04 to 2022-11 | 13 | 6 | 23 | 0 | 4 | 7 | 3 | 1 | 4 |
| nsw2019 | 1 | 2019-03 to 2019-03 | 53 | 2015-04 to 2019-03 | 1 | 0 | 52 | 0 | 1 | 4 | 1 | 0 | 3 |
| nsw2023 | 21 | 2021-03 to 2023-03 | 32 | 2020-04 to 2023-03 | 10 | 11 | 22 | 0 | 7 | 7 | 7 | 0 | 0 |
| qld2020 | 11 | 2018-02 to 2020-10 | 18 | 2017-12 to 2020-10 | 2 | 9 | 16 | 0 | 2 | 4 | 1 | 1 | 3 |
| qld2024 | 23 | 2022-02 to 2024-10 | 30 | 2022-02 to 2024-10 | 15 | 8 | 15 | 0 | 5 | 5 | 4 | 1 | 1 |
| sa2022 | 5 | 2019-03 to 2022-02 | 11 | 2019-03 to 2022-03 | 2 | 3 | 9 | 0 | 0 | 3 | 0 | 0 | 3 |
| sa2026 | 11 | 2022-09 to 2026-03 | 15 | 2022-09 to 2026-03 | 9 | 2 | 6 | 0 | 4 | 5 | 3 | 1 | 2 |
| **all 22** | **1,499** | | **2,760** | | **1,139** | **362** | **1,621** | **136** | **141** | **233** | **119** | **17** | **114** |

One AE poll is matched to at most one Wikipedia row. AE's quarterly Newspoll rows (wa, sa) are matched to Wikipedia's quarterly rows by their mid-date.

Overall, over each poll's whole cycle: Wikipedia 1,499 polls, 1,137 of them in AE (76%); AE 2,760 polls, 1,139 in Wikipedia (41%); 1,254 of AE's unmatched polls
carry ALP and Coalition primaries (the other 367 do not, e.g. Morning Consult and some Essential rows).

### Why AE polls are missing from Wikipedia (the join's own reasons, all 1,621 unmatched)

| reason | AE polls | of which final 30 days |
|---|---:|---:|
| firm is on Wikipedia but has no poll within 4 days | 636 | 76 |
| AE row has no ALP or Coalition primary to compare | 367 | 13 |
| no Wikipedia polling table covers the date | 338 | 0 |
| same firm and date on Wikipedia, but primaries differ by more than 0.5 | 197 | 12 |
| firm never appears on Wikipedia for that region | 83 | 13 |

(Final-30-day column sums to 114.) The 76 is the real gap: Wikipedia lists the firm but not that poll. In the final 30 days the missing ones are mainly
Galaxy (12), Essential (10, plus 6 with no primary), Morgan variants (28), Ipsos (9), Newspoll with an era suffix (14), Nielsen (6), Westpoll (6).

### The same poll on a different base: undecided

Of the 362 Wikipedia-only polls, 271 are Essential; 107 headline Wikipedia rows carry an undecided column (`pv_UND`; Essential fed2022 43, Essential fed2025 56, Ipsos,
ANU, DemosAU, Resolve, Dynata, Redbridge, one Essential nsw2023). AE removes undecided: Essential 35 with 7 undecided is 37.63 in AE (35 / 0.93). The join's 0.5 tolerance
therefore counts the same poll as a gap on both sides. Rescaling Wikipedia's row by 100 / (100 - UND) and allowing 1.0 point of rounding, 136 of the 362 Wikipedia-only polls
and 136 of the 1,254 AE-only polls with primaries are the same poll (fed2022 41, fed2025 58, fed2016 17, fed2019 14, fed2013 5, fed2010 1; 4 in the final 30 days). So the true
overlap is 1,139 + 136 = 1,275 AE polls, not 1,139. The rest of the 362 (226 Wikipedia polls) are genuine Wikipedia-only polls, mostly Essential and Morgan rows AE did not load.

### The final 30 days, Wikipedia polls AE lacks (17)

fed2013: Essential 12 Aug, Essential 25 Aug, Morgan multi 25 Aug. fed2016: Essential 5 Jun, 19 Jun. fed2019: YouGov-Galaxy exit poll on polling day. fed2022: Ipsos 23 Apr,
Essential 30 Apr, Ipsos 7 May (all three are the undecided case). fed2025: Essential 14 Apr (undecided case). qld2020: Roy Morgan 15 Oct. qld2024: Resolve 30 Sep. sa2026:
Resolve 16 Mar. vic2014: Roy Morgan 20 Nov. vic2022: Lonergan 6 Nov. wa2005: Newspoll 24 Feb. wa2017: Galaxy exit poll on polling day. Full list with sources:
`output/poll-coverage-wiki-only.csv`. Not all of these are checked by hand; the join tolerances can miss a real match.

### The final 30 days, AE polls Wikipedia lacks (114)

List with firm, date, primaries and the join's reason: `output/poll-coverage-ae-only.csv` (days_out <= 30). 38 of the 114 are fed2007 and fed2010 where Wikipedia has no table;
13 are fed2025, 10 fed2022. Several AE rows carry no primaries (Morning Consult, Essential, Ipsos for fed2022 and fed2025), so they cannot feed a primary-vote series
whichever source supplies them.

## Poll Bludger (only where Wikipedia has nothing)

`pollbludger.net/<election>/polltracker.htm` exists for four elections only (HTTP 200: vic2018, nsw2019, qld2017, sa2018; 404 for vic2010/2014/2022, nsw2015/2023,
qld2015/2020/2024, sa2022/2026, wa2008/2013/2017/2021/2025; fed2007 and the archive paths 404). The page draws from a public Google Sheet whose first tab lists every poll
the tracker used (date, pollster, primaries, two-party, trend columns). Fetched by `scripts/fetch_pollbludger_tracker_polls.R`; raw sheets are in
`external/reference/polls/statewide-samples/raw/pollbludger_*_sheet_gid0.csv`, parsed rows in `pollbludger_polls.csv` (every column kept).

| election | Poll Bludger polls | dates | matched to an AE poll | AE polls covered by Wikipedia or Poll Bludger | final 30d: AE polls / covered |
|---|---:|---|---:|---:|---|
| nsw2019 | 48 | 2015-08 to 2019-03 | 37 | 37 of 53 | 4 / 2 |
| vic2018 | 52 | 2015-01 to 2018-11 | 35 | 37 of 59 | 7 / 5 |

Poll Bludger's tables list Essential, Newspoll, Morgan, ReachTEL (and Galaxy for vic2018) and are missing the other houses AE records (uComms, Galaxy and Newspoll2 for nsw2019 in the
final month). Terms of use of the sheet were not checked (unconfirmed). Poll Bludger's tracker has nothing for WA, SA or Queensland 2020 onward, and federal 2007 has no page.
I did not look for other Poll Bludger pages (federal BludgerTrack, weekly posts) or for web archive copies of Wikipedia revisions.

## Swap proposal for step 2 (Pete decides; none of this is built)

**What to build.** One long poll file per region in the shape `load_polls()` returns (date, firm, tpp_published, one column per party), built from three layers with a stated precedence:
(1) Wikipedia headline statewide or national primary-vote rows (dedicated page, else main-article table); (2) Poll Bludger for nsw2019 and vic2018, where Wikipedia has 1 and 22 polls;
(3) AE kept only as a cross-check column and for the elections Wikipedia cannot cover (below), clearly marked as borrowed.

**Nationals.** The existing rules are already stated in code and carry over unchanged: `load_polls()` maps WA's `LIB FP` to LNP, and `.lr_polls()` / `level_recent_avg()` fold NAT
into LNP with `rowSums(na.rm = TRUE)`, NA only when both are missing. The scrape keeps `lnp_fp` (a combined L/NP column), `lib_fp` and `nat_fp` separately; the own file should
set coalition = `lnp_fp` if present, else `lib_fp + nat_fp` (NA nat counts as zero). Two traps seen: (a) a single merged Liberal/National cell is echoed into both columns (vic2018), flagged by
`coalition_merged` and read as the combined figure, not doubled; (b) after 23-25 Jul 2010 Newspoll's "Lib" column on the fed2010 page is already the coalition and "Nat" is "<", so adding
the two is still right; "<.5%" is stored as 0.5, which overstates the Nationals by up to 0.5 point in the old Newspoll tables.

**Undecided.** There is no written rule. The only stated expectation is `sanity_check_polls()`: first preferences should sum to 95-105 for a modern poll, which means undecided has to be
removed. AE removes it by dividing by (100 - undecided) (35 with 7 undecided becomes 37.63). Proposal: do the same on the Wikipedia rows that have an undecided column, keep the raw figure
and the undecided in their own columns, and write the rule into docs/CONSTANTS.md. Without it 107 headline rows (all the Essential rows of fed2022 and fed2025) would enter the trend about
6 points low for every party, and would look like a house effect. Unconfirmed: whether any Wikipedia table lists "undecided" under a name my search missed (I looked for UND, Undecided, Uncommitted).

**Elections Wikipedia cannot cover.** fed2007 and wa2001 (no polls), nsw2019 (Poll Bludger only, 37 of 53), and the thin ones listed above (fed2010, wa2005/2008/2013, wa2025, sa2022, qld2020,
vic2018). For these the choices are: keep AE for the backtest history and use our own source only for live and recent elections (cheapest; the backtest then still depends on AE for 8 or more of the
22 pairs); or hand-collect the missing polls from dated archive captures (CLAUDE.md "fixed pre-election sources": archive captures or wiki revisions dated before polling day, never open search).

**What to re-measure before switching (all of it reads polls).**
1. The trend: `prep_trend_obs()` uses the firm string for house effects and pools firms with fewer than 3 polls. AE labels eras ("Newspoll", "Newspoll2", "Newspoll3", "YouGov2", "ResolvePM2");
   Wikipedia does not. The house-effect structure will change. Unconfirmed: how much the level moves; this needs a run.
2. Quarterly Newspoll rows (wa2005 to wa2013, sa, older vic) are aggregates over a quarter, not polls; the trend should not treat them as one poll on one day.
3. `level_recent_decay_avg()` and the 28-day mean read the final month; Wikipedia has 141 polls there against AE's 233, and in the final month for fed2022 and fed2025 several rows
   exist only as undecided-base duplicates, so deduplicate before averaging.
4. The decay half-life (20 days, shipped 2026-10-11) was fitted on AE's poll density; refit it, or at least check it, on the thinner own file.
5. `poll_record.R`, `freshness.R`, `scorecard.R`, `byelection_prior.R`, `projection.R`, `forecast_mode.R` all call `load_polls()`; the live Victoria path should read `vic2026_opinion`
   (172 rows, sample sizes on 60 of 115 headline rows).
6. Results already measured on AE's file (for example the poll sample-weight refusal of 2026-10-09) describe AE's file only.
7. Exit polls (YouGov-Galaxy 2019, Galaxy 2017) are on Wikipedia as polls on polling day; exclude them.
Per CLAUDE.md ("a fix to one harness is a fix to all of them"), re-measure on all 22 pairs (AEF-7 screen first), not on the elections Wikipedia covers well.

## Not confirmed, and where I looked

- Whether Wikipedia's main-article tables were fuller in older revisions: not looked at (page histories).
- Whether the other 226 Wikipedia-only polls are genuine omissions by AE or join misses: the undecided rescaling explains 136 of the 362; the rest are not hand-checked.
- Every Wikipedia number comes from HTML cached 2026-10-09 (re-fetched only wa2001 and wa2005 on 2026-10-11); later edits are not seen.
- Poll Bludger's sheet terms of use and whether the same sheets stay public.
- The footnote text and sponsor of the Wikipedia rows (caveats, "commissioned by") was not audited.
- `docs/DATA-REGISTRY.md` needs no change (it lists only the top level of `polls/`). `docs/DATA-DICTIONARY.md` was regenerated for the polls/ block only; the generator reads
  these CSVs with generic column names (`V1`..) for files whose first row it mis-detects, which is a generator quirk, not a data problem.

## Reproduce

```
powershell.exe -Command 'Rscript "scripts/fetch_statewide_poll_samples.R"'     # re-parses cached HTML, no download unless a page is new
powershell.exe -Command 'Rscript "scripts/fetch_pollbludger_tracker_polls.R"'
powershell.exe -Command 'Rscript "scripts/join_statewide_poll_samples.R"'     # rewrites docs/reviews/statewide-poll-samples-2026-10-09.md; restore it with git checkout
powershell.exe -Command 'Rscript "scripts/check_poll_coverage.R"'            # writes output/poll-coverage-{by-election,wiki-only,ae-only}.csv
```
