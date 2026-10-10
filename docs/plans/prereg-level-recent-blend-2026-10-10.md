# Pre-registration: blend the day-before level toward the recent polls (2026-10-10)

Written BEFORE any arm ran. From the screen `reviews/trend-lag-day-before-2026-10-10.md` (Pete: go): outside
WA, a plain mean of the last 28 days of polls beat the shipped trend's day-before level by 0.26 points (SE 0.13)
in 14 of 16 elections, all 7 federal, on Labor and the Coalition; slightly worse on the Greens. Victoria 2022:
trend Coalition 31.4, polls 34.1, actual 34.5 -- the cause of the Labor-v-Greens two-candidate over-calls
(Richmond, Footscray, Brunswick, Preston, Pascoe Vale).

## The change (`AUSPOL_LEVEL_RECENT`, default "0")

For ALP, LNP and GRN only, the day-before statewide level becomes

    level = (1 - w) x trend + w x avg28,    w = n28 / (n28 + k)

where `avg28` is the mean of the polls fielded in the 28 days before polling day (LNP + NAT where a poll file
reports the Nationals separately, i.e. WA), `n28` how many there were, and `k` a single constant fitted on
EARLIER elections only: the value on a log grid that minimises squared error of the blended level against the
actual ALP/LNP/GRN shares over every election dated before the target. No earlier elections: w = 0 (the trend).
No cut-off on n28: two polls get a small weight, twenty a large one. The other classes absorb the change pro rata
so the level still sums to 100. One shared function, applied where the six harnesses form their level
(`forecast_statewide_or_oracle()`) and where the live forecast forms `state_mean` (`fit_seats_full.R`).

The earlier elections' trend levels come from a table built with the switch off (`output/level-recent.csv`,
`scripts/build_level_recent_table.R`, added to the rebuild ahead of stage 6), so a harness never refits the trend
of another election.

## Arm and criteria

Arm: `AUSPOL_LEVEL_RECENT=1`, everything else shipped. Screen with `quick_arm.R` on all 22 elections (in
chunks if memory requires); the deciding run is the full 20,000-sim stage 6.

1. PRIMARY: pooled seat-winner log loss over the 22 elections falls by more than 2 SE (clustered on election).
   Lower is better. A statewide change moves every seat, so the whole-election metric is the right scope.
2. SECONDARY (reported, not gating): day-before level MAE on ALP/LNP/GRN, time-forward, against the trend's.
3. GUARD: AEF-7 ledger seat log loss rises by no more than 1 SE.
4. GUARD: the Greens' day-before level MAE rises by no more than 0.2 points (the screen's one adverse class).
5. UNACCEPTABLE-WIN, named in advance: any single election's seat log loss worse by more than 0.02, or a fitted
   k that puts w above 0.9 for an election with fewer than 5 polls in the window (the average would then be
   trusted on almost no data, which is what WA showed goes wrong).
6. Named target, reported: vic2022 Coalition level moves from 31.4 toward 34.5.

Ship rule: 1 passes, 3 and 4 hold, 5 does not fire. Otherwise off, and the split goes to Pete.
Any amendment is added below with this text unedited.

## Dry run (2026-10-10, before any arm ran): clause 5 FIRES; the arm is not run as specified

`output/level-recent.csv` built (`scripts/build_level_recent_table.R`, 22 scoreable elections, Nationals folded).
The fitted k sits at the bottom of its grid (0.25) for every target with any earlier election, so w = 0.89-0.99:
the earlier elections say "the 28-day average, essentially alone". That puts w above 0.9 on fewer than 5 polls for
nsw2019 (4), sa2022 (3) and qld2020 (4): the pre-registered unacceptable condition. Named target: vic2022
Coalition 31.4 -> 34.0 (actual 34.4).

But the clause's premise came from WA before the Nationals were folded in (WA's poll LNP column was Liberals
only). With the fold, from the table, day-before MAE on ALP/LNP/GRN (lower is better): all 22 elections trend 1.90
vs average 1.58 (-0.32, SE 0.21, average better in 17); fewer than 5 polls 2.22 vs 1.90 (-0.32, SE 0.63, better in
4 of 7); 5-9 polls -0.48 (SE 0.16, 6 of 7); 10+ polls -0.19 (SE 0.22, 7 of 8). The premise is not supported, nor
refuted on 7 elections. To Pete before anything runs.
