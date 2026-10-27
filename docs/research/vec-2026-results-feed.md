# What the VEC 2026 results feed contains

Research for issue #149 (part of map #148). Written 2026-10-28.

Why it matters: election night is only useful if our parser reads the feed correctly the first
time, and the 2026 feed changed in ways that break a 2022-shaped parser (new vote types, early
voting centres as extra "booths", a withheld-2CP flag, new file names).

## Sources and how they were read

All four documents were downloaded raw into `external/reference/vec/2026/feed-docs/` (gitignored):

| Source | Local file |
|---|---|
| Feed page https://www.vec.vic.gov.au/about-us/media/2026-results-data-feed | `feed-page.html` |
| User guide v1.0, September 2026 (72 pp) | `user-guide.pdf`, text via `pdftotext -layout` as `guide.txt` |
| 2026 sample zip (v2 files) | `sample2026.zip`, unzipped to `z2026/`, inner zips to `inner26/` |
| 2022 sample zip (real 2022 data) | `sample2022.zip`, unzipped to `z2022/`, inner zips to `inner22/` |

Labels used below: **[guide]** = stated in the user guide, **[sample]** = observed in the 2026
sample XML, **[2022 sample]** = observed in the 2022 sample XML, **[NOT CONFIRMED]** = not in any
of the four sources.

Important caveat on the 2026 sample: it is **test data** ("Test State Election 2026", event id
18738): 6 Lower House districts (Bass, Evelyn, Gippsland East, Gippsland South, Hastings,
Monbulk) and 1 Upper House region (Eastern Victoria), with invented candidates ("CANDIDATE,
One") and invented tiny counts (enrolment 5,000). It shows structure and behaviour, not real
numbers. The 2022 sample is the real 2022 result (88 districts, 1,729 booths).

## Short answer

- **The count is per voting centre AND per vote type, but not both at once.** Each polling
  place row has first preferences (and 2CP) as a single total. Vote-type splits exist only for
  the whole district. [guide, sample]
- In 2026 "polling place" now means three things: election-day voting centres, **early voting
  centres (EVCs, one row each)** and **one amalgamated mobile voting row per district**.
- Postal, other-early, marked-as-voted, provisional and absent votes have **no booth**. They
  appear only in the district-level `VotesByType`.
- Files are **complete snapshots**, not deltas, one file per (file type x house), covering
  **all districts (or regions) in one XML file**. A new timestamped ZIP is written about every
  5 minutes on election weekend. Nothing is overwritten.
- Delivery is a **SharePoint site plus a shared access token**. The host name, protocol and
  directory path are given only to approved users; they are not public. [NOT CONFIRMED beyond that]
- Access needs a signed terms-of-use agreement. Access opens 4 Nov; trial 25 Nov; set-up files
  and zero results from 10 Nov; election 28 Nov.

## 1. Granularity: district, voting centre, vote type

Verified by summing the sample (Bass District, final Lower House Verbose file, 2 Oct 2026):

| Contest-level `VotesByType` (formal) | Value | Sum of booth rows of that class |
|---|---|---|
| `Ordinary` | 88 | 88 (5 rows with `Classification="VotingCentre"`) |
| `EVCEarly` | 46 | 46 (3 `EarlyVotingCentre` rows) |
| `MobileVotingEarly` | 15 | 15 (the 1 `MobileVoting` row) |
| `Postal`, `Early`, `MarkedAsVoted`, `Provisional`, `Absent` | 90, 118, 3, 4, 18 | no booth rows exist |

The same identity held for Evelyn, Gippsland East and Gippsland South (all four districts that
had `VotesByType` in that file) for both Formal and Total. So a district total can be rebuilt
from booths plus the five centrally counted vote types, and the booth-level and type-level
views reconcile exactly. Hastings in the same file was in **recount** (see section 8).

Vote types, exactly as spelled in `Votes/@Type` [guide p.28-29, sample]:

| `@Type` | Meaning [guide] |
|---|---|
| `Ordinary` | Election-day voting centre, voter's own district |
| `EVCEarly` | Early voting centre, voter's own district (new in 2026) |
| `MobileVotingEarly` | Mobile voting before election day, own district (new in 2026) |
| `Postal` | Valid postal votes admitted to the count |
| `Early` | Other early votes outside the voter's district (telephone-assisted, overseas, interstate, out-of-district votes taken in Victorian EVCs and mobile teams then moved to a central count). Narrowed in 2026 |
| `MarkedAsVoted` | Declaration votes by electors already marked as having voted |
| `Provisional` | Declaration votes by electors not on the roll; admitted after verification |
| `Absent` | Election-day votes outside the voter's district, admitted later |

Where each file type carries what [guide p.14, sample]:

| File | Contest totals | Contest `VotesByType` | Booth rows | Booth votes | Booth name/class |
|---|---|---|---|---|---|
| Lite (`lite`) | yes | yes | ids + `Updated` only | no | no |
| LitePP (`litepp`) | yes | yes | yes | yes | no (id only) |
| Verbose (`verbose`) | yes | yes | yes | yes | yes (`Name`, `Classification`) |

Booth rows never carry `VotesByType` [guide p.23, sample: element absent].

## 2. Two-candidate-preferred (2CP) pairings

**What is reported.** The district-level `TwoCandidatePreferred` holds exactly two `Candidate`
elements ordered by ballot position, each with `eml:CandidateIdentifier/@Id`, `Votes`, and
`VotesByType` (Lite/LitePP/Verbose all carry district-level 2CP; the Verbose adds
`eml:CandidateName`). Each booth row also has its own `TwoCandidatePreferred` with the same two
candidates and `Votes` only (LitePP, Verbose). In the Lite file, booth-level 2CP is a bare
`Updated` timestamp. [guide, sample]

**The VEC chooses the pair.** It is a VEC selection, not "the top two on first preferences".
The 2CP count is "indicative only" and a selection "may be corrected at the commencement of
rechecks following election weekend". [guide p.13]

**When the pair can change** [guide p.23, p.71-72, sample]:

1. The element is absent until a 2CP result is entered. In the sample, early files have no
   `TwoCandidatePreferred` at all, then it appears for each district at a different time (first
   at 12:25 on 21 Sep for 5 of 6 districts, Evelyn 15:39).
2. It can be **withheld**: `Maverick="true"` on the district `TwoCandidatePreferred` (and on
   every booth-level `TwoCandidatePreferred` in that district, LitePP/Verbose). The element
   stays, keeps `PollingPlacesReturned`, `PollingPlacesExpected` and `Updated`, but has **no
   `Candidate` children**. Used when the 2CP pair is not expected to be the final two, when a
   3CP is being run (3CP data is not in the feed), or when the pairing is unclear. The attribute
   is only ever present as `true`; `Maverick="false"` never appears. FirstPreferences are
   unaffected. [guide p.22, p.30, p.66, p.71]
3. **The pair can change between the primary 2CP count and the recheck 2CP count.** When it
   does, only recheck 2CP results are published, so the feed never mixes two pairings.
   [guide p.23, p.72]
4. Observed in the sample (Evelyn District): pair `24982, 25000` on election weekend, then
   `Maverick="true"` from 23 Sep (file `..._20260923_103451`) through 26 Sep 11:17, then in
   the next file (`..._20260926_142544`) the pair is `25000, 25029` with
   `PollingPlacesReturned="0"` of 9, counting back up to 9 of 9 by 2 Oct. Candidate 24982 left
   the pair; 25029 entered. The other five districts kept their pair throughout.

**What the parser must therefore do**: never key 2CP by position or by an earlier file's pair;
read the two `CandidateIdentifier/@Id` values in each file; treat a pair change as normal; and
treat `Maverick="true"` as "no 2CP data" rather than zeros. Because the pair is VEC-chosen,
2CP-vs-our-model scoring must be done against whatever pair the file names, and a 2CP result
from a different pair than we modelled cannot be compared like for like.

**Not in the feed**: preference distributions, two-party-preferred (2PP), swing, declaration
date, Upper House recount data. [guide p.15]

## 3. How files arrive

| Question | Answer | Source |
|---|---|---|
| Host / protocol | A "secure result data feed SharePoint site" for manual download, plus "a shared access token that will allow users to automatically download". Host name, URL and whether the token is an HTTPS signed URL are given to approved users only | [guide p.7]; **[NOT CONFIRMED]** the exact host/protocol |
| One file or many | One ZIP per file type x house per publication. Each ZIP holds one XML covering **every district (Lower House) or region (Upper House)** | [guide p.15, sample: 6 districts in one LH file, 88 in the 2022 one] |
| File types | `lite`, `litepp`, `verbose` x `lh`, `uh` = 6 results files per publication, plus 3 set-up files | [guide] |
| Overwrite or new file | **New file each time.** The directory accumulates; names are listed ascending by timestamp; "list all files within the directory and select the most recent" | [guide p.15] |
| Snapshot or delta | Complete snapshot of everything available at that time. Not incremental | [guide p.67] |
| Cadence | Every 5 minutes during election weekend. Then continues as declaration votes are processed; "may be reduced to every 15 minutes and continue to reduce". The website and feed come from the same data source; small timing differences are possible | [guide p.8, p.67] |
| Set-up files | Published before results; fixed for the event. Revised versions published if changes needed | [guide p.10] |

File names [guide p.11, p.15; sample]:

- Results ZIP: `<Election><filetype><house>v2_YYYYMMDD_HHMMSS.zip`, e.g.
  `State2026mediafileliteppuhv2_20260706_170045.zip`. The sample uses `TestState2026...`. Inner
  XML has the same stem with `.xml`.
- Set-up: `State2026MediaFilePollingLocationsV2.xml`, `State2026MediaFileCandidatesV2.xml`,
  `State2026MediaFileGroupsAndTicketsV2.xml` (not zipped, not timestamped).
- Changed from 2022: `v2` added to the stem. 2022 was `State2022mediafileverboselh_20221201_100010.zip`.
- The timestamp in the name is "the primary mechanism for identifying newer versions". The XML
  root `@Created` also gives generation time.
- The sample timestamps in names (`20260921_090801`) agree with root `@Created`
  (`2026-09-21T09:08:00`) to the second, so the name is the file's generation time in
  Melbourne local time. [sample]

Guide text mentions ".xip compression" on p.8; every sample file is a plain `.zip`, so this
looks like a typo. [guide p.8 vs sample]

Dates [feed page]: access granted from **Wed 4 Nov**; set-up files and zero-version results
from **Tue 10 Nov**; election-night trial **Wed 25 Nov** (test data, no 2CP); election
**28 Nov 2026**.

Access terms [feed page, guide]: terms-of-use agreement and access request form; "approved
stakeholders" (media, analysts). The VEC offers no technical support to embed the feed. Whether
Pete's use qualifies as "analyst" is **[NOT CONFIRMED]**; the request goes to
`communication@vec.vic.gov.au`.

## 4. What identifies a voting centre; matching to 2022

Identifier: `PollingPlaceIdentifier` with attributes `Id`, `Name`, `Classification`
(`VotingCentre` | `EarlyVotingCentre` | `MobileVoting`). `Name` and `Classification` appear
**only in Verbose** results files. Lite and LitePP carry `Id` only, so they need the Polling
Locations set-up file. [guide p.29, sample]

The Polling Locations set-up file (root `PollingDistrictList`, namespace
`http://www.aec.gov.au/xml/schema/mediafeed`, `Created="31/08/2026 4:46:21 PM"` in the
sample) is: `PollingDistrict/PollingDistrictIdentifier@Id` + `Name`, then
`PollingPlaces/PollingPlace/PollingPlaceIdentifier(@Id,@Name,@Classification)`,
`WheelchairAccess` (`None|Assisted|Full`), and `Address` with `AddressLongitude`,
`AddressLatitude`, `AddressLine1`, `AddressLine2`, `Suburb`, `Postcode`. Mobile voting rows
have empty coordinates and `AddressLine1` = "Multiple mobile voting locations". The guide says
latitude and longitude are populated for voting centres and EVCs. In the sample test set-up
file coordinates were blank for 164 of 176 EVC rows and 1 of 56 voting centres (test data;
real file expected from 10 Nov). Names are display text: the guide says "should not be relied
upon as unique identifiers". [guide p.11, sample]

**Matching to 2022 booth files**, checked by script against the 2022 sample (Dec 2022 final
Verbose LH) and the 2026 sample set-up file:

| Key | Result |
|---|---|
| District id (`PollingDistrictIdentifier/@Id`) | **88 of 88 identical ids and identical names** in 2022 and 2026. Safe join key |
| Contest id (`ContestIdentifier/@Id`) | Differs (e.g. Albert Park 15818 in 2022; Bass 18828 in 2026). Do not join on it |
| Polling place id | **0 of 1,729 2022 ids appear in the 2026 set-up** (2022 ids 16003-17774; 2026 ids 18835-19087). Ids are reissued per event |
| (district, booth name) | 44 of the 56 `VotingCentre` rows in the 2026 test set-up have an exact (district, name) match in 2022 (e.g. Bass District / Bass, Clyde, Grantville, San Remo) |
| Candidate id | New each event (Bass 2026: 24952-24975) |

So: **join 2022 booths to 2026 by (district id, normalised booth name), with a fuzzy/manual
fallback, and treat the polling place `Id` as an in-event key only.** Caveats, all unconfirmed:
the sample set-up is the test event and covers only 56 election-day centres, so the 44/56
match rate is for test districts; the real file arrives 10 Nov. Booth openings, closures and
renames between 2022 and 2026 are expected but not measured. EVCs and mobile teams have no
2022 booth row because in 2022 early votes were not published by location (2022 sample: 0 of
1,729 place names contain EVC/Early/Mobile; early votes sat in the district-level `Early` type).
Our `output/booths/vic2022-booth-fp.csv` is keyed by booth name and district (per
`docs/DATA-REGISTRY.md`); it carries no VEC place id, so name-and-district is the only join
available on our side.

## 5. Upper House (Legislative Council) files

Root is the same `MediaFeed`, with `Election/ElectionIdentifier@Id="U"` and the body under
`Senate` (not `House`) [sample]. The 2026 sample has one region (Eastern Victoria Region);
the 2022 sample has all 8.

Per region `Contest` [guide, sample]:

- `ContestIdentifier@Id`, `ContestName`, `PollingDistrictIdentifier@Id` + `Name` (the region
  id; Eastern Victoria is 16002 in both 2022 and 2026), `Declared`, `eml:NumberOfPositions`
  (note the `eml:` prefix, unlike Lower House), `Enrolment`, `Quota Provisional="true"`.
- `FirstPreferences@PollingPlacesReturned/Expected/Updated` containing, per party group,
  `Group/GroupIdentifier@Id` (+ `GroupName`), `TicketVotes/Votes` (above-the-line votes) and
  `GroupVotes/Votes` + `VotesByType` (above + below the line combined), then
  `UngroupedCandidate` (id, `Elected`, `BallotPosition`, `Votes`, `VotesByType`), `Formal`,
  `Informal`, `Total`, each with `VotesByType`.
- `PollingPlaces`: the same booth structure as the Lower House (voting centres, EVCs, one
  mobile row), with group `TicketVotes`/`GroupVotes` per booth and no `VotesByType`. In
  Verbose, `GroupName` is repeated at booth level.
- No `TwoCandidatePreferred`. No preference distributions. Upper House recount data is not in
  the feed. Recheck data comes from the computerised recheck. [guide p.15, p.22]
- Group voting tickets are gone: the guide says that ticket information "will no longer
  populate" after the August 2026 Electoral Act change. Above-the-line votes are still
  counted as `TicketVotes`. The Groups and Tickets set-up file (root `SenateGroups`) has
  `GroupIdentifier@Id`, `Ticket` (the group letter), `GroupName`, and each candidate with
  `eml:AffiliationIdentifier`. [guide p.12, sample]

## 6. Structure of the Lower House file (for the parser)

Namespace: results files use default `http://www.vec.vic.gov.au`; candidate/contest/election
ids use `eml:` (`urn:oasis:names:tc:evs:schema:eml`). The set-up files use different default
namespaces (`urn:oasis:names:tc:evs:schema:eml`, `http://www.aec.gov.au/xml/schema/mediafeed`),
and some elements (e.g. `eml:NumberOfPositions`) switch prefix between houses, so **match by
local name, not by namespace-qualified path**.

Verbose Lower House, element paths [sample]:

```
MediaFeed @Verbose @Id @Created @Phase
  eml:EventIdentifier @Id / eml:EventName
  Election / eml:ElectionIdentifier @Id (L) / ElectionName / ElectionCategory
    House / Contests / Contest @Updated
      eml:ContestIdentifier @Id / eml:ContestName
      PollingDistrictIdentifier @Id / Name
      Declared, NumberOfPositions, Enrolment
      FirstPreferences @PollingPlacesReturned @PollingPlacesExpected @Updated
        Candidate @Independent(yes|no)
          eml:CandidateIdentifier @Id / eml:CandidateName
          Affiliation / eml:AffiliationIdentifier @Id / eml:RegisteredName   (only if Independent="no")
          Elected, BallotPosition, Votes, VotesByType / Votes @Type
        Formal | Informal | Total  -> Votes, VotesByType / Votes @Type
      TwoCandidatePreferred @PollingPlacesReturned @PollingPlacesExpected @Updated [@Maverick]
        Candidate (x2) -> eml:CandidateIdentifier @Id (/CandidateName), Votes, VotesByType
      PollingPlaces / PollingPlace @Updated
        PollingPlaceIdentifier @Id @Name @Classification
        FirstPreferences @Updated -> Candidate(eml:CandidateIdentifier @Id, Votes)*, Formal, Informal, Total (Votes only)
        TwoCandidatePreferred @Updated [@Maverick] -> Candidate(id, Votes) x2   (@Updated="" = no count yet)
```

`Phase` was `ElectionNight` in all 219 2026 sample files and all 72 2022 sample files, even a
week later, so it carries no information in the samples.

Lite adds `BallotPosition` to contest-level `Candidate` and to 2CP `Candidate`, drops names and
affiliation, and gives booth rows as `PollingPlaceIdentifier@Id`, `FirstPreferences@Updated`,
`TwoCandidatePreferred@Updated` with no votes.

Other behaviours [guide, sample]:

- **Booths appear only once they report.** The 2026 `PollingPlaces` list grows from 0 to
  9-10 rows per district; `PollingPlacesExpected` is the denominator (9 or 10 in the sample).
  Booth ordering: voting centres, then EVCs, then mobile.
- **Counts are the latest completed count per parcel**, primary or recheck, so a file can mix
  count stages until everything is aligned. [guide p.9, p.21]
- **Empty `Updated=""`** on a booth-level `TwoCandidatePreferred` means no completed 2CP yet
  for that booth. [guide p.25, p.67; sample at 11:07 21 Sep]
- **Recount** (district): only contest-level candidate totals; no `VotesByType`, no
  `PollingPlaces`. Seen in the sample for Hastings on 2 Oct (`PollingPlacesReturned="0"` of 10,
  `Formal`/`Informal`/`Total` with `Votes` only, 2CP present with no `VotesByType`).
  [guide p.15, p.22; sample]
- **Declared** is `true`/`false` per contest; counting and updates can continue after `true`.
  [guide p.69-70; sample: all of Bass/Evelyn flip to `true` on 2 Oct]
- Zeros mean "not yet reported" as well as "no votes". Totals can fall as well as rise
  (corrections, missort fixes, rechecks). [guide p.70]
- Timestamps: `Created` on the root has no offset (`2026-09-26T11:17:35`); `Updated` has an
  offset (`+11:00`). The set-up file `Created` uses `31/08/2026 4:46:21 PM`. In the sample,
  September timestamps carry `+11:00` although daylight saving began 4 Oct 2026; this is
  probably a quirk of the test environment, and polling day (28 Nov) is inside daylight
  saving so `+11:00` will then be right. [sample]

## 7. What changed from 2022 to 2026

Verified by diffing the element/attribute set of the 2022 final Verbose LH file against the
2026 Verbose LH file, plus [guide p.9, p.57-66].

| Change | 2022 | 2026 |
|---|---|---|
| File names | `State2022mediafileverboselh_...zip` | `State2026mediafileverboselhv2_...zip` (`v2` added); set-up files `...V2.xml` |
| Booths | Only election-day voting centres (1,729 in 2022) | Plus one row per EVC and one amalgamated mobile row per district, in the same `PollingPlaces` list |
| `PollingPlaceIdentifier` | `@Id`, `@Name` | adds `@Classification` (`VotingCentre`/`EarlyVotingCentre`/`MobileVoting`) |
| `VotesByType` types | 6: `Ordinary, Postal, Early, MarkedAsVoted, Provisional, Absent` | 8: adds `EVCEarly`, `MobileVotingEarly`; `Early` now means only out-of-district and similar early votes |
| 2CP withholding | none | `TwoCandidatePreferred@Maverick="true"` at district and booth level |
| 2CP update | primary count | updated again after recheck (pair may change; only recheck published if it does) |
| Count stage | primary or recheck for an entire electorate | latest result per parcel (booth or vote-type total) |
| Upper House recheck | not present | published, from the computerised recheck |
| Polling Locations set-up | names and ids | adds classification, address, latitude and longitude, wheelchair access |
| Group voting tickets | present | removed from the law in August 2026; ticket fields no longer populate |

Everything else (root `MediaFeed`, `House`/`Senate`, `Contest`, `FirstPreferences`, `Candidate`
fields, `Declared`, `Enrolment`, district and region ids) was identical in the diff.

**What the 2026 sample cannot tell us**: the real polling place list (only the 238-row test
set-up) and real-scale behaviour (6 test districts, not 88).

## 8. What our parser must handle

1. Pick the latest file by the `YYYYMMDD_HHMMSS` in the ZIP name; each is a full snapshot, so
   replace state, do not add. Keep every raw ZIP unmodified (repo rule: save raw first).
2. Unzip, then read the one XML inside. Parse by local element name; namespaces differ between
   files and houses (`eml:NumberOfPositions` in Upper House but not Lower).
3. Choose one results file type and know what it lacks. Verbose is self-contained; Lite and
   LitePP need the set-up files for names, party and classification.
4. Load all three set-up files once from the zero-version drop (10 Nov); re-read if the VEC
   says it revised them.
5. Treat booth rows as `(district id, PollingPlaceIdentifier@Id)`, three classes. Never sum
   booths across classes without saying which. Booths appear only after reporting; use
   `PollingPlacesReturned / PollingPlacesExpected` for progress.
6. District `VotesByType` is district-wide only. Booth rows have none. Postal, `Early`,
   `MarkedAsVoted`, `Provisional`, `Absent` have no booth location.
7. 2CP: read the pair from each file (2 ids, ordered by ballot position); allow the pair to
   change; treat `Maverick="true"` and a missing `TwoCandidatePreferred` as "no data"; treat
   `Updated=""` as "not counted yet", not zero.
8. Do not assume monotonic counts; totals can drop; a file can mix primary and recheck.
9. Recount contests have contest totals only (no `VotesByType`, no booths).
10. `Declared` can be `true` while the feed still updates.
11. Join 2022 by district id (stable) and (district, booth name); polling place, contest and
    candidate ids are all new each event.
12. Upper House: `Senate` branch, `Group` with `TicketVotes` (above the line) and `GroupVotes`
    (all first preferences), `UngroupedCandidate`, no 2CP.
13. Timestamps: root `Created` has no offset, `Updated` has one; use `Updated` for ordering
    within a file.

## Open questions (not answerable from the four sources)

- Host name, protocol and directory layout of the SharePoint/token delivery, and whether the
  token is a signed HTTPS URL. Only available after access is approved. Ask:
  `communication@vec.vic.gov.au`.
- Whether the real election-night files keep `Phase="ElectionNight"` throughout (the 2022 sample
  does, for 5 days).
- Whether real 2026 polling place ids are reused from the test set-up (the real set-up
  arrives 10 Nov).
- Whether our access request is approved.
