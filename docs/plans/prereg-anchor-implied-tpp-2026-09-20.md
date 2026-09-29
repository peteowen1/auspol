# Pre-registration: anchor the draws to their own implied two-party, and zero the phantom vote, as one change

Written 2026-09-20 17:00, before running. Follows the nsw2023 walk and
the two refused arms (`prereg-fundamentals-drop-fed-aligned-2026-09-20.md`,
`prereg-phantom-minor-vote-2026-09-20.md`).

## The defect

`statewide_draws_as_at()` anchors the first-preference draws to
`w * trend_TPP + (1 - w) * fundamentals`, where `trend_TPP` is the trend's
PUBLISHED two-party series, and moves Labor by `d = target - implied` and
the Coalition by `-d`, where `implied` is the two-party the draws
themselves imply through the flows. The published series and the
flow-implied value disagree by up to 1.5 points (nsw2023 +1.0, fed2019
-1.5, wa2017 +0.6, vic2022 -0.4), so the anchoring spends primary-vote
points reconciling two estimates of the same quantity before the
fundamentals are even applied. On nsw2023 that step alone took 1.1 off
Labor; on fed2019 it added 1.5 to Labor, in a cycle where Labor was
already 2.2 high. The phantom vote of unpolled classes (1.1 points per
class, `prereg-phantom-minor-vote`) sits underneath and was found to be
offsetting the Coalition push on rebuild v43, so the two change together.

## The change

1. The mix's trend input is the draws' own implied two-party
   (`mean(implied)`), not the published series: `target = w * implied_mean
   + (1 - w) * fund`. The published TPP series stays as a diagnostic
   (`FS1`). The only thing the anchoring then does is apply the
   fundamentals' pull, `(1 - w) * (fund - implied_mean)`, symmetrically.
2. Unpolled classes draw exactly zero (`sd[folded] <- 0`).

Behind `AUSPOL_ANCHOR_IMPLIED` (default 0 until the result), so the arm
can be smoked against the shipped path in the same session.

## Prediction

nsw2023 Labor rises about 2.3 (1.1 + 1.2) toward 37.0; fed2019 Labor
falls about 1.5 toward 48.5; wa2001's Labor over-forecast shrinks; the
Coalition's +0.28 statewide signed miss after the phantom fix returns
toward 0 because the gap correction no longer pushes it.

## Criterion, in order

1. **Statewide audit** (`audit_statewide_forecast.R`, 22 pairs): mean
   |miss| over ALP/LNP/GRN falls by at least one paired SE, AND the
   majors' mean signed miss each sits within 0.3 of zero.
2. **Seat smokes** (500 sims, xgb off): nsw2023, wa (all seven pairs) and
   federal all-class RMSE none rises by more than 0.05.
3. **Rebuild v44 decides the ledger**: seat log loss must not rise above
   v42's 0.2943 (v43 rose to 0.3022 on a change that passed both smokes,
   so the smokes are necessary, not sufficient).

**What would make a win unacceptable**: the audit passing because
fed2019 alone moved (the largest single gap); the result reports the
audit with fed2019 removed. If 1 and 2 pass and 3 fails, the arm stays
off and the mix weight is re-examined against the implied series (the
weight was fitted to the published series' error, which is not the same
quantity).

## RESULT, criterion 1 (added 2026-09-27; everything above is unedited)

Built behind `AUSPOL_ANCHOR_IMPLIED` in `R/forecast_mode.R` (both halves) and
`scripts/fit_seats_full.R` (implied-anchoring half only: live Victoria's
unpolled classes draw around their seat mean, not 0 +/- 2.85, so it has no
phantom vote to zero). Audit: `scripts/audit_statewide_forecast.R` with
`AUSPOL_AUDIT_TAG`, both arms today on the same code
(`output/statewide-forecast-audit-base27sep.csv`, `-ai1.csv`). The 20 Sep
audit file is NOT the baseline: it was written while the v43 phantom-vote
fix was live.

- Mean |miss| ALP/LNP/GRN over 22 pairs: 1.758 -> 1.686, change -0.071,
  paired SE 0.093 (t -0.77). **Bar was -1 SE: FAILS.**
- Majors' mean signed miss: ALP -0.76 -> +0.22 (passes), LNP -0.68 -> +0.32
  (fails the 0.3 bound by 0.02).
- Without fed2019: -0.035, SE 0.090 (t -0.39); ALP +0.14, LNP +0.51.
- 13 of 22 pairs improve. Biggest gains fed2019 -0.83, vic2022 -0.66,
  vic2014 -0.50; biggest losses wa2005 +0.82, wa2025 +0.76, fed2022 +0.38,
  nsw2019 +0.38.
- Predictions checked: nsw2023's implied-vs-published gap was +1.42 and its
  anchored two-party rose 52.01 -> 53.03 (predicted direction); fed2019 gap
  -1.46, anchored 52.12 -> 51.07 (predicted direction).

Verdict on the pre-registered rule: criterion 1 not met, arm stays OFF.
The bias removal is real; the level gain is inside noise. The follow-up the
pre-registration names (re-examine the mix weight against the implied
series, since `w` was fitted to the published series' error) is the next
version of this arm.
