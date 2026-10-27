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

## RESULT, screen on Pete's two pairs (2026-10-26 00:43-00:48; appended, nothing above edited)

`quick_arm.R "AUSPOL_GRN_TREE_SHRINK=1" --pairs=fed2025,qld2024 --no-reuse --slots=1`, 1,000 sims, code t181ee5f.
Baseline cache 050d4221173d, arm cache 0c9be42fa4d1. Log `deciding-runs/quickarm-20261026-grn-tree-shrink-2pairs.log`;
scorer `score_grn.R` (session e7e809d4 scratchpad). Lower is better throughout; SE clustered on election (only 2).

- 1. Primary, Greens squared error on the 110 changed Greens cells (more than 0.05 points): -0.2989 (SE 0.4598),
  within 1 SE. fed2025 -0.0013 (85 cells, RMSE 2.296 unchanged); qld2024 -1.3105 (25 cells, RMSE 3.563 -> 3.375).
- 2. Guard, seat log loss over 243 seats: -0.0015 (SE 0.0018), within 1 SE. fed2025 -0.0001, qld2024 -0.0038.
- 3. Neither election is worse by 2 SE. Without the two largest-gain seats (South Brisbane, Griffith fed2025) the guard
  is +0.0001, so the sign is lost.
- 4. Named seats, Greens share from base to arm (actual): Melbourne fed2025 47.56 -> 47.36 (39.46), Griffith fed2025
  35.53 -> 35.02 (31.65), South Brisbane qld2024 43.46 -> 42.48 (34.71); p(actual winner) for South Brisbane goes
  0.040 -> 0.056. Northcote vic2022 and Griffith fed2022 are reported from the all-pairs run.
Reading: in the right direction everywhere, but small. Most of the move is qld2024. Not worse, so `--pairs=all`
followed (launched 00:59).

## RESULT, all elections (2026-10-26 00:59-01:29; appended)

`quick_arm.R "AUSPOL_GRN_TREE_SHRINK=1" --pairs=all --no-reuse --slots=1`, 1,000 sims, code t181ee5f. Baseline
050d4221173d, arm 0c9be42fa4d1. Log `deciding-runs/quickarm-20261026-grn-tree-shrink-all.log`, score `...-all-score.txt`.
Greens cells moved by more than 0.05 points: 511, in 19 of 35 elections. Limiting case: the 16 elections with nothing
earlier to fit on score exactly 0.

| clause (lower is better; SE clustered on election) | n | change | SE | result |
|---|--:|--:|--:|---|
| 1 primary: Greens squared error on changed cells | 511 cells / 19 el. | -0.1247 | 0.1133 | better by >1 SE (1.10 SE): PASS |
| 2 guard: seat log loss, every seat | 2,921 seats / 35 el. | -0.0000 | 0.0002 | PASS |
| (quick_arm Q3 / AEF-7) | 2,931 / 681 | -0.0000 / -0.0002 | 0.0002 / 0.0006 | |
| 3a leave-one-election-out | 19 drops | sign kept in 19 of 19; >1 SE in 15 of 19 | | weakest without qld2024 (0.66 SE), vic2022 (0.76), vic2018 (0.78), nsw2019 (0.94) |
| 3b no election worse on log loss by >2 own SE | | vic2022 +0.0019 (own SE 0.0007, z 2.54) | | **FAIL** |
| 3c without the two largest-gain seats (South Brisbane qld2024, Melbourne vic2022) | | primary -0.0639 | 0.0871 | sign kept |
| unacceptable win: gain only in fed2025 + qld2024 | 401 cells / 17 el. | -0.0770 | 0.1165 | does not fire (no reversal) |

Per election, the primary gains in qld2024 -1.31, sa2018 -1.11, vic2018 -0.82, vic2022 -0.81, wa2021 -0.63 and loses in
nt2020 +0.96, qld2020 +0.70, qld2017 +0.34. Named seats, Greens share base -> arm (actual): Melbourne fed2025 47.56 ->
47.36 (39.46); Griffith fed2025 35.53 -> 35.02 (31.65); South Brisbane qld2024 43.46 -> 42.48 (34.71), p(winner)
0.040 -> 0.056; Northcote vic2022 37.38 -> 37.45 (30.01), p 0.143 -> 0.139; Griffith fed2022 (the under-call) 26.82 ->
26.72 (34.59), p 0.106 -> 0.101, worse as predicted.

**Verdict: the headline primary PASSES, but clause 3 refuses it.** vic2022 seat log loss is worse by 2.5 of its own
SE, and in 4 of 19 drops the leave-one-out falls under 1 SE (the sign holds in all of them). Under rule 9 the split goes
to Pete; no deciding run without his call. The size is small: about 0.12 points^2 per changed cell, and seat log loss
is unchanged.

## DECISION (2026-10-26; appended)

Pete asked for the cause before deciding. Traced (`docs/reviews/greens-overcall-shap-trace-2026-10-26.md`): in the three
tree-driven over-calls the trees' incumbency features (own previous vote, same MP, elected before, incumbent party) add
+6 to +7 points. The shrink damps every Greens seat to catch these few. Clustered on election, the strong-seat Greens MP
overshoot is +1.90 (SE 1.84, 21 cells, 12 elections, 7 over), and no other party shows one. **Left OFF (not shipped);
no Greens-only incumbency fix built** on that evidence. Recommended by Claude and accepted by Pete ("go", 26 Oct).
