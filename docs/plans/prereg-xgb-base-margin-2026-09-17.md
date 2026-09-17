# Pre-registration: train xgb on the residual to base_pred, not raw actual_share

Written 2026-09-17, **before the guard backtest is run**. Pete's idea,
mid-conversation about the NSW departed-member variance fault:
`base_pred` already carries the vast majority of `fit_xgb_primary_v6.R`'s
prediction (SHAP +16 to +22 of a typical row, `CLAUDE.md`'s "test base_pred
and xgb layer" note), but as an ordinary feature xgboost has no guarantee it
fully trusts it — `eta=0.05` shrinkage and L2 regularisation mean the
ensemble could under- or over-weight it relative to a coefficient of
exactly 1. Setting `base_pred` as the training `DMatrix`'s `base_margin`
forces every tree to boost on the residual (`actual_share - base_pred`)
from round one, a structurally different optimisation target from including
it as a plain feature.

## WHAT I ALREADY KNOW, stated before the criterion

**Dry-run already done, three variants, pooled OOF RMSE (leave-one-pair-out,
xgb.cv, all 23 pairs), because the naive full-offset version is worse, not
better:**

| variant | pooled RMSE | vs plain-feature baseline |
|---|--:|---|
| baseline: `base_pred` as an ordinary feature (shipped) | 3.8012 | — |
| `base_margin` only, `base_pred` REMOVED from features | 3.8563 | **worse, +0.0551** |
| `base_margin` AND `base_pred` KEPT as a feature | **3.7690** | **better, -0.0322** |

Pure offset-only modelling is worse than the shipped baseline — removing
`base_pred` as a feature loses the tree's ability to use its own VALUE to
size the correction (an offset is a fixed additive shift, not something a
tree can split on). Only the combined version (`AUSPOL_XGB_BASE_MARGIN=2`)
is being pre-registered here.

**On the AEF7-comparable pairs specifically** (the standing benchmark):
pooled 3.6522 → 3.6070 (-0.0452). Per pair:

| pair | baseline | base_margin+feature | delta |
|---|--:|--:|---|
| fed2022 | 3.4142 | 3.4065 | -0.0078 |
| fed2025 | 3.2548 | 3.2273 | -0.0275 |
| nsw2023 | 4.4760 | 4.5026 | **+0.0267 (worse)** |
| qld2024 | 2.8562 | 2.8462 | -0.0099 |
| **sa2026** | **4.7859** | **4.1826** | **-0.6033** |
| vic2022 | 3.8002 | 3.8724 | **+0.0722 (worse)** |
| wa2025 | 3.7557 | 3.8309 | **+0.0752 (worse)** |

sa2026 — the single pair the standing AEF gap analysis already names as our
biggest deficit contributor — moves by an order of magnitude more than any
other pair. Traced by hand (not just the aggregate): **ONP's mean primary
error there drops 4.58 → 2.58 across all 47 seats, broadly and
systematically** (Narungga 27.0→31.8 vs actual 37.5, King 20.8→26.0 vs
actual 31.0, MacKillop 21.8→25.6 vs actual 35.3 — every seat trending toward
the real statewide surge, not a couple of outliers carrying the mean). LNP
fixes one clear anomaly (Mount Gambier: old model predicted 36.9 against its
own `base_pred` of 11.3 and an actual of 12.5; new model predicts 25.3 —
still off, but not pathological).

**Non-AEF7 pairs are a genuine mixed bag**, not a uniform win: WA elections
mostly improve substantially (wa2001 -0.14, wa2005 -0.17, wa2008 -0.26,
wa2017 -0.17, wa2021 -0.80), but fed2007 (+0.19), nsw2019 (+0.16) and wa2013
(+0.25) get worse by comparable margins. The pooled -0.0322 is real but is
several large wins and several real losses netting out, not a broad
improvement everywhere.

**Named risk, mechanism understood before running further**: by party
class, IND is the one class that gets WORSE on average (mean error 2.81 →
3.17), while ONP (+2.00 improvement), LNP (+1.15), OTH_RIGHT (+0.71) all
improve. Traced to why: `screened_slopes()` (which builds `base_pred`'s
class-level swing multiplier for IND/OTH_RIGHT/GRN/ONP) gates on
`salience_screen()`'s permit signal, but the "new candidate, salience
permits" bucket uses **uniform swing (1.0) — not a fitted value at all**,
by the function's own docstring: *"there is no fitted value for 'new
candidate who fires'."* `base_pred` for a genuinely emerging independent is
a crude placeholder, unlike the well-fitted majors/ONP case. Forcing full
trust in an unreliable anchor via `base_margin` is plausibly worse than
letting the tree decide how much to trust it — which plain-feature mode
allows and `base_margin` does not.

## The change

`AUSPOL_XGB_BASE_MARGIN` in `fit_xgb_primary_v6.R` (already built, default
`"0"`): `"2"` sets `base_pred` as the training `DMatrix`'s `base_margin`
AND keeps it in `feat_cols`. (`"1"`, offset-only, already measured and
rejected above — not part of this pre-registration.)

**Scope of this pre-registration: v6 in isolation, measured by swapping
`AUSPOL_XGB_PRIMARY_OOF` to point at the base_margin-mode OOF file**, same
technique used earlier today for `seat_prev_pcv` — NOT yet threaded through
`fit_xgb_primary_v7.R` or the shipped snapshot. If this clears its bar,
integrating it into v7's arms is a separate, follow-up decision — v7 has
its own feature engineering on top and deserves its own measurement rather
than inheriting this one by assumption.

## The criterion

**This changes the training objective for every row, not a named target
set, so per `CLAUDE.md`'s scoping rule the primary is the election-wide
metric: pooled seat log loss across all 23 pairs**, full six-harness
backtest, `AUSPOL_N_SIMS=5000` exploratory, `AUSPOL_XGB_PRIMARY_OOF`
pointed at the base_margin-mode file for every harness.

**Adopt if pooled seat log loss improves by at least 0.005** — modest,
because this is a training-objective change touching every row, not a
targeted fix, and the do-no-harm bar for a general change is tighter than
for a scoped one.

**Report, not gated on a bar**: the AEF7 pooled seat log loss specifically
(does the primary-level -0.0452 on AEF7 survive to the seat level?), and
whether sa2026's One Nation improvement (the reason this looked worth a
full backtest at all) shows up as a real seat-level gain or evaporates once
simulated.

## Refusal: what makes an apparent win unacceptable

- **If IND's regression shows up as a real seat-level cost** — check IND
  win probability/log loss specifically, not just pooled. A pooled win that
  is quietly funded by worse independent-seat calls is not a clean trade;
  independents are exactly the class this codebase has struggled hardest to
  predict and can least afford to get worse at.
- **If the pooled win is carried by sa2026/wa2021 alone** and the other 21
  pairs net to roughly zero or negative — that would mean this is a fix for
  two specific elections' primary levels dressed as a general architecture
  improvement, and should be scoped/named as such rather than shipped
  as a default.
- **If nsw2023, vic2022 or wa2025 (the three AEF7 pairs that got worse at
  the primary level) show a comparable or larger seat-level cost** — the
  AEF7 pooled figure could hide one pair paying for another's gain within
  the same 7.

## What the criterion cannot see

- **Whether a class-scoped version** (base_margin for ALP/LNP/GRN/ONP,
  ordinary feature treatment for IND) beats the uniform version — a real
  possibility given the named IND mechanism, but a different arm, not run
  here. Flagged as the obvious follow-up if the uniform version's IND cost
  is large enough to matter but the rest of the win is real.
- **Whether v7's own arms (jump_pctile, candidate-level features) interact
  with base_margin differently than v6's raw features do** — untested here
  by design (see Scope above).

## Prediction, written before running

**I expect the pooled seat log loss bar to clear, driven mostly by sa2026**,
because a 0.60-point primary RMSE improvement concentrated in the ONP class
of the pair with the worst seat log loss in the whole corpus is a large
enough primary-level signal to survive simulation, even after IND's named
cost and the three AEF7 regressions are accounted for. **I expect IND's
seat-level cost to be real but small** relative to the ONP/sa2026 gain,
worth naming and worth a class-scoped follow-up, but not large enough on
its own to refuse the whole arm.

---

# RESULT, 2026-09-17: REFUSED. Bar missed, and for a different reason than predicted.

Full six-harness backtest, all 23 pairs, `AUSPOL_N_SIMS=5000`, both
conditions via the `AUSPOL_XGB_PRIMARY_OOF` swap technique, confirmed via
each harness's own log line.

**Pooled seat log loss: 0.2841 → 0.2880 (+0.0039, worse).** The bar required
an improvement of at least 0.005. Missed, and in the wrong direction.

**Refusal condition confirmed**: excluding sa2026 and wa2021 (the two large
predicted wins), the other 21 pairs go **0.2868 → 0.2928** — genuinely
worse on their own. The pooled win, where it exists, really is carried by
two pairs, exactly the shape the pre-registration's refusal conditions
existed to catch.

**My prediction about the mechanism was wrong. IND's named risk did NOT
materialize at the seat level** — log loss on seats IND actually won moved
0.9993 → 0.9705 (slightly better), accuracy 0.6528 → 0.6944. **The real cost
is ALP**, the single largest class in the corpus: seat log loss 0.2478 →
0.2606 across 1,112 seat-elections, plus real losses in qld2020 (+0.0347),
wa2001 (+0.1036), wa2013 (+0.0842), vic2022 (+0.0183). A primary-level view
correctly flagged that something would get worse; it flagged the wrong
class.

**The third named refusal condition, checked on all three named pairs, not
just the one that failed it**: of the three AEF7 pairs that regressed at
the primary level, only **vic2022 carries a comparable seat-level cost
(+0.0183)**. **nsw2023 is a small real cost too (+0.0021)** — same
direction, much smaller. **wa2025 reverses entirely and improves at the
seat level (-0.0236)** despite its primary-level regression — a primary-RMSE
regression that did not survive to a seat-level cost at all. So this
condition is mixed: one pair confirms it, one shows the same direction at
a much smaller scale, one reverses outright. A primary-level regression is
not a reliable predictor of a seat-level one in either direction here.

**A genuine silver lining, unplanned by the criterion**: both conditions
already beat AEF pooled on the 7 comparable pairs (baseline ahead by
0.0113), and base_margin widens that lead to 0.0180. Seats where we're
notably worse than AEF (>1.0 log-loss gap) narrow from 13 of 660 to 8:
Morwell, Richmond, Hughes, Higgins, Black, Parramatta, Flynn, Wakehurst,
Mount Gambier remain.

**Verdict: does not ship.** `AUSPOL_XGB_BASE_MARGIN` stays in
`fit_xgb_primary_v6.R`, default off, kept for reuse (same convention as
`AUSPOL_DEFECT_CONSERVE`). The natural next arm — scoped away from ALP, or
to just the pairs it measurably helps (sa2026/wa2021-shaped cases) — is a
real follow-up, not run here; the pre-registration's own "what the
criterion cannot see" section already named a class-scoped version as the
obvious next step, just for the wrong class.
