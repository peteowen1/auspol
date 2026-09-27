# Pre-registration: the anchoring's implied two-party must be net of exhausted ballots

Written 2026-09-27, before running. Follows the anchor-implied arm
(`prereg-anchor-implied-tpp-2026-09-20.md`, criterion 1 not met).

## The defect

`derive_tpp()` (`R/tpp.R:51-64`) computes the published two-party series on
the NON-EXHAUSTED total: `100 * (ALP + sum w*live*fp) / (majors + sum
live*fp)`, `live = 1 - exhaust/100`. That is the official NSW count under
optional preferential voting, and the fundamentals and eventual results are
on the same basis. The anchoring in `statewide_draws_as_at()`
(`R/forecast_mode.R`, `implied <- ALP + sum fp * flow`) ignores exhaustion,
so for NSW it compares a full-preferential quantity with an OPV target and
moves Labor/Coalition by the difference.

Evidence: the implied-minus-published gap by pair (audit 2026-09-27) is
largest for exactly the two NSW pairs, +1.58 (nsw2019) and +1.42 (nsw2023).
NSW flows carry exhaust GRN 39.7, ONP 60-71, OTH ~61; every other
jurisdiction's flows carry exhaust 0.

## The change

Compute `implied` with `derive_tpp()`'s formula (flows' `exhaust`), and
convert the needed two-party move into a first-preference move exactly:
shifting ALP by `+x` and LNP by `-x` leaves the non-exhausted denominator
unchanged, so `x = (target - implied) * denom / 100`. The realised
`implied_tpp` returned is computed the same way. Behind
`AUSPOL_ANCHOR_EXHAUST` (default 0 until measured).

Scope: only pairs whose flows carry non-zero exhaust (nsw2019, nsw2023).
**Live Victoria is unaffected by construction (exhaust 0)**; the live copy of
the anchoring in `fit_seats_full.R` gets the same formula so the two paths
stay one recipe.

## Prediction

nsw2019 and nsw2023 Labor first preferences rise by roughly 1 point and the
Coalition falls by the same; every non-NSW pair is byte-identical.

## Criterion, in order

1. **Guard, must hold exactly**: every non-NSW row of the statewide audit is
   identical between arms. Any difference means the change leaked outside
   its scope and the arm is void until explained.
2. **Primary (targets)**: over nsw2019 + nsw2023, the ALP and LNP statewide
   |miss| (4 cells) falls on average, and neither pair's mean |miss| over
   ALP/LNP/GRN rises. With two pairs there is no SE to speak of; the
   direction must hold in both, stated as such.
3. **Seat smokes**: `smoke_pair.sh nsw 2019` and `nsw 2023`, class RMSE for
   ALP and LNP each does not rise.
4. **Rebuild decides the ledger** (seat log loss not above v42's 0.2943),
   batched with whatever else is ready, since the change touches one of
   seven ledger elections.

**What would make a win unacceptable**: an improvement in one NSW pair paired
with a worsening in the other (a units fix should move both the same way),
or any movement outside NSW.
