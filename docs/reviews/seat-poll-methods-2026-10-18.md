# Seat-poll method and sponsor classification (2026-10-18)

Purpose: give each of the 1,210 seat polls in `external/reference/polls/seat-polls/seat_polls.csv` a method and a sponsor, so poor methods can be down-weighted from data. Output: `external/reference/polls/seat-polls/poll_methods.csv` (one row per poll; `confidence` is for pollster and method, `sponsor_confidence` is for the sponsor).

How it was built: the cached Wikipedia pages in `raw/` were parsed locally; each poll was matched to its table row (seat, date, firm, sample) and its footnotes read. The two MRP pollster families were classified at pollster level only. Web look-ups were few: Poll Bludger posts, The Conversation (Wentworth Project), and the Australia Institute page for uComms. Sky News, The Australian, the Saturday Paper and web.archive.org were not fetchable or not tried, and the ABC Media Watch page for the Compass poll returned 404.

## Counts: what the numbers are

Number of polls in each pollster x method x sponsor cell (n = 1,210 polls; higher means more polls, nothing about quality). Method and sponsor labels are explained in the CSV; "unknown" means no source I read says.

| Pollster (cleaned) | Method | Sponsor type | Polls |
|---|---|---|---|
| Accent/RedBridge | mrp | pollster_self | 401 |
| YouGov | mrp | pollster_self | 387 |
| YouGov | mrp | media | 152 |
| unknown | unknown | media | 41 |
| ReachTEL | ivr_robopoll | unknown | 27 |
| Galaxy/Newspoll | mixed | media | 24 |
| unknown | unknown | unknown | 20 |
| unknown | unknown | advocacy_group | 17 |
| uComms | ivr_robopoll | unknown | 16 |
| uComms | ivr_robopoll | advocacy_group | 14 |
| YouGov | online_panel | media | 11 |
| Utting Research | ivr_robopoll | media | 10 |
| RedBridge | unknown | media | 9 |
| JWS Research | unknown | industry_lobby | 8 |
| unknown | unknown | party | 7 |
| unknown | unknown | industry_lobby | 7 |
| Galaxy | mixed | media | 7 |
| Insightfully | unknown | advocacy_group | 6 |
| Freshwater Strategy | unknown | media | 6 |
| KJC Research | ivr_robopoll | unknown | 5 |
| DemosAU | unknown | unknown | 4 |
| ReachTEL | ivr_robopoll | media | 3 |
| ReachTEL/uComms | ivr_robopoll | unknown | 2 |
| ER&C | unknown | party | 2 |
| RedBridge | unknown | pollster_self | 2 |
| Freshwater Strategy | unknown | party | 2 |
| uComms | ivr_robopoll | industry_lobby | 2 |
| Compass Polling | optin_link | unknown | 2 |
| RedBridge | unknown | unknown | 2 |
| Freshwater Strategy | unknown | unknown | 2 |
| Galaxy | mixed | unknown | 1 |
| ReachTEL | ivr_robopoll | union | 1 |
| ReachTEL | ivr_robopoll | advocacy_group | 1 |
| unknown | unknown | union | 1 |
| Laidlaw Campaigns | unknown | unknown | 1 |
| Compass Polling | unknown | unknown | 1 |
| Community Engagement | unknown | unknown | 1 |
| KJC Research | ivr_robopoll | media | 1 |
| YouGov | online_panel | unknown | 1 |
| YouGov | online_panel | pollster_self | 1 |
| EMRS | unknown | unknown | 1 |
| Engage Poll (New England Times) | unknown | media | 1 |

Totals by method: mrp 940, ivr_robopoll 82, mixed 32, online_panel 13, optin_link 2, unknown 141.
Totals by sponsor: pollster_self 791, media 265, advocacy_group 38, industry_lobby 17, party 11, union 2, unknown 86.

Still unknown: method 141 polls (11.7%); sponsor 86 polls (7.1%). Most unknown-method rows are 56 fed2016 polls with no firm named and the sponsor-labelled rows (Climate 200 x17, Industry Association x7, Sky News x6, Internal polling x5, United Workers Union, Laidlaw, Insightfully, JWS, Freshwater, DemosAU, RedBridge, EMRS, ER&C, Community Engagement, New England Times).

## Confidence: read this before fitting anything

- Only a minority of method labels are stated in a source I read. "high" is almost entirely the 788 MRP rows, where the label itself says MRP. Non-MRP "medium" and "low" labels are mostly my inference from the firm's usual practice and are unverified.
- Stated in a source: uComms = "self-completed automated voice methodology" (Australia Institute page, an ACT poll, so applied to uComms by assumption); KJC Wentworth 2022 = "Automated polling" (The Conversation); Compass Wentworth = "conducted by SMS" (Poll Bludger).
- Inferred, unverified: ReachTEL = automated phone; Galaxy/Newspoll = "mixed" (automated phone plus online, from memory, low); Utting = automated phone (low); YouGov seat polls other than MRP = online panel (low); YouGov 2022 (152 polls, no sample sizes) = MRP-style model (medium, from the shape of the data and the Herald Sun headline).
- Sponsor "high" only where a footnote says "Commissioned by" or "Sponsored by" (37 polls). The `client` column gives "medium" where present. News-outlet sponsors are mostly inferred from which outlet reported the poll ("low"): an outlet reporting a poll does not prove it paid for it.

## Dirty pollster labels resolved

- "Climate 200" (17 polls: 16 fed2025, 1 nsw2023) is a sponsor, not a firm. The firm is not named in the footnotes; Climate 200 polls were commonly run by uComms (unverified). Recorded as sponsor advocacy_group, pollster_clean unknown, method unknown.
- Blank pollster (87 fed2016 polls): the Wikipedia table has no firm column for these. Firm recovered only from footnote titles: 30 polls cite ReachTEL (medium), 1 Galaxy, 56 remain unknown. 44 are media-reported, 1 is an ALP poll.
- "44%" (fed2025, Brisbane, n=1,184): a parse error. It is the 2PP 56/44 cell of the uComms Brisbane poll for Liberals against Nuclear (n=1,184, 20 Mar 2025). It is a DUPLICATE of an existing uComms row, so that poll is counted twice in the 1,210.
- "YouGo (MRP)": typo of "YouGov (MRP)". "Redbridge", "Redbridge Group", "RedBridge" are one firm; "Freshwater" = Freshwater Strategy; "Unnamed" (Bullwinkel) was commissioned by the National Party.
- "Industry Association", "Internal polling", "United Workers Union", "Sky News" are sponsors or reporters, not firms. The nsw2023 "Sky News" rows are described as "leaked polling" with no firm or sponsor named.
- seat_polls.csv also contains 91 non-poll "event" rows (resignations etc.) in the pollster column; I excluded them (row_type != poll).

## Surprising or consequential

1. Compass Polling (McMahon, 8 Apr 2025, n=1,003, independent 41%): classified optin_link, medium. The "opt-in SMS link, preselected drop-down" detail comes from your brief (ABC Media Watch); I could not fetch it. Poll Bludger independently says Compass's Wentworth poll was "conducted by SMS" with undisclosed fieldwork date. No sponsor found for either (the Australian published them). Unverified: whether Compass sponsored these itself.
2. 940 of 1,210 polls (78%) are model estimates (MRP), so poll-method weights fitted on this file are mostly weights on MRP versus not. Only 270 rows are direct polls, and of those 141 have no known method.
3. YouGov 2022 (152 seat rows with no sample size) look like an MRP-type model for News Corp, not 152 separate polls. Medium confidence.
4. Sponsorship matters more than method in this data: 38 advocacy-group, 17 industry-lobby, 11 party, 2 union sponsored polls, including Australian Energy Producers (JWS, 8) and Climate 200 / Australia Institute (uComms). uComms alone appears under five different sponsors.
5. Two of the highest-profile rows are also the thinnest: Insightfully for Advance ("right-wing activist group", method and dates undisclosed per Poll Bludger) and Compass.

## Not done / unverified

- Not fetched: ABC Media Watch (404), The Australian, Sky News, Saturday Paper, Courier-Mail. Pollster practices marked "recalled" are my memory, not a source.
- Fed2010/2013 and the state elections have no seat-poll rows in this CSV, so were not classified.
- Row matching to the Wikipedia table was automatic; fed2016 polls sharing a seat and date were matched to the single best row and their footnotes may include a sibling poll's.
