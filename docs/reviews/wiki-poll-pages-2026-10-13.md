# Wikipedia poll pages by election, 2000 to next scheduled (generated 2026-10-13)

This lists, for each Australian election, which Wikipedia articles hold voting-intention poll tables and how many poll rows they hold; more rows means more coverage, and the last column says what `scripts/fetch_statewide_poll_samples.R` is missing.

Method: the MediaWiki API (`action=parse`, one request a second) fetched every candidate article and counted `<table>` elements from the page HTML itself. A table is a voting-intention (VI) table when its header names 2+ parties and a date or poll-wording column, and it is not a leader/approval, seat or sub-state table. Row counts are approximate (rowspans and footnote rows are not handled; the scraper's own count sometimes differs, e.g. wa2025 22 vs ~10). Page discovery used `list=allpages` on every title prefix beginning "Opinion polling", "Electorate opinion polling" and "Leadership approval" plus per-election `list=search`, so the title list below is complete for those prefixes; other prefixes and split pages with unusual names are not confirmed absent. Per-page data: `deciding-runs/wiki-poll-pages-2026-10-13.csv`.

Key structural finding: Wikipedia has only a few dedicated polling pages (federal 2010 to next, the Tasmanian 2025, NT 2020, SA 2026, Victoria 2026, NSW 2027 and Queensland 2028 pages, plus the federal electorate pages and one federal leadership page). Every other state or territory election has its poll tables only inside the main election article. The "Opinion polling for the 2011/2015/2019/2023 NSW" style titles the scraper tried do not exist.

| Election | Best page(s) with VI tables | Approx poll rows (statewide VI, summed) | What the scraper is missing |
|---|---|---|---|
| fed2001 | no table | 0 | - |
| fed2004 | no table (prose/graphs only) | 0 | - |
| fed2007 | no table (prose/graphs only) | 0 | - |
| fed2010 | Opinion polling for the 2010 Australian federal election (2 VI tbl, ~71 rows) | 71 | ok (counts comparable) |
| fed2013 | Opinion polling for the 2013 Australian federal election (3 VI tbl, ~430 rows) | 430 | ok (counts comparable) |
| fed2016 | Opinion polling for the 2016 Australian federal election (1 VI tbl, ~254 rows) | 254 | ok (counts comparable) |
| fed2019 | Opinion polling for the 2019 Australian federal election (1 VI tbl, ~199 rows) | 199 | seat/leader page 'Electorate opinion polling for the 2019 Austr' not scraped as statewide (flag only) |
| fed2022 | Opinion polling for the 2022 Australian federal election (8 VI tbl, ~402 rows) | 402 | ok (counts comparable) |
| fed2025 | Opinion polling for the 2025 Australian federal election (14 VI tbl, ~588 rows) | 588 | seat/leader page 'Electorate opinion polling and projections fo' not scraped as statewide (flag only) |
| fed2028 | Opinion polling for the next Australian federal election (40 VI tbl, ~807 rows) | 807 | seat/leader page 'Electorate opinion polling and projections fo' not scraped as statewide (flag only) |
| nsw2003 | no table | 0 | - |
| nsw2007 | no table | 0 | - |
| nsw2011 | 2011 New South Wales state election (1 VI tbl, ~37 rows) | 37 | ok (counts comparable) |
| nsw2015 | no table (prose/graphs only) | 0 | - |
| nsw2019 | no table | 0 | - |
| nsw2023 | 2023 New South Wales state election (1 VI tbl, ~29 rows) | 29 | ok (counts comparable) |
| nsw2027 | Opinion polling for the 2027 New South Wales state election (4 VI tbl, ~39 rows) | 39 | ok (counts comparable) |
| vic2002 | no table | 0 | - |
| vic2006 | 2006 Victorian state election (1 VI tbl, ~11 rows) | 11 | '2006 Victorian state election' never fetched or not in manifest |
| vic2010 | 2010 Victorian state election (1 VI tbl, ~23 rows) | 23 | ok (counts comparable) |
| vic2014 | 2014 Victorian state election (1 VI tbl, ~49 rows) | 49 | ok (counts comparable) |
| vic2018 | 2018 Victorian state election (1 VI tbl, ~45 rows) | 45 | ok (counts comparable) |
| vic2022 | 2022 Victorian state election (1 VI tbl, ~32 rows) | 32 | ok: scraper already has it via the "Opinion polling for the 2022 Victorian state election" redirect (manifest vic2022_opinion, 71 rows) |
| vic2026 | Opinion polling for the 2026 Victorian state election (20 VI tbl, ~126 rows) | 126 | ok (counts comparable) |
| qld2001 | no table | 0 | - |
| qld2004 | no table | 0 | - |
| qld2006 | 2006 Queensland state election (1 VI tbl, ~14 rows) | 14 | '2006 Queensland state election' never fetched or not in manifest |
| qld2009 | 2009 Queensland state election (1 VI tbl, ~13 rows) | 13 | '2009 Queensland state election' never fetched or not in manifest |
| qld2012 | 2012 Queensland state election (1 VI tbl, ~11 rows) | 11 | ok (counts comparable) |
| qld2015 | 2015 Queensland state election (1 VI tbl, ~49 rows) | 49 | ok (counts comparable) |
| qld2017 | 2017 Queensland state election (1 VI tbl, ~40 rows) | 40 | ok (counts comparable) |
| qld2020 | 2020 Queensland state election (1 VI tbl, ~16 rows) | 16 | ok (counts comparable) |
| qld2024 | 2024 Queensland state election (1 VI tbl, ~29 rows) | 29 | ok (counts comparable) |
| qld2028 | Opinion polling for the 2028 Queensland state election (6 VI tbl, ~27 rows) | 27 | ok (counts comparable) |
| sa2002 | no table | 0 | - |
| sa2006 | 2006 South Australian state election (2 VI tbl, ~18 rows) | 18 | '2006 South Australian state election' never fetched or not in manifest |
| sa2010 | 2010 South Australian state election (1 VI tbl, ~24 rows) | 24 | ok (counts comparable) |
| sa2014 | 2014 South Australian state election (1 VI tbl, ~14 rows) | 14 | ok (counts comparable) |
| sa2018 | 2018 South Australian state election (1 VI tbl, ~28 rows) | 28 | ok (counts comparable) |
| sa2022 | 2022 South Australian state election (1 VI tbl, ~12 rows) | 12 | ok (counts comparable) |
| sa2026 | Opinion polling for the 2026 South Australian state election (2 VI tbl, ~20 rows); 2026 South Australian state election (1 VI tbl, ~10 rows) | 30 | in manifest but 0 rows, page has ~10 |
| wa2001 | no table | 0 | - |
| wa2005 | 2005 Western Australian state election (1 VI tbl, ~17 rows) | 17 | ok (counts comparable) |
| wa2008 | 2008 Western Australian state election (1 VI tbl, ~16 rows) | 16 | ok (counts comparable) |
| wa2013 | 2013 Western Australian state election (1 VI tbl, ~17 rows) | 17 | ok (counts comparable) |
| wa2017 | 2017 Western Australian state election (1 VI tbl, ~25 rows) | 25 | ok (counts comparable) |
| wa2021 | 2021 Western Australian state election (1 VI tbl, ~8 rows) | 8 | ok (counts comparable) |
| wa2025 | 2025 Western Australian state election (1 VI tbl, ~10 rows) | 10 | ok (counts comparable) |
| tas2002 | no table | 0 | - |
| tas2006 | no table | 0 | - |
| tas2010 | 2010 Tasmanian state election (1 VI tbl, ~8 rows) | 8 | '2010 Tasmanian state election' never fetched or not in manifest |
| tas2014 | 2014 Tasmanian state election (1 VI tbl, ~18 rows) | 18 | '2014 Tasmanian state election' never fetched or not in manifest |
| tas2018 | 2018 Tasmanian state election (1 VI tbl, ~26 rows) | 26 | '2018 Tasmanian state election' never fetched or not in manifest |
| tas2021 | 2021 Tasmanian state election (1 VI tbl, ~16 rows) | 16 | '2021 Tasmanian state election' never fetched or not in manifest |
| tas2024 | 2024 Tasmanian state election (1 VI tbl, ~15 rows) | 15 | '2024 Tasmanian state election' never fetched or not in manifest |
| tas2025 | Opinion polling for the 2025 Tasmanian state election (8 VI tbl, ~42 rows) | 42 | 'Opinion polling for the 2025 Tasmanian state election' never fetched or not in manifest |
| nt2001 | no table | 0 | - |
| nt2005 | no table | 0 | - |
| nt2008 | no table | 0 | - |
| nt2012 | no table | 0 | - |
| nt2016 | 2016 Northern Territory general election (1 VI tbl, ~3 rows) | 3 | '2016 Northern Territory general election' never fetched or not in manifest |
| nt2020 | Opinion polling for the 2020 Northern Territory general election (6 VI tbl, ~23 rows) | 23 | 'Opinion polling for the 2020 Northern Territory general election' never fetched or not in manifest |
| nt2024 | 2024 Northern Territory general election (1 VI tbl, ~4 rows) | 4 | '2024 Northern Territory general election' never fetched or not in manifest |
| act2001 | no table | 0 | - |
| act2004 | no table | 0 | - |
| act2008 | no table | 0 | - |
| act2012 | no table | 0 | - |
| act2016 | no table | 0 | - |
| act2020 | 2020 Australian Capital Territory election (6 VI tbl, ~4 rows) | 4 | '2020 Australian Capital Territory election' never fetched or not in manifest |
| act2024 | no table | 0 | - |
| act2028 | Next Australian Capital Territory election (1 VI tbl, ~2 rows) | 2 | 'Next Australian Capital Territory election' never fetched or not in manifest |
| nt2028 | no table | 0 | - |
| wa2029 | 2029 Western Australian state election (1 VI tbl, ~5 rows) | 5 | '2029 Western Australian state election' never fetched or not in manifest |
| tas2029 | no table | 0 | - |

## Elections where Wikipedia has NO usable poll table

No table at all (no poll section, or the article does not mention polls): fed2001, nsw2003, nsw2007, nsw2019, vic2002, qld2001, qld2004, sa2002, wa2001, tas2002, tas2006, nt2001, nt2005, nt2008, nt2012, act2001, act2004, act2008, act2012, act2016, act2024, nt2028, tas2029.

Thin (6 rows or fewer, includes the election-result row): nt2016, nt2024, act2020, act2028, wa2029.

Polls appear only as prose and/or graph images (not scrapable as rows): fed2004, fed2007, nsw2015.

Note: ACT and NT articles are redirect-resolved ("Australian Capital Territory election" holds all ACT years); NT 2016/2024 and ACT 2020 main articles contain 3 to 5 small tables flagged VI that need a manual look. Extra rows act2028, nt2028, wa2029, tas2029 are beyond the requested list: act2028 and wa2029 have pages with a stub table; nt2028 and tas2029 resolve to non-election pages or do not exist.

Not confirmed: "Results of the ..." articles were not fetched (they rarely hold polls); heading-text heuristics may misclassify a table (seat vs statewide), so spot-check before relying on a single count; pages that only exist as redirects to a section (e.g. 2022 Victorian) are listed under the target article.

## Parser extended (2026-10-13)

`scripts/fetch_statewide_poll_samples.R` now reads the older Wikipedia layouts. The run ends with no TBL2/TBL3 errors (the 11 lost tables are parsed). Counts below are poll rows (result rows such as "2006 election" excluded). "Statewide VI" is a primary-vote table that counts as a statewide poll; "seat" and "leader" rows are kept raw but typed so the statewide join cannot use them. Higher is better for parsed rows; the sweep column is the approximate count above.

| Page | Sweep approx | Poll rows parsed | Statewide VI | Seat / region | Leader or other | Pollster comes from |
|---|---|---|---|---|---|---|
| vic2006_main | 11 | 10 | 10 | 0 | 0 | "Source: Newspoll" row |
| qld2006_main | 14 | 12 | 12 | 0 | 0 | not stated anywhere in the table (firm_from = not_stated) |
| qld2009_main | 13 | 21 | 11 | 0 | 10 | footer "Polling conducted by" (Newspoll) |
| sa2006_main | 18 | 22 | 14 | 0 | 8 | "Source:" rows (Newspoll, Roy Morgan) |
| tas2010_main | 8 | 13 | 8 | 0 | 5 | firm column (already parsed) |
| tas2014_main | 18 | 17 | 17 | 0 | 0 | footer (EMRS) |
| tas2018_main | 26 | 25 | 25 | 0 | 0 | firm column |
| tas2021_main | 16 | 15 | 15 | 0 | 0 | firm column |
| tas2024_main | 15 | 23 | 14 | 0 | 9 | firm column |
| nt2016_main | 3 | 12 | 2 | 7 | 3 | row footnote "NT News" where present, else not_stated (4 rows) |
| nt2020_opinion | 23 | 13 | 5 | 5 | 3 | firm column |
| nt2024_main | 4 | 2 | 2 | 0 | 0 | firm column |
| act2020_main | 4 | 2 | 2 | 0 | 0 | firm column |
| sa2026_main | ~10 | 0 | 0 | 0 | 0 | none: its polls are on sa2026_opinion (40 rows); this page's tables are results |

What changed: a blank first header cell with a "Political parties" or "Firm" group row now marks the date column; the pollster is taken from a "Source:" row, a caption, the paragraph above, then a row's own footnote; a footnote digit typed after a year ("Jul 20161") no longer breaks the date; seat or region tables (headings "By region", "seat polling") get table_type "seat"; every no_date_header refusal now states why. A voting-intention table whose pollster is never named is kept with firm NA and firm_from "not_stated" instead of aborting the run (qld2006 all 12 rows, nt2016 4 rows).

Frozen pages: the 34 pages parsed before the extension are byte-identical (all.equal TRUE, 5,382 rows). To keep that, two new rules skip them (`frozen_pages` in the script). Unfrozen (`AUSPOL_POLL_UNFREEZE=1`) they would add 4 Roy Morgan rows from fed2010_opinion table 4 and retype 69 rows on the 2026-cycle pages as "seat".

Still unparsed, with reason (table_outcomes.csv carries the same text): 157 tables are election results, pendulums, candidate lists or endorsements; 7 are preferred-premier or approval tables with no voting intention (tas2014, tas2018, tas2021 and similar); 25 have no date header and no party-group row (ACT and NT candidate tables, SA 2026 standings). sa2006_main table 1 (8 rows) is typed "other" (no party columns) and was not inspected beyond that. Not confirmed: whether qld2006's pollster is Newspoll (the table does not say).
