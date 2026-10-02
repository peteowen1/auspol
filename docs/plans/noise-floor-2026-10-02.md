# Noise floor: how much does an equally valid refit move the metrics?

Registered 2026-10-02 before running. Pete chose this before arm B.

Why: two v57 rebuilds differing by one seat (Narracan) moved the AEF-7
like-for-like log loss by 0.0044, and council arm A failed its Victoria guard
by +0.0072 -- both the size of most tested effects. The xgb seeds are fixed
(42), so identical inputs reproduce exactly; the instability is the trees'
sensitivity to small input changes. Varying the seed gives equally valid fits
and sizes that sensitivity directly.

Runs: v57 config unchanged, `AUSPOL_XGB_SEED` and `AUSPOL_SEED` (simulation)
set to 7 and to 99, rebuilt from stage 3 (stages 1-2 are deterministic and
seed-free at stage 1's point estimate). Compared with the v57 snapshot
(`output/snapshots/20261001-2353-a78e0ae-from1`, seed 42) and with each other.

Reported: AEF-7 ledger log loss; 22-election per-election log loss; Victoria
seat log loss; primary RMSE (all rows; Victoria); for each, the spread across
the three seeds. A change smaller than ~2x that spread is not distinguishable
from refit noise. Arm A stays refused unless a NEW, registered test using this
floor says otherwise.
