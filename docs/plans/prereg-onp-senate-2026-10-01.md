# Pre-registration: One Nation allocated by its federal SENATE vote (`AUSPOL_ONP_ORDER = "senate"`)

Written 2026-10-01, before the rebuild. From Pete's chart (SA 2026 district One
Nation against the 2025 Senate One Nation vote, r 0.92, concave).

## Evidence so far (exploratory, not pre-registered)

Leave-one-election-out over SA 2026, Qld 2017, 2020, 2024 and NSW 2023,
eleven allocation rules, each given the election's actual One Nation mean so
only the spread is tested. RMSE in points (lower is better):

| rule | SA 2026 + Qld 2017 (One Nation ~21-23%) | all five |
|---|---|---|
| log curve of the most One-Nation-heavy earlier election, on the Senate share, scaled | **3.25** | 3.13 |
| pooled logit on the Senate share | 3.76 | 3.11 |
| House-rank rule (what the live forecast ships) | 5.28 | 3.90 |
| uniform (what the Qld and NSW harnesses do) | 6.74 | 5.34 |

The House vote added nothing; pooling curves did not help. The floor
(below the source election's lowest Senate share) was chosen after seeing
Qld 2017, which is a post-hoc choice.

## The change

`R/onp_senate.R`: curve from the most One-Nation-heavy election BEFORE the
target with district Senate shares (time-forward: Qld 2017 for SA 2022/2026,
Qld 2020/2024 and NSW 2019/2023; SA 2026 for live Victoria), applied to each
contested seat's Senate share, the seat-mean preserved. In the SA, Qld and NSW
harnesses (replacing SA's House-rank concentration arm and the others' uniform
allocation) and the live forecast. Not in fed, vic, wa: One Nation is
negligible in the Victorian backtests, WA has no booth map, and the federal
harness has the House vote directly.

## Measurement

Full rebuild with `AUSPOL_ONP_ORDER=senate` against v56
(`output/snapshots/20260930-2115-72387b7-from1`).

1. **Primary (targeted):** One Nation's share error (RMSE over seats One
   Nation contested) in base_pred AND the xgb layer, pooled over sa2022,
   sa2026, qld2020, qld2024, nsw2019, nsw2023. Must fall in the xgb layer.
2. **Guard:** pooled seat log loss over all 22 elections not worse by more
   than one SE clustered on election; published ledger likewise.
3. **Reported:** AEF-7 ledger metrics; per-election seat log loss for the six.

Unacceptable-win clause: if the One Nation share error falls but seat log loss
rises in SA 2026 or Qld 2024 by more than one SE, the spread is better and the
seats are worse -- report it, do not ship it.
