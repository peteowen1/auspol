# Pre-registration: an additive lift for signal first-timers, fitted on the published share (2026-11-09)

Written BEFORE the arm ran. Lever 2 of `docs/reviews/newcomer-independents-walk-2026-11-09.md` (Pete, 9 Nov: "Figure out
where in our forecast pipeline we can make adjustments for these to help predictions"; "Go" on lever 2). Follows the
refusal of `prereg-new-ind-shrink-signal-2026-11-09.md` Amendment 1, whose lesson was: a lift fitted on `base_pred`
double counts, because the trees already add their own signal correction; fit on what the model publishes.

## What the residual looks like (published share, 9 Nov 10:42 rebuild)

First-time sole independents (`new_ind_cells()`), 626 cells across the 35 elections; 75 carry a pre-election signal
(`c200`, `voices`, `council_elected` or `council_mayor` above 0). Residual = actual minus published, points, by band
of our published call:

| Published call | Signal cells | Our call | Actual | Under-call | SD |
|---|---|---|---|---|---|
| 0-3 | 13 | 1.9 | 5.1 | +3.2 | 4.2 |
| 3-6 | 23 | 4.4 | 8.2 | +3.7 | 5.2 |
| 6-10 | 16 | 7.5 | 12.1 | +4.6 | 8.9 |
| 10-15 | 11 | 12.0 | 12.9 | +0.9 | 5.3 |
| 15+ | 12 | 20.2 | 26.8 | +6.6 | 6.5 |

Flat across the band (linear fit: intercept +3.0, slope 1.11), so the correction is a number of POINTS added, not a
multiplier. A multiplier fitted on the published share is 1.5-2.2, which would again take Lane Cove from 19 to ~32.
The no-signal cells (551) run +1.1, +0.8, -2.0, +2.0, -0.8 by the same bands, and are left alone.

## Arm

`AUSPOL_NEW_IND_LIFT=1` (`R/new_ind_lift.R`). For target T: training cells are the signal first-timer cells of every
scored election dated strictly before T; residual `actual - ours` from `output/published-predictions.csv` (each
`ours` came from as-at models, so it was a genuine forecast). Mean residual per jurisdiction, SE clustered on
election, partially pooled toward the all-jurisdiction mean (DerSimonian-Laird). The target's signal cells get the
shift added (bounded to [0, row total]); the seat's other classes give it up pro rata. Applied as the LAST share step
(after the final nomination zero and `level_conserve_apply(stage = "final")`), xgb layer only in the harnesses, and
at the same point in `fit_seats_full.R`.

Dry run (`new_ind_lift_fit()`, before any arm), shift in points: fed2016 +3.30, fed2019 +3.06, fed2022 +2.38,
fed2025 +4.40, nsw2019 +2.63, nsw2023 +4.54, qld2017 +2.39, qld2020 +3.25, qld2024 +4.52, sa2018 +2.94, sa2022 +3.14,
sa2026 +3.88, vic2014 +3.45, vic2018 +4.36, vic2022 +5.08, vic2026 (live) +3.73, wa2017 +2.55, wa2021 +2.78, wa2025
+3.50, nt2020 +3.25, nt2024 +4.42. Training cells 15-75 in 5-20 elections; tau2 0-3.7.

Dry run of criterion 1 on the published file (shift added, no renormalisation of other classes): 75 cells in 20
elections, squared error 4,053.5 -> 3,403.2 (-650), SE 517 clustered on election, i.e. 1.26 SE. Best fed2022 -409,
nsw2019 -142, sa2022 -127; worst vic2022 +148, fed2016 +83, fed2025 +65.

## Criteria

Baseline: the shipped configuration at the same seed and sims (`scripts/quick_arm.R`, common random numbers), all 35
elections, 1,000 sims. A pass goes to the 20k deciding run before shipping.

1. PRIMARY (targeted): squared share error on the changed cells falls by more than 1 SE (cells' errors summed, SE
   clustered on election), AND stays below zero with any one election left out.
2. GUARD: 35-election seat-winner log loss rises by no more than 1 SE (clustered on election).
3. GUARD: AEF-7 ledger subset rises by no more than 1 SE.
4. DISQUALIFIER: any single election's seat-winner log loss rises by more than 0.02 (Amendment 1's nsw2023 was
   +0.052), or vic2022's by more than 0.005 (the live state's latest election).

Ship (to the 20k run) if 1 passes, 2 and 3 hold and 4 does not fire; otherwise off and to Pete with the cells.

## Named in advance, so they cannot be invented after the result

- The bar is 1 SE, not the 2 SE of the shrink preregs, BECAUSE the dry run above puts the expected effect at 1.26 SE:
  a 2 SE primary could only refuse (PRE-REGISTRATION-RULES: size the MDE before choosing the primary). The
  leave-one-election-out clause stands in for the lost margin; fed2022 alone carries -409 of -650.
- Expected losers, all signal cells we already called near or above the actual: Vaucluse 2023 (21.3 -> ~25.8, actual
  17.1), Deakin 2025 (12.0 -> ~16.4, 7.1), Sturt 2025, Caulfield, Bellarine and St Albans 2022 (Victorian
  councillors). Expected winners: Dubbo 2019, Flinders 2022, Blaxland 2025, Pittwater 2023, Mackellar and Nicholls
  2022. vic2022 is expected WORSE on squared error (+148 in the dry run); clause 4's vic2022 line is about log loss.
- SHIP BLOCKER, not a screen criterion: once shipped, `published-predictions.csv` would carry the lifted `ours`, and the
  next fit would learn the residual of the corrected forecast and drift back toward 0. Before shipping, the harnesses
  must write the pre-lift share (a `pred_share_prelift` column in sharedetail, carried by
  `build_published_predictions.R`) and the fit must read it. The screen is unaffected: its copied
  `published-predictions.csv` comes from the shipped 9 Nov rebuild, lift off.
- Search interest stays out of the signal list for the same reason as the shrink prereg (no cut-off that is not fitted).
- Not added to `post_xgb_switches()`: the lift runs after `xgb_primary_override()` records its reference, and is gated
  to `AUSPOL_XGB_PRIMARY=1`, so it can never enter a stage-1 base.

## Result, screen (quick_arm, 1,000 sims, all 35, 9 Nov 6:56pm, code 0a816ba5): PASSES, goes to the 20k deciding run

Log `output/quick-arm-newind-lift-1109.log`. 404 of 19,616 cells changed (the lifted cells and the classes that gave
up share), in 19 elections; 16 byte-identical. Largest share move 5.08 points.

1. PRIMARY: changed-cell squared error 9,768.9 -> 8,979.1 (-789.8, -8%), SE 686.9 = 1.15 SE: passes the 1 SE bar.
   Leave-one-election-out: the largest gain is fed2022 -481.0; without it -308.8, still below zero. PASSES.
2. GUARD: 35-election seat log loss 0.3005 -> 0.3006 (+0.0001, SE 0.0009): holds.
3. GUARD: AEF-7 0.2522 -> 0.2522 (+0.0001, SE 0.0043): holds.
4. DISQUALIFIER: worst single election fed2025 +0.0106 (bar 0.02); vic2022 -0.0023 (bar +0.005): does not fire.

Seat log loss per election: fed2022 -0.0136, vic2022 -0.0023, qld2020 -0.0007; fed2025 +0.0106, nsw2023 +0.0073,
vic2018 +0.0009; the rest within 0.0005. Squared error: fed2022 -481, nsw2019 -256, sa2022 -188, vic2010 -177; vic2022
+234, fed2016 +131, fed2025 +98, vic2018 +93.

Where the win chance moved most (independent share before -> after, actual; independent win chance):
- fed2025: Forrest 18.4 -> 22.8 (18.3), 0.22 -> 0.57, lost; Grey 16.0 -> 20.4 (17.5), 0.10 -> 0.28, lost; Fisher
  0.09 -> 0.27, lost; Bean 20.3 -> 24.7 (26.4), Fremantle 17.6 -> 22.0 (23.0), closer on share, both lost.
- nsw2023: Wakehurst 29.0 -> 33.5 (35.9), 0.42 -> 0.70, WON; Pittwater 22.7 -> 27.2 (35.9), 0.23 -> 0.55, lost
  narrowly; Vaucluse 21.3 -> 25.8 (17.1), 0.15 -> 0.43, lost; Lane Cove 0.06 -> 0.23, lost.
- fed2022: Curtin 0.35 -> 0.54 and Goldstein 0.43 -> 0.62, both WON; North Sydney, Mackellar up, both WON.
- vic2022: Hawthorn 13.7 -> 18.8 (20.0); Caulfield 11.2 -> 16.2 (6.5) and Bellarine 10.7 -> 15.8 (4.6), the
  councillors named in advance.

The gain is in share error; seat log loss is a wash (2022's teal wins paid for 2025's and 2023's near misses). Before
shipping, the ship blocker above (a pre-lift share column the fit reads) is still required.

### Ship blocker BUILT (9 Nov, 7:10pm, while the deciding run runs from its 13d88c25 snapshot)

Each harness keeps the lift's log (`NIL_LOG`, fed `X$nil_log`) and passes it to `seat_share_rmse(prelift =)`, which
writes `pred_share_prelift` into sharedetail only when the lift is on (lift off: format byte-unchanged).
`build_published_predictions.R` carries it as `ours_prelift` (= `ours` for runs with the lift off), and
`.nl_read_published()` fits on `ours_prelift` whenever the file has it. Checked on real input: quick_arm sa2022 at 200
sims, arm sharedetail Flinders IND 11.10 published, 7.96 pre-lift (the baseline's 7.96), Hammond 14.76 / 11.62; the
baseline file has no new column. Same squared-error change as the screen (-188.4). Tests in
`tests/testthat/test-new-ind-lift.R`.

## Result, deciding run (20,000 sims, all 35, 9 Nov 8:18pm, code 13d88c25, `deciding-runs/20261109-1858-newind-lift`): PASSES

Same as the screen. 404 cells changed in 19 elections.

1. PRIMARY: 9,770.2 -> 8,980.5 (-789.7), SE 686.8 = 1.15 SE (quick_arm's own label says FAIL at its default 2 SE; this
   prereg's bar is 1 SE, set before the run for the reason above). Without fed2022 (-481.1): -308.6. PASSES.
2. GUARD: 35-election seat log loss 0.3083 -> 0.3084 (+0.0000, SE 0.0010): holds.
3. GUARD: AEF-7 0.2530 -> 0.2528 (-0.0001, SE 0.0044): holds.
4. DISQUALIFIER: worst fed2025 +0.0106, nsw2023 +0.0070; vic2022 -0.0017: does not fire.

Live vic2026 (published shares in `output/seat-shares-vic-2026.csv`): two signal first-timers, both councillors,
Ringwood (Prue Cutts) IND 3.4 -> ~7.1 and Williamstown (Tony Briffa) 3.8 -> ~7.5 at shift +3.73. No seat changes
hands.
