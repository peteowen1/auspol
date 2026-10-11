# Poll coverage: AE Forecasts' files against Wikipedia (2026-10-11)

Pete: "can we check if theres any polling data we're missing anywhere?" Our only poll source is AE Forecasts'
public files (`external/aus-polling-analyser`, cloned fresh by every CI run; the local clone had drifted two weeks
and was pulled 2026-10-11). Tool: `scripts/check_poll_coverage.R` (writes `output/poll-coverage-wiki-only.csv`).

- 16 of 22 elections parsed from Wikipedia; 1,409 distinct headline polls, 1,012 matched to an AE poll (same firm,
  within 4 days, primaries within 0.5), 397 not.
- NOT scored (scrape empty): fed2007, fed2010, nsw2019, wa2001, wa2005, wa2008, wa2013. Either the guessed polling
  page does not exist (fed2007, nsw2019, the WA pages) or its tables did not parse (fed2010, the main election
  pages). Fixing those parses is the next step for full coverage.
- Final 28 days, 13 candidate gaps; 9 are the same polls stored differently (AE re-bases Ipsos and Essential
  without undecided voters, e.g. fed2022 Ipsos 34/32 on Wikipedia vs 36.6/34.4 in AE, and dates Essential's rolling
  samples differently). 4 are genuinely absent, no poll from that firm within 14 days:
  vic2022 Lonergan Research (6 Nov, ALP 42 / Coalition 29), sa2026 Resolve (16 Mar, 32 / 18), qld2020 Roy Morgan
  (15 Oct, 36 / 35), vic2014 Roy Morgan (20 Nov, 35.5 / 35).
- The 397 over whole cycles are not yet triaged the same way; the same re-basing explains many of them.
