# auspol

Australian election modelling and forecasting in R — a 538-style forecast with a
journalistic, interactive presentation. Anchored on the
[AE Forecasts](https://www.aeforecasts.com/) methodology
([d-j-hirst/aus-polling-analyser](https://github.com/d-j-hirst/aus-polling-analyser)),
with planned extensions: ABS Census demographics at electorate level, booth-level
results, and seat-level preference-flow modelling.

Full analysis of the anchor model (methodology, data sources, improvement
targets): [`docs/ANCHOR-MODEL.md`](docs/ANCHOR-MODEL.md).

## Status

Walking skeleton (stage 1 of 4): national poll trend model.

- `load_polls()` etc. — read the anchor project's public poll/reference CSVs
  from a local clone under `external/` (gitignored; the data has no formal
  license so it is never committed here — licensing contact with the author
  is on the queue).
- `fit_trend()` — Jackman-style latent voting-intention model (daily Gaussian
  random walk + pollster house effects). All-Gaussian, so the posterior is
  exact via one sparse linear solve — seconds per cycle, no MCMC. Stan
  replaces this when fat tails / campaign dynamics / time-varying house
  effects are added.
- `derive_tpp()` — TPP from first preferences via historical preference flows
  (published poll TPPs are display-only, matching the anchor).
- `scripts/fit_federal.R` — fits the 2022, 2025 and 2028 federal cycles and
  runs pre-registered anchor checks (2022/2025 endpoints vs known results,
  house-effect bounds, the 2021-22 Morrison decline). All passing.

Not yet built: fundamentals regression, trend→result projection, seat
simulation, website.

## Setup

```r
# one-off: clone the anchor repo for data
# git clone https://github.com/d-j-hirst/aus-polling-analyser external/aus-polling-analyser

devtools::load_all()
devtools::test()
```

Run the federal pipeline (PowerShell, not Git Bash — arrow segfaults there):

```powershell
Rscript "scripts/fit_federal.R"
```

Outputs land in `output/` (gitignored): trend CSVs and plots per cycle.

## Conventions

Repo follows the `C:\dev` house rules: work on `dev`, merge to `main` via
reviewed PR, data outputs stay out of git (parquet/CSV, GitHub Releases later
if needed).
