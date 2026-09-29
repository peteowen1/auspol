# Pre-registration: remove the actual national swing from the state-poll feature, and add 2025

Written 2026-09-28, before running. A LEAK FIX: it ships whatever it does to
the score, and becomes the new honest baseline.

## The defect

`scripts/build_state_deviation_features.R` builds `state_poll_dev` as
`(state poll two-party - state's previous result) - natl_swing`, and
`natl_swing` is the ACTUAL national swing at the election being predicted
(`tpp-fed-regions.csv`, `state == "all"`, e.g. `2022,fed,all,52.13,3.66`).
So the feature equals the legitimate state-vs-nation poll difference PLUS
the national polling error of that election, which is known only after the
count and is shared by every seat. The federal backtests (and the ledger's
fed2022 and fed2025) have been reading it. Second defect: the anchor's state
breakdowns stop at 2022, so every fed2025 state read 0 with `state_poll_n = 0`.

## The change

1. The national reference becomes the national POLLS: the federal trend's
   two-party the day before the election (`trend_as_at()`, the same call the
   statewide forecast makes), minus the previous election's actual national
   two-party. Each value is asserted to come from polls dated before the
   election.
2. 2025 state rows from `external/reference/polls/newspoll-quarterly/breakdowns.csv`:
   the latest Newspoll release before 3 May 2025 as the aggregate
   (24 Mar-23 Apr: NSW 52, VIC 53, QLD 46, SA 55, WA 54), every pre-election
   2025 reading (Newspoll and Freshwater) counted in `state_poll_n`, the 2022
   state result as the previous two-party.

`AUSPOL_STATE_POLL_NATL=actual` rebuilds the old (leaky) feature for
comparison only.

## Checks (verification, not a gate)

- Printed per state-year: old vs new `state_poll_dev`, and the national
  poll error each old value carried.
- fed2025 rows non-zero for NSW, VIC, QLD, SA, WA.
- Rebuild: report the ledger's seat log loss and primary RMSE before (rebuild
  A, 0.2951 / 5.198) and after, per federal pair. A rise is expected and is
  the honest number; it is logged, not reverted.

## RESULT (2026-09-28, rebuild C against rebuild A on the same code)

Applied: the fed harness's `SD1` lines differ from rebuild A's for every
federal pair; fed2025's correction went from "SKIPPED" to ON for 139 of 152
seats. Leaked national polling error removed (two-party points): 2007 1.54,
2010 1.82, 2013 0.63, 2016 -0.60, 2019 4.09, 2022 1.69.

| | seat log loss | weighted primary RMSE | TCP MAE |
|---|---|---|---|
| A (leaky) | 0.2951 | 5.198 | 4.05 |
| **C (fixed)** | 0.2963 | **5.083** | **3.95** |

Log loss C minus A +0.0011 (SE by seat 0.0028, t 0.40; by election 0.0047):
fed2022 +0.008, fed2025 -0.014, nsw2023 -0.012, qld2024 +0.005, sa2026
+0.012, vic2022 +0.010, wa2025 +0.019. State pairs move because the as-at
models train on all pairs pooled. **Ships as the new baseline**, as
pre-registered. Outputs in `output/rebuild-C/`.
