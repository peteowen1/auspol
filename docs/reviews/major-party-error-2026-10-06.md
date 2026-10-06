# Where the Labor and Coalition primary-vote error comes from (2026-10-06)

Measurement only. No code in `R/`, `scripts/` or `output/` was changed and no harness was run.
Scripts (scratch, not committed): `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\599330fc-0de9-4609-8538-29a34fc021fd\scratchpad\majors\{a,b,c,d,g}.R`.

## Bottom line

The ALP and LNP error is mostly seat-specific noise that nothing available before the election predicts.
Three things carry structure, all small. Nothing here is a large, stable, removable pattern.

- 24.8% of major-party squared error is a statewide-level miss (the whole election off, every seat in the same direction).
  Pre-election attributes do not predict it.
- 75.2% is within-election seat allocation. Fourteen pre-election features, fitted time-forward, remove none of it
  (every block moved the out-of-time within-election squared error by -0.4% to +3.7%, i.e. no gain).
- The one pattern with a consistent sign is the two majors being collectively under-called in Victoria and Queensland, which means
  the non-major parties are over-called there. It is worth about 0.9% of major squared error out of time.

## Data and definitions

- `output/forecasts.csv`: 12,023 rows, 18 elections. ALP 1,809 rows, LNP 1,809 rows (3,618 total).
  Reproduced: RMSE ALP 5.136, LNP 4.789; ALP+LNP are 51.45% of all squared error.
- Signed error = `actual_share - xgb_pred` (positive = the model under-called the party). Checked: `|err|` equals `err_xgb` to 1e-13.
- Joins: `output/seat-context.csv` (previous margin, sitting member, retiring, by-election, has-previous-result),
  `output/candidacies.csv` (previous shares by party class, candidate names, party label), `output/census-features.csv`
  (education, birthplace, age, language; no metro/regional field exists, see unconfirmed items).
  All joins covered every row except 6 (seat-context) and are noted per slice.
- "Government party" = the major party holding the most seats in `seat-context` before the election. A proxy, not looked up.
- SE is clustered by election (the independent unit). With 2 to 3 elections in a cell, an SE is not a reliable guide.
  The SSE-share column is the share of that party's total squared error sitting in the group (it counts noise as well as bias).

## 1. Between-election versus within-election split

Squared error split into the election's own mean error (statewide-level miss) and the spread of seats around it. Share of total; the lower the between share, the more the error is seat allocation.

| Party | Total SSE | Between-election (statewide level) | Within-election (seat allocation) |
|---|---|---|---|
| ALP, n=1,809 | 47,723 | 13,864 (29.1%) | 33,859 (70.9%) |
| LNP, n=1,809 | 41,486 | 8,269 (19.9%) | 33,217 (80.1%) |
| Both, n=3,618 | 89,210 | 22,134 (24.8%) | 67,076 (75.2%) |

Reference: random cell labels with the same cell sizes explain 1,968 (95th percentile 2,319), so the 22,134 is real, not sampling.

Election mean error (SD across 18 elections): ALP 2.64, LNP 2.11 points. ALP and LNP election-mean errors correlate -0.36.
Within-election, seat-level ALP and LNP errors correlate -0.27. Within-election SD of the ALP-minus-LNP difference is 6.87, of the sum 5.20:
most within-election error is the two-party allocation (which major wins the seat's swing), not the minor-party share.

## 2. Slice tables

Every table: mean = average signed error in points (positive = model under-called the party; 0 is good), sd = spread, se = SE clustered by election,
rmse = root mean square error in points (lower is better), n = rows.

### 2.1 By election

Mean signed error per election and party; n is 47 to 151 per cell. Elections with a large mean are a statewide-level miss.

| Election | ALP mean | ALP rmse | LNP mean | LNP rmse |
|---|---|---|---|---|
| fed2010 | -0.78 | 4.37 | 2.96 | 5.43 |
| fed2013 | -0.97 | 3.73 | -0.14 | 4.09 |
| fed2016 | 1.55 | 4.23 | -1.31 | 4.46 |
| fed2019 | -3.22 | 5.41 | 3.01 | 5.05 |
| fed2022 | -3.22 | 5.83 | 1.65 | 3.90 |
| fed2025 | 3.39 | 5.63 | -3.11 | 4.92 |
| nsw2019 | -2.21 | 4.93 | -0.08 | 5.34 |
| nsw2023 | 2.14 | 5.81 | -1.14 | 5.30 |
| qld2020 | 6.38 | 7.56 | 0.50 | 4.28 |
| qld2024 | 1.94 | 4.75 | 0.44 | 3.18 |
| sa2022 | -1.09 | 4.36 | -1.47 | 4.76 |
| sa2026 | -0.43 | 4.62 | 1.99 | 4.98 |
| vic2014 | 2.71 | 4.04 | 2.82 | 4.74 |
| vic2018 | 4.23 | 6.62 | -1.83 | 4.61 |
| vic2022 | 1.36 | 4.40 | 3.93 | 5.86 |
| wa2013 | 0.70 | 4.33 | 1.80 | 6.69 |
| wa2017 | 3.88 | 5.64 | -1.53 | 4.21 |
| wa2025 | 0.82 | 4.26 | -2.35 | 4.27 |

Eleven of 36 cells have a mean over 2 points in size; the worst is qld2020 ALP +6.38 (rmse 7.56). Yes, some elections are biased as a whole.

### 2.2 By jurisdiction

Mean signed error by jurisdiction (2 to 6 elections each, so SEs are rough).

| Jurisdiction | Party | n | Elections | Mean | se | rmse |
|---|---|---|---|---|---|---|
| fed | ALP | 902 | 6 | -0.55 | 0.98 | 4.93 |
| nsw | ALP | 186 | 2 | -0.03 | 1.54 | 5.39 |
| qld | ALP | 186 | 2 | 4.16 | 1.57 | 6.31 |
| sa | ALP | 94 | 2 | -0.76 | 0.24 | 4.49 |
| vic | ALP | 263 | 3 | 2.78 | 0.67 | 5.16 |
| wa | ALP | 177 | 3 | 1.80 | 0.85 | 4.79 |
| fed | LNP | 902 | 6 | 0.51 | 0.92 | 4.67 |
| nsw | LNP | 186 | 2 | -0.61 | 0.38 | 5.32 |
| qld | LNP | 186 | 2 | 0.47 | 0.02 | 3.77 |
| sa | LNP | 94 | 2 | 0.26 | 1.22 | 4.87 |
| vic | LNP | 263 | 3 | 1.67 | 1.46 | 5.09 |
| wa | LNP | 177 | 3 | -0.69 | 1.04 | 5.19 |

### 2.3 Sum of the two majors' errors (equals minus the non-major error), by jurisdiction

Mean of (ALP error + LNP error) per seat, in points. Positive = the two majors together were under-called, so the model over-called the non-major parties.
Zero is good. n = 1,809 seats; overall mean +1.12, se 0.59.

| Jurisdiction | Seats | Elections | Mean | se | By election |
|---|---|---|---|---|---|
| fed | 902 | 6 | -0.03 | 0.49 | 2.19, -1.11, 0.24, -0.21, -1.57, 0.28 |
| nsw | 186 | 2 | -0.64 | 1.16 | -2.28, 1.00 |
| qld | 186 | 2 | 4.63 | 1.59 | 6.88, 2.39 |
| sa | 94 | 2 | -0.50 | 1.46 | -2.56, 1.57 |
| vic | 264 | 3 | 4.41 | 0.82 | 5.54, 2.40, 5.30 |
| wa | 177 | 3 | 1.11 | 1.08 | 2.50, 2.35, -1.53 |

Same quantity by the model's own predicted combined non-major share in the seat (known before the election). Positive = over-called.

| Predicted non-major share | n | Mean | se | sd |
|---|---|---|---|---|
| 5.5 to 18.6 | 362 | -0.21 | 0.70 | 4.43 |
| 18.6 to 22.3 | 362 | 0.67 | 0.63 | 5.20 |
| 22.3 to 26.7 | 361 | 1.41 | 0.65 | 4.89 |
| 26.7 to 32.2 | 362 | 1.36 | 0.97 | 6.54 |
| 32.2 to 76.4 | 362 | 2.38 | 0.97 | 7.10 |

Within-election slope of actual on predicted non-major share is 0.929 (1.0 is calibrated): predictions are a little too spread out.

### 2.4 Redistribution (no previous result for the seat)

Mean signed error for seats with and without a previous-election result (renamed or new seats).

| Party | Group | n | Elections | Mean | se | rmse |
|---|---|---|---|---|---|---|
| ALP | has previous | 1,747 | 18 | 0.69 | 0.70 | 5.14 |
| ALP | no previous | 62 | 12 | 0.77 | 1.03 | 5.08 |
| LNP | has previous | 1,747 | 18 | 0.43 | 0.55 | 4.80 |
| LNP | no previous | 62 | 12 | 0.25 | 0.71 | 4.38 |

No difference. Redistribution is 3% of the error.

### 2.5 Sitting-member status for the party

Mean signed error by whether the party's own sitting member is standing (positive = party under-called).

| Party | Status | n | Elections | Mean | se | rmse |
|---|---|---|---|---|---|---|
| ALP | its member standing | 738 | 18 | 1.14 | 0.79 | 5.25 |
| ALP | its member retiring or departed | 111 | 17 | 0.20 | 0.81 | 5.54 |
| ALP | other major holds the seat | 809 | 18 | 0.38 | 0.69 | 4.98 |
| ALP | minor or independent holds it | 89 | 15 | 0.42 | 1.00 | 5.09 |
| ALP | no previous result | 62 | 12 | 0.77 | 1.03 | 5.08 |
| LNP | its member standing | 693 | 18 | 0.56 | 0.64 | 5.03 |
| LNP | its member retiring or departed | 116 | 18 | -0.60 | 0.65 | 5.36 |
| LNP | other major holds the seat | 849 | 18 | 0.38 | 0.59 | 4.34 |
| LNP | minor or independent holds it | 89 | 15 | 1.30 | 0.93 | 6.17 |
| LNP | no previous result | 62 | 12 | 0.25 | 0.71 | 4.38 |

Sitting-and-standing is +1.14 / +0.56 against about +0.4 elsewhere: under 1 SE and unstable (ALP early +0.43, late +1.82; LNP early +0.91, late 0.00).
Same candidate as last time (matched on name): ALP +1.08 (se 0.86, n=798) vs new +0.36 (n=949); LNP +0.61 vs +0.27. Under 1 SE.

### 2.6 Government versus opposition

Mean signed error for the governing and opposing major, pooled across ALP and LNP rows (18 elections each side). Zero is good.

| Group | n | Mean | se (naive clustered) |
|---|---|---|---|
| Government party | 1,809 | +1.25 | 0.52 |
| Opposition party | 1,809 | -0.13 | 0.63 |

The right test pairs the two within each election: government minus opposition mean error is +0.98, se 0.91, t 1.08, positive in 11 of 18.
Early nine elections +0.49 (se 1.35), late nine +1.47 (se 1.27). The naive table overstates it because the two rows in an election are negatively linked.

### 2.7 Previous margin and previous share

Previous margin (`margin_est`, the party's own side signed) and previous primary share: no monotone pattern.
By own previous primary share decile the mean runs -0.47 to +1.83 (ALP) and -0.41 to +1.26 (LNP), with every se 0.5 to 1.1.
By model-predicted swing quintile the means run -0.45 to +1.71 (ALP) and -0.12 to +1.32 (LNP), no gradient. A within-election regression of error on previous share has slope -0.003 (ALP) and -0.041 (LNP).

### 2.8 Previous strength of a minor party in the seat

Mean signed error by the minor party's previous share in the seat. Few elections in the high bands, so SEs are unreliable.

| Group | n (elections) | ALP mean | LNP mean |
|---|---|---|---|
| Previous One Nation 0 | 1,241 (18) | 0.20 | 0.69 |
| One Nation 0 to 5 | 238 (9) | 2.21 | -0.84 |
| One Nation 5 to 10 | 153 (7) | 0.78 | -0.91 |
| One Nation 10 to 15 | 50 (7) | -0.22 | 0.65 |
| One Nation 15 to 25 | 48 (4) | 4.82 | 3.61 |
| One Nation over 25 | 17 (2) | 5.28 | 2.29 |
| Previous independent over 25 | 58 ALP, 58 LNP (17) | -0.19 | 2.28 (se 1.24, rmse 7.35) |
| Previous Greens 0 to 5 | 237 (18) | -0.99 | 0.62 |
| Previous Greens over 25 | 46 (13) | 2.52 | 0.75 |

Where One Nation was strong, both majors were under-called: the model over-called One Nation. Only 65 rows in 3 to 5 elections (late elections: 59 rows from 3; early 6 from 1 with opposite sign for ALP).

### 2.9 Other slices

- Three-cornered (Liberal and National both on the ballot): LNP +2.88 (se 0.65, n=96, 6 elections); early +3.25 (n=85, 4 elections), late +0.06 (n=11). Nearly gone from recent elections.
- LNP row labelled National Party: -0.80 (n=72); Liberal Party: +0.70 (n=638). Both under 1 SE.
- Census quartiles (education, born in Australia, over 55, under 35, other language at home): ALP means run -0.64 to +1.58 across quartiles, LNP 0.0 to +0.87; the ALP gradient persists out of time (section 3) but shrinks from early to late elections.
- Seat held by an independent or minor party is in 2.5. Seat with a by-election since last: ALP +0.23, LNP -0.35 (n=59), nothing.
- Seats with a retiring incumbent of any party: ALP +0.52, LNP +0.41 (n=239); rmse 5.57 / 5.68 against 5.07 / 4.64 otherwise (wider, not biased).

## 3. Ranked patterns

Ranked by squared error they account for, not by how interesting they are. "Removable" is what a time-forward correction removed.
Explained SS is in-sample sum of n times mean squared, as a share of the 89,210 total.

| Rank | Pattern | In-sample explained | Removable out of time | Stable across elections? |
|---|---|---|---|---|
| 1 | Statewide level miss (election mean) | 22,134 (24.8%) | none found | Sign flips by election; not predicted by government/opposition (paired t 1.08), time-forward gov/opp correction -0.4% |
| 2 | Non-majors over-called in Vic and Qld (majors summed +4.4 / +4.6) | about 4,560 (5.1%) if perfectly corrected | -0.9% (time-forward, jurisdiction-shrunk); gain is vic2022 -752 and qld2024 -264; wa2025 and nsw2023 got worse | Vic positive in 3 of 3 elections, Qld 2 of 2; WA 2 of 3; NSW/SA negative; fed zero |
| 3 | One Nation previously strong: majors under-called | 2,301 (2.6%) | not tested out of time (65 rows) | Not stable: early (n=6, 1 election) has the opposite ALP sign |

Not on the list because they failed: government/opposition level (4.8% in-sample, 0.4% out of time, paired t 1.08), sitting-member status (1.9%), previous share (2.7%), predicted swing (3.3%). Census (ALP only, -3.2% of ALP within-election error out of time) is a fourth pattern, about the size of pattern 2.

Out-of-time test (train on earlier elections, score later, fitted within-election, elections 6 to 18): change in within-election squared error, negative is better.

| Feature block | ALP | LNP |
|---|---|---|
| Own previous share and predicted swing | +0.35% | +0.55% |
| Sitting, retiring, minor-held | +0.33% | +1.02% |
| Previous One Nation, Greens, independent share | -0.43% | +3.75% |
| Census (4 variables) | -3.18% (better) | +1.86% |
| Three-cornered (LNP only) | n/a | -0.11% |
| All 14 together | not valid, see unconfirmed | +3.47% |

Positive means the correction made the out-of-time error larger (worse). The one improvement is ALP with the census block (-3.18% of ALP within-election squared error, about 0.9% of major squared error): seats with more people born overseas or speaking another language at home are under-called for Labor (born in Australia top quartile -0.64, bottom +1.41; early elections -1.13 vs late -0.10, so the size is not stable). The existing `R/demographic_residual.R` and `R/education_residual.R` (`AUSPOL_EDU_RESID=0`, off) target the same thing; a candidate for a pre-registered ALP-only demographic residual, about the size of pattern 2.

## 4. What already targets each pattern, and one proposed fix

### Pattern 1: statewide level miss

- Existing: the statewide stage (poll trend in `R/trend.R`, `R/forecast_statewide.R`), `R/fundamentals.R` (which party governs and for how long),
  `R/state_deviation.R` (federal seats corrected for their state's swing, `AUSPOL_STATE_DEV=1`), `R/state_poll_pool.R` (v60).
- Why error remains: the statewide level is the poll average plus a fundamentals prior, so a poll miss (qld2020 ALP +6.4, fed2019/2022 -3.2, fed2025 +3.4) passes straight through.
  A government-versus-opposition bias is not detectable at 18 elections (paired t 1.08), so there is nothing to subtract.
- Proposed fix (one): none for the point forecast. Check the simulation's statewide level spread against the observed SD of election-mean error (ALP 2.64, LNP 2.11).
  If the draws are narrower than that, widen them in `R/forecast_statewide.R` (fallback_sd). This is a calibration fix, it does not change the central number. Not verified here.

### Pattern 2: non-majors over-called in Victoria and Queensland (and in seats where the model predicts a big non-major share)

- Existing: `R/others_bucket.R` / `AUSPOL_OTHERS_SCALE` (shrinks the unpolled others bucket by its time-forward poll bias; REFUSED 2026-09-28, backtest-only, off),
  `AUSPOL_SHRINK=0.01`, `AUSPOL_LEVEL_SD`, `AUSPOL_DISPERSION_SLOPE=0` (built, off), `AUSPOL_EDU_RESID=0`.
- Why error remains: the refused arm pooled all jurisdictions, and this pattern is jurisdiction-specific (fed 0, nsw and sa negative, vic and qld +4.4 and +4.6).
  A pooled time-forward bias averages to near zero.
- Proposed fix (one): a jurisdiction-specific, shrunk non-major level in `others_bucket_scale()` (`R/others_bucket.R`), with the shrinkage weight `w = m^2 / (m^2 + se^2)`
  already there but fitted per jurisdiction from earlier elections of that jurisdiction, falling back to the pooled value when fewer than 2 exist.
  Pre-register it (grid, criterion, what would make a win unacceptable) and score it on vic2022, qld2024, vic2018 first. Honest size: -0.9% of major squared error out of time,
  almost all vic2022. It matters mainly because vic2026 is the live target. This is a proposal for a measured arm, not evidence it works.

### Pattern 3: One Nation seats

- Existing: `AUSPOL_ONP_CONC_SD`, `R/party_surge.R`, `R/salience_surge.R`, `R/onp_senate.R`, the breakout mixture (`R/breakout_mix.R`, refused twice).
- Why error remains: 65 rows in 3 to 5 elections cannot separate a bias from a few seats. Documented overcalled-independents item is already open.
- Proposed fix (one): none until the One Nation seat count grows (vic2026 has none in the as-at table: One Nation rows are absent in Victoria).

## 5. Unconfirmed items

- No metro/regional/rural field was found in `docs/DATA-REGISTRY.md`; census quartiles (education, born abroad, age, language) stand in. `output/seat-centroids.csv` (state seats only, 1,164 rows) was not used. Metro/regional is therefore NOT tested.
- "Government party" is the major with the most pre-election seats in `seat-context.csv`, not a looked-up fact. Coalition-versus-Labor governing at a federal level for state elections is not tested.
- "Retiring or departed" is the `retiring` flag in `seat-context.csv`; I did not check how it is built.
- Candidate matching ("same candidate as last time") is exact name match against `candidacies.csv`; renames and spelling differences would count as new.
- The "all 14 features" out-of-time row for ALP is invalid: a constant column (the three-cornered flag is zero for ALP) made the coefficients NA and the result 0.00%. The LNP row and each block are valid.
- The first expanding-window fit (uncentred features with an intercept) showed -9.6% / -56.8% and was discarded as an extrapolation artefact; the centred version (section 3) is the one reported.
- Cluster SEs with 2 to 3 elections per jurisdiction are not trustworthy; they are shown, not leaned on.
- `forecasts.csv` is the as-at table with the shipped configuration at the 2026-10-06 rebuild; I did not check that every row's `built_at` is the same rebuild.
- Statewide level SD in the simulation was not read (only grepped). The comparison in pattern 1's fix is unverified.
- Not tested: previous-election seat swing (the seat-swing port), HTV cards, preference flows effects on primary error; these target seat-level swing and the seat-level error here looks like noise.
