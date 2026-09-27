# Pre-registration: close the statewide total proportionally, not with an OTH remainder

Written 2026-09-28, before running. Pete chose this over shipping the
level-parity fix as-is (DECISIONS 2026-09-28).

## The defect

The trend fits each party separately, so its endpoints need not sum to 100
(Victoria 2026-09-28: 97.93). `statewide_draws_as_at()` closes the total by
setting OTH to the remainder (`mu[["OTH"]] <- 100 - sum(the rest)`), so the
whole shortfall lands in the unpolled "others" bucket. Audit 2026-09-27: the
bucket is too big in 17 of 22 elections, mean forecast minus actual +1.05,
mean |size error| 2.01. The remainder rule is the likely source: a
2-point shortfall in the fitted sum becomes 2 points of others.

## The change

`AUSPOL_CLOSE_PROPORTIONAL=1`: when OTH has its own fitted series, keep it
and rescale every fitted class (and any series folded into a class) by
`100 / sum`, the same normalisation `derive_tpp()` applies to produce the
published two-party series. When OTH has no fitted series the remainder rule
stays (there is nothing else to close with). Unpolled folded classes keep
mean 0 as now.

Both paths: `R/forecast_mode.R` (backtests) and `fit_seats_full.R` LL1
(live, used when `AUSPOL_LIVE_LEVEL_ANCHOR=1`).

## Prediction

Bucket size error falls in most pairs (mean forecast-minus-actual moves
from +1.05 toward 0); majors and Greens each gain a share of the ~2 points;
live Victoria's others total goes 12.65 (remainder) -> ~10.8.

## Criterion, in order

1. **Primary (the target)**: statewide audit, 22 pairs: mean |bucket size
   error| falls by at least one paired SE.
2. **Do no harm**: mean |miss| over ALP/LNP/GRN does not rise by more than
   one paired SE.
3. **Rebuild v44 decides the ledger**: seat log loss not above v42's 0.2943.
   If it passes, v44 ships with `AUSPOL_LIVE_LEVEL_ANCHOR=1` so live runs
   the recipe the ledger scored.

**What would make a win unacceptable**: the primary passing only because of
one pair (reported with the largest mover removed); any pair where OTH had
no fitted series changing at all (the rule must not touch them).
