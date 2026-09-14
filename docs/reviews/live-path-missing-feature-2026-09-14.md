# The live forecast was predicting half the vote, and renormalisation hid it

Found 2026-09-14 while answering a question about why One Nation was rated so
highly in three Victorian seats. The answer turned out not to be about One
Nation.

**Verdict: a feature the model had never seen missing was passed as `NA` on
every live Victorian row, deflating all predictions ~45%. Fixed for the live
path (`88653b4`); the underlying data gap backfilled (`4e5fde4`); retrain
outstanding.**

## What was observed

Three seats where our forecast disagreed sharply with AE Forecasts:

| seat | AEF ONP | ours ON | ours OFF |
|---|--:|--:|--:|
| Eureka | 0.181 | 0.985 | 0.780 |
| Sunbury | 0.120 | 0.916 | 0.720 |
| Melton | 0.129 | 0.908 | 0.722 |

The predicted primaries behind them looked equally lopsided — One Nation at
43-46% against AEF's 17.7-19.8%.

## What was actually wrong

The model's RAW predictions, before renormalisation:

| Melton | raw | renormalised |
|---|--:|--:|
| ONP | 19.75 | 43.34 |
| ALP | 16.22 | 35.59 |
| **LNP** | **6.05** | 13.28 |
| GRN | 1.69 | 3.71 |
| **sum** | **45.6** | (×2.194) |

One Nation's raw 19.75 is reasonable against a statewide 20-23%, and close to
AEF's 17.65. **The Coalition's 6.05% is not a low prediction, it is a broken
one.** Every party was deflated, One Nation least, and renormalising the seat
to 100 converted "least deflated" into "commanding lead" — while also
multiplying the gaps between parties by 2.19, which is where the 0.985 came
from.

The decisive comparison: raw row sums.

| | median row sum |
|---|--:|
| live Victorian path | **54.3** |
| the same model's out-of-fold predictions, all 23 backtest pairs | **91.2 - 105.0** |

## The cause

`historic_elected_i` — "is a proven former winner standing here for this
party" — was `NA` on 100% of live rows. Two sibling features were also missing
and were **fine**, which is what made this hard to see:

| feature | missing live | missing in training |
|---|--:|--:|
| `own_prev_pcv` | 100% | 95.0% — model knows this route |
| `ballot_pos_min` | 100% | 60.6% — model knows this route |
| **`historic_elected_i`** | **100%** | **never** |

Filling that one feature with `0` moved the median row sum from 54.0 to
**98.7**. `0` is not a fallback: it is the value every state election in the
training corpus carries.

And it did not lift the parties equally — in Melton, LNP +12.96 against ONP
+6.65 — which is why it changed answers rather than just levels. Labor's
expected Victorian seats went **39.49 → 29.95**.

## Why the feature was constant

`historic_elected` comes from the AEC's `HistoricElected` column, which exists
only in FEDERAL files. `build_candidacies.R` fell to `else NA` for every state
commission and the downstream `%in% c("Y","TRUE","1")` turned that into
`FALSE`. All 907 `TRUE` values in the corpus were federal; all 21 state
elections recorded zero returning members, which is false about the world and
made the column a federal/state label inside the model.

## Three wrong conclusions drawn before the cause was found

Each was measured honestly and each was an artefact:

1. **"The override suppresses One Nation."** From sa2026 alone, where it turns
   4 correct seat calls into 1.
2. **"It is neutral for minor parties generally."** The 58 minor-party wins
   split IND 36 (override better by 0.139), GRN 13 (worse by 0.030),
   OTH_RIGHT 5, ONP 4 (worse by 1.141) — four One Nation seats almost exactly
   cancelling thirty-six independent ones.
3. **"ALP 32.84 → 39.95 is what the XGBoost components are worth."** Mostly
   this bug. The corrected figure sits BELOW the override-off arm.

## What let it through

The comment at `R/xgb_primary_override.R:132`:

> `historic_elected`/`ballot_position`, both NA pre-nomination -- fine, same
> missing-value routing

An assumption written as a reassurance, never tested. True of the feature
beside it, false of this one. Nothing errored, shares summed to 100, and the
output looked plausible — the exact shape CLAUDE.md's opening rule describes:
*every real bug here produced plausible output while something quietly did not
apply.*

**The check that would have caught it on day one**: compare the raw row sums of
the live path against the backtest's. One line, and it is the only diagnostic
that made this visible.
