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

## RESULT (added 2026-09-27 after running; everything above is unedited)

Audit `output/statewide-forecast-audit-ae1.csv` against `-base27sep.csv`,
same code, `AUSPOL_ANCHOR_EXHAUST=1` only.

1. **Guard: PASS.** 130 of 130 non-NSW cells identical.
2. **Primary: FAILS on the pre-registered unacceptable condition.** The four
   ALP/LNP cells' mean |miss| falls 2.197 -> 1.883, but the two pairs move
   in opposite directions: nsw2023 mean |miss| ALP/LNP/GRN 2.257 -> 1.317
   (ALP -4.83 -> -3.35, LNP +1.41 -> -0.07), nsw2019 1.027 -> 1.547
   (ALP -0.51 -> +0.78, LNP -2.04 -> -3.33). The fix moves ~1.3 points of
   first preference from the Coalition to Labor in both, as predicted.

Why nsw2019 worsens: its Coalition was already 2.04 low before the fix,
because the unpolled classes are over-forecast (IND 7.61 vs 4.77 actual,
OTH_RIGHT 5.68 vs 4.99). The exhaustion bug was partly offsetting that. In
nsw2023 the unpolled classes miss the other way round (OTH_RIGHT +4.30,
IND -2.35).

Verdict: arm stays OFF, per the rule. The units defect is real and remains
in the code behind the flag. It cannot ship on its own while the unpolled
classes' statewide level is wrong, because that error is what it was
offsetting in 2019. Next: how unpolled classes get their statewide level in
`forecast_statewide_for()` (the columns it replaces for folded classes).

## RE-TEST on ledger v44 (added 2026-09-28 BEFORE running; above unedited)

Motivated by v44: nsw2019's worsening was attributed to the over-forecast
unpolled classes, which the candidate bucket split (`cand_naive`) now
changes. Same guard and primary criterion as above (non-NSW cells identical;
ALP and LNP improve on average over nsw2019+nsw2023 and neither pair's mean
|miss| ALP/LNP/GRN rises), both arms run with `AUSPOL_BUCKET_SPLIT=cand_naive`.

RE-TEST RESULT: identical to the first test (guard PASS; nsw2023 2.257 ->
1.317, nsw2019 1.027 -> 1.547). The premise was wrong: the candidate split
moves only the division of the unpolled bucket, never ALP/LNP, so nsw2019's
Coalition shortfall (-2.04) is a LEVEL error the split cannot touch. Stays OFF.
