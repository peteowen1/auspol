# Pre-registration: state-deviation correction applied once, learned from this run (correctness fix)

Written 2026-09-30 16:05, before the rebuild. Ships whatever it scores.

## The defect (in published v53)

A full rebuild did not reproduce itself (v53 full restore: ledger 0.2712 vs
0.2722). Traced: only the FEDERAL stage-1 file differed, fed2010-2025 (5,632
of 7,357 rows, up to 0.38 points), fed2007 not at all. Cause: the
state-deviation correction (`AUSPOL_STATE_DEV=1`, federal only)

1. ran in stage 1 as well as stage 6, so it entered `base_pred` (the xgb
   input) and was applied again on top: the v53 double-counting bug, missed
   there because this correction predates it;
2. learned from `xgb-primary-v6-oof-predictions.csv`, written at stage 3, so
   stage 1 read the PREVIOUS rebuild's file;
3. that file is leave-one-out, so earlier elections' residuals came from
   models trained partly on later elections.

## The change

xgb layer only (stage 6), learning from this run's stage-4 as-at predictions
(`current_seat_predictions()`, time-forward) via `.sd_training()`.

## Checks

- Hard: after the rebuild, rerunning the federal stage-1 harness gives a
  byte-identical file (no dependence on a previous run).
- Reported against v53 (the full restore, `output/rebuild-V53full/`): pooled
  seat log loss, primary RMSE, ledger, per federal election.
