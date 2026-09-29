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

## RESULT (added 2026-09-28 after running; everything above is unedited)

Audit `-cp1` against `-base27sepB`, same code. 21 of 22 pairs had a fitted
OTH series (`CP1` lines; fitted sums 94.75 to 102.94); wa2005 had none and
is byte-identical (the out-of-scope check holds).

1. **Primary: FAILS.** Mean |bucket size error| 2.010 -> 2.005, change
   -0.005, paired SE 0.357 (t -0.02). Largest mover removed (wa2001):
   -0.230, SE 0.291, also fails. It fixes 12 pairs (fed2019 -2.37, sa2022
   -1.99, qld2024 -1.66, nsw2023 -1.64, wa2017 -1.56) and badly worsens
   others (wa2001 +4.72, fed2022 +3.13, fed2016 +2.45, wa2025 +0.94).
2. Do no harm: PASS. Mean |miss| ALP/LNP/GRN 1.758 -> 1.813 (+0.055, SE
   0.084). Majors' bias nearly gone: ALP -0.76 -> -0.30, LNP -0.68 -> -0.11.

**The hypothesis that the remainder rule causes the +2 others bias is
refuted as a general explanation**: the polls' own fitted OTH is sometimes
further from the result than the remainder was. Verdict: stays OFF; the
rebuild (criterion 3) is not reached. The live level-parity question goes
back to Pete with this result.
