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
