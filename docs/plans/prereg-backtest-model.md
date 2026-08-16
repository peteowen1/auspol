# Pre-registration: does the fuller trend model actually forecast better?

Written 2026-08-16, before the comparison is run. Committed before any result.

## The question

The published headline comes from `trend_as_at()`, which uses `fit_trend()`'s
default sigmas and no per-pollster noise factors. `fit_vic.R` estimates both.
The two have never been compared out of sample — one has been called "fuller"
and assumed better, which is an argument, not a measurement.

## The complication that may be the real reason

The fuller model has **two leakage vectors the simpler one does not**:

1. **Pooled sigmas.** `estimate_cycle_sigmas()` shrinks a cycle's volatility
   toward a pooled value, and in `fit_vic.R` that pooled value is estimated
   across validation cycles — including cycles *after* the one being
   backtested.
2. **Firm noise factors.** `estimate_firm_factors()` is fitted on past fits.
   In the live forecast "past" means everything; in a backtest it must mean
   strictly before the election under test, or a pollster's reliability is
   being learned from elections that had not happened.

Either, done carelessly, inflates apparent accuracy — the same failure already
recorded twice in `R/projection.R` for preference flows. **This is a plausible
reason the backtest uses defaults, and if so it deserves to be written down as
a decision rather than left looking like an oversight.**

## What is being compared

Two arms, both leakage-free by construction:

- **A — defaults (incumbent).** `fit_trend()`'s `default_sigmas()`, no firm
  factors. What is published today.
- **B — per-cycle sigmas, self-contained.** `estimate_cycle_sigmas()` using
  only that cycle's own polls up to the horizon cutoff, shrunk toward the
  **default** sigmas rather than a pooled value estimated across cycles. This
  removes leakage vector 1 by construction.

**Firm factors are deliberately out of scope.** Removing leakage vector 2
needs per-fold refitting of the factors, which is a larger change. If B wins,
that becomes the next question. If B loses, it is moot.

## Criterion and rule, fixed now

**Primary:** held-out MAE from `projection_loo`, leave-one-election-out, the
same criterion used for the mix weight, `szc_sd_pts` and the flow estimator.

**Decision:**

1. **A is the incumbent and wins ties.** Adopt B only if it beats A by more
   than **0.02 MAE**, the same bar used for the other two priors.
2. B must produce **the same number of usable election-horizon pairs** as A,
   within 5%. A model that silently drops cycles because its sigma estimation
   failed is not more accurate, it is fitted on an easier subset — the exact
   hazard `build_projection_data()`'s skip-accounting exists to catch. Report
   the counts.
3. If B wins, **every existing pre-registered check must still pass** before
   adoption, and `szc_sd_pts` must be **re-tuned** against B, since it was
   chosen against A.

## What is not a criterion

Not that B is more sophisticated. Not that B uses features this project spent
effort building. Sunk effort is not evidence.

## Expected outcome

Genuinely uncertain, and the uncertainty is informative either way. The
backtest spans horizons to 730 days out, where a cycle may have ~10 polls;
estimating volatility from 10 polls is noisy, and a badly estimated sigma is
worse than a sensible default. So B plausibly wins at short horizons and loses
at long ones. **If the overall result is close, the per-horizon breakdown is
the more useful finding** and will be reported whatever the headline says.
