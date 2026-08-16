# Pre-registration: do per-pollster noise factors improve the forecast?

Written 2026-08-16, before implementation. Committed before any result.

## The question

`estimate_firm_factors()` measures how noisy each pollster is relative to the
others, and the published forecast **does not use it** — `trend_as_at()` calls
`fit_trend()` with `firm_factors = NULL`, so every poll carries equal weight.
The page now says so plainly. Whether using it would help has never been
tested.

## Stated expectation, before running

**I expect this to fail**, and the reasoning is on the record so the result
cannot be reinterpreted afterwards:

- Per-cycle volatility — the same family of "more sophisticated weighting"
  change — gained **0.0041 MAE for 33× the runtime** and was rejected.
- `sigma_house_pts` turned out to be at its optimum already, and `szc_sd_pts`
  moved but bought 1.3%. The pattern so far is that this model's remaining
  gains are small.
- Down-weighting a noisy pollster helps only if noisiness is *stable* for a
  firm across elections. If it is mostly cycle-specific, the factor is fitted
  noise and will hurt.

If it succeeds anyway, that is the interesting outcome and worth the runtime.

## The leakage vector, and how the design removes it

This is the part that makes firm factors harder than volatility.
`estimate_firm_factors()` is fitted on residuals from *past fits*. In the live
forecast "past" means everything; **in a backtest it must mean strictly
earlier than the election under test**, or a pollster's reliability is being
learned from elections that had not happened. That is the failure recorded
twice in `R/projection.R` for preference flows and once, by me, for
hyperparameters.

Two candidate designs, and only one is affordable:

- **Cross-cycle factors, done honestly** — refit every prior cycle per fold to
  get residuals, then estimate factors, then fit the target. Correct, and
  roughly the cost of arm B again or worse. Out of scope.
- **Self-contained two-pass (the arm being tested)** — within one cycle,
  truncated at the horizon cutoff: fit once with equal weights, estimate firm
  factors from *those* residuals, refit with them. Nothing outside the cycle
  and nothing after the cutoff can reach it. Roughly **2× the fits**, not 33×.

The self-contained version tests a weaker claim — "noisiness is detectable
*within* a cycle and worth acting on" — and that is the honest framing of what
is being measured.

## Criterion and rule, fixed now

**Primary:** held-out MAE from `projection_loo`, leave-one-election-out, the
same criterion used for `szc_sd_pts`, `sigma_house_pts`, the flow estimator
and the volatility comparison.

**Decision:**

1. **Equal weights is the incumbent and wins ties.** Adopt factors only if
   they beat equal weighting by more than **0.02 MAE** — the same bar.
2. **Coverage must match within 5%**, and any pair skipped with reason
   `error` fails the comparison outright. A model that drops difficult cycles
   is fitted on an easier subset, not more accurate.
3. Any adopted version must **pass every existing pre-registered check**, and
   interval coverage (`B2`/`B3`) must still hold.
4. Report the **per-horizon split regardless of the headline** — and read
   alternating signs as noise, as they were for per-cycle volatility, rather
   than picking the favourable horizon.

**Runtime is part of the decision.** At roughly 2× it is affordable; if the
implementation turns out to cost 10× or more, the bar rises, because a
backtest that takes an hour makes every future constant expensive to
re-examine and constants that are expensive to re-examine stop being
re-examined.

## What is not a criterion

That the factors look plausible. That the project already built
`estimate_firm_factors()` and it would be a shame not to use it — sunk effort
is not evidence. That it makes the scorecard's Variability column feel more
justified.
