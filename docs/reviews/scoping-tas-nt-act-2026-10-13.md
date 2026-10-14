# Scoping: Tasmania, Northern Territory, ACT (2026-10-13)

Track C of `docs/plans/coverage-program-2026-10-13.md`. Research only; no code touched. Verification key:
**[V]** = fetched live this session (URL given), **[M]** = from memory, not checked, **[S]** = web-search snippet only.
Several official sites blocked or 404'd the fetcher (NTEC 403, parts of TEC 404), so the data sections say what could
not be confirmed.

## Summary

Column notes: "polls per cycle" is statewide voting-intention polls found in the Wikipedia table for the most recent
cycle(s) I could open (n given); more is better. Effort is relative to the existing single-member IRV path.

| Jurisdiction | System | Elections since 2000 | Results data quality | Polls per cycle | Model work | Effort | Recommendation |
|---|---|---|---|---|---|---|---|
| NT | 25 single-member, IRV; full preferential except 2016 (optional) | 7 (2001, 2005, 2008, 2012, 2016, 2020, 2024) [M dates] | First prefs by division confirmed for 2016 and 2024 pages; preference distributions published for 2024 (format unconfirmed, NTEC 403) | 2020: 5 statewide + 5 seat polls; 2024: 2 statewide (Redbridge, Freshwater) [V] | Existing path fits; a 25-seat, ~5,000-voter-per-seat variant, CLP not LNP, many independents | Small to medium | Do first of the three, but treat as a low-value demo: poll trend is nearly empty |
| ACT | Hare-Clark, 5 electorates x 5 members (25) since 2016; earlier 17 members in 3 electorates | 7 (2001, 2004, 2008, 2012, 2016, 2020, 2024) [M dates] | Best of the three: every-ballot preference files for 2001, 2004, 2008?, 2012?, 2016, 2020, 2024 (2024 [V], 2016/2020 [S]) as text files | 2020: 2 [V]; 2024: not found (polling page 404'd), likely 0 to 3 | New multi-member STV simulator; ballot-level files make flows and within-party splits estimable | Large | Do second, only after the Hare-Clark engine exists; poll scarcity limits what a forecast could say |
| Tas | Hare-Clark, 5 divisions x 5 members (25) to 2024; x 7 members (35) from 2025 | 8 (2002, 2006, 2010, 2014, 2018, 2021, 2024, 2025) [years V, dates M] | 2025: XLSX first prefs by polling place + count export per division [V]; older years mostly PDF scrutiny sheets; no per-ballot file found | 2018-21 cycle: 15 (14 EMRS + 1 uComms); 2024-25 cycle: 15 (10 EMRS, 2 YouGov, 2 DemosAU, 1 Wolf & Smith) [V] | Same Hare-Clark engine as ACT, plus a 25-to-35 seat discontinuity | Large (shares the engine with ACT) | Do third, together with ACT; best polling of the three, so best value once the engine exists |

Order recommended: NT (small) -> build one Hare-Clark engine -> ACT (best data) -> Tas (best polls, worst historical data).
If only one is done, NT, because it reuses the existing model; if the site wants "all jurisdictions" coverage, the
Hare-Clark engine is the real project and should be scoped as one piece of work serving two jurisdictions.

## What in the current model is reusable

Read from `ARCHITECTURE.md` and the file list in `R/` [V].

Reusable for all three:
- Poll loading and the statewide trend (`load_polls`, `fit_trend` / `trend_as_at`, `forecast_statewide`, house effects).
  Per-party latent share with an exact posterior; nothing in it assumes a state. It needs a party list per jurisdiction
  (`R/parties.R`, `R/wa_party.R` show the per-state pattern; the others would need the same).
- Fundamentals / projection (`fundamentals.R`, `projection.R`): previous result, incumbency, federal alignment. With only
  7 to 8 elections per jurisdiction the fitted weights will be near the prior (shrinkage is the stated house rule).
- The statewide-to-seat step conceptually: `dev_slope()` (swing a party's seat vote by the statewide change), personal
  incumbency (`personal_prior_vote`, `sitting_member.R`), correlated statewide draws via Cholesky, seat noise.
- Scoring tools: `scripts/pool_backtests.R` log-loss style reporting, `quick_arm.R` screening, election-dates registry
  (`election_dates.R`).

Reusable only for NT (single-member IRV):
- `build_flow_matrix()` transfer rates keyed on excluded party and who remains; `simulate_seat_contests()` and
  `src/seat_sim_core.cpp` (exclude lowest, distribute, repeat to final two); XGB primary and flow layers (but see the
  training-size problem below).

New for Tas and ACT: everything from "seat primaries" onward. The IRV loop cannot elect more than one winner per
electorate, and the whole candidate-level machinery (flows between parties, TCP, "winner = higher of last two") is
a single-winner construct.

## Tasmania

**System.** House of Assembly, Hare-Clark. 2025 article [V, en.wikipedia.org/wiki/2025_Tasmanian_state_election]: 35 members, five divisions (Bass, Braddon,
Clark, Franklin, Lyons), seven each; size set by the *Expansion of House of Assembly Act 2022* (assent December 2022).
TEC 2025 pages [V] confirm "7 to be elected" for Clark. The 25 -> 35 history is **only partly verified**: from memory, the House was
35 members (7 x 5) until 1998, cut to 25 (5 x 5) from the 1998 election, and restored to 35 for the 2025 election. The Wikipedia
page did not state the earlier sizes; treat "25 for 2002-2024" as [M] but very likely. Robson rotation, ballot formal with at
least 5 preferences [S, ecanz.gov.au/node/24]; 5-preference minimum means exhausted ballots are common.

**Elections since 2000.** Years [V from Wikipedia list]: 2002, 2006, 2010, 2014, 2018, 2021, 2024, 19 July 2025. Exact dates [M]:
20 Jul 2002, 18 Mar 2006, 20 Mar 2010, 15 Mar 2014, 3 Mar 2018, 1 May 2021, 23 Mar 2024. Eight elections; seven are 25-seat
and one (2025) is 35-seat.

**Results data.**
- TEC site `https://www.tec.tas.gov.au/house-of-assembly/elections-2025/` [S/V]. Per division results page
  (e.g. `.../results/clark/index.html` [V]) offers: a PDF "further details of the count" (`pdf/2025-ha-clark-export-count-47.pdf`),
  an XLSX "Export Count 47" (the count-by-count Hare-Clark distribution is very likely inside, **unconfirmed**; I did not open
  the XLSX), and one statewide XLSX `downloads/2025-state-election-first-preferences-by-polling-places.xlsx` (first preferences by
  polling place, 87 KB for Clark per search snippet).
- 2024: the election page lists results pages per division and writs only [V]; no data download found on the overview page.
- Older: the TEC "House of Assembly Elections" index [V] lists mainly PDF scrutiny sheets for recounts (2015-2023) and links
  election pages for 2014, 2018, 2021, 2024. Format for older first-preference tables unconfirmed (probably PDF/HTML).
- No per-ballot preference file found. **Unverified whether one exists**; Tasmania historically publishes the Hare-Clark
  count by candidate (distribution of preferences) rather than every ballot. Not searched: Tasmanian Parliamentary Library,
  PRSA (`prsa.org.au`) archives, Kevin Bonham's tallyroom-style pages, and the Australian Election Database at UWA
  (`research-repository.uwa.edu.au` dataset "Australian Election Database Tasmania lower house", seen in search results [S]). All three
  are the likely route for 2002-2021 candidate first preferences.
- Annual report PDF has division first-preference tables [S]: `tec.tas.gov.au/info/Publications/ElectionReports/Report_on_Parliamentary_Elections_2024-2025_w.pdf`.

**Polls.**
- 2018-21 cycle: 15 polls, 14 EMRS and 1 uComms [V, 2021 election article].
- 2024-25 cycle: 15 polls, EMRS 10, YouGov 2, DemosAU 2, Wolf & Smith 1; fieldwork May 2024 to July 2025 [V,
  en.wikipedia.org/wiki/Opinion_polling_for_the_2025_Tasmanian_state_election].
- 2024 election has a separate polling page URL that 404'd under the title I guessed; its polls are probably in the 2024 article. Earlier cycles
  (2002-2014) not checked; EMRS has polled quarterly for decades so expect 10 to 20 per cycle [M]. PRSA lists poll reports at
  `prsa.org.au/tas_poll_reports.html` [S].
- Tas is the only one of the three with enough polls for the existing trend model to behave as designed. Statewide only; no
  division polls found.

**What a model needs.** See the Hare-Clark section below. Tasmania-specific: the 2025 expansion means the 2025 and later cycles
are 7-member and all earlier are 5-member; quota is 1/6 (16.7%) then 1/8 (12.5%). A 7-seat division gives minor parties and
independents far more chance (2025: 5 independents elected [V, Wikipedia: Liberal 14, Labor 10, Greens 5, independents 5, 35
total]) and the 5-member history cannot be used to calibrate that. Party tickets are loose: Tasmanian voters vote
for candidates and within-party order matters a lot (e.g. big-name candidates carry the ticket), so within-party splits are first-order.

## ACT

**System.** 25-member Assembly, Hare-Clark, five electorates (Brindabella, Ginninderra, Kurrajong, Murrumbidgee, Yerrabi) of five
members each [V, 2024 election article]. From memory: 25 members / 5x5 since 2016; before that 17 members in three
electorates (Brindabella 5, Ginninderra 5, Molonglo 7) from 1995 on, with the 1989-92 assembly also 17 [M]. The page did not state this.
Quota 1/6 = 16.7%. Elections since 2000 [M dates]: 20 Oct 2001, 16 Oct 2004, 18 Oct 2008, 20 Oct 2012, 15 Oct 2016 [V, from
Elections ACT snippet: 15 October 2016], 17 Oct 2020, 19 Oct 2024. Seven elections. Elections ACT lists all of these under
`elections.act.gov.au/elections/previous-assembly-elections/{year}-election` [V, index page links 1989 to 2024].
2024 result [V]: Labor 10, Liberal 9, Greens 4, Independents for Canberra 1, Fiona Carrick Independent 1.

**Results data (best of the three).**
- Ballot-paper preference data (every formal ballot, from the electronic voting and counting system) as plain text files:
  - 2024 [V, `.../2024-election/ballot-paper-preference-data`]: Data description PDF; BallotPaperVersions.txt 5.4 MB;
    candidates.txt; Electorates.txt; Groups.txt; PollingPlaceBatchNumbers.txt 38 KB; one `{Electorate}Total.txt` per electorate,
    9 to 10.7 MB each. File links resolve under `elections.act.gov.au/__data/assets/text_file/...`. Field layout is in the PDF,
    which I did not open.
  - 2020 and 2016 [S: search snippets quoting "Ballot paper preference data - 2020 Election", updated 19 Nov 2020; "- 2016 Election", updated
    9 Nov 2016]. The old-style URLs (`/elections_and_voting/2020_legislative_assembly_election/...`) returned 404 to me, so
    the pages moved; re-find them from the 2020 and 2016 election pages.
  - 2008 and 2004 [S]: a "Ballot paper preference data" page exists for 2008 and 2004 (2004 is an "older dataset in the same
    format"); 2012 is listed in menus [S]; 2001 has a "voting data 2001 election" page [S]. None opened. Treat as likely but unverified.
- Distribution of preferences (count sheets): 2024 Table 1 (ballot papers) and Table 2 (votes) per electorate, XLSX and PDF
  [V, `.../2024-election/distribution-of-preferences-2024/table1_{Electorate}-FINAL.xlsx`]; 2008, 2012, 2016 have their own
  distribution pages [V links found].
- Polling-place results: 2004 first preferences by polling place XLS [V link
  `.../__data/assets/excel_doc/0009/2508777/2004-first-preferences-by-polling-place.xls`]; 2008 and 2012 results by electorate and party; no
  2024 results by polling place link on the distribution page [V].
- Licence not checked. Per-ballot data means a Hare-Clark flow model can be fitted from first principles rather than
  from published count sheets, which is better than anything available for Tasmania or the Senate.

**Polls.** Sparse. 2020: 2 (ClubsACT Sept 2020, uComms Aug 2020) [V]. 2024: unverified (the guessed polling URL 404'd and the 2024 election article was not opened for polls). Earlier cycles unchecked. Expect 0 to 3 polls per cycle; the trend would be nearly all prior and fundamentals.

## Northern Territory

**System.** 25 single-member electorates [V], instant-runoff. Full preferential before 2016; optional preferential for the 2016
election only (Electoral Legislation 2016 reform by the Giles CLP government); full preferential restored from 2020
(Electoral Legislation Amendment Act 2019, April 2019) [V via search summary of NTEC, APH and NT Parliament documents]. So 2016 is
a different count rule: ballots exhaust, and the existing flow matrix (built on full-preferential flows) is wrong for it. Elections since
2000 [M dates]: 18 Aug 2001, 18 Jun 2005, 9 Aug 2008, 25 Aug 2012, 27 Aug 2016, 22 Aug 2020, 24 Aug 2024. Seven elections. Note that 2012
and 2016 each had a large swing (CLP government 2012-16, Labor landslide 2016, CLP landslide 2024: 17 CLP, 4 Labor, 3 independents,
1 Greens [V]), which is the point: this is a volatile system with very small electorates (roughly 5,000 voters per seat [M]; 101,741 valid votes in
2024 [S] over 25 seats is ~4,070 per seat).

**Results data.** NTEC site returned 403 to the fetcher, so listings are from search results [S]:
- `ntec.nt.gov.au/elections/current-elections/2024-territory-election/results/nt-summary-of-first-preference-votes-by-division` (2024) and the
  equivalent under `.../past-elections/legislative-assembly/2016-territory-election/results/...` (2016): first preferences by division with
  party columns ALP, CLP, Greens, independents, formal, informal, roll and turnout. HTML tables.
- Distribution of preferences for 2024 published (media release "2024 territory election distribution of preferences concludes";
  Poll Bludger treated it as the final result) [S]. File format and URL not confirmed.
- Booth-level results and the other years: not confirmed. The NTEC past-elections index could not be opened. The Wikipedia
  results article for 2024 is a fallback for division totals [V]. Another route is the Australian Election Database.
- **Open item:** someone needs to open the NTEC pages in a browser (the fetcher is blocked) and list files per election.

**Polls.** Very thin. 2020 cycle [V, Wikipedia]: 5 statewide polls (MediaReach 3, uComms 1, one Labor-commissioned) and 5 seat polls (all MediaReach,
Araluen, Braitling, Blain, Johnston, Mulka), plus 3 preferred-chief-minister polls. 2024 cycle: 2 statewide polls on the 2024 NT article [V: Redbridge 16-18 Nov 2023, Freshwater Strategy May 2024], no seat polls. Poll Bludger covers NT elections (`pollbludger.net/category/northern-territory-politics/northern-territory-election-2024/` [S]). Realistic: 0 to 5 statewide polls per cycle,
mostly MediaReach, uComms or party-commissioned. Seat polls matter more here than statewide ones, and the model already has a seat-poll path
(`seat_poll_blend.R`, `seat_poll_joint.R`).

**What the model needs.**
1. Results ingest: 25 seats x 7 elections of candidate first preferences, plus preference distributions (flow matrix). 175 seat-elections only.
2. Party classes: CLP replaces LNP (ALP, CLP, Greens, independents, plus a local party like Territory Alliance 2020 and others). Handled by `parties.R` /
   `classify_party()` once extended.
3. Tiny electorates: seat noise `sd_cell` (`1.10 + 8.67*sqrt(p(1-p))`) was fitted on mainland seats of 30,000 to 50,000 voters. With 4,000 voters per
   seat, sampling noise alone is larger, and independents with personal followings (Indigenous communities, remote seats) swing 20+ points. The noise function must be refit with a small-electorate term.
4. Independents and incumbents: personal vote is much bigger than on the mainland; `slope` for returning candidates needs checking on NT data.
5. Optional preferential in 2016: either skip that pair, or model exhaustion. Simplest: score 2020 and 2024 as pairs (and 2012 -> 2016 flagged).
6. Training data for the XGB layers: 175 seat rows is too small to retrain the primary or flow xgb; use the pooled national xgb as-is or shrink to the
   linear model (house rule: shrinkage not cliffs). Expect the AEF-style layers to add little here.
7. Backtest pairs: 2001->2005 ... 2020->2024 = 6 pairs (7 elections), of which 2012->2016 and 2016->2020 are non-comparable on count rules.
   Registered like other jurisdictions in `all_election_pairs()`, `election_dates.R`, six harnesses: **CLAUDE.md requires any harness change to hit all six**, so
   adding a seventh harness (or a jurisdiction parameter) is itself a task.

## What a Hare-Clark simulator needs (Tas and ACT)

The existing loop in `src/seat_sim_core.cpp` removes the lowest candidate and distributes, to a final two. Hare-Clark instead fills N seats
per electorate: elect anyone at quota, transfer the surplus at a fractional value (Tasmania: the last bundle's transfer value;
ACT: all ballots at a reduced value, since 1995 via the electronic count), then exclude the lowest and transfer, repeat until N filled. In
principle this is a separate C++ routine.

Inputs per electorate (candidate level, not party level):
- Candidate first-preference shares, not just party shares. Within a party the split is the crux: Labor and Liberal tickets each have 2 to 5 candidates,
  and who gets elected inside a party depends on the within-party split and on the quota. Two parties with 40% and 45% could win 2+2
  or 3+2 seats depending on candidate splits.
- A model of the within-party split: share of party vote going to each candidate, from candidate profile (sitting member, ex-minister, leader),
  previous election splits, and noise. Robson rotation randomises ballot position, so position effects are not a systematic bias, but the split
  is high-variance. This replaces the single-member "seat noise" with a Dirichlet-style draw per party.
- Flows: preferences between parties and, crucially, between candidates within a party. In Hare-Clark most surplus and exclusion transfers go to
  same-party candidates (typically 70% to 85% [M]). ACT per-ballot files give this exactly; Tas count sheets give it aggregated.
- Exhaustion: Tasmania needs only 5 preferences and many ballots exhaust; the simulator needs a leakage rate per excluded party.
- The statewide-to-electorate step: `dev_slope()` applies to a party's share per electorate; five electorates of 5 or 7 seats means very few units per election (5)
  and each is large (~70,000 voters), so a per-electorate residual SD is estimable only from ~35 to 40 electorate-elections in total per jurisdiction.

Can we simulate party seat counts per electorate from party vote shares plus within-party candidate splits? Yes, and that is the right first version: draw party
shares per electorate (trend + dev_slope + noise), draw a within-party candidate split, then run the count. A short-cut version that skips the count
entirely (Droop-quota remainders: seats = floor(share/quota), allocate remainders by largest remainder after a
leakage adjustment) would be a baseline to beat but is known to mis-assign the last seat, which is where all the interesting probability lies; the
full count is what the model should do.

Backtest scoring: unit = (party, electorate, election) with seats won an integer 0..N. Score as multinomial / ordinal log loss on the seat count per
party-electorate (or as P(party wins >= k seats)), plus a statewide seat-count log loss and a binary "who forms government" score. The existing
seat winner log loss does not translate: there is no single winner. Eps floor of 1e-6 from the house rule should be kept. Sample sizes: Tas 7 elections x 5
divisions x ~4 parties; ACT 7 x 5 x ~4. About 100 to 150 party-electorate cells each, which is **an order of magnitude less than the mainland (2,050
seat-elections)**: nothing can be fitted with xgb; shrink everything to priors; and AEF-7-style screening is not available.

Reusable pieces: statewide trend, dev_slope, correlated statewide draws, personal incumbency, calibration and scoring scaffolding. New:
the count itself (C++), the candidate-level data model (candidate rows already exist for single-member, `output/candidacies.csv`; they need an electorate-with-N-seats
field and a party-ticket id), within-party split model, a Hare-Clark flow table, 5/7-member quotas, jurisdiction config.

## Effort

| Jurisdiction | Main work items | Size |
|---|---|---|
| NT | (1) get and parse NTEC results for 7 elections; (2) CLP/local-party classes, 2016 optional-preferential handling; (3) refit seat noise for ~4,000-voter seats; (4) wire into `all_election_pairs()`, six harnesses (or one parametrised) and publication; (5) poll ingest (Wikipedia + Poll Bludger) | Small to medium (about 1 to 2 weeks). Risk is the data hunt, since NTEC blocked my fetcher |
| ACT | (1) parse ballot files for 6 to 7 elections; (2) Hare-Clark count engine in C++ with surplus transfer rules, tested on the 2024 count; (3) candidate-level share model with within-party splits; (4) electorate-level swing + residual model; (5) scoring harness; (6) poll ingest (2 polls per cycle) | Large (3 to 5 weeks incl. engine) |
| Tas | Same engine as ACT, plus: (1) older-year results scraped from PDF/XLSX; (2) 25 to 35 seat regime change handled in the swing model; (3) different surplus rule (last parcel) vs ACT; (4) poll ingest (EMRS-heavy) | Large if first; medium (1 to 2 weeks) after the ACT engine exists |

## Recommendation

- **Order**: NT, then ACT, then Tas. Ship the Hare-Clark engine on ACT because the per-ballot files let us verify the engine against 6 to 7 real counts
  (a rare chance to test a simulator against ground truth, and the 2024 distribution Tables give a second check). Tasmania last
  because its older data is the worst and the 7-seat expansion means only one election exists under the current rules, but its polls (about 15 per cycle) are the only
  ones good enough to make the forecast more than a prior.
- **Worth doing?** NT: modest value, 25 seats and the next election is 2028; but nearly free given the existing path. ACT: next election 2028 (October), poll
  scarcity means the forecast is mostly fundamentals; do it for completeness and for the engine. Tas: the next is due by 2029; the most-followed of the three and the best polling; the value
  is real but the engine cost is shared.
- Defer all three until the mainland 2010+ coverage (the program's priority) is done; none of the three blocks it.
- **Not recommended**: retrofitting the single-member IRV model to Tas/ACT by treating seats as single winners per party. It cannot express "Greens win 1 of 5".

## Unverified / gaps (what to check first)

1. NTEC results files and formats (403). 2. TEC "Export Count" XLSX contents and any older-year (pre-2025) data. 3. ACT ballot-file pages for 2001 to 2020 (URLs moved;
2024 only confirmed). 4. Exact election dates (from memory). 5. ACT 2024 poll count (not found).
6. The Tas 25-seat period (1998-2024) and ACT pre-2016 17-seat structure, from memory. 7. Data licences. 8. Wikipedia poll pages for ACT/NT/Tas
cycles before 2018; Track B's `deciding-runs/wiki-poll-pages-2026-10-13.csv` should supersede my poll counts.
