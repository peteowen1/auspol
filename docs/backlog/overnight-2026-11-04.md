# Overnight 4-5 Nov 2026 (Pete asleep; working the queue on dev)

Times are Sydney. Updated as I go; the morning summary is the top section.

## Needs Pete (morning)

1. **Narracan booth history for election night.** Narracan has no 2022 booths (its poll was the 28 Jan 2023
   supplementary), so on the night every Narracan booth is "new" with no swing. The supplementary is not a like-for-like
   base: it had NO Labor and NO Nationals candidate (Liberal 16,741, Greens 4,132, IND Wolfe 4,110, DLP 2,641, Freedom
   2,254, One Nation 2,246; final two Liberal 62.9 v Wolfe). Choices: (a) 2018 Narracan booths as the reference (both
   majors stood, but before the 2021 redistribution), (b) the 2023 booths for the parties that stood only, (c) leave them
   "new". Raw pages saved: `external/reference/vec/2022/booths/narracan-supp2023-{fp,2cp}.html`. My pick: (a), matched by
   booth name, since the night swing is Labor minus Coalition.
2. **My mistake to flag:** the curl that fetched those two VEC pages sent your email address in its User-Agent header
   ("auspol research (fptpost@gmail.com)"). It went only to vec.vic.gov.au, but it should not have gone anywhere.
   Later fetches do not do it.

## Done overnight

- Doc-audit sentinel (#109, 3 Nov run): the four still-drifted citations now name functions (`83d08209`); the other five
  were already fixed; its CONSTANTS:646 "value differs" is a false alarm (3 earlier elections = 3 pairs).
- Flows queue item narrowed (`b56f2032`): the federal Greens->Labor estimate running 3-7 points above the AEC is the
  estimator's known bias (failed its bar 13 Oct) and reaches no published forecast; federal flows come from the AEC.

## In flight

- vic2026 Google Trends snapshot to 4 Nov (`AUSPOL_SALIENCE_TO=2026-11-04`, watching only; the shipping one is 25-27 Nov).
