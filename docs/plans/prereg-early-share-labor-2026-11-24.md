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

## RESULT

(to be filled in)
