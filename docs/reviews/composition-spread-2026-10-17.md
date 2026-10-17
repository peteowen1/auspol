# Seat-composition spread: screen result and what it shows (2026-10-17)

Prereg: `plans/prereg-composition-spread-2026-10-17.md`. Arm C = `AUSPOL_COMPOSITION_SD=1` (code 1d0b733).
Screen: `deciding-runs/20261017-1225-composition-screen-1k/` (1,000 sims, all 35 elections, slots 1), scored by
`scripts/score_composition_spread.R`, codes CQ0-CQ9 (dry-run first on the Lib/Nat deciding run: reproduced its all-seat guard,
-0.0049 SE 0.0031 on 2,081 seats). Full output in that folder's `prereg-score.txt`.

## Screen (seat log loss, lower is better; C minus shipped A; SE clustered on election; floor 5e-4)

| Scope | Seats | A | C | C - A (SE) |
|---|---|---|---|---|
| PRIMARY: widened 1.10+ | 213 in 29 el | 0.5546 | 0.5242 | **-0.0304 (0.0157)** |
| GUARD: every seat | 2,931 in 35 | 0.3124 | 0.3103 | -0.0021 (0.0013) |
| IND predicted 15+ | 217 | 0.7243 | 0.6941 | -0.0302 (0.0159) |
| AEF-7, all seats | 681 | 0.2662 | 0.2654 | -0.0008 (0.0024) |
| primary NSW | 37 | 0.1953 | 0.2363 | **+0.0410 (0.0164)** |
| primary NT / QLD / VIC | 31 / 33 / 17 | | | -0.079 / -0.080 / -0.077 |
| favourites A 0.90+ who won | 1,772 | | | +0.0023 (0.0005), summed +4.1 |

Clauses: largest single-election share of the gain 0.34 (passes); floor seats supply none of it (passes);
favourites worse by >1 SE (reported). Victorian split seats: Shepparton winner 0.063 -> 0.150, Mildura
0.145 -> 0.218, Morwell 0.083 -> 0.091.

## Why NSW and the favourites pay (shipped model, `published-predictions.csv`; z = error / sim sd)

| Cells | n | RMS z | robust sd (1.4826 median abs z) | beyond 4 sd |
|---|---|---|---|---|
| the IND's own share, IND 10+ seats | 358 | 2.06 | **2.15** | 5.0% |
| other classes, IND 10+ seats | 1,469 | 1.26 | **0.96** | 1.5% |
| other classes, every other seat | 10,945 | 1.05 | 0.81 | 0.57% (bell curve: 0.006%) |

- The independent's own share is about **twice too narrow and bell-shaped**: a real sd error.
- The majors in those seats are right in a typical seat (0.96) and **heavy-tailed**. C widens them too, which
  taxes clear calls (NSW: long-held independent seats, 0.183 log loss before) and safe favourites.
- **Heavy tails are everywhere**, not just in independent seats: 0.57% of all cells miss by 4+ sds, ~100x a
  bell curve.
- Not incumbency: sitting independents (80 seats) are as over-confident as challengers (278): ratio 1.37 vs
  1.49, log loss 0.639 vs 0.550.
