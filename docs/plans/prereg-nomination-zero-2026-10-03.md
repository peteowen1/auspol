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

## RESULT, 2026-10-03 00:45: FAILS guards 2 and 3 (primary passes)
`output/snapshots/20261003-0035-a33fb31-from6` against v60.
1. PRIMARY: final primary RMSE over the 1,313 affected seats 3.984 -> 3.833
   (ALP bias -0.10 -> +0.61, LNP -0.82 -> -0.08, IND +0.45 -> -0.13): PASS.
2. 22-election log loss 0.3434 -> 0.3454: FAIL (+0.0020, at the limit).
3. nsw2019 +0.0356 (FAIL, limit 0.011); vic2018 +0.0103; 12 of the other 20
   improve slightly.
Unacceptable clause: 0 zeroed cells where the class stood -- does not fire.
Cause: Barwon nsw2019 (Butler, SFF, won from ~5%) 9.903 -> 13.816, onto the
1e-6 floor -- without it nsw2019 improves ~0.006; and Richmond vic2018, where
the Liberals' phantom 10.8 was spread proportionally, mostly to Labor (lost)
rather than the Greens (won). Proportional redistribution of the freed share
is the untested design choice. Not shipped.

## AMENDMENT: mode 2, freed share by preference flows (registered before running)
Pete's choice, 2026-10-03, after the result above. `AUSPOL_NOM_ZERO = "2"`:
the same zeroing, but each freed share goes where that class's voters go --
the harness's own flow matrix (time-forward, already built for the count):
the survivor-conditional cell for the seat's actual field, else the class's
pooled flows, else proportional. Same criteria 1-3 and unacceptable clause,
against v60. Flagged: Liberal preferences in inner Melbourne have often
favoured Labor over the Greens, so flows may NOT fix Richmond 2018; and Barwon
(a floor seat) may still decide guard 3.

## RESULT, mode 2, 2026-10-03 01:20: PASSES -> v61
`output/snapshots/20261003-0115-ca788a4-from6` against v60.
1. PRIMARY: final primary RMSE over 1,313 affected seats 3.984 -> 3.774. PASS.
2. 22-election log loss 0.3434 -> 0.3413. PASS.
3. Worst single election wa2017 +0.0025 (limit 0.011); best wa2001 -0.0305,
   nsw2019 -0.0145. PASS.
Unacceptable clause: 0 zeroed cells where the class stood.
Victoria 0.2654 -> 0.2649; ledger 0.2686 -> 0.2677. Flow source per zeroed
cell: conditional on the seat's field almost everywhere, pooled otherwise,
never proportional. Seats: Barwon nsw2019 9.903 -> 9.210, Richmond vic2018
0.642 -> 0.569, Narracan vic2022 0.026 -> 0.005, Churchlands wa2008 0.104 ->
0.006, Alfred Cove wa2001 5.860 -> 4.160.
LIVE: fit_seats_full.R does not call it; Victoria 2026 nominations close in
November, so the live forecast has nothing to zero until then. Wiring it into
the live path is a follow-up before nominations close.
