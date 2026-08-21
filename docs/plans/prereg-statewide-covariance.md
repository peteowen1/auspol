# Pre-registration: when one party outperforms, whose votes did it take?

Written 2026-08-21, **before anything is fitted or changed**. Committed before
running.

## The defect

`simulate_seat_contests()` draws each party's statewide deviation
**independently**:

```r
shift <- stats::rnorm(K, 0, sd_vec)
```

So a simulation where One Nation runs five points above its central forecast is
equally likely to pair with a strong Coalition as a weak one. That is not how
votes work: they come from somewhere.

`fit_seats_full.R` is no better. It draws each party independently, renormalises
proportionally — which takes the excess evenly from Labor, the Greens and the
Coalition alike — then re-anchors only the **Labor-versus-Coalition** split. The
code comment above that step shows the covariance problem was already found and
fixed *for the two majors*. The same problem for every other party is
unhandled.

**South Australia, March 2026, says who pays.** One Nation +20.24 points came
with Liberal **−17.12**, Labor only −2.48, and the Greens actually **rose**
+1.27. A point of One Nation cost the Coalition 0.85 and Labor 0.12.

## Why it biases in a knowable direction

One Nation's winnable seats are the ones where it fights the Coalition. Under
independent draws, its good simulations are not systematically the Coalition's
bad ones, so it crosses the winning line less often than it should.

**The expected effect is therefore to RAISE One Nation's upside.** That is
stated now because it is exactly what must not be used as evidence later.

## THE POWER CALCULATION, AND THE CHOICE OF CRITERION

A covariance change moves the **joint** distribution of seats far more than the
**marginal** probability of any single seat. Scoring it on per-seat log score —
the criterion every previous test here used — would mostly miss it.

So the criterion is the **seat TOTAL**: for each election and party, the actual
number of seats won is one draw from the predicted seat-count distribution.
Scored by the log score of that actual total under the predicted distribution,
summed across parties, clustered on the election.

Ten elections, **9 degrees of freedom** — the same design that detected +2.85 SE
in `prereg-calibration.md`, so it can see effects of the size this repo argues
about.

Reported alongside, not as criteria: per-seat log score, and 90% coverage of the
seat total.

## Arms

- **A — status quo.** Independent statewide deviations.
- **B — empirical covariance.** The covariance of statewide first-preference
  CHANGES across the ten election pairs the corpus holds, estimated
  leave-one-election-out and shrunk toward the diagonal, with the shrinkage
  weight fixed at 0.5 in advance rather than tuned.
- **C — single-factor, South Australian.** One Nation's deviation drives the
  others through the measured SA response; every party keeps independent
  residual noise.

**B is preferred if the two are close**, because it is estimated from ten
elections and C rests on one.

## Decision rule, fixed now

- **Adopt whichever of B or C beats A by more than 2 SE** on the clustered
  seat-total log score, preferring B on a tie or where they are within 1 SE.
- **If neither beats A by 2 SE, keep A** and report that the covariance is real
  but not worth its complexity at this sample size.
- **If the per-seat log score degrades by more than 1 SE, refuse regardless.**
  A change that improves seat totals by making individual seats worse is
  trading the thing the pendulum is for.

## Refusals — what disqualifies an apparent win

- **V1 — One Nation rising is NOT evidence.** The predicted direction is stated
  above. If the case for adoption rests on the One Nation seat range widening or
  its median rising, that is the hypothesis restating itself, not a result.
- **V2 — MOVING TOWARD YOUGOV IS NOT EVIDENCE, AND IS A HAZARD.** This change is
  expected to close part of the gap with an external forecast we currently
  disagree with. That must play no part in the decision. If the criterion fails
  and the change is adopted anyway because it "looks more like YouGov", that is
  fitting to a competitor rather than to data. Stated here because the
  temptation is foreseeable and specific.
- **V3 — the One Nation column of any covariance rests on one election.** Nine
  of the ten pairs have One Nation near zero and unmoving; only SA 2026 informs
  its covariance with anything. Arm B's ten-election pedigree is real for the
  majors and largely illusory for One Nation, and a write-up that claims
  otherwise is wrong.
- **V4 — the live forecast.** If any party's Victoria 2026 seat median moves by
  more than **2**, stop and report rather than ship. A covariance change should
  move the SHAPE of the distribution; a moved centre means something else
  happened.
- **V5 — the two-party anchoring must not be double-counted.**
  `fit_seats_full.R` already corrects the Labor-versus-Coalition covariance
  downstream. If a covariance is imposed upstream and the anchor then corrects
  it again, the two-party spread will be wrong in a way neither step owns.
  Report the statewide two-party sd before and after; if it moves by more than
  0.2 points, the interaction is real and must be resolved before adoption.

## What this cannot see

- **Whether the SA response transfers to Victoria.** One Nation took Liberal
  votes in a state where the Liberals had just governed for a term in
  opposition's shadow; Victoria's Coalition is in a different position.
- **Non-linearity.** Both arms impose a single linear response. If One Nation's
  first ten points come from the Coalition and its next ten from Labor, neither
  arm can express it and the sweep in
  `docs/reviews/` built on it will be wrong in the tail.
- **Anything about the seat-level allocation**, whose shape is fitted on SA 2026
  and remains untestable until Victoria votes.
