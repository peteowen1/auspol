# Night replay: Western Australia 2025 (previous election 2021)

Written 2026-10-30. Replays a saved pre-election forecast state for wa2025 against the real booth results, counting a growing fraction of the night's vote, and asks when the result could have been called.

**Call point: the result needed no count at all.** P(Labor majority, 30 or more of 59 seats) was 1.000 (1,000 of 1,000 simulations) at every fraction from 0, including the afternoon forecast before any booth was counted. The call is therefore "at 6pm, before polling closed", and the interesting question is not the majority but how many seats. Labor ended on 46 seats (Liberal/National 13); the model's expected Labor seats settled at about 47 from 10% of the vote onward.

## Replay table

What the numbers are: one row per fraction of the night's booth vote revealed. "Vote counted" is the mean share of each seat's final vote already in (the booth-table share, not an enrolment share). "Indicative clock" is 6pm + 4 hours x fraction and is a label only; it is not a real WAEC count timeline. "Seats right" is how many of 59 seats the model's favourite was the real winner (higher is better, max 59). "Seat log loss" is the mean of minus the log of the probability given to the real winner (lower is better; 0 is perfect). "Labor expected" is the mean Labor seats over the simulations with a 5th to 95th percentile range. "P(majority)" is the share of simulations with Labor on 30 or more (higher is more certain; resolution is 0.001 at 1,000 simulations).

| fraction | vote counted % | indicative clock | seats right of 59 | seat log loss | Labor expected (90% range) | P(majority) |
|---|---|---|---|---|---|---|
| 0 | 0.0 | 6:00pm | 55 | 0.192 | 45.2 (39-50) | 1.000 |
| 0.02 | 0.4 | 6:05pm | 55 | 0.185 | 44.6 (40-49) | 1.000 |
| 0.05 | 2.2 | 6:12pm | 55 | 0.137 | 46.4 (42-50) | 1.000 |
| 0.10 | 6.4 | 6:24pm | 56 | 0.078 | 47.3 (44-50) | 1.000 |
| 0.15 | 9.8 | 6:36pm | 57 | 0.085 | 47.8 (45-50) | 1.000 |
| 0.20 | 13.8 | 6:48pm | 57 | 0.081 | 47.3 (44-50) | 1.000 |
| 0.30 | 21.4 | 7:12pm | 57 | 0.072 | 47.1 (44-49) | 1.000 |
| 0.40 | 29.0 | 7:36pm | 56 | 0.088 | 47.5 (45-50) | 1.000 |
| 0.50 | 35.5 | 8:00pm | 56 | 0.082 | 47.5 (45-50) | 1.000 |
| 0.75 | 43.1 | 9:00pm | 57 | 0.073 | 47.3 (45-49) | 1.000 |
| 1.00 | 79.9 | 10:00pm | 57 | 0.110 | 47.6 (46-49) | 1.000 |

Reading it: the majority question was settled throughout. The count does sharpen the seat picture (log loss 0.192 to about 0.07-0.08 by 10% counted; Labor's 90% range narrows from 39-50 to 44-50), but it does not get better after about 6:24pm. Two seats stay wrong at the end: Albany (real winner Liberal, model gave 0.44) and Kalamunda (real winner Liberal, model gave 0.03). Fraction 1.00 shows only 79.9% counted because the replay counts the booth table, and absent/provisional/postal lines are revealed in the model's interleaved order, not as a full set.

## Five seats that moved most

What the numbers are: the probability the model gave the real winner, at each fraction, for the seats whose probability swung most between fractions (largest high minus low across the night). Higher is better. Fractions are 0, 0.02, 0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.5, 0.75, 1.

| seat (real winner) | probability on the winner across the night | what happened |
|---|---|---|
| Pilbara (Labor) | .755 .224 .309 .946 .971 .696 .664 .661 .704 .747 .657 | swung from 0.22 to 0.97 and back; thin early count in a remote seat, never settled |
| Scarborough (Labor) | .347 .339 .643 .767 .878 .881 .965 .978 .984 .988 .993 | a slow, correct climb from toss-up to certain |
| Murray-Wellington (Liberal) | .206 .764 .332 .275 .167 .287 .407 .450 .380 .513 .549 | whipsawed; real winner only just ahead at the end (0.55) |
| Dawesville (Labor) | .531 .529 .973 .960 .959 .953 .895 .901 .905 .910 .988 | jumped at 5% counted, dipped, finished near certain |
| Nedlands (Liberal) | .540 .553 .899 .900 .965 .966 .976 .987 .991 .994 .995 | jumped at 5% counted, then certain |

Computed from the saved JSON files (the replay detail script was not run, see below). The real winners come from `external/elections/waec-wa-winners.csv`.

## How this was built (and what to check)

- **Booth results.** Not fetched again: `output/booths/wa2025-booth-fp.csv` (and wa2021) were already on disk, parsed from the WAEC JSON in `external/reference/waec/sg2025-*.json` (raw responses already saved). Checked: per-district vote totals equal `external/elections/waec-2025-wa-firstprefs.csv` and the 2021 file, 59 of 59 districts each, 1,527,968 and 1,411,990 votes, zero mismatches.
- **Night-schema tables.** `scripts/build_night_booths_wa2025.R` writes `output/booths-wa2021.csv` and `output/booths-wa2025.csv`. booth_type from vote_type: `ordinary` to ordinary; `count centre: Absent Votes` to absent; `count centre: Early Votes (In Person)` (2021 only) to early; `count centre: Early Votes (by Post)` (2021) and `count centre: Postal Votes` (2025) to postal; `count centre: Provisional Votes` to provisional. In 2025 early in-person votes are not a separate line, so they sit inside ordinary booths; the 2021 file has them as a count-centre line. That is a real difference between the two years in how the model sees early voting (unverified how much it matters).
- **Party names, a deviation from the brief.** The brief said party = party_raw, but WA publishes only codes (ALP, LIB, PHON) and the night code classifies by name alone, so the first replay sent every code to "other" and showed Labor falling to 11 seats. I now write a canonical name for the class that the harness's own `classify_party(code, code=code)` gives (Labor, Liberal, Greens, One Nation, Independent, Shooters), keep raw codes for other parties, and the script asserts the name-only classification reproduces the code-based one. The first-replay output was discarded.
- **State save.** The AUSPOL_NIGHT_DUMP block is in `scripts/backtest_candidate_wa.R` just before the final `simulate_seat_contests()`. WA's call passes no party_cor, so none is saved; sd_override is computed in the block with the same expression the call uses (unverified that it is byte-identical to the call's value; the afternoon forecast at fraction 0 scored 55 of 59 right and Labor 45.2, consistent with the screened run's seat log loss 0.1915, which matches the replay's fraction-0 0.1915).
- **Run size.** The state was saved by quick_arm at 1,000 simulations, so P(majority) cannot show anything finer than 0.001 and the ranges are rougher than a 20,000-simulation run.
- **Two-candidate counts.** None: run with `--tcp=0`. Not scored: whether a WA two-candidate feed would have sharpened the close seats.
- **Not run: `scripts/night_replay_detail.R`.** It reads a two-candidate booth file unconditionally (`fread(pth(5, ...))`), none exists for WA, and the brief said to stop rather than edit it.
- **Scope.** wa2025 was an unusually safe election for Labor (46 of 59 seats), so a call at zero is expected; it says nothing about how the model does on a close night.
