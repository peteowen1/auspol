# Pre-registration: xgb surge parameters v2 — nested per-class selection

**Written and committed 2026-09-11, BEFORE running it.** Follows
`prereg-xgb-surge-parameters-2026-09-11.md`, whose v1 arm was **refused** on its
own primary (rms_z 3.93 → 3.00 against a bar of 2.50).

## What v1 established, and the error it exposed in its own design

v1's diagnosis was clean: the emergence hazard is learnable where a class's
emergences are spread across pairs, and not where they are concentrated.

| class | emergences | pairs | % in biggest pair | v1 model AUC | `pred_share` alone |
|---|---|---|---|---|---|
| IND | 91 | 21 | 13% | **0.872** | 0.819 |
| ONP | 64 | 7 | **59%** (sa2026) | **0.201** | **0.854** |
| OTH_RIGHT | 37 | 9 | **57%** (fed2013) | 0.546 | **0.751** |
| GRN | 22 | 10 | 36% | 0.473 | **0.643** |

**`pred_share` beats the fitted model on every class except IND.** Under
leave-one-pair-out, holding out sa2026 removes 38 of ONP's 64 emergences, so
the fold needing the prediction is the fold carrying the evidence.

**AND THE OBVIOUS v2 — "IND only, where it demonstrably works" — IS DEAD, on a
sizing check run before writing this file.** rms_z over the 201 emergence rows:

| | rms_z |
|---|---|
| IND-only, v1's treatment | 3.12 |
| **IND made PERFECTLY calibrated, other classes untouched** | **2.45** |
| the committed bar | 2.50 |

A flawless IND fix clears the bar by 0.05. **So v1's bar implicitly required
fixing ONP and OTH_RIGHT as well, and I did not check that when I set it.** I
sized the metric's MDE, per CLAUDE.md, and did not size the achievable
CEILING — the same family of error one step further on. Recorded here rather
than quietly moving the bar.

## The change

**Nested per-class selection of the hazard.** For each held-out pair `t` and
each class `c`:

1. compute class `c`'s out-of-fold AUC using **only pairs other than `t`**;
2. if that AUC ≥ **0.55**, use the xgb hazard for class `c` in pair `t`;
3. otherwise use `pred_share`'s own ranking, calibrated to the class's base
   rate on those same other pairs.

Magnitudes stay as v1 fitted them: per-class, partially pooled,
leave-one-pair-out — IND +12.9 (sd 8.9), OTH_RIGHT +9.2, ONP +7.0, GRN +5.9.

**Why this is not the rationalisation v1 refused to make.** v1's write-up said
a per-class fallback "would very likely clear the bar" and declined to apply it,
because picking it after seeing which classes failed is choosing the rule to fit
the answer. What makes it admissible now is the **nesting**: the selection never
sees the pair it is predicting. The rule is specified once, applied identically
to every class, and can select the fallback for IND too if IND's AUC drops on
some fold.

## Criterion — UNCHANGED from v1, deliberately

**PRIMARY: rms_z on the 201 emergence rows. Pass bar ≤ 2.50.** Baseline 3.93.
Clustered on pairs. MDE 0.93.

Not re-baselined and not re-scoped, even though v1's failure and the ceiling
analysis above now make it a demanding bar. Changing a criterion after a
refusal is worth almost nothing, and the one thing that makes this arm's result
meaningful is that its bar predates it.

**GUARDS, also unchanged:**

1. non-emergent minor rows (n = 7,056) stay in **[0.65, 1.25]** and ≤ 5% beyond
   z = 2. v1 landed at **0.69**, a near-miss against the floor — watch it.
2. election-wide pooled seat log loss no worse by more than **0.010**.
3. rms_z improves in ≥ 6 of the 10 pairs holding an emergence win.

## REFUSAL conditions — v1's four, plus two for the selection rule

1–4. As in v1: no broad directional lift; no buying the tail with the body
(guard 1 below 0.65); no accuracy loss beyond 0.5 points; vic2026 IND median
not above **3** (the modern-era Victorian record, looked up before scoring).

5. **The selector must not be a coin flip.** If the chosen source flips between
   xgb and `pred_share` for the same class across more than half its folds,
   the 0.55 threshold is sitting in noise and the rule is unstable — refuse,
   whatever the primary says.
6. **The fallback must not be doing all the work.** Report the primary with the
   fallback disabled (xgb hazard everywhere, i.e. v1) and with the xgb hazard
   disabled (`pred_share` everywhere). If plain `pred_share` everywhere scores
   as well as the nested rule, ship *that* instead — it is simpler, and a
   selection mechanism that adds nothing over its own fallback is complexity
   for its own sake.

## What the criterion still cannot see

Everything listed in v1 — marginals not joint behaviour, which opponent loses
the vote, the threshold defining emergence — plus one new thing: the AUC used
by the selector is itself estimated from few emergences for the thin classes
(GRN has 22), so the selection decision is noisy exactly where it matters most.
Refusal 5 is the guard against that, not a fix for it.

## Decision rule

Ship if the primary passes **and** all three guards hold **and** no refusal
fires. If refusal 6 fires in favour of plain `pred_share`, ship `pred_share`.
Report every number either way.
