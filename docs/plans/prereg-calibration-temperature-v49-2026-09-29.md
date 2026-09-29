# Pre-registration: does a calibration temperature still help, on v49?

Written 2026-09-29, before running. Retest of Ship C
(`reviews/calibration-2026-08-21.md`: +2.85 SE, temperature 0.30–0.35), which
was measured on the 21 August model (pooled log score 0.56 against v49's
~0.28), before the candidate model, the xgb as-at pipeline and five leak
fixes. It was never shipped, because a per-seat rescale disagrees with the
simulated seat-count histogram (its K5).

## What this measures, and what it does not

This is a **go / no-go on building it**, not a ship. It rescales published
per-seat win probabilities after the fact; shipping would need the rescale
inside the simulation so that the seat totals agree (K5 route 2).

## The rescale

For each seat, `p_i' = p_i^a / sum_j p_j^a` over the parties the model lists
(a < 1 flattens, a > 1 sharpens; argmax and accuracy are unchanged). `a` for
target T is fitted by maximum likelihood on the seats of elections dated
before T only (`elections_before`), with at least 3 elections, else a = 1.
Probabilities are clamped at 1e-6 before the power, as in every score here.

Source: rebuild M (v49) `forecasts-seats.csv` (16 elections) and the ledger's
`our_p_win` plus the per-party probabilities in the same file for the 7
ledger elections.

## Decision rule

- **Primary:** seat log loss over the 16 elections in `forecasts-seats.csv`,
  paired by seat, SE clustered by election. **Worth building if** it improves
  by more than 2 SE.
- **Guard:** no ledger election worse by more than 0.01.
- **Reported:** the fitted `a` per target (stability: K2's bar was a factor
  of 2 across folds), reliability by band before and after.
- **Unacceptable even if it passes:** an improvement carried by the floor
  seats alone (the three WA seats whose winner the model never listed can
  only move if their p is not exactly 0; they are excluded from the fit and
  reported separately).
