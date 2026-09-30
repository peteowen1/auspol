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
