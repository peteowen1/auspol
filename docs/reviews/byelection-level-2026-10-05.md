# By-election winners: what level should a non-major winner be credited with? (2026-10-05)

Measurement only. Nothing in `R/`, `scripts/` or `output/` was edited and no harness, rebuild or fit was run.
Scripts and raw printouts are in the session scratchpad `...\scratchpad\byelec-level\` (`pop.R`, `score.R`,
`dep.R`, `extra.R`, `tab.R`; results in `results.rds`, `dep.rds`). Companion to
`docs/reviews/byelection-incumbents-2026-10-05.md` (defect 1, "level missing") and
`docs/reviews/defector-carry-2026-10-05.md` (layout template).

Pete's decision (2026-10-05): a non-major by-election winner (Oakeshott, Donato, McGirr, Phelps, Sharkie)
should be credited with the level a sitting non-major member typically holds at the next election, fitted
time-forward on every sitting non-major member and shrunk, instead of nothing (`own_prev_pcv` NA) or the
distorted by-election share.

## Answer first

- **Population: 80 members, 59 non-major plus 21 Greens.** A member elected at a general election in a
  non-major class who stood again in the same seat at the region's next election (all six regions, 2001 to
  2026). Next-election own share: **median 41.1, mean 40.8, SD 10.6, IQR 33.9 to 46.1 (n = 59, Greens
  excluded).**
- **A flat level, L1, beats today's model on the five by-election winners by a wide margin.** RMSE of the
  winner's own first-preference share: **today (L0) 24.1 (bootstrap SE 5.6); L1 median 6.9 (SE 0.8); L1 mean
  6.9 (SE 0.8).** Time-forward levels used were 39.5 to 41.6. n = 5, so this shows L0 is badly wrong, not
  that L1 is the best level.
- **Federal vs state does not separate (L2).** Fed mean 40.4, state 41.2, Welch p = 0.79, Wilcoxon p = 0.34.
  The shrinkage weight on the split was 0 in 44 of 55 time-forward fits and never above 0.57. L2 is no better
  than L1 on either test.
- **The by-election share carries no usable information about the next share.** Across the five winners,
  correlation 0.06, slope 0.03. Using it as the "prior" (L3) scores RMSE 16.5 (SE 2.6) on the five, against
  6.9 for the flat level. Lyne (63.8 to 47.2) and Orange (23.8 to 49.2) go in opposite directions.
- **Where a member DOES have a general-election share, use it, not L1.** On the 55 time-forward population
  cases, persistence or the ratio rule score RMSE 8.2 to 8.6 against L1's 11.1 to 11.3 (paired gap about 2
  SEs). The model already has `own_prev_pcv` for those. L1 is for the members who lack one.
- **The departed-penalty item is small and not separable.** 11 seats where a major lost at a by-election: the
  old major's class row at the next general election was over-called by a mean 2.2 points (SE 2.7), against
  0.5 (SE 0.8) for 47 retained seats; difference -1.7 (SE 2.9). The big misses (Lyne -15.6, Orange -18.3,
  Wagga -10.2) are the winner's surge taking the old major's vote. The documented departed tier (-2.8 points
  on the base) could explain at most a fifth of them.

**Recommendation: build L1, fitted time-forward as a shrunk pooled mean (about 41), no federal/state split,
and keep it independent of the by-election share.** Details and limits in section 6.

## 1. Population (n = 80)

Rule: person flagged `elected` at the region's previous general election with party class IND, OTH,
OTH_RIGHT, ONP or GRN (`output/candidacies.csv`), found again in the same seat at the next general election,
matched by `match_key(surname_of(), given_of(), "initial")`. The seat was matched under BOTH the old and new
spelling of any `seat_rename_map()` entry (Denison to Clark; with only the new spelling Wilkie's fed2013 and
fed2016 rows were lost). Rows where the first two letters of the first names differ were to be dropped: **0
rows hit that rule**. Where the corpus gives no first name (older WA rows: CONSTABLE, PENDAL, WOOLLARD) the
match is surname and seat only. Class is the member's class AT the prior election; a changed class at the
next election shows in the "Next class" column (Butler, Dalton, Donato, Katter, Andrew).

Table: one row per member-election pair. "Prior" is the member's own first-preference % at the election they
won; "Next" is their own % at the following election. Points of first-preference vote. "Won again" is the
`elected` flag. Rows are not independent (Katter 5 rows, Wilkie 5, Bandt 4, Greenwich, Piper and Sharkie 3
each). The fed2019 Mayo row (Sharkie) is also a by-election winner (2018).

| Election | Seat | Member | Prior class | Prior % | Next class | Next % | Won again |
|---|---|---|---|--:|---|--:|---|
| fed2013 | Melbourne | Adam BANDT | GRN | 36.2 | GRN | 43.2 | yes |
| fed2016 | Melbourne | Adam BANDT | GRN | 43.2 | GRN | 43.7 | yes |
| vic2018 | Melbourne | SANDELL, Ellen | GRN | 41.4 | GRN | 38.8 | yes |
| vic2018 | Prahran | HIBBINS, Sam | GRN | 24.8 | GRN | 28.1 | yes |
| nsw2019 | Ballina | SMITH Tamara | GRN | 27.0 | GRN | 31.7 | yes |
| nsw2019 | Balmain | PARKER Jamie | GRN | 37.4 | GRN | 42.7 | yes |
| nsw2019 | Newtown | LEONG Jenny | GRN | 45.6 | GRN | 46.0 | yes |
| fed2019 | Melbourne | Adam BANDT | GRN | 43.7 | GRN | 49.3 | yes |
| qld2020 | Maiwar | BERKMAN, Michael | GRN | 27.8 | GRN | 41.3 | yes |
| fed2022 | Melbourne | Adam BANDT | GRN | 49.3 | GRN | 49.6 | yes |
| vic2022 | Brunswick | READ, Tim | GRN | 40.1 | GRN | 43.6 | yes |
| vic2022 | Melbourne | SANDELL, Ellen | GRN | 38.8 | GRN | 37.3 | yes |
| vic2022 | Prahran | HIBBINS, Sam | GRN | 28.1 | GRN | 36.4 | yes |
| nsw2023 | Ballina | SMITH Tamara | GRN | 31.7 | GRN | 35.2 | yes |
| nsw2023 | Newtown | LEONG Jenny | GRN | 46.0 | GRN | 54.1 | yes |
| qld2024 | Maiwar | BERKMAN, Michael | GRN | 41.3 | GRN | 34.0 | yes |
| qld2024 | South Brisbane | MACMAHON, Amy | GRN | 37.9 | GRN | 34.7 | no |
| fed2025 | Brisbane | Stephen BATES | GRN | 27.2 | GRN | 25.9 | no |
| fed2025 | Griffith | Max CHANDLER-MATHER | GRN | 34.6 | GRN | 31.7 | no |
| fed2025 | Melbourne | Adam BANDT | GRN | 49.6 | GRN | 39.5 | no |
| fed2025 | Ryan | Elizabeth WATSON-BROWN | GRN | 30.2 | GRN | 29.0 | yes |
| wa2001 | Churchlands | CONSTABLE | IND | 83.2 | IND | 46.6 | yes |
| wa2001 | South Perth | PENDAL | IND | 39.6 | IND | 30.8 | yes |
| wa2005 | Alfred Cove | WOOLLARD | IND | 20.3 | IND | 24.0 | yes |
| wa2005 | Churchlands | CONSTABLE | IND | 46.6 | IND | 43.7 | yes |
| fed2007 | Kennedy | Bob KATTER | IND | 40.1 | IND | 39.5 | yes |
| fed2007 | New England | Tony WINDSOR | IND | 57.3 | IND | 61.9 | yes |
| wa2008 | Alfred Cove | WOOLLARD | IND | 24.0 | IND | 25.5 | yes |
| wa2008 | Churchlands | CONSTABLE | IND | 43.7 | IND | 67.3 | yes |
| fed2010 | Kennedy | Bob KATTER | IND | 39.5 | IND | 46.7 | yes |
| fed2010 | New England | Tony WINDSOR | IND | 61.9 | IND | 61.9 | yes |
| wa2013 | Alfred Cove | WOOLLARD | IND | 25.5 | IND | 10.1 | no |
| fed2013 | Denison | Andrew WILKIE | IND | 21.3 | IND | 38.1 | yes |
| fed2013 | Kennedy | Bob KATTER | IND | 46.7 | OTH_RIGHT | 29.4 | yes |
| fed2016 | Denison | Andrew WILKIE | IND | 38.1 | IND | 44.1 | yes |
| fed2016 | Indi | Cathy McGOWAN | IND | 31.2 | IND | 34.8 | yes |
| fed2016 | Kennedy | Bob KATTER | OTH_RIGHT | 29.4 | OTH_RIGHT | 39.9 | yes |
| vic2018 | Shepparton | SHEED, Suzanna | IND | 32.7 | IND | 38.4 | yes |
| nsw2019 | Lake Macquarie | PIPER Greg | IND | 42.5 | IND | 53.5 | yes |
| nsw2019 | Sydney | GREENWICH Alex | IND | 39.6 | IND | 41.4 | yes |
| fed2019 | Clark | Andrew WILKIE | IND | 44.1 | IND | 50.0 | yes |
| fed2019 | Kennedy | Bob KATTER | OTH_RIGHT | 39.9 | OTH_RIGHT | 41.0 | yes |
| fed2019 | Mayo | Rebekha SHARKIE | IND | 34.9 | IND | 34.2 | yes |
| qld2020 | Hill | KNUTH, Shane | OTH_RIGHT | 48.2 | OTH_RIGHT | 52.6 | yes |
| qld2020 | Hinchinbrook | DAMETTO, Nick | OTH_RIGHT | 20.9 | OTH_RIGHT | 42.5 | yes |
| qld2020 | Mirani | ANDREW, Stephen | ONP | 32.0 | ONP | 31.7 | yes |
| qld2020 | Noosa | BOLTON, Sandy | IND | 31.4 | IND | 43.9 | yes |
| qld2020 | Traeger | KATTER, Robbie | OTH_RIGHT | 66.2 | OTH_RIGHT | 58.9 | yes |
| sa2022 | Mount Gambier | Troy Bell | IND | 38.7 | IND | 45.7 | yes |
| fed2022 | Clark | Andrew WILKIE | IND | 50.0 | IND | 45.5 | yes |
| fed2022 | Indi | Helen HAINES | IND | 32.4 | IND | 40.7 | yes |
| fed2022 | Kennedy | Bob KATTER | OTH_RIGHT | 41.0 | OTH_RIGHT | 41.7 | yes |
| fed2022 | Mayo | Rebekha SHARKIE | IND | 34.2 | IND | 31.4 | yes |
| fed2022 | Warringah | Zali STEGGALL | IND | 43.5 | IND | 44.8 | yes |
| vic2022 | Mildura | CUPPER, Ali | IND | 32.7 | IND | 33.9 | no |
| vic2022 | Shepparton | SHEED, Suzanna | IND | 38.4 | IND | 29.4 | no |
| nsw2023 | Barwon | BUTLER Roy | OTH_RIGHT | 33.0 | IND | 44.8 | yes |
| nsw2023 | Lake Macquarie | PIPER Greg | IND | 53.5 | IND | 57.5 | yes |
| nsw2023 | Murray | DALTON Helen | OTH_RIGHT | 38.8 | IND | 50.2 | yes |
| nsw2023 | Orange | DONATO Philip | OTH_RIGHT | 49.1 | IND | 53.1 | yes |
| nsw2023 | Sydney | GREENWICH Alex | IND | 41.4 | IND | 41.1 | yes |
| nsw2023 | Wagga Wagga | McGIRR Joe | IND | 44.6 | IND | 44.2 | yes |
| qld2024 | Hill | KNUTH, Shane | OTH_RIGHT | 52.6 | OTH_RIGHT | 43.6 | yes |
| qld2024 | Hinchinbrook | DAMETTO, Nick | OTH_RIGHT | 42.5 | OTH_RIGHT | 46.4 | yes |
| qld2024 | Mirani | ANDREW, Stephen | ONP | 31.7 | OTH_RIGHT | 25.0 | no |
| qld2024 | Noosa | BOLTON, Sandy | IND | 43.9 | IND | 43.2 | yes |
| qld2024 | Traeger | KATTER, Robbie | OTH_RIGHT | 58.9 | OTH_RIGHT | 49.3 | yes |
| fed2025 | Clark | Andrew WILKIE | IND | 45.5 | IND | 48.9 | yes |
| fed2025 | Curtin | Kate CHANEY | IND | 29.5 | IND | 32.2 | yes |
| fed2025 | Fowler | Dai LE | IND | 29.5 | IND | 33.5 | yes |
| fed2025 | Goldstein | Zoe DANIEL | IND | 34.5 | IND | 30.7 | no |
| fed2025 | Indi | Helen HAINES | IND | 40.7 | IND | 42.3 | yes |
| fed2025 | Kennedy | Bob KATTER | OTH_RIGHT | 41.7 | OTH_RIGHT | 40.4 | yes |
| fed2025 | Kooyong | Monique RYAN | IND | 40.3 | IND | 33.9 | yes |
| fed2025 | Mackellar | Sophie SCAMPS | IND | 38.1 | IND | 38.0 | yes |
| fed2025 | Mayo | Rebekha SHARKIE | IND | 31.4 | IND | 29.9 | yes |
| fed2025 | Warringah | Zali STEGGALL | IND | 44.8 | IND | 39.7 | yes |
| fed2025 | Wentworth | Allegra SPENDER | IND | 35.8 | IND | 36.5 | yes |
| sa2026 | Narungga | ELLIS, Fraser | IND | 32.5 | IND | 17.4 | no |
| sa2026 | Stuart | BROCK, Geoff | IND | 48.5 | IND | 40.3 | yes |

Counts: non-major 59 (federal 28, state 31); Greens 21 (federal 8, state 13). Hand-check: no false matches
found among the 80 by reading names (same given name and surname throughout where a given name exists).
Cross-seat movers are excluded by definition (for example Brock, Frome to Stuart, is absent for sa2022
because Frome is only mapped to Ngadjuri).

Table: summary of next-election own share by group. Points of first-preference vote; "ratio" is next divided
by prior.

| Group | n | Median next | Mean next | SD | Median ratio |
|---|--:|--:|--:|--:|--:|
| Non-major, federal | 28 | 39.8 | 40.4 | 8.3 | 1.02 |
| Non-major, state | 31 | 43.6 | 41.2 | 12.5 | 1.03 |
| Greens, federal | 8 | 41.3 | 39.0 | 9.1 | 0.98 |
| Greens, state | 13 | 37.3 | 38.8 | 6.8 | 1.11 |
| Non-Green, first win at the member's first general election | 18 | 37.2 | 38.1 | 7.2 | 1.09 |
| Non-Green, longer-serving | 29 | 41.7 | 40.4 | 12.3 | 0.98 |

First-term vs longer-serving: Welch p = 0.42, not separable. 12 cases had no earlier election to classify and
are in neither of those two rows.

## 2. Level definitions and method

All fitted TIME-FORWARD: for the case whose next election is on date D, the training set is every case whose
next election is strictly before D (same-day elections do not train each other). At least 3 training cases
are required; 4 of the 59 non-major cases fall in that burn-in, leaving 55 scored.

- **L0 today:** the model's actual `xgb_pred` for the winner's class row (`output/forecasts.csv`, built
  2026-10-05 18:25). Used only on by-election winners; for general-election members the model already has
  `own_prev_pcv`, so it is not comparable there.
- **L1:** median of training members' next-election share (also shown as the mean, `L1_mean`).
- **L2:** training-set group means for federal and state, each shrunk toward the pooled mean with
  w = tau^2/(tau^2 + s^2/n_g); tau^2 is the variance of the two group means minus their mean sampling variance
  (floored at 0), s^2 the pooled within-group variance. With two groups tau^2 is weakly estimated; that is
  itself the finding.
- **L3:** median training ratio (next/prior) times the member's own prior share. For by-election winners the
  prior is the by-election share, per the brief.
- **L4 (extra, reference):** linear on the prior, slope shrunk toward 0 by ridge worth four observations.
- **Lp:** persistence, next = prior (reference). For by-election winners that is the by-election share.

RMSE SE is the bootstrap SE over cases (5,000 resamples, case-level, not clustered on member). "dMSE" is the
paired mean difference in squared error against the named base, with its SE; negative means better than the
base. z = dMSE / SE.

## 3. Scoring A: all sitting non-major members, time-forward (n = 55)

Table: error of each rule's prediction of the member's next-election own share. RMSE and MAE in points of
first-preference vote; lower is better. "Mean (actual - pred)" is the bias; positive means under-called.
dMSE is against L1 median; negative is better.

| Rule | RMSE | RMSE SE | MAE | Mean (actual - pred) | dMSE vs L1 | dMSE SE | z |
|---|--:|--:|--:|--:|--:|--:|--:|
| L1 median | 11.28 | 1.28 | 8.39 | -0.48 | 0 | | |
| L1 mean | 11.05 | 1.30 | 8.08 | -0.32 | -5.0 | 2.1 | -2.4 |
| L2 fed/state split | 11.23 | 1.25 | 8.31 | -0.42 | -1.0 | 6.2 | -0.2 |
| L3 median ratio x prior | 8.63 | 0.93 | 6.52 | -0.22 | -52.6 | 25.6 | -2.1 |
| L4 shrunk slope on prior | 9.21 | 1.18 | 6.81 | 0.29 | -42.4 | 12.6 | -3.4 |
| Lp persistence | 8.19 | 0.93 | 6.01 | 1.41 | -60.1 | 27.3 | -2.2 |

Table: the same by jurisdiction (federal n = 28, state n = 27). RMSE in points, lower is better.

| Rule | Federal RMSE | SE | State RMSE | SE |
|---|--:|--:|--:|--:|
| L1 median | 9.25 | 1.40 | 13.05 | 2.03 |
| L1 mean | 8.82 | 1.48 | 12.97 | 2.02 |
| L2 | 9.39 | 1.47 | 12.87 | 1.96 |
| L3 | 6.88 | 1.08 | 10.14 | 1.39 |
| L4 | 7.44 | 1.44 | 10.74 | 1.78 |
| Lp | 6.20 | 1.16 | 9.84 | 1.34 |

Reading it. (a) Among flat levels the mean (11.05) is a hair better than the median (11.28), 2.4 SEs on the
paired squared-error difference, driven by a few outliers (Constable at 83% as a prior, Wilkie). (b) L2 does
not separate: the split is worth 0.05 points of RMSE overall and its weight is 0 in 44 of 55 fits (11 early
fits had 0.22 to 0.57). (c) Anything that uses the member's own prior beats a flat level by about 2.5 to 3
points of RMSE, so a flat level is right only where the prior is unknown or not comparable, which is the
by-election winner. State members are noisier (SD 12.5 vs 8.3). (d) SEs are not clustered on member, so the
true uncertainty is wider.

Table: Greens, time-forward (n = 17). RMSE in points, lower is better; dMSE against L1 median.

| Rule | RMSE | RMSE SE | dMSE vs L1 | dMSE SE |
|---|--:|--:|--:|--:|
| L1 median | 8.04 | 0.90 | 0 | |
| L1 mean | 8.01 | 0.89 | -0.4 | 6.8 |
| L2 | 9.33 | 1.31 | 22.4 | 15.1 |
| L3 | 6.79 | 1.15 | -18.5 | 24.5 |
| L4 | 6.13 | 0.55 | -27.0 | 12.7 |
| Lp | 5.97 | 0.96 | -29.0 | 22.2 |

Greens full-sample level: median and mean 38.9, n = 21. L2 is again worse than L1 (the split costs 1.3 points
of RMSE). Same ordering as the non-major group.

## 4. Scoring B: the five non-major by-election winners (time-forward)

Table: one row per winner. "By-elec %" is the winner's by-election first-preference share (the L3 prior);
"Next %" is their own share at the next general election; the right-hand columns are each rule's prediction of
that own share, in points, closer to "Next %" is better. L0 is the class row's `xgb_pred`, and the class row
also contains the other candidates of that class, so it is not a pure own-share forecast (section 7).
"n train" is the number of earlier members behind the L1 level.

| Election | Seat | Winner | By-elec % | Next % | n train | L0 today | L1 median | L1 mean | L2 | L3 ratio | L4 |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| fed2010 | Lyne | Rob Oakeshott | 63.8 | 47.1 | 8 | 9.0 | 41.6 | 42.4 | 42.4 | 65.3 | 48.1 |
| nsw2019 | Orange | Philip Donato | 23.8 | 49.1 | 17 | 17.5 | 39.5 | 40.1 | 39.0 | 25.7 | 33.1 |
| nsw2019 | Wagga Wagga | Joe McGirr | 25.4 | 44.6 | 17 | 26.5 | 39.5 | 40.1 | 39.0 | 27.5 | 33.8 |
| fed2019 | Wentworth | Kerryn Phelps | 29.2 | 32.4 | 19 | 23.9 | 39.9 | 40.9 | 40.9 | 31.6 | 36.0 |
| fed2019 | Mayo | Rebekha Sharkie | 44.4 | 34.2 | 19 | 40.6 | 39.9 | 40.9 | 40.9 | 48.0 | 42.8 |

Table: RMSE over the five winners' own share (points; lower is better), bootstrap SE, and the paired
squared-error difference against L0 today (negative is better than today).

| Rule | n | RMSE | SE | MAE | Mean (actual - pred) | dMSE vs L0 | dMSE SE | z |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| L0 today | 5 | 24.09 | 5.62 | 20.56 | +18.0 | 0 | | |
| L1 median | 5 | 6.88 | 0.79 | 6.67 | +1.4 | -533 | 277 | -1.9 |
| L1 mean | 5 | 6.94 | 0.80 | 6.69 | +0.6 | -532 | 282 | -1.9 |
| L2 fed/state | 5 | 7.41 | 0.88 | 7.15 | +1.1 | -525 | 281 | -1.9 |
| L3 median ratio x by-elec % | 5 | 16.53 | 2.60 | 14.69 | +1.9 | -307 | 227 | -1.4 |
| L4 shrunk slope on by-elec % | 5 | 9.61 | 2.29 | 8.00 | +2.7 | -488 | 277 | -1.8 |
| By-election share unchanged | 5 | 16.77 | 3.12 | 14.94 | +4.2 | -299 | 233 | -1.3 |

Without Sharkie (she has a 2016 general-election share, 34.86, so the "no prior" premise does not hold for
her; n = 4): L0 26.74 (SE 5.50), L1 median 7.15 (0.91), L1 mean 7.00 (1.03), L2 7.57 (1.09), L3 17.15 (3.13).
Conclusions unchanged.

Rough hand check against the CLASS actual instead of the own share (Lyne 47.8, Orange 56.2, Wagga 46.1,
Wentworth 33.0, Mayo 34.2): L0's RMSE is about 26.5. The class row exceeds the winner's own share by 0.7,
7.0, 1.4, 0.6 and 0.0 points, so a built L1 must add the class-mates (Orange's three minor right-wing
candidates, Wagga's second independent) or it will under-call the class row.

How the by-election share relates to the next share (n = 5): correlation 0.06, slope 0.03, next-share mean
41.5, SD 7.7. Five points are not a usable regression sample, but nothing suggests the by-election share
helps.

## 5. Sizing the "member departed" penalty

Question: where a major lost the seat at a by-election, how wrong is the model about the OLD major's class
share at the next general election, given that the by-election override clears its `mp_departed` flag
(defect 3 of the incumbents review)? Population: for each of the 18 forecast elections, the last by-election
in each seat in the window; old class = the by-election's `prev_party_raw` class; row = that class's row in
`output/forecasts.csv`. No seat had two by-elections in one window. 62 by-elections fall in forecast windows;
61 were held by a major, 58 of those have a forecast row for the old class (3 not matched; seat renamed or
the class did not stand).

Table: the old major's class share at the next general election vs the model, for the 11 seats a major
lost. Base and xgb are the model's predictions; signed error = actual minus xgb, in points; negative means
the model over-called the old major; closer to zero is better. Every row has one candidate in the class.

| Election | Seat | Old major | By-election winner class | Base | xgb | Actual | Signed error |
|---|---|---|---|--:|--:|--:|--:|
| fed2010 | Lyne | LNP | IND | 52.8 | 50.0 | 34.4 | -15.6 |
| fed2019 | Wentworth | LNP | IND | 53.3 | 50.2 | 47.4 | -2.8 |
| fed2025 | Aston | LNP | ALP | 37.3 | 38.0 | 37.7 | -0.3 |
| nsw2019 | Orange | LNP | OTH_RIGHT | 45.0 | 44.1 | 25.8 | -18.3 |
| nsw2019 | Wagga Wagga | LNP | IND | 37.0 | 36.2 | 26.0 | -10.2 |
| nsw2023 | Bega | LNP | ALP | 36.4 | 35.7 | 31.5 | -4.3 |
| qld2024 | Ipswich West | ALP | LNP | 32.0 | 31.1 | 38.6 | +7.5 |
| sa2026 | Black | LNP | ALP | 6.1 | 5.0 | 10.3 | +5.4 |
| sa2026 | Dunstan | LNP | ALP | 26.6 | 25.4 | 28.3 | +2.9 |
| vic2018 | Northcote | ALP | GRN | 39.4 | 37.6 | 41.7 | +4.1 |
| wa2013 | Fremantle | ALP | GRN | 33.8 | 30.7 | 38.2 | +7.5 |

Table: summary of the signed error. n = number of seats; SE of the mean; RMSE in points; closer to zero is
better.

| Group | n | Mean error | SE | Median | RMSE | Over-called | Under-called |
|---|--:|--:|--:|--:|--:|--:|--:|
| Major lost the seat | 11 | -2.19 | 2.74 | -0.28 | 8.94 | 6 | 5 |
| ... lost to a non-major | 6 | -5.90 | 4.31 | -6.49 | 11.29 | 4 | 2 |
| ... lost to the other major | 5 | +2.26 | 2.09 | +2.94 | 4.75 | 2 | 3 |
| Major kept the seat (control) | 47 | -0.53 | 0.82 | -1.17 | 5.57 | 27 | 20 |

Difference lost minus kept in mean error: -1.66 (SE 2.86), not separable. The model's base over-calls by a
mean 3.6 points on the lost group (1.6 on kept).

How the model's departed tier would apply if the flag were kept. `R/candidate_returns.R:197-200` sets
`mp_departed = had_mp & !same_mp`, where `had_mp` comes from the previous election's `elected` flags; the
by-election override rewrites those flags (`R/candidate_returns.R:79`), so the losing major has no member
(`had_mp` FALSE, `mp_departed` FALSE). `R/dev_slope.R:162-170` applies the fitted `major_departed` slope to
ALP/LNP cells where `mp_departed` is TRUE; its documented size is -2.8 points on 361 cells
(`R/dev_slope.R:151-157`). Rough arithmetic only (a flat -2.8 on xgb, not a model run; the real tier scales
with the vote): the 11 errors would shift by +2.8, RMSE 8.94 to about 8.7, helping the six over-called seats
and hurting the five under-called ones. **It is a 0.3-point RMSE item, far below the level fix, and a flat
2.8 cannot reach a 15-point miss.** The 15 to 18 point misses are where the winner took the old major's
votes; a correct level for the winner (section 4) is the lever there, and the old major's row should be
re-measured after that rather than given its own penalty first.

## 6. Recommendation

1. **Build L1: one pooled level for non-major by-election winners, about 41 (mean 40.8, median 41.1, n = 59
   on all data), refitted time-forward as a shrunk pooled mean** (partial pooling toward the grand mean of
   all sitting non-major members). Evidence: five-case RMSE 6.9 (SE 0.8) vs 24.1 (SE 5.6) for today; also
   the best flat level on the 55-case population (11.1, SE 1.3).
2. **Do not split by federal/state (L2).** Not separable (p 0.79 / 0.34; weight 0 in 44 of 55 fits; worse
   on Greens by 1.3 points RMSE). Shrinkage already collapses it, so it costs nothing, but there is no
   evidence for it.
3. **Do not feed the by-election share through (L3/L4).** On five cases the correlation is 0.06 and the ratio
   rule scores 16.5. Keep the by-election share for what it does now (class baseline via
   `AUSPOL_BYELECTION_PRIOR`), not for the winner's personal level.
4. **For any non-major member who has a general-election prior, keep using it** (Lp/L3/L4 8.2 to 9.2 vs L1
   11.1 on the 55 cases). L1 is the fallback for "no own prior", which covers four of the five winners.
5. **Treat the level as the OWN share and add the class-mates** so the class row does not under-call
   (Orange by about 7).
6. **Departed penalty: later, if at all.** n = 11, mean 2.2 (SE 2.7), not separable from the retained
   control. Fix the winner's level first, then re-measure the old major's row.
7. Per `CLAUDE.md`: test it in `base_pred` AND the xgb layer, on all six harnesses, check the five rows end
   to end, and pre-register the criterion on the named rows (primary) with the 43-row and election-wide
   do-no-harm guards.

**What n can and cannot separate.** n = 5 can show that L0 is wrong (a 17-point RMSE gap; 1.9 on the paired
squared error) and that the by-election share is no better than having no prior (RMSE 16.5 vs 6.9). It cannot
rank L1 median, L1 mean, L2 and L4 (within 3 points of RMSE, SEs 0.8 to 2.3), and it cannot say whether
first-term members sit lower than the pooled level (first-term median 37.2 vs 41.7, p 0.42). n = 55
separates "use your own prior" from "use a flat level" at about 2 SEs, and does not separate L1 from L2. The
right next step is an outcome check on the five rows once built, not a bigger significance test.

## 7. Not confirmed, and where I looked

- **Own share vs class row.** L0 is the class row's `xgb_pred`, scored against the member's own share
  (stated in section 4). Against the class share RMSE is about 26.5, by hand arithmetic on the table, not
  computed in code.
- **`forecasts.csv` vintage.** Built 2026-10-05 18:25. The incumbents review quoted a 2026-10-02 build (Lyne
  xgb 7.73, Orange 20.91); this build has Lyne 8.97, Orange 17.48. I did not check what changed. The state of
  the departed flag on this build is taken from that review and from reading `R/candidate_returns.R:79,
  197-200`; I did not re-verify it.
- **By-election winners without candidate-level results (38 of 92) cannot be scored.** Non-major winners in
  `byelection-winners.csv` (10 of 92): Lyne, Orange, Wagga, Wentworth and Mayo are scored; Pittwater 2024,
  Farrer 2026 and Secret Harbour 2026 fall after the last scorable election; Northcote 2017 (Thorpe, Greens)
  and Fremantle 2009 (Carles, Greens, then IND at 7.7% in wa2013) have no result rows, so no by-election
  share. Greens by-election winners were not scored.
- **Member-repeat clustering.** Several members appear 3 to 5 times; SEs treat rows as independent and are
  understated. Not quantified.
- **Sharkie** is in both populations: a general-election member (2016 win) for fed2019 and a by-election
  winner. Her own row is excluded from the fed2019 training set (same-day cases do not train each other).
- **First-term flag** (section 1) is derived from the earlier election in the same region; Donato and McGirr
  count as first-term at nsw2023 because their first general-election win was nsw2019, which differs from
  their time as sitting members (since 2016 and 2018).
- **Not matched by design:** cross-seat movers; Brock (Frome to Stuart) in sa2022 because Frome is mapped
  only to Ngadjuri in `seat_rename_map()`; vic2010 has no `elected` flags, so the vic2010 to vic2014 pair is
  absent; any member whose seat was renamed and is not in the map.
- **L2 construction.** With two groups tau^2 is poorly estimated, so a weight of 0 mostly says the data
  cannot support a split, not that fed and state are identical. Mean difference 0.8 points, SDs 8 to 12.
- **False-match check** was a read of the names (the rule dropped 0 rows), not a lookup of each person. WA
  rows with no given name match on surname and seat only.
