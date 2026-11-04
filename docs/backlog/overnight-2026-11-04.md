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

3. **The others-bucket split every harness uses cannot be rebuilt from committed code, and is stale.**
   `AUSPOL_BUCKET_SPLIT=cand_naive` reads `output/minor-class-shares-v2.csv` (`published_flags.R`,
   `candidate_bucket_ratio()`). That file is byte-identical to the 28 Sep 15:42 run's `minor-class-shares-resid-v2.csv`;
   `scripts/rebuild_forecasts.sh` never runs `fit_minor_candidates.R`, and the one committed version of that script
   (29 Sep) already has the v3 defector rule, so the v2 file is not reproducible. It predates the 25 Oct LDP
   reclassification and the 1 Nov sa2026 absent-vote fix. Live vic2026 is unaffected today (no vic2026 rows, so the
   live run falls back to the 2022 mix, `FST1!`), but that means live and backtests split the bucket differently.
   Choices: (a) recover v2 as a named arm in the script (`AUSPOL_MC_OWN_RULE=v2`), regenerate it, add it to the rebuild
   and give it vic2026 rows after nominations (live = backtest); (b) switch the split to v3 (committed) with a screen.
   My pick: (a) first, so what ships is reproducible, then (b) as its own screen.
   (The 1 Nov audit of inputs built outside the rebuild likely saw this one and filed it as a false alarm, "a first
   commit after its first run": the commit came after the run, but it also changed the rule. Not confirmed which file
   that audit meant.)

## Done overnight

- Doc-audit sentinel (#109, 3 Nov run): the four still-drifted citations now name functions (`83d08209`); the other five
  were already fixed; its CONSTANTS:646 "value differs" is a false alarm (3 earlier elections = 3 pairs).
- Flows queue item narrowed (`b56f2032`): the federal Greens->Labor estimate running 3-7 points above the AEC is the
  estimator's known bias (failed its bar 13 Oct) and reaches no published forecast; federal flows come from the AEC.

## In flight

- vic2026 Google Trends snapshot to 4 Nov (`AUSPOL_SALIENCE_TO=2026-11-04`, watching only; the shipping one is 25-27 Nov).
