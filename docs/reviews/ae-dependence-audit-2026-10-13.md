# How much of the poll data still comes from AE? (2026-10-13)

Pete, 2026-10-13: *"remember the end game is to move off AE data so if you have fallbacks to it we need to improve
the parser to actually fix whats going wrong"*. Measured under the shipped layered source (PR #124) with
`scripts/audit_ae_dependence.R` (provenance recorded by `poll_layer()`), over the 22 scored elections plus the live
cycles vic2026 and nsw2027 (fed2028 is not scored). Output: `output/ae-dependence-audit.csv`.

## Headline

3,099 polls in those cycles. **1,280 (41%) carry only our numbers**; in the final 30 days before polling day,
103 of 253 (41%).

| why AE is still needed | whole cycles | final 30 days | fix |
|---|---|---|---|
| poll missing from Wikipedia, in an election Wikipedia covers | 1,071 | 79 | first find out how many are on the page but dropped by our parser (parser) vs genuinely absent (Poll Bludger, original releases) |
| election Wikipedia effectively does not cover (fewer than 5 of our polls: fed2007, nsw2019, wa2001-2013) | 491 | 30 | another source: Poll Bludger posts, archived releases |
| a party Wikipedia folds into Others (UAP 183, NXT 59, ON 12, other 5) | 250 | 39 | original releases or Poll Bludger; or accept: these are small parties the federal tables never broke out |
| disputes AE won, or ours failed its own two-party check | 7 | 2 | parser |
| firm label from AE (methodology eras set house effects) | 2,975 | 244 | our own era rules (Newspoll 2015 switch to online, Morgan modes, YouGov/Newspoll) |

The parser errors that Pete asked about are the smallest bucket (7 polls). The large one is coverage.

## By election

Columns: polls in the cycle; ours = numbers entirely ours; missing / no_wiki / filled / disputes = AE-dependent
by cause; last column = final-30-day polls still needing AE (share).

| election | polls | ours | missing | no wiki | AE filled a party | disputes + suspect | final 30 days needing AE |
|---|---|---|---|---|---|---|---|
| wa2017 | 49 | 7 | 36 | 0 | 6 | 0 | 6 (100%) |
| sa2022 | 15 | 4 | 10 | 0 | 1 | 0 | 3 (100%) |
| wa2025 | 15 | 7 | 8 | 0 | 0 | 0 | 2 (100%) |
| fed2007 | 234 | 1 | 0 | 233 | 0 | 0 | 18 (95%) |
| fed2010 | 293 | 65 | 227 | 0 | 0 | 1 | 21 (78%) |
| nsw2019 | 53 | 1 | 0 | 52 | 0 | 0 | 3 (75%) |
| fed2019 | 221 | 132 | 43 | 0 | 46 | 0 | 12 (75%) |
| vic2018 | 67 | 16 | 50 | 0 | 1 | 0 | 5 (71%) |
| fed2025 | 452 | 230 | 201 | 0 | 21 | 0 | 20 (69%) |
| wa2001 | 44 | 1 | 0 | 43 | 0 | 0 | 2 (67%) |
| wa2008 | 64 | 2 | 0 | 62 | 0 | 0 | 4 (67%) |
| fed2016 | 346 | 113 | 116 | 0 | 116 | 1 | 12 (60%) |
| qld2020 | 27 | 11 | 16 | 0 | 0 | 0 | 3 (60%) |
| wa2005 | 65 | 2 | 0 | 62 | 0 | 1 | 2 (50%) |
| wa2013 | 30 | 2 | 0 | 28 | 0 | 0 | 1 (50%) |
| vic2014 | 70 | 21 | 49 | 0 | 0 | 0 | 6 (50%) |
| vic2022 | 43 | 17 | 24 | 0 | 2 | 0 | 4 (50%) |
| fed2013 | 441 | 394 | 31 | 0 | 14 | 2 | 15 (47%) |
| fed2022 | 304 | 96 | 167 | 0 | 40 | 1 | 7 (35%) |
| wa2021 | 14 | 3 | 0 | 11 | 0 | 0 | 1 (33%) |
| sa2026 | 26 | 19 | 5 | 0 | 2 | 0 | 2 (22%) |
| qld2024 | 35 | 15 | 19 | 0 | 1 | 0 | 1 (20%) |
| nsw2023 | 43 | 21 | 22 | 0 | 0 | 0 | 0 (0%) |
| nsw2027 | 52 | 32 | 19 | 0 | 0 | 1 | 0 (0%) |
| vic2026 | 96 | 68 | 28 | 0 | 0 | 0 | 0 (0%) |

Worst in the final month: wa2017, sa2022 and wa2025 (every final-month poll needs AE), fed2007 (19 of 19 bar one),
fed2010 (21 of 27). vic2026 and nsw2027, the live ones, need AE for nothing in the final 30 days so far.

## Next

1. Split "missing" (1,071) into on-the-page-but-dropped vs not-on-Wikipedia, by searching every parsed table and the
   raw page text for each AE-only poll's firm and date. That sizes parser work against source work.
2. Then the sources: Poll Bludger's per-poll posts first (they quote full primaries), original releases where those fail.
3. Firm eras: write our own label rules, test that house effects are no worse (a screen, then the deciding run).

## Update, same night: the split found a parser bug, now fixed

`scripts/audit_ae_missing.R` looked for each AE-only poll in every parsed row. 146 of them (39 in the final 30 days)
were on the page but typed "result": the scraper tested the firm cell for the word "election" before stripping its
footnotes, so "conducted ahead of the 2013 federal election" made a real poll a result. Fixed
(`scripts/fetch_statewide_poll_samples.R`): result rows 768 -> 110, vic2026 page 118 -> 158 polls.

After the fix: 1,426 of 3,136 polls (45%) carry only our numbers; **final 30 days 140 of 261 (54%)**. AE still
needed (whole cycles | final 30 days): missing from a covered page 935 | 39 (770 | 37 in no parsed table at all:
Essential, Morning Consult and Morgan's modes lead), no Wikipedia coverage 480 | 29, a party folded into Others
284 | 50 (UAP 213, NXT 62, ON 18), disputes and suspect rows 11 | 3.

Effect: live Victoria One Nation 18.08 -> 18.20 seats (the recovered polls were in AE already); day-before level
screen 2.071 -> 2.074 (max cell move 1.33, wa2021, unscored). Pushed without a new deciding run; the next
publish rebuild re-scores with these rows.

Also (Pete asked): AE's repo calls its poll files "authored inputs", committed as "routine data update", with no
source, sample size or client per poll; `provenance.json` holds file checksums only. Its numbers cannot be traced
to a source, which is how the swapped RedBridge row went unnoticed.

## Poll Bludger as the replacement source (checked 2026-10-13)

The target: 71 final-month polls still carrying AE's numbers (`deciding-runs/ae-final-month-polls.csv`): fed2007 18,
fed2010 21, the rest single digits per election (vic2018 4, wa2008 4, fed2022 4, nsw2019 3 ...). 12 of the 71 are
two-party-only rows in AE (Morning Consult, Ipsos, some Essential) that do not feed the primary trend anyway.

What Poll Bludger has, checked by hand:
- **2018 on (pollbludger.net day archives, e.g. `/2018/11/22/`):** full primaries in the post text. Vic 21 Nov 2018:
  "YouGov Galaxy ... Both parties on 40% primary; Greens 11%" (AE has the same), uComms/ReachTEL "Labor 39%,
  Coalition 36%, Greens 10.4%", n = 1,239 (AE has 40.8 / 37.8: undecided divided out).
- **2007 (the same site, day archives back to at least November 2007):** posts exist for the final-month polls
  ("Newspoll: 52-48", "Morgan: 54.5-45.5", "Galaxy: 52-48 in marginals"), but primaries are often missing at the
  time of the post: the 23 Nov 2007 Newspoll post says "a sample size of 2614, but no primary votes".
- The Wayback Machine refused requests (HTTP 429), and the old Crikey blog address does not resolve.

So Poll Bludger is free text. Plan: fetch every day archive page in each cycle's final 90 days (about 2,250 pages,
about 40 minutes at one request a second), store the raw HTML, extract firm, fieldwork, sample and primaries from
each post, and measure the extractor on the polls AE also has (AE as the answer key, before AE is dropped).
Tally Room does not publish polls.

## Poll Bludger fetched and scored (2026-10-13, later)

**Fetch** (`scripts/fetch_pollbludger.R`): the site's five post sitemaps list all 4,935 posts back to July 2004, so
only days with posts are requested. Each election's final 90 days: 1,890 posts on 1,302 day pages, all fetched
(1,890 of 1,890 sitemap posts found on the pages), 25 minutes. Raw pages in
`external/reference/polls/pollbludger/raw/days/`, manifest `days_manifest.csv`.

**BludgerTrack poll tables** (`scripts/extract_bludgertrack.R`): BludgerTrack's "Poll data" tab is a structured table
(start, end, pollster, mode, sample, primaries, undecided, published and respondent-allocated two-party, plus state,
age, gender and other breakdowns) for three cycles only: fed2025 (345 national polls, May 2022 to May 2025),
fed2028 (to 31 Aug 2026) and vic2026 (63 polls). Older cycles return 404; the 2019 file holds weekly trend points,
not polls. Against the layered set it agrees almost exactly where both have a poll (424 federal polls carrying our
Wikipedia numbers: mean gap 0.06 points), and it has 66 of the 195 polls in those cycles that still carry AE's
numbers (fed 55 of 175, vic 11 of 20).

**Bug it found, fixed:** `wiki_polls()` let sub-state tables (Inner Melbourne, Outer Melbourne, Regional SA,
Brisbane), Legislative Council tables, "Voting consideration" and "Leader satisfaction" tables through as statewide
polls: 85 rows on the sa2026, vic2026, nsw2027, qld2028 and fed2028 pages. Example: DemosAU Inner Melbourne, Feb
2026, Greens 23, read as a statewide Greens 23. Fixed in `R/poll_source.R` (test `test-wiki-polls-sections.R`, which
fails on the old list). Effect: day-before level screen 2.074 -> 2.072; only sa2026 moves (Labor error 0.99 -> 0.23,
Greens 1.12 -> 1.50, Coalition 2.41 -> 2.27). Live trend, before -> after: Vic ON 21.03 -> 20.77, ALP 24.44 ->
24.58 (polls in trend 102 -> 82); NSW ON 20.68 -> 22.21, ALP 31.54 -> 30.54 (56 -> 48). The next publish rebuild
re-scores sa2026.

**Also found, not fixed:** Wikipedia folds Essential's undecided (about 5%) into Others on the fed2028 page, so our
13 Essential rows since May 2025 understate every party by about 5% of its share. BludgerTrack carries undecided
separately and is the fix.

**Post extractor** (`scripts/extract_pollbludger.R`, rules, version 3): one sentence at a time, pollster carried
from earlier in the paragraph or the title, region from the post's WordPress categories, and sentences about
subgroups, seats, exit polls, upper houses, issue questions or earlier polls skipped. Tuned on pages up to
2017-03-05; pages after that held out.

| pages | polls matched to the layered set | every party within 0.5 point | any party off by more than 2 |
|---|---|---|---|
| tuning (2004 to Mar 2017) | 174 | 146 (84%) | 14 (8%) |
| held out (2017 to 2026) | 134 | 111 (83%) | 12 (9%) |

Coverage of each election's final 30 days: 151 of 285 polls found (53%); of the 98 still carrying AE's numbers,
40 found (fed2007 9 of 18, fed2010 10 of 18, nsw2015 10 of 14, fed2004 1 of 20). Several of the disagreements
look like AE and Poll Bludger reporting different numbers for the same poll (Galaxy Vic Oct 2010 with Nationals
added, Lonergan NSW Mar 2015); not checked against the original releases.

**Reading:** the rules find about half the polls and get about 1 in 11 wrong by more than 2 points, so their
numbers cannot replace AE's unchecked. They can serve as a third opinion on disputes and as a source for polls
nobody else has, under the same two-party self-check our Wikipedia rows get. Reading the posts with a language
model instead of rules is the stronger version and has not been tried (no API key on this machine; it would run
as subagents).

## BludgerTrack joined the layered source; poll registry built (2026-10-13, Pete: "go")

`AUSPOL_POLL_BT=1` (`R/poll_source.R`): BludgerTrack's tables (`scripts/build_bludgertrack_polls.R`) join our
Wikipedia rows before the AE layer. A poll both have keeps BludgerTrack's row (undecided divided out on every poll;
fixes the Essential rows); a poll only BludgerTrack has is added. Federal: 506 BludgerTrack polls, 440 also on
Wikipedia, 66 not. Victoria: 62, 52 and 10.

**Duplicate polls found and fixed on the way:** Resolve's two-month Victorian polls are dated 14-29 days apart by
Wikipedia, AE and BludgerTrack, so the 4-day window counted them twice; this was already true in the shipped set
(Resolve Vic 24/41 twice, AE's 1 Mar 2025 and Wikipedia's 30 Mar). New rule (`.ps_same_poll_far()`): one firm's rows
with the same primaries within 0.5 point and up to 31 days apart are one poll. Live Vic polls in the trend 82 -> 70.

Day-before level screen (lower is better): 2.072 -> 2.058, mostly the duplicate rule in older elections (vic2014
Greens error 3.43 -> 3.13, Coalition 2.55 -> 2.25; qld2020 slightly worse, Coalition 0.14 -> 0.30). Live Vic trend:
One Nation 20.79 -> 20.68 with BludgerTrack, everything else within 0.05. Not yet re-scored on seats: the next
publish rebuild does it.

**Poll registry** (`docs/POLL-REGISTRY.md`, generated by `scripts/build_poll_registry.R`): per election, every poll
the trend reads by whose numbers it carries. Scored elections, final 30 days: 232 polls, AE's numbers on 56 (24%);
whole cycles: 2,575 polls, AE's numbers on 940 (37%), almost all in fed2007, fed2010, nsw2019 and WA 2001-2013.
