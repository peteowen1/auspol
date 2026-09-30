# Pre-registration: post-xgb corrections applied once, learned from this run (correctness fix)

Written 2026-09-30 10:53, before the rebuild. A CORRECTNESS fix: ships
whatever it scores, as the leak fixes did.

## The two defects (both in published v52)

1. **Counted twice.** The demographic correction (`AUSPOL_DEMO_RESID=2`) and
   the leader-seat bonus (`AUSPOL_LEADER_SEAT=1`) ran in rebuild stage 1 as
   well as stage 6. Stage 1's shares become `base_pred`, the xgb training
   input and base margin, so both corrections were baked into the xgb layer and
   then applied again on top. The seat-swing port and the seat-poll blend were
   already gated to the xgb layer for exactly this reason; the two v52
   additions were not. Confirmed from the v52 stage-1 logs (`LS1`, `DR1` lines
   in `s1_*.log`).
2. **Learned from the previous rebuild.** All three post-xgb corrections (seat-
   poll blend, demographic, leader seat) read `output/forecasts.csv`, written
   at stage 7, so stage 6 learned from the previous rebuild's predictions. The
   vic2026 leader bonus read 2.33 or 1.05 depending on which rebuild ran
   before. They now read this run's stage-4 as-at predictions
   (`current_seat_predictions()`), identical to the forecasts table within a
   run (11,643 of 11,643 rows, max difference 6e-14).

## Measurement

Full rebuild (v53 candidate) against published v52 (`output/rebuild-V52/`):
pooled seat log loss, primary RMSE, AEF-7 ledger, leader seats, reported per
election. Ships regardless; the numbers are recorded, not a gate. One check
that must hold: stage-1 logs carry no `LS1` or `DR1  demographic` lines.

## RESULT (rebuild-V53, 10:53-11:20; stage-6 files in output/rebuild-V53/sharedetail/) = v53

Stage-1 check held: 0 `LS1` / `DR1` lines in `s1_*.log`. Against published
v52: pooled seat log loss 0.3419 -> 0.3409 (-0.0017, SE 0.0017, better in 9
of 16); primary RMSE 4.1698 -> 4.1771 (+0.061 MSE, SE 0.039); AEF-7 ledger
0.2717 -> 0.2722; accuracy 88.6% -> 88.9%; leader seats mean abs error 4.69
-> 5.00 (the doubled bonus had helped there: leaders out-poll us by more than
one bonus). Against v51 every measure is better (log loss 0.3434 -> 0.3409,
RMSE 4.2065 -> 4.1771, ledger 0.2753 -> 0.2722). Like for like against AEF
(same 654 seats, four classes): weighted primary error 4.90 vs 5.63.
Ships as v53. Follow-up worth a look: the leader bonus may be too small.
