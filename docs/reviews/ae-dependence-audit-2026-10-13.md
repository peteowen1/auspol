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
