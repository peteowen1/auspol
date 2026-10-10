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

## Amendment 1 (2026-10-10, after the dry run; Pete chose it from the numbers above)

POST HOC, and marked so. Clauses above unedited. Clause 5's second condition (w above 0.9 on fewer than 5 polls)
is WITHDRAWN: its stated evidence was WA before the Nationals were folded in, an artefact of the poll file, and
with the fold the average is no worse on few polls (4 of 7 better, -0.32, SE 0.63). Clause 5's first condition
(any single election's seat log loss worse by more than 0.02) stands, as do 1-4 and the ship rule. The fitted
form is effectively "the 28-day average for ALP/LNP/GRN" (w 0.89-0.99); judged as such.

## Screen result (2026-10-10, quick_arm, 1,000 sims, all 22 elections, run in chunks of 3-4 elections)

The first chunk came back byte-identical: the federal harness builds its level itself and never calls
`forecast_statewide_or_oracle()`. Hooked there (`BF0r`, using the target's own date -- `ed` is reassigned by the
minor-poll loop above it), then every chunk re-run. Lower is better throughout.
1. PRIMARY: seat log loss, 2,120 seats, 0.3093 -> 0.3027 (-0.0066, SE 0.0035 clustered on election): 1.9 SE,
   just short of 2 SE at screen precision. The deciding run is the full 20,000-sim stage 6.
3. GUARD: AEF-7 ledger 0.2742 -> 0.2697 (-0.0045, SE 0.0031): holds (better).
4. GUARD: Greens day-before level MAE 1.08 -> 1.09 (table, w ~1): holds.
5. No election worse by more than 0.02 (worst wa2013 +0.0126, nsw2019 +0.0088, qld2024 +0.0069, fed2007
   +0.0059): does not fire.
Better in 15 of 22: wa2008 -0.093, qld2020 -0.038, wa2025 -0.022, vic2018 -0.020, wa2017 -0.012, fed2016
-0.011, fed2025 -0.010, vic2022 -0.009 (the target). Share-level squared error on changed cells -2% (SE 5,075).

## Deciding run (2026-10-11, 20,000 sims, all 22 elections, code e190cab): REFUSED on two clauses

Stage 6 harness by harness in the foreground with `AUSPOL_LEVEL_RECENT=1`, then `AUSPOL_REBUILD_FROM=7`; every
pooled pair from this run (ge190cab). Baseline: the shipped 20k run (gddbcedd, kept in a scratch backup).
1. PRIMARY: seat log loss, 2,120 seats, 0.3239 -> 0.3172 (-0.0067, SE 0.0039 clustered on election): 1.7 SE,
   FAILS the 2-SE bar. Better in 14 of 22 (wa2008 -0.080, qld2020 -0.038, vic2018 -0.023, wa2025 -0.022,
   fed2013 -0.021, fed2025 -0.010, vic2022 -0.009).
3. GUARD: AEF-7 ledger 0.2732 -> 0.2682 (AEF 0.2825): holds, better.
5. FIRES: nsw2019 +0.0453 (> 0.02). Four polls in the window, whose mean moved the Coalition away from the result
   (trend 41.1, polls 39.9, actual 41.6) -- the few-polls case Amendment 1 withdrew from this clause. The screen
   at 1,000 sims showed +0.0088 there. Others worse: wa2013 +0.008, fed2007 +0.006, qld2024 +0.004.
Off unless Pete overrides; the split goes to him.

## PETE'S OVERRIDE (2026-10-11): ships despite the refusal

Asked with the split above (quiz: leave off, recommended, or override). Pete chose "Override and ship": the ledger
gain (0.2732 -> 0.2682) is the largest in weeks, and Victoria 2026 should have several polls in its final month,
so the few-polls failure (nsw2019) is least likely where it matters. The clauses and results above stand as
written; this is a decision against them. Shipped as `AUSPOL_LEVEL_RECENT="1"`, with rebuild stage 1 running it
OFF so the as-at trees stay trained on the unblended base -- exactly the configuration the deciding run measured.
Live: the window ends on the day of the run, so it acts only once polls land in the last 28 days (none for
vic2026 on 2026-10-10).

## Amendment 2 (2026-10-11, after shipping; Pete: "I assume you did a decay and not a hard cap at 28 days")

The shipped form uses a hard 28-day window, against Pete's standing no-hard-caps rule; recorded in
`PETE-ASKED-FOR.md`. Written BEFORE the arm below ran. `AUSPOL_LEVEL_RECENT="decay"`: every poll of the current
cycle (since the previous election) fielded before the as-at date counts, weighted 2^(-age/H); the level becomes
(1 - w) x trend + w x the weighted poll mean, w = n_eff / (n_eff + k), n_eff the summed weights. H (half-life,
days) and k are fitted jointly on EARLIER elections only, by squared error of the blended ALP/LNP/GRN level
against the actual, over a grid. No window, no poll-count cut-off.

Judged against the SHIPPED form ("1"), since the question is whether removing the cliff costs anything:
1. PRIMARY: 22-election seat log loss no worse than the shipped form by more than 1 SE (clustered on election).
2. GUARD: AEF-7 ledger no worse by more than 1 SE.
3. GUARD: no single election worse than the shipped form by more than 0.02.
Ship rule: "decay" replaces "1" if 1-3 hold (Pete's rule decides between two forms that score alike). Screen with
quick_arm on all 22 first; the deciding run is the full 20,000-sim stage 6.

### Amendment 2 dry run (before the screen; no seat outcome read)

The joint fit runs to the edge of its grid: on (3 days, k 0.25) first, then, with the grid widened to 1 day and
k 0.01, on half-life 1-1.5 days and k 0.01 for every target with history -- "the final poll or two, at nearly full
weight". Coalition day-before level, trend -> decay (actual): fed2016 39.3 -> 42.3 (42.1), vic2022 31.4 -> 33.8
(34.4), nsw2019 41.1 -> 41.0 (41.6), vic2018 37.8 -> 36.0 (35.2), sa2026 17.7 -> 17.0 (19.5). Live vic2026 on
2026-10-11: newest poll 15 days old, weight 0.09. A boundary optimum leans hard on one or two polls; the
pre-registered comparison against the shipped form decides.
