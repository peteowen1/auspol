# Pre-registration: pull the trees' Greens share back toward base as the Greens base grows (2026-10-24)

Pete, 2026-10-24: *"Greens over-called in high-Greens seats (Melbourne, Griffith, South Brisbane). Pull the tree's
Greens share back toward base_pred as the Greens base gets larger. Screen it with quick_arm.R on fed2025 and qld2024."*
The in-sample check (`docs/reviews/greens-overcall-investigation-2026-10-24.md`) predicted about no gain; Pete chose the
same day to build and screen it anyway.

Written before any run.

## The arm

Greens cells only, after the trees and before the row is renormalised:
`x' = base + w (xgb - base)`, `w = 1 / (1 + lambda * base)`. `lambda = 0` is exactly today.

`lambda` is fitted by least squares on the Greens rows of `output/forecasts.csv` (as-at tree predictions) from elections
strictly before the target, then shrunk toward 0 by `G / (G + 3)`, G the number of those elections
(`AUSPOL_GRN_TREE_SHRINK_K`). Dry run of the fit (stub date order, scratch script), shrunk lambda and the weight `w`
given to the tree correction at a Greens base of 40:

| target | elections before | lambda | w at base 40 |
|---|--:|--:|--:|
| fed2016 | 11 | 0.0000 | 1.00 (no change) |
| fed2025 | 28 | 0.0139 | 0.64 |
| qld2024 | 26 | 0.0113 | 0.69 |
| vic2026 (live) | 30 | 0.0189 | 0.57 |

This fit is stronger than the investigation's grid (which picked no change or k = 200) because it is scored against the
tree output, where the shrink is applied, not against the final published share. Recorded here so the difference is not
discovered later.

Switch `AUSPOL_GRN_TREE_SHRINK`: `0` (shipped, off), `1` (fitted). Added to `post_xgb_switches()`, so the as-at trees
never train on it. Wired into `xgb_primary_override()` (all harnesses) and `xgb_primary_predict_live()` (published).

## Arms

| arm | setting | differs from baseline on |
|---|---|---|
| baseline | `AUSPOL_GRN_TREE_SHRINK=0` | - |
| G1 | `AUSPOL_GRN_TREE_SHRINK=1` | that switch only |

Limiting case: an election with no earlier Greens rows gets lambda 0 and must score exactly 0 in quick_arm.

## Criterion

Screen: `scripts/quick_arm.R "AUSPOL_GRN_TREE_SHRINK=1" --pairs=fed2025,qld2024` (Pete's two), then `--pairs=all`.

1. **Primary:** squared Greens share error on the changed cells, better by more than 1 SE clustered on election.
2. **Guard:** seat log loss (minus log of the probability given to the actual winner; lower is better) over every
   seat of every scored election, not worse by more than 1 SE.
3. Leave-one-election-out on the primary; no election worse on seat log loss by more than 2 SE of its own seat
   differences; sign survives dropping the two largest-gain seats.
4. Report the named seats: Melbourne fed2025, Griffith fed2025, South Brisbane qld2024, Northcote vic2022, and Griffith
   fed2022 (the under-call, which this arm makes worse).

**Unacceptable win:** a gain carried by fed2025 and qld2024 alone that reverses on the other elections. Two elections
cannot clear an arm; they can only stop one.
