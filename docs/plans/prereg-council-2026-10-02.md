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
