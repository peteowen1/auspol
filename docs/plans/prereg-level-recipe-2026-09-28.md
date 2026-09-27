# Pre-registration: which statewide-level recipe performs best (live vs backtest)

Written 2026-09-28, before running. Pete: *"Test live on back test? Let's
just use the method that seems to perform best."*

## The three recipes

| name | level the seats get | switches |
|---|---|---|
| **A anchored** (v42 ledger, backtests today) | OTH = remainder, anchored to the projection (trend mixed with LOO fundamentals) | defaults |
| **L live** (what production publishes today) | trend endpoints rescaled to 100, NOT anchored | `AUSPOL_LEVEL_RECIPE=live` |
| **P anchored + proportional** | endpoints rescaled to 100, THEN anchored | `AUSPOL_CLOSE_PROPORTIONAL=1` |

## Measurement

1. **Statewide audit** (22 pairs, minutes): mean |miss| over ALP/LNP/GRN,
   and over every class, per recipe; paired SEs against A.
2. **Rebuild** (`rebuild_forecasts.sh`, the ledger): A is v42 (0.2943). L is
   rebuilt. P is rebuilt only if its audit mean |miss| ALP/LNP/GRN is not
   worse than L's.

## Decision rule

Ship the recipe with the lowest pooled ledger seat log loss (lower is
better), in BOTH paths so live runs what the ledger scored. If the best
beats A by less than one paired SE, it still ships (Pete asked for the best
performer, not a significance test), and the margin is reported with its SE.
Primary RMSE is reported beside it; if the log-loss winner is worse on
weighted primary RMSE by more than one SE, that goes to Pete before shipping.

**What would make a result unacceptable**: the recipes differing in anything
but the level (each run prints `LR1`/`CP1` so the arm is visible), or a
rebuild that reused stale as-at models trained under another recipe.
