# Greens "over-called in high-Greens seats by the trees": investigation, 2026-10-24

Verdict: **the claim is half right and the proposed fix does not pay.** The trees
do overshoot the Greens in the strongest seats (30%+ base), but on average only
by a couple of points on 34 rows from 15 elections, the published stage already
claws about 1.4 of it back, and a shrink of the tree correction toward base does
not lower share error time-forward. In-sample screen only; nothing here is a
held-out result except where labelled.

Scripts (scratch, not committed): `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\597d5a10-bcc6-422e-a23c-66b6c6fb51da\scratchpad\greens\{b,c,e}.R`.
Data: `output/forecasts.csv` (base_pred, xgb_pred, actual_share) joined on
election/seat/party to `output/published-predictions.csv` (`ours` = final,
`actual`). 17,010 rows, 30 elections, join clean (max actual difference 5e-5).
The forecasts file has no fed2007 / wa2001-2008 (first election of a state).
Only forecasts.csv rows exist for 30 elections; GRN rows = 2,620 over 31 labels.

## Which stage over-calls

Mean signed error in vote-share points, actual minus prediction, so **positive =
under-called, negative = over-called**. Lower absolute is better. `E_` = mean
signed error, `R_` = RMSE (points, lower is better). Bins are the GRN base_pred
(pre-tree) share. n = candidate rows (one GRN row per seat per election).

All 30 elections, GRN rows:

| base bin | n | mean base | mean actual | E_base | E_xgb | E_final | R_base | R_xgb | R_final |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| <10 | 1202 | 7.3 | 6.2 | -1.10 | -0.91 | -0.73 | 2.34 | 2.19 | 1.96 |
| 10-20 | 1285 | 13.2 | 11.6 | -1.58 | -1.42 | -1.48 | 3.25 | 3.17 | 3.15 |
| 20-30 | 99 | 23.6 | 23.0 | -0.59 | -1.23 | -0.90 | 5.54 | 5.52 | 4.95 |
| 30+ | 34 | 36.3 | 37.2 | +0.87 | -2.29 | -0.88 | 5.77 | 6.42 | 5.51 |

AEF-7 pairs only (fed2022, fed2025, nsw2023, qld2024, sa2026, vic2022, wa2025):

| base bin | n | mean base | mean actual | E_base | E_xgb | E_final | R_base | R_xgb | R_final |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| <10 | 275 | 8.0 | 7.0 | -1.01 | -0.73 | -0.57 | 2.09 | 1.88 | 1.64 |
| 10-20 | 355 | 13.2 | 12.1 | -1.04 | -0.89 | -0.72 | 2.82 | 2.62 | 2.38 |
| 20-30 | 35 | 23.7 | 23.1 | -0.55 | -1.06 | -0.41 | 5.47 | 5.57 | 4.29 |
| 30+ | 16 | 37.1 | 36.3 | -0.88 | -4.44 | -2.87 | 4.89 | 6.61 | 5.47 |

What this says:

1. **Which stage over-calls: the trees, in the 30%+ band only.** At 30+ the base is
   roughly unbiased (+0.87 all, -0.88 AEF-7), the tree correction averages +3.2
   points (sd 3.2) and is only partly right (regression of base error on
   correction: slope 0.32, i.e. about a third of the correction is warranted),
   leaving xgb at -2.3 (all) / -4.4 (AEF-7). The final published stage recovers
   about 1.4 / 1.6 of that. In the 20-30 band the tree adds -0.6 all and -0.5
   AEF-7: small.
2. **Below 20 the Greens are over-called at every stage by about 1 to 1.5 points,**
   base included. That is the known statewide level bias (NEXT-STEPS line ~75:
   level over-predicts Greens in 23 of 35 elections), not a tree effect. The
   trees move it by +0.2.
3. The 30+ band is **n = 34 rows from 15 elections, 16 rows in AEF-7.** The sign
   is election-dominated (per-election mean xgb error at 30+ ranges from +11.9
   nsw2015 / +9.7 vic2014 / +9.5 fed2013, all single seats where the Greens
   beat the base, to -8.2 qld2024, -6.1 fed2016, -5.8 fed2025, -5.2 vic2022).
   It is not a stable one-directional effect: 6 of 15 elections have a
   positive xgb error at 30+.
4. Named seats (base / xgb / final / actual GRN %): fed2025 Melbourne 44.6 / 48.6 /
   47.6 / 39.5; fed2025 Griffith 33.8 / 42.7 / 35.5 / 31.7 (tree +8.9, final
   claws back); qld2024 South Brisbane 38.7 / 44.1 / 43.5 / 34.7; vic2022
   Northcote 38.0 / 38.0 / 37.4 / 30.0 (tree did nothing here; base itself was
   +8 too high); fed2022 Griffith 24.9 / 25.6 / 26.8 / 34.6 (the opposite
   direction: under-called). Northcote shows the over-call is not always a tree
   effect.
5. Excluding Melbourne rows, 30+ is 25 rows with E_base +0.12, E_xgb -2.81,
   E_final -1.24: the pattern does not rest on Melbourne.

Caveat on the 2026-09-15 retraction (`greens-under-concentration-2026-09-15.md`):
that note warned against grouping by ACTUAL share. Here the bins use base_pred,
known before the outcome, so the selection trap does not apply. The bin sizes
at 30+ are still small.

## Other parties

Same layout (E = actual minus prediction; positive = under-called). All 30
elections; AEF-7 in brackets where it differs in sign or by more than 1 point.

| party / base bin | n | E_base | E_xgb | E_final |
|---|--:|--:|--:|--:|
| ONP 20-30 | 23 | +0.57 | +1.47 | +2.18 |
| ONP 30+ | 9 | -0.24 | +0.47 | +0.08 |
| IND 20-30 | 56 | -2.04 | -2.84 | -3.19 |
| IND 30+ | 66 | +2.08 | -0.38 | +0.97 |
| ALP 30+ | 1825 | -0.52 | -0.89 | -0.34 |
| LNP 30+ | 2030 | -0.54 | -0.62 | -0.23 |

ONP is **under**-called by the trees at high base (xgb +1.5 at 20-30, AEF-7
+3.6), the opposite sign. IND is over-called at 20-30 by every stage including
base (-2 to -3.2) but at 30+ the trees reduce the error (+2.1 to -0.4). So there
is **no general "trees overshoot at large base values" rule**: the effect is
Greens-only, if real, and the Greens have the smallest non-major high-base n
(34). ALP and LNP show the trees nudging 0.1-0.4 lower at 30+, nothing like the
Greens figure.

## In-sample effect size

**In-sample, screen only, not held-out.** Form tested: final' = final -
(1 - w) * (xgb - base) for GRN rows, w = 1/(1 + base/k); k = Inf is no change.
Share RMSE in points, lower is better. All-party RMSE is over all 17,010 rows
(baseline 4.012; the brief's "about 4.1").

| k | GRN RMSE, all 2,620 rows | GRN RMSE, base>=20 (n=133) | GRN RMSE, AEF-7 | all-party RMSE |
|---|--:|--:|--:|--:|
| Inf (now) | 2.817 | 5.098 | 2.387 | 4.012 |
| 100 | 2.815 | 5.022 | 2.366 | 4.012 |
| 50 | 2.821 | 5.040 | 2.369 | 4.012 |
| 30 | 2.832 | 5.094 | 2.382 | 4.014 |
| 20 | 2.844 | 5.161 | 2.399 | 4.015 |
| 10 | 2.871 | 5.301 | 2.442 | 4.018 |
| 5 | 2.898 | 5.427 | 2.487 | 4.021 |

The best in-sample k (100, a very mild shrink) gains 0.002 points on GRN RMSE
and 0.0002 overall. Stronger shrinks make things **worse**, because the tree
correction is mostly right (slope of base error on correction is positive at
every bin; it is 0.6 at 10-30 and 0.3 at 30+, so the warranted share is at
most about a third only in the extreme band).

**Time-forward k** (for each election from 2014, k chosen from
{Inf,200,100,50,30,20,10,5} by squared error on GRN rows of strictly earlier
elections only): it chose k = Inf or 200 every time, and the held-out GRN RMSE
over 24 elections went 2.595 -> 2.594. That is no change.

**Share of total error at stake.** GRN rows are 15% of rows and 7.6% of total
squared share error (2,620 x 2.817^2 over 17,010 x 4.012^2). Rows with base >=
20 (133) are 1.3% of total squared error. Even removing the 30+ mean bias
entirely (-0.88 on 34 rows) is worth a squared error of about 26 of a total of
about 274,000: negligible for RMSE. The case is not about RMSE; it is about
winner calls.

**Winner flips (k = 20, in-sample, final shares):** the Greens are in the final
top two in 110 seat-elections and lead in 25 (19 of those won). The shrink changes
the leader in 5: Balmain nsw2015 (GRN to ALP, actual GRN: wrong), South Brisbane
qld2020 (GRN to ALP, actual GRN: wrong), Richmond vic2022 (GRN to ALP, actual GRN:
wrong), Ballina nsw2019 (GRN to LNP, actual LNP: right), Northcote vic2018 (GRN to
ALP, actual ALP: right). Net 2 right, 3 wrong. Note the leader flips are
share-level only; the seat probabilities come from the simulation and could
differ. The named cases Pete listed (fed2025 Melbourne, Griffith 2025,
South Brisbane 2024, Northcote 2022) do **not** flip at k = 20 because the final
is far ahead of the runner-up in share terms; their problem is the *probability*
(Melbourne ALP 0.006) which comes from the seat-level spread, not the mean
(UNCONFIRMED: I did not read the seat-sd path; the spread of Greens
strongholds in the simulation is the more likely lever than the mean).

## Code location

(Read, not run.)

- Published path: `R/xgb_primary_override.R:205` `xgb_primary_predict_live()`
  (returns `shares` unchanged if disabled at :210; computes trees from its
  `shares` argument, which is the pre-tree base, and sets `base_margin` from
  `rows$base_pred` at :663-667). Called at `scripts/fit_seats_full.R:1396`. A
  post-tree shrink goes at the end of this function, where both the input base
  `shares` and the tree output are in scope (UNCONFIRMED exact line: I did not
  read :668-750 in full).
- Backtest harnesses: `R/xgb_primary_override.R:29` `xgb_primary_override()`,
  called from `scripts/backtest_candidate_fed.R:1489`, `_nsw.R:903`, `_qld.R:888`,
  `_sa.R:1067`, `_vic.R:772`, `_wa.R:622` (and `_nt.R:655`). The loop at
  :105-117 replaces each party column of `shares` (base) with `X$xgb_pred`
  and renormalises at :118; `shares` (base) and the tree value `v` are both
  in scope there. **That is the one shared function for the six harnesses.**
- Precedent: `post_xgb_switches()` at `R/new_ind_shrink.R:40` lists every switch
  that acts after the trees were trained (the as-at trees must never train on
  it), and `scripts/rebuild_forecasts.sh` stage 1 pins them all to 0. A new
  GRN switch must be added to both. Note the existing post-xgb fixes
  (`new_ind_shrink_apply`, `scripts/backtest_candidate_vic.R:767`,
  `fit_seats_full.R:1350`) act BEFORE the override, on the base, and so also
  change the trees' `base_margin`. A shrink *toward base* must act AFTER the
  trees (it needs the tree output), so it is a different shape from those.
- The final stage between xgb and published (E_final differs from E_xgb)
  runs after this point and would act on the shrunk value: the tree-to-final
  stage moved GRN 30+ by about +1.4 on average, so the final interacts with the
  shrink (UNCONFIRMED which function; not traced).

## Proposed arm

Given the numbers above I recommend **not** building this as proposed. If Pete
wants it screened anyway:

- Switch: `AUSPOL_GRN_TREE_SHRINK` (`"0"` off, `"1"` on; validated like
  `new_ind_mode()`), added to `scripts/published_flags.R` (default `"0"` until
  decided), to `post_xgb_switches()` and to `rebuild_forecasts.sh` stage 1.
- Form: for GRN cells only, `x' = base + w * (xgb - base)`, `w = 1/(1 + base/k)`;
  renormalise rows. Shrinks toward "no tree correction", which is the
  shrinkage-toward-no-change form the CLAUDE.md asks for; k = Inf is exactly
  today's behaviour, so the arm is a continuous, not a cliff, change.
- Fitting k time-forward: for target election T, pick k from the grid by
  squared GRN share error on the tree OOF rows of elections strictly before T
  (the as-at predictions file already carries `base_pred` and `xgb_pred`;
  no new training). Partial-pool toward Inf when fewer than about 150 prior GRN
  rows (the design above chose Inf in 14 of 24 elections and 200 in the other 10 for lack of signal).
  Report the k chosen per election.
- Pre-register before running: criterion = pooled seat log loss on all 22 pairs
  plus named-seat probability for the five cases above; name in advance that
  a gain carried by one election (leave-one-election-out) is refused, and that
  the screen above (k=100: -0.0002 overall RMSE; time-forward 0.001 on GRN)
  predicts a null.
- More promising alternative (UNCONFIRMED, not tested): widen the simulation
  spread for high-GRN seats rather than move their mean. The Melbourne 0.006
  figure is a probability problem; mean error 4-9 points on a seat with
  sd about 3-4 would give that.

## Whether quick_arm can screen it

Yes, with one condition. `scripts/quick_arm.R:88` sources
`xgb-primary-asat-predictions.csv`, copies it into each scratch run, and each
harness still runs `xgb_primary_override()` at the normal line (a harness
rerun per election, cached baseline shared). A shrink inside
`xgb_primary_override()` is applied on every quick_arm run. It also needs the
base `shares` argument, which is available there. The cached baseline is
byte-identical for pairs with no GRN seat above the shrink's reach, so only the
affected pairs differ. Two things to check before trusting it: (a) the cached
file must be the one `AUSPOL_XGB_BASE_DELTA` etc. leave alone (the function
applies `xgb_base_delta_apply` at :93-95 first, which could alter `X$xgb_pred`
before the shrink; the shrink should read the post-delta value), and (b) the
live path (`xgb_primary_predict_live`) is not exercised by quick_arm at all, so
a green screen does not show the published forecast changed. UNCONFIRMED: I
have not run quick_arm (forbidden here) and did not verify (a).
