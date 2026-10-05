# Breakout risk: using salience, seat polls and the other signals (2026-10-05)

Measure-and-design only. Nothing in `R/`, `scripts/` or `output/` was edited and no harness or rebuild was run.
Scratch scripts (`b1`..`b6`, `b3d.R` is the classifier) are in the session scratchpad `breakout/`.
Pete's ask: "salience and seat polls help here, lets use them". This note says what each signal does today,
how well a breakout classifier built from every signal on disk can do, and which way of feeding it into the
forecast works.

## 1. What each signal does TODAY for the named misses

Method: loaded each as-at xgb model (`output/xgb-primary-asat/<election>.ubj`), fed it the row from
`output/xgb-primary-v6-features.csv`, took SHAP contributions (`predcontrib`) and re-predicted with each signal
switched off. Points are primary vote %. A single model file reproduces the `forecasts.csv` `xgb_pred` to within
about 0.6 points (the CSV looks like the average of the `-m2/-m3` ensemble files; not confirmed), so SHAP is for
size, not exact accounting.

How to read the table: "Salience shap" is the points the salience features (`jump`, `governed`, `permit`, `surge_h`,
`is_recipient`) add to this row; "Off" columns are how many points the prediction falls if that signal is removed.
Higher is more influence. Endorsement and council SHAP are small everywhere.

| Row | actual | xgb_pred | Salience shap | Endorse shap | Council shap | Seat poll (applied AFTER xgb, not in xgb_pred) |
|---|---|---|---|---|---|---|
| fed2019 Warringah STEGGALL | 44.7 | 11.8 | +2.7 (jump 0.77) | 0.0 (c200=1, no endorsed training row) | -0.05 | ReachTEL 98 days out, outside 90-day window, fed2019 weight 0 |
| fed2016 Mayo SHARKIE | 34.9 | 2.4 | +0.9 | n/a | 0 | TCP only in our file, primary missing (web: 23.5, unconfirmed) |
| nsw2019 Barwon BUTLER | 36.4 | 4.6 | -0.05 (jump 0) | 0 | 0 | none |
| fed2022 Goldstein DANIEL | 34.5 | 4.6 | +1.2 | 0.0 (c200=1, voices=1) | -0.15 | uComms IND 33 to 35 |
| vic2014 Shepparton SHEED | 35.2 | 8.3 | +0.6 | 0 | 0 | none |
| fed2013 Indi McGOWAN | 32.1 | 5.8 | +0.04 | 0 | 0 | none |
| sa2022 Flinders HABERMANN | 27.2 | 1.1 | 0 (no salience row) | 0 | +0.48 (councillor) | none |
| fed2022 Mackellar SCAMPS | 38.1 | 12.0 | +2.8 | 0.0 | -0.14 | uComms 23.9 |
| fed2022 Kooyong RYAN | 40.5 | 15.2 | +5.0 (6.7 if jump removed) | 0.0 | -0.12 | uComms 31.8 |
| fed2022 Curtin CHANEY | 29.5 | 7.4 | +0.8 | 0.0 | -0.14 | 32 (May) |
| nsw2023 Wakehurst REGAN | 35.9 | 12.2 | +1.7 | not endorsed | +0.58 | TCP only, no primary |
| vic2018 Pascoe Vale YILDIZ | 32.9 | 10.7 | +0.2 | 0 | +0.39 | none |
| nsw2019 Dubbo DICKERSON | 28.4 | 6.0 | 0 | 0 | +0.31 | none |
| wa2025 Fremantle HULETT | 25.6 | 4.5 | +1.3 | not endorsed | -0.13 | none |
| nsw2019 Murray DALTON | 40.3 | 19.6 | +0.3 | 0 | -0.04 | none |

What this says, per signal:
- **Salience (Trends jump)**: IS a feature (`jump`, `governed`, `permit`, `surge_h`, `is_recipient`). It adds 0 to 5 points
  on these rows; the biggest is Kooyong. It is zero for Barwon, Flinders and Dubbo (no Trends row for the candidate).
  Only 5,755 of 12,023 rows have a salience row at all. 62% of those jumps are exactly zero (3,571 tied at zero,
  1,617 distinct values), so the percentile must be ranked among non-zero values only (rule in CLAUDE.md; done here).
- **Seat polls**: not in `xgb_pred`. They are blended afterwards with a weight fitted on earlier elections
  (0.45 at fed2022, 0 at fed2019). Where a primary exists they pull the teals up to 17 to 27 and the result is
  still 11 to 21 points low (from the earlier review, my arithmetic). Mayo 2016, Wakehurst and the 2019 Warringah poll
  have no usable primary in our file.
- **Endorsement (Climate 200 / Voices)**: a feature, but the models for the first wave had no endorsed training rows,
  so its SHAP is 0.00 on every row. It cannot help the first wave by construction.
- **Council**: a feature; adds 0.3 to 0.6 for ex-councillors (Flinders, Wakehurst, Pascoe Vale, Dubbo). The earlier review
  found `council_mayor` is TRUE for only 11 of 6,478 minor rows (three confirmed ex-mayors coded FALSE).
- **Not used at all**: a classifier-style "probability of a 20%+ result" (this note); state Trends series on disk
  (`external/reference/trends/v6_AU_NSW_*`, `_VIC_*`, `_SA_2021_*`) never built into the salience population.

## 2. The breakout classifier (time-forward)

Rows: every non-major class row (IND, OTH, OTH_RIGHT, ONP) that has a named candidate, from `output/forecasts.csv`
(the as-at, honest predictions), joined to `output/xgb-primary-v6-features.csv`. GRN excluded (different
phenomenon). Target: actual primary share >= 20 (also >= 25). Time-forward: for each scored election, train only on
elections with a strictly earlier election date; the first election with at least 5 earlier positives is
fed2013, so 16 elections are scored (fed2013 to sa2026). Row-alignment between saved predictions and the data was
asserted in code.

Features: 54 time-forward-safe features in 9 groups: model (own as-at `xgb_pred`, `base_pred`), salience (`jump`,
its percentile among non-zero jumps within the election, row-present flag, `governed`, `permit`), endorsement (2),
council (4), seat poll (poll primary, poll minus our prediction, days out, number of polls, polled flags), prior
vote (7), structure (margin, retirement, ballot position, candidate counts, level, top-major prediction, rank in
seat, etc.), demographics (7 census columns), context (class and region dummies). `surge_h` and `is_recipient`
were deliberately LEFT OUT: `fit_xgb_primary_v6.R` builds them with leave-one-election-out (`SURGE_CANON` minus the
target), which is not time-forward (CLAUDE.md names this exact trap). So the result is "AUC x using 54 of 54
time-forward-safe features available (56 on disk)".

Two bugs found and fixed on the way (first-pass numbers discarded):
(1) 2,485 of 6,596 non-major rows are PHANTOM classes (no candidate, predicted 0, actual 0); they inflated AUC
(all-feature ridge looked like 0.943) and gave junk rivals. Removed. (2) A data.table NSE slip (`p[nm]` inside
`Z[nm, ...]`) mislabelled the p column once; caught because printed p did not match the shift it caused.

AUC = chance a random 20%+ row ranks above a random other row (0.5 chance, 1 best). Brier = mean squared
probability error (lower better; the flat-rate figure is a constant base-rate guess). "Hard" = rows our model
predicted under 15, the ones that matter here. Top-20 per calendar year = flag the 20 highest-probability rows each year.

| Model (y20, 54 features unless stated) | AUC all (n=3,784, 175 positive) | AUC hard (n=3,581, 56 positive) | Brier (flat 0.0441) | Top-20/yr: hits of 240 flagged | Recall |
|---|---|---|---|---|---|
| Our own prediction alone (1 feature) | 0.903 | 0.741 | 0.0238 | 106 | 0.61 |
| Shrunk (ridge) logistic | 0.930 | 0.827 | 0.0281 | 114 | 0.65 |
| xgboost, `xgb.cv` + early stopping | **0.949** | **0.889** | 0.0251 | 111 | 0.63 |
| xgboost, scored from 2016 only (n=3,327) | 0.957 | 0.902 | 0.0251 | 107 of 200 | 0.66 |
| xgboost, target >= 25 (n=3,493, 126 positive) | 0.973 | 0.928 (29 positive) | 0.0190 | 89 of 220 | 0.71 |

Reading it:
- AUC 0.949 using 54 features, but most of that is the model's own prediction (0.903 alone). The real gain is on the
  HARD rows: 0.741 to 0.889. That is the surprise-detection value, from 56 positives, so treat the AUC as +/- 0.03
  (my rough estimate, not computed).
- At the top-20-per-year cut the precision barely moves (111 vs 106 hits) because the flagged rows are mostly
  candidates the model already expects to do well. The classifier is useful as a graded probability on low-predicted
  rows, not as a top-20 list.
- Calibration on the hard rows (time-forward p vs observed rate): p<0.01 -> 0.26% vs 0.33% (n=2,756, 9 hits);
  0.01-0.03 -> 1.6% vs 2.8%; 0.03-0.1 -> 5.3% vs 9.9%; 0.1-0.3 -> 17% vs 17%; above 0.3 -> 44% vs 24% (n=21).
  Close in the middle, under-confident in the low-middle, over-confident at the top.
- Dropping a group (xgb, hard-row AUC from 0.889): salience 0.833 (the biggest loss), demographics 0.859, structure 0.870,
  context 0.873, council 0.881, prior vote 0.883, endorsement 0.887, poll 0.892, model predictions 0.887. Only salience
  clearly matters; poll, endorsement and council are inside noise (poll covers few hard rows: only fed2019/2022/2025
  and nsw2023 have any seat polls on disk). Group-alone-plus-prediction: salience 0.797, council 0.756, endorsement
  0.742 (zero lift). So "salience helps" is supported; "seat polls help" cannot be measured with the polls we have.
- sa2026 is a party-wide One Nation wave (34 of 188 rows, 22% rate; mean p 0.076): a different mechanism, already
  handled by the party-surge machinery; the classifier under-calls it.
- The classifier does NOT find the headline cases. Time-forward p for the named rows: Warringah 2019 0.14, Mackellar 0.14,
  Wakehurst 0.44, Shepparton 2014 0.14, Hawkins 2018 0.22, Pascoe Vale 0.10, Goldstein 0.013, Chaney 0.024, Mayo 2016
  0.041, Dubbo 0.047, Barwon 0.003, Flinders 0.028, Hulett (wa2025) 0.002, Dalton 2019 (pred 19.6, outside the
  hard set). The AUC is real but the headline wins are rated 1-45%, not 90%.

## 3. Translating it into the forecast (proxy, time-forward)

Applied only to hard rows (model predicted under 15); rows already predicted 15+ get no insurance (applying it
to them pulled expected winners down toward 33, which is wrong: see the first, ungated run below).
Breakout size B = earlier hard-row breakouts' actual shares (mean about 31).

(a) today: our `xgb_pred` with empirical residuals (class x prediction band, earlier elections only).
(b) mean shift: `pred + p*(B_mean - pred)`, other classes rescaled. Same residual spread.
(c) mixture: each simulation draw, with probability p the row's share is drawn from the earlier-breakout shares,
the others rescaled; otherwise today's draw. Point forecast (the mean) is identical to (b); only the spread differs.
Win probability = share of 1,500 draws in which the class has the top primary; winner = `actual_winner` in
`forecasts-seats.csv`. Scored on 15 elections (fed2016 to sa2026), 1,449 seats, 73 of them non-major winners.

| Result (y20 xgb p, gated to pred<15) | today | (b) mean shift | (c) mixture |
|---|---|---|---|
| Row squared error, all non-major rows (lower better, n=3,493) | 17.90 | 17.98 (diff +0.085, SE 0.20) | same as (b) |
| Seat-winner log loss (lower better, 1,449 seats) | 0.4843 | 0.4837 (diff -0.0005, SE 0.0018) | 0.4541 (diff **-0.0302, SE 0.0124**) |
| Log loss on the 73 non-major winners | 2.314 | 2.274 | **1.643** |
| Log loss on 1,376 major/GRN winners | 0.3872 | 0.3888 | 0.3910 |
| Brier over seat x class | 0.04379 | 0.04375 | 0.04370 |

Robustness (same proxy): ridge p mixture -0.0361 (SE 0.0159); y25 xgb p mixture -0.0370 (SE 0.0141), mean shift
-0.0050 on log loss and -0.21 (SE 0.13) on row error; doubling p gives mixture -0.0392 but a mean shift that is
worse on row error (+1.27, SE 0.43). SEs are clustered by seat-election.

Named rows, winner probability today -> mixture (their p): Wakehurst REGAN 0.0053 -> 0.0333 (p 0.44), Warringah 2019
0.0007 -> 0.0033, Mackellar 0.0073 -> 0.0193, Hawkins 2018 0 -> 0.020, Pascoe Vale 0 -> 0.011, Shepparton 2014 0 -> 0.0013,
Goldstein 0.0000 -> 0.0027, Fremantle 2025 0.021 -> 0.112 (p 0.43). Barwon, Flinders, Dubbo, Mayo 2016, Murray stay under 1%.
The mixture helps in aggregate (73 winners, 2.31 -> 1.64 nats each) but the single named misses stay at 1-3%: the
classifier does not see them, it only stops giving them literally zero.

Anchor and limits (read before quoting): (i) my proxy "today" winner log loss is 0.475 against 0.271 for the real
simulator's `win_prob` on the same seats. The proxy ignores preferences (leader on primaries, not winner after
preferences), so the absolute numbers are NOT the published model's; only the within-proxy comparison is meaningful, and the
real simulator may already absorb part of the gain. (ii) the first, ungated run (mixture applied to every non-major row)
gave a similar log-loss gain (-0.038, SE 0.018) but a mean shift that cost 2.0 points^2 of row error (SE 0.44) because it pulled
expected winners down. (iii) the seat-poll blend (applied after `xgb_pred`) is not simulated here. (iv) breakout
draws are earlier winners' shares (fed2013 drops out of the gated run: fewer than 5 earlier hard breakouts).

### Why the upset floor was refused, and whether this avoids it
`docs/reviews/upset-signal-2026-10-02.md`: the floor gave eps of each seat's win probability to every minor contender
predicted 2%+, in proportion to predicted share (or to a propensity). Blanket and propensity-weighted versions
improved log loss only by taking probability from everyone (22-election log loss 0.3444 -> 0.3396) while every
version raised Brier (0.0894 -> 0.0903 or worse) and Victoria and the AEF-7 elections got worse. The propensity
model was AUC 0.837 but gave the real upsets (Barwon, Shepparton, Murray) only about 1% in absolute terms.
What this design changes: (1) it works on shares, not on a final win probability, so a breakout takes votes from the
other classes consistently; (2) it only touches rows the model predicted under 15, and p is a calibrated row probability
(reliability above) rather than a fitted eps; (3) Brier does not rise in the proxy (0.04379 -> 0.04370). What it does NOT
change: the same fundamental limit. The classifier does not isolate the headline upsets, so the gain comes from many small
rows, and the true test (Brier and log loss on the real simulator, per election, AEF-7 and Victoria) has not been run.

## 4. Recommendation for Pete

Use the **mixture**, not a mean shift. Concretely (a design, not built):
1. Time-forward xgboost breakout classifier (target actual >= 20, 54 features, `xgb.cv` early stopping, grouped by
   election; retrained per as-at cutoff exactly as the as-at primary models are).
2. In the simulator, for non-major rows predicted under 15: with probability p (capped at 0.5 pending recalibration) replace
   the row's drawn share with a draw from the earlier hard-breakout shares and rescale the other classes. Do not move the
   point forecast (the mean shift added nothing measurable: row error +0.085, SE 0.20).
3. Pre-register before any harness run (CLAUDE.md rule): primary = seat log loss on the non-major winners plus pooled
   all-winner log loss across the 22 pairs, guard = Brier and Victoria and AEF-7 do-no-harm, tolerance in SEs clustered on
   seat-election. Test in `base_pred`-independent form since it acts in the simulator, and in all six harnesses at once.
4. Re-estimate the p calibration on the real simulator: the top bin (p>0.3) is over-confident here (44% vs 24%).
Expected size, honestly: about 0.03 nats of proxy log loss (2.4 SE) and a drop from 2.3 to 1.6 on non-major winners; no
change to the named misses beyond a few percentage points. It is insurance with calibrated odds, not a fix for first-time breakouts.

Data that would raise the cap (none of it is in the model today):
- State Trends series on disk but never built (Regan 69-88% of his batch in the final 8 weeks per the earlier review).
  Salience is the strongest single group, so extending it to state elections (only 5,755 of 12,023 rows have a row now) is the
  most promising lift. Salience LEVEL and RISE are not in the feature file at all (only `jump`); rebuilding them from the weekly
  series is the second item.
- Seat-poll primaries missing: Mayo 2016, Warringah 2019 (outside window), Wakehurst 2023; state seat polls almost absent. The
  poll group cannot be evaluated until more exist (only fed2019/22/25 and nsw2023 have any).
- `council_mayor` miscoded (11 flags in 6,478 rows).
- No training examples before the first teal wave for endorsement; dated announcements (`announced_date`) almost empty.

## Unconfirmed items (and where I looked)

- AUC SE (+/- 0.03) is a rough estimate from 56 positives, not computed (no bootstrap run).
- Census vintage per election: `output/census-features.csv` has vintages 2016/2021/2022/2024/2025; for older elections
  a later census is mild look-ahead on slowly moving demographics. I did not check which rows. Dropping demographics
  costs 0.03 hard AUC, so a lookahead there could matter.
- `jump` is the only salience quantity on disk per row; whether the other salience files (`salience-v6.csv`) carry level/rise
  was not opened beyond the header.
- Whether `forecasts-seats.csv` `win_prob` includes the seat-poll blend: unresolved (same as the earlier review).
- The mixture rescaling of other classes, the cap of p at 0.95 inside the proxy, and the independence of residuals across
  classes are my choices; sensitivity to them was not tested.
- The ablation "preds + group" and ridge rows were still running when this was written; only the xgb drop-one rows and
  preds + salience/endorsement/council were read.
- Breakout cut-offs (20/25, hard < 15) are mine.
- Pascoe Vale primary (23.5 per a search summary vs 32.9 in our data) is still unreconciled (carried from the earlier review).
