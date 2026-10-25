# Mildura and Benambra: where the independent's vote goes in the live forecast (2026-10-25)

Why this matters: Mildura is the one Victorian seat where an independent with a large personal vote (Ali Cupper, 33.9
in 2022) is standing again, and the published forecast gives her 25.6 at the point estimate and **2.3% to win**. One
Nation is given 82%. Most of that is not the point estimate at all: it is the simulation adding a second One Nation
surge on top of a One Nation share that already sits at its surge level.

One correction to the brief: Cupper is **not** the sitting member. Jade Benham (Nationals) won Mildura in 2022 and is
recontesting (`returns`: LNP `same_mp` TRUE, IND `same_mp` FALSE; xgb row `same_mp_i` 0 for IND, 1 for LNP). Cupper
was the member 2018-2022 (`historic_elected_i` 1). That matters for the comparison with the vic2022 backtest, where
she WAS sitting.

## How this was measured

A copy of `scripts/fit_seats_full.R` with print lines added after every stage
(`scratchpad/fit_seats_full_trace.R`, built by `scratchpad/make_trace.R`; nothing in `R/`, `scripts/` or `src/`
edited). Run three times, all exit 0, with `AUSPOL_OUT_SUFFIX` set and `output/S7-BREACH.txt` restored after each
(checked with `cmp`):

| Run | Log | What it adds |
|---|---|---|
| `-mtrace` | `deciding-runs/20261025-mildura-trace/trace.log` | per-stage values, xgb rows and SHAP, sim with surge off in the two seats |
| `-mtrace2` | `trace2-shipped.log` | same as shipped, plus two whole-state sim variants (below) |
| `-mtrace2hold` | `trace2-holdind.log` | returning-independent cells held through the One Nation fill (`TRACE_HOLD_IND=1`, trace copy only) |

The traced run's stage-21 values equal the published walk (`deciding-runs/20261025-minor-additive-walk/seat-shares-vic-2026-walk-add.csv`)
to two decimals for every class in both seats, so the prints did not change the model. All suffixed outputs, the xgb
feature rows (`xgb-rows-focus.csv`) and the SHAP contributions (`xgb-shap-focus.csv`) are in
`deciding-runs/20261025-mildura-trace/`. Switches as published (`published_flags.R`), including
`AUSPOL_MINOR_ADDITIVE=1`.

## Mildura, IND (Cupper), stage by stage

Values are the IND share of the seat's first preferences, in percentage points. "Line" is `scripts/fit_seats_full.R`
at commit `37ccddf`. "Live only?" says whether the six backtest harnesses do something different at this point.

| # | Stage | IND in | IND out | Change | Line | Live only? |
|---|---|---|---|---|---|---|
| 00 | prior-election class share (Cupper 33.86 + two other independents) | - | 41.19 | | 1018 | no |
| 01-03 | by-election prior, transferred votes, departed origin | 41.19 | 41.19 | 0 | 1022-1046 | no |
| 04 | own-vote substitution: Cupper's own 33.86 replaces the class total (`own_prev_substitute`) | 41.19 | 33.86 | -7.33 | 1273 (`.own_x`) | no |
| 05 | minor-field block, additive: `3.36 + 0.907 x (33.86 - 5.55)`. Class level 5.55 -> 3.36 costs 2.19; slope 0.907 (same-candidate IND slope) costs 2.64 | 33.86 | 29.03 | -4.83 | 1270-1275 | no (since today's `AUSPOL_MINOR_ADDITIVE`) |
| 06 | re-entry prior | 29.03 | 29.03 | 0 | 1286-1294 | no |
| 07 | **One Nation fill**: every non-held cell x `(100 - 33.92) / 75.61 = 0.874` | 29.03 | 25.37 | **-3.66** | 1318-1331 | **yes**: no harness has the One Nation quantile allocation or this fill (`backtest_candidate_vic.R` swings One Nation additively like every class; no `onp_` code in it) |
| 08-12 | One Nation set to 33.92; renormalise (hold); new-IND shrink (Cupper excluded, returning); salience-once (off); person rule base (off) | 25.37 | 25.37 | 0 | 1333-1409 | no |
| 13 | live xgb: tree output 26.80 (`own_prev_pcv` +2.78, `base_pred` -1.61, `party_IND` -0.96, `council_elected` +0.84...), then the row (sum 106.95) renormalised | 25.37 | 25.06 | -0.31 | 1410-1419; `R/xgb_primary_override.R:663-689` | yes, documented: live predicts from this run's shares, harnesses read a static cache |
| 14 | person rule final (no match) | 25.06 | 25.06 | 0 | 1423 | no |
| 15-19 | seat-swing port (majors only), seat-poll blend (no Mildura poll), demographic correction (+0.42, from renormalising the Labor/Greens change), leader seat, departed fed | 25.06 | 25.48 | +0.42 | 1431-1471 | no |
| 20-21 | salience point blend (+0.09); nomination zeroing (not applied, provisional list) = **published point estimate** | 25.48 | **25.57** | +0.09 | 1479-1501 | no |
| 22 | **simulation mean**: One Nation surge fires with hazard 0.7346, adding N(34.28, 9.70) to One Nation and taking it proportionally from everyone else | 25.57 | **15.84** | **-9.73** | 1818-1826; `src/seat_sim_core.cpp:222-245` | not a code difference, but never scored: see cause 1 |

Result at each end: point estimate IND 25.57 / LNP 34.14 / ONP 33.75; simulation means IND 15.84 / LNP 21.08 / ONP
57.74 (median ONP 61.4). Win probability IND 0.023, LNP 0.157, ONP 0.820.

## Benambra, IND (new candidate Lachie McKeeman succeeding Jacqui Hawkins)

Hawkins (31.70 in 2022, never elected) has gone; `departed-successor-rates.csv` gives vic2026 Benambra the "strong"
successor rate 0.511, and the cell is held through the One Nation fill and renormalisation (`DSR1`, `DH0`).

| # | Stage | IND in | IND out | Change | Line | Live only? |
|---|---|---|---|---|---|---|
| 00 | prior class share (Hawkins) | - | 31.70 | | 1018 | no |
| 04 | no own-vote substitution (new person) | 31.70 | 31.70 | 0 | 1273 | no |
| 05 | minor-field block: `3.36 + 0.511 x (31.70 - 5.55)`; the 0.511 is the successor rate, used as the slope | 31.70 | 16.71 | -14.99 | 1270-1275 (`screened_slopes(successor_rate=)`) | no |
| 07-12 | One Nation fill (fill 1.136, but IND is HELD, so unchanged); new-IND shrink skips it (class prior >= 10) | 16.71 | 16.71 | 0 | 1318-1409 | fill is live only; it does not touch this cell |
| 13 | live xgb: tree output 12.55 (`base_pred` -1.75, `party_IND` -1.69, `level_pred` -0.37...), row sum 97.76 renormalised | 16.71 | 12.84 | **-3.87** | 1410-1419 | documented cache difference only |
| 15-21 | port, poll blend, demographic (+0.12), leader, salience (no Benambra salience rows) | 12.84 | **12.96** | +0.12 | 1431-1501 | no |
| 22 | simulation mean (no surge hazard in Benambra) | 12.96 | 12.85 | -0.11 | 1818 | no |

Win probability IND 0.0025, LNP 0.950, ONP 0.047. Overall retention of Hawkins's vote: 12.96 / 31.70 = 0.41. Earlier
departed independents who had never been elected kept 0.06 to 0.64 (Wentworth 2007 0.06, Barker 2019 0.10, Boothby
2019 0.12, Wide Bay 2007 0.52, Parkes 2010 0.60, New England 2019 0.64; `output/departed-ind-successors.csv`), so 0.41
is not out of line. **Benambra has no single broken stage**: two thirds of the drop is the fitted successor rate, and
the rest is the trees shrinking a cell that was already set by a fitted retention rule (see "Secondary" below).

## vic2022 backtest, Mildura, for comparison

From `output/xgb-primary-asat-predictions.csv` and the vic harness sharedetail (`...-a8d7c86-g50a389c.csv`); the harness
itself was NOT re-run with prints, so its intermediate stages are not shown.

| Quantity | vic2022 backtest | vic2026 live |
|---|---|---|
| Cupper sitting? | yes | no (Benham is) |
| base before the trees | 33.92 | 25.37 (29.03 before the One Nation fill) |
| trees | 43.40 (+9.48) | 26.80 (+1.43) |
| final point estimate | 38.75 (actual 41.19) | 25.57 |
| One Nation in the seat | 0 (did not stand) | 33.9 |
| surge recipient, hazard | IND, 0.219 | ONP, 0.735 |

The backtest's good Mildura number comes from a sitting-member uplift in the trees and the absence of One Nation.
Neither applies in 2026, so the backtest says nothing about the two stages that cost Cupper most now.

## Causes of the remaining gap

1. **The simulation double-counts the One Nation surge (largest; live and harness share the code).** The surge size
   `surge_mu = 34.28` is the mean first-preference vote of the 23 past emergence WINNERS
   (`R/salience_surge.R:341`). Those winners came from a mean prior vote of 1.06, so in training "the vote a winner
   gets" and "how much a surge adds" were the same number. The simulator uses it as an amount to ADD
   (`src/seat_sim_core.cpp:233`, documented as a "gain" at `R/seat_sim.R:256`). One Nation's Mildura cell is already
   33.75 from the statewide One Nation allocation, so a fired surge lifts it to about 68. It fires in 73% of draws:
   Guy Cooper's salience rise sits at the 88th percentile, and the hazard model has learned a strong One Nation effect
   from the three South Australian 2026 winners. 26 of the 31 recipient seats are One Nation, with a mean point share
   of 29.3 already.

   Measured whole-state (`trace2-shipped.log`, 20,000 sims, same seed; expected seats = sum of win probabilities):

   | Simulation variant | Mildura IND / LNP / ONP win prob | Expected seats LNP / ALP / ONP / IND |
   |---|---|---|
   | as shipped | 0.023 / 0.157 / 0.820 | 30.27 / 29.13 / 21.89 / 0.66 |
   | surge as a LEVEL (add `mu - point share`, approximation) | 0.062 / 0.436 / 0.502 | 31.50 / 29.27 / 20.40 / 0.68 |
   | One Nation recipients' surge off | 0.078 / 0.581 / 0.340 | 32.15 / 29.48 / 19.37 / 0.72 |

   Not a code train/serve difference: every harness runs the same simulator. But it has never been scored in this
   regime. No backtest has had a recipient whose cell already sat near its surge level with a hazard this high; the
   only One Nation winners in training are in sa2026, and the sa2026 harness leaves sa2026 out of its own hazard fit.

2. **The One Nation fill cuts a personal vote by the same fraction as everyone else (point estimate, live only).**
   Stage 07 multiplies every cell by 0.874 to make room for One Nation's 33.9, costing Cupper 3.66 points. This is
   the same multiplicative shape `AUSPOL_MINOR_ADDITIVE` removed one block earlier. It is a **train/serve
   difference**: the harnesses have no One Nation allocation or fill, so the trees were never trained on a base that
   went through it. Holding returning-independent cells through the fill (trace-only arm, `trace2-holdind.log`) gives
   Mildura IND 28.93 at the point estimate (LNP 34.14 -> 31.28). But on its own it does almost nothing for her chance
   of winning (IND 0.023 -> 0.058, ONP 0.820 -> 0.840) while cause 1 is there. A hold in both directions is wrong: in
   Kew the fill is above 1, and holding there LOWERS the independent (23.35 -> 21.07). The fix has to be one-sided.

3. **What the model does on purpose (not gaps to fix here).** The additive minor-field step (-4.83) is the shipped
   rule, the same one the state harnesses score: the class level falls 5.55 -> 3.36, and a returning, non-sitting
   independent keeps 0.907 of her deviation. The trees add only +1.4 because she is no longer the member.

With causes 1 and 2 both removed (hold arm plus surge off for One Nation recipients), Mildura is IND 0.202, LNP 0.379,
ONP 0.419. With the hold plus the level approximation: 0.155 / 0.279 / 0.566.

## Proposed fix: `AUSPOL_SURGE_LEVEL` (with a one-sided personal-vote hold as a second, separate arm)

### Arm A: `AUSPOL_SURGE_LEVEL=1` (default "0")

When the surge fires, draw the recipient's surge LEVEL `L ~ N(surge_mu, surge_sd)` and raise the recipient to
`max(v_j, L)`, taking `max(0, L - v_j)` proportionally from the other cells (`src/seat_sim_core.cpp:229-244`; R
reference path in `R/seat_sim.R` the same). "0" leaves the engine byte-identical. The trace's variant only
approximated this (it set `mu` to `surge_mu - point share` per seat, so the gap is measured from the point estimate,
not from each draw's value); the real arm must use each draw's value.

Why it is general, not a Mildura patch: the training winners' mean prior vote was 1.06, so a level and a gain agree
wherever the recipient starts near zero, which is every training case. They part only where the recipient already
sits high, and that is exactly where adding a winner's whole vote again is wrong.

### Arm B (separate, after A is decided): `AUSPOL_ONP_FILL_HOLD_PERSONAL=1` (default "0")

At the One Nation fill (`fit_seats_full.R:1318-1331`), a cell whose candidate personally returns (`.returns$same`
TRUE for IND/OTH_RIGHT/OTH) is held when the fill is below 1 (a cut) and scaled as now when it is above 1. Live only,
because no harness has the fill. That means it cannot be backtested; it is a parity fix of the same kind as
`AUSPOL_MINOR_ADDITIVE`, and it goes to Pete as one.

### Draft pre-registration (Arm A)

Written before any run of the arm.

- **Where it acts:** every election with a surge hazard (the salience corpus: the 9 training pairs plus any harness
  scoring them), in all six harnesses, since the simulator is shared. Screen: `scripts/quick_arm.R "AUSPOL_SURGE_LEVEL=1"
  --pairs=all --sims=5000`; deciding run at 20,000 sims, all 22 elections (`scripts/deciding_run.ps1`).
- **Named target seats (rule fixed in advance):** every (election, seat) where the recipient's point share before the
  simulation is at least 10 and the hazard is at least 0.02, because that is where a level and a gain differ by more
  than 10 points. The screen prints the list before any score is read. Expected to include vic2022 Mildura (IND,
  base 38.7, hazard 0.219); if the list is empty outside Victoria 2026 the arm cannot be measured, and that is
  reported as "not measurable", not as "no effect".
- **Primary:** seat-winner log loss on the target seats, better than shipped by more than 1 SE, SE clustered on
  election.
- **Guard (election-wide):** seat log loss over all 2,050+ seats of the 22 elections not worse by more than 1 SE,
  clustered on election.
- **No election materially worse:** no election worse on the guard by more than 2 SE of its own paired seat
  differences.
- **Leave-one-election-out:** the primary keeps its sign with each election dropped.
- **Not one seat's quirk:** the primary keeps its sign with the two largest-gain target seats removed.
- **Unacceptable win (named in advance):** any target-seat surge recipient who actually WON loses more than 0.10 win
  probability, or the arm moves any untouched seat (hazard 0) by more than 0.001 (it must not).
- **Reported, not decisive:** Brier and reliability by band on the target seats; the vic2026 walk (Mildura and the
  26 One Nation recipient seats, expected seats by party before and after).
- **Ship rule:** ships if the primary passes and every guard holds; a clause refusing an otherwise passing result
  goes to Pete with the split shown.

Known limit, stated now: the target set is likely small (high-base recipients are rare before 2026), so the primary
may be underpowered. Its noise (the smallest effect it can detect) is printed with the result. A refusal from a
target set of under 10 seats is "not measurable", not a negative.

### Secondary (Benambra; not proposed as a switch yet)

The live trees take the held successor cell from 16.71 to 12.55. The successor rate is itself fitted on what
successors actually got, so the trees may be shrinking a cell that was already shrunk. Whether the trees' training
base (`output/pooled-sharedetail.csv`, 16 Oct, after the successor rule shipped 7 Oct) carried the successor hold
for every past successor cell was **NOT checked row by row**. Check that before proposing anything for Benambra.
Given the retention range above, the published 12.96 is plausible.

## What was not checked

- The vic2022 harness was not re-run with prints; its stage values come from cached files.
- Why Cupper's own salience rise (`jump`) reads exactly 0.000 in the vic2026 target population, while Guy Cooper's
  reads 16.9 (88th percentile), was not traced. "Guy Cooper" is a common name and could be a namesake. If her series
  is missing rather than flat, the recipient choice in Mildura may be wrong as well.
- The surge-as-level numbers are an approximation (measured from the point estimate, not from each draw).
