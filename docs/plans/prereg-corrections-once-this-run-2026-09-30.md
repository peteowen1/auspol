# Pre-registration: post-xgb corrections applied once, learned from this run (correctness fix)

Written 2026-09-30 11:05, before the rebuild. A CORRECTNESS fix: ships
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
