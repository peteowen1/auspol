# Upper-house VOTE model (Legislative Council), pre-registration, 26 Nov 2026

Written and committed BEFORE any model below is fitted. Scope: the vote side only (each group's first-preference
share by region). The count and its preference parameters belong to another piece of work and are not touched.

Switch: `AUSPOL_UPPER_HOUSE_VOTE_MODEL` ("0" = the current hand-set ratios, "1" = this model), registered "0".
Code: `R/upper_house_vote.R`, tests `tests/testthat/test-upper-house-vote.R`, wired into
`scripts/build_upper_house_forecast.R` only where region vote shares and minor weights are set.

## Data

- Victorian Legislative Council first preferences by district: `output/council-fp-2018.csv`,
  `output/council-fp-2022.csv` (district_total rows), and 2010 parsed from the raw VEC files
  `external/reference/vec/state2010*RegionFPVbyVC.xls` (each sheet's "<district> District" total block).
  No 2014 council results are on disk (checked `external/reference/vec/2014/`: lower house only).
- Lower house first preferences by district: `output/candidacies.csv` (vic2010, vic2018, vic2022).
- Party class from `classify_party()` on both sides (one source of truth).
- Regions are labelled by name. 2018/2010 "Eastern Metropolitan" is mapped to 2022's "North-Eastern Metropolitan";
  boundaries moved in the 2013 and 2021 redistributions, so the region effect carries some boundary noise, and that
  noise lands in the estimated within-region drift, where it belongs.
- Federal Senate vs House by division (`output/senate-by-division-class.csv` + ordinary House votes from
  `candidacies.csv`) for One Nation by state and election.
- Other states' upper vs lower houses (`output/other-upper-house-fp.csv`, sibling branch) if it lands in time.
- DemosAU same-poll upper and lower figures: 21-25 Nov 2026 (n 1,321): upper LNP 31 ONP 17 ALP 16 GRN 15;
  lower LNP 34 ALP 19 ONP 16 GRN 16. 1-10 Feb 2026 (n 1,274, Pollbludger): upper LNP 28 ONP 20 ALP 19 GRN 14
  (12% uncommitted); lower LNP 29 ALP 23 GRN 15 ONP 21. 21-27 Oct 2025 (n 1,016, demosau.com): upper LNP 30 ALP 21
  GRN 14 ONP 11; lower LNP 37 ALP 26 GRN 15 (One Nation's lower figure not published). The 30 Oct-5 Nov 2026 poll's
  upper-house figures were not found (demosau.com, Pollbludger, news search). YouGov's MRP seat projection is a
  benchmark only, never an input.

## What is fitted

**Majors (ALP, LNP, GRN), per party.** y(e, r) = log(upper share / lower share) for election e, region r.
y(e, r) = m(e) + d(e, r), where m(e) is the statewide log ratio.

- Region effect: dbar(r) = mean over elections of d(e, r). Within-region drift variance s2 = pooled variance of
  d(e, r) about dbar(r). Between-region variance tau2 = max(0, var_r(dbar) - s2 / E). Shrunk region effect
  w * dbar(r), w = tau2 / (tau2 + s2 / E). No cliff: a region with an unstable effect shrinks toward statewide.
- Statewide level for the next election: mean of the last two elections' m(e) (the 2018 and 2022 regime). Drift
  sd for a new election = sd of m(e) across the available elections (pooled over the three parties, so it is not
  one number from two points), drawn once per simulation and shared by every region.
- Region residual for a new election: N(0, s2 + posterior variance of the shrunk effect), drawn per region.
- Arm B adds a cross-district level slope: within each election, log ratio regressed on the district's log lower
  share deviation from the party's statewide share (slope pooled over elections), and the region's relative level
  in the new election shifts its ratio by slope x log(region lower / statewide lower). Region effects are then
  fitted on what the slope leaves.

**One Nation.** Random-effects meta-analysis (DerSimonian-Laird) on the log ratio. Sources: each federal
state-election where One Nation stood in at least 5 House divisions in that state (ratio of summed Senate to summed
House ordinary votes over those divisions, se from the division-level spread), Victoria 2022 (4 districts), other
states' upper houses when the sibling file lands, and the DemosAU polls as a HOUSE-EFFECT-FREE relative ratio:
(ONP upper/lower) / (geometric mean of the three majors' upper/lower in the same poll), times the historical
Victorian majors' geometric mean ratio. Poll se from sampling (n) plus the poll-vs-history discrepancy variance of
the majors' relative ratios. Weights 1 / (se^2 + tau2) reported per source. Sensitivity: federal sources before 2019
(One Nation standing in a selected handful of seats) excluded.

**Minor groups.** For each 2026 group matched to a 2022 group: regional pattern = log(region share / statewide
share) in 2022, shrunk toward 0 by w = tau2 / (tau2 + s2), s2 = between-election variance of the same pattern for
groups that ran in both 2018 and 2022, tau2 = cross-region variance of the pattern beyond s2. Statewide levels: the
named DemosAU 21-25 Nov figures (DLP 4, Legalise Cannabis 4, Victorian Socialists 3, the latter with the existing
YouGov regional crosstab kept); every other group at its 2022 statewide share. Groups with no 2022 match get the
2022 median minor share, as now. Within each region the minor shares are scaled to fill the residual pool
(100 minus the majors and One Nation), so the pool stays consistent with the majors. Reported: implied statewide
minor pool against DemosAU's 21 points.

**Majors poll blend (arm C, untestable in the backtest).** The statewide ratio of each major blended with the
DemosAU 21-25 Nov relative ratio (house-effect-free as above), precision-weighted: history variance = drift sd^2,
poll variance = sampling + discrepancy variance. Reported side by side; it enters switch "1" only if its weight and
justification are stated in the report.

## Backtest (time-forward)

Predict each election's region-level upper-house shares for ALP, LNP, GRN from earlier elections' ratios applied to
that election's ACTUAL lower-house region shares (an oracle input, so this tests the ratio model alone):

- 2018 from 2010 (n = 8 regions x 3 parties = 24 cells).
- 2022 from 2018 alone, and from 2010 + 2018 (24 cells each).

Arms: uniform statewide ratio from the previous election (the time-forward version of the current method; the
current constants 0.905/0.845/0.883 were fitted ON 2018 and 2022, so scoring them on 2022 leaks, and they are shown
labelled as such); arm A (region shrinkage); arm A without shrinkage (raw region ratios); arm B (A + level slope).
Metric: RMSE of region share in percentage points, with n. Also the minor-group pattern test: for groups in both
2018 and 2022, predict 2022 region shares given the oracle 2022 statewide share, flat vs raw 2018 pattern vs shrunk.

The 2022 PUBLISHED lower-house forecast as an input is not attempted: no archived 2022 published region forecast
exists in this repo (the backtest predictions are model reruns, not what was published).

## Decision rule (fixed now)

- Switch "1" uses arm A if its RMSE pooled over the 2018 and 2022 backtests (48 cells) is below the uniform arm's;
  arm B replaces A only if it beats A pooled AND is not worse on either backtest. Otherwise switch "1" uses the
  uniform ratio with the fitted drift uncertainty (still an improvement in honesty, not in point estimate).
- Minor regional pattern: shrunk pattern used if its RMSE beats flat; else flat.
- An apparent win is unacceptable if it comes from one party alone (reported per party), or if the shrinkage weight
  is near 1 with tau2 estimated from 8 regions (reported).
- The switch ships "0". Pete decides on "1" from the live 0-vs-1 seat table.

## Addition, 26 Nov 2026, still before any model fit (original clauses above left unedited)

Added after a review of the plan, before fitting; the data tables built so far were descriptive (statewide and
region ratios by election), no model output.

1. **One Nation pooling is clustered on the election.** Federal state rows within one election are not
   independent (election-level sd about 0.26 in the 24 Nov walk). States are first pooled within each election
   (inverse-variance), then the meta-analysis runs over election-level units (federal elections, Victoria 2022,
   each DemosAU poll, each other-state upper house election if the sibling file lands). Weights are reported by
   source family. The simulation draws the predictive spread for a NEW setting (pooled se and tau), not only the
   se of the pooled mean. Rows dropped by the n >= 5 rule are counted.
2. **Majors' drift is correlated.** The statewide drift is split into a common part (all three majors move
   together, as when the minor pool grows) and a party part; both variances come from the 2010, 2018 and 2022
   statewide log ratios. One common draw per simulation, plus one per party.
3. **Oracle-level RMSE reported too.** 2010 had six groups per region and major ratios of 0.96 to 1.07, so a
   level miss shared by every arm can hide the regional evidence. Beside the pre-registered RMSE, each backtest
   also reports RMSE with each party's statewide ratio set to its actual value (labelled as an addition; the
   decision rule is unchanged).
4. **Minor groups:** groups named in the poll (DLP, Legalise Cannabis, Victorian Socialists) are held at their
   polled statewide level, with sampling error drawn; only the un-named groups are scaled to fill the pool.

## Second addition, 26 Nov 2026 (after the other-states file landed, before the Victorian model fit)

The sibling file `output/other-upper-house-fp.csv` (branch other-upper-houses 82039762) landed. Seen before
fitting: its statewide major-party ratios and One Nation's contested-district ratios (descriptive only).

5. **One Nation units from other states**: nsw2019, nsw2023, sa2026, wa2021, wa2025, each restricted to the
   districts where One Nation stood for the lower house (a statewide ratio is diluted by seats with no candidate;
   NSW 2019 statewide reads 6.3). sa2022 has statewide upper rows only and is left out. Each is one unit in the
   pooling. WA 2021 is labelled as a ticket-era unit.
6. **Group tickets are abolished for 2026; Victoria's 2010-2022 ratios are all ticket-era.** Two natural
   experiments are on disk: WA Legislative Council 2021 (tickets) to 2025 (none): log change ALP -0.02,
   LNP +0.19, GRN +0.07; the Victorian Senate 2013 (tickets) to 2016 (none, also a double dissolution):
   ALP -0.08, LNP -0.18, GRN -0.22. They disagree in sign, so no mean shift is applied. Their spread (pooled
   sd of the six changes) is added to the common statewide drift for 2026 as a regime-change variance, so the
   simulation carries the uncertainty instead of a guessed direction. Reported: the mean shift that WOULD
   apply, and the seat table it would move, so Pete can see the size of the bet.

## Results (26 Nov 2026, after fitting; revised the same evening after a review; full output in `upper-house-vote-model-2026-11-26-output.txt`)

**Backtest, majors.** Error in each party's upper-house region share, percentage points (lower is better); n = 24
cells per backtest (8 regions x 3 parties), lower-house actuals given.

| backtest | uniform ratio, last election | raw region effects | A: shrunk region effects | B: A + level slope |
|---|---:|---:|---:|---:|
| 2018 from 2010 | 4.24 | 7.10 | 7.10 (one election: no shrinkage possible) | 7.10 |
| 2022 from 2018 | 1.77 | 2.80 | 2.80 (one election) | 2.54 |
| 2022 from 2010+2018 | 1.77 | 3.89 | 3.30 | 3.53 |
| pooled, 48 cells (decision) | **3.25** | 5.73 | 5.54 | 5.61 |
| pooled, statewide level given (addition 3) | **1.97** | 2.64 | 2.41 | 2.48 |

The current constants score 1.67 on 2022 but were fitted on 2018 and 2022 themselves, so that is not a fair score.

**Decision (pre-registered rule): arm A does not beat the uniform ratio, so switch "1" uses a uniform statewide
ratio per party** (level = mean of 2018 and 2022: Labor 0.905, Coalition 0.845, Greens 0.882), with the whole
region spread as region noise (log sd 0.05 to 0.08).

**What the loss means (corrected).** It is NOT that region effects never repeat. Region deviations from the
statewide ratio correlate 0.70 (Labor) and 0.73 (Coalition) between 2018 and 2022, 0.18 for the Greens; between
2010 and 2018, 0.54, 0.29, 0.22. The loss comes from 2010 (a six-group ballot) and from the Coalition's 2018 spread
being 1.6 times 2022's, which one election cannot shrink. With the three-election shrinkage weights applied to
2018's effects (in-sample: the weights use 2022), 2022 from 2018 scores 1.48 against uniform 1.77 (Labor 1.89 v
2.36, Coalition 1.56 v 1.80, Greens 0.76 v 0.75). So region effects are a live alternative that the
pre-registered test could not clear; the seat table below shows it barely matters (64% against 65%).

**Drift (results addition 8, replacing addition 6's stacking).** Victorian history alone gives common log sd 0.095
and party 0.047, combined 0.106. Every statewide major ratio on disk (Victoria 2010-22, NSW, SA, WA, Victorian
Senate 2004-25; n = 17 per party) has log sd 0.068 (Labor), 0.079 (Coalition), 0.117 (Greens), ranges 0.81-1.01,
0.75-0.98, 0.79-1.22. Stacking the ticket-experiment variance on top (combined 0.190, 80% range x0.78 to x1.28)
is wider than everything ever observed: the Victorian history already contains the 2010-to-2018 regime change.
So switch "1" uses the Victorian drift alone. The stacked version stays in the table as the pre-registered one.

**One Nation.** Pooled ratio 0.879 (80% of draws 0.73 to 1.06) from 16 units. Weight by source: federal Senate vs
House 45% (8 elections), other states' upper houses 38% (no tickets 31%: SA 2026 1.05, NSW 2019 1.08, NSW 2023
0.87, WA 2025 0.78; WA 2021 with tickets 7%), DemosAU same-poll 11% (Nov 1.04, Feb 0.92), Victoria 2022 5%
(0.94, four districts). The weights are near equal per unit because the between-unit sd (0.14) swamps every
unit's own se, so a family's weight is mostly its unit count. Sensitivity: federal 2019 onward only 0.906;
Victorian federal rows only 0.870.

**Minor groups' regional pattern** (2022 from 2018, statewide 2022 level given, 9 groups, n = 72): flat 1.02
points, raw 2018 pattern 0.82, shrunk (w 0.76) 0.70. Shrunk pattern used. w is in-sample (it uses 2022).

**Minor split (results addition 7, replacing addition 4).** Holding the polled groups fixed and stretching the
rest made the un-polled groups absorb every swing in the pool: Family First and the Libertarians rose to about 0.7
seats each while Legalise Cannabis and DLP fell under 0.05. Now the pool is shared in proportion to every group's
level (polled groups at DemosAU's level times a sampling draw, Victorian Socialists at YouGov's regional figures,
the un-polled groups scaled together to DemosAU's "others" 10%, factor 1.35). After the fill (mean of regions):
DLP 4.1%, Legalise Cannabis 4.1%, Victorian Socialists 3.9%, other minors 9.7%, against DemosAU 4 / 4 / 3 / 10.

**NOISE kept.** The build script's `NOISE` (2.0 to 3.0 points per region) was hand-set in the walk with no sizing
(`upper-house-forecast-walk-2026-11-24/sim.R` line 29). Under switch 1 it stays as the lower-house regional
forecast error, which nothing else carries (the lower-house draws are statewide); the fitted ratio residual is
added on top. Possible double counting of up to half its size; not resolved.

**Arm C (poll blend).** Weight on the 21-25 Nov poll 0.29 / 0.19 / 0.17 (Coalition, Labor, Greens); shift +0.016,
-0.017, +0.007 (log). Not in switch 1; shown in the table.

**Live, 26 Nov 2026 inputs (forecast-latest), 4,000 simulations.** Mean seats of 40 (80% range); last two rows are
the chance of a 21-seat majority for each bloc.

| | switch 0 | **switch 1** | + ticket variance (prereg add. 6) | + region effects | + mean ticket shift | + WA ticket shift | arm C poll blend |
|---|---|---|---|---|---|---|---|
| Labor | 10.0 (8-12) | **9.8 (7-12)** | 9.8 (7-13) | 9.7 (8-12) | 9.4 (7-12) | 9.3 (7-12) | 9.6 (7-12) |
| Coalition | 12.7 (11-14) | **12.5 (10-15)** | 12.3 (9-15) | 12.4 (10-15) | 12.6 (10-15) | 14.6 (12-17) | 12.7 (10-15) |
| One Nation | 8.7 (7-11) | **8.8 (7-11)** | 8.6 (6-11) | 8.8 (7-11) | 8.9 (7-11) | 8.6 (6-11) | 8.8 (7-11) |
| Greens | 6.7 (5-9) | **6.3 (4-8)** | 6.1 (3-9) | 6.4 (4-9) | 5.8 (3-8) | 6.2 (4-9) | 6.3 (4-9) |
| minor groups | 1.8 (0-4) | **2.6 (0-6)** | 3.2 (0-9) | 2.7 (0-7) | 3.3 (0-7) | 1.3 (0-4) | 2.5 (0-6) |
| P(Coalition + One Nation >= 21) | 72% | **65%** | 58% | 64% | 69% | 91% | 69% |
| P(Labor + Greens >= 21) | 1% | **2%** | 5% | 2% | 1% | 1% | 2% |

Mean ticket shift = the average of the two experiments (Labor -0.05, Coalition +0.01, Greens -0.08, log); WA
shift = WA 2021 to 2025 alone (Labor -0.02, Coalition +0.19, Greens +0.07), the direction the other states'
no-ticket figures point. The WA case is the single biggest lever on the headline number.

Switch "0" output is byte-identical to origin/dev's script on the same inputs (built_at aside), re-checked after
these changes.

## Third addition, 26 Nov 2026 evening: a ballot-crowding term (Pete: "go"). Written BEFORE fitting it.

Why: 2010 (5 to 8 groups per region) is a different ballot from 2018 (18-19) and 2022 (22-24); 2026 has 11 to 16.
A uniform ratio averaged over 2018 and 2022 assumes the 2026 ballot is as crowded as those.

9. **Model, per major party k.** log(upper/lower) = a_k + b_k x + c_k ticket + e, fitted at the ELECTION level
   (one row per election: the regions of one election share its swing, so they are not independent rows), on
   Victoria 2010, 2018, 2022 and the six analogues nsw2019, nsw2023, sa2022, sa2026, wa2021, wa2025 (n = 9 per
   party, 3 parameters). ticket = 1 for Victoria 2010/2018/2022 and WA 2021.
   - **x = log(groups on the ballot per seat to fill)**, averaged over regions where a state has regions.
     Chosen over the raw group count because NSW (21 seats), SA (11) and WA 2025 (37) are single statewide
     ballots: 20 groups for 21 seats is not the same crowding as 20 groups for 5 seats, since the number of
     viable minor options a voter sees scales with the seats on offer (quota 4.5% against 16.7%). Raw log groups is
     reported as a sensitivity. The minor-vote share the ballot offers was rejected as x: it is the outcome
     (the majors' ratio is 1 minus it, nearly), so it would be circular.
   - Group counts: Victoria 2010 from the raw VEC files (parser above), 2018/2022 from the council results,
     2026 from `upper-house-groups-2026.csv` (ungrouped columns excluded everywhere); analogues from the state
     rows of `other-upper-house-fp.csv` (WA 2021 region rows), ungrouped excluded. Seats: Victoria 5 per region,
     NSW 21, SA 11, WA 2021 6 per region, WA 2025 37.
   - **Shrinkage on both terms**: each party's b_k and c_k (OLS) are partially pooled toward their
     precision-weighted mean across the three parties (DerSimonian-Laird, w = tau2 / (tau2 + se^2)); the
     intercept is then refitted given the shrunk b and c.
   - **Prediction for 2026**: each region at its own x (its 2026 group count / 5), ticket = 0. Uncertainty drawn
     per simulation: the residual sd of the election-level fit split into a common part (row means across the
     three parties) and a party part, plus the coefficient uncertainty x0' V x0 from the unshrunk OLS
     (conservative), plus the same region residual as switch 1.
10. **Backtest, time-forward.** Only analogues held BEFORE the target can enter: 2022 from Victoria 2010 + 2018 +
    nsw2019 + wa2021 + sa2022 (5 rows). 2018 from 2010 has one usable row (no analogue precedes it), so the
    crowding model is not estimable there and that cell is reported as such; pooled numbers are then over the 2022
    backtest only (24 cells) for all arms, with the original 48-cell table left as it was. A leaky variant fitted on
    every row is shown labelled, for reference only.
11. **Switch value "2"** = switch 1 with the majors' ratios from this model; "1" unchanged. Decision is Pete's,
    from the live table; this addition sets no automatic rule beyond reporting.
