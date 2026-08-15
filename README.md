# auspol

Australian election modelling and forecasting in R — a 538-style forecast with a
journalistic, interactive presentation. Anchored on the
[AE Forecasts](https://www.aeforecasts.com/) methodology
([d-j-hirst/aus-polling-analyser](https://github.com/d-j-hirst/aus-polling-analyser)).

How the pieces fit, the load-bearing decisions, and the hazards that have
actually bitten: [`ARCHITECTURE.md`](ARCHITECTURE.md).

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

The forecast is published as a self-contained page — see `build_page.R`.

Not yet built: the anchor's per-seat elasticity and candidate effects
(retirement, sophomore surge), and an elimination-aware preference simulator.
None is likely to move the headline much: seat mechanics contribute a standard
deviation of about 4 seats against 11 from the statewide vote, so accuracy in
the projection is worth more than refinement below it.

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

Run everything, in the one order that works (PowerShell, not Git Bash — arrow
segfaults there):

```powershell
Rscript "scripts/run_all.R"              # ~5 minutes
Rscript "scripts/run_all.R" --quick      # skip the federal and NSW cycles
Rscript "scripts/run_all.R" --stale-ok   # proceed on old data (historical runs)
```

It checks poll freshness *before* computing anything, runs each stage in its
own R process, echoes every pre-registered check, and stops on the first
failure. The stages are not independent — `fit_projection.R` writes the mix
table that both `fit_seats.R` and `build_page.R` read — so running them by
hand in the wrong order silently uses whatever was left in `output/` from last
time.

Individual stages, if you want one: `fit_vic.R`, `fit_federal.R`, `fit_nsw.R`,
`fit_projection.R`, `fit_seats.R`, `fit_scorecard.R`, `build_page.R`.

Outputs land in `output/` (gitignored): trend CSVs and plots per cycle,
hyperparameters, seat simulations, the scorecard, and
`victoria-2026.html` — a self-contained forecast page with no external
requests.

### Staleness

Every poll comes from a third party's hand-maintained CSVs in the `external/`
clone. Nothing else in the pipeline notices if that clone stops being updated:
the fit still runs, every check still passes, and the forecast quietly
describes the world as it was weeks ago. `check_poll_freshness()` warns past
21 days and stops past 60.

## Conventions

Repo follows the `C:\dev` house rules: work on `dev`, merge to `main` via
reviewed PR, data outputs stay out of git.
