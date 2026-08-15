# auspol 0.3.0

The forecast's assumptions are now estimated from the record rather than taken
as given.

## Preference flows are estimated, not assumed

- `estimate_flow()` / `estimate_flows_for()` / `is_observed_election()` —
  where a minor party's preferences go is the largest lever on a two-party
  figure (at 21% of the vote, one point of flow moves it 0.21), and it was a
  constant read from a hand-maintained file. It is now the mean of the party's
  five most recent observed elections, pooled across regions, and it moves as
  elections are held.
- **The estimator was chosen by strict temporal backtest**, every election
  predicted using only elections held strictly earlier, across 103 elections.
  Eleven candidates. A linear trend — the obvious choice, and the one this was
  first built around — came sixth (MAE 5.282 against 4.815). Leave-one-out had
  endorsed it, wrongly: it lets a later election inform an earlier prediction. Every recency-weighted
  scheme also lost, and monotonically in the half-life, because exponential
  decay never fully discards a 1998 flow of 54% while behaviour has drifted to
  26%.
- `scripts/backtest_flows.R` re-runs that comparison on every pipeline run and
  fails as check **G3** if the adopted estimator stops winning. The choice is
  itself made from data, so it needs re-testing as new elections land rather
  than being correct once and unexamined after.
- Victoria: One Nation 25.5 → 33.7, Greens 81.9 → 83.5, Others 49.3 → 48.9.
  Labor's published two-party moves 46.8 → 47.8.
- A state-versus-federal difference in One Nation flows was tested and
  rejected: +1.10 points, se 1.90, p = 0.57, and worse out of sample.

## Fixes

- Preference-flow leakage in the historical backtest, arriving through a new
  door: estimation counts elections that have "already happened", which
  defaulted to *today*, so backtesting 2018 used flows informed by 2022 and
  2025. Caught because the fitted mix weight moved when recorded historical
  flows cannot. `as_of` is now pinned to each cycle's start.
- data.table NSE shadowing, for the third time here: a filter written
  `flows[flows$party == party, ]` binds the bare name to the column, matches
  every row, and hands every party the pooled mean of all 202 estimates.

# auspol 0.2.1

## Publishing

- The page now names a recent change of government leader, the date, and how
  many polls have been taken since — computed from the data, so it cannot go
  stale, and shown only while the change is recent enough to be
  under-observed. Victoria changed premier on 2026-07-28, four months out,
  and the forecast had three polls covering it while saying nothing about
  that. The model has no leader term by measurement, not oversight: one
  tested as a fundamentals predictor across 56 elections came back at
  p = 0.52.
- `tools/check-page.js` runs the published page's own JavaScript against a
  stub DOM and fails the build if any block did not draw, reported as check
  `B1`. The page had no test at all, having once shipped with three of four
  charts silently missing; the per-block guards added afterwards stopped one
  failure cascading and thereby made a single missing chart quieter still.
  Validated against a page corrupted into the exact shape that caused the
  original incident.

## Running it

- The forecast refreshes daily on a schedule and deliberately does not
  publish: it runs, checks, reports the numbers and every pre-registered
  check, and uploads the page for a human to look at.

# auspol 0.2.0

The forecast is published, the pipeline runs in one command, and both are
checked on every push.

## Publishing

- `scripts/build_page.R` + `scripts/page-template.html` produce a
  self-contained `output/victoria-2026.html`: no external requests, so it
  renders offline and under a strict content-security policy. It leads with
  the pendulum and publishes the calibration record, the four rejected
  improvements, the pollster scorecard and five caveats alongside the
  headline numbers.

## Running it

- `scripts/run_all.R` runs every stage in the one order that works, each in
  its own R process, echoing every pre-registered check and stopping on the
  first failure. `--quick` skips the two slowest cycles; `--stale-ok`
  proceeds on old data. About five minutes.
- `check_poll_freshness()` / `poll_data_age()` — every poll comes from a
  third party's hand-maintained CSVs, and nothing previously noticed if that
  clone stopped being updated. Warns past 21 days, stops past 60, and
  distinguishes "our copy is old" from "no new polls published" using the
  source file's own modification time.

## Checking it

- CI runs `R CMD check` (`--as-cran`, warnings are errors) and the tests on
  every push, with a floor on assertions executed so an all-skipped run
  cannot pass silently.
- `ARCHITECTURE.md` records the load-bearing decisions and the five hazard
  classes that have bitten this codebase.

## Fixes

- The page shipped with three of four charts silently not drawing: jsonlite
  serialises a data.table as an array of row objects and the template read
  them as column arrays, so one throw took out the rest. Drawing blocks are
  now isolated and a failed one says so visibly.
- A missing projection would have rendered a fabricated "0% chance of a Labor
  majority", because JavaScript coerces `null` to `0` in arithmetic. Missing
  values now render as an em dash, and the build asserts finiteness first.
- A region whose poll dates fail to parse was silently exempt from the
  stale-data gate, since `which()` drops `NA` rather than matching it.
- `run_all.R` dropped every stage `warning()` — the mechanism this package
  uses for "a human should look".
- `skip_if_no_anchor()` rebuilt a path by hand instead of resolving through
  `anchor_data_path()`, so a CI dry-run reported green while checking a
  different directory.

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
