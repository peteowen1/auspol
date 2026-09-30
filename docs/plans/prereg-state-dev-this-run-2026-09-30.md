# Pre-registration: state-deviation correction applied once, learned from this run (correctness fix)

Written 2026-09-30 15:45, before the rebuild. Ships whatever it scores.

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

## RESULT (full rebuild SD, 15:45-16:07) = v54

Hard check held: rerunning the federal stage-1 harness afterwards gave a
byte-identical file. Against the v53 full restore: pooled seat log loss
0.3412 -> 0.3469 (per election +0.0034, SE 0.0043); primary RMSE 4.1852 ->
4.2018; AEF-7 ledger 0.2712 -> 0.2757; accuracy 88.5% -> 88.9%. Ships as
pre-registered (correctness fix).

About half the log-loss rise is one seat at the floor: fed2010 Lyne, whose
winner (Rob Oakeshott, IND, 47.8%) we give ~8.5% in BOTH versions; v53's
simulation happened to land him ~1 win in 10,000, this one 0 in 20,000, and
the floor (1e-6) turns that into +0.09 on fed2010. Not caused by this fix.
The real defect: the by-election prior is SKIPPED when a major did not stand
(Lyne 2008: Labor did not stand), so a by-election winner's vote is ignored;
Victoria 2026's Prahran (2025 by-election, Labor did not stand, Liberal gain
from the Greens) is in the same class. Queued, to design with Pete.
