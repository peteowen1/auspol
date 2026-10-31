# State electoral commissions: what they publish, what we hold, what it is worth (2026-10-30)

Why this matters: the federal audit found that most of what the AEC publishes sat unused. The same is true of the state commissions, and the biggest items are bigger than the federal ones: NSW publishes every single ballot's preference order (the real routing of preferences, booth by booth), and the VEC has already handed us an hourly replay of the real 2022 election night. Both were on a website, not in a model.

Scope: lower house only. Elections in the repo's pairs: Vic 2010-2022, NSW 2015-2023, Qld 2017-2024, SA 2014-2026, WA 2008-2025. Nothing below was run through a model; uses are ranked by reading files and model code, not by measurement. Items marked **UNVERIFIED** were not confirmed.

## Night-feed archives: answer per state (the question that matters most)

Table: is there a public archive of past election-night feeds with real timestamps? "Yes" means files exist that a replay could read.

| State | Archive of past night feeds? | What exists | Source |
|---|---|---|---|
| Victoria | **Partly, yes: 2022 only, hourly, already on disk.** No full 5-minute archive found. | The VEC's 2026 feed page offers a "2022 sample pack" (`sample2022.zip`) that is the real 2022 feed: 6 pm zero files, then 7 pm, 8 pm, 9 pm, 10 pm, 11 pm, 12 am, 1 am and 2 am snapshots on 26-27 Nov 2022 (file names carry the time, e.g. `..._20221126_190004`), plus three later phases (1 Dec, 8 Dec, 15 Dec). Six file types (lite, litepp, verbose, each lower and upper house). The `litepp` and `verbose` files carry votes per polling place and `VotesByType` (Ordinary, Postal, Early, MarkedAsVoted, Provisional, Absent). Booths returned grow 187 (7 pm) to 886 (8 pm) to 1,404 (9 pm). | Downloaded 2026-10-28 into `external/reference/vec/2026/feed-docs/inner22/` (777 files, 200 MB). Page: https://www.vec.vic.gov.au/about-us/media/2026-results-data-feed. Nothing in `R/` or `scripts/` reads these snapshots yet (grep for `inner22` finds only `fetch_vec_candidates.R`). |
| NSW | **No.** | The NSWEC feed is XML in 5-minute extracts on an access-restricted FTP site that needs a static IP and a signed terms-of-use; registration per election. The user guide (fetched) describes the files but no public archive of 2019 or 2023 extracts was found. | https://elections.nsw.gov.au/media/election-results-feed ; guide saved at `external/reference/nswec/media-feed/nswec-state-and-local-election-media-feeds.pdf`. Not an archive: **UNVERIFIED that none exists behind the login** (we do not log in). |
| Queensland | **No (final file only).** | `resultsdata.elections.qld.gov.au/elections.json` lists every event with one `archiveXML` link, the final data file, generated well after polling day. There is an ECQ "XML Feed Overview" PDF for media, but the ECQ server returned 403 to our fetch, so it is **UNVERIFIED** what it says. Not worked around. | `external/reference/ecq/state-fetch/elections.json` |
| South Australia | **No.** | The results API answers any version number with the one current state (`HAChange/{date}/{n}`: versions 0, 1, 5, 90, 91, 92 and -1 returned identical bytes; `dataVersion` is 91 for the 2026 election in the first copy and 908 in the copy fetched today, so the data is revised in place). No history or version-list endpoint (404). 2018 and 2014 return 204 (no data in the API). | Tested 2026-10-30. |
| Western Australia | **No.** | The API keeps one `LatestVersionDate` per election (e.g. 2025-08-05). The `timeline` endpoint is the list of dates for key events (postal votes open and so on), not a count history. | `external/reference/waec/state-fetch/sg2025/api/timeline.json` |

Also searched: Wayback CDX for VEC media-feed or `mediafile` URLs returned nothing (one query returned 503, so **partly UNVERIFIED**). So for a real-reporting-time replay: Victoria 2022 is the only one, and the hourly pack is what we have. The 2026 sample pack and trial (25 Nov) are the only other timestamped Victorian data before polling day.

## Fetch summary

Script: `scripts/fetch_state_commissions.py` (one request at a time, 1 s pause, browser-like user agent, skips what is on disk, every request logged to `external/reference/state-commissions-fetch-log.csv`; 1,532 log rows). Originals are byte for byte. Layout: `external/reference/<commission>/...`; the VEC full-preference-distribution files keep the VEC's own hashed names (district name is in the log's note column).

Table: files and size on disk per commission from this fetch (MB rounded; "not found" counts genuine server 404/204 only).

| Commission | Files | MB | Not found / blocked |
|---|---|---|---|
| VEC (`vec/state-pages`, `vec/2022/...`, `vec/2018/files`, `vec/2014/files`, `vec/historical-files`) | 258 | about 11 | none from the server. Upper-house/region files and the 2018 group voting ticket PDFs were deliberately skipped (out of scope). |
| NSWEC (`nswec/SG2301`, `SG1901`, `SGE2015`, `media-feed`, `state-pages`) | 769 successful requests | 142 (of which about 125 is ballot-level preference data) | 1 transient 522 (Heffron 2015), succeeded on retry. **My bug, fixed:** 93 NSW 2019 zip requests got 404 because the script double-encoded the URL; rerun fetched all 93. Those 94 rows remain in the log as 404. |
| ECQ (`ecq/state-fetch`) | 7 | 4 | 1 page 404 (`ecq.qld.gov.au/.../election-results`, my guessed URL). The ECQ XML-feed PDF returned 403 and was not retried with other headers. |
| ECSA (`ecsa/state-fetch`) | 10 | 4 | 2018 and 2014 API calls return 204 (no data). Two "Enrolment by age" CSVs are statewide only (7 rows). |
| WAEC (`waec/state-fetch`) | 391 | 16 | none |

Total about 177 MB, far under the 1 GB line. Nothing is behind a form or login that we tried to bypass. Nothing was parsed or loaded into a model; two NSW zips, one VEC xls and a few JSON files were opened for headers only.

## Inventory

Cells: "HAVE" = raw copy already on disk before this task (path given); "NEW" = fetched today (path under `external/reference/`); "-" = the commission does not offer it for that state (or not found); "USED" names the script that reads it; "unused" means grep of `R/` and `scripts/` found no reader (by file name; a path built in pieces would be missed).

### VEC (Victoria)

| Data product | Elections | Status |
|---|---|---|
| First preferences by voting centre (per-district `Results by Voting Centre`) | 2022 (HTML pages HAVE `vec/2022/booths/`; the VEC's own `.xls` NEW `vec/2022/state-reports/`, 93 files, includes district totals by vote type: "Total Declaration Votes", "TOTAL ALL VOTE TYPES"); 2018 HAVE `vec/2018/booths/`; 2014, 2010 HAVE as district HTML | USED: `output/booths-vic2022.csv`, `booths-vic2018.csv` (via `fetch_booths_vic2022.R`). The `.xls` adds the district vote-type rows: unused |
| 2CP by voting centre | 2022, 2018 HAVE (`*-2cp.html`) | USED: `booths-vic20xx-2cp.csv` |
| Distribution of preferences by district | 2010, 2014, 2018, 2022 HAVE (`dop-*.html`, `dist-*.html`; `output` transfers `vec-20xx-vic-transfers.csv`). 2022 full distributions for 39 districts NEW `vec/2022/full-preference-distributions/` (40 files) | USED: `fetch_preferences_vic*.R`. The VEC xls versions: unused |
| Statewide preference flow by party (the state version of the AEC's `TppFlowByParty`) | **Not published.** The VEC publishes no flow-by-party table. It can be computed from the district distributions (exclusion-by-exclusion transfers by party), which is what `vec-20xx-vic-transfers.csv` already holds | See item 3 below |
| 2PP/2CP all districts | 2022 NEW `vec/2022/files/a8466a1794024583a2128ed431ca24f3.xlsx`; 2018 NEW `vec/2018/files/2ppvote2018.xlsx` and `-final.xlsx`; 2014 NEW `vec/2014/files/2ppvote2014.xls` | unused (`vec-2002-vic-tcp.csv` etc. come from elsewhere) |
| Vote type counts (ordinary, early, postal, absent, provisional) | Only inside the Results-by-VC xls totals (2022) and the night-feed `VotesByType` (2022 sample pack). No separate declaration-votes-issued/received table | unused |
| Enrolment, turnout, informal by district | Turnout and informal rates statewide on the statistics page (NEW `vec/state-pages/results_electoral-statistics_state-election-statistics.html`: turnout 87.13% in 2022, informal 5.53%, candidates 1,194). District enrolment is in the xls header (`ENROLMENT:`) | unused |
| Voting centre locations (lat/long) | 2022 HAVE `vec/2022/voting-centre-locations-2022.xlsx` | partly (booth lat/lon in night plan) |
| Candidate lists | 2022 HAVE `vec-candidates-2022.csv`, `State2022MediaFileCandidates.xml`; all years via `candidacies.csv` | USED |
| Elected members lower house | 2010 NEW `vec/historical-files/2010_state_election-elected_members_lower_house.xls/.xml`; others HAVE as winners CSVs | USED (winners) |
| By-election distributions | Broadmeadows and Niddrie NEW `vec/historical-files/` | unused |
| Night-feed archive | 2022 hourly sample pack HAVE `vec/2026/feed-docs/` (see above); 2026 sample (test data) HAVE | read by `R/night_runner.R` fixtures only; the real 2022 timeline is unused |

### NSWEC

| Data product | Elections | Status |
|---|---|---|
| Final first preferences by venue and candidate (state-wide spreadsheet) | 2015, 2019, 2023 HAVE `nsw/sge20xx-la-final-votes.xlsx` | USED: `parse_booths_nsw_qld.py`, `output/booths-nsw2019.csv`, `booths-nsw2023.csv` (vote type PP, PR, DI) |
| 2CP by polling place | 2023 HAVE `nsw/tallyroom-NSW-2023-LA-2CP-Pollingplace.xlsx`; per-district TCP pages 2019, 2023 NEW `nswec/SG1901/tcp/`, `SG2301/tcp/` (93 each) | 2023 USED; per-district TCP pages unused |
| Distribution of preferences by district | 2015, 2019, 2023 HAVE (`nsw/dop/SG*.html`, `nswec-nsw-transfers.csv`) | USED: `fetch_transfers_nsw.R` |
| **Ballot-level preference markings, every district** (columns District, PollingPlaceName, BPNumber, Formality, CandidateName, PrefMarking, PrefCounted) | 2015 NEW `nswec/SGE2015/preferences/` (93 zips), 2019 NEW `nswec/SG1901/preferences/` (93), 2023 NEW `nswec/SG2301/preferences/` (93). Albury 2023 alone is 7.1 MB unzipped. | **unused.** `scripts/measure_nsw_flows.R` line 261 says "the real routing needs ballot-level data we do not hold". We now hold it. |
| Preference pages (explainer, counts) | NEW `nswec/*/preferences-pages/` | low |
| Turnout and informality by district; party formal vote; elected | 2019, 2023 NEW `nswec/SG*/LA-state-turnout.html`, `LA-state-formal.html`, `LA-state-elected.html`; 2015 `la-state-formal/turnout/tpp/tcp.htm` NEW | unused |
| Voting centres, early voting centres, declared facilities (names, addresses) | 2023 NEW `nswec/SG2301/*.xlsx` (3 files); coordinates: `tallyroom-NSW-2023-Pollingplaces.xlsx` HAVE | partly |
| Count status (progress by district and day) | 2019, 2023 NEW `LA-status.html` | unused, final state only |
| Declaration votes issued/received | **Not found** on the VTR. NSWEC publishes "election daily metrics" for postal votes (per press, **UNVERIFIED**; not located) | - |
| Night feed | Restricted FTP (above) | - |

### ECQ (Queensland)

| Data product | Elections | Status |
|---|---|---|
| Public results XML: first preferences and TCP by booth, vote-type pseudo-booths (Postal Declaration Votes, In Person Declaration Votes, Absent, Absent Early, Telephone Voting, Mobile Polling, Early Voting Centres), booth coordinates (1,339 booths), full distribution of preferences by district | 2017 HAVE `ecq/qld2017.xml`, `ecq/raw/2017/`; 2020 HAVE `qld2020.xml`; 2024 HAVE `qld2024.xml` (and NEW identical `ecq/state-fetch/2024/`, 2020 likewise) | USED: `parse_booths_nsw_qld.py` (vote types), `fetch_preferences_qld.R`, `booths-qld20xx*.csv` |
| Electorate and venue JSON (`*-electorates.json`, `*-boundary_venues.json`) | 2020, 2024 NEW `ecq/state-fetch/` | unused; low |
| Event index with flags (`indicativeCount`, `preferenceDetailsBooth`, `archiveXML`) | NEW `ecq/state-fetch/elections.json` (a copy exists in `ecq/elections.json`) | HAVE |
| Distribution of preferences | 2020, 2024 in the XML; none for 2017 (optional preferential until 2016, so none in the 2017 file) | USED for 2020/2024 |
| Declaration votes issued/received, enrolment, turnout by vote type | Not offered in the public files (enrolment per district only on the ECQ website, which returned 403/404 to our requests) | **UNVERIFIED** |
| Night feed | Media XML feed per the ECQ PDF (not read, 403) | - |

### ECSA (South Australia)

| Data product | Elections | Status |
|---|---|---|
| Results API: first preferences by polling place and declaration type, TCP and TPP, informal, enrolment per district | 2022 HAVE `ecsa/ha-change-2022-03-19.json`; 2026 HAVE (older, 2,338,425 bytes, lastUpdated 2026-05-04) and NEW `ecsa/state-fetch/2026-03-21/` (2,340,754 bytes, lastUpdated 2026-09-21): the figures were revised after our copy. Not diffed: **UNVERIFIED how much changed**. 2018-03-17 HAVE file is 0 bytes; the API now returns 204 for 2018 and 2014 | USED: `parse_booths_sa_wa.py`, `fetch_sa2026.py` |
| 2018 and 2014 results pages (district and polling place HTML) | HAVE `ecsa/2018/` (95), `ecsa/raw/2014/` (49) | USED |
| **Daily tally: issued and returned postal votes, and early-vote mark-off numbers, per district per day** (2026, 14-20 March) | 2026 NEW `ecsa/state-fetch/se2026-daily-tally.html` (table text seen, not parsed). The state version of the AEC's declaration votes issued/received. Whether 2022's equivalent is archived: **UNVERIFIED** | unused |
| Statewide enrolment by age | NEW two CSVs, 7 rows each | low |
| Polling place coordinates | The static API returns `coordinates: null` for most places in the file we hold | **UNVERIFIED** how many are filled |
| Night feed | none | - |

### WAEC (Western Australia)

| Data product | Elections | Status |
|---|---|---|
| Per-district results JSON (first preferences, 2CP, full distribution of preferences, per-polling-place breakdown including absent and count-centre groups, `Percent_Counted`) | 1996-2025 HAVE `waec/sgYYYY-*.json` (941 files) | USED: `fetch_preferences_wa.R`, `parse_booths_sa_wa.py` |
| `LAVoteSummary` (district enrolment, formal, informal, % counted), `LAResultsByParty`, `LAElectedMembers`, `list`, `timeline` | 2008, 2013, 2017, 2021, 2025 NEW `waec/state-fetch/sgYYYY/api/` | unused (enrolment/informal also inside the district JSON `toptotals`, which is USED) |
| Early polling places and early "other" places, and per-district polling place lists | 2008-2025 NEW `waec/state-fetch/sgYYYY/api/pollingPlacesEarly.json`, `pollingPlacesEarlyOther.json`, `pollingPlaces/<DIST>.json` (295 files). The early-place file has venue names, addresses and contact; lat/long **UNVERIFIED** | unused |
| State enrolment by age and habitation | NEW `STATE_statistics.json` | low |
| **Daily early-voting statistics PDFs by day and by district, and returned postal votes and postal application statistics by day** | 2021 NEW `waec/state-fetch/2021-stats/` (42 PDFs: early voting by centre and by district, postal returned 14, postal applications 9); 2025 NEW `waec/state-fetch/2025-stats/` (10 daily early-voting PDFs, 24 Feb-7 Mar 2025). 2025 postal-vote series: not found on the pages (**UNVERIFIED**). 2017, 2013, 2008: not found | unused; PDFs not parsed |
| Enrolment statistics by SA1 (district) | Listed on the WAEC reports page (page saved; the xlsx for 30 Sep 2026 not fetched; out of scope: not an election in the pairs) | - |
| Night feed | none found | - |

## Ranked uses (top 10 first)

Value: high = changes a number we publish or fixes a known weakness; medium = tightens something; low = context. "Already computed?" says what in the repo overlaps.

### Top 10

1. **Real 2022 election-night timeline (VEC hourly sample pack): replay the night on actual reporting times.** Pre-election: no. Night: high. The booth-order and booth-count assumptions in the current replays are synthetic; here are 9 real snapshots from 6 pm to 2 am with booths returned per district, votes by type, and the 2CP appearing and being withheld. It tests the exact question the model must answer on 28 Nov: after 187 of 1,729 booths, how wrong is the seat call, and does it beat the prior? Already computed? `R/night_runner.R` and the `SE26...` fixture read the feed format; the 2022 hourly snapshots are not used in a replay. Cost: a parser pass (the 2022 files have the same schema as 2026 apart from vote types) and a replay script. Also the only evidence for how fast postals and early votes arrive.
2. **NSW ballot-level preference markings, 2015/2019/2023 (279 zips, 125 MB).** Forecast: high. This is the true routing of every preference, by polling place, for all 93 seats: the flow table for any party to any final-two pair, with real sample sizes, instead of the exclusion-by-exclusion aggregate. It answers the question the NSW harness could not (`measure_nsw_flows.R` line 261). It gives exhausted-ballot rates under optional preferential voting (NSW is OPV, which the federal-flow stand-in cannot show), which matters for Queensland-style seats too. Night: medium (final-two probabilities by pair). Already computed? No; NSW flows come from district-level exclusion tables.
3. **State preference flow by party for Victoria.** The VEC publishes none. It can be computed, not downloaded: the 2022 (88 districts), 2018, 2014, 2010 distributions already in `vec-20xx-vic-transfers.csv` give exclusion-by-exclusion transfers; the 39 full distributions fetched today (2022, including seats decided on first preferences, where the VEC ran an information-only count) add Greens exclusions in safe seats, which the official counts never needed. Forecast: high for the live election, since the Victorian Greens flow currently rests on hand-copied federal figures. Check first what the existing transfers files already give (grep `build_aec_tpp_flows.R` for the Victorian path) before building. Already computed? Partly (transfers files); a party-to-party flow summary for Victoria from them is not shown as a table anywhere I found: **UNVERIFIED**.
4. **Vote-type splits for the night: Victoria, Queensland, SA, NSW.** Night: high. ECQ XML (2017/2020/2024), the SA API (declaration blocks), NSW venue types (PP/PR/DI) and the VEC 2022 `VotesByType` all separate ordinary from early, postal, absent and declaration votes. The booth builder already carries these for NSW, Qld and SA; VEC 2022 gives only a district-level split, no per-booth type. The postal and early lean per party and state, combined with item 1's timing, sets how the count should drift after the early booths. Already computed? Yes for booth tables; no party-lean-by-type summary for state elections.
5. **Postal votes issued and returned, early voting counts by day (SA 2026 daily tally, WA 2021 and 2025 PDFs).** Night: high-medium. These are the state versions of the AEC's declaration votes issued/received: they size the votes still to come after the night, by district. Victoria publishes nothing equivalent that I found (UNVERIFIED), so this is a calibration source only: how large the late postal and early tail is relative to enrolment in SA and WA. Needs PDF/HTML parsing. Forecast: low.
6. **VEC district results by voting centre `.xls` with district vote-type totals (2022), plus 2018 district xlsx.** Night: medium. The totals row "Total Declaration Votes" vs ordinary gives, per district, the final share of the count that arrives after the night, the missing denominator for % counted in Victoria. Forecast: low. Already computed? The booth CSVs drop these totals (booth rows only).
7. **Full preference distributions for 39 Victorian 2022 districts (information-only counts).** Forecast: medium. Safe-seat Greens/other exclusions give flow information the 49 official distributions lack; see item 3. Night: none.
8. **Booth/venue lists with coordinates across states (NSW 2023 venue xlsx, WA early places, ECQ boundary venues, VEC voting centres 2022).** Forecast and night: medium. Nearest-booth matching across redistributions and demographic joins; for the night, matching 2026 early voting centres (new in 2026) to anything at all. Already computed? Name matching only.
9. **Informal and turnout by district (NSW formal/turnout pages, WA `LAVoteSummary`, VEC statistics page, SA informal in API).** Forecast: medium. Informal-rate swing flags ballot-paper changes; turnout (87.13% in 2022 vs 90.16% in 2018 in Victoria) is a driver of the vote total. Night: expected total votes. Already computed? Informal rows dropped at parse.
10. **VEC elected-members, 2PP-all-districts files and by-election distributions (2010, 2018, 2022).** Low-medium. Cross-check of our own winner and 2CP tables, which catches a scoring-set error cheaply.

### The rest

Table: value for each remaining item; "pre / night" are forecast and night-model value.

| Item | Pre / night | Value |
|---|---|---|
| NSW per-district TCP pages (2019, 2023), count status, party formal vote | low / low | low |
| ECQ electorate and boundary-venue JSON | low / low | low |
| ECSA revised 2026 API copy (lastUpdated 2026-09-21 vs 2026-05-04) | medium / low: our SA 2026 numbers may be stale | medium; diff the two copies before trusting any SA 2026 figure |
| WAEC `LAResultsByParty`, `LAElectedMembers`, `list`, `timeline` | low / low | low |
| Statewide enrolment by age (SA, WA) | low / low | low |
| NSW 2023 state election report (PDF) | low / low | low |
| VEC statistics page (candidates per election since 1992) | low / low | low |

## Things to check before relying on any of this

- Nothing was loaded into a model or parsed; sizes and layouts come from headers, file names and a few first rows. Check `nrow`, date range and key uniqueness on first load.
- The NSW 2019 zips carry two different internal names (`SGE2019 ...zip` containing `SG1901 LA Pref Data_NA_Albury.txt`); the 2015 zips use `_NA_` in the file name. Read by directory, not by assumed name.
- The ECSA 2026 file on disk before today is older than the live API. The district count and vote totals may differ; the SA 2026 booth CSVs may describe the older copy.
- `docs/DATA-REGISTRY.md` and `docs/DATA-DICTIONARY.md` were regenerated (`DR9`, `DD9` ran clean) but their scan lists do not include the new folders (`nswec/SG*`, `waec/state-fetch`, `ecsa/state-fetch`, `ecq/state-fetch`, `vec/2022/state-reports`, `vec/2022/full-preference-distributions`, `vec/*/files`, `vec/historical-files`), so they do not mention today's fetch. The scripts live in `scripts/` (not edited here). The authoritative list is `state-commissions-fetch-log.csv`.
- No requests were made behind logins. The two blocked items (ECQ XML Feed Overview PDF, `www.ecq.qld.gov.au` pages) were left alone.
- Reproduce: `python scripts/fetch_state_commissions.py [vec nswec ecq ecsa waec]` (skips files on disk).
