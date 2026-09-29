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

## RESULT (2026-09-29, rebuild M = v49; the text above is unedited)

**No-go: not worth building.** Time-forward exponent, 16 elections (1,590
seats; 3 floor seats excluded): per-election mean log-loss change -0.0020,
SE 0.0038 (t -0.53), better in 6 of 16. Far short of the 2 SE bar.

The model is no longer over-confident. The exponent fitted on all seats is
0.942 (August: 0.30-0.35), and the time-forward fits drift from 0.77 to 0.93
as elections accumulate. Reliability, favourite's stated probability against
its actual win rate: 0.5-0.6 band 0.548/0.485 (n 103), 0.6-0.7 0.652/0.610
(100), 0.7-0.8 0.749/0.764 (182), 0.8-0.9 0.855/0.834 (205), 0.9-0.95
0.927/0.926 (176), 0.95-0.99 0.976/0.974 (458), 0.99+ 0.994/0.992 (364).
Only the 0.5-0.7 bands run a few points hot.

Post hoc, NOT a finding: flattening helps all four WA elections it applied to
(-0.005 to -0.031) and hurts fed2016/19/22/25 and vic2014/18/22. A
WA-specific over-confidence is a hypothesis for a separately registered
test, not a reason to revisit this one. Ship C (August) is closed: the
over-confidence it fixed was cured by the model changes since.
