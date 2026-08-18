# The "Others" bias is a fifth the size it was reported to be, and the polls own most of what remains

Run 2026-08-18 against
[../plans/prereg-others-bias.md](../plans/prereg-others-bias.md), by
`scripts/test_others_bias.R`. Every threshold and decision rule was fixed
before the run.

## Headline

Two findings, and the first changes how to read the second.

1. **The −3.60 that motivated the pre-registration is mostly an artefact of
   cycles whose recorded actuals do not sum to 100.** On the cycles that do,
   the bias is **−1.02** points over 33 cycles.

   Two comparisons, because they are different and only one of them is
   like-for-like. Within this script's own pipeline, dropping the completeness
   filter moves the bias from −1.02 to −5.03, so **80%** of the unfiltered
   figure is contamination. Against the published −3.60, the drop to −1.02 is
   **72%** — but that comparison is not clean, because this pipeline does not
   reproduce −3.60 under any filter setting (it gets −5.03 on 58 cycles where
   the published run reported −3.60 on 54). The 80% is the defensible number;
   the exact composition of the published 54-cycle set is unrecoverable.

2. **On the clean set, the fit sits within 0.87 points of the final month of
   polling while that polling sits 2.11 points from the result** — a ratio of
   0.41. T1 and T3 do not fire.

Per the decision rule fixed in advance, that means: record it as a limit of
poll-based forecasting, publish the caveat beside the Others figure, and **do
not change the trend model**. That is what was done.

**One honest caveat about T2's verdict.** The plan said T2 fires when
|model − polls| is "much smaller" than |polls − actual|, and never put a number
on it. The `0.5` bar in `test_others_bias.R:184` was written with the script,
in the same commit that ran it — it is **not pre-registered**, and the measured
0.41 clears it narrowly enough that a bar of 0.4 would have reported "nothing
fired". So read the ratio, not the verdict.

What saves this from mattering much: **the action is the same either way.** The
plan's "nothing fires" branch says record the bias as measured and unexplained,
which — like the T2 branch — leaves the trend model untouched. The two branches
differ only in whether the miss is *attributed* to the polls, and the numbers
supporting that attribution (0.87 against 2.11) are descriptive and hold
regardless of where the bar sits. The page caveat quotes those numbers rather
than announcing a fired test.

## The anchor check failed first, and that was the useful part

The plan's table came from an ad-hoc measurement that left no script. So the
first thing `test_others_bias.R` does is try to reproduce it, with the
tolerances written down before the run:

| party | published bias | published n | reproduced | n |
|---|---:|---:|---:|---:|
| **OTH** | **−3.60** | 54 | **−1.02** | 33 |
| LNP | −1.11 | 54 | −0.88 | 28 |
| ALP | +0.33 | 54 | +0.06 | 33 |
| GRN | +0.10 | 33 | +0.10 | 28 |

**OB0 FAILS.** Had the script simply run T1–T3 and reported a winner, it would
have reported a cause for a quantity that does not exist as stated.

## Where the missing 2.6 points went

Dropping the completeness filter reproduces the published shape almost exactly:

| set | cycles | OTH bias |
|---|---:|---:|
| complete actuals only (pre-registered) | 33 | **−1.02** |
| no completeness filter | 58 | **−5.03** |
| as published | 54 | −3.60 |

The 25 excluded cycles have actuals summing to **111.0 on average** — not
short, *over*. Parties are double-counted in those rows (a state's Liberal,
National and combined LNP lines all present, for instance), and the surplus
sits in the listed "Others" figure. Fitted Others is unaffected, so the
comparison manufactures a shortfall that no model produced.

The review that published the −3.60 described its 54 cycles as ones "where the
recorded results are themselves complete". **They were not**, and its own plan
listed this exact confound as the threat the filter existed to remove. The
filter was named and then not applied.

## The three tests, on the clean set

| test | cause | result | fires |
|---|---|---|:--:|
| T1 | prior too sticky | slope +0.026 (se 0.104, p=0.80) | no |
| T2 | shared pollster miss | \|model−polls\| 0.87 vs \|polls−actual\| 2.11 | **yes** |
| T3 | walk too slow | slope −0.265 (se 0.173, p=0.14) | no |

T1 predicted a negative slope and got a positive one indistinguishable from
zero. T3's slope has the predicted sign but does not reach the threshold.

T2's ratio is 0.41 against a pre-registered bar of 0.5. The model's endpoint is
0.22 points below the final month of polling; that polling is 0.80 points below
the result. **The model tracks its inputs and its inputs miss.**

## What was NOT concluded

- **Not "the trend model is fine".** A −1.02 bias on Others is still the
  largest of any party. T2 says the model is not where it originates.
- **Not a cause for the −5.03.** That number is contaminated and no cause was
  sought for it.
- **Not settled at n=33.** Restricting to four regions instead of six moved the
  bias from −1.02 to −0.63 and flipped which test fires (T3 at p=0.008 rather
  than T2). The six-region set is the correct one — four was an unstated
  narrowing copied from `build_projection_data()`, whose defaults exist for a
  different purpose — but a result that moves this much under a scope change is
  not a strong result, and T3 deserves a second look with more cycles.

## A data bug found on the way

`eventual-results.csv` carries **WA 1993 twice**, all six of its rows duplicated
verbatim (lines 347–358). Every mean taken over that table double-counted the
cycle. The file's only duplicate — the whole key set was swept, per the rule
that one wrong entry in hand-maintained reference data predicts siblings.

`load_eventual_results()` now drops identical duplicates with a warning naming
the cycle, and **refuses** rows that share a key while disagreeing on the
value, since there is no basis for choosing between them. Both branches were
proven against deliberately broken input before being trusted.

Note what could not have caught this: the loader's `nrow(out) < 380` floor.
Duplicates push the count *up*, so they make a truncated file look healthier —
the repo's "a size floor is not a completeness check" hazard, arriving from the
other side.

## Still open

- **`NL3` still fails and the scheduled job stays red.** NSW's 2027 fitted
  first preferences sum to 94.1 against a required 100 ± 5. The plan treated the
  drifting sum as a symptom of the Others bias; at −1.02 for Others and −0.88
  for LNP, that accounts for about 2 of the 5.9 points. **The rest is
  unexplained.** Do not relax the threshold to clear it.
- **T3 at n=33.** Sign is right, significance is not, and it was significant on
  a smaller set. Worth revisiting when more cycles have complete actuals.
- **Fixing the 25 contaminated cycles upstream** would roughly double the
  sample. The double-counting looks mechanical and may be repairable.
