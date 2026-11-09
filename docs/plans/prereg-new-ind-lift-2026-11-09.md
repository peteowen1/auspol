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
