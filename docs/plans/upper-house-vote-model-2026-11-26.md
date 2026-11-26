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
