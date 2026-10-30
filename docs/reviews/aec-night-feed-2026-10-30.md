# AEC election-night media feed: real booth reporting times (federal 2022 and 2025)

Written 2026-10-30. Script: `scripts/parse_aec_mediafeed.py` (Python standard library only; run `python -I scripts/parse_aec_mediafeed.py 27966` or `31496`; add `--report` to rebuild the summary from the written files). Full check output: `output/night-feed/summary-fed2022.txt` and `summary-fed2025.txt`.

All times are Canberra clock (AEST in May). A WA booth shown at 20:00 here closed its doors at 6pm WA time.

## What was parsed

Snapshots, divisions and rows behind every output. All snapshots parsed; none failed.

| Item | 2022 (event 27966) | 2025 (event 31496) |
|---|---|---|
| Zip snapshots parsed / on disk | 368 / 368 | 365 / 365 |
| First, last snapshot | Sat 17:01, Sun 03:53 | Sat 16:59, Sun 02:36 |
| Parse failures | 0 | 0 |
| Feed `Created` minus filename time | 0 s for every file (same clock) | 0 s for every file |
| Divisions | 151 | 150 |
| Polling places listed / that ever showed votes | 8,479 / 7,811 | 8,940 / 7,995 |
| division-progress rows (snapshots x divisions) | 55,568 | 54,750 |
| raw polling-place rows (change-only, gzipped) | 701,780 | 783,388 |

Outputs per election, in `output/night-feed/`: `booth-returns-fed<year>.csv`, `division-progress-fed<year>.csv`, `national-progress-fed<year>.csv`, `raw-pp-fed<year>.csv.gz`, plus an extra `division-fp-fed<year>.csv` (every candidate's first-preference count per division per snapshot).

Things worth knowing about the feed:

- **Polling places carry no timestamp of their own.** Only the division's first-preference block and two-candidate block carry an `Updated` time (the latest booth in that division). Where exactly one booth in a division first appeared in a snapshot, that `Updated` is that booth's true return time (`fp_exact`, `fp_exact_flag = 1`): 5,426 places in 2022 and 5,510 in 2025. For these the snapshot time lagged the true time by a median 59 s (2022) and 56 s (2025), 90th percentile about 95 s. For the rest, `fp_prev_snapshot` and `fp_first_seen` bracket the return to within one snapshot gap (1 to 2 minutes). The state tables below use snapshot times, so read them as up to about 1.5 minutes late.
- **The raw table is change-only**: all fields of a polling place are written at the first snapshot and again at every snapshot where any of its figures changed, so nothing is dropped but unchanged repeats are not stored. Kept: first preferences per candidate and the historic "ghost" candidates, formal, informal, total, two-candidate counts, and every attribute (historic, percentage, swing, matched-historic, any other attribute as JSON).
- Division-level fields kept include votes by type (ordinary, absent, provisional, pre-poll, postal), enrolment, booths returned and expected for both counts, the `Maverick` and `Restricted` flags on the two-candidate block, and the two-party figures. The House national/state Analysis blocks and the Senate are not parsed.
- Declaration votes: in 2022 no declaration vote type showed any count on the night. In 2025 only postal votes did (117 divisions, median first appearance 22:04). They are in `booth-returns` as rows named `[Postal]` etc. with classification `declaration:...`.

## Join to the final results booth file

Whether feed polling-place names match `output/booths-fed<year>.csv` on (division, name). Higher matched is better.

| Check | 2022 | 2025 |
|---|---|---|
| Feed places matched to a booth in `booths-fed` | 8,479 of 8,479 | 8,940 of 8,940 |
| Unmatched feed names | 0 | 0 |
| `booths-fed` ordinary booths with no feed place | 0 | 0 |
| Division names, feed vs `booths-fed` | identical (151) | identical (150) |

The feed spells every name exactly as the final file does. In `booths-fed`, pre-poll and special places are typed "ordinary", so they join too. Some listed places never showed votes before the feed stopped counting (counts below), so they have a row in `booth-returns` with blank times.

Listed places with no votes ever, by type (fewer is better coverage).

| Type | 2022 | 2025 |
|---|---|---|
| Pre-poll voting centres | 486 | 281 |
| Special hospital teams | 60 | 484 |
| Prison mobiles | 13 | 114 |
| Remote mobiles | 17 | 32 |
| Ordinary booths | 92 | 34 |
| Total | 668 | 945 |

## Check: last snapshot against the final results

The feed's ordinary first-preference votes at its last snapshot divided by the final ordinary total in `booths-fed`. The brief expected below 1.0, since the final includes later counting.

| Measure | 2022 | 2025 |
|---|---|---|
| Sum of polling-place votes, last snapshot | 10,836,225 | 11,715,186 |
| Final ordinary votes | 11,477,254 | 12,322,744 |
| Ratio | 0.944 | 0.951 |
| Divisions flagged (ratio below 0.90 or above 1.0) | 35 of 151 | 37 of 150 |
| of which below 0.90 | 27 | 22 |
| of which at or above 1.0 (feed higher than final) | 8 | 15 |
| Highest / lowest ratio | 1.005 Fairfax / 0.475 Kingsford Smith | 1.030 Pearce / 0.537 Oxley |

"Close but below" does not hold everywhere: in 8 divisions (2022) and 15 (2025) the feed has as many or more ordinary votes than the final file, by up to 0.5% and 3.0%. Not diagnosed. A plausible cause is votes the AEC reclassified between types or corrected at recheck, but I did not check that. Divisions far below 0.90 are ones where large pre-poll centres had not reported. Per-division list: the `FLAG` lines in each summary file.

The feed stops adding ordinary counts around 02:00: in 2022 national formal votes rose by only 14,267 between the 02:00 snapshot and the last one (03:53).

## When booths reported, by state

First-preference return time per polling place (snapshot when votes first became non-zero), for places that showed votes by the last snapshot. Earlier is faster. "Ordinary" means classification none (excludes pre-poll centres, hospitals, prisons, remote mobiles).

Ordinary polling places, 2022 (n = 6,955).

| State | n | First | Median | 90th percentile |
|---|---|---|---|---|
| ACT | 106 | 17:46 | 20:07 | 21:34 |
| NSW | 2,336 | 18:19 | 19:46 | 21:29 |
| NT | 39 | 19:02 | 19:52 | 20:44 |
| QLD | 1,252 | 18:17 | 19:31 | 20:53 |
| SA | 613 | 18:56 | 20:41 | 22:56 |
| TAS | 279 | 18:31 | 19:40 | 21:11 |
| VIC | 1,629 | 18:19 | 19:52 | 21:17 |
| WA | 701 | 20:29 | 21:50 | 23:46 |
| All | 6,955 | 17:46 | 19:56 | 22:01 |

Ordinary polling places, 2025 (n = 6,932).

| State | n | First | Median | 90th percentile |
|---|---|---|---|---|
| ACT | 110 | 18:20 | 19:48 | 22:04 |
| NSW | 2,351 | 18:22 | 19:55 | 22:02 |
| NT | 38 | 18:59 | 19:56 | 20:57 |
| QLD | 1,227 | 18:25 | 19:35 | 21:24 |
| SA | 603 | 18:56 | 20:34 | 22:38 |
| TAS | 279 | 18:25 | 19:53 | 21:32 |
| VIC | 1,636 | 18:28 | 19:59 | 21:53 |
| WA | 688 | 20:22 | 22:20 | 00:12 |
| All | 6,932 | 18:20 | 20:04 | 22:26 |

All polling places including pre-poll centres and special places (n = 7,811 in 2022, 7,995 in 2025). Pre-poll centres are the late ones: across all states their median is 22:34 (2022) and 22:22 (2025) and their 90th percentile 00:56 and 00:40.

| State | 2022 first | 2022 median | 2022 p90 | 2025 first | 2025 median | 2025 p90 |
|---|---|---|---|---|---|---|
| ACT | 17:46 | 20:16 | 22:08 | 18:20 | 19:56 | 22:31 |
| NSW | 18:19 | 19:53 | 22:16 | 18:19 | 20:04 | 22:40 |
| NT | 19:02 | 20:16 | 23:05 | 18:59 | 20:30 | 22:49 |
| QLD | 18:17 | 19:37 | 21:41 | 18:25 | 19:44 | 22:22 |
| SA | 18:56 | 20:50 | 23:32 | 18:56 | 20:37 | 22:59 |
| TAS | 18:31 | 19:43 | 21:17 | 18:25 | 19:58 | 21:58 |
| VIC | 18:19 | 19:59 | 22:04 | 18:28 | 20:07 | 22:32 |
| WA | 20:29 | 21:56 | 00:34 | 20:22 | 22:28 | 00:32 |
| All | 17:46 | 20:05 | 22:37 | 18:19 | 20:13 | 22:59 |

Notes:

- The first ACT booth in 2022 (17:46) is Norfolk Island in Bean. The first mainland booths were Lucinda and Mungindi (QLD) at 18:17. In 2025 the first was Haymarket PPVC (Fowler) at 18:19.
- WA's first booths reported about 20:22 to 20:29 Canberra time, which is 6:22 to 6:29pm in Perth, about as quickly after close as the east. The late WA medians on this clock are because WA closes two hours later.

## National progress

Cumulative first-preference formal votes counted, all vote types, as a share of the final formal vote (14,659,042 in 2022 and 15,490,236 in 2025, summed from `booths-fed`). Higher is further through. The feed never gets past about 74% (2022) and 78% (2025) because postal, pre-poll and absent votes are counted after the night.

| Clock time | 2022 formal votes | 2022 % of final | 2025 formal votes | 2025 % of final |
|---|---|---|---|---|
| 19:00 | 279,121 | 1.9% | 178,109 | 1.1% |
| 20:00 | 3,009,814 | 20.5% | 2,560,760 | 16.5% |
| 21:00 | 5,560,917 | 37.9% | 4,836,734 | 31.2% |
| 22:00 | 7,393,367 | 50.4% | 6,950,319 | 44.9% |
| 23:00 | 8,711,954 | 59.4% | 9,072,398 | 58.6% |
| 00:00 | 9,565,276 | 65.3% | 10,619,819 | 68.6% |
| 01:00 | 10,325,417 | 70.4% | 11,611,700 | 75.0% |
| 02:00 | 10,821,958 | 73.8% | 12,098,969 | 78.1% |
| last snapshot | 10,836,225 | 73.9% | 12,123,186 | 78.3% |

2025 was slower to 22:00 (44.9% against 50.4%) and ahead from midnight.

## Wentworth 2022 (division 152)

How far through the night Wentworth was, using the latest snapshot at or before each hour. Booths are first-preference booths returned of 52 expected (the feed lists 53 places). "Share of enrolment" is all votes counted over enrolment; "share of final" is formal votes over the final total for the division in `booths-fed` (88,923). Higher is further through.

| Time | Snapshot | Booths returned / 52 | Two-candidate booths / 52 | Votes counted | Share of enrolment | Share of final formal |
|---|---|---|---|---|---|---|
| 19:00 | 18:59:31 | 0 | 0 | 0 | 0.0% | 0.0% |
| 20:00 | 19:59:31 | 20 | 10 | 17,769 | 17.1% | 19.6% |
| 21:00 | 20:59:36 | 30 | 22 | 27,962 | 27.0% | 30.8% |
| 22:00 | 21:59:37 | 34 | 32 | 35,802 | 34.5% | 39.5% |
| 23:00 | 22:59:37 | 39 | 39 | 39,150 | 37.7% | 43.1% |

At the last snapshot Wentworth's polling places held 57,072 ordinary votes, 81% of the final ordinary count of 70,260; the rest was pre-poll and later counting.

## When Spender v Sharma was the counted pair

The AEC showed "SHARMA, Dave v SPENDER, Allegra" as Wentworth's two-candidate pair from the first snapshot after polls closed, 18:01:01 on 21 May 2022 (the previous snapshot, 17:59:31, showed no pair), with no votes counted yet (0 of 52 booths). It never changed all night, so for Wentworth the AEC chose the right pair before any vote was counted. The division's two-candidate `Updated` stamp was blank at that point.

## When the AEC picked the wrong pair

The feed marks a withdrawn pair with `Maverick="true"` on the two-candidate block and no candidates listed. In 2022, 11 divisions started with one pair, had it withdrawn mid-evening, and a replacement pair first appears in the LAST snapshot (03:53 Sunday) with no votes counted for it. When the pair was withdrawn and what replaced it (snapshot times; withdrawal time is when the feed first showed no pair):

| Division | Pair shown from about 18:01 | Withdrawn at | Replacement pair (03:53) |
|---|---|---|---|
| Bradfield | Brigden v Fletcher | 22:47 | Boele v Fletcher |
| Calare | Elliott v Gee | 20:29 | Gee v Hook |
| Canberra | Minson v Payne | 21:14 | Hollo v Payne |
| Cowper | Conaghan v McMullen | 20:29 | Conaghan v Heise |
| Grey | Habermann v Ramsey (from 18:31) | 22:44 | Ramsey v Watson |
| Griffith | Butler v Roberts | 20:34 | Chandler-Mather v Roberts |
| Hinkler | Dempsey v Pitt | 21:01 | Pitt v Scanes |
| Maranoa | Kelly v Littleproud | 23:08 | Kerrigan v Littleproud |
| Melbourne | Bandt v Damches | 22:31 | Bandt v Paterson |
| Ryan | Cossar v Simmonds | 20:43 | Simmonds v Watson-Brown |
| Sydney | Andruska v Plibersek | 22:14 | Plibersek v Sahai |

Four more 2022 divisions had the pair withdrawn and re-shown as the same pair, and four have no pair at the last snapshot. In 2025 no division moved to a different pair in the feed: 22 had the pair withdrawn and came back as the same pair, and 21 ended the feed with no pair (see `summary-fed2025.txt`). So during the night the feed gives the time the AEC's guess failed, but not a corrected pair or its count; the replacement only appears at the end of the feed.

## Caveats

- Times are snapshot times unless `fp_exact_flag = 1` (see above). For flag 0 places the true time lies between `fp_prev_snapshot` and `fp_first_seen`. One 2025 place has an exact-time gap of 1,917 s, so treat `fp_exact` with some care.
- The division-level Formal/Informal/Total "Ordinary" figures in the feed show 0 while candidates already have ordinary votes, so they are not usable. Use `ordinary_cand_votes_sum` (sum of candidates' ordinary votes) and `pp_fp_votes_sum` (sum over polling places) in `division-progress`; they agree in every division at the last snapshot.
- The summary files' parse-time lines (Created vs filename, unknown tags) come from the full parse; a `--report` rebuild leaves them as "not recomputed".
- A superseded earlier full 2022 run (before the Maverick and fixed-header changes) was overwritten by the final one.
