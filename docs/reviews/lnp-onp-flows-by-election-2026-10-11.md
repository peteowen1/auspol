# Liberal <-> One Nation preference flows, by election (2026-10-11)

Script: `scripts/audit_lnp_onp_flows.R` (reads every `external/elections/*-transfers.csv`, 25 elections, 36,064 rows).

## What the live Victorian forecast uses

Printed from the objects `simulate_seat_contests()` receives (live `fit_seats_full.R` cut before the call; per-seat
xgb override, 88 seats):

- Liberal excluded, only Labor and One Nation left: **68.0%** to One Nation (range 65.5-73.8; shared table 68.2).
- One Nation excluded, only Labor and Liberal left: **64.3%** to Liberal (range 58.8-73.8; shared table 67.8).

## What real counts show

Share of the votes going to the two named parties that went to the second one, in every contest where both were
still alive. "only two" = contests where they were the only two left (the like-for-like comparison).

Liberal excluded, % to One Nation (vs Labor):

| election | seats | all contests | only two (n) |
|---|---|---|---|
| fed2019 | 15 | 85.1 | - |
| fed2022 | 2 | 74.8 | - |
| fed2025 | 4 | 78.7 | 80.1 (1) |
| qld2020 | 2 | 73.8 | 73.8 (2) |
| sa2026 | 30 | 66.2 | 66.6 (11) |
| wa2017 | 4 | 53.6 | - |
| wa2025 | 6 | 62.2 | - |

(fed2004, nsw2023, wa2021: 1-2 seats each, 40-65%.)

One Nation excluded, % to Liberal (vs Labor):

| election | seats | all contests | only two (n) |
|---|---|---|---|
| fed2004-fed2016 | 11-69 | 49.8-59.5 | 48.6-51.1 |
| fed2019 | 58 | 66.1 | 65.3 (26) |
| fed2022 | 134 | 66.5 | 63.8 (25) |
| fed2025 | 139 | 75.5 | 71.4 (25) |
| nsw2023 | 16 | 64.9 | 62.0 (11) |
| qld2024 | 92 | 72.6 | 70.0 (29) |
| sa2026 | 14 | 72.4 | 68.9 (7) |
| wa2025 | 41 | 75.0 | 75.1 (10) |

## Reading

1. **One Nation -> Liberal looks too low.** Every election since 2024 sits at 69-75% like-for-like; the live forecast
   uses a median of 64.3%. The flow has risen steadily from ~50% (2004-2016); a fit weighting old elections equally
   would land low. Not yet traced to which input pulls it down. Unverified: that the gap moves seats.
2. **Liberal -> One Nation varies a lot between elections** (54 to 85%), and the variation is election-wide, not
   per-seat. The live 68% is mid-range and matches SA 2026 (66.6%), the one election where the Liberal card is known
   to have put One Nation above Labor. The simulation draws this flow independently per seat, so it misses that
   the whole state moves together.
3. **No past Liberal card orders for One Nation vs Labor are on disk** (`external/reference/htv/` covers Labor vs
   Greens only). A card-follow-rate model cannot be fitted from what we have; card orders would need collecting
   from dated pre-election sources.

## Recency weighting, first test (2026-10-11 evening)

**Trace.** The live per-seat flow model's rate feature (`R/xgb_flow_override.R`, `key_rates`) is a
`cond_n`-weighted mean over every earlier election, equal weight by age: 65.6% for ON -> Lib (ALP+LNP left);
the trees then take it to the 64.3% median. The shared table (`fm`, Vic + SA + Qld transfers) gives 67.8% but
is consulted only where the per-seat override has no key.

**Screen** (`scripts/screen_flow_recency.py`, time-forward, rate feature only, 4,409 election-cells; vote-weighted
absolute error in points, lower is better):

| half-life | all cells | One Nation cells | ON<->Lib cells |
|---|---|---|---|
| equal | 5.60 | 6.71 | 7.00 |
| 4 y | 5.05 | 5.84 | 5.99 |
| 2 y | 4.96 | 5.67 | 5.70 |
| 1.5 y | 4.96 | 5.59 | 5.51 |
| 1 y | 5.06 | 5.55 | 5.16 |

**Seat test** (`quick_arm.R "AUSPOL_FLOW_RATE_HL=2"`, AEF-7, 681 seats, 1,000 sims, switch confirmed applied in
every arm log and in no baseline): seat-winner log loss 0.2723 -> 0.2745, +0.0022 (SE 0.0018), WORSE by 1.2 SE.
Better on sa2026 (-0.0037) and qld2024 (-0.0030); worse on fed2025 (+0.0086) and vic2022 (+0.0044).

**Not a refusal: this was the weak version.** Only the inference-time rate feature changed. The trees were trained
on equal-weighted rates (`scripts/fit_xgb_flows_v1.R` builds `cond_rate` from every OTHER election, later ones
included; `fit_xgb_flows_asat.R` reuses those features), so they already learned corrections relative to that
feature and a recency-weighted input is a train/predict mismatch. The strong version rebuilds the training feature
as a time-forward, recency-weighted rate and refits the as-at flow models, then reruns the arm.
