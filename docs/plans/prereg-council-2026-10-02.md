# Pre-registration: council history as a model input

Registered 2026-10-02, before any rebuild with it on.

## Evidence that motivated it (against v57's error, not a test)

Mean signed primary error (actual minus predicted) for independent and minor
classes: state elections, mayor +8.94 (n 9), councillor +3.55 (n 117), stood
and lost -0.14 (n 157), none -0.10 (n 2,587); federal councillor +1.77 (n 81),
none -0.31. Positive for councillors in all five states. Pete: "a mayor should
count for more than a councillor -- probably right??? test this" (it did: +5.4,
SE 1.9).

## Arm A (`AUSPOL_XGB_COUNCIL = "1"`): xgb features

`council_mayor`, `council_elected`, `council_lost`, `council_pct` on every state
and federal row (R/council_features.R; 0 = no record), from council elections
before the target election only (scripts/build_council_history.py). Rebuild
from stage 3 against v57 (`output/snapshots/20261001-2353-a78e0ae-from1`).

## Arm B (later, registered separately): a base_pred / seat-level shift

Per the base_pred-and-xgb rule. Only if arm A leaves the targeted rows'
error largely in place.

## Criteria

1. PRIMARY (targeted): primary RMSE on rows whose class has a council record
   (mayor, councillor or stood-and-lost), all classes, rows in both runs:
   lower than v57. Reported with its SE (rows clustered on seat).
2. GUARD: seat log loss over all 22 elections, seats in both runs: per-
   election mean change not worse than +1 SE.
3. GUARD: Victoria (239 seats) not worse than +1 SE.
4. GUARD: primary RMSE over all rows not worse by more than 0.02.

RUN-TO-RUN NOISE: a retrain moved the AEF-7 ledger by ~0.005 on 2026-10-02.
So guards 2-3 are read in SE, and the targeted gain must exceed 1 SE of its
own change to count as a pass on criterion 1.

UNACCEPTABLE even if all pass: the targeted rows improve while the OTHER
classes in the same seats get worse by more than the targeted gain (the
correction would be moving votes between candidates wrongly).

## Decision

Ships if all hold and the unacceptable clause does not fire.

## RESULT, arm A, 2026-10-02 10:55: REFUSED on the Victoria guard

`output/snapshots/20261002-1042-537a9b7-from3` against v57. C1 targeted rows
(n 1,410): per-seat summed squared error -0.73 (SE 0.35), RMSE 4.954 -> 4.905
-- passes. C2 all elections +0.0004 (SE 0.0016) -- passes. C4 all rows 4.1507
-> 4.1446 -- passes. C3 Victoria +0.0072 (SE 0.0021, +3.4 SE) -- FAILS.
Ledger 0.2700 -> 0.2709. Other classes in targeted seats 3.924 -> 3.929
(unacceptable clause does not fire).

The trees absorbed only part of the effect: mayors' mean signed error +4.72
-> +3.29, councillors' +1.32 -> +1.04, stood-and-lost unchanged. Victoria has
no mayors in the data and few touched rows, so a +0.007 shift there is the
size of the retrain noise seen on 2026-10-01 (~0.005 on the ledger); whether
the guard caught harm or noise is UNKNOWN until that noise is measured.

## Arm A2 (registered 2026-10-02 13:05, before running): council features on the seed ensemble

Arm A's refusal turned on a Victoria change (+0.0072) inside the measured
refit noise (Victoria range 0.011 across seeds). Re-test the SAME features on
top of the 3-seed ensemble (`AUSPOL_XGB_ENSEMBLE=3`) if the ensemble ships, so
the comparison is ensemble-without vs ensemble-with council features, both
seed 42, rebuilt from stage 3.
Criteria as arm A, with the Victoria guard written against the noise floor:
1. targeted rows improve by more than 1 SE (as before);
2. 22-election per-election log loss not worse by more than 0.0012 (the
   single-seed range; the ensemble's own range, once measured, replaces it if
   smaller);
3. Victoria seat log loss not worse by more than the ensemble's measured
   seed range (E42 vs E7);
4. primary RMSE all rows not worse by more than 0.01.
The original arm A clause stays as written; this is a new test, not a re-read.

## RESULT, arm A2 (fixed matcher, NA where no data), 2026-10-02 14:45: PASSES -- ships in v58

The 13:45 A2 run is VOID (pre-review matcher: 28% false WA matches; zeros for
no-data seats). Rerun on the fixed features against a baseline B rebuilt with
the same code and the published switches exported (`20261002-1419-0a481f6-from3`).
A2 `20261002-1435-0a481f6-from3`:
1. targeted rows (n 1,514): RMSE 4.885 -> 4.813, per-seat summed squared error
   -1.04 (SE 0.30) -- PASS. Mayors' mean signed error +4.91 -> +3.61,
   councillors' +1.43 -> +1.09, stood-and-lost +0.17 -> +0.10.
2. 22-election log loss 0.3449 -> 0.3444 -- PASS.
3. Victoria 0.2717 -> 0.2696 (better) -- PASS.
4. primary RMSE 4.1083 -> 4.0946 (better) -- PASS.
Unacceptable clause: other classes in targeted seats 3.900 -> 3.892, does not fire.
Ledger 0.2648 -> 0.2686 (inside its seed range of ~0.004).
