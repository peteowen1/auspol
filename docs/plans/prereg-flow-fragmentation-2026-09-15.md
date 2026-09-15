# Pre-registration: the leading candidate's primary share as a flow feature

Written 2026-09-15, **before the arm is fitted**. Follows
`docs/reviews/flow-fragmentation-2026-09-15.md`.

## The claim being tested

`scripts/fit_xgb_flows_v1.R` predicts what share of an excluded candidate's
votes lands on each surviving class. Its features describe the SOURCE and
DESTINATION classes -- `from_primary`, `to_primary`, class dummies -- and the
count's state (`n_survivors`, `cond_rate`, `pool_rate`). **Nothing describes
the shape of the seat as a whole.**

The review measured that the seat's shape moves flows, and that closeness does
not:

| model, 872 observations | slope on 2CP margin | t |
|---|--:|--:|
| margin alone | +0.357 | +3.56 |
| margin + leader's primary | **+0.003** | **+0.02** |
| leader's primary, same model | **+0.508** | **+3.69** |

## WHAT I ALREADY KNOW, stated before the criterion

- Flow to ALP as a share of the two majors runs **38.4% where the leader polls
  under 35%** and **48.2% where the leader polls 50%+**, across 3,031
  early-round observations.
- That gap is **not** the leading party: LNP leads 1,488 observations at mean
  safety 48.6 and ALP 1,429 at 47.7, and controlling for the leader's party
  leaves the slope at +0.183 against +0.181 uncontrolled.
- It is **not** closeness: the two-candidate margin's slope collapses from
  +0.357 to +0.003 once the leader's primary share is in the model.
- Every number above is **in-sample across the whole corpus** and from a linear
  fit. None of it is evidence that a gradient-boosted tree already carrying
  `from_primary`, `to_primary` and class dummies gains anything.

## The change

One feature, `lead_primary` -- the maximum first-preference share in the seat,
computed from `output/candidacies.csv`, known before any preference moves and
available for every seat whether or not its count ran to completion.

**One feature and no more.** An effective-number-of-candidates term and a
`n_candidates` count are both plausible and both unregistered; adding either
after seeing this result would be choosing the model from the answer. If
`lead_primary` fails, those are a separate plan.

## The criterion

**Primary: out-of-fold row-level RMSE from `xgb.cv` with leave-one-election-out
folds**, which `fit_xgb_flows_v1.R` already computes and prints, against the
same shipped-equivalent baseline it already compares to
(`0.85 * base_rate + 0.15 * (1/n_survivors)`).

Primary rather than seat log loss because of power. The flow model has
thousands of event-rows and its own held-out metric; pooled seat log loss has
22 pairs and an MDE around 0.003, which this session has already watched refuse
a real effect twice. `CLAUDE.md` is explicit that a targeted change is
validated on its target.

**Adopt if out-of-fold RMSE improves against the arm without the feature**,
both fitted in the same run with the same folds and seed.

**Confirming, and it must not worsen: pooled seat log loss across all 22
pairs.** A flow feature that helps flow RMSE and hurts seats is not an
improvement; the seat number is what ships.

## Refusal: what makes an apparent win unacceptable

- **If pooled seat log loss worsens at all.** The flow model exists to serve
  the seat forecast.
- **If the gain needs a second feature.** Registered as one feature; a result
  that only appears with `n_candidates` alongside is a different arm.
- **If `lead_primary` does not appear in the top ten features by gain.** A
  measured effect of t = 3.69 that the tree then ignores means the existing
  features already carry it, and the honest conclusion is "already captured",
  not "small but positive".
- **If the improvement is confined to one region.** The effect was measured
  pooled across six jurisdictions; a gain appearing only in, say, WA would be a
  regional artefact rather than the mechanism claimed.
- **A directional side effect:** if any class's mean predicted flow share moves
  by more than 2 points, investigate before adopting -- that is a re-levelling
  of the flow matrix, not a refinement.

## What the criterion cannot see

- **Victoria 2026.** Flow rates reaching the live forecast come from this
  model, so the change does reach it -- but no Victorian number is computed
  here and vic2026 is not in the backtest.
- **Whether fragmentation is a proxy for something else.** A fragmented field
  plausibly means a different KIND of minor candidate, whose voters differ.
  The feature would capture that without explaining it.
- **Exhausted votes.** Still unparsed, still estimated from polls; a flow model
  fitted on non-exhausting jurisdictions and applied to NSW carries that error
  regardless of this feature.

## Prediction, written before running

**Out-of-fold RMSE improves by 0.5% to 2% relative**, and `lead_primary` lands
in the top ten features by gain but not the top three -- `cond_rate` and
`pool_rate` are the historical rates and should stay dominant.

**Pooled seat log loss moves by less than 0.001 in either direction**, because
the flow half of the model is downstream of the primary prediction and most
seats are not decided by preferences. If seat log loss moves more than that in
either direction I will look for a bug before believing it.

**The most likely failure is the fourth refusal condition**: the tree already
has `from_primary`, `to_primary` and `n_survivors`, and may be reconstructing
the seat's shape from them well enough that an explicit term adds nothing.
