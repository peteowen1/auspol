# auspol build journal — August 2026

(Session write-ups moved out of the hub. Nothing here is open work.)

Completed stage write-ups, newest first, moved verbatim out of
`docs/NEXT-STEPS.md` on 2026-08-15. Nothing here is open work: the hub holds
state, this holds the narrative of how it got there.

- 2026-08-15 (stage 8): **Regional swing structure in the seat model.**
  Seats do not move independently, they move in regional blocks: 36% of
  seat-swing variance at the 2022 Victorian election and 29% at 2018 is
  shared within a region. `simulate_seats()` now draws a regional effect per
  region per simulation on top of the statewide draw, with the seat-specific
  spread reduced so total per-seat variance is unchanged (2.40 and 3.42
  recombine to 4.17 against a pooled 4.20).
  Region effects are drawn fresh rather than predicted: across Victoria's 13
  regions they correlate only **0.27** between 2018 and 2022, so which region
  swings hardest is not forecastable from the last election, though that
  seats move in blocks at all clearly is.
  Honest sizing: this widens the seat-count spread by only **5%** (sd 8.33 to
  8.73), because statewide projection error already dominates — see the
  section above. Correct to include, but it does not change the picture, and
  the earlier claim that the 90% range was "too narrow" was directionally
  right and materially small: 27 seats wide to 29.
- 2026-08-15 (stage 7): **Seat model — the pipeline is end to end.**
  `R/seats.R` reads the anchor's authored per-seat configuration (
  `analysis/seats/2026vic.txt`: redistribution-adjusted margins, incumbent,
  challenger, region) and simulates. Each run draws a statewide result from
  the projection's own uncertainty, then gives each seat an independent
  deviation. Statewide error moves all seats together and sets the range;
  seat-level noise decides the close ones. Seat-level swing spread is
  measured, not assumed: sd 4.41 at the 2022 election and 3.99 at 2018.
  All four pre-registered checks passed, and S1 is the one that matters —
  **at zero swing the model returns a median of exactly 56 classic seats,
  against an actual 2022 result of 56 of 88.** That single number tests the
  margins, the sign convention and the simulation together.
  It also caught a real error: `fTppMargin` is **Labor's** margin in every
  seat, not the incumbent's, which is why Coalition seats carry negative
  values. Reading it the obvious way gave Labor 82 of 83 seats at zero swing.
  Stated assumptions, not modelled: the five non-classic seats (three
  Green-held plus Prahran and South-West Coast) are held by their current
  incumbents, since a two-party number cannot decide a Labor-versus-Green or
  independent contest; and seat deviations are independent, whereas real ones
  cluster by region, so the spread of seat counts here is if anything too
  narrow.
  Not implemented from the anchor's stage 4: regional swing structure,
  per-seat elasticity, candidate effects (retirement, sophomore surge), and
  proper modelling of minor-party and independent contests.

- 2026-08-15 (stage 6): **Fundamentals + projection — it is a forecast now.**
  `R/fundamentals.R` predicts a result from history alone (previous result,
  six-election average, incumbency, years in office, and for state elections
  whether the party's federal counterpart governs), by ridge regression with
  the penalty chosen leave-one-election-out. On two-party vote it scores MAE
  **3.05** against 4.93 for "assume the last result" and 4.08 for the
  long-run average, over 62 elections. The coefficients carry the right
  politics without being told to: `govt_years` negative (the "it's time"
  effect) and `fed_aligned` negative (a state party is punished when its
  federal cousins govern).
  `R/projection.R` mixes trend and fundamentals by horizon, refitting the
  trend at each horizon from only the polls available then — reading a
  whole-cycle trend at an earlier date would leak later polls backwards and
  flatter the long horizons badly.
  All three pre-registered checks passed, and two of them were genuinely
  falsifiable: the trend weight RISES toward the election (0.29 at two years
  out, 0.58 at three months) and the error spread FALLS (2.98 to 2.41).
  Held-out accuracy on ALP two-party, 42 elections:

  | horizon | mix (held out) | trend only | fundamentals only |
  |---|---|---|---|
  | 30 days | 1.97 | 2.31 | 2.70 |
  | 90 days | 1.97 | 2.40 | 2.70 |
  | 365 days | 2.35 | 3.27 | 2.57 |
  | 730 days | 2.21 | 3.67 | 2.55 |

  For comparison the anchor reports 2.87 for its projection at one year out
  against 3.68 fundamentals-only and 3.77 trend-only — a different, federal-
  only sample, so not directly comparable, but the same shape and magnitude.
  Two silent-data bugs found: `fread` **stops early** on the first ragged row
  in eventual-results.csv, so the model was training on 263 of 421 lines
  until the loader was rewritten; and `build_fundamentals_data()` started
  from results rather than priors, which excluded every election that has not
  happened yet — i.e. exactly the one being forecast.
  Not yet implemented from the anchor's stage 3: per-horizon bias correction
  and an asymmetric, fat-tailed error distribution. Ours is symmetric.

- 2026-08-14 (session 2, stage 5): **Parties folded into "Others" corrected.**
  Pollsters that do not name One Nation still count its voters — into the
  Others line. Measured within the SAME firm federally, so not a house
  effect: Essential's Others averaged 8.5 when it named ONP and 17.6 when it
  did not; Redbridge 9.9 vs 18.1; Morgan 12.4 vs 17.9. `R/fold.R` detects
  these arithmetically (a poll whose reported shares already sum to ~100
  without party P must be carrying P inside a reported category), imputes P
  from its own trend and subtracts it from Others, iterating to convergence.
  The imputed value is deliberately NOT written back as an observation of P —
  that would feed a trend its own output.
  Two bugs caught by checks rather than review. **Multi-party folding:**
  detection is arithmetic, so subtracting One Nation first dropped the row's
  total below the window and hid UAP, which is folded on 100% of the same
  polls; masks are now computed before any subtraction. **Over-correction
  outside the observed window:** NSW 2027's 20 folding polls run 2023-05 to
  2026-01 but One Nation is only measured from 2025-12, so the trend there
  was prior-driven interpolation. Imputing from it subtracted ~13 points of
  phantom vote and crushed NSW Others to 6.1; the fitted-shares sum check
  (L3) caught it at 95.0. The correction is now restricted to each party's
  observed date range, and skipped rows are counted and reported.
  Honest limitation: F1 as pre-registered ("max within-firm gap < 2.0")
  FAILS at 2.86 for Essential 2025, on three polls at the very start of a
  cycle where the imputing trend is least determined. What is enforced is the
  poll-weighted gap (the quantity that actually biases the trend) plus the
  per-firm gap for firms with >= 10 folded polls. Morgan, with 20 polls,
  went 5.66 -> -0.56.
- 2026-08-14 (session 2, stage 4): **Per-cycle volatility — the model now
  reproduces One Nation leading.** Pete's observation that ONP "isn't really
  a small party anymore" turned out to be a testable defect. Sigmas were
  pooled across completed cycles, so ONP's walk was learned from 2022/2025
  when it sat at 2–10% and barely moved (~0.35 points/month of expected
  movement). It then moved ~1.5 points/month for over a year. The pooled
  walk acted as a speed limit: the fit clipped the peak at 28.1 and showed
  ONP ahead of ALP on **0 of 461 days**, when the raw June 2026 polls had
  ONP 29.2 vs ALP 28.5 and 17 of 144 individual polls had ONP highest.
  Now both sigmas are estimated per cycle, shrunk toward the pooled values
  by poll count (`estimate_cycle_sigmas()`). ONP's 2028 walk comes out 4.9×
  pooled and its noise 1.53 points against a stale 0.78. The fit now peaks
  at 29.3 against a local poll-average peak of 29.1, and puts ONP ahead
  from **2026-05-29 to 2026-06-19**.
  Deliberate loosening: this lets the live cycle inform its own smoothing.
  A walk size is not the answer, only how much of the wiggle you believe.
  An intermediate version held `sigma_obs` pooled "to avoid the
  noise-vs-movement trade-off" and was worse — the stale noise value sat
  below the binomial sampling floor for a party at 26%, so the walk
  inflated to 6.7× to absorb the mismatch and began chasing individual
  polls. Freeing both fixed it. There is a test for exactly this.
  New checks: **L4a** (residual autocorrelation < +0.25, the over-smoothing
  detector — calibrated by simulation: correct fits never exceeded +0.118,
  over-smoothed ones give ~+0.97) and **L4b** (each cycle's noise must clear
  the binomial floor at the level that party *actually polled*, not at its
  previous-election result). L4b is what diagnoses the ONP failure directly.

- 2026-08-14 (session 2, stage 3): **Logit-scale modelling — adopted per
  party, not globally.** Poll shares can now be modelled in log-odds instead
  of raw points, which keeps trends inside (0, 100), lets noise and movement
  scale with a party's own size, and makes house effects proportional. The
  pre-registered test (L1: logit must beat points on Jacobian-corrected log
  evidence for most parties, and for ONP) **FAILED**, so the global switch
  was rejected; the scale is now selected per party by that same comparable
  evidence, with a hard structural override — any fit whose 95% band leaves
  (0, 100) is escalated to logit regardless of likelihood.
  That override fired on two real cases, both catching genuine
  overconfidence: NSW SFF 2023 and NSW ONP 2027, where the points fit
  claimed 25.3 [22.8–27.8] from 8 polls spanning 4–30% AND put negative
  vote share inside its own interval; logit gives 20.8 [15.8–26.9].
  The hand-set NSW ONP override (`sigma_rw = 0.25`) is **retired** — it had
  been compensating for the wrong scale all along.
  Two bugs found by the pre-registered checks, not by review: the
  sum-to-zero constraint had a hard-coded 0.3-point tolerance that was never
  translated (≈20× too weak in log-odds, so house effects stopped being
  centred — caught by A3b at 1.89 vs the required <1), and the
  points-equivalent house-effect column linearised at a party's stale prior
  result rather than its fitted level, overstating OTH's by half again.
  All A1–A4 / N1–N3 anchor checks pass; NSW 2023 validation endpoint 54.33
  vs actual 54.3. `R CMD check` clean; 59 tests.
- 2026-08-14 (session 2): **Hyperparameters estimated, not fixed.** The
  Gaussian model has an exact evidence, so `sigma_obs`/`sigma_rw` come from
  maximising log marginal likelihood (L-BFGS-B on the log scale) over the
  completed cycles, then a second empirical-Bayes stage turns pooled
  standardised residuals into per-pollster noise multipliers. Federal:
  ALP 1.32/0.12, LNP 1.41/0.17, GRN 0.94/0.035, OTH 1.85/0.09 —
  all far from the old hand-set 1.7/0.10, worth +3 to +163 log points.
  Noisiest firm ResolvePM (×1.31), quietest Newspoll3 (×0.73). All A1-A4
  and N1-N3 anchor checks still pass; NSW 2023 validation endpoint 54.33 vs
  actual 54.3. Pre-registered H1 (binomial-sd floor on `sigma_obs`), H2
  (walk-size range), H4 (evidence must beat the fixed values) added.
- 2026-08-14: Anchor model analysed (ANCHOR-MODEL.md); R package skeleton;
  Gaussian-exact Jackman trend + house effects; TPP via preference flows with
  NSW exhaust handling; federal 2022/2025/2028 + NSW 2023/2027 cycles fitted;
  all pre-registered anchor checks passing; synthetic-recovery tests green.
  Found + fixed: ONP omission inflating NSW 2027 TPP by ~4.7 pts.


## Review gate, 2026-08-15 — one real leak, and what it moved

Five scoped Sonnet reviewers over the whole package before the first PR.
Seven findings, all verified against the code before acting. The three that
mattered:

**Preference-flow leakage in the backtest.** `build_projection_data()` looked
up flows for the election year being backtested, so `derive_tpp()` converted
every horizon's first preferences using the flows observed AT that election —
the realised distribution, published only after the count. Two years out, the
trend was being scored with a number nobody could have had. Now keyed to
`y - 1`. The fix moved the trend weight at 30 days from **0.57 to 0.52**,
exactly the predicted direction: the leak had been inflating measured trend
accuracy and buying the trend more weight than it earned.

**The published intervals were not the ones validated.** Coverage was checked
with `projection_loo()`'s held-out spread, but `project_result()` shipped
`sd_err` from the in-sample fit, which is smaller by construction — so the
bands quoted were narrower than the bands certified. `fit_projection_mix()`
now returns `sd_err_loo` and that is what `projection_params()` uses.

**Fold-wise standardisation in `ridge_loo()`.** Centre and scale were computed
once on all rows, letting the held-out election influence the scale of the
model predicting it. Narrower than a full leave-one-out violation, since the
response was already re-centred per fold, but it flattered `loo_mae` most for
the categories with as few as 10 elections.

Four more, all guards rather than wrong numbers: a party polling 0.0
everywhere with no prior result produced `NaN` priors and an opaque Cholesky
failure; a seat missing `sRegion` killed the simulation with "invalid
arguments"; blanket `tryCatch` around `load_polls()` would have let a corrupt
region vanish while every check still printed PASS; and
`load_election_cycles()` was the last loader still using `fread`, which stops
early on a ragged row — the bug that once cost 38% of the fundamentals
training data.

`build_projection_data()` now returns a `skipped` attribute distinguishing
"too thin" from "errored", and `fit_projection.R` fails on any error skip.
`fit_scorecard.R` asserts it fitted every eligible cycle, not merely some.

Also corrected: `load_seats()`'s roxygen still described `margin` as the
INCUMBENT's, the buggy reading that gave Labor 82 of 83 seats at zero swing,
contradicting `seat_alp_tpp()` five functions below. A maintainer reading only
the loader's docs would have reintroduced it.


## Pollster scorecard (2026-08-15) — `scripts/fit_scorecard.R`

The differentiator identified in the feature review: nobody in Australia
publishes pollster house effects, noise and accuracy as a maintained,
comparable table, and we compute all three as a byproduct. Built over 41
cycles across federal, NSW, Victoria and Queensland; 163 final-poll
observations across 39 elections.

**Final-poll accuracy** is the solid column and needs no model — each firm's
last published two-party figure inside 30 days, against the actual result.
ReachTEL 0.81 mean absolute error (6 elections), Newspoll 1.53 over 25,
Essential 1.51 over 11, face-to-face Morgan 3.07 over 8.

**Lean is published as a within-cycle relative position, NOT as a claim about
who will be right.** The check that would have licensed the stronger claim —
does a firm's fitted lean predict which way it misses? — is suggestive but
not established: r = +0.35, p = 0.14 across 19 firms.

That number came from fixing a bad test. As pre-registered, C3 required only
`cor > 0`, which any noise passes half the time, and it returned r = +0.08.
The fault was comparing raw final-poll errors, which are dominated by how
wrong the WHOLE FIELD was — 2019 missed by about three points for everyone —
swamping any single firm's relative lean. Comparing each firm against the
others polling the SAME election lifts it to +0.35, the right size and
direction, but 19 firms is not enough to confirm it.

One result does line up with something already known: face-to-face Morgan
shows the largest Labor lean (+1.24) AND the largest relative final-poll
overstatement of Labor (+1.70). Morgan's face-to-face series was famously
Labor-leaning, and the two independent routes both find it.

**Herding is weaker than the Victorian result suggested.** Only 2 of 19 firms
sit below the binomial sampling floor on Labor first preferences, both
Newspoll variants and both marginal (ratios 0.92 and 0.98). The earlier
sub-binomial finding was Victorian One Nation — a small party in one cycle —
and does not generalise to the majors.

That check also had to be rewritten. The first version read the per-firm
noise FACTORS as a herding measure, but those are relative, normalised so the
average pollster sits at 1. A factor of 0.7 means "quieter than other
Australian pollsters", which says nothing about sampling theory if the whole
field is quiet. `pollster_noise_vs_binomial()` now compares each firm's
implied ABSOLUTE poll-to-poll sd with the binomial floor at the level the
party actually polled.


## After the merge, 2026-08-15 — publishing and plumbing

- **The forecast is published.** `scripts/build_page.R` + `page-template.html`
  produce a self-contained `output/victoria-2026.html` with no external
  requests. It leads with the pendulum, and publishes the calibration table,
  the four rejected improvements and five caveats alongside the numbers.
- **One command runs everything.** `scripts/run_all.R`, ~5 minutes, freshness
  checked before any computing, each stage in its own R process, every
  pre-registered check echoed, stops on first failure.
- **CI runs `R CMD check` and the tests on every push.** 217 assertions run
  with the anchor clone absent (15 skip); the workflow asserts a floor so an
  "everything skipped" run cannot pass silently.
- **ARCHITECTURE.md** records the load-bearing decisions and the five hazard
  classes that have actually bitten.

Three bugs found by checking rather than assuming:

1. **Half the page was not drawing.** jsonlite emits a data.table as an array
   of ROW objects; three chart blocks read them as column arrays. The seat
   histogram threw, which — same script, sequential — also killed the trend
   chart, its legend and both tables. `node --check` passed (valid syntax) and
   the browser showed the top of the page fine. Caught by running the page's
   own script against a DOM stub in Node and asserting every target populates.
   Blocks are now isolated and a failed chart says so visibly.
2. **A test guard was answering about the wrong directory.** `skip_if_no_anchor()`
   rebuilt the data path by hand instead of asking `anchor_data_path()`, so a
   CI dry-run reported 217 passed / 0 skipped / 0 failed — green, and
   meaningless.
3. **The freshness message asserted a cause it could not know** ("pull the
   clone"). NSW was flagged at 45 days; the clone was three commits behind,
   pulling changed no poll data at all. Nobody is polling NSW 19 months out.
   It now distinguishes "our copy is old" from "no new polls" using the source
   file's own mtime.


## Negative result: fat-tailed poll noise does not help (2026-08-15)

Student-t observation noise was the last big item on the trend side and the
principled fix for outlier handling. It is **built, tested and NOT enabled by
default**, because it was tested against the eventual result and did not help.

Across the same 195 (election, horizon) pairs, only the observation model
changing:

| | MAE vs actual |
|---|---|
| Gaussian | **2.779** |
| Student-t, nu = 4 | 2.791 |

Better at 3 of 5 horizons, better on 107 of 195 individual rows, sign test
p = 0.197. Statistically indistinguishable, point estimate marginally worse.

**The interesting part is why.** It is not that the reweighting does nothing:
10% of real polls fall below weight 0.5, against the ~1.4% clean Gaussian
data would produce, so the residuals genuinely do have fat tails. Discounting
those polls just does not improve the forecast — which means they carry
signal, not error.

That fits the herding finding exactly. Australian poll noise is often BELOW
the binomial sampling floor (see the Victorian One Nation result), i.e.
pollsters agree with each other more than sampling theory permits. In a
herded field the poll that disagrees is the informative one, and
down-weighting it discards the very observation worth most.

This sharpens the criticism of theswingison's outlier rule beyond what was
argued before. Penalising a poll for deviating from local consensus is not
merely "herding by construction" — on this evidence it actively discards the
most informative polls. Our own version, discounting by residual size through
the likelihood, is the principled form of the same idea and still does not
pay. Neither should be used.

Available via `fit_trend(..., nu = 4)` for anyone who wants it; the machinery
(a scale-mixture reweighting of the exact solve, so no MCMC) is sound and has
tests showing it beats the Gaussian fit under genuine contamination.


## Negative result: the bias correction was making things worse (2026-08-15)

The projection subtracted a per-horizon bias, fitted on past elections, from
every forecast. Held out, that made it **worse at every one of the five
horizons** — MAE 2.173 with the correction against 2.126 without.

The in-sample bias is +0.3 to +0.5 points with a standard error near 0.37, so
it was never distinguishable from zero. Subtracting a noisy estimate of
roughly nothing adds variance and removes none. `project_result()` now
defaults to `debias = FALSE`; the value is still reported as a diagnostic,
and `fit_projection.R` asserts that the correction does not help, so if it
ever starts to the check fails and we look again.

Worth noting the direction: this MOVED the Victorian forecast, from 46.3 to
46.8 two-party and from 33 seats to 35. A correction that could not be
distinguished from noise was shifting the headline by half a point of vote
and two seats.

## Measurement write-ups, 2026-08-16 to 08-18

Moved verbatim from `docs/NEXT-STEPS.md` on 2026-08-21 with a summary left
in its place. Nothing here was open when it moved.
## What 2026-08-18 measured

| Question | Result |
|---|---|
| are Victorian distributions fetchable at scale? | **yes** — 452 exclusions, all reconciling |
| is the model's Greens flow right? | **no** — 79.2 measured against 83.5 used |
| does correcting the flow record move the forecast? | **no — zero.** Vic 2022 is 7th most recent; the estimate averages the last 5 |
| is the observed flow record sound? | **no** — 14% of rows are carried-forward duplicates |
| does the estimator survive cleaning them out? | **yes** — `mean_last5` wins all three variants |
| does the OTH bucket need splitting? | **for the rebuild, yes; for what is published, no** |

Three lessons, all expensive:

1. **Two of three sizings tonight were wrong, both in the direction that made
   the finding look important.** The Greens record error was sized at 0.564
   points of published two-party vote and is worth **zero** — Victoria 2022 is
   not among the five elections the estimate averages. Check *which inputs a
   function actually reads* before sizing a change to one of them.
2. **A contaminated benchmark flatters the method that shares its bias.**
   `last_in_region` sat 0.048 MAE off the winner on the raw target set and fell
   to 0.727 behind — second to sixth — once carried-forward targets were
   removed. Had the 2026-08-16 ranking gone one notch differently, the project
   would have adopted a method whose strength was duplicated data.
3. **A speculation offered as explanation was tested and false.** Contamination
   does *not* explain why the linear trend ranks sixth; it ranks 6, 5, 7 across
   variants. Withdrawn where it was made.

## What 2026-08-17 measured

Five pre-registered tests, committed before each run. **Two adopted, one
negative, one void, one inconclusive.** Reviews:
[onp-allocation-sa-2026-08-17.md](reviews/onp-allocation-sa-2026-08-17.md),
[oth-flow-composition-2026-08-17.md](reviews/oth-flow-composition-2026-08-17.md).

| Question | Result |
|---|---|
| allocate an ONP surge by rescaled 2022 minor-right vote | **failed** — MAE 9.298 against uniform's 6.306 |
| same predictor, linear instead of proportional | **adopted** — LOO MAE 4.171 against 6.306 |
| prior LNP share as a seat-level predictor | **worthless** — LOO correlation −0.006 |
| does allocation move the seat count? | **almost not at all** — ONP wins ~0 either way |
| is the OTH flow wrong now ONP is modelled separately? | **inconclusive** — not measurable from transfer tables |

Four lessons, each of which cost something:

1. **A predictor can be good and its link function fatal.** The rescaled proxy
   correlated 0.735 with the truth and still lost to a flat allocation, because
   proportional scaling turns "no candidate stood" into "predicted zero" and
   multiplies a 6.6% base by 3.4.
2. **Registering two estimands is what stopped a wrong number shipping.** The
   OTH test's two measures disagreed by 4.2 points *in opposite directions*;
   either alone would have cleared the threshold to change the published
   two-party figure.
3. **A mechanism true in aggregate can be worth zero per unit.** The One Nation
   surge did come out of the Liberal vote statewide — LNP fell 17 points while
   ONP rose 20 — and prior LNP share still predicts nothing at seat level.
4. **The stripped-down-harness trap again.** The seat sweep gives Labor 47–52
   seats against a published 39, because its implied two-party is 49.19 against
   47.8. Same failure as 2026-08-16's sensitivity sweep. Shape usable, level
   not.

**Free result:** the void OTH estimand accidentally validated two flows the
model estimates, from a different state and a separate data path — GRN 86.7%
against the model's 83.5%, ONP 32.4% against 33.7%. First independent check
either has had.

## What 2026-08-16 measured

Five things were tested against held-out error under a criterion fixed before
the run. **One helped.** That ratio is the point: a procedure that only
produced adoptions would be evidence it was finding what it went looking for.

| Change | Result |
|---|---|
| `szc_sd_pts` 0.3 → 1.5 | **adopted** — 1.3% better, and two independent lines agree on 1.5 |
| `sigma_house_pts` | already the outright optimum of a smooth U; kept at 3 |
| per-cycle volatility | irrelevant — 0.2% for **33×** the runtime |
| per-firm poll weighting | **harmful** — −0.6%, and consistently worse at every horizon past 30 days |
| seat type as a swing predictor | **worthless** — 0.06%, and region is worse than nothing |

Full write-ups in `reviews/`. Three general lessons, all of which cost
something today:

1. **Held-out error overturned an in-sample result twice.** Leave-one-out
   endorsed a linear trend for preference flows that a temporal backtest ranked
   sixth of eleven; an F-test at p = 0.006 endorsed seat type that a
   leave-one-election-out test found worthless. Both in-sample statistics were
   real and both conclusions were wrong.
2. **Per-seat swing looks genuinely unforecastable.** Seat type fails, region
   fails, region effects correlate 0.27 between elections. `simulate_seats()`
   already draws its regional effect fresh rather than predicting one, and that
   now has three independent lines of evidence behind it.
3. **A sensitivity sweep on a simplified harness predicted the wrong sign.**
   It ran `fit_cycle_trends` bare while the pipeline has firm factors, the fold
   correction and estimated sigmas. A stripped-down harness is not the model.

## What 2026-08-16 fixed, none of which changed a number

Every one was a gap between what the model does and what the machinery around
it claimed:

- The page drew its **chart from one fit and its headline from another** — up
  to 0.54 points apart on Others, so a reader adding up the published first
  preferences could not reproduce the published result.
- `fit_vic.R`'s L2/L3 structural checks were **validating a fit nobody
  publishes**. `G7` now checks the published one.
- `G7` itself **shipped unable to fail**: an `| is.na(lo95)` clause made an
  unverifiable band count as a pass.
- The scorecard used the **sensitive** binomial reference for a published claim
  about named polling firms — the aggressive setting on the one output where a
  false positive costs someone else.
- The page described **the wrong metric entirely** for Variability, and
  `R/scorecard.R`'s own docstring warns against that exact conflation.
- `overrides` through the new `...` raised an argument error that `tryCatch`
  swallowed into a `NULL`, which the backtest recorded as **"too few polls"**.

The through-line: not wrong numbers, but **checks pointed at the wrong object,
labels describing the wrong quantity, and guards that could not fail.** Those
look identical to working ones until someone traces them.

## Seat rebuild status, 2026-08-18

Moved from `docs/NEXT-STEPS.md` on 2026-08-21. Every open item in it was
closed by then.

## Next session starts here (2026-08-18, late)

**The seat rebuild is built and in the package. What remains is data hosting
and a decision.**

Evidence: [reviews/seat-sim-working-2026-08-18.md](reviews/seat-sim-working-2026-08-18.md)
(result), [reviews/seat-sim-prototype-2026-08-18.md](reviews/seat-sim-prototype-2026-08-18.md)
(the failed first attempt, do not quote its numbers),
[plans/preference-data-acquisition.md](plans/preference-data-acquisition.md) (how to
refetch).

**The whole path is now in the repo.** Nothing below runs from a scratchpad.

| piece | file |
|---|---|
| fetch Victorian distributions | `scripts/fetch_preferences_vic.R` |
| fetch South Australian distributions | `scripts/fetch_preferences_sa.R` |
| party name → modelling class | `classify_party()` |
| transfers → rates by excluded party and survivors | `build_flow_matrix()` |
| one seat's count to a final two | `distribute_preferences()` |
| every seat, n simulations | `simulate_seat_contests()` |
| the runner joining all of it | `scripts/fit_seats_full.R` |

**78 tests**, none needing external data, so the logic is checked in CI while
the election data cannot be committed. A full run is 87 seats × 20,000 sims in
about 200 seconds. Architecture diagram in `ARCHITECTURE.md`; every constant is
inventoried in `docs/CONSTANTS.md` §4b.

**Latest result** (local, from fetched data): **ALP 41 (90%: 24–51)**, LNP 38,
GRN 5, ONP 3. Greens hold their four — Brunswick 100%, Melbourne 99.6%,
Richmond 96%, Prahran 72% — and One Nation's best is Melton at 57%.

**That range is after the anchoring fix and the earlier one was wrong.** The
simulation was rebuilding the statewide distribution instead of inheriting the
projection, giving an implied two-party of 49.23 ± 1.52 against the
projection's 48.00 ± 2.52 — centred 1.2 points too favourable to Labor and
about 40% too tight. Corrected, the two methods now agree:

| | two-party model | candidate-level |
|---|---|---|
| ALP median | 39 | 41 |
| ALP 90% | 23–51 | 24–51 |

Two very different methods landing in the same place is the cross-validation
that was missing while the ranges disagreed. See
[reviews/seat-sim-working-2026-08-18.md](reviews/seat-sim-working-2026-08-18.md).

**What is left, in order:**

1. **Where the VEC data lives** (see Awaiting Pete). `scripts/fetch_preferences_vic.R`
   and `scripts/fetch_preferences_sa.R` both work and write to gitignored
   `output/`, so a developer can reproduce everything locally — but CI has no
   data and the page cannot use the new path until this is settled.
2. **A runner script** joining the pieces: fetch → `build_flow_matrix()` →
   per-seat projected primaries → `simulate_seat_contests()` → output. The
   parts all exist and are tested; nothing yet calls them in sequence.
3. **Decide whether this replaces the two-party seat model or runs beside it.**
   Pete chose replace. Worth revisiting now the One Nation allocation has been
   checked: it survives (below), but its ordering beats uniform by only
   0.122 MAE, so individual ONP seat probabilities are soft even though the
   total is sound.

**Settled 2026-08-18, no longer open:** the One Nation allocation passed both
pre-registered checks — the Greens-share ordering replicates with a negative
coefficient in NSW, Queensland and WA, and the magnitude transfer is within
1.41x of SA's spread against a 1.5 bar. See
[reviews/onp-allocation-checks-2026-08-18.md](reviews/onp-allocation-checks-2026-08-18.md).

**Do not start with:** anything that makes the backtest slower. Arm B of the
volatility comparison took 33x and bought nothing; a backtest that takes an
hour makes every constant expensive to re-examine, and constants that are
expensive to re-examine stop being re-examined.

---

Moved from `docs/NEXT-STEPS.md` on 2026-08-23 (housekeeping pass, hub past
90k characters). Both fully superseded — their content lives on as compact
pointers in the hub and, for the first one, duplicated into `ARCHITECTURE.md`.

## Next build steps (in rough order) — as it read up to 2026-08-23

1. ~~Estimate model hyperparameters instead of fixing them~~ — **done**
   (session 2): exact log marginal likelihood, L-BFGS-B, plus a per-pollster
   noise-factor stage.
2. ~~Poll-share transformation~~ — **done** (session 2, stage 3), but not as
   planned: a global switch to logit was REJECTED by its own pre-registered
   test. The scale is now chosen per party by comparable log evidence.
3. ~~Handle "modelled party folded into OTH"~~ — **done** (session 2). Was:
   some polls (e.g. ResolvePM Jan 2026 NSW) report ONP inside OTH; anchor
   imputes from trend and subtracts. We currently over-count OTH in those
   polls.
4. ~~Fundamentals stage~~ — **done** (2026-08-15), as ridge rather than
   elastic net, penalty chosen leave-one-election-out. Two-party MAE 3.05
   against 4.93 for "assume the last result".
5. ~~Stan version of the trend~~ — **not needed, and the interesting half was
   tested without it.** Fat tails were the main reason to want Stan, and they
   were built instead as Student-t observation noise by IRLS, measured, and
   rejected on their own numbers (MAE 2.791 against 2.779). What Stan would
   still add is honest uncertainty in the hyperparameters themselves, which
   we currently treat as known. That is a real gap but a second-order one,
   and it costs the exact sparse solve — seconds per cycle becomes minutes.
   Revisit only if the intervals start failing calibration.

## The published page is now executed, not just generated (2026-08-15)

`tools/check-page.js` runs the page's own JavaScript against a stub DOM and
fails the build if any block did not draw, reported as check **G1**. Nothing
else covered it: `R CMD check` never looks at HTML, `node --check` parses
without running, and a browser shows a page missing three of four charts as
merely quiet.

The instructive part is that the check was wrong three times before it was
right, and every wrong version *passed*:

1. Counting only `innerHTML`/`textContent` called the three SVG charts
   missing on a healthy page — they are built with `appendChild`.
2. "Was anything written" then passed a page whose pendulum had failed,
   because the block appends its axes before it touches the data. The real
   signal is the template's own `draw()` guard, which logs the failure.
3. Conditional blocks (`datawarn`, `leadcav`) were exempted from the
   must-render rule outright, so a caveat that silently failed still read as
   OK — and `leadcav`'s condition holds right now. Each conditional now
   carries a predicate over the page's own embedded data.

Plus a fourth found while fixing the third: the regex extracting that data
required `};\n` and R on Windows writes `};\r\n`, so it never matched.

**The rule, now in ARCHITECTURE.md: prove a check fails on a deliberately
broken input before trusting it to pass.** Every guard in the file has been
run against a page corrupted in the specific way it claims to detect.

Related: check codes are hand-maintained across seven scripts and nothing
enforced uniqueness. `B1` was claimed by both `fit_projection.R` and the page
check; the page check is now `G1` and `run_all.R` stops on any clash.

