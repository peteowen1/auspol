# Prereg: night per-booth best guess (lane F), 28 Nov 2026 (election day)

Written before any arm ran, about 7:30am. Pete's design (28 Nov, 7am): "we need a best guess for every booth that
updates with all information, then we can sum up the booths".

## Why

Mildura, vic2022. The live projection gives every uncounted booth the SAME swing per class (the vote-weighted swing of
the counted booths of its type). At 8pm the 17 counted booths swung in opposite directions: the Mallee booths about 15
to 32 points away from the Coalition, the big Mildura town booths (Irymple, Mildura West, Cardross) about 8 points to
it. Pooled, that is roughly zero, applied to uncounted booths that are mostly town booths and to the early vote (16,077
votes in 2018, 40% of the seat), which swung like the towns (Coalition 37.0 to 43.8). A scratch run on the saved 8pm and
9pm Mildura data (`booth_guess.R` in the session scratchpad) cut the vote-weighted booth error on the Coalition share
from 6.5 to 4.9 points at 8pm and 4.1 to 2.7 at 9pm. A1 (one straight-line slope on the booth's own 2018 share) is a
cruder form of the same idea and failed again on top of A3 + D2 this morning (pooled +0.0012, SE 0.0018; fed2025 worse
by 2.1 SE).

## The change

`project_seat_from_booths(booth_knn = list(h, k, size_w, types))`, `NULL` (default) byte-identical. Each uncounted
ORDINARY booth with a reference gets its own swing per class:

```
sw_b(c) = base(c) + sum_j w_bj * (y_j(c) - base(c)) / (sum_j w_bj + k)
w_bj    = (votes_j / median booth) * exp(-d_bj^2 / (2 h^2))
d_bj^2  = sum over reference classes of (100 * (ref share_b - ref share_j))^2 + (size_w * (log ref votes_b - log ref votes_j))^2
```

`j` runs over the counted ordinary booths with a reference, `y_j(c)` is booth j's own swing, `base(c)` the current
ordinary swing (unchanged rule). So a booth with no similar counted booth keeps today's swing (partial pooling, no
cliff). With `types = TRUE`, an uncounted early / postal / absent / other unit whose type has NO counted unit takes,
instead of the all-types counted swing, the swing of ALL the seat's ordinary booths (counted: own swing; uncounted:
the guess above), weighted by their reference votes, plus the existing type gap. A counted type keeps its own swing.

Fixed in advance, no sweep: **h = 10 points, k = 1 median booth, size_w = 10, types = TRUE**. Cannot be combined
with A1 (`booth_reg_k`). Flag `--booth-knn=10,1,10,1` (h,k,size_w,types).

## Screen (fixed before running)

`screen.sh` (2,000 draws, snapshots to 9pm, vic2022 + fed2022 + fed2025, live flags A3 + D2), arms against `a3d2`:

- `bk`: `--booth-knn=10,1,10,1` (as above)
- `bko`: `--booth-knn=10,1,10,0` (ordinary booths only; the early vote keeps today's rule), reported to separate the parts

Scored by `score_screen_a3d2.R`. **Primary:** seat-winner log loss over (seat, snapshot) cells under 15% counted,
pooled over the three nights, SE clustered on seat. **Pass** (the `bk` arm decides) = all of:

1. primary better (arm minus base below zero) by more than 1 SE;
2. no night's average log loss (all snapshots run) worse by more than 1 SE;
3. wrong 0.99 calls (leader 0.99+, 10%+ counted, lost) not more than base, summed over nights;
4. seats right at the last snapshot not fewer than base, summed over nights.

**Named target, reported not decisive:** Mildura vic2022 at 7, 8 and 9pm (Cupper's win chance).

**Unacceptable even if it passes:** a pass that comes from Mildura alone (leave Mildura out: primary must still be
below zero), or from a night whose booths are mostly unmatched to a reference (check the arm changed cells on every
night). A pass here is a screen pass only: full 20,000-draw replays to 2am on all three nights before shipping, with
the same four clauses on the full run. Cutoff: Pete's 1pm; anything not passed by then stays off.

## RESULT (28 Nov 2026, 7:40am; screen, 2,000 draws, code 970bf419): FAIL, stays off

Seat-winner log loss, arm minus base `a3d2` (below zero is better; SE clustered on seat). Primary = cells under 15%
counted (1,382 cells, 389 seats); per night = all snapshots run (vic2022 352 cells, fed2022 1,057, fed2025 900).

| arm | primary | vic2022 | fed2022 | fed2025 | wrong 0.99 calls (base 2) | seats right (base 374) | verdict |
|---|---|---|---|---|---|---|---|
| `bk` (deciding) | -0.0004 (0.0005) | +0.0009 (0.0019) | -0.0014 (0.0010) | +0.0014 (0.0023) | 2 | 376 | **FAIL clause 1** (0.8 SE, needs > 1) |
| `bko` (reported) | -0.0004 (0.0003) | -0.0011 (0.0012) | -0.0012 (0.0007) | +0.0002 (0.0013) | 2 | 376 | (not deciding) |

Mildura (Cupper's win chance, she lost): a3d2 0.95 / 0.94 / 0.45 at 7 / 8 / 9pm; `bk` 0.95 / 0.90 / 0.49; `bko` 0.95 /
0.92 / 0.44. Seat-level traces on the saved Mildura data: the guess moves the uncounted town booths the right way
(Coalition swing +1.8 to about +6.4 at 8pm against finals of +6 to +13), but the early vote (40% of the seat, no
similar counted unit) only moves from +1.8 to +2.6 against a final +6.8, and that block decides the seat. Nothing is
worse by more than 1 SE and both arms gain 2 seats right at 9pm, so the effect is real but too small to clear the bar.
Stays OFF (`--booth-knn` absent). Pete told in conversation, 28 Nov.

## Amendment 1 (28 Nov 2026, about 8:15am): Pete's override, visible, original clauses unedited

Shown both arms and Mildura, Pete chose "Both": B1c (PR #294) and `bko` (polling booths only, `--booth-knn=10,1,10,0`) ON
for tonight, although `bk` was the arm named to decide and it failed clause 1. This is his override, not a pass.
Joint screen of B1c + `bko` against `a3d2` (2,000 draws, to 9pm, code 4cb9de21): primary -0.0010 (SE 0.0008); nights
vic2022 -0.0066 (0.0063), fed2022 -0.0014 (0.0008), fed2025 -0.0001 (0.0013); wrong 0.99 calls 2 = 2; seats right
376 vs 374 base. B1c alone was -0.0006 (0.0007). Mildura (Cupper, lost) 7 / 8 / 9pm: 0.85 / 0.86 / 0.29 (a3d2 0.95 /
0.94 / 0.45). Full 20,000-draw replays to 2am follow, before the ship.
