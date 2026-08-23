# Pre-registration: backtest the model we actually publish

Written 2026-08-22, **before anything is measured**. Committed before running.

## The problem this fixes, which is not the one it looks like

The four backtest harnesses take each election's **actual** statewide first
preferences and swing them across seats. Two consequences, and the second is the
serious one:

1. **The comparison with AE Forecasts is unfair in our favour.** Their number is
   a genuine forecast that knew polls and nothing else. We score 0.524 log loss
   against their 0.276 anyway, so the advantage is not what is beating us.
2. **We are not backtesting the model we publish.** `fit_seats_full.R:573`
   passes `statewide_draws` — statewide vote drawn from the projection, with
   party correlation. **No harness does.** `simulate_seat_contests()`'s own
   documentation records that dropping that covariance made the seat range
   "roughly 40% too tight".

So every calibration figure this repo has ever quoted describes a **tighter
variant than the one it ships**, and nothing measures the published
configuration at all. That is the same failure as the two seat models, in a new
guise, and it survived because backtest numbers look like model numbers.

## What changes

Each harness gains a forecast mode, off by default:

- the statewide vector comes from `trend_as_at(as_at = election day − 1)`
  instead of from the target election's result;
- the resulting uncertainty is carried into `simulate_seat_contests()` through
  the existing `statewide_draws` argument, exactly as the published path does.

Nothing else moves. Flows, seat baselines and the seat-swing spread are already
sourced from strictly earlier elections and are already leakage-free.

## Leakage

`trend_as_at()` truncates polls at `keep <- cp$date <= as_at`
(`R/projection.R:79`), and this is asserted rather than assumed:
`tests/testthat/test-projection.R:101-117` fits the same Victorian cycle at two
cutoffs and requires both the poll count and the fitted TPP to differ.

**A leakage guard is still required per election**, because a passing unit test
on one cycle is not a guarantee across ten. Each harness must assert that the
polls reaching the trend are dated strictly before the election being predicted,
and abort otherwise.

## The two decisions, made now rather than during the run

**D1 — a party below the poll-inclusion floor.** `trend_as_at()` returns no
entry for a party with fewer than 8 polls in the cycle. One Nation has **6 in
vic2018, 3 in vic2022, 7 in nsw2023**, and 12 in sa2026.

> **Decision: fold it into `OTH` via the existing `refold_unfitted()` path**,
> which is what the live path already does, and record per election which
> parties were folded. The alternative — carrying the previous result forward —
> invents a series the polls do not support, and would be a new estimator
> introduced silently inside a calibration experiment.

This means **vic2018, vic2022 and nsw2023 cannot test One Nation seat
probabilities at all** in forecast mode. Stated now: sa2026 is the only election
in the corpus that does.

**D2 — where the statewide draws come from.** The projection's own held-out
error, via `fit_projection_error()`, drawn with the party correlation already
estimated in `output/statewide-cov.rds` and already used by the published path.

> **Decision: reuse the published path's construction unchanged.** The point of
> this experiment is to measure what we ship, so any bespoke error model built
> here would defeat it.

**The short-horizon error is not yet measured.** The finest horizon ever scored
in this repo is 30 days (TPP MAE 1.84); these backtests need roughly 1 day. The
true error at that horizon is presumably smaller, but that is an extrapolation.
**Measuring it is part of the work, not an assumption**, and the measured value
is reported with the result whatever it turns out to be.

## What is measured

Per-seat log score, accuracy, Brier and **calibration slope**, leave-one-
election-out, clustered on the election — plus the reliability table (claimed
versus actual, by band), because the slope alone hides where the miscalibration
lives.

Reported against the benchmark: **AE Forecasts' pooled slope 1.14 and log loss
0.2802**.

## Decision rule, fixed now

This is not a "does it improve the score" experiment. Forecast mode uses
**strictly less information**, so its log score is **expected to get worse**.
Judging it on log score would guarantee refusal of the correct change.

- **Adopt forecast mode as the reported configuration if its calibration slope
  is closer to 1.0 than the current harness's**, on the pooled nine elections.
  That is the quantity the change exists to fix.
- **The log score is reported, not judged.** It will fall. A fall is not a
  refusal.
- **If the slope moves AWAY from 1.0**, refuse and investigate: that would mean
  statewide uncertainty is not what makes us over-confident, which is a finding
  about the seat model rather than about the harness.

## Refusals

- **F1 — the leakage guard must fail on a broken input.** Deliberately feed a
  cutoff after the election and confirm the assertion fires, before trusting any
  arm that passes it.
- **F2 — the default path must be byte-identical.** With forecast mode off,
  every harness must reproduce its current output exactly. Otherwise the change
  is doing something besides adding a mode.
- **F3 — no tuning inside this experiment.** `SHRINK`, `seat_sd`, `party_sd` and
  the correlation matrix keep their current values throughout. The temptation
  will be to re-tune once calibration is finally measurable on the right
  configuration; that is the NEXT experiment and needs its own plan, or this one
  becomes a fishing trip with a benchmark attached.
- **F4 — the folded parties must be reported per election**, not silently
  absorbed. An election where One Nation vanished into `OTH` must not be quoted
  as evidence about One Nation.
- **F5 — the live forecast does not change.** This adds a backtest mode. If any
  published Victorian number moves, stop: nothing here should reach
  `fit_seats_full.R`.

## What this cannot see

- **Whether the published model is well calibrated in an absolute sense.** It
  measures the published *configuration* on past elections, which is a much
  better proxy than today's harness and still not the same as scoring the live
  forecast.
- **Whether AE Forecasts would still beat us on equal terms.** Forecast mode
  makes the comparison fair; it does not promise it becomes favourable, and the
  0.524-against-0.276 gap was measured while we held the advantage.
- **Seat-level TCP**, which we do not produce at all. That remains the largest
  unscored metric and needs its own work.
