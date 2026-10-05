# Personal-vote rows need a wider SD: measurement, 2026-10-05

Measure only. No harness or rebuild was run, and nothing in `R/`, `scripts/` or `output/` was changed.
Scratch scripts are in the session scratchpad (`pvsd/s1_tag.R`, `s2_stats.R`, `s4_mult.R`, `s5.R`).

## Answer in one paragraph

Rows that lean on a candidate's own vote have a realised spread of 1.5 to 2.6 times the SD the model gives them. The pooled group (111 rows) is 1.73x (cluster-bootstrap 95% interval 1.38 to 2.09). The model gives them the same SD as any other row: `1.10 + 8.67*sqrt(p(1-p))`, about 5.3 points at p = 0.30. A time-forward, shrunk multiplier of about 1.65 improves the row-level Gaussian log score out of sample. Its effect on seat log loss in the 7 AEF-7 pairs is not distinguishable from zero (about -0.0003, paired SE 0.0016, approximate). Widening helps seats where the person collapsed (MacKillop, Goldstein, Griffith) and hurts seats where the person held (Kavel, Kiama, Balmain). The existing XGBoost SD layer (`AUSPOL_XGB_PRIMARY_SD`, off in the published config) already assigns these rows 7.4 to 10.5 points, so most of the fix already exists and is switched off.

## 1. How per-row SD is set today

- **Shipped default, every cell:** `a + b*sqrt(p(1-p))` with `AUSPOL_LEVEL_SD = "1.10,8.67"` (`scripts/published_flags.R:29`; built at `scripts/fit_seats_full.R:36-52`; used in `R/seat_sim.R:1225-1229`). The per-class multipliers `AUSPOL_LEVEL_MULT_IND` and `_OTH` are 1 (`published_flags.R:79-80`), and majors are never touched. A defector, a returning teal and a first-time stranger at the same predicted share get the same SD.
- **`sd_override`** (`R/seat_sim.R:1006-1030`): a seats x classes matrix, `NA` meaning "keep level_sd". Several overrides combine by elementwise maximum (`combine_sd_override`, `R/reentry_prior.R:632`).
- **XGBoost SD layer** (`scripts/fit_xgb_primary_sd.R`, `R/xgb_primary_sd_override.R:45-142`): predicts the absolute error of the shipped primary prediction and converts it to an SD (leave-one-pair-out). It is restricted to the IND, OTH, OTH_RIGHT and ONP classes (`:85`). `AUSPOL_SD_DEPARTED=1` (`:93-124`) extends it to ALP and LNP in seats whose previous winner is gone.
- **It is off in the published forecast.** `AUSPOL_XGB_PRIMARY_SD = "0"` (`published_flags.R:375`). The file header says there is no live path (`xgb_primary_sd_override.R:34-37`). `fit_seats_full.R:1505` calls `simulate_seat_contests()` with no `sd_override`. Only the six backtest harnesses read it, for example `scripts/backtest_candidate_fed.R:1827-1831`. (Confirmed by grep of those two files; I did not read the other five harnesses end to end.)

## 2. Residual SD by personal-vote type

Residual = `actual_share - xgb_pred` in points of primary vote, from `output/forecasts.csv` (as-at, 18 elections, 9,534 rows with a named candidate; padding rows with no candidate are dropped). "Model SD" is the shipped `level_sd` formula evaluated at `xgb_pred` (assumed to be what the simulation sees; unconfirmed, see below). RMS z is realised SD divided by model SD, so 1.00 is calibrated and higher means the model is over-confident. The robust SD is 1.4826 x MAD.

| Type | n | Mean resid | Residual SD | Robust SD | Model SD | XGB-SD layer (sd_hat) | RMS z | % of rows with abs z > 2 |
|---|---|---|---|---|---|---|---|---|
| major: other | 2,016 | 0.55 | 4.75 | 4.51 | 4.95 | n/a (not set) | 0.99 | 3.7 |
| major: sitting member returns | 1,323 | 0.71 | 5.01 | 4.88 | 5.37 | n/a | 0.94 | 3.5 |
| major: member departed (successor) | 276 | -0.06 | 5.88 | 5.85 | 5.32 | n/a | 1.13 | 5.1 |
| first-time non-major | 4,999 | -0.04 | 3.68 | 2.38 | 3.19 | 3.00 | 1.17 | 4.7 |
| returning non-major (not sitting) | 809 | -0.67 | 3.24 | 2.20 | 3.35 | 2.93 | 1.00 | 2.7 |
| **returning non-major sitting member** | 72 | 0.61 | 7.58 | 7.05 | 5.27 | 7.86 | 1.48 | 15.3 |
| **defector (sitting major MP, now non-major)** | 19 | -1.03 | 9.62 | 5.32 | 4.29 | 7.96 | 1.96 | 21.1 |
| **non-major: class member departed (successor)** | 15 | -3.99 | 9.53 | 10.25 | 4.28 | 10.46 | 2.13 | 46.7 |
| **non-major by-election winner** | 5 | 7.05 | 13.21 | 16.87 | 5.26 | 7.42 | 2.64 | 60.0 |
| **Personal-vote group, pooled (the 4 bold rows)** | 111 | | | | | | 1.73 | 23 |

Named cases are tagged as expected: Cregan Kavel sa2022 (27.9 predicted, 50.5 actual, z +4.5), Ward Kiama nsw2023 (30.5 vs 38.8), Ellis Narungga sa2022 (36.0 vs 40.8) and sa2026 (30.5 vs 17.0), Johnson Ryan fed2010 (30.6 vs 8.5, z -4.4), McBride MacKillop sa2026 (31.1 vs 15.0, z -3.2). Broadfoot Grey fed2019 (28.0 vs 6.9) is tagged "returning non-major (not sitting)", not personal-vote, because she lost in 2016. That is a real gap in the typing: her 2016 result made her the class base, so the model leaned on her personal vote anyway.

Shape of the pooled distribution (n = 111): median abs z 1.04, excess kurtosis 0.40, 23% of rows beyond 2 SDs. The outcome is wide rather than heavy-tailed once the SD is right. The sd_hat column gets rms z of 1.02 to 1.19 on three of the four types and 1.96 on by-election winners (n = 5).

Side findings, outside the question:
- First-time independents have RMS z of 2.06 (n = 674, robust SD 3.1 against realised 6.6) and first-time ONP 1.45. That is the known teal and emergence tail. These cells are exactly what the XGB SD layer widens.
- "Major: member departed (successor)" is 1.13 (n = 276, 95% interval 0.99 to 1.27). Not significant on its own.

## 3. Per-type SD multiplier, time-forward, shrunk toward 1

Method:
- k = sqrt(mean z^2) per type (the Gaussian maximum-likelihood scale of residual over model SD).
- SE of log k is the larger of the delta-method SE and an election-cluster bootstrap SE (1,000 resamples of elections), because rows within an election are correlated.
- Shrinkage: `w = tau^2 / (tau^2 + se^2)` applied to log k, with tau^2 estimated by moments across the 9 types (full sample 0.132). The multiplier is `exp(w * log k)`.
- Time-forward means that for election E the multiplier uses only elections dated strictly before E.

Full-sample multipliers (the SE column is the SE of log k; k95 is the cluster-bootstrap interval for raw k):

| Type | n | Raw k | k 95% interval | SE of log k | Shrink weight w | Multiplier |
|---|---|---|---|---|---|---|
| returning non-major sitting member | 72 | 1.48 | 1.14-1.93 | 0.134 | 0.88 | **1.41** |
| defector | 19 | 1.96 | 1.25-2.55 | 0.187 | 0.79 | **1.70** |
| non-major class member departed (successor) | 15 | 2.13 | 1.25-2.75 | 0.200 | 0.77 | **1.79** |
| non-major by-election winner | 5 | 2.64 | 1.29-3.31 | 0.272 | 0.64 | **1.86** |
| **pooled personal-vote group** | 111 | 1.73 | 1.38-2.09 | 0.112 | 0.91 | **1.65** |
| major: other / sitting returns / departed successor | 2,016 / 1,323 / 276 | 0.99 / 0.94 / 1.13 | | 0.04 / 0.05 / 0.07 | 0.96-0.99 | 0.99 / 0.95 / 1.13 |

Out-of-sample check (time-forward multiplier applied to the same rows, per-row Gaussian negative log likelihood, positive gain = better, in nats per row):

| Rows | n | Mean multiplier | Gain | SE |
|---|---|---|---|---|
| pooled personal-vote types | 106 | about 1.5 | +0.193 | 0.108 (1.8 SE) |
| by election block (13 elections) | | | +1.57 per election | 1.32 |
| defector | 18 | 1.50 | +0.43 | 0.32 |
| returning sitting | 70 | 1.46 | +0.12 | 0.12 |
| all other types | | | -0.16 to +0.004 | the large-n types are within 1 SE of zero |

For comparison, the existing XGB SD layer on the same 111 rows (leave-one-pair-out, so not strictly time-forward) gains +0.343 nats per row, SE 0.160, against the shipped level_sd. It beats a flat 1.65x on these rows because it widens the departed-successor cell most and the returning-sitting cell least.

## 4. Approximate effect on seat probabilities (no rebuild)

Method (an approximation, not a simulation):
- Seats are the 681 AEF-7 seat-elections in `output/aef-comparison-full.csv` (fed2022, fed2025, qld2024, nsw2023, vic2022, wa2025, sa2026). Its `our_p` equals `win_prob` of the actual winner in `output/forecasts-seats.csv` for all 681 (max abs difference 0).
- 53 seats have at least one personal-vote class (leading candidate tagged as one of the 4 types).
- For each, take the affected class and its strongest rival. Back out the implied margin from `p_class / (p_class + p_rival)` as `qnorm(p) * S`, with `S^2 = s_c^2 + s_r^2` from the level_sd formula at `xgb_pred`. Rescale `s_c` by the multiplier, then recompute `pnorm(M / S')`. Other classes keep their probabilities.
- It ignores preference flows, the statewide shift, party SDs and the simulation floor (1 / 20,000 = 0.00005). Treat it as direction and size, not a forecast.

Log loss is on the actual winner's win probability, clamped at 1e-6 (lower is better). Paired SE is over seats.

| Multiplier source | Seats | Before | After | Difference | Paired SE |
|---|---|---|---|---|---|
| time-forward, all 681 seats | 681 | 0.2827 | 0.2824 | -0.0003 | 0.0016 |
| time-forward, 53 affected seats only | 53 | 0.4915 | 0.4875 | -0.0040 | 0.0205 |
| full-sample multipliers (in-sample, optimistic), all seats | 681 | 0.2827 | 0.2821 | -0.0007 | 0.0015 |
| full-sample multipliers, affected seats only | 53 | 0.4915 | 0.4831 | -0.0084 | 0.0190 |

By pair (time-forward, mean change over all seats in the pair): fed2022 +0.0029, fed2025 -0.0005, qld2024 -0.0065, nsw2023 +0.0057, vic2022 -0.0040, wa2025 0.0000, sa2026 -0.0032.

Seats that move most (time-forward; win probability of the actual winner, before to after):

| Seat | Personal-vote class | Actual winner | Before | After | Change in log loss |
|---|---|---|---|---|---|
| qld2024 South Brisbane | GRN | ALP | 0.040 | 0.082 | -0.72 |
| vic2022 Shepparton | IND | LNP | 0.134 | 0.199 | -0.40 |
| sa2026 MacKillop (McBride) | IND | ONP | 0.169 | 0.239 | -0.35 |
| fed2025 Griffith | GRN | ALP | 0.180 | 0.235 | -0.27 |
| fed2025 Goldstein | IND | LNP | 0.174 | 0.226 | -0.26 |
| nsw2023 Balmain | GRN | GRN | 0.789 | 0.675 | +0.16 |
| sa2026 Kavel | IND | IND | 0.936 | 0.847 | +0.10 |
| nsw2023 Kiama (Ward) | IND | IND | 0.785 | 0.712 | +0.10 |

Reading: the wide SD pays in the seats where the person collapsed and costs in the seats where the person held. A mean-neutral widening cannot do better than that on bimodal outcomes. The seat-level effect is a small net gain, well inside its own noise. By the metric-scoping rule in `CLAUDE.md`, this is a do-no-harm check, not a result: a fix touching 53 of 681 seats cannot move the pooled number enough to clear a pooled bar. The row-level score is the primary metric.

## 5. Recommendation

1. **Where it belongs: the simulation's per-cell SD (`sd_override`), not `base_pred` and not the xgb mean layer.** The problem is the spread of the outcome. The mean residuals of these types are small (-1.0 to +0.6, except the 15 successor rows at -4.0 and the 5 by-election rows at +7.1, both within one robust SD). Moving the mean would not help a bimodal outcome. This also avoids the `base_pred` trap in `CLAUDE.md`, since a primary-vote fix is not what this is.
2. **First option, nothing new to fit: switch the existing layer on for the published forecast.** `AUSPOL_XGB_PRIMARY_SD` is "0" in `published_flags.R:375` and has no live path (`xgb_primary_sd_override.R:34-37`, `fit_seats_full.R:1505` passes no `sd_override`). It already gives these rows 7.4 to 10.5 points, a +0.34 nat gain (SE 0.16) on the 111 rows, and it also widens first-time independents (RMS z 2.06). Its leave-one-pair-out file cannot serve a live election, which is the stated reason it is backtest-only; a live path needs an as-at fit.
3. **Second option, a small explicit multiplier:** add a personal-vote branch to `R/xgb_primary_sd_override.R` next to the `AUSPOL_SD_DEPARTED` block (`:93-124`), building `1.65 x level_sd(p)` for cells where the leader is a defector, a by-election winner, a returning non-major sitting member or a non-major successor. Take the four types as one group, not four, because three of them have fewer than 20 rows. The per-type values (1.41, 1.70, 1.79, 1.86) lie within each other's intervals. The typing already exists in `candidate_returns()` (`R/candidate_returns.R:44`, `same_mp`, `mp_departed`) and `personal_prior_vote()` (`:527`); the by-election and defector tests need `byelection_winner_rows()` (`R/byelection_prior.R:173`) and the prior-election `elected` flag. The live forecast would need the multiplier added at the `simulate_seat_contests()` call (`scripts/fit_seats_full.R:1505`) and the flag registered in `published_flags.R` in the same commit.
4. **Process:** pre-register the grid and the decision rule before running (`docs/PRE-REGISTRATION-RULES.md`). Apply it to all six harnesses and measure all of them (the harness-parity rule). Make row-level Gaussian log score on the 111 typed cells primary and seat log loss the do-no-harm guard. Include the retrospective typing fix for Broadfoot-type cases (a returning loser who was the class base).
5. **Does not help here:** a "more than 2 SE" bar on the seat log loss. At -0.0003 with SE 0.0016 the seat effect cannot clear any plausible bar, so a refusal on that metric would reflect the metric's power, not the idea.

## Unconfirmed or limited

- **Small cells:** 19 defectors, 15 successors, 5 by-election winners. The by-election multiplier (1.86) rests on 5 rows (Oakeshott, Sharkie, Phelps, Donato, McGirr). Only the pooled group (n = 111) carries weight.
- **Typing is by name:** region-wide surname plus first initial against the previous election's corpus (`match_key(..., "person")`); WA publishes bare surnames, so a shared surname reads as persistence. "Defector" means elected under ALP or LNP at the previous election. By-election winners come from `byelection_winner_rows()`, which skipped 10 winners it could not match to a results row (Manly and North Shore 2017, Cheltenham and Enfield 2019, Northcote 2017, Armadale, Willagee and Fremantle, Lyndhurst, Melbourne, Niddrie, Gippsland South) and so are untagged. I did not audit the 4,999 "first-time non-major" rows for missed personal-vote candidates.
- **Model SD is reconstructed** from the default `level_sd` formula at `xgb_pred` and not read from a run. The simulation computes it from its own share matrix, which may differ slightly from `xgb_pred`. The `AUSPOL_LEVEL_SD` env var was not confirmed unset in any given run.
- **`forecasts.csv` holds one leading candidate per class,** so a second teal or a second defector in a class is invisible.
- **`output/xgb-primary-sd-oof.csv` is leave-one-pair-out, not time-forward:** its sd_hat gain over level_sd (+0.34) is therefore a little optimistic, unlike the time-forward multiplier gain (+0.19).
- **The seat recompute is a normal approximation** (section 4) and does not use the simulator's preferences, floor or shared shift. Low-probability winners (below 0.001) are the least reliable.
- **Dates of artifacts were not checked** against `output/forecasts.csv` build time beyond the `built_at` stamp (2026-10-05T21:29Z), which is today.
