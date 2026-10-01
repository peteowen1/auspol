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

## RESULT, 2026-10-01 13:10: REFUSED (the unacceptable-win clause fires), switch stays "federal"

Full rebuild `output/snapshots/20261001-1259-540a65c-from1` against v56
(`20260930-2115-72387b7-from1`).

| measure (lower is better) | v56 | Senate rule |
|---|---|---|
| One Nation share RMSE, xgb layer, 276 contested seats | 5.42 | 5.00 (per-election MSE change -1.96, SE 2.48) |
| One Nation share RMSE, base_pred | 5.69 | 5.22 |
| seat log loss, 22 elections, per-election mean change | | +0.0010 (SE 0.0018) |
| sa2026 seat log loss | 0.2376 | 0.2641 (+0.0265, SE 0.0160 by seat, **1.7 SE**) |
| qld2024 seat log loss | 0.2736 | 0.2744 (0.1 SE) |
| ledger (AEF 0.2851) | 0.2741 | 0.2765 |
| primary RMSE, all rows | 4.1617 | 4.1737 |

The share error falls (all of it Qld 2020, 6.59 -> 5.41) but SA 2026's seat
log loss rises by 1.7 SE -- exactly the shape the clause names. Ngadjuri,
which One Nation won, 0.695 -> 0.398. The allocation test that motivated this
gave every rule the true statewide level and scored the spread alone; in the
full model the xgb layer was already correcting One Nation's geography (the
residual check found no Senate signal left in v56's One Nation errors), and
SA 2026 had to use Qld 2017's curve (R2 0.66) rather than its own (0.87).
Kept behind the switch: the Senate tables, R/onp_senate.R and the harness
wiring.
