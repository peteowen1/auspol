# Pre-registration: unpolled classes must not draw phantom vote

Written 2026-09-20 16:50, before running. Found by decomposing nsw2023's
Labor forecast (36.5 trend -> 32.1 forecast, 37.0 actual) step by step
(`reviews/statewide-forecast-audit-2026-09-20.md`).

## The defect

`statewide_draws_as_at()` gives every class in `parties` a draw column.
A class the polls do not track (nsw2023: ONP, IND, OTH_RIGHT) has mean 0
and keeps `fallback_sd` (1.5), then `fp_extra_sd` (2.419) is added in
quadrature, so it is drawn from N(0, 2.85), floored at 0.1 and the row
renormalised to 100. The expected value of that draw is **1.1 points per
class**. nsw2023 has three such classes: 3.4 points of vote the polls said
did not exist, paid for by every polled class in proportion (Labor -1.2,
Coalition -1.1, Greens -0.4, Other -0.6) before any anchoring happens.
`forecast_statewide_for()` then folds those classes back into the Other
bucket and splits it by the prior election's ratio, so the phantom vote
lands in the minor bucket and the majors stay short. Every election with
at least one unpolled class is affected; most have two or three.

## The fix

A class with no fitted series and zero mean draws exactly zero (its sd is
set to 0 before the draws), so the row's renormalisation is a no-op for
it. The downstream fold gives it its share of the Other bucket as before.
One line.

## Prediction and criterion

The majors rise by about 1 point each wherever classes are unpolled.

1. **Primary: mean |miss| over ALP/LNP/GRN first preferences across the 22
   audited pairs falls** (`scripts/audit_statewide_forecast.R`, SA2), with
   the paired difference at least one SE in favour (n = 22 pairs).
2. **Seat level, smoke**: nsw2023 and the federal harness (xgb off, 500
   sims) all-class RMSE against the actual result does not rise on either.
3. The deciding number is the ledger from rebuild v43.

**What would make a win unacceptable**: the audit passing because the
Other bucket's error fell while the majors' rose; the result reports the
majors separately.

# RESULT (17:20): criterion 1 NOT MET on its SE bar, criterion 2 met; kept provisionally, held for Pete

Statewide audit, mean |miss| over ALP/LNP/GRN (points, lower is better),
22 pairs: 1.758 -> 1.717, paired diff -0.041, SE 0.081. 11 pairs better
(vic2022 -0.60, fed2016 -0.48, sa2022 -0.45, vic2014 -0.45, qld2020 and
qld2024 -0.42), 2 flat, 9 worse (wa2005 +0.75, wa2025 +0.68, fed2022
+0.35, nsw2023 +0.30, wa2001 +0.27, wa2017 +0.25). By class, the mean
SIGNED miss: Labor -0.70 -> -0.01, Coalition -0.74 -> +0.28, Other +0.04
-> -0.46. The bug's signature (both majors under-forecast by three
quarters of a point) is gone; the Coalition now sits a quarter point
high, and the two WA pairs that worsened most are the ones where the
Coalition was already over-forecast. nsw2023's own Labor level improves
(the fix's first step) but the pair's mean |miss| rises because the
Coalition rises too.

Seat level (500 sims, xgb off, all-class RMSE against the actual result):
nsw2023 5.483 -> 5.424 (-0.059; Labor 7.73 -> 7.43, Coalition 5.99 ->
6.37); federal 4.023 -> 4.013 (-0.010; fed2010 -0.6 both majors, fed2019
+0.3/+0.4). Neither rose.

Disposition: a class the polls put at zero should draw zero; the fix
removes 0.7 points of systematic major-party under-forecast. The
remaining asymmetry (Coalition now high where Labor is right) is the
anchoring's, which is the next arm. Rebuild v43 decides the ledger.

# RESULT, rebuild v43 (2026-09-20 16:13): REFUSED, reverted

Ledger (660 seats, lower is better): seat log loss 0.2943 -> **0.3022**
(AEF 0.2851), weighted primary RMSE 5.15 -> 5.18, TCP MAE 3.99 -> 4.08.
Per pair, v42 -> v43: wa2025 0.284 -> 0.361 (+0.077), sa2026 +0.018,
fed2025 +0.009, nsw2023 0.293 -> 0.301 (+0.008), qld2024 -0.003,
vic2022 -0.012, fed2022 -0.004. All-seat pooled over 20 pairs 0.3326 ->
0.3357.

The smokes were right about the primaries (nsw2023 and federal all-class
RMSE both fell) and wrong about what matters: removing the phantom vote
raised the Coalition's statewide level everywhere it was already high
(the audit's +0.28 signed miss), and at 20,000 sims with the xgb layer on
that cost more seats than the Labor correction won. wa2025, where the
Coalition was over-forecast before the fix, is the clearest case.

**What this says**: the phantom vote was real, but it had been partly
compensating for the anchoring pushing the Coalition up (the same
asymmetry seen on wa2001 after the Nationals fold). Removing one leg of a
compensating pair is a regression until the other leg is fixed. The line
is reverted; the mechanism stays documented here and in the code comment,
and the anchoring arm must be designed with it (the two are one change).
Stage 9 did not run, so the release and artifact still carry v42; the
local `output/` ledger files are v43 until the next rebuild.
