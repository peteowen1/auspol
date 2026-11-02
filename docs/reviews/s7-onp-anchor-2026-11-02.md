# S7 breach on the published One Nation trend, 2 Nov 2026: the cause is the 2022 anchor, not the ORU poll

The 4:30am 2 Nov forecast run (Actions 41331814597) published with `S7 BREACH ONP fitted 19.52 against
22.03 from 15 polls (bound 2.5)`. It showed green. The run's own `##[error]` line is the only sign.

Scripts (scratchpad, not committed): refit `trend_as_at()` exactly as `fit_seats_full.R:382-391` does, with
local poll inputs refreshed by `scripts/refresh_local_poll_inputs.sh` at 11:26am 2 Nov. Reproduces the
CI number to two decimals (19.52 against 22.03, 15 polls).

## What moves the gap

Fitted One Nation endpoint minus the 90-day poll mean; S7 allows 2.5.

| fit | ONP endpoint | 90-day poll mean | gap |
|---|---:|---:|---:|
| published (all polls, anchor at 2022 result 0.28%) | 19.52 | 22.03 (15 polls) | 2.52 |
| without the Online Research Unit poll (ONP 14, 20 Oct) | 20.19 | 22.61 (14 polls) | 2.42 |
| without the One Nation day-0 anchor (prior dropped) | 21.42 | 22.03 (15 polls) | 0.62 |

**The ORU poll moves the trend 0.68 points; the anchor moves it 1.90.** The trend has sat about 2 points
under every poll since July (20.40 on 30 Jul, when the polls were 22-23.5).

The mechanism: `trend_anchor()` (`R/trend.R:103`) pins day 0 (27 Nov 2022) at logit(0.28%) with the
strong sd (5 points translated at the party's observed 22%). The walk is stiff (`sigma_rw` 0.0044 per day),
so climbing from 0.28 to 22 is penalised, and the soft sum-to-zero on house effects gives way instead: every
firm's One Nation house effect comes out positive, poll-weighted mean **+2.12 points** (Redbridge +4.46,
SMS Morgan +4.36, Freshwater +2.37, DemosAU +1.48, ResolvePM +1.03, other firms -1.14). Without the anchor
they centre (Redbridge +2.54, SMS Morgan +2.45, ResolvePM -1.00, other firms -2.99).

**This corrects `reviews/poll-lag-2026-08-19.md`**, which said "the day-0 anchor was never the mechanism"
from WA 2017 (prior 0.00, fitted 7.8). On WA 2017 the anchor costs 1.38 points (9.20 without it).

**It also corrects NEXT-STEPS #1 and what Pete was told on 1 Nov**: the published trend DOES fit a house
effect per firm per party (`fit_cycle_trends()`, within-cycle, centred by a soft sum-to-zero). What it does
not have is house effects measured against RESULTS across cycles, or sponsor and mode terms.

## Is the shading wrong? The record, 10 One Nation cycles with polls and a result

Error = estimate minus actual statewide primary (positive = over-states One Nation). Actuals: next cycle's
`prev1` in prior results; sa2026, qld2024 and wa2025 from `output/candidacies.csv`. wa2025 has 2 polls in the
window and no fit; fed2016 has none.

| election | prior | polls (n) | trend, anchor | trend, no anchor | actual | err anchor | err no anchor | err polls |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| nsw2019 | 0.00 | 5.18 (5) | 3.94 | 4.63 | 1.10 | +2.84 | +3.53 | +4.08 |
| nsw2023 | 1.10 | 5.60 (5) | 4.63 | 4.96 | 1.80 | +2.83 | +3.16 | +3.80 |
| wa2017 | 0.00 | 10.39 (9) | 7.82 | 9.20 | 4.93 | +2.89 | +4.27 | +5.46 |
| qld2017 | 0.92 | 15.30 (10) | 12.71 | 13.87 | 13.73 | -1.02 | +0.14 | +1.57 |
| qld2020 | 13.73 | 9.80 (5) | 10.65 | 10.58 | 7.12 | +3.53 | +3.46 | +2.68 |
| qld2024 | 7.12 | 8.54 (7) | 8.97 | 8.98 | 8.00 | +0.97 | +0.98 | +0.54 |
| sa2026 | 2.63 | 22.90 (10) | 20.66 | 21.18 | 22.87 | -2.21 | -1.69 | +0.03 |
| fed2019 | 1.29 | 4.96 (29) | 4.86 | 5.06 | 3.08 | +1.78 | +1.98 | +1.88 |
| fed2022 | 3.08 | 3.90 (37) | 4.24 | 4.29 | 4.96 | -0.72 | -0.67 | -1.06 |
| fed2025 | 4.96 | 7.41 (53) | 7.74 | 7.72 | 6.40 | +1.34 | +1.32 | +1.01 |
| **mean absolute error (lower is better)** | | | | | | **2.01** | **2.12** | **2.21** |

- Polls over-stated One Nation in 8 of 10 cycles (mean signed +1.90). The anchor's shading helps on average,
  by 0.11 points of MAE over no anchor: 10 cycles, no SE computed, so this is a lean, not a result.
- **The one completed case the size of Victoria (sa2026: prior 2.6, polls 22.9) goes the other way**: the
  polls were exact (+0.03) and the anchor cost 0.52 points. The cases where polls over-stated most are small
  surges (nsw2019, nsw2023, wa2017 at 5-10%) and a fading party (qld2020).
- Not checked: whether over-statement depends on the surge's size or on the firms polling, which is exactly
  the question NEXT-STEPS #1 (poll weighting by type, company and age) asks.

## Status

LIVE, not a code bug: the published forecast carries One Nation at 19.5 statewide against 22.0 in the polls,
and S7 will keep firing on every daily run while that holds. Whether to shade a surging party toward its last
result, and by how much, is a modelling decision for the #1 prereg, fitted time-forward on these cycles.

## Correction, same day (after arm BLD): the published level is 20.92, not 19.52

The forecast's statewide One Nation level is the trend rescaled to 100 (19.96) plus the recent-poll blend's spill from
the other three parties (+0.96): **20.92** in the 4:30am 2 Nov run (log line "blended minus pre-blend ... ONP +0.96").
So the published gap to the polls is about 1.1 points, not the 2.5 S7 reports, and "the gap is not confined to the trend
chart" in S7's own message overstates it. The trend gap and the anchor finding above stand; the size reaching the seats
is smaller. All three poll-lean arms tested on 2 Nov (`plans/prereg-poll-lean-2026-11-02.md`) did not pass.
