# Statewide poll sample sizes from Wikipedia: coverage of the anchor poll files

Generated 2026-10-09 by `scripts/join_statewide_poll_samples.R` from `external/reference/polls/statewide-samples/statewide_polls_wiki.csv`
(built by `scripts/fetch_statewide_poll_samples.R`). Step 1 of `docs/plans/statewide-poll-weighting-scope-2026-10-09.md`.

Match rule: same region; firm agrees through `firm_alias.csv`; Wikipedia fieldwork end or middle within 4 days of the anchor `MidDate`; ALP and Coalition primary both within 0.5 points. Best candidate kept. All 6093 anchor rows are in `output/statewide-poll-samples.csv` (asserted).

Wikipedia side: 1836 voting-intention poll rows in headline tables (not sub-national, demographic, seat or upper-house tables); 727 have a sample size, 205 name a client.

**Read this first.** Wikipedia only has a dedicated statewide opinion-polling page for the elections in the first table below; for every earlier state election the main article carries no poll table, or a table with no sample column. So the gap is mostly Wikipedia not having the data, not the join failing (section 4 splits the two).

Pages that supplied poll rows (count of rows; `rows_with_n` = rows that show a sample size):

| page | headline_rows | rows_with_n |
|---|---|---|
| fed2013_opinion | 413 | 0 |
| fed2016_opinion | 232 | 35 |
| fed2019_opinion | 184 | 0 |
| fed2022_opinion | 138 | 116 |
| fed2025_opinion | 252 | 248 |
| fed2028_opinion | 188 | 188 |
| nsw2011_main | 37 | 0 |
| nsw2023_main | 22 | 0 |
| nsw2027_opinion | 27 | 22 |
| qld2015_main | 39 | 0 |
| qld2017_main | 31 | 0 |
| qld2020_main | 12 | 0 |
| qld2024_main | 23 | 23 |
| qld2028_opinion | 17 | 15 |
| sa2018_main | 23 | 0 |
| sa2022_main | 6 | 0 |
| sa2026_opinion | 16 | 16 |
| vic2014_main | 39 | 0 |
| vic2018_main | 25 | 0 |
| vic2022_opinion | 19 | 0 |
| vic2026_opinion | 57 | 57 |
| wa2017_main | 23 | 0 |
| wa2021_main | 6 | 0 |
| wa2025_main | 7 | 7 |

Dedicated opinion-polling pages that do not exist on Wikipedia (HTTP 404, checked 2026-10-09; the main election article was parsed instead): fed2007, vic2010, vic2014, vic2018, nsw2011, nsw2015, nsw2019, nsw2023, qld2012, qld2015, qld2017, qld2020, qld2024, wa2008, wa2013, wa2017, wa2021, wa2025, sa2010, sa2014, sa2018, sa2022.

Elections with NO headline voting-intention poll row on any page we could find (10): fed2007, fed2010, vic2010, nsw2015, nsw2019, qld2012, wa2008, wa2013, sa2010, sa2014.
Elections with poll rows but no sample size on any of them (14): fed2013, fed2019, nsw2011, nsw2023, qld2015, qld2017, qld2020, sa2018, sa2022, vic2014, vic2018, vic2022, wa2017, wa2021.
(fed2007: the 2010 federal page starts after the 2007 election, and `Opinion polling for the 2007 Australian federal election` is a 404. A Wikipedia poll row belongs to the election of the page it sits on, not the election cycle of its date.)

## 1. Coverage

Counts of anchor polls (rows in `poll-data-<region>.csv`) from 2007 onward, by election cycle (a cycle is the polls between the previous election and the one named). `matched` = a Wikipedia row found; `matched_with_sample_n` = that row shows a sample size. Higher is better; blanks mean no anchor polls.

| region | cycle | anchor_polls | matched | matched_with_sample_n | pct_matched | pct_with_sample_n |
|---|---|---|---|---|---|---|
| fed | fed2007 | 97 | 0 | 0 | 0% | 0% |
| fed | fed2010 | 293 | 3 | 0 | 1% | 0% |
| fed | fed2013 | 382 | 322 | 0 | 84% | 0% |
| fed | fed2016 | 312 | 168 | 28 | 54% | 9% |
| fed | fed2019 | 204 | 142 | 0 | 70% | 0% |
| fed | fed2022 | 303 | 91 | 90 | 30% | 30% |
| fed | fed2025 | 448 | 189 | 185 | 42% | 41% |
| fed | fed2028 | 175 | 70 | 70 | 40% | 40% |
| nsw | nsw2011 | 48 | 9 | 0 | 19% | 0% |
| nsw | nsw2015 | 68 | 0 | 0 | 0% | 0% |
| nsw | nsw2019 | 53 | 1 | 0 | 2% | 0% |
| nsw | nsw2023 | 32 | 10 | 0 | 31% | 0% |
| nsw | nsw2027 | 30 | 10 | 9 | 33% | 30% |
| qld | qld2012 | 49 | 2 | 0 | 4% | 0% |
| qld | qld2015 | 70 | 26 | 0 | 37% | 0% |
| qld | qld2017 | 63 | 18 | 0 | 29% | 0% |
| qld | qld2020 | 18 | 2 | 0 | 11% | 0% |
| qld | qld2024 | 30 | 12 | 12 | 40% | 40% |
| qld | qld2028 | 16 | 6 | 6 | 38% | 38% |
| sa | sa2010 | 23 | 0 | 0 | 0% | 0% |
| sa | sa2014 | 21 | 0 | 0 | 0% | 0% |
| sa | sa2018 | 41 | 7 | 0 | 17% | 0% |
| sa | sa2022 | 11 | 2 | 0 | 18% | 0% |
| sa | sa2026 | 15 | 9 | 9 | 60% | 60% |
| vic | vic2010 | 37 | 2 | 0 | 5% | 0% |
| vic | vic2014 | 68 | 20 | 0 | 29% | 0% |
| vic | vic2018 | 59 | 9 | 0 | 15% | 0% |
| vic | vic2022 | 36 | 13 | 0 | 36% | 0% |
| vic | vic2026 | 57 | 16 | 16 | 28% | 28% |
| wa | wa2008 | 27 | 0 | 0 | 0% | 0% |
| wa | wa2013 | 30 | 1 | 0 | 3% | 0% |
| wa | wa2017 | 45 | 9 | 0 | 20% | 0% |
| wa | wa2021 | 13 | 2 | 0 | 15% | 0% |
| wa | wa2025 | 15 | 7 | 7 | 47% | 47% |

Pooled by region, polls from 2010-01-01 onward:

| region | anchor_polls | matched | matched_with_sample_n | pct_matched | pct_with_sample_n |
|---|---|---|---|---|---|
| fed | 1922 | 985 | 373 | 51% | 19% |
| vic | 241 | 60 | 16 | 25% | 7% |
| nsw | 206 | 28 | 9 | 14% | 4% |
| qld | 220 | 66 | 18 | 30% | 8% |
| wa | 97 | 19 | 7 | 20% | 7% |
| sa | 95 | 18 | 9 | 19% | 9% |
| ALL | 2781 | 1176 | 432 | 42% | 16% |

Same, restricted to cycles where Wikipedia has a headline table at all (cycles with at least one Wikipedia poll row in the region):

| region | anchor_polls | matched | matched_with_sample_n | pct_matched | pct_with_sample_n |
|---|---|---|---|---|---|
| fed | 1824 | 982 | 373 | 54% | 20% |
| vic | 220 | 58 | 16 | 26% | 7% |
| nsw | 85 | 27 | 9 | 32% | 11% |
| qld | 197 | 64 | 18 | 32% | 9% |
| wa | 73 | 18 | 7 | 25% | 10% |
| sa | 67 | 18 | 9 | 27% | 13% |
| ALL | 2466 | 1167 | 432 | 47% | 18% |

Match quality of the matched rows (`exact` = date within a day and primaries within 0.05; `close` = within the 4-day / 0.5-point tolerance):

| match_quality | rows | median_date_gap_days | median_primary_gap_pts |
|---|---|---|---|
| exact | 1015 | 0 | 0 |
| close | 163 | 3 | 0 |

Anchor rows that share one Wikipedia row with another anchor row: 4 of 1178 matched rows (a Wikipedia poll can be echoed by two anchor firm labels).

## 2. Spread of sample size

Sample size (people interviewed) for anchor polls that matched a Wikipedia row showing one, polls from 2010 onward. `p10` and `p90` are the 10th and 90th percentiles, `p25` and `p75` bound the middle half (interquartile range). Larger n means a more precise poll.

| region | polls | median | p25 | p75 | p10 | p90 | min | max |
|---|---|---|---|---|---|---|---|---|
| fed | 373 | 1538 | 1404 | 1716 | 1115 | 2415 | 526 | 10239 |
| vic | 16 | 1112 | 1020 | 1669 | 1003 | 2014 | 920 | 3001 |
| nsw | 9 | 1088 | 1028 | 1123 | 1013 | 1175 | 1000 | 1293 |
| qld | 18 | 1040 | 1004 | 1124 | 937 | 1355 | 818 | 1724 |
| wa | 7 | 1000 | 913 | 1020 | 847 | 1103 | 800 | 1200 |
| sa | 9 | 1004 | 904 | 1057 | 894 | 1247 | 856 | 1265 |
| ALL | 432 | 1516 | 1243 | 1697 | 1033 | 2260 | 526 | 10239 |

By firm (canonical firm name from the alias table), the 12 firms with the most sample sizes, polls from 2010 onward:

| firm_group | polls | median | p25 | p75 | p10 | p90 | min | max |
|---|---|---|---|---|---|---|---|---|
| newspoll | 110 | 1506 | 1245 | 1524 | 1223 | 1663 | 1000 | 4135 |
| roymorgan | 97 | 1687 | 1564 | 1947 | 1383 | 2788 | 526 | 3174 |
| resolve | 55 | 1606 | 1601 | 1632 | 1109 | 2006 | 924 | 4728 |
| yougov | 44 | 1502 | 1500 | 1521 | 1500 | 1576 | 1004 | 8732 |
| redbridge | 31 | 1205 | 1008 | 2008 | 1001 | 2039 | 818 | 6015 |
| demosau | 27 | 1238 | 1022 | 1526 | 1005 | 1949 | 903 | 4100 |
| freshwater | 26 | 1053 | 1047 | 1062 | 1020 | 1087 | 1000 | 1384 |
| reachtel | 10 | 2414 | 2364 | 2544 | 2166 | 2757 | 2084 | 3274 |
| essential | 8 | 1760 | 1618 | 1776 | 1163 | 1786 | 1050 | 1790 |
| foxhedgehog | 7 | 1608 | 1004 | 1662 | 962 | 1744 | 904 | 1810 |
| wolfsmith | 6 | 1363 | 909 | 1949 | 867 | 6132 | 856 | 10239 |
| galaxy | 2 | 1754 | 1746 | 1761 | 1742 | 1765 | 1739 | 1768 |

Share of those polls under 500, 500 to 999, 1000 to 1499, 1500 and over (pooled, 2010 onward):

| polls | under_500 | n500_999 | n1000_1499 | n1500_plus |
|---|---|---|---|---|
| 432 | 0 | 11 | 146 | 275 |

## 3. Sponsor / client coverage

Of the matched anchor polls from 2010 onward, how many carry a client (the organisation that paid for the poll): from the Wikipedia `Client` column, or from a footnote saying 'commissioned by'. Higher is better.

| region | matched_polls | with_client | pct |
|---|---|---|---|
| fed | 985 | 60 | 6% |
| vic | 60 | 10 | 17% |
| nsw | 28 | 5 | 18% |
| qld | 66 | 1 | 2% |
| wa | 19 | 0 | 0% |
| sa | 18 | 0 | 0% |
| ALL | 1176 | 76 | 6% |

Of all anchor polls from 2010 onward (matched or not):

| anchor_polls | with_client | pct |
|---|---|---|
| 2781 | 76 | 3% |

Most common clients among matched polls:

| client | polls |
|---|---|
| The Australian | 13 |
| Sky News Australia | 10 |
| Australian Financial Review | 10 |
| Sydney Morning Herald/The Age | 8 |
| Capital Brief | 8 |
| Herald Sun | 6 |
| News24 | 5 |
| The Daily Telegraph | 3 |
| Sydney Morning Herald | 3 |
| The Australia Institute | 2 |
| The Age | 2 |
| News Australia | 1 |
| The Courier Mail | 1 |
| The Chronicle | 1 |
| Amplify | 1 |

## 4. The 20 largest unmatched groups

Unmatched anchor polls from 2010 onward, grouped by region, firm and election cycle; `reason` is the most common cause in the group. Reasons, in the order tested: no Wikipedia poll table covers the date (within 45 days); the firm never appears on Wikipedia for that region; the firm is there but has no poll within 4 days; same firm and date but the primaries differ by more than 0.5 points.

| region | firm | cycle | unmatched | reason | share_with_that_reason |
|---|---|---|---|---|---|
| fed | Morning Consult | fed2022 | 115 | anchor ALP or Coalition primary missing | 100% |
| fed | Morning Consult | fed2025 | 98 | anchor ALP or Coalition primary missing | 100% |
| fed | Essential | fed2016 | 78 | anchor ALP or Coalition primary missing | 38% |
| fed | Essential | fed2022 | 76 | same firm and date on Wikipedia, but ALP/Coalition primary differ by more than 0.5 | 55% |
| fed | Morgan multi-mode | fed2025 | 75 | firm is on Wikipedia but has no poll within 4 days of this date | 83% |
| fed | Essential | fed2025 | 64 | same firm and date on Wikipedia, but ALP/Coalition primary differ by more than 0.5 | 88% |
| fed | Essential | fed2013 | 41 | anchor ALP or Coalition primary missing | 83% |
| fed | Morgan multi-mode | fed2028 | 41 | same firm and date on Wikipedia, but ALP/Coalition primary differ by more than 0.5 | 54% |
| fed | Essential | fed2019 | 38 | same firm and date on Wikipedia, but ALP/Coalition primary differ by more than 0.5 | 47% |
| fed | Morgan multi-mode | fed2016 | 36 | firm is on Wikipedia but has no poll within 4 days of this date | 94% |
| fed | F2F Morgan | fed2010 | 24 | no Wikipedia poll table covers this date | 79% |
| fed | Essential | fed2010 | 22 | anchor ALP or Coalition primary missing | 41% |
| nsw | Essential | nsw2019 | 22 | no Wikipedia poll table covers this date | 95% |
| qld | Essential | qld2017 | 22 | firm never appears on the Wikipedia pages for this region | 100% |
| vic | Essential | vic2018 | 21 | firm is on Wikipedia but has no poll within 4 days of this date | 62% |
| nsw | Newspoll | nsw2015 | 19 | no Wikipedia poll table covers this date | 100% |
| vic | ResolvePM | vic2026 | 19 | firm is on Wikipedia but has no poll within 4 days of this date | 63% |
| sa | SMS Morgan | sa2018 | 18 | firm is on Wikipedia but has no poll within 4 days of this date | 83% |
| fed | Newspoll | fed2010 | 17 | no Wikipedia poll table covers this date | 71% |
| vic | Essential | vic2014 | 17 | firm is on Wikipedia but has no poll within 4 days of this date | 94% |

Why every unmatched anchor poll from 2010 onward is unmatched:

| reason | polls |
|---|---|
| firm is on Wikipedia but has no poll within 4 days of this date | 617 |
| anchor ALP or Coalition primary missing | 366 |
| no Wikipedia poll table covers this date | 323 |
| same firm and date on Wikipedia, but ALP/Coalition primary differ by more than 0.5 | 238 |
| firm never appears on the Wikipedia pages for this region | 61 |

The first and third reasons mean no match is possible (no Wikipedia table for that date, or the anchor row has no primary vote to compare). The second is most likely Wikipedia not listing that poll, but can also be a date convention difference between the two sources. The fourth and fifth are the only ones that could be join or alias gaps; spot-check them before trusting the rule is too strict.

## 5. Spot-check: 10 random matched rows, anchor beside Wikipedia

Five random matched national rows and five random matched state rows (seed 20261009). `anchor` columns come from the poll file, `wiki` columns from the Wikipedia row it was matched to. Check that the firm, the dates and the two primaries agree.

| region | anchor_date | anchor_firm | anchor_ALP | anchor_Coalition | wiki_page | wiki_dates | wiki_firm | wiki_ALP | wiki_Coalition | sample | n | client | quality |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| fed | 2016-01-21 | ReachTEL | 31.8 | 48.5 | fed2016_opinion | 21 Jan 2016 | ReachTEL | 31.8 | 48.5 |  |  |  | exact |
| fed | 2011-05-28 | Newspoll | 34 | 44 | fed2013_opinion | 27–29 May 2011 | Newspoll | 34 | 44 |  |  |  | exact |
| fed | 2013-06-14 | Nielsen | 29 | 47 | fed2013_opinion | 13–15 Jun 2013 | Nielsen | 29 | 47 |  |  |  | exact |
| fed | 2014-03-08 | Newspoll | 35 | 41 | fed2016_opinion | 7–9 Mar 2014 | Newspoll | 35 | 41 |  |  |  | exact |
| fed | 2026-07-29 | Redbridge | 29 | 22 | fed2028_opinion | 27–30 Jul | RedBridge/Accent | 29 | 22 | 1,001 | 1001 | Australian Financial Review | exact |
| vic | 2024-03-17 | Redbridge | 36 | 38 | vic2026_opinion | 14–20 Mar 2024 | RedBridge/Accent | 36 | 38 | 1,559 | 1559 | Herald Sun | exact |
| vic | 2025-11-23 | Freshwater | 30 | 37 | vic2026_opinion | 21–24 Nov 2025 | Freshwater | 30 | 37 | 1,220 | 1220 | Herald Sun | exact |
| qld | 2014-10-26 | SMS Morgan | 38.5 | 38 | qld2015_main | 24–27 Oct 2014 | Roy Morgan | 38 | 38.5 |  |  |  | close |
| sa | 2025-05-22 | YouGov2 | 48 | 21 | sa2026_opinion | 15–28 May 2025 | YouGov | 48 | 21 | 1,004 | 1004 |  | exact |
| qld | 2014-05-23 | Galaxy | 34 | 43 | qld2015_main | 21–22 May 2014 | Galaxy | 34 | 43 |  |  |  | exact |

---
Row-level detail: `output/statewide-poll-samples.csv`; alias table: `external/reference/polls/statewide-samples/firm_alias.csv`; pages tried: `external/reference/polls/statewide-samples/pages_manifest.csv`.
