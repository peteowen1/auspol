# sa2026's ONP miss traced to base_pred; the existing (unused) concentration
# fix cuts seat log loss 0.4339 -> 0.3577

Overnight session 2026-09-13/14, continuing from the AEF-comparison work
earlier the same evening. Pete was asleep for the second half; this
autonomous-session convention applies (`~/.claude/CLAUDE.md`, "Autonomous
Sessions") -- work continued without pausing for confirmation, nothing
destructive was done, and nothing was committed.

## Starting point

Four separate SHAP investigations that evening (wa2025 OTH, nsw2023 ALP,
vic2022 IND, sa2026 ONP) all landed on the same driver: `base_pred` -- the
seat-level forecast from `fit_seats_full.R`/the backtest harnesses, computed
*before* xgboost ever sees a row -- accounts for 88-89% of the tree's gain in
every case checked. No downstream xgboost feature (raw trend/fundamentals
split, retiring-MP tenure, census demographics, a 3-way party-group model
split) could compete with it or even meaningfully use the room freed up when
tested in isolation. That ruled out every xgboost-side idea tried that
evening and pointed the investigation at `base_pred` itself.

## The mechanism, traced end to end for Narungga

`base_pred` for ONP comes from `R/dev_slope.R`: `level_now + slope * (x -
level_prev)`, slope = 0.551 (fitted, shrinks each seat's deviation from the
statewide mean). Real numbers for Narungga:

- `x` (Narungga's own 2022 ONP result): 5.39%
- `level_prev` (SA's 2022 statewide ONP result, ALL votes, all 47 seats):
  **2.63%** -- ONP contested only 19 of 47 seats in 2022; the seats they DID
  contest averaged 6.59%, but the vote-share-of-everyone denominator crushes
  the "statewide" figure most other reasoning about this pair had assumed
  was ~11-12%. (A wrong guess corrected in-session when Pete pushed back on
  it -- see the conversation transcript.)
- `level_now` (predicted 2026 statewide ONP, from `level-pred.csv`): 19.85%
- `dev_slope(5.39, 2.63, 19.85, 0.551)` = **21.37** -- matches the observed
  base_pred (18.5-21.7 range) closely.
- Actual 2026 result: **37.72%**, the single highest ONP seat in the state.

`dev_slope()` is rank-preserving by construction: a seat's position relative
to the statewide mean persists, just shrunk. Narungga went from a modestly
above-average seat in a crushed 2022 baseline to the strongest ONP seat in
the state -- there is no `slope` value that formula can produce that outcome
from those inputs. The same failure mode explained MacKillop and Taylor.

Two direct answers that came out of this trace, both confirmed against the
code:

- **Demographics do not feed `base_pred`.** Neither `dev_slope()` nor the
  ONP-specific mechanism below touches census data. Every census experiment
  that evening (v7k/l/m, and a retest as v7n) was downstream of `base_pred`,
  which is why even a genuinely strong within-election correlation
  (yr12_pct vs ONP, r=-0.922 in sa2026 alone) moved predictions by hundredths
  of a point against `base_pred`'s 6-12 point pull.
- **"Did the minor party run last time" is already the whole mechanism** (`x`
  above) -- the problem was never that this signal was missing, it's that
  the persistence assumption built around it cannot express a seat becoming
  the party's new stronghold.

## The fix already existed, unused

`scripts/backtest_candidate_sa.R` (lines ~626-674) has an `AUSPOL_ONP_CONC_SD`
arm, default OFF, that reorders seats by their own recent **federal** One
Nation vote (`external/elections/federal-transposed-to-state.csv`, an
independent, fresher signal than the seat's stale 2022 state result) and
quantile-maps the statewide ONP total onto a target concentration SD. The SD
itself comes from `scripts/estimate_onp_concentration.R`, a proper
leave-this-election-out fit (`SD = a * statewide^k` on 16 other elections),
which prints exactly what to run:

```
CN3  held-out ecsa-2026-sa-firstprefs.csv: statewide 22.88
CN3  PREDICTED SD 9.18   (actual 7.67, ratio 1.20)
CN4  R3 extrapolation check: ... 22.88 is ABOVE that range -- provisional
CN5  run the arm with:  AUSPOL_ONP_CONC_SD=9.18
```

This was built for a *different* purpose (`docs/plans/prereg-onp-concentration-transport.md`,
transporting a concentration shape to Victoria's live 2026 forecast) and had
apparently never been scored against sa2026 itself -- exactly the "ask what
the system already has" trap `CLAUDE.md` names, caught only because tracing
`base_pred` by hand for one seat led straight to the same mechanism a
from-scratch scratch-script reimplementation had just reproduced (same
ordering, Spearman +0.939 both times -- the fitted `sa_ratio` VIC uses and an
ad hoc NSW2023-template version score identically on ranking, which is a
useful cross-check that the ordering signal is real and not an artefact of
which shape template is used).

## Measured

**First wiring gap found**: `AUSPOL_ONP_CONC_SD` reshapes `shares[,"ONP"]`,
but `shares <- xgb_primary_override(shares, TGT)` (line 798, AUSPOL_XGB_PRIMARY=1,
the shipped default) unconditionally overwrites `shares` with the offline
xgboost model's own prediction straight after. Under the shipped config the
two runs were **byte-identical** -- the arm never had a chance to matter
until the offline xgboost model was retrained on sharedetail that was itself
built with the arm on.

**Raw model (`AUSPOL_XGB_PRIMARY=0`), isolating the fix on its own terms:**

| | accuracy | Brier | log loss |
|---|---|--:|--:|
| off | 40/47 (85.1%) | 0.1121 | 0.3611 |
| **on (SD=9.18)** | **43/47 (91.5%)** | **0.0904** | **0.2961** |

18% lower log loss, 3 more seats called correctly, rank correlation
0.668 -> 0.939.

**A CV sensitivity sweep** (rescaling concentration between the NSW2023
template's own raw CV 0.314 and the 0.482 upper bound `fit_seats_full.R`'s
own VIC docs already bracket) found the best pooled RMSE around CV 0.40, and
confirmed MacKillop is a genuine outlier the mechanism cannot reach at any
setting: its federal ONP vote ranks it 15th of 47 SA seats, but its actual
2026 result is 2nd-highest in the chamber. Every other seat in the top 12 by
federal rank lands within a few places of its actual rank; MacKillop alone
does not, most likely a state/federal boundary mismatch under the shared
seat name rather than a magnitude problem.

**Full retrain-and-verify, confirming the fix survives into the actually
shipped configuration** (all 23 pairs regenerated clean at
`AUSPOL_XGB_PRIMARY=0`, 20,000 sims -- `pool_sharedetail.R`'s own safety
checks refused to pool anything short of this twice, correctly -- then
`fit_xgb_primary_v6.R` retrained, then `fit_xgb_primary_v7.R` rebuilt the
shipped v7f arm on the corrected features):

| SA2026, shipped config (`AUSPOL_XGB_PRIMARY=1`), 20,000 sims | accuracy | Brier | log loss |
|---|---|--:|--:|
| before (current shipped OOF file, unmodified) | 39/47 (83.0%) | 0.1402 | 0.4339 |
| **after (retrained on ONP-fix-corrected sharedetail)** | **41/47 (87.2%)** | **0.1193** | **0.3577** |

17.6% lower log loss through the full pipeline, nearly matching the raw
model's own 18% -- xgboost does not wash the fix out.

**Do-no-harm spot check, QLD2024** (the other state with a real One Nation
presence, most likely place for a corpus-wide retrain to disturb something):
log loss 0.3061 -> 0.3106, accuracy unchanged at 81/93, Brier 0.0969 -> 0.0976.
Noise-level, not a regression.

## Full six-harness sweep (completed after this doc's first version)

Same before/after comparison (current shipped OOF vs the retrained-with-the-fix
OOF), all at 20,000 sims:

| pair(s) | before | after | verdict |
|---|---|---|---|
| SA2026 | log 0.4339 | log 0.3577 | **big win** (the target) |
| NSW2023 | log 0.2699 | log 0.2694 | flat |
| QLD2024 | log 0.3061 | log 0.3106 | flat (noise) |
| WA (7 pairs) | Brier 0.1013 | Brier 0.1007 | flat, every pair noise-level |
| FED (7 pairs, pooled) | log ~0.2602 | log ~0.2587 | flat/tiny win |
| **VIC2022** | **72/78 (92.3%), log 0.2347** | **69/78 (88.5%), log 0.2494** | **real regression** |
| VIC2014, VIC2018 | — | — | flat |

**VIC2022 is a real, not noise-level, regression** (3 fewer seats correct,
log loss +6.3%). Traced directly: the retrained model pushes IND predictions
UP across nearly every VIC2022 seat where an independent barely polled --
Richmond (actual 1.0%, was predicted 9.6, now 12.2), Northcote (1.4% actual,
9.8 -> 11.8), Prahran, St Albans, Brunswick, Malvern all show the same
pattern. `vic2022`'s own `base_pred` input is unchanged (fixed seed, no VIC
code touched tonight) -- this is the retrained xgboost model's own tree
structure shifting, a genuine shared-learner side effect: fixing SA's ONP
splits moved the model's general IND-prediction behaviour, and vic2022 is
the pair that happens to be sensitive to it. This is the exact same
"vic2022 IND/OTH_RIGHT degeneracy" pattern already named in
`fit_xgb_primary_v6.R`'s own diagnostic print, now shown to interact with
this fix specifically.

**This changes the recommendation below**: the fix is not a clean win, it is
a real trade -- SA gets much better, VIC2022 gets measurably worse, everything
else is unaffected. Shipping it as-is means knowingly trading one state's
accuracy for another's without resolving why they're coupled.

## What is NOT done
- MacKillop's federal/state boundary mismatch is unexplained, not just
  unfixed. Worth checking directly against an SA electoral boundary map
  before assuming it's a labelling issue.
- The concentration SD (9.18) is a genuine out-of-range extrapolation per
  `estimate_onp_concentration.R`'s own R3 check -- flagged provisional there
  and worth re-stating here rather than treating 9.18 as settled.
- `AUSPOL_ONP_CONC_SD` was tested but not turned on by default anywhere.
  `output/xgb-primary-shipped-oof-predictions.csv` (the file
  `published_flags.R` actually points harnesses at) is untouched; tonight's
  new OOF file lives at `output/xgb-primary-v7-oof-predictions.csv`, a
  diagnostic file, not the shipped one.
- No code was committed. `git status` at the end of this session shows the
  earlier evening's rename (`level_now`->`level_pred`, `pred_share`->
  `base_pred`, `x`->`seat_prev_pcv`) and the `fit_xgb_primary_v7.R` `ran`-list
  bug fix, still uncommitted from before this ONP work started, plus three
  earlier-session scripts (`build_level_components.R`,
  `build_retiring_mp_cases.R`, `build_level_pred_aef_compare.R`) and the NSW
  exhaust wiring in `backtest_candidate_nsw.R`. Recommend reviewing and
  committing these as separate, already-described commits before touching
  anything ONP-related, since they predate and are independent of tonight's
  finding.

## Follow-up: the VIC2022 regression traced to `sal_exp`, and a real
## normalisation bug that is NOT worth fixing as-is

SHAP on the v7f feature set (the actually-shipped arm, `ret_exp`/`sal_exp`
included -- an earlier pass used v6's feature file by mistake and missed
them) showed `sal_exp` is the second-largest contributor in every one of the
seven worsened VIC2022 seats, always pushing UP against `base_pred`'s correct
pull down: Richmond +1.16, Northcote +1.72, Prahran +1.25, St Albans +1.86,
Brunswick +1.70, Malvern +2.09, Albert Park +4.16.

**A real bug underneath it.** `fit_xgb_primary_v7.R` computes `jump_pctile`
two different ways: the model FEATURE (X71 block) ranks within the non-zero
jump set only -- the correct form, per this repo's own documented
percentile-of-ties fix -- while `sal_exp`'s own isotonic TRAINING data
(the `GOV` block) ranked over all governed candidates including the 51-81%
with `jump == 0`. Train and apply were on different scales: the zero-jump
population piles up at percentile 0.40-0.55 in training instead of 0, so any
candidate whose real percentile sits below that pile got clamped (`rule = 2`)
up to "what a typical zero-salience independent polls".

**It is not vic2022-specific.** Share of non-zero-jump IND candidates falling
below the training pile-up point: fed2019 66.7%, sa2026 66.7% (n=3),
fed2010 62.5%, **vic2022 48.4%**, qld2020 47.1%, ... wa2008 25.0%. VIC2022 is
mid-pack. It surfaced there only because that was the pair the ONP do-no-harm
check was already looking at, and VIC's 88-seat chamber dilutes 31 affected
candidates less than a 150-seat federal field does.

**Both corrected versions were built and measured, and both lose
election-wide.** Pooled seat log loss over 738 seat-elections (sa2026, three
VIC pairs, fed2019/2022/2025):

| config | pooled log loss |
|---|--:|
| baseline, no fixes | 0.2452 |
| **ONP fix only** | **0.2403** |
| ONP + corrected percentile (v1) | 0.2426 (fed2022 0.2758) |
| ONP + corrected percentile, curve trained on non-zero only | 0.2426 (fed2022 0.2708) |

The stronger second variant (train the curve on the population it is actually
applied to) beats the first on every federal pair and **essentially repairs
VIC2022** -- 0.2494 -> 0.2373 against a 0.2347 pre-regression baseline, and
vic2018 improves too -- but it costs fed2022 (0.2628 -> 0.2708) and fed2025
(0.2600 -> 0.2658), and nets out slightly behind ONP-alone.

The reading: the isotonic curve's SHAPE is tuned to the compressed training
scale, so correcting the input without refitting the curve for the corrected
scale just moves the error between elections.

## Refitting the curve on the corrected scale (`AUSPOL_SAL_CURVE_NZ=2`)

Diagnosed WHY the corrected scale lost before refitting. `isoreg()` is least
squares, so it fits the conditional MEAN, and independents' vote is heavily
right-skewed -- on the corrected scale the (0.5,0.8] band averages 9.8 across
160 cells while most of those candidates poll far less. Mean-fitting therefore
hands every mid-salience independent a prediction the typical one never
reaches. The old buggy scale accidentally compressed that whole population
into a flat, low region, which is closer to the typical outcome.

At the FEATURE level the corrected scale looks better on teals -- the `sal_exp`
value itself lands closer to what they polled:

| fed2022 teal | actual | old scale | corrected, mean | corrected, median |
|---|--:|--:|--:|--:|
| Kooyong | 40.3 | 32.9 | 32.9 | 30.9 |
| Mackellar | 38.1 | 22.1 | 27.4 | 27.8 |
| Curtin | 29.5 | 21.6 | 27.4 | 26.3 |
| North Sydney | 25.2 | 21.6 | 27.4 | 23.3 |

**AND THAT IS MISLEADING -- the FINAL predictions move the other way.** An
earlier version of this doc concluded from the table above that teal detection
was not the problem. Checking the model's actual output rather than the
feature's value shows the opposite (predicted IND primary, %):

| fed2022 teal | actual | shipped | +ONP | +corrected, mean | +corrected, median |
|---|--:|--:|--:|--:|--:|
| Kooyong | 40.5 | 29.7 | 27.7 | 27.4 | 29.8 |
| Mackellar | 38.1 | 21.8 | 24.0 | 18.4 | 18.8 |
| Wentworth | 35.8 | 35.4 | 33.0 | 31.6 | 30.3 |
| Goldstein | 34.5 | 20.9 | 19.4 | 16.2 | 18.1 |
| Curtin | 29.5 | 22.4 | 25.5 | 20.4 | 18.0 |
| North Sydney | 25.2 | 13.9 | 14.9 | 13.6 | 13.5 |
| **mean abs error** | | **9.92** | **9.85** | 12.67 | 12.51 |

A BETTER-CALIBRATED FEATURE PRODUCED WORSE PREDICTIONS. The mechanism: the
model's value from `sal_exp` is its DISCRIMINATIVE SEPARATION, not its
calibration. On the corrected scale many mid-salience independents also get
elevated `sal_exp`, so a split like `sal_exp > 15` stops isolating genuine
teals, its branch fills with mid-tier also-rans, and the leaf value dilutes
downward -- taking the real teals with it. This is the federal regression,
seen directly.

Worth recording separately: **every config under-calls all six teals by 10-20
points.** The teal wave is not solved by any of this; the ONP fix is a wash on
it (9.85 against the shipped 9.92).

Mode 2 bins the training rows and isoregs the bin MEDIANS -- monotone as
before, but tracking the typical outcome rather than one dragged up by a few
successes. Its curve is conservative through the mid-range (2.8 at pctile 0.4,
5.7 at 0.6) and still steep in the tail (28.4 at 0.95).

**Measured, and the trade is real -- confirmed at two seeds.** Seed-to-seed
variation is ~0.001, an order of magnitude below the differences:

| config | sa2026 (s42/s43) | fed2022 (s42/s43) | vic2022 | pooled, 738 seats |
|---|---|---|--:|--:|
| baseline, no fixes | 0.4339 | 0.2673 | 0.2347 | 0.2452 |
| **ONP fix only** | 0.3577 / 0.3569 | **0.2628 / 0.2637** | 0.2494 | **0.2403** |
| ONP + corrected, mean | 0.3610 | 0.2708 | 0.2373 | 0.2426 |
| ONP + corrected, median | **0.3472 / 0.3466** | 0.2748 / 0.2755 | **0.2365** | 0.2430 |

The median refit does exactly what it was built to do: **best sa2026 of any
config** (0.347, better even than the ONP fix alone) and **vic2022 essentially
repaired** (0.2365 against a 0.2347 pre-regression baseline). It still loses
pooled, because the federal cost is real and federal carries 452 of the 738
seats.

**A judgement call worth making explicitly rather than on a pooled average.**
The live target is Victoria, November 2026. vic2022 is the closest available
proxy for that job, and it is the pair the median refit repairs. Choosing
ONP-only because it wins a pooled number weighted 61% federal means choosing
the config that is measurably worse on the election we are actually
forecasting. That is Pete's call, not a number's.

**Amended after the teal check above**: the trade is less balanced than that
framing suggested. The salience refits do not merely cost federal on a pooled
average -- they degrade teal primary predictions by ~2.6 points of mean
absolute error (9.85 -> 12.5), which is the specific capability `sal_exp`
exists to provide, and independents are where the standing gap against AE
Forecasts actually lives. Recommend leaving the salience change OFF on that
basis rather than on the pooled number. The vic2022 repair still wants
solving, but through something that does not blunt teal separation.

## Recommendation

**NOT ready to ship as-is.** The six-harness sweep found a real regression
(VIC2022, -6.3% log loss, 3 fewer seats) alongside the SA win, both traced
to the same retrained model -- this is a genuine trade, not a clean win, and
shipping it now means knowingly making VIC2022 worse without understanding
why the two are coupled. Before shipping `AUSPOL_ONP_CONC_SD=9.18` as SA's
default in `scripts/published_flags.R`:

1. **Understand the VIC2022/IND coupling first.** Likely candidates: retrain
   with a higher `min_child_weight` or more regularisation so one region's
   correction can't shift a shared split elsewhere; or give IND's tree
   region-specific room (an interaction feature) so SA's fix stops leaking
   into VIC's IND predictions. Re-run the vic2022 IND SHAP breakdown (already
   done once tonight, before this fix) against the retrained model to see
   which feature moved.
2. MacKillop's boundary question -- shipping without checking it means
   knowingly leaving the state's 2nd-strongest ONP seat under-called by ~9
   points with no plan to fix it.
3. The usual code-review gate before any PR, per `~/.claude/CLAUDE.md`.
