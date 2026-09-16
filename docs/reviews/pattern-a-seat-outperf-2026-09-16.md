# Pattern A tested: real targeted signal, pooled guard fails either way, and gating didn't fix it

2026-09-16, following up Pete's question on the AEF-7 Seat Ledger artifact:
"any fix tested?" for the worst misses. Four of the artifact's worst rows
(Black, South Brisbane, Finniss, Parramatta) trace to patterns diagnosed in
`docs/reviews/worst-seats-five-patterns-2026-09-13.md`. Pattern A — a senior
retiring MP loses more personal vote than the flat retirement discount
assumes — was queued there as "the cheapest lever... next session/turn's
task" and never built. This is that build.

## Sizing, before building anything

The review named 5 cases. Testing a feature only on the cases that motivated
it is the selection-bias trap `CLAUDE.md` names repeatedly, so this was sized
on **all 349 retirement cases in the corpus**, not the 5.

`seat_outperf`: for the party that held a seat, how much its own result last
time exceeded its statewide average at that same election — computable
directly from data already in `fit_xgb_primary_v6.R` (`seat_prev_pcv` minus
`state_level(pr$prev)`), no new fetch, no hand-curated "was this MP a
minister" list (which would have meant verifying ~349 individuals across 6
jurisdictions from memory — the fabrication risk `CLAUDE.md` warns about).

Correlation between `seat_outperf` and the current model's residual on
retiring-incumbent rows: **r = 0.176, p = 0.001, n = 349**. Real, in the
predicted direction (bigger personal-vote premium → model over-predicts more
after the member leaves), small.

## Built, measured: real targeted gain, pooled guard fails

Added as a feature, retrained (leave-one-pair-out OOF, same seed/params as
every other v6 change this repo makes):

| slice | before | after |
|---|--:|--:|
| pooled, all 13,739 rows | 3.8078 | **3.8239** (worse) |
| all 2,245 retirement-seat rows | 4.9409 | 4.9234 |
| held-party row only (176 rows, the exact mechanism) | 7.6661 | 7.4256 |
| the 5 named seats, aggregate | 5.1057 | 4.9725 |

Seat-by-seat on the actual 5 targets: Monaro/Barilaro, Riverstone/Conolly and
Parramatta/Lee improved (Parramatta the most, 11.28→9.84 error); Braddon/
Pearce flat; **Richmond/Wynne got worse (4.56→5.86)** — expected, since the
2026-09-13 review already flagged Richmond as a *different* mechanism
(preference reversion direction, not personal-vote size).

## Did it stay scoped to the target rows? No — measured, not assumed

66.5% of all 13,739 rows moved by more than 0.1 points, because `seat_outperf`
was computed and exposed for every row, not gated to retirement cases.
Non-retirement rows (81.7% of the corpus) got *worse* (RMSE +0.0314), more
than retirement rows improved (-0.0175) and over 4x the row count — that
single-handedly explains the pooled regression (121% of the pooled squared-
error change comes from non-retirement rows).

## Gated it. Spillover barely moved. Targeted gain shrank.

Reworked the feature to be nonzero on exactly the 176 rows the mechanism
applies to (retiring incumbent's own row), zero everywhere else. Verified via
`XG8` log line before training.

| slice | ungated | gated |
|---|--:|--:|
| pooled | 3.8239 | 3.8233 |
| non-retirement RMSE delta | +0.0314 | +0.0244 |
| rows moved >0.1pt | 66.5% | **62.7%** |
| retirement-rows RMSE delta | -0.0175 | **-0.0057** (weaker) |
| 5 named held-party rows | 5.3559 -> 5.2253 (both runs, similar) | |

Gating the feature's *values* barely reduced how many predictions moved and
did not fix the non-retirement regression, while it measurably weakened the
targeted gain. **This rules out "the tree misuses the feature on rows where
it shouldn't apply."** The real mechanism is almost certainly the same one
found earlier the same session with the by-election fallback: adding any new
column to this pipeline shifts xgboost's histogram binning and split search
broadly, regardless of how much information that column actually carries on
most rows. A near-all-zero column still perturbs the fit.

## What this means for the pooled do-no-harm guard, generally

**A single fixed-seed OOF run's pooled RMSE may not be a valid arbiter for a
small, narrowly-targeted feature addition.** The training-process noise from
merely adding a column looks to be comparable in size to, or larger than, the
genuine targeted effect being tested. This is a different failure mode from
the MDE-sizing problem `CLAUDE.md` already documents for simulation-based
metrics (calibration slope, seat-share RMSE at one seed) — this is the
*primary model's own training procedure* being unstable to column addition,
not sampling noise in what it's evaluated against.

**Tested and ruled out**: `colsample_bytree=1` (removing column-subsampling
randomness entirely) does NOT fix this — pooled RMSE with the gated feature
at `colsample_bytree=1` was 3.8279, slightly worse than the default 0.8's
3.8233. The instability is not from random column selection interacting
with feature-set size.

**Not established**: whether the instability is fixable another way (e.g.
averaging multiple `xgb.cv` seeds before trusting any pooled delta below
some threshold), or whether it's simply an inherent property of this
training procedure to live with. Either would change how every future
"pooled vs targeted" measurement in this pipeline should be read, not just
this one.

## The fix: NA, not zero, for the off-target rows

Pete's question: does NA vs. 0 for the gated-off rows change this? Tested
both, plus placebo columns (same fill convention, zero real information) to
separate "cost of adding a column" from "cost of this feature specifically."

| fill for the 13,563 off-target rows | real values | pooled RMSE | vs no-column baseline (3.8078) |
|---|--:|--:|--:|
| — (no column at all) | — | 3.8078 | — |
| all-0 (placebo) | 0 | 3.8222 | +0.0144 |
| all-NA (placebo) | 0 | 3.8222 | +0.0144 |
| **0-filled**, gated | 176 | 3.8233 | +0.0155 |
| **NA-filled**, gated | 176 | **3.8161** | **+0.0083** |

A wholly-constant column costs the same **+0.0144 regardless of whether it's
0 or NA** — that increment is the noise floor of adding any column to this
pipeline (confirmed earlier the same session with the by-election-fallback
feature; not specific to this one). But once real values are mixed in,
representation matters a great deal: NA-fill costs roughly **half** what
0-fill costs. Mechanically clean: `seat_outperf`'s real values range about
-24 to +63, so a filled `0` sits inside the plausible range and the tree
cannot tell "off-target row" from "a seat that genuinely scored zero" —
every split placed near 0 mixes both populations. NA is explicitly flagged
missing and routed via xgboost's learned default-direction path instead,
which doesn't force a value into the middle of the real range.

**Placebo-controlled, the real information is worth +0.0061 of pooled RMSE**
(3.8222 all-NA placebo minus 3.8161 real-values NA-fill) — both runs pay the
same one-column noise floor, so this isolates what `seat_outperf` itself
contributes: a genuine, if small, net improvement once that floor is
subtracted out. The raw number (3.8161) still sits above the true
no-column baseline (3.8078), so it does not clear the guard as usually read,
but the guard itself is not built to separate "one more column" noise from a
feature's own effect, and this is the first time that noise floor has been
measured directly.

And the targeted gain got STRONGER with the correct fill, not just cheaper:

| slice | 0-fill gated | NA-fill gated |
|---|--:|--:|
| held-party row, retirement seats (n=176) | 7.6661 -> 7.4256 | 7.6661 -> **7.2843** |
| Riverstone/Conolly error | 1.29 -> 0.74 | 1.29 -> **0.30** |
| Monaro/Barilaro error | 5.17 -> 4.34 | 5.17 -> **4.10** |
| Parramatta/Lee error | 11.28 -> 9.84 | 11.28 -> 9.11 |
| Richmond/Wynne error | 4.56 -> 5.86 (worse) | 4.56 -> **7.23** (worse still) |

NA-fill sharpens both the correct cases (bigger gains) and the wrong-mechanism
case (Richmond gets worse still) — consistent with a cleaner, more confident
signal rather than a diluted one. Richmond is not this feature's mechanism
(the 2026-09-13 review already named it as rightward preference reversion),
so it should not be expected to help there.

## Status

**SHIPPED, 2026-09-16.** `seat_outperf`, gated to the retiring incumbent's own
row, **NA-filled elsewhere, not zero-filled** — real, placebo-controlled
positive effect (+0.0061), strong targeted gain (held-party RMSE -0.38, two
of the five named seats' errors roughly halved), known and expected
exception (Richmond, different mechanism). Pooled OOF RMSE 3.8161, confirmed
to reproduce exactly on the final commit. `output/xgb-primary-v6-oof-
predictions.csv` regenerated; every harness reading `AUSPOL_XGB_PRIMARY_LIVE=1`
picks it up on its next run.

**Not yet done**: the zero-vs-NA finding likely generalises to OTHER
existing features in this script using the same `ifelse(is.na(x), 0, x)`
convention (`seat_prev_pcv` itself, at minimum, uses it) — worth an audit,
not assumed. And the noise-floor finding (any added column costs ~0.014
pooled RMSE regardless of content) means every past "pooled RMSE moved by
X" verdict in this pipeline that added or removed a feature should be read
against that floor, not at face value — this wasn't known before tonight.
