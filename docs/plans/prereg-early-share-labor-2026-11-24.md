# Pre-registration: last election's early-vote share as a Labor correction

Written 24 November 2026, before any harness run. Pete: "go" on building and
screening it before polling day (28 November).

## What the change does

Where a lot of a seat's votes were cast early in person at the PREVIOUS
election, our model has rated Labor too high; where few were, too low. The
switch moves Labor's predicted primary by a slope times how far the seat's
previous early share sits from its election's average, and leaves the statewide
Labor total alone (the shifts sum to zero across a state's seats).

`AUSPOL_DEMO_RESID_EARLY`: `"0"` off (default), `"1"` on, `"shuffle"` the
placebo (the early-share column permuted between seats within each election).
It lives in `R/demographic_residual.R` beside the census correction, so all
seven harnesses and the live forecast reach it through the same call.

- Labor only. The Greens showed nothing in the screen.
- One slope, fitted on elections held before the one predicted (as-at misses of
  elections that have the feature), with the seven census columns partialled
  out so it measures what the census correction leaves. No intercept.
- Shrunk, not gated: `b * b^2 / (b^2 + se^2)`, `se` clustered on election. A
  weak slope goes to about zero by itself. No tuned constant.
- The census fit is untouched. A seat or election with no previous early share
  gets no shift.
- Input: `output/prev-early-share.csv` (`scripts/build_prev_early_share.R`),
  the previous election's counted early share by seat. For vic2026 that is
  vic2022, known since 2022.

## What has already been looked at (so this is not a clean test)

About 28 features times 6 party classes were screened on 22 elections
(`scripts/screen_early_vote.R`); this is the one that held. Both holdouts
(vic2022, fed2025) were opened. The same idea as an xgb tree feature tied a
shuffled placebo. A direct-correction scout at share level gave Labor RMSE
5.014 -> 4.960 over 14 elections (`docs/reviews/early-vote-scouts-2026-11-24/`).
**The only untouched election is vic2026.**

## Screen

`scripts/quick_arm.R`, 1,000 sims, every election that has the feature (16
expected), real arm and placebo arm against the shipped configuration.

1. **Identity.** Every election WITHOUT the feature must come back unchanged
   under both arms. If one moves, something else changed and the run is void.
2. **Primary: Labor's squared error on seats that have the feature**, through
   the harness, real arm paired against the placebo arm, SE clustered on
   election. Pass: better than the placebo by more than 1 SE and better in more
   than half the elections.
3. **Guards.** Pooled seat-winner log loss not worse than baseline beyond 1 SE.
   No Victorian election worse on seat log loss beyond its own noise (compare
   with the placebo arm's movement on the same election).
4. **Delivery.** The row rescale after the census correction delivers only part
   of a Labor shift. Print fitted against delivered; expect less than the
   scout's gain.

## The tie rule, written now

The scout moved 2 of 1,415 "is Labor ahead" calls, so seat log loss will very
likely read as a tie. If the primary passes and seats tie:

- It is a correctness improvement of about 0.05 points on Labor's primary.
- Shipping before Saturday still needs the builder in `rebuild_forecasts.sh`,
  a regenerated `demo-resid-vic2026.csv`, `check_like_ci.R`, the review gate
  and a registry regen.
- **My recommendation in that case is to ship after polling day, not before**,
  and the question goes to Pete with the vic2026 per-seat Labor shifts and the
  win-probability change for the biggest movers (Albert Park in particular:
  low early share in 2022, Labor 0.52 against the Greens 0.32).

If the primary fails, or a guard fails, it is refused and Pete is told with the
split.

## RESULT, 24 November 2026 5:58pm: PASSES every clause. Not shipped; the ship question is with Pete.

`quick_arm.R`, 1,000 sims, 16 elections, one process at a time; scored by
`deciding-runs/20261124-early-share-screen/score.R` (cache keys: baseline
`e9205f7ba140`, arm `2a4798fff10c`, placebo `691ce3c6e322`).

1. **Identity: pass.** sa2026, vic2010 and wa2013 (no previous early share, or
   too few earlier elections) came back with 0 of 329, 528 and 295 cells moved
   under both arms. The correction acts in 13 elections.
2. **Primary: pass.** Labor's squared error on the 1,265 covered seats, arm
   against placebo: -0.258 (SE 0.096 across elections), better in 9 of 13.
   Against the shipped model: arm -0.232 (SE 0.079, 10 of 13 better), placebo
   +0.026 (SE 0.028). Labor RMSE 4.954 -> 4.930, placebo 4.955. All parties,
   same elections (9,078 cells): 3.513 -> 3.507, placebo 3.513.
3. **Guards: pass.** Seat-winner log loss over 1,320 seats 0.2279 -> 0.2269
   (-0.0009, SE 0.0006, 9 of 13 better); placebo 0.2281 (+0.0004, SE 0.0004).
   The gain is mostly qld2024 (-0.0074) and fed2025 (-0.0041). Victoria:
   vic2014 -0.0002, vic2018 -0.0001, vic2022 -0.0001; none worse. quick_arm's
   own lines: all 16 elections -0.0008 (SE 0.0006), AEF-7 -0.0020 (SE 0.0011).
4. **Delivery.** The average covered seat's Labor share moved 0.00 to 0.26
   points per election (fed2025 0.26, qld2024 0.24, wa2025 0.22, vic2022 0.12),
   well under the scout's full-delivery shifts, as expected.

So this is better than the "seats tied" case the tie rule was written for: the
seat metric is better by about 1.5 SE, not tied.

**Two things changed after the screen, both from the review of `db25a16b`:**
the slope's standard error now carries the small-cluster factor G/(G-1), and
the regressors are re-centred after the row filter. For vic2026 the kept share
of the slope goes 93% -> 92% (shift per SD -0.561 -> -0.558); vic2022 76% ->
74%; fed2025 and nsw2023 change by under 1 point. The screened and fixed
versions differ by 1 to 3% of an already small shift, so the screen was not
rerun. A deciding run before any ship would use the fixed code.

**Correction to the text above:** the shifts sum to zero across a state's
covered seats BEFORE the row rescale; after it, Labor's statewide total can
move slightly. "Leaves the statewide Labor total alone" overstated it.

**vic2026, fitted shifts before the rescale** (slope -0.605, SE 0.175, 16
earlier elections; `deciding-runs/20261124-early-share-screen/vic2026-fitted-shifts.csv`):
31 of 87 seats move under 0.25 points, 23 between 0.25 and 0.5, 27 between 0.5
and 1, 6 over 1. Live seats that move most: St Albans -1.38 (Labor 63%),
Greenvale -1.11 (46%), Werribee -0.88, Monbulk +1.36 (24%), Preston +0.89,
Box Hill +0.80, Albert Park +0.75 (Labor 52%, Greens 32%). The effect on
vic2026 win probabilities has NOT been measured: it needs a live run with and
without the switch.

**LIVE WALK, 24 November 6:14pm** (Pete chose "Walk it live first").
`fit_seats_full.R` twice on this checkout, same seed, `AUSPOL_OUT_SUFFIX`
`-esbase` and `-esarm`; files moved to
`deciding-runs/20261124-early-share-screen/live/`; compared by
`docs/reviews/early-vote-scouts-2026-11-24/walk.R`. **Read the changes, not the
levels:** the local poll clone is from 14 November, so this baseline (Coalition
majority 31.4%) is not today's published forecast (35%).

- Labor's primary: 76% of the fitted shift is delivered; the average seat moves
  0.33 points, from -1.00 (Melton) to +1.44 (Eildon).
- Win probabilities: largest change in any seat-party cell 0.073; 34 of 616
  cells move by 0.02 or more, 6 by 0.05 or more.
- One favourite changes: Ringwood, Coalition 0.474 / Labor 0.429 becomes Labor
  0.462 / Coalition 0.445.
- Labor's win chance: Monbulk 0.256 -> 0.329, Ashwood 0.532 -> 0.588, Albert
  Park 0.472 -> 0.522 (Greens 0.384 -> 0.352), St Albans 0.693 -> 0.626,
  Greenvale 0.496 -> 0.432, Werribee 0.289 -> 0.244, Kororoit 0.501 -> 0.460.
- Expected seats: Labor 25.60 -> 25.60, Coalition 39.96 -> 39.85, One Nation
  14.91 -> 15.07, Greens 7.09 -> 7.05.
- Parliament: Coalition majority 31.4% -> 31.1%, hung 67.8% -> 68.2%, Coalition
  most seats 79.4% -> 79.1%.

**SHIPPING, 24 November 6:15pm: Pete chose "Ship for Saturday" after the live
walk.** `AUSPOL_DEMO_RESID_EARLY = "1"` in `published_flags.R`, the inline
default in `early_share_mode()` flipped with it (the promote step calls the
correction without applying the flags), and the builder runs before stage 6 in
`rebuild_forecasts.sh`. In flight until the release carries a regenerated
`demo-resid-vic2026.csv` and a daily run has used it.

**Still needed before a ship (the list as it stood before the decision):** the builder in
`rebuild_forecasts.sh`, a regenerated `demo-resid-vic2026.csv` through the
promote step, `check_like_ci.R`, a registry regen and the publish.
