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

## RESULTS (added after running; everything above is unedited)

**Statewide audit (2026-09-28)**, mean |miss| ALP/LNP/GRN over 22 pairs
(first-preference points, lower is better): A 1.758; L 1.776 (+0.018, SE
0.140, better in 10 of 22); P 1.813 (+0.055, SE 0.084). Majors' signed miss:
A ALP -0.76 / LNP -0.68; L +0.02 / -0.43; P -0.30 / -0.11. P's audit is
worse than L's, so by the rule P is not rebuilt.

**Rebuild L** (09:20-09:48, `AUSPOL_LEVEL_RECIPE=live`, local only; every
stage-1 harness log carries `LR1` for all 22 pairs; outputs saved in
`output/rebuild-L/`): seat log loss **0.2966** vs AEF 0.2851 (n = 660);
weighted primary RMSE 5.236; TCP MAE 3.99. Against the published v42
(0.2943 / 5.15) it is worse on both, but v42 was built on 20 Sep code, so
the deciding comparison is rebuild A on today's code (queued behind a
pannaverse job sharing the machine's memory).

**Rebuild A** (12:37-13:01, default flags, same code as L; no `LR1` lines):
seat log loss **0.2951**, weighted primary RMSE 5.198, TCP MAE 4.05. Paired
over 660 seats, L minus A = +0.0015 (SE by seat 0.0073, t 0.21; by election,
7 clusters, SE 0.0139). Per election L minus A: fed2022 -0.004, fed2025
+0.044, nsw2023 -0.075, qld2024 -0.005, sa2026 +0.003, vic2022 +0.016,
wa2025 +0.015.

**Decision by the rule: A (anchored) has the lowest seat log loss and ships,
inside noise, as the rule allows.** Its primary RMSE is also lower. Live
`fit_seats_full.R` now runs it (`AUSPOL_LIVE_LEVEL_ANCHOR=1`): local run
ALP 30.83 expected seats (models retrained by rebuild A at 12:49; CI uses the
v42 shipped models). P is not rebuilt (its audit was worse than L's).
