# Pre-registration: make party shares sum to 100 by construction

Written 2026-08-18, **before anything is built or run**. Committed before any
result.

## The problem, measured

Each party's trend is fitted independently, so the fitted shares only sum to
100 by luck. Measured at the cycle endpoint:

| cycle | endpoint FP sum | check |
|---|---:|---|
| federal | 98.9 – 101.2 | passes |
| Victoria 2026 | 97.5 | passes (bound 100 ± 5) |
| **NSW 2027** | **94.1** | **fails** |

On 2026-08-17 that failure halted the whole daily pipeline, and the Victorian
forecast stopped refreshing for an election 102 days away because of a
validation cycle for one in 2027. That coupling has since been removed
(`run_all.R` now separates target from validation stages), so this is no longer
urgent — but it is still the **largest remaining structural approximation in
the model**, and thin-polling cycles are where it bites first.

Note what is already compensated: `derive_tpp()` renormalises first preferences
to 100 before computing the two-party figure, so a drifting sum does not
corrupt the published two-party number. What it does corrupt is the first
preferences themselves, which the page publishes, and any seat model built from
them — which now includes the candidate-level one.

## Candidates, fixed now

| | approach | keeps the exact sparse solve? |
|---|---|---|
| **A** | leave it (renormalise only where already done) | yes — the incumbent |
| **B** | soft sum-to-100 prior per day, mirroring the existing weighted sum-to-zero on house effects | yes |
| **C** | additive log-ratio: model K−1 log-ratios against a reference party | yes |
| **D** | multinomial-logit / softmax | **no** — costs the exact solve |

B is listed because the machinery already exists: `R/trend.R:119-124` builds a
soft weighted sum-to-zero prior on house effects by adding `outer(w, w)/szc_sd²`
into the precision matrix. A sum-to-100 constraint across parties on the same
day is the same shape.

D is named so that not testing it is a recorded decision rather than an
oversight: it is the textbook answer and it forfeits the property that makes
this model seconds rather than minutes per cycle. It is tested only if B and C
both fail.

## Criterion

**Held-out two-party MAE**, on the same strict temporal backtest the other
constants were chosen with (`scripts/compare_backtest_model.R`) — every
election predicted using only elections held strictly earlier.

Reported alongside, and **not** decisive on its own: the endpoint FP sum per
cycle, and runtime per cycle.

The sum is deliberately *not* the criterion. Optimising a model to make its
shares sum to 100 while forecasting worse would be fitting the diagnostic
rather than the outcome — the sum is what alerted us, not what we care about.

## Decision rule, fixed now

1. **Adopt the lowest held-out MAE**, provided it beats the incumbent (A) by
   more than **0.02 MAE** — the same bar `szc_sd_pts` and `sigma_house` were
   held to, so this change is not admitted on a looser standard than the
   constants around it.
2. **A coupling that does not improve held-out error is still adoptable if it
   is neutral** — within 0.02 either way — **and** brings every cycle's endpoint
   sum inside 100 ± 2. Structural correctness is worth having for free; it is
   not worth paying accuracy for.
3. **If a coupling improves the sum but costs more than 0.02 MAE, reject it**
   and record that the independent fit is better despite being structurally
   wrong. That is a legitimate outcome and would be worth knowing.
4. **Runtime is a veto, not a criterion.** Any candidate more than 5× the
   incumbent per cycle is rejected regardless of accuracy. A backtest that
   takes an hour stops being re-run, and constants that are expensive to
   re-examine stop being re-examined.

## Threats, stated before the run

- **The scale-transform trap.** Moving to log-ratios (C) changes the units every
  prior is expressed in. This project has already been bitten by exactly that:
  adding a logit scale means translating every hard-coded prior or it fails
  silently. `sigma_house`, `szc_sd_pts`, the walk sigmas and the binomial floor
  are all in percentage points. **Any C variant must translate them explicitly
  and assert the translation**, not inherit them.
- **A renormalised model is not the same model.** Rescaling shares changes the
  variance structure too, and reporting bands that were computed pre-rescale
  beside means computed post-rescale would be the two-model-paths error again.
- **NSW 2027 is the worst case and the smallest sample.** Whatever wins must be
  judged on the full backtest, not on whether it rescues the one cycle that
  motivated the work.
- **The endpoint sum is one number per cycle.** With few cycles it is a weak
  signal, which is the second reason it is not the criterion.

## What would make this not worth doing

If A wins on held-out error and no candidate brings the sums inside 100 ± 2
without cost, the honest outcome is to keep the independent fit, document that
the sums drift, and rely on the renormalisation `derive_tpp()` already performs
— extending the same renormalisation to the published first preferences and the
seat model's inputs, so every consumer sees shares that sum to 100 even though
the fit does not produce them.
