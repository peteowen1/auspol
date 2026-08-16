# Pre-registration v2: estimating the sum-to-zero prior

Written 2026-08-16, **before** the grid is run. Committed before any result is
seen. Supersedes the v1 attempt recorded in
[../reviews/szc-prior-2026-08-16.md](../reviews/szc-prior-2026-08-16.md),
which was reverted because its mechanism check (SZ2) was mis-specified.

## Why v1 is not simply resumed

v1 changed `szc_sd_pts` to a value picked by judgement from a measurement,
then judged it on four checks. Three passed, one failed, and the failing one
turned out to be watching the wrong quantity. The held-out error — which did
improve, 2.0850 to 2.0588 — was **not** a pre-registered criterion, so
adopting the change on it afterwards would be choosing the criterion to fit
the answer.

## What is different this time

**Stop picking the value at all.** `szc_sd_pts` becomes an estimated
hyperparameter, chosen the same way every other one in this model already is:
by held-out error. `sigma_obs`, `sigma_rw`, the per-cycle sigmas, the
trend/fundamentals mix weight and the ridge penalty are all set this way. This
one was the odd exception.

That also satisfies the standing rule: it will move as new elections arrive,
rather than being correct once.

## The criterion, fixed now

**Primary: held-out mean absolute error from the projection backtest**
(`projection_loo`, leave-one-election-out, ~195 election-horizon pairs). The
same criterion, on the same data, already used to choose the mix weight.

**Grid:** `szc_sd_pts` in {0.3, 0.75, 1.5, 3.0}. Spans the incumbent value and
the measured industry drift of ~1.5 (docs/CONSTANTS.md §6). Chosen now, not
after seeing results.

## Decision rule, fixed now

1. Compute held-out MAE at each grid value.
2. **The incumbent 0.3 wins ties and near-ties.** Adopt a different value only
   if it beats 0.3 by **more than 0.02 MAE** — roughly 1% of the current
   2.085. Below that the difference is not worth changing a published number
   for, and is within what four grid points of noise can produce.
3. Any value adopted must **pass every existing pre-registered check** — V1–V5,
   A1–A4, N1–N3, L1–L4, H1–H4, P1–P4, B1–B3, S1–S4, R1–R3, C1–C3, F1, O1, G1–G3.
   A value that lowers held-out error while breaking a validation bound is
   rejected: those bounds were written against actual election results and are
   the stronger evidence.
4. **Interval coverage (B2/B3) must still pass.** A prior that improves point
   accuracy while making the published intervals dishonest is not an
   improvement.
5. If two values are within 0.02 of each other and both qualify, take the
   **smaller** — less freedom for the industry mean to absorb signal.

## What is NOT a criterion

Not the size of individual house effects. That was v1's error: `szc`
constrains their weighted mean, and the mean is now confirmed to respond
correctly (0.13 → 3.17 across the grid) while individual effects move for
other reasons.

Not the agreement between the chosen value and the 1.5 measured from industry
drift. If the data picks 0.3, the measurement was measuring something the
model does not need, and that is the finding.

## Expected failure mode

The grid may be flat, since the two-party figure moved only 0.21 points
between 0.3 and 1.5. If so, rule 2 keeps 0.3 and this is recorded as "the
prior does not matter enough to estimate", which is a perfectly good answer
and closes the question.
