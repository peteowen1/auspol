# Is the simulated statewide spread as wide as the real statewide misses? (2026-10-06)

Measurement only. No code in `R/`, `scripts/` or `output/` was changed and no harness was run.
Scratch scripts (not committed): `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\599330fc-0de9-4609-8538-29a34fc021fd\scratchpad\spread\{a,c}.R`; data `statewide.csv` in the same folder.

## Bottom line

Calibrated for the two majors, no change. The simulated statewide SD for ALP and LNP is about 2.6 points; the real statewide miss has an RMS of 2.73 (ALP) and 2.30 (LNP).
SD of z is 0.95 over 44 party-elections (1.0 is calibrated). If anything the spread is too wide for the Greens and the others total, not too narrow for anyone.
The review's pattern 1 ("check the draws are not narrower than 2.64 / 2.11") is answered: they are not.

## How the numbers were made

- Simulated statewide SD: `forecast_statewide_for()` run for the 22 scored pairs (wa2021 has no trend, skipped, as in the audit script), at 20,000 draws, seed 42, with the time-forward fundamentals and mix (`AUSPOL_FUND_TIME_FORWARD=1`, the published setting). Per party: SD and mean of the draw column after the folded classes are split out of OTH.
  This is the object `simulate_seat_contests()` uses: it centres the draws on their own column means and adds each draw's deviation to every seat (`R/seat_sim.R:987-998`), so the draw SD is the statewide SD the seats see.
- Realised statewide: sum of candidate votes per class in `output/candidacies.csv` (same source as `scripts/audit_statewide_forecast.R`). Miss = actual - draw mean (positive = the party did better than forecast). z = miss / simulated SD.
- "Others total" is 100 - ALP - LNP - GRN (so it includes IND, ONP, OTH, OTH_RIGHT) with SD taken from the sum of the three draw columns. Per-column SDs for IND, OTH, OTH_RIGHT and a folded ONP are not used: the fold splits one OTH draw by a fixed ratio, so they have no spread of their own (SD 0.00 in four pairs) and a z against them is meaningless (z up to 13).
- ONP is scored only in the 9 pairs where it was polled (not folded).

## Calibration of the statewide level

Each row is one party over the 22 pairs. Miss and SD are in first-preference points. sd z and rms z compare the real misses to the simulated spread: 1.00 is calibrated, above 1 is over-confident, below 1 is too wide. Share beyond 1.96 sigma should be 5%. n is party-elections.

| Party | n | Mean miss | RMS miss | Mean simulated SD | sd of z | RMS z (95% CI, resampling elections) | Beyond 1.96 sigma |
|---|---|---|---|---|---|---|---|
| ALP | 22 | +0.26 | 2.73 | 2.61 | 1.05 | 1.03 (0.79 to 1.26) | 1 of 22 (4.5%) |
| LNP | 22 | +0.72 | 2.30 | 2.65 | 0.84 | 0.87 (0.71 to 1.02) | 0 of 22 |
| ALP + LNP | 44 | +0.49 | 2.52 | 2.63 | 0.95 | 0.96 (0.82 to 1.08) | 1 of 44 (2.3%) |
| GRN | 22 | -0.10 | 1.13 | 2.30 | 0.56 | 0.55 (0.35 to 0.73) | 0 of 22 |
| ONP (polled only) | 9 | -0.26 | 2.54 | 2.35 | 1.06 | 1.01 | 0 of 9 |
| Others total | 22 | -0.87 | 2.63 | 3.36 | 0.73 | 0.75 (0.58 to 0.92) | 0 of 22 |

By region, majors only (n party-elections): fed 14 RMS z 0.99; vic 6, 1.03; qld 4, 1.04; wa 12, 1.07; nsw 4, 0.49; sa 4, 0.50.
The four NSW and SA party-elections are well inside the band; nothing region-specific is too narrow, but each cell is 4 to 14 rows.

Worst single cases: qld2020 ALP +4.8 (z 1.8), vic2018 ALP +4.1, fed2022 ALP -4.1, wa2017 ALP +5.7 (z 2.1, the only major beyond 1.96), wa2001 ALP -3.9.
The SD across elections of the ALP miss is 2.78 and of the LNP miss 2.24, against the earlier review's 2.64 and 2.11. The small difference is that review used the seat-mean error of the final xgb prediction; this is the statewide forecast the draws are centred on. Same size either way.

The simulated spread (2.5 to 2.9 per major) is wider than the poll-trend band alone because `fp_extra_sd = 2.419` is added in quadrature (`R/forecast_mode.R:72`, adopted in `docs/reviews/fp-widening-choice-2026-08-19.md`). That is what makes it calibrated; without it the spread would be about 1.4 to 1.9 and clearly too narrow.

## Seat consequence

Per election, seat log loss (clamped at 1e-6; lower is better) and Brier from `output/forecasts-seats.csv` (22 elections, 2,120 seats; 6 seats whose winner had no probability row score the 1e-6 clamp). Pooled: log loss 0.3271, Brier 0.1725.
Correlated with the election's mean |statewide miss| over ALP and LNP. r is Pearson over elections, SE = (1 - r^2)/sqrt(n - 2).

| Comparison | n elections | r | SE | Spearman |
|---|---|---|---|---|
| Seat log loss vs mean abs miss, all | 22 | 0.60 | 0.14 | 0.50 |
| Seat Brier vs mean abs miss, all | 22 | 0.64 | 0.13 | 0.61 |
| Seat log loss vs mean abs z, all | 22 | 0.53 | 0.16 | 0.46 |
| Seat log loss vs mean abs miss, federal only | 7 | -0.61 | 0.28 | -0.71 |
| Seat log loss vs mean abs miss, states only | 15 | 0.72 | 0.13 | 0.71 |

Slope: +0.109 log loss per point of mean abs miss (SE 0.032).
By tercile of |miss| (seat-weighted): small miss (8 elections, 628 seats, mean 1.22 points) log loss 0.296; mid (7, 835, 2.10) 0.311; large miss (7, 657, 3.13) 0.378.

Reading: yes, a bigger statewide miss costs seat log loss, but that is expected even from a calibrated model, because a large miss moves many seats at once. It is not evidence the spread is too narrow. The test that bears on that is the z table above, and it says the spread is about right. The federal elections go the other way (r -0.61 on 7 elections, SE 0.28, not meaningful); the state correlation is driven by WA (wa2001 log loss 0.882, wa2008 0.707, both with 57 to 59 seats and polling-thin cycles).

## Multiplier proposal

None: calibrated, no change.
For the record, a time-forward statewide SD multiplier (each election scored by RMS z over ALP, LNP, GRN and others total from earlier elections only, shrunk toward 1 with 11 pseudo-observations) comes out at 0.85 to 1.09 and drifts down to 0.85 by sa2026 (n = 84 prior z values). That is below 1, so a multiplier would narrow the draws, which is the opposite direction from the concern. It is driven by GRN (z 0.55) and the others total (0.75), which have much smaller real misses than their simulated SDs. Majors alone sit at 0.96. Scaling those two classes down is a possible later, separate test but is not recommended here: it needs the MDE of seat log loss sized first and would shrink a spread that the majors need.

## Unconfirmed

- Seat-level noise: I did not check how much statewide-scale spread the independent per-seat noise (`AUSPOL_LEVEL_SD`, 1.10 + 8.67*sqrt(p(1-p)), `AUSPOL_PARTY_COR` shrunk) adds to the seat-weighted statewide total. If seat deviations are independent across seats it averages out (roughly 0.5 points over 100 seats); not read from `seat_sim.R`.
- The published forecast also runs `xgb_primary_predict_live`, which sets its own base_margin from this run's shares; I measured the statewide draws going in, not the seat-weighted statewide of the final xgb-adjusted shares.
- Actual statewide comes from summed candidate votes in `candidacies.csv`; class definitions (NAT folded into LNP, sa2026 LNP 17.7 vs ONP 22.5) were not audited per pair, and these misses were not compared with `output/statewide-forecast-audit.csv` (not regenerated).
- Seed 42 and 20,000 draws, one run. Misses are 22 elections: RMS z has a CI of roughly 0.8 to 1.1 for the majors, so a true multiplier of 0.9 to 1.1 cannot be separated from 1.
- wa2021 not scored (no trend), consistent with the other builders.
