# auspol — work queue

Updated 2026-08-15. Remote: github.com/peteowen1/auspol (private, default
branch `dev`; `main` exists and is reached only through a reviewed PR).

Completed stage write-ups live in
[backlog/journal-2026-08.md](backlog/journal-2026-08.md) — this file holds
open state, not the narrative of how it got here.

## Awaiting Pete

- **Merge PR #2** — github.com/peteowen1/auspol/pull/2, version 0.2.0. The
  forecast page, `run_all.R` + freshness, CI, `ARCHITECTURE.md`, and the
  seven fixes from the second review gate. PR #1 is merged, so `main` exists.
  CI green on the current head.
  It has since grown well past that: **16 commits, 20 files, +2143/−208**,
  adding the scheduled refresh, the leadership caveat, the page test and the
  check-code registry.

  **Reviewed in three passes, all before merge**, because the PR kept growing
  after each one — work pushed to `dev` joins the open PR automatically, which
  is the shape the review gate is least able to catch on its own. Pass 1: the
  modelling commits, before the PR existed. Pass 2: the workflow and version
  bump, which found that this bullet claimed the whole PR was pre-reviewed.
  Pass 3: the page test, which found three real defects (see below).

  **In hindsight this should have been a stack.** A 20-file PR is past the
  size where one review can be thorough, and `gh-stack` exists here precisely
  so a mechanical layer gets a cheap pass while a logic layer gets a real one.
  Worth doing next time the work runs this long before merging.
- **Repo is still private and `dev` is still the default branch**, both by
  choice. Going public remains a separate decision (see below).
- **Decide whether the repo goes public.** It was created private on purpose.
  Two things in it are outward-facing and should be a deliberate choice, not
  a side effect: `docs/plans/product-features.md` contains critical
  commentary on named competitors (theswingison, DemosAU — the latter also a
  pollster in our own data), and the pollster scorecard publishes named
  firms' house effects and accuracy. Both are defensible; neither should
  appear publicly by accident.
- **Poll data licensing** — unchanged and now more pressing if the repo goes
  public. The anchor's data is gitignored and not committed (verified before
  the first push: no `external/`, no CSVs, no outputs are tracked), so
  nothing of his is republished. Formal permission is still worth having.

- **Answer the four improvement-quiz questions** (from session chat; context in
  [ANCHOR-MODEL.md](ANCHOR-MODEL.md) "Honest assessment"): demographics in the
  seat model, seat-level preference flows, the 2019 herding problem, and the
  trend-vs-simulator scope call. #4 was pre-empted: trend built first — confirm
  or redirect.
  The anchor repo (d-j-hirst/aus-polling-analyser) has no LICENSE; his site
  invites use of the files, but formal permission is worth having.
- ~~Create GitHub remote~~ — **done 2026-08-15**, private, see above.

## Also worth a look (Pete found, 2026-08-14)

- **theswingison.com** — an existing Australian forecast site. Its
  *preference simulator* (12-rule hierarchy keyed on who is eliminated and
  who remains, with a confidence score per rule tier) is genuinely better
  than a fixed flow rate and worth stealing for the seat stage. Its poll
  aggregation is weaker than ours: a Gaussian kernel rolling average that
  explicitly does **not** remove systematic house effects, and an outlier
  rule that penalises polls for disagreeing with the local consensus —
  herding by construction.
- **demosau.com MRP** (Aug 2026) — 9,343 respondents May–Jul 2026, MRP to
  all 150 seats, 20,000-simulation Monte Carlo, preferences from a mix of
  previous-election and respondent-allocated flows. Reports a hung
  parliament: ALP 60–72, ONP 53–66, Coalition 11–22, GRN 1–5, OTH 3–7.
  Two things matter for us. (1) It independently corroborates ONP at
  historic highs, the single most surprising number in our own 2028 fit.
  (2) DemosAU is also a **pollster in our input data**, and our federal
  2028 fit gives their polls a −2.1 point house effect on ALP FP, the
  second largest of any firm — worth stating plainly if we ever cite them.
  No backtesting is published and the MRP specification (levels,
  poststratification frame) is not disclosed, so the seat ranges cannot be
  independently assessed.
- **buildaballot.org.au** — non-partisan "answer questions → match to
  candidates → drag into a ballot order" tool by Project Planet Inc. A
  possible companion product to the forecast, not a modelling input.

Feature comparison of all four sites and the proposed build order:
[plans/product-features.md](plans/product-features.md).

## Next build steps (in rough order)

1. ~~Estimate model hyperparameters instead of fixing them~~ — **done**
   (session 2): exact log marginal likelihood, L-BFGS-B, plus a per-pollster
   noise-factor stage. See "Done".
2. ~~Poll-share transformation~~ — **done** (session 2, stage 3), but not as
   planned: a global switch to logit was REJECTED by its own pre-registered
   test. The scale is now chosen per party by comparable log evidence. See
   "Done" and the open question below.
3. ~~Handle "modelled party folded into OTH"~~ — **done** (session 2). See
   "Done". Was: some polls (e.g. ResolvePM
   Jan 2026 NSW) report ONP inside OTH; anchor imputes from trend and
   subtracts. We currently over-count OTH in those polls.
4. ~~Fundamentals stage~~ — **done** (2026-08-15), as ridge rather than
   elastic net, penalty chosen leave-one-election-out. Two-party MAE 3.05
   against 4.93 for "assume the last result". See "Done".
5. ~~Stan version of the trend~~ — **not needed, and the interesting half was
   tested without it.** Fat tails were the main reason to want Stan, and they
   were built instead as Student-t observation noise by IRLS, measured, and
   rejected on their own numbers (MAE 2.791 against 2.779 — see the negative
   result below). What Stan would still add is honest uncertainty in the
   hyperparameters themselves, which we currently treat as known. That is a
   real gap but a second-order one, and it costs the exact sparse solve —
   seconds per cycle becomes minutes. Revisit only if the intervals start
   failing calibration.

Still ahead: ABS Census electorate demographics (CED/SED + SA1
correspondences) for a seat model that knows something about each seat, and
theswingison's preference-simulator idea (see below) in place of a fixed
flow rate.

## Open: the negative tail of the tracking check (L4c)

L4 was pre-registered two-sided (|acf1| < 0.25) and now ships **one-sided**,
because only the positive side is calibrated. Over-smoothing is unambiguous:
simulated correct fits never exceeded +0.118, over-smoothed ones give ~+0.97.

The negative side is not. The synthetic null centres at −0.045, but the 17
real federal party-cycles centre near −0.11, and NSW reaches −0.41. Real
polling has structure the synthetic generator lacks: Morgan's multi-mode
series uses overlapping rolling samples, about half of all reported values
are whole numbers, and publication dates cluster. Any of those could shift
the null. Enforcing an uncalibrated bound would be enforcing a number
rather than a finding, so the values are printed and left open.

**To close it:** build the null by resampling the real polling calendar
(same dates, same firms, same rounding) rather than an idealised one, then
set the bound from that. Until then a large negative value is a hint to
look, not a failure.

## Open question from stage 3 (worth a proper answer)

**Why do ALP, LNP and (federally) ONP fit better in raw percentage points
than in logit?** The logit scale wins decisively for OTH (+50 log points),
UAP (+10) and GRN (+2), and loses for ALP (−3), LNP (−5) and ONP (−9). The
majors losing is unsurprising — near 35% the transform is nearly linear, so
there is little to gain and a Jacobian to pay for. ONP is the real puzzle.

Best current guess, NOT established: the federal sigmas are estimated only
on completed cycles, where ONP sits at 2–10%; its 6%→32% climb is entirely
inside the live 2028 cycle the estimator never sees. Including the live
cycle flips ONP to logit by +70 log points, which is consistent with that
story — but we deliberately do not select on the live cycle, because
tuning the live forecast on itself is exactly what the separation prevents.

Two candidates worth testing before trusting either scale for minor
parties: reported-value discretisation (about half of all poll values are
whole numbers, which is a much coarser grid in log-odds at 3% than at 35%)
and the fact that a party polling near zero has a genuinely skewed, not
just bounded, sampling distribution. A Student-t observation model (stage 5,
Stan) may make the question moot.

## Known limitations of the current skeleton (documented, accepted for now)

- Sigmas are estimated from COMPLETED cycles and held fixed for the live one
  (no propagation of hyperparameter uncertainty into the bands).
- Firm noise factors are an empirical-Bayes approximation on pooled
  standardised residuals, not per-firm sigmas inside the marginal likelihood.
- Party trends are still fitted INDEPENDENTLY, so fitted shares only sum to
  ~100 by luck (checked: 98.9–101.2 federally, 95.5 for NSW 2027). A proper
  multinomial-logit / softmax model would couple them, at the cost of the
  per-party independent solve. This is the largest remaining structural
  approximation.
- Scale selection is per-party and post-hoc (see the open question above);
  it should be revalidated on the next completed cycle.
- House effects constant within a cycle (anchor uses new/old split).
- TPP error bands assume independent party trends (mildly conservative).
- OTH double-counts a modelled party when a poll folds it in (see #3 above).
- No undecided-voter rescaling (anchor CSVs appear already rescaled; verify).

## Victoria 2026 is the target — 106 days out as of 2026-08-14

Settled 2026-08-14. Victoria votes **28 November 2026**, the nearest real
deadline by a long way (NSW 2027, federal 2028, Qld 2028) and the only
chance this cycle to publish a forecast and have it graded in months rather
than years. `scripts/fit_vic.R` fits 2018 and 2022 as validation plus the
live 2026 cycle.

**Current standing (trend only — no fundamentals or seat model yet):**
LNP 28.6, ALP 25.4, ONP 20.9, GRN 12.9, OTH 10.5; derived ALP TPP 47.3
(95%: 45.1–49.5), against 55.0 at the 2022 election.

**Projection to election day** (105 days out): ALP two-party
**46.8 (95%: 41.9–51.7)**, trend weight 0.57 — an 8.2-point swing against a
Labor government seeking a fourth term. Trend and fundamentals agree closely
and independently (47.1 vs 46.5), which is corroboration rather than
confirmation: they share no inputs, but both could be wrong in the same
direction if 2026 repeats 2018's polling miss.

**The published intervals are calibrated.** Refitting mix weight, bias and
spread with each election held out, over 195 election-horizon pairs: nominal
95% intervals contain the truth 92.8% of the time, nominal 80% 76.4%, nominal
50% 54.9%. Excess kurtosis −0.17, essentially normal, so no fat-tailed or
asymmetric error model is warranted — measured rather than assumed.

**Seat forecast**: ALP **35 of 88** seats (50%: 29–41, 90%: 19–49),
P(ALP majority) **14.2%**, a median loss of 21 seats from the 56 won in 2022.

## Findings from the Victorian build worth keeping

- **The polls, not the model, missed 2018.** Our 2018 Victorian trend ends at
  ALP TPP 54.17 against a final-30-day published-poll mean of 53.93 — the
  trend tracks the polls to a quarter of a point. The actual result was
  57.60. That "Danslide" 3.67-point polling error is exactly what the
  projection stage exists to correct, and Victoria supplies two clean
  measurements of it (2018: +3.67, 2022: +0.33).
- **House-effect correction hurt in Victoria 2022, by about 2.4 points.**
  Our LNP endpoint is 32.07 against a final-poll mean of 34.11 and an actual
  of 34.48. The correction is behaving correctly — the last month's polls
  over-represent firms with positive Coalition house effects (Newspoll2
  +3.31, Redbridge +1.87), so the raw mean is the biased quantity — but here
  the bias happened to point at the truth. One election is one data point,
  and it is an argument for the anchor's bias-consistency weighting over our
  poll-count weighting of the sum-to-zero constraint. Worth revisiting when
  the seat model needs accurate majors.
- **Victorian One Nation polls are sub-binomial**, i.e. they agree with each
  other more closely than pure sampling error permits at n=2500. That is the
  herding signature. The noise is now floored at the binomial bound and the
  party-cycle reported, rather than the model inheriting false precision.

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

## Where seat-count uncertainty actually comes from (measured 2026-08-15)

Three separate simulations at the projected Victorian vote, sd in seats:

| source | sd |
|---|---|
| statewide projection error alone | 10.87 |
| seat and regional variation alone | 3.96 |
| both together | 8.69 |

**Do not read these as a variance decomposition** — they do not add, because
the seat count is a step function of the vote and the components interact.
An earlier version divided them and reported "156% of the variance", which is
how the non-additivity was caught.

Two things follow.

1. **The statewide vote dominates.** Accuracy in the PROJECTION is worth far
   more than further seat-model refinement. That reorders the remaining work:
   fat-tailed observation noise and per-horizon bias correction beat per-seat
   elasticity and candidate effects.
2. **Per-seat randomness makes the seat total LESS volatile, not more** (8.69
   against 10.87 with no seat noise at all). Victorian Labor seats bunch
   tightly on the pendulum — a dense cluster between 54 and 60 — so a uniform
   swing sweeping through them flips many at once. Per-seat noise smooths that
   step and damps the amplification. Counterintuitive, and it means the
   pendulum's SHAPE matters as much as the swing.

## Victoria has a new premier, and the forecast has barely seen it (2026-08-15)

**Carroll replaced Allan on 2026-07-28**, four months out. Allan stood down
after months of falling polls and a rising One Nation challenge — which
independently corroborates the ONP numbers our own fit found surprising
(`O1`: ONP led ALP on 22 of 461 fitted days, peaking at 29.3).

The model has **no leader term**, by measurement rather than oversight (see
the negative result below). A change therefore reaches the forecast only
through polls taken after it, and there have been **3**, moving ALP first
preference 25.17 → 24.67 — nothing, on that sample. Any honeymoon or backlash
beyond those three polls is simply not in the published numbers.

The page now says so, in the caveats, with the leader, the date and the poll
count computed from the data so the wording cannot go stale, and shown only
while the change is recent enough to be under-observed.

Worth watching rather than modelling: if the next handful of polls move
sharply, the random walk will absorb it with a lag, because its step size is
estimated from ordinary periods and a leadership change is not one. Inflating
the walk sigma around a known structural break is the principled fix and
would need its own pre-registered test before it went anywhere near the page.

## Negative result: a leader-change term does not belong in fundamentals (2026-08-15)

Leader *approval* is not in the anchor's data, but `government-leaders.csv`
is, and it dates every change of government leader back to 1938 — so "did the
governing party change leader during this term" is free. Australian politics
says it should matter. It does not, and the way it fails is instructive.

There is plenty of variation to work with: **31 of 56 elections** in the
fundamentals set had a mid-term leader change, so this is not a small-cell
problem.

The raw split looks like a finding. Mean swing to Labor +0.51 where the leader
changed against +1.12 where it did not, and — more interestingly — a swing sd
of **7.28 against 5.31**, suggesting a leader change makes the result more
volatile even if it does not move the mean. Per the "prefer the variance to
the mean" rule that is the more promising half.

**Both halves evaporate once conditioned on the features already in the
model.** Regressing swing on `prev1 + govt_years + opp_years + is_incumbent +
fed_aligned` and adding the leader-change indicator:

- **Mean effect: 0.83 points, se 1.27, p = 0.52.** Indistinguishable from zero.
- **Variance effect reverses.** Residuals are *smaller* when the leader
  changed (mean |resid| 2.59 against 3.11), F = 0.65, p = 0.26, ratio CI
  [0.29, 1.38]. The raw sd gap was the other predictors, not the leader.
- Sizing: `s²/2σ²` with s = 0.83 and σ = 3.57 is **2.7% of error** — about
  0.08 points on a fundamentals MAE of 3.05, and fundamentals carry roughly
  0.45 weight in the projection, so ~0.04 points on the published number.
  That is the *optimistic* reading, taking a p = 0.52 coefficient at face
  value.

Not built. Worth recording because the raw comparison was persuasive and
pointed the wrong way on the variance — the confound was `govt_years`, which
correlates with leader change (0.12) and is already a predictor. Fifteen
minutes of sizing replaced building a feature and then discovering this.

## Preference flows are now estimated, not assumed (2026-08-16)

Pete's direction, and it reframed the whole question: **never hand-code an
assumption — derive it from data so it moves as data arrives.** And more
broadly, auspol is *inspired by* AE Forecasts and theswingison rather than a
reimplementation of either; where both do something poorly we skip it or do it
better. This is the first place that bites.

Both references hand-set preference flows. AE Forecasts authors the value and
borrows across regions (`2026,vic,ONP FP,25.5,#Use federal pref flow
estimate`), so the same borrowed number stands for three future elections as
though it were three estimates. theswingison uses a twelve-rule hierarchy —
better than one rate, still hand-authored rules no election can update.

**Ours is estimated**: the mean of a party's five most recent observed
elections, pooled across regions, moving as elections are held.

**The estimator was chosen by strict temporal backtest** — each election
predicted from only earlier ones, 103 elections, eleven candidates:

| | MAE |
|---|---:|
| **mean of last 5** | **4.815** |
| last in region | 4.863 |
| mean of last 3 | 5.027 |
| linear trend | 5.282 |
| exp decay, 4-yr half-life | 5.669 |
| exp decay, 8-yr + region bonus | 6.544 |

Two results worth keeping:

- **The linear trend came fifth**, though the trends are real and strong
  (Greens +1.10 points/year over 53 elections, One Nation −0.605 over 21, both
  p < 0.001). Leave-one-out endorsed it and leave-one-out was wrong: it lets a
  later election inform an earlier prediction.
- **Every weighting scheme lost, monotonically in the half-life.** A hard
  window beats soft decay because decay never fully discards anything, so a
  1998 flow of 54% keeps a vote forever while behaviour has drifted to 26%.
  Same-region weighting had *no effect at all* (6.544 vs 6.541).

Victoria: ONP 25.5 → 33.7, GRN 81.9 → 83.5, OTH 49.3 → 48.9. **Published
two-party 46.8 → 47.8.**

`scripts/backtest_flows.R` re-runs the comparison every pipeline run and fails
as **G3** if the adopted estimator stops winning, with a 0.15 MAE tolerance so
ordinary jitter does not cause churn. The choice is itself made from data and
would otherwise have been correct once and unexamined forever.

**Still open:** per party the ranking differs — One Nation prefers the mean of
3 (3.155 vs 3.744), the Greens prefer last-in-region. Reported by G3, not
acted on: 16 and 38 elections cannot support choosing an estimator each.
Revisit if a principled grouping appears (say, by party size or by how much
history exists) rather than per-party cherry-picking.

## One Nation preferences: measured, and smaller than it looks (2026-08-15)

Full evidence:
[reviews/onp-preference-flows-2026-08-15.md](reviews/onp-preference-flows-2026-08-15.md).

The forecast assumes **25.5%** of One Nation preferences go to Labor — lower
than every one of the 21 elections actually held, and an assumption rather
than an observation. It is not uniquely lowest: the same 25.5 is used for NSW
2027 and federal 2028, so the three lowest entries are one forward view
repeated. With ONP on 20.9% of the vote this is the largest single lever
on the two-party number.

Three findings:

1. **The page's caveat was factually wrong.** It said the flow came from
   federal elections; `flows_for()` deliberately never reaches across regions,
   and the anchor authored a Victorian 2026 row. Fixed, and the sensitivity is
   now published rather than buried in an input file.
2. **Pooled spread overstates the uncertainty twofold.** The 8.70 sd across
   all estimates is mostly a thirty-year trend (−0.605 points/year, R² = 0.74);
   residual scatter is **3.73**. The trend predicts 34.1 for 2026, so the
   assumption sits **2.3 sds low**. New check **G2** fails past 2.5 sds.
3. **It does not change the answer.** Recomputing the whole projection:

   | Flow | Source | Published ALP TPP |
   |---:|---|---:|
   | 25.5 | current | **46.8** |
   | 34.1 | fitted trend | 47.8 |
   | 36.15 | SA 2026 observed, ONP 22.9% | 48.0 |
   | 42.0 | Victoria 2018 | 48.7 |

   Labor never reaches 50 under any plausible flow. The mix weight is 0.52 and
   fundamentals (46.47) are flow-independent, so the headline moves about half
   the trend shift — +1.2 points for the best comparator, half a standard
   error.

A first-pass linear estimate gave +2.2 points and "line-ball" — nearly double,
and the wrong qualitative conclusion. The mix weight is exactly what a
back-of-envelope drops.

**Awaiting Pete — the flow was deliberately not changed.** It is the anchor's
authored input, he is the domain expert, and now that the effect is measured
it shifts nothing a reader would conclude. Three options: keep 25.5 and
publish the sensitivity (done); adopt the trend value 34.1; or ask the anchor
directly why 25.5, given SA 2026 delivered 36.15 on a comparable ONP vote.
The third is the cheapest and would settle it.

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

## The forecast refreshes daily, and deliberately does not publish itself

`.github/workflows/forecast.yaml` runs at 06:00 Melbourne: shallow sparse
clone of the anchor's `analysis/` directory, then the whole pipeline, then
the headline numbers and every pre-registered check into the run summary.
The page is uploaded as a downloadable artifact.

**It does not publish**, and that is the decision rather than an unfinished
step. This page has already shipped once with three of four charts silently
not drawing, and could once have rendered a fabricated "0% chance of a Labor
majority" — both from failures that produced plausible-looking output rather
than an error. Unattended republishing turns exactly that class of bug into
a confident wrong number in front of readers. Revisit once the job has run
clean for a few cycles and the checks have proven they catch what they claim.

Validated by dispatch rather than assumed: `quick=true` and full mode both
green on a clean runner. Since `output/` is gitignored, the runner built the
forecast from nothing but source and the anchor's CSVs — which makes this
also the first real proof the pipeline reproduces off this laptop.

Open: the freshness gate stops the run past 60 days, so if the anchor's repo
goes quiet the job fails daily until someone looks. That is the intended
behaviour. GitHub does email the owner when a scheduled workflow fails, so
there is a notification path, but it is the kind that gets filtered — worth
confirming it actually arrives before treating the job as self-monitoring.

## Done

Full write-ups moved to [docs/backlog/journal-2026-08.md](backlog/journal-2026-08.md) on 2026-08-15 — 11.5k characters of completed-stage narrative that every session in this repo was re-reading on every turn. Index of what is in there:

- 2026-08-15 (stage 8): Regional swing structure in the seat model
- 2026-08-15 (stage 7): Seat model — the pipeline is end to end
- 2026-08-15 (stage 6): Fundamentals + projection — it is a forecast now
- 2026-08-14 (session 2, stage 5): Parties folded into "Others" corrected
- 2026-08-14 (session 2, stage 4): Per-cycle volatility — the model now reproduces One Nation leading
- 2026-08-14 (session 2, stage 3): Logit-scale modelling — adopted per party, not globally
- 2026-08-14 (session 2): Hyperparameters estimated, not fixed
- 2026-08-14: Anchor model analysed; package skeleton; Jackman trend; federal and NSW cycles fitted

