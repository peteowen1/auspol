# auspol architecture

How the pieces fit and why they are shaped this way. For the work queue and
measured findings see [docs/NEXT-STEPS.md](docs/NEXT-STEPS.md); for the anchor
model this is built on, [docs/ANCHOR-MODEL.md](docs/ANCHOR-MODEL.md).

## The shape of the thing

```
  anchor clone (external/, gitignored, third-party, hand-maintained)
        │  polls · prior results · preference flows · incumbency
        │  eventual results · seat margins
        ▼
  ┌─────────────┐
  │ load_polls  │  freshness check runs FIRST, before anything is computed
  └──────┬──────┘
         ▼
  ┌─────────────┐   per party, per cycle:
  │  fit_trend  │   latent daily vote share + pollster house effects
  └──────┬──────┘   exact posterior, one sparse Cholesky, no MCMC
         │
         ├──► unfold_others()      One Nation hidden inside "Others" — detected
         │                         arithmetically, imputed, subtracted, iterated
         │
         ├──► derive_tpp()         first preferences → two-party, via flows
         │
         ▼
  ┌─────────────┐   trend says "now"; fundamentals say "usually"
  │ projection  │   weight fitted per horizon on past elections
  └──────┬──────┘   ▲
         │          └── fit_fundamentals()  history alone: previous result,
         │                                  incumbency, federal alignment
         ▼
  ┌─────────────┐   statewide draw + regional block + per-seat residual
  │   seats     │   → distribution of seat counts
  └──────┬──────┘
         ▼
   build_page.R  →  a self-contained HTML forecast
```

`scripts/run_all.R` runs that whole chain in one command. The stages are *not*
independent: `fit_projection.R` writes the mix table both `fit_seats.R` and
`build_page.R` read, so out-of-order runs silently use last time's numbers.

## Load-bearing decisions

**The posterior is exact, not sampled.** Every term in the trend model is
Gaussian, so the whole thing is one sparse linear solve. The anchor's Stan
implementation of the same model takes one to four hours per election; this
takes seconds. That is what makes it affordable to refit the trend at five
horizons for every past election, which is what the projection stage needs to
be honest.

**Fat tails did not require giving that up.** A Student-t likelihood is a scale
mixture of normals, so robustness is a reweighting of the same exact solve
(`fit_trend(nu =)`). It is implemented, tested, and off by default because it
measurably did not help.

**Hyperparameters are estimated, not chosen.** Observation noise and walk size
come from maximising the exact marginal likelihood — pooled across completed
cycles, then re-estimated per cycle and shrunk back. A party's volatility
belongs to the cycle, not to its whole history: One Nation federally needed a
walk 4.9× the pooled value.

**Model scale is per party, decided by evidence.** Vote shares are modelled in
logit or in raw points, whichever the comparable log evidence prefers. Comparing
across scales requires the transform's log Jacobian; without it the two numbers
are densities in different units.

**Everything downstream reads shares, not the model scale.** `fit_trend()`
back-transforms before returning, so `derive_tpp()`, `plot_trends()` and the
seat model never need to know which scale was used. That seam is why adding the
logit scale did not touch them.

## Where the guards are

The unusual thing about this codebase is not the model, it is the checking.
Nearly every real bug found while building it produced *plausible output* and
was caught only against a number someone already knew.

- **Pre-registered checks live in the fit scripts**, not the package, and halt
  the pipeline. They are stated before results are seen: `fit_vic.R` V1–V5,
  `fit_federal.R` A1–A4/H1–H4/L1–L4, `fit_seats.R` S1–S4/R1–R3,
  `fit_projection.R` P1–P4/B1–B3, `fit_scorecard.R` C1–C3.
- **Structural guards live in the package**, where they can be unit-tested:
  `scale_breaches()`, `trend_tracking()`, `binomial_sd_link()`,
  `check_poll_freshness()`.
- **Skipped work is counted, not ignored.** `build_projection_data()` returns a
  `skipped` attribute distinguishing "too thin to fit" from "errored", because
  a bug that quietly dropped elections would refit the mix on a shrunken subset
  with no symptom.

Several checks have *failed and changed the design* rather than being explained
away — a global switch to logit was rejected by its own test, and the Victorian
validation checks were restated twice because the check was wrong, not the
model.

## Recurring hazards, all of which have bitten

- **data.table NSE shadowing.** A function argument sharing a name with a
  column, used bare inside `dt[...]`, filters nothing and returns every row.
  Twice here. Masks are now computed outside the brackets with `which()`.
- **`fread` stops early on a ragged row** without erroring. It read 263 of
  `eventual-results.csv`'s 421 lines and trained the fundamentals model on 62%
  of the data. All hand-maintained files now go through `read_anchor_csv()`.
- **Untranslated constants after a scale change.** A hard-coded `0.3` in points
  became a ~20× weaker constraint in log-odds; house effects stopped being
  centred and nothing errored.
- **Leakage in the backtest.** Preference flows were keyed to the election
  being backtested — the realised post-count distribution. Fixing it moved the
  fitted trend weight from 0.57 to 0.52.
- **Blanket `tryCatch`.** Wrapping `load_polls()` swallows its deliberate
  corruption stop and lets a whole region vanish while every check still passes.

## Data boundary

Nothing from the anchor clone is ever committed: no CSVs, no `external/`, no
`output/`. The clone is disposable and re-cloneable; `anchor_data_path()` is
the single point where the package touches it, and `options(auspol.anchor_dir)`
redirects it for tests. Every test needing that data calls
`skip_if_no_anchor()`, which is why CI runs 217 assertions with the clone
absent.
