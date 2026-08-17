# Pre-registration: the functional form for allocating an ONP surge

Written 2026-08-17, after round 1 and **before round 2 is run**. Committed
before any result.

## What round 1 established, and what it did not

Round 1 ([../reviews/onp-allocation-sa-2026-08-17.md](../reviews/onp-allocation-sa-2026-08-17.md))
tested whether the 2022 minor-right vote, rescaled proportionally, allocates a
known statewide ONP total across seats better than a flat allocation. It does
not: MAE 9.298 against uniform's 6.306. Uniform is adopted.

But the same run reported a correlation of **0.735** between the predictor and
the truth. The predictor ranks seats well; proportional rescaling is what
failed, by turning structural zeros into predicted zeros and by multiplying a
6.6% base up by 3.4×.

**Round 2 therefore tests the link function, not the predictor.** This is a
different question from round 1 and it is being registered before it is run,
because "try a linear form instead" chosen after seeing which form failed is
precisely how a specification search launders itself into a finding.

## Candidates, fixed now

All predict per-seat ONP first preference in SA 2026, with the statewide total
taken as known and predictions rescaled so the vote-weighted statewide
prediction reproduces it.

| | Form | Mechanism it assumes |
|---|---|---|
| **A** | linear on 2022 minor-right seat share | ONP inherits an existing minor-right constituency |
| **B** | linear on 2022 LNP seat share | the surge is drawn out of the Liberal vote — statewide LNP fell 36.15 → 19.05 while ONP rose 2.63 → 22.88 |
| **C** | linear on both, together | the two channels are partly distinct |
| **D** | uniform | the incumbent, carried forward from round 1 |

B is registered on a stated mechanism, not because it has been tried. Neither B
nor C has been run at the time of writing.

## Criterion

**Leave-one-seat-out cross-validated MAE** across the 46 SA districts matched
across both elections. Refit the coefficients with each seat held out, so a
seat is never predicted by a model that saw it.

Reported alongside, not as criteria: RMSE, correlation, and the worst five
residuals.

## Decision rule, fixed now

1. Adopt the lowest LOO-CV MAE.
2. It must beat **uniform (D)** by **at least 1.0 MAE point**. If none does,
   adopt uniform and stop pursuing per-seat ONP allocation — record it as a
   negative result and publish the seat model with an explicit statement that
   One Nation's seat-level vote is not allocated.
3. If two candidates are within **0.5 points** of each other, adopt the one
   with fewer predictors.
4. **Coefficients are not transferred to Victoria.** Whatever form wins is
   re-estimated on Victorian data. SA decides the *shape*, not the numbers —
   the two states have different party systems and, more to the point, a
   different minor-right base (SA 6.6% in 2022 against Victoria's near-zero
   One Nation vote of 0.28%).

## Known limitations, stated before the run

- **SA 2026 is now contaminated for form selection.** Round 1 looked at this
  outcome. Round 2 tests a different question against it, and LOO-CV limits
  per-seat overfitting, but the choice of *which* forms to test was made by
  someone who has seen the round-1 residuals. The honest reading of a round-2
  win is "this form is worth trying in Victoria", not "this form is validated".
- **2022 SA figures are on pre-redistribution boundaries.** Uncorrected. It
  adds noise to every candidate equally, so it should not favour one, but it
  depresses all of them against uniform.
- **One election, 46 seats.** A 1.0-point bar on 46 observations is not a
  strong test. It is the test available.

## What would falsify the whole approach

If D wins, per-seat ONP allocation is not forecastable from prior-election
vote shares, and that belongs in the same file as the other three negative
results on seat-level prediction — seat type failed out of sample, region
failed, region effects correlate 0.27 between elections. A fourth would make
the pattern hard to argue with, and the seat model should then say plainly that
it cannot place a One Nation vote geographically.
