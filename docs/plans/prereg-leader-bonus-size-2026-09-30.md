# Pre-registration: apply the leader-seat bonus at the size it was estimated

Written 2026-09-30, before any run with the fix.

## The defect

`leader_seat_apply()` added the bonus to the leader's class and then rescaled
the WHOLE row back to its total, the leader's cell included. The leader keeps
`b * (tot - s) / (tot + b)`: a Labor leader on 45 given +2.45 gained +1.32.
The bonus is estimated from as-at predictions that carry no bonus, so the
estimate is the full-size gap; half of it was being handed back.

Measured on v54's shipped backtests (all 22 pairs, `xgb_primary_on == 1`):
the leader's actual minus our prediction, less the party's median miss that
election, is still **+1.72 points** (n 52, SE 0.77); premiers and prime
ministers +2.36 (n 22, SE 0.81), opposition leaders +1.48 (n 22, SE 1.16),
minor-party leaders +0.57 (n 8, SE 3.39).

## The fix

`.shift_cell()`: the leader's cell moves by exactly the bonus, the other
classes give it up in proportion. Also used by `departed_fed_apply()`
(`AUSPOL_DEPARTED_FED`, off), which had the same shape.

## Measurement

Rebuild from stage 6 on top of v54 (`output/` restored from
`20260930-1607-33a848a-from1`). Only leader seats can move.

1. **Primary, targeted**: the leader residual above, all 52 seats, must fall
   toward zero: |mean| smaller than v54's 1.72.
2. **Do-no-harm**: published ledger seat log loss (660 seats) not worse by
   more than 0.001, and pooled seat log loss over every seat not worse by more
   than one SE clustered on pair.

This is a correctness fix (the bonus is applied at the size it was
estimated). It ships unless criterion 2 fails; if it fails, that says the
bonus estimate itself is too big, and that is the thing to fix next, not
the halving.

Unacceptable-win clause: if the ledger improves but the leader residual does
not move, the fix did not reach the published numbers and the gain is from
something else.

## Result, 2026-09-30 18:20: PASSES, ships

Rebuild from stage 6, `output/snapshots/20260930-1807-3c1a1db-from6`, against
v54 `20260930-1607-33a848a-from1`.

Leader residual (actual minus published prediction, less the party's median
miss; points, 0 = sized right):

| role | n | v54 | full-size bonus |
|---|---|---|---|
| premier / PM | 22 | +2.36 (SE 0.81) | +1.01 (SE 0.87) |
| opposition leader | 22 | +1.48 (SE 1.16) | +0.59 (SE 1.28) |
| minor-party leader | 8 | +0.57 (SE 3.39) | -2.53 (SE 3.77) |
| all | 52 | **+1.72 (SE 0.77)** | **+0.29 (SE 0.86)** |

Do-no-harm (lower is better): published ledger seat log loss 0.2757 ->
0.2761 (+0.0004, inside the 0.001 allowance; AEF 0.2851); all 1,593 seats
0.3469 -> 0.3462 (-0.0006, SE 0.0007 clustered on pair); accuracy 88.94%
both. 77 seats moved by more than 0.001, mostly by under 0.01. Biggest
gains: Fairfax 2013 (Palmer) 9.21 -> 8.52, Kennedy 2013 3.35 -> 3.02,
Kennedy 2016 0.33 -> 0.12. Biggest losses are leaders who LOST their own
seats: Dickson 2025 (Dutton) 1.79 -> 2.02, Melbourne 2025 (Bandt) 2.46 ->
2.60. That is the price of any leader bonus, and the reason the minor-party
row now reads -2.53: Bandt 2025 and Robbie Katter 2024 on n = 8.

Early WA pairs (2001-2013) and fed2007/2010 get no bonus at all (n 0): the
as-at predictions start at fed2010, so there are fewer than three earlier
leader seats to learn from. That is time-forward, not a defect.
