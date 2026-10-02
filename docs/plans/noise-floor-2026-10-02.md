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

## RESULT, 2026-10-02 12:00

| metric | seed 42 (v57) | seed 7 | seed 99 | range |
|---|---|---|---|---|
| AEF-7 ledger log loss | 0.2700 | 0.2694 | 0.2659 | 0.0041 |
| 22-election per-election log loss | 0.3422 | 0.3434 | 0.3428 | 0.0012 |
| Victoria seat log loss | 0.2723 | 0.2764 | 0.2833 | 0.0110 |
| primary RMSE, all rows | 4.1507 | 4.1819 | 4.1551 | 0.031 |
| primary RMSE, Victoria | 4.4720 | 4.5115 | 4.4768 | 0.040 |

Snapshots: seed 7 `20261002-1114-bfc14ff-from3`, seed 99 `20261002-1156-22a1f1a-from3`
(a first seed-99 run reused seed 7's cached as-at models -- the cache key
omitted the seed; fixed in 22a1f1a and rerun).

Reading: an equally valid refit moves Victoria's seat log loss by up to 0.011
and primary RMSE by ~0.03. Guards that use an SE over seats treat the model as
fixed and understate this ~5x (council arm A's Victoria "+3.4 SE" was +0.0072,
inside the seed range). The 22-election mean is stable (range 0.0012).

5,000 vs 20,000 simulations (same models, `20261002-1138-bfc14ff-from6`):
stage 6 359 s vs 456-658 s; seat win probabilities differ by 0.0017 on average
(max 0.021); but 22-election log loss +0.0045 because rare winners hit the 1e-6
floor more often. Not used for log-loss decisions.

Consequence for every pending result: a Victoria-only or ledger-only
difference smaller than the seed range is not evidence. Proposed fix: average
the xgb layer over several seeds (an ensemble) so the noise falls by ~sqrt(k).
