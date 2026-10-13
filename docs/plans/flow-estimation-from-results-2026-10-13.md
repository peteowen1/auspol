# Preference flows estimated from results (2026-10-13, Pete's decision)

Pete, 2026-10-13: where no distribution of preferences exists, estimate an election's flows **from its own
results** rather than borrow another election's. Needed for NSW 2003/2007, Vic 2002, Qld 2001-2015, SA 2010/2014
(no published distributions; `reviews/coverage-results-inventory-2026-10-13.md`, `reviews/distributions-*`). It also
replaces an AE dependency: today's statewide flows come from AE's hand-made `preference-estimates.csv`
(`load_preference_flows()`, `R/load_polls.R:188`).

## What is estimated

Per election, per minor-party class k (GRN, ONP, OTH, IND, ...): `a_k` = share of k's first preferences that end
with Labor, `e_k` = share that exhaust (optional preferential: NSW always, Qld before 2016), and `1 - a_k - e_k` to
the Coalition. The same shape `load_preference_flows()` returns (`flow_alp`, `exhaust`, percent).

## The data each seat gives

In every seat whose final two candidates are Labor and the Coalition, with first preferences F_ALP, F_LNP, F_k and
final counts T_ALP, T_LNP:

    T_ALP - F_ALP = sum_k a_k F_k
    (sum_k F_k) - (T_ALP - F_ALP) - (T_LNP - F_LNP) = sum_k e_k F_k        (votes that reached neither)

Worked example (illustrative numbers, not a real seat): Labor 40,000, Coalition 38,000, Greens 10,000, others
6,000 first preferences; final count Labor 51,500, Coalition 42,000. Labor gained 11,500 and the Coalition 4,000
from 16,000 minor votes, so 500 exhausted. One seat cannot say whether the Greens or the others supplied Labor's
11,500; across 50-90 seats with different Greens/others mixes it can, which is the regression below.

## Estimator

Constrained least squares over seats (0 <= a_k, e_k and a_k + e_k <= 1), each seat's equations weighted by its
minor-party votes, **partially pooled** toward a prior (CLAUDE.md "shrinkage, never a min_n cliff"): the prior is
the nearest earlier election in the same state with a published distribution, else federal flows for the same
year; the pooling weight comes from how precisely the seats pin each a_k down (its standard error from the fit,
bootstrap over seats). A class present in few seats shrinks almost entirely to the prior, which is the point.

Seats with a minor party in the final two, and seats decided on first preferences where the count was not taken
to two (NSW 2011: 11 seats stopped at a majority), are left out of the equations and counted in the log.

## Validation before use (the estimator is a measuring instrument)

Elections WITH published distributions are the answer key: estimate their flows from first preferences and
final counts alone, then compare with the flows the distributions actually show.
- Test set: fed 2004-2025, NSW 2011/2015/2019/2023 (optional preferential), Vic 2006-2022, Qld 2017-2024, SA 2018-2026.
- Report per election and class: estimated vs actual `a_k` and `e_k`, absolute error, and whether the actual lies
  inside the bootstrap interval (coverage near 90% for a 90% interval).
- Dry-run first on two elections whose flows are well known (fed2022 Greens ~86% to Labor; NSW 2023 exhaust).
- Pass bar, set before running: mean absolute error on Greens and One Nation flows under 5 points, and no worse
  than borrowing the nearest earlier election's flows (the alternative Pete did not choose). If it fails, report
  and stop; do not tune on the test set.

## Then

Estimated flows enter as a new file (`output/flows-estimated.csv`) read only for elections without a published
distribution, flagged per row, and the move-off-AE audit counts AE's `preference-estimates.csv` as a dependency
until every election reads ours.
