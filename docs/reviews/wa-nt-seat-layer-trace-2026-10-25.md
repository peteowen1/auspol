# Where the WA and NT seat means leave the statewide level: trace, 2026-10-25

Asked: the level screen (`level-jurisdiction-bias-2026-10-25.md`) found NT's level UNDER-calls the Coalition
while NT seats over-call it, and WA seats over-call by more than the WA level does. Find the stage.

Inputs (all read from the 2026-10-21 rebuild, no harness rerun for the aggregate tables):
`output/rebuild-forecasts-logs/s1_*.log` and `s6_*.log` (the level each stage was built on, printed as
"forecast statewide replaces the oracle"), `output/xgb-base-ref/<pair>.csv` (stage-1 shares just before the
override: after `dev_slope`, independent zeroing and row renormalisation, before the late nomination zero),
`output/xgb-primary-asat-predictions.csv` (`base_pred` = those shares after the nomination zero, and the as-at
`xgb_pred` that stage 6 reads, `AUSPOL_XGB_PRIMARY_OOF`), `output/published-predictions.csv` (final, published
path). Seat weights for "implied statewide" are the target election's formal votes from `output/candidacies.csv`.
Scripts: scratchpad `stage_err.R`, `departure.R`
(`C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\e7e809d4-b07a-4695-a3bd-7e8f88a19663\scratchpad\`).

## Cause, in two sentences

Every harness puts each class at its statewide level with `dev_slope()` and then rescales each seat's row to
100 (`scripts/backtest_candidate_wa.R:614`, `_nt.R:647`); any level share that cannot land in a seat (an
independent zeroed where none nominated, `_wa.R:603`; One Nation or Greens zeroed late where they did not stand,
`_wa.R:677`; and the whole level of a class with no candidate anywhere, which `R/forecast_statewide.R:382-383`
(thin cycle) and `:403` drop without rescaling) is handed to whoever is left in that seat in proportion to
their share there, so both major parties end up about one point above the level they were given (ALP +1.07,
SE 0.38; Coalition +1.09, SE 0.36; 20 of 28 state elections positive for each). In NT the dropped level is
large (8.1, 3.8 and 14.8 points: the level sums to 91.9, 96.2 and 85.2), which makes the NT seat layer add
+4.4 to the Coalition and +5.7 to Labor; in WA the departure is +0.68 for the Coalition, and most of WA's
Coalition over-call (+2.29 implied) is the level itself (+1.61, 5 of 7 elections positive in the departure).

**Live or fixed: live.** The same shape is in the published Victoria forecast: `scripts/fit_seats_full.R:1271`
(`dev_slope` to `state_mean`) then `:1382` (`shares <- 100 * shares / rowSums(shares)`); its size there was not
measured.

## Correcting the screen's reading of NT

"NT's level under-calls the Coalition (mean -2.59)" is an average of opposite misses: nt2016 -1.6, nt2020
+5.7, nt2024 -9.3 (shipped stage-6 level minus actual). The seat over-call is mostly **nt2020**, where the level
itself over-called the CLP by 5.7 (Territory Alliance, a new party, polled at 0 and took 14.1). In nt2024 the
level carried Territory Alliance's 14.1 forward as OTH 14.8 (thin cycle, no polls for OTH, weight 0), the party
did not stand, the 14.8 was dropped, and the row renormalisation gave it out pro rata, lifting the CLP from a
39.6 level to 49.1 in the seats (actual 48.9). The seat layer "rescued" nt2024 by accident; the level model is
what is wrong there (a dead party's share carried forward).

## Seat 1: Southern River, wa2017 (ALP won at P 0.12)

Values are this seat's share, points. Prior = the notional wa2013 result on 2017 boundaries
(`state_notional_prior`, `_wa.R:284`). Actual 2017: ALP 49.69, Coalition 38.89.

| stage | code | ALP | Coalition | what changed |
|---|---|---|---|---|
| prior (notional 2013) | `_wa.R:284`, `:353` | 29.03 | 63.07 | statewide then ALP 33.1, Coalition 53.2 |
| level handed to the seats, stage 1 | `R/forecast_statewide.R:403-408` | 36.4 statewide | 37.7 statewide | trend, recent-poll blend off at stage 1 |
| level, stage 6 (published) | `R/level_recent.R` via `forecast_statewide.R:407` | 38.2 statewide | 38.4 statewide | `BW0r` decay blend 36.4 -> 38.2 |
| after `dev_slope` + row renormalisation (stage 1) | `_wa.R:574`, `:614` | 33.06 | 44.72 | ONP given 7.62 here (statewide 7.7, prior 0) |
| `base_pred` after nomination zero (ONP did not stand) | `R/nomination_zero.R` via `_wa.R:677` | 35.79 | 48.42 | ONP's 7.62 shared pro rata: ALP +2.73, Coalition +3.70 |
| xgb override, as-at trees (stage-1 base) | `R/xgb_primary_override.R`, `_wa.R:622` | 35.20 | 48.01 | small |
| seat-swing port, seat polls, demography, leader | `_wa.R:640`, `:645`, `:666`, `:671` | (0) | (0) | log: port coef 0.000, no polled cells, ALP demography term 0, no leader here |
| final published (stage 6) | `output/published-predictions.csv` | 37.10 | 48.90 | stage-6 level +1.8 ALP re-predicted through `AUSPOL_XGB_BASE_DELTA` |
| actual | | 49.69 | 38.89 | |

Reading it: of the Coalition's +10.0 miss, about +1.8 is the level (38.4 vs 36.6) and +3.7 is One Nation's
zeroed share handed out pro rata (One Nation took 4.9 statewide but stood in only 35 of 59 seats; the level
spread its statewide figure over all 59). The rest (+4.5) is the seat itself: its Coalition lead over the state
fell from +9.9 to +2.3, a realised deviation slope of 0.23 against the model's ~0.7. Labor's +12.6 miss is
level (-4.0) and the same seat-specific swing (ALP deviation -4.1 -> +7.5); it is not a stage bug. A check
across wa2017 seats found no cross-class pattern to exploit (published residual on prior Coalition share:
ALP +0.047 per point, SE 0.051; Coalition -0.064, SE 0.054; n 54).

**The wa2017 "36.4 -> 41.2" lift is now traced** (vote-weighted implied statewide ALP, points): stage-1 level
36.4 -> after renormalisation 37.76 (+1.36, mostly 35 seats with independents zeroed before `_wa.R:614`) ->
after the One Nation zero 39.17 (+1.41) -> stage-6 level blend adds +1.8 (36.4 -> 38.2) -> published 41.49
(unweighted seat mean 41.2). Two thirds of the lift is renormalisation of share the seats cannot hold; it
happened to help Labor (actual 42.2) and hurt the Coalition (implied 39.95 vs 36.62).

## Seat 2: Arafura, nt2024 (Coalition over-called by 25.2)

Prior = nt2020 result. Actual 2024: ALP 69.68, Coalition 30.32.

| stage | code | ALP | Coalition | what changed |
|---|---|---|---|---|
| prior (nt2020) | `_nt.R:388` | 48.98 | 40.18 | IND 7.68, OTH 3.16; statewide then ALP 39.4, CLP 31.3, OTH 14.1 |
| level, thin cycle | `R/thin_cycle.R` via `forecast_statewide.R:380` | 26.2 statewide | 39.6 statewide | OTH 14.1 -> 14.8 carried with no polls |
| level the seats get | `R/forecast_statewide.R:382-383` | 26.2 | 39.6 | OTH dropped (no OTH candidate in 2024): levels sum to 85.2 |
| after `dev_slope`, IND zeroed (none stood), before renormalisation | `_nt.R:607`, `:636` | about 34 | about 47 | reconstructed, slope ~0.85; row sums ~85 |
| after row renormalisation (stage 1) | `_nt.R:647` | 38.56 | 56.32 | every class x ~1.17 |
| `base_pred` after nomination zero (no Greens) | `_wa/_nt` late zero | 42.49 | 57.51 | Greens 5.1 out by flows |
| xgb, as-at | `_nt.R:655` | 42.50 | 55.41 | |
| final published | | 42.04 | 55.57 | |
| actual | | 69.68 | 30.32 | |

Here the renormalisation adds about +9 to the Coalition and +4.5 to Labor; the rest of the Coalition miss is
the level's uniform +8.3 swing landing on a remote seat that swung the other way (a seat-specific miss).

The "about" rows are reconstructed by hand from the prior, the levels and the stage-1 renormalised shares; a
traced harness copy (`bt_wa_trace.R` / `bt_nt_trace.R` in the scratchpad, printing every stage) was prepared
but could not run in this session: available memory stayed between 4.2 and 5.9 GB (the brief's floor is 8 GB)
for over an hour with no auspol job running. Its runner, `run_trace.ps1`, moves everything it writes to
`deciding-runs/20261025-wa-nt-seat-trace/`.

## Is it a jurisdiction effect? Departure from the level by stage

Implied statewide share (seat shares weighted by formal votes, zeros included) minus the level that stage was
built on, points; positive = the seats give the party more than the level did. Mean over elections, n =
elections; SE across elections. "renorm" = stage-1 shares after `dev_slope` and row renormalisation minus the
stage-1 level; "zero" = the extra from the late nomination zero; "final" = published minus the stage-6 level.
Level error = stage-6 level minus actual (positive = level over-calls). Fed is missing: its harness prints no
level line in this form.

| jurisdiction | party | n | level error | renorm | zero | final departure (SE) | final implied error (SE) | elections with departure > 0 |
|---|---|---|---|---|---|---|---|---|
| nsw | ALP | 4 | -0.23 | +0.25 | +0.33 | +0.45 (0.38) | +0.25 (1.35) | 3 |
| nt | ALP | 3 | -2.77 | +2.81 | +1.85 | +5.67 (0.75) | +2.74 (0.22) | 3 |
| qld | ALP | 5 | -0.52 | -0.13 | +0.61 | +0.90 (0.59) | +0.40 (1.33) | 4 |
| sa | ALP | 5 | -0.94 | +0.43 | +0.26 | +0.68 (0.70) | -0.13 (0.57) | 4 |
| vic | ALP | 4 | -0.68 | +0.47 | +0.20 | +0.06 (0.25) | -0.68 (0.63) | 3 |
| wa | ALP | 7 | +0.16 | +0.18 | +0.28 | +0.45 (0.53) | +0.69 (1.52) | 3 |
| nsw | Coalition | 4 | -0.35 | +0.45 | +0.69 | +0.80 (0.45) | +0.44 (0.51) | 3 |
| nt | Coalition | 3 | -1.73 | +3.49 | +0.66 | +4.40 (2.56) | +3.01 (2.20) | 3 |
| qld | Coalition | 5 | -0.38 | +0.09 | +0.57 | +1.33 (0.62) | +0.95 (0.53) | 4 |
| sa | Coalition | 5 | -1.62 | +0.33 | +0.27 | +0.77 (0.42) | -0.83 (0.73) | 4 |
| vic | Coalition | 4 | -0.95 | +0.25 | +0.14 | -0.26 (0.24) | -1.17 (1.23) | 1 |
| wa | Coalition | 7 | +1.61 | +0.40 | +0.33 | +0.68 (0.31) | +2.29 (0.70) | 5 |
| **all 28** | ALP | 28 | -0.65 | +0.50 | +0.50 | **+1.07 (0.38)** | +0.45 | 20 |
| **all 28** | Coalition | 28 | -0.33 | +0.65 | +0.42 | **+1.09 (0.36)** | +0.81 | 20 |

Level mass dropped before the seats see it (100 minus the sum of the level vector, points): nt2016 8.1,
nt2020 3.8, nt2024 14.8, wa2005 1.6, qld2012 1.2, wa2008 1.1; every other election under 0.3.

Signed seat error by stage (ours minus actual, points; positive = over-call; mean over every seat-class cell
where the class stood; SE of the final column clustered on election, n = elections / cells):

| jurisdiction | party | n | level | stage-1 renorm | base_pred | xgb | final (SE) |
|---|---|---|---|---|---|---|---|
| fed | ALP | 7 / 1051 | n/a | +1.66 | +2.25 | +2.51 | +1.80 (0.98) |
| nsw | ALP | 4 / 372 | -0.23 | -0.36 | -0.04 | -0.00 | +0.23 (1.35) |
| nt | ALP | 3 / 73 | -2.75 | -0.81 | +1.44 | +2.05 | +2.40 (0.15) |
| qld | ALP | 5 / 457 | -0.55 | +0.02 | +0.65 | +0.70 | +0.43 (1.33) |
| sa | ALP | 5 / 227 | -0.93 | +0.74 | +1.00 | +1.05 | -0.14 (0.57) |
| vic | ALP | 4 / 351 | -0.68 | -0.65 | -0.45 | -0.55 | -0.67 (0.64) |
| wa | ALP | 7 / 397 | +0.09 | +0.30 | +0.65 | +0.67 | +0.92 (1.58) |
| fed | Coalition | 7 / 1051 | n/a | -0.65 | -0.07 | +0.04 | -0.04 (0.53) |
| nsw | Coalition | 4 / 372 | -0.35 | -0.39 | +0.30 | +0.06 | +0.44 (0.51) |
| nt | Coalition | 3 / 73 | -1.84 | +2.03 | +3.05 | +3.02 | +3.38 (2.13) |
| qld | Coalition | 5 / 457 | -0.38 | +1.38 | +1.96 | +2.20 | +0.98 (0.55) |
| sa | Coalition | 5 / 227 | -1.58 | -0.18 | +0.09 | +0.02 | -0.72 (0.72) |
| vic | Coalition | 4 / 351 | -0.96 | -1.57 | -1.36 | -1.70 | -1.14 (1.22) |
| wa | Coalition | 7 / 396 | +1.56 | +1.91 | +2.44 | +2.52 | +2.23 (0.73) |

(The stage-1 columns use the stage-1 level, which had the recent-poll blend off; the final column uses the
stage-6 level. The xgb column is the as-at prediction from the stage-1 base, the one the cache holds; the
stage-6 re-prediction from the stage-6 base is not saved on disk. The level column is cell-weighted, which is
why it differs slightly from the per-election table above.)

Reading the two tables together: the departure is **not a WA or NT parameter**. It is one mechanism present in
every state, sized by how much level share the seats cannot hold, and NT is where that share is largest. The
xgb layer does not remove it (base_pred to xgb moves the departure by under 0.3 almost everywhere), which fits
the trees learning a residual on top of `base_margin` rather than the level constraint.

## Proposed fix

`AUSPOL_LEVEL_CONSERVE` (new, default "0"): after nomination zeroing, rake the seat x class matrix so each
standing class's vote-weighted implied statewide equals its level (the level first rescaled to 100 over the
classes that stand), rows still summing to 100. Arms at `base_pred` (reaches xgb through base-delta) and at the
final shares, both measured, per the base_pred-and-xgb rule. Draft prereg, criteria in SEs clustered on
election: `docs/plans/prereg-level-conserve-2026-10-25.md`. Not built.

Two things it will NOT fix, said now so they are not expected of it:
- **nt2024's dead-party level** (OTH 14.8 for a party that did not stand). Conserving the level makes nt2024's
  CLP seats WORSE (49.1 -> about 46.5 against 48.9). The level model needs its own fix: a class with no
  candidates should give up its level by flows or polls before the seats see it, not by default pro rata.
- **WA's level over-call of the Coalition** (+1.61 over 7 elections). That is a level question; the screen of
  2026-10-25 refused a jurisdiction correction to it.

## Not checked (unverified)

- How big the departure is in the live vic2026 forecast (same code shape, grep only).
- The federal harness's level, so fed's departure is not in the first table.
- The exact per-stage values from a traced run (both seats' "about" rows), for the memory reason above.
