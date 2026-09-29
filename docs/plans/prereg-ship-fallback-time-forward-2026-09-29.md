# Pre-registration: the minor-party slope fallback learns only from earlier elections

Written 2026-09-29, before running. A LEAK FIX: ships whatever it does to the
score.

## The defect

`fit_conditional_slopes()` (`R/split_slope.R`) starts every minor class's
same/new slope at hardcoded constants (`SHIP_SAME` IND 0.907, OTH_RIGHT
0.891, GRN 0.994, ONP 0.610; `SHIP_NEW` IND 0.326, OTH_RIGHT 0.325, GRN
0.880, ONP 0.545) and keeps them for any cell with fewer than `min_n` = 40
rows, and for every class when no rows exist at all. Those constants were
fitted on every election, so an early election, and the ONP returning-
candidate cell in 4 of the 7 ledger elections (31-38 rows: fed2022,
nsw2023, qld2024, vic2022), gets a slope learned partly from later elections.

## The change (`AUSPOL_SHIP_TIME_FORWARD=1`, the new default)

The fallback for a thin cell is the tier's POOLED slope (all minor classes'
rows for that tier, same or new) from the same earlier-elections rows; if
the pooled tier itself has fewer than `min_n` rows, 1. The hardcoded
constants are no longer used. `0` restores them, for comparison only.
`fit_dispersion_slopes()` carries its own copy of `SHIP_SAME` but is off in
the shipped configuration (`AUSPOL_DISPERSION_SLOPE=0`); noted, not changed.

## Checks

Print which cells fall back and to what, per target. Rebuild against v46:
ledger (0.2822) and all 16 elections (0.2987) reported per election; the
number is logged whatever it is.

## RESULT (rebuild K vs v46, 2026-09-29; the text above is unedited)

Ledger seat log loss 0.2822 -> 0.2840 (+0.0018, SE by seat 0.0019, t 0.93;
by election 0.0042); all 16 elections 0.2987 -> 0.3012 (per-election mean
+0.0035, SE 0.0020, better in 6); weighted primary RMSE 4.947 -> 4.986; TCP
MAE 3.90. Per ledger election: sa2026 -0.011, qld2024 -0.007, vic2022
-0.004, fed2022 -0.003, nsw2023 +0.003, fed2025 +0.011, wa2025 +0.021.
The honest cost of removing the constants' hindsight. **Ships as ledger v47**
(a leak fix, as pre-registered); still ahead of AEF (0.2851).
