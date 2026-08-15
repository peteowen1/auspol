# auspol

Australian election modelling and forecasting in R — a 538-style forecast with a
journalistic, interactive presentation. Anchored on the
[AE Forecasts](https://www.aeforecasts.com/) methodology
([d-j-hirst/aus-polling-analyser](https://github.com/d-j-hirst/aus-polling-analyser)).

Full analysis of the anchor model (methodology, data sources, improvement
targets): [`docs/ANCHOR-MODEL.md`](docs/ANCHOR-MODEL.md). Work queue, measured
findings and negative results: [`docs/NEXT-STEPS.md`](docs/NEXT-STEPS.md).
Comparison against the other Australian forecast sites and the case for what to
build: [`docs/plans/product-features.md`](docs/plans/product-features.md).

## Status

The pipeline runs end to end: **polls → trend → projection → seats**, with
prediction intervals validated as calibrated.

Current live target is **Victoria, 28 November 2026**.

| stage | what it does | entry point |
|---|---|---|
| Trend | Jackman-style latent voting intention: daily random walk plus pollster house effects. All-Gaussian, so the posterior is exact via one sparse solve — seconds per cycle, no MCMC. | `fit_trend()` |
| Hyperparameters | Observation noise and walk size estimated by exact marginal likelihood, per party and per cycle, plus per-pollster noise factors. | `estimate_trend_sigmas()`, `estimate_cycle_sigmas()` |
| Two-party | TPP derived from first preferences via historical preference flows, with optional-preferential exhaust handling for NSW. | `derive_tpp()` |
| Fundamentals | Expected result from history alone — previous result, long-run average, incumbency, years in office, federal alignment — by ridge regression chosen leave-one-election-out. | `fit_fundamentals()` |
| Projection | Mixes trend and fundamentals by days-to-election, with the weight fitted on past elections. | `project_result()` |
| Seats | Simulates a seat count: statewide draw, regional block effect, per-seat residual. | `simulate_seats()` |
| Scorecard | Per-pollster lean, noise against the binomial sampling floor, and final-poll accuracy. | `pollster_scorecard()` |

Not yet built: a website, and the anchor's per-seat elasticity and candidate
effects (retirement, sophomore surge).

## Discipline

Every stage carries **pre-registered checks** — assertions written before
looking at the output, chosen so a plausible-looking wrong answer still fails.
They run inside the fit scripts and stop the pipeline. Examples: the 2022
federal endpoint must land in a stated range around the known result; fitted
vote shares must sum to 100; a zero-swing seat simulation must reproduce the
last election's seat count.

That has repeatedly mattered. Nearly every real bug found here produced
plausible output and was caught only by a check against a number someone
already knew.

The same discipline killed several plausible ideas. Fat-tailed poll noise, an
asymmetric error distribution, and a per-horizon bias correction were each
built, measured out of sample, and found not to help — the bias correction was
actively making the forecast worse. They are documented in
[`docs/NEXT-STEPS.md`](docs/NEXT-STEPS.md) so they are not rebuilt.

## Setup

```r
# one-off: clone the anchor repo for data
# git clone https://github.com/d-j-hirst/aus-polling-analyser external/aus-polling-analyser

devtools::load_all()
devtools::test()
```

The anchor's poll and reference CSVs are read from that local clone under
`external/` (gitignored). The data has no formal licence, so it is never
committed here; licensing contact with the author is on the queue.

Run a pipeline (PowerShell, not Git Bash — arrow segfaults there):

```powershell
Rscript "scripts/fit_vic.R"          # Victoria: 2018 and 2022 validation + live 2026
Rscript "scripts/fit_federal.R"      # federal 2022, 2025, 2028
Rscript "scripts/fit_nsw.R"          # NSW 2023, 2027
Rscript "scripts/fit_projection.R"   # fundamentals + trend-vs-fundamentals mix
Rscript "scripts/fit_seats.R"        # seat simulation (reads projection output)
Rscript "scripts/fit_scorecard.R"    # pollster scorecard
```

`fit_projection.R` must run before `fit_seats.R`. Outputs land in `output/`
(gitignored): trend CSVs and plots per cycle, hyperparameters, seat
simulations and the scorecard.

## Conventions

Repo follows the `C:\dev` house rules: work on `dev`, merge to `main` via
reviewed PR, data outputs stay out of git.
