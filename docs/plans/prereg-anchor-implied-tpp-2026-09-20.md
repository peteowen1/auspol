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
