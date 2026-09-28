# Pre-registration: a per-candidate model for minor parties and independents

Written 2026-09-28, before fitting. Pete chose this over a candidate-count
split of the others bucket, and asked for every feature that can be
engineered, with the CV deciding what is useful.

## The question

The unpolled "others" bucket (IND, OTH_RIGHT, OTH, plus ONP where it is not
polled) is split among groups by the previous election's mix, and that split
is the largest statewide error found (mean 3.39 points of misallocation per
election, 22 pairs). The current seat model predicts each GROUP's total per
seat, not each candidate. This model predicts each minor or independent
CANDIDATE's first-preference share from what is known when nominations
close, and sums candidates to each group's statewide share.

## Data

`output/candidacies.csv` (18,172 rows, 30 elections), every candidate whose
class is IND, OTH_RIGHT, OTH or ONP, with votes. Target: the candidate's
share of formal first preferences in the seat.

## Features (all knowable at nominations; the fit decides which matter)

- **Candidate**: own share at the previous election in this jurisdiction
  (any seat, and this seat), number of earlier elections contested, held
  the seat, contested this seat before, ran federally in the same state
  before and their vote there.
- **Party** (normalised name key with aliases; independents are their own
  party): mean share where it ran last election, seats contested now and
  last time and the ratio, brand new, its share in this seat last time, its
  vote at the latest earlier federal election in the same state.
- **Seat**: last election's total minor/IND share and this class's share,
  number of minor/IND candidates now and in this class, total candidates.
- **Group statewide**: the class's statewide share last election, its
  candidate count now vs last time.
- **Context**: class, jurisdiction, federal or state.

## Validation

**Time-forward**: for each target election, fit only on elections dated
strictly before it (`election_dates()`), across all jurisdictions. xgboost
with `xgb.cv` early stopping inside the training set; a regularised linear
model (glmnet, same folds) reported beside it. Feature importance and a
drop-group ablation reported, not used to tune on the targets.

## Criterion

Scored on the 22 audit pairs (`output/statewide-forecast-audit-base27sepB.csv`
defines each pair's bucket classes and actuals).

1. **Primary**: per pair, mean |statewide share error| over its bucket
   classes, candidate-model sums against the current statewide class
   forecast (the audit's `forecast`). Passes if the mean change is at least
   one paired SE below zero.
2. **Secondary**: candidate-level RMSE against a naive baseline (own
   previous share if any, else the party's previous mean, else the class's
   previous seat mean).
3. Reported: how many pairs had under 3 earlier elections to train on, and
   the result without them.

**What would make a win unacceptable**: any feature built from the target
election or later (each feature's source election is asserted to precede
the target); a win carried by one pair (reported with the largest mover
removed).

If it passes, the next step is wiring it into the statewide bucket split
in both paths (backtests and live), measured by a rebuild, as a separate
pre-registered change.

## RESULT v1 and a VISIBLE ADDITION (2026-09-28; the text above is unedited)

v1 (xgboost from scratch, per-election CV folds), 21 pairs with 2+ earlier
elections (wa1996/wa2001 not fitted): mean |statewide class share error|
current 1.506 -> **1.541** (+0.035, SE 0.343): **primary FAILS**. Candidate
RMSE xgb 5.055 vs naive 5.289. The naive baseline's sums: **1.115** (-0.391,
SE 0.216, t -1.81, better in 14 of 21). Signed bias by class (forecast
minus actual): xgb IND -0.61, OTH_RIGHT +1.01; naive IND +0.04, OTH_RIGHT
+0.03.

Added AFTER seeing v1, so motivated by its result and weaker evidence than a
pre-registered win: **v2 = xgboost fitted as a correction on the naive
prediction** (`base_margin = naive`), the architecture every other model in
this repo uses; CV changed to 5 folds grouped by election (runtime). Same
criterion. The naive sum is reported beside it as the fallback. Whichever is
carried forward, the deciding measurement is the rebuild when it is wired in.

## RESULT v2 (2026-09-28)

`AUSPOL_MC_ARM=resid`, 5 grouped folds: candidate RMSE xgb **4.948** vs
naive 5.289. Mean |statewide class share error| over 21 pairs: current
1.506 -> **1.171** (-0.335, paired SE 0.214, t -1.56): **PASSES** the
criterion as added after v1. Largest mover removed (sa2022): -0.242, SE
0.203, passes. The naive sums remain slightly better on the group total
(1.115). Next: wire the bucket split to candidate sums in both paths, v2
and naive as two arms, a rebuild deciding (separate pre-registration).
Runtime 5 minutes (was 9); not instrumented per stage.
