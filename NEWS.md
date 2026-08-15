# auspol 0.1.0

First release with a complete forecast pipeline: **polls → trend → projection
→ seats**, with prediction intervals validated as calibrated. Live target is
Victoria, 28 November 2026.

## Model

- `fit_trend()` — Jackman-style latent voting intention: daily random walk
  plus pollster house effects. All-Gaussian, so the posterior is exact via one
  sparse solve; seconds per cycle, no MCMC.
- Hyperparameters estimated rather than assumed. `estimate_trend_sigmas()`
  maximises the exact log marginal likelihood; `estimate_cycle_sigmas()`
  re-estimates per cycle, shrunk toward the pooled value, because a party's
  volatility belongs to the cycle and not to its whole history.
- Vote shares modelled on a **logit or points scale, chosen per party** by
  comparable log evidence. The transform's Jacobian is included, without which
  the two are densities in different units and not comparable at all.
- `estimate_firm_factors()` — per-pollster noise weighting.
- `unfold_others()` / `fit_cycle_unfolded()` — corrects polls that fold a
  party (typically One Nation) into the "Others" line, detected arithmetically
  and imputed only where that party was actually measured.
- `fit_trend(nu = )` — optional Student-t observation noise by iteratively
  reweighted least squares. Off by default; see below.

## Forecast

- `fit_fundamentals()` — expected result from history alone (previous result,
  long-run average, incumbency, years in office, federal alignment) by ridge
  regression, penalty chosen leave-one-election-out. Two-party MAE 3.05
  against 4.93 for "assume the last result".
- `project_result()` — mixes trend and fundamentals by days-to-election. The
  trend at each horizon is refitted on only the polls available then.
- `simulate_seats()` — statewide draw, regional block effect, per-seat
  residual.
- `pollster_scorecard()` — per-pollster lean, noise against the binomial
  sampling floor, and final-poll accuracy.

## Measured negative results

Four principled additions were built, tested out of sample, and are documented
in `docs/NEXT-STEPS.md` so they are not rebuilt:

- Fat-tailed poll noise: MAE 2.791 against 2.779. Not enabled.
- Asymmetric error distribution: excess kurtosis −0.23, not warranted.
- Per-horizon bias correction: worse at all five horizons. **Removed.**
- Regional swing structure: real, but worth +5% on seat-count spread.

## Notes

- Every stage carries pre-registered checks that halt the fit scripts. They
  caught the majority of real bugs in this release, all of which produced
  plausible output rather than an error.
- Reviewed before release; findings fixed in `8be7750`, including a
  preference-flow leak in the historical backtest.
- `R CMD check` clean with zero notes; 263 tests.
