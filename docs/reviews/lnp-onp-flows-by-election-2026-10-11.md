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

## Strong version: retrained flow trees (2026-10-11, late)

`scripts/fit_xgb_flows_tf.R <tag> <half-life>` rebuilds the four rate features for each election's rows from
EARLIER elections only, through `.flow_rates_tf()` (the same function prediction calls under
`AUSPOL_FLOW_TF=1`), and trains one as-at model per election with the shipped params and nrounds (980). 2.5 min
per tag. Two tags, so the two changes can be told apart: `tf0` (time-forward, equal weight) and `tf2`
(time-forward, 2-year half-life). Both arms' logs show the tagged as-at model loaded and the time-forward line
printed on all 7 elections; no baseline log does.

Seat-winner log loss on AEF-7 (681 seats, 1,000 sims; lower is better; baseline 0.2723 = shipped):

| election | inference-only HL=2 | tf0 | tf2 |
|---|---|---|---|
| fed2025 | +0.0086 | +0.0310 | +0.0234 |
| vic2022 | +0.0044 | +0.0078 | +0.0043 |
| sa2026 | -0.0037 | +0.0012 | +0.0042 |
| nsw2023 | +0.0010 | +0.0006 | +0.0022 |
| wa2025 | +0.0011 | -0.0047 | -0.0019 |
| qld2024 | -0.0030 | -0.0021 | -0.0078 |
| fed2022 | +0.0005 | -0.0060 | -0.0117 |
| **pooled** | **+0.0022 (SE 0.0018)** | **+0.0060 (SE 0.0069)** | **+0.0025 (SE 0.0062)** |

Reading: no version helps on the pooled number; tf2 beats tf0 (recency itself is worth about -0.0035 here, the
direction the screen predicted), but taking the trees time-forward costs more than that on fed2025 in every
version. fed2025 is the open question: its flows are the most accurately predicted by the recency screen, yet it
moves the wrong way every time. Next: walk the fed2025 seats that moved most under tf2 (which flow, which way,
who won) before any further arm. Not shipped; switches stay "0". No live vic2026 model was written.

## fed2025 walked (2026-10-12)

The tf2 damage on fed2025 (+0.0234) is concentrated: the 10 worst seats carry +0.0140. Two shapes. Labor v Liberal
seats Labor won (Forde, Leichhardt, Bass, Hughes) moved toward the Liberal; Liberal v independent seats the
Liberal won (Monash, Flinders, Wannon, Goldstein) moved toward the independent.

**The flows got MORE accurate, not less.** fed2025 rate feature vs actual, percent:

| cell | shipped | tf2 | actual |
|---|---|---|---|
| GRN -> ALP (ALP+LNP left, 73 events) | 77.9 | 79.3 | 81.8 |
| ONP -> LNP (ALP+LNP left, 25) | 63.3 | 66.5 | 71.4 |
| IND -> ALP (ALP+LNP left, 16) | 53.8 | 55.5 | 63.0 |
| ALP -> IND (IND+LNP left, 13) | 77.4 | 77.1 | 76.3 |

**The cause is the primary vote.** The shipped fed2025 run under-calls Labor by 4.6 points on average (30.2
predicted, 34.8 actual over 150 seats) and over-calls the Liberals by 2.2 (33.8 vs 31.6); Forde ALP 26.4 vs 34.2,
Leichhardt 25.3 vs 36.5, Hughes 28.5 vs 39.0. Flows that under-sent right-wing preferences to the Liberals were
partly offsetting that miss; correcting them removes the offset. A seat-level metric therefore cannot judge a
flow change on fed2025 by itself. A flow change needs a flow-only score: seat outcomes given ACTUAL primaries
and predicted flows (no such mode exists yet; grep for an oracle-primary switch found none).

## Flow-only score: the retrained trees are better flows (2026-10-12, overnight)

`scripts/score_flows_oracle.R` takes the primary vote out: every seat's ACTUAL first preferences, each
configuration's flows (per-seat override fed those actual primaries, then a time-forward pooled table, smoothing
0.15). E = vote-weighted half-L1 error of the predicted split at every real exclusion (actual excluded party,
actual survivors), points, lower is better. W = seats whose actual winner comes out of the count. Pooled over
the 18 elections where every configuration loaded its own model (fed2007, sa2022, wa2001, wa2005 excluded: no
as-at model, so all four fall to the same pooled table). 7,295 exclusions, 1,821 seats.

| configuration | E (points) | W |
|---|---|---|
| shipped | 14.21 | 1,724 (94.7%) |
| inference-only HL=2 | 14.10 | 1,726 |
| tf0 (retrained, time-forward, equal weight) | **11.75** | 1,737 |
| tf2 (retrained, time-forward, 2-year half-life) | 11.89 | **1,740** (95.6%) |

tf0 and tf2 beat shipped on E in **all 18** elections (largest: fed2016 14.06 -> 9.74, fed2019 13.32 -> 9.83).
Recency adds little once the trees are retrained; the gain is the training/prediction feature mismatch.

**Reading against the seat test.** On AEF-7 seat log loss tf0 was +0.0060 and tf2 +0.0025 (within 1 SE). The
flows are measurably better; the seat metric moves the other way because the old flows were offsetting primary
misses (fed2025, above). That is a decision for Pete, not a refusal: ship the better component and take the
headline hit until the primary misses are fixed, or hold it. Before shipping either way: a prereg, an all-22
deciding run, and a tagged live (vic2026) model, which `fit_xgb_flows_tf.R` does not yet write.

## What tf2 does to the live Victorian forecast (2026-10-12, overnight)

Live models written by `fit_xgb_flows_tf.R <tag> <hl> vic2026` (all 25 corpus elections, all earlier than
polling day). Flows the live forecast would use (per-seat median, 88 seats, percent):

| flow | shipped | tf0 | tf2 |
|---|---|---|---|
| ON -> Lib (ALP+LNP left) | 64.3 | 69.4 | 72.2 |
| Lib -> ON (ALP+ONP left) | 68.0 | 70.0 | 73.4 |
| GRN -> ALP (ALP+LNP left) | 79.2 | 79.3 | 79.0 |
| GRN -> ALP (ALP+ONP left) | 68.8 | 78.0 | 71.1 |
| ALP -> Lib (LNP+ONP left) | 64.2 | 57.7 | 55.3 |

Full live run (`fit_seats_full.R`, published flags, output suffixes `-flowbase` / `-flowtf2`, files in
`deciding-runs/20261012-live-flows-tf2/`), seats won, median (90% range):

| party | published flows | tf2 flows |
|---|---|---|
| ALP | 32 (19-45) | 30 (17-42) |
| LNP | 35 (24-50) | 34 (23-50) |
| ONP | 14 (5-26) | 18 (8-30) |
| GRN | 5 (3-8) | 5 (3-8) |

The "published flows" column is today's code at published flags, not the forecast-latest release.
