# Victoria 2026 upper house (Legislative Council): rules, count, and what a live model needs

Ticket: peteowen1/auspol#152 (part of #148). Researched 2026-10-28. Election: Saturday 28 November 2026.
Source tags: [P] primary (statute text, bill, VEC, Parliament); [S] secondary (news, blogs, advocacy).
Anything marked UNCONFIRMED could not be verified; where I looked is stated.

## 1. Group voting tickets are abolished for 2026

- Law: *Electoral Amendment (Miscellaneous Matters) Act 2026*, Act No. 28/2026. Introduced in the Assembly 28 July 2026, passed Assembly 29 July, introduced in the Council 30 July, passed Council 11 August (committee finished with the bill NOT amended), Royal Assent 18 August 2026. Commencement: the day after Royal Assent (clause 2). [P] bill page https://www.legislation.vic.gov.au/bills/electoral-amendment-miscellaneous-matters-bill-2026 ; bill as passed https://content.legislation.vic.gov.au/sites/default/files/2026-08/601335bs1.pdf ; Explanatory Memorandum https://content.legislation.vic.gov.au/sites/default/files/bills/601335exi1.pdf
- Mechanism: clause 7 repeals s69B of the *Electoral Act 2002* (the ticket provision). Clause 15 rewrites s93A (how to vote). [P] bill text.
- Context: the Electoral Matters Committee recommended abolition "in time for the 2026 state election" (report tabled 2 Dec 2025) [S] https://www.tallyroom.com.au/63675 (summary only; the report itself not read). A separate Greens private member's bill, *Electoral Amendment (Group Voting and Vote Counting) Bill 2026* (Puglielli; second reading 4 Feb 2026), proposed abolition AND a switch to weighted inclusive Gregory counting [P, Hansard, via a summarising fetch] https://www.parliament.vic.gov.au/parliamentary-activity/hansard/hansard-details/HANSARD-974425065-33994 . It is NOT the bill that was enacted; see section 2.
- Support: Labor, Liberal, National, Greens and One Nation supported; Bourman (SFF), Limbrick (Libertarian), Payne (Legalise Cannabis) and Purcell (Animal Justice) opposed [S] news (neoskosmos / kyfreepress, 13 Aug 2026). A "33-4" division figure appeared in one aggregator only: UNCONFIRMED.
- Other 2026 acts (VEC summary [P] https://www.vec.vic.gov.au/about-us/legislation/electoral-act-amendments-2026): *Electoral Amendment Act 2026* (13/2026, partly commenced 25 May; Council group registration closes noon six days after the writ, i.e. 9 Nov 2026; also a full distribution of preferences in all 88 Assembly districts) and *Electoral Further Amendment Act 2026* (19/2026, assent 9 June; no Council changes listed).
- One advocacy page (PRSA) calls it the "Electoral (Miscellaneous Matters) Act 2026" operating "19 August 2026" [S]; that matches assent 18 Aug plus one day.

## 2. Voting rules and the count

### Voting ([P] bill text clauses 15-17, VEC pages)
- Above the line (ATL): number at least 1 to 5 in unbroken sequence across groups. If there are 5 or fewer groups, number all of them. Preferences run to every candidate of each numbered group in the order printed: first preference to the numbered-1 group's first candidate, then the rest of that group, then the next-numbered group's candidates, and so on. Senate-style, not ticket-style.
- Below the line (BTL): number at least 1 to 5 candidates in unbroken sequence (unchanged).
- Informality saving: an ATL ballot with at least one number but fewer than required, or a break in sequence, is formal up to the break (s112A as amended). A tick or cross ATL counts as 1.
- Both ATL and BTL marked: if both are valid, BTL is used; if only one is valid, that one is used (s112B).
- Group candidate order is set by the group at registration (not drawn).
- Consequence: ATL ballots can now exhaust late in the count (under tickets they never did).

### Structure
- 40 members: 8 regions x 5 members, each region = 11 Assembly districts. Regions (2022 names): Eastern Victoria, North-Eastern Metropolitan, Northern Metropolitan, Northern Victoria, South-Eastern Metropolitan, Southern Metropolitan, Western Metropolitan, Western Victoria. [P] https://www.vec.vic.gov.au/se22 . Whether 2026 regions equal 2022's: UNCONFIRMED (2026 boundary determination not checked).
- Quota (Droop): formal ballots / (5 + 1), plus one, remainder dropped; about 16.7% of formal votes. [P] https://www.vec.vic.gov.au/voting/how-voting-works/counting-votes

### Count method (surplus and exclusion)
- Surplus of an elected candidate: their ballot papers are redistributed at a reduced value; transfer value = surplus / number of ballot papers they hold. Exclusion: lowest candidate excluded, papers move at the value they arrived with. Repeat until 5 are filled. [P] VEC counting page above.
- That is the existing unweighted inclusive Gregory method. The Greens bill would have made it weighted; the enacted bill has no clause touching counting (I searched the passed bill text for gregory / transfer value / surplus / quota: no hits). So the method is, by inference, UNCHANGED for 2026. I did NOT read the current s114A text; confirm there before coding tie-breaking, bulk-exclusion and surplus-order rules.

## 3. What the VEC reports, and when

- Region pages show first preferences by candidate and group, with enrolment, formal and informal totals. Results by voting centre are NOT on the page; only in a "Rechecked results by voting centre" Excel download. Distributions of preferences and "votes received" are Excel downloads (in 2022 also a group voting tickets PDF). [P] https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-region/eastern-victoria-region-results ; statewide first preferences and seats: https://www.vec.vic.gov.au/se22
- Election night 2022: about 20-30% of enrolment per region counted (election-day votes plus some postal; pre-poll not yet counted). No official Council distribution; analysts ran the ABC preference calculator on partial first preferences. [S] https://www.tallyroom.com.au/50494 (28 Nov 2022). The same post says no easy statewide primary-by-party table was published.
- Precedent from 2018/2014 [S: search summaries of a VEC pdf and Poll Bludger, not opened]: Assembly counts first after 6pm, then the Council primary count; early votes counted from the Monday after, absent votes from the Tuesday, provisionals the next week; Council ballots rechecked; the Council count finished several days after the Assembly. 2026 timing is UNCONFIRMED: no VEC page I could open states it. The VEC 2026 page gives dates only (writ 3 Nov, rolls close 3 Nov, early voting 18-27 Nov, polling 28 Nov 8am-6pm). [P] https://www.vec.vic.gov.au/voting/2026-state-election
- Date of the full distribution: BTL preference files appeared around 10 Dec 2022 [S, a reader comment: weak]; a Crikey piece said final Council preferences were distributed the day before it ran (date unverified). "Roughly 1.5 to 2.5 weeks after polling" is an estimate, not a fact.
- With no tickets, the outcome rests on voters' own sequences. Whether the VEC will release ATL/BTL preference data files for 2026: UNCONFIRMED.

## 4. What the repo already holds

Read `docs/DATA-REGISTRY.md` and `docs/DATA-DICTIONARY.md` (the worktree has no `external/`; names come from those docs).
- NOTHING for the Legislative Council. The `vec-2022-vic-*` files (candidates 731 rows, firstprefs 508, transfers 1,956, winners 88) are LOWER HOUSE (88-seat `seat` key). The same goes for the 2002-2018 vec files. `docs/ANCHOR-MODEL.md:145` says "Upper houses not modelled at all."
- Useful: `external/reference/vic-district-regions.csv` (88 rows, `district`, `region`) maps Assembly districts to Council regions, so district forecasts can roll up to regions. Check against 2026 boundaries (UNCONFIRMED).
- Missing: 2022 and earlier Council first preferences by group/candidate per region (ideally by voting centre/vote type); 2022 distributions of preferences; BTL data; group order. All are VEC Excel downloads (links above); I did not download any. There is also no data at all on ATL preferencing under the new rules; only analogues (federal Senate, NSW/WA/SA councils), none in the registry.

## 5. What a live upper-house model needs

Inputs
1. District-to-region map (refreshed for 2026) and enrolment/turnout per region (formal votes set the quota).
2. Group list per region: names, ballot letters, candidate order (registration closes noon 9 Nov 2026). Which groups stand where is the biggest unknown until then.
3. First-preference forecast per group per region for ALL groups (ALP, Lib, Nat, Grn, ONP, Legalise Cannabis, SFF, Animal Justice, Libertarian, others). The current model forecasts Assembly seats by candidate; it must roll up to regions, and minor groups have no Assembly analogue. Needs 2022/2018 Council history (missing).
4. Voter preference behaviour: share voting BTL (2022 about 9.5-10%), and the distribution of how many groups ATL voters number and in what order. No Victorian data exists; borrow from the Senate. Council how-to-vote cards are registered with the VEC and can inform flows.
5. Exhaustion: ballots that run out before the fifth seat (ATL voters give at least 5 numbers).

Count algorithm (per region)
1. Expand each ballot to a candidate order: ATL = group sequence, candidates in printed order within each group; BTL = candidate list; apply short-sequence and mixed-ballot rules.
2. quota = floor(formal / 6) + 1.
3. Sequential count: elect anyone at quota, pass surpluses with inclusive Gregory transfer value (surplus / ballots held), exclude lowest and move papers at the value received, until 5 elected. Take tie and bulk-exclusion rules from s114A (not yet read).
4. Simulate over uncertainty in primaries, preference flows and BTL rate; report P(seat) per group per region, the fifth seat being the main uncertainty.
5. Validate on a proxy: replay 2022 first preferences under the new rules and compare with other analysts' what-ifs ([S] https://www.tallyroom.com.au/50522) and Senate results. 2022 actuals came from tickets and are not a clean test.

Knowable on the night versus after
- Night: partial first preferences by group per region (2022: roughly 20-30% of enrolment, mostly election-day votes; pre-poll is the larger share and counted later). Seats 1-3 per region are often clear early; the 4th and 5th depend on late votes and preferences.
- Not on the night: any official distribution of preferences, BTL preference data, rechecked counts. A live model must project the preference stage itself from first preferences plus an assumed flow model.
- After: full distributions and declarations (days to weeks; 2026 timing unconfirmed). A close fifth seat will be decided by real preference sequences nobody has in advance.

## Gaps to close next
- Read s114A and the consolidated Act on legislation.vic.gov.au.
- Confirm 2026 region boundaries and the group list (after 9 Nov).
- Download the VEC 2022 and 2018 Council Excel files.
- Find the VEC 2026 election-night results plan for the Council.
