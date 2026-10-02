# Pre-registration: zero every class with no candidate (`AUSPOL_NOM_ZERO = "1"`)

Registered 2026-10-03 before any harness run with it on.

## Why
The AEF-7 ledger's largest miss: Narracan 2022 forecast Labor 33.4; Labor did
not contest the supplementary election. The harnesses zeroed only independents
with no nominee, and did so BEFORE the xgb override, which writes its own
prediction back wherever its feature rows (built from an earlier nomination
list) have the class. v59 sharedetail, all 22 elections: 2,125 cells above
0.5% for a class with no candidate (Churchlands wa2008 LNP 33.3, Alfred Cove
wa2001 ALP 28.4, Armadale wa2001 LNP 25.9, Callide qld2020 ONP 13.5).
Nominations are public before polling day: no leakage.

## Change
R/nomination_zero.R `zero_unnominated()`, called after the override in all six
harnesses (federal: after the state correction too). A class is zeroed in a
seat only if the target result table has the seat and uses the class anywhere.

## Criteria (rebuild from stage 6 against v60, all 22 elections)
1. PRIMARY: final primary RMSE over the seats where any cell was zeroed
   improves (any amount: a correctness fix, the direction is the test).
2. GUARD: 22-election log loss not worse by more than 0.0020.
3. GUARD: no single election's seat log loss worse by more than 0.011.
UNACCEPTABLE: it zeroes a class that DID stand (any such cell is a bug, found
by checking every zeroed cell with actual share > 0).
Not touching the live forecast in this change: Victoria 2026 nominations close
in November; fit_seats_full.R's handling is checked separately.
