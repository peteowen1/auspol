# auspol — work queue

Updated 2026-08-18. Remote: github.com/peteowen1/auspol (private, default
branch `dev`; `main` exists and is reached only through a reviewed PR).

Completed stage write-ups live in
[backlog/journal-2026-08.md](backlog/journal-2026-08.md) — this file holds
open state, not the narrative of how it got here.

## Awaiting Pete

- **PRs #5–#8 merged** (2026-08-17/18). Each was reviewed before opening and
  each review caught a real defect the tests could not: four stale published
  seat figures, roxygen documenting a field under the wrong argument, and a
  correction pass that had missed two of its own targets. **The review gate is
  earning its cost — do not skip it, least of all on docs-only diffs, which is
  where skipping feels most defensible.**

  The stacking lesson is now recorded four times and acted on zero. `gh-stack`
  is installed (v0.1.0). The seat rebuild has three separable layers and is
  exactly what it is for.
- **VEC data licensing — now blocking, not theoretical.** The Victorian
  distribution data fetched 2026-08-18 sits in the session scratchpad. The VEC
  publishes **no** copyright, Creative Commons or terms-of-use statement on any
  results page, and `vec.vic.gov.au/copyright` returns 404. Fetching for
  analysis is unproblematic; **committing it is redistribution**, and the
  approved plan is to commit. `R/paths.R` already states the convention for the
  anchor's data — "carries no formal license, so it is never committed" — and
  the same reasoning applies here. Derived aggregates (a measured flow rate with
  provenance) are arguably facts rather than a copy of their dataset; raw tables
  are not. Needs a decision before the rebuild lands.
- **Decide whether the repo goes public.** Private on purpose. Two things are
  outward-facing and should be deliberate: `docs/plans/product-features.md`
  carries critical commentary on named competitors (theswingison, DemosAU —
  the latter also a pollster in our own data), and the scorecard publishes
  named firms' house effects and accuracy. Both defensible; neither should
  appear publicly by accident.
- **Poll data licensing.** The anchor's data is gitignored and not committed —
  verified: no `external/`, no CSVs, no outputs are tracked — so nothing of
  his is republished. His repo has no LICENCE and his site invites use of the
  files, but formal permission is worth having before going public.
- **Answer the four improvement-quiz questions** (context in
  [ANCHOR-MODEL.md](ANCHOR-MODEL.md), "Honest assessment"): demographics in the
  seat model, seat-level preference flows, the 2019 herding problem, and the
  trend-versus-simulator scope call. Two of the four now have measured answers
  — see the seat-type and methodology reviews below — so this is smaller than
  it was.
- **Decide whether to transfer South Australia's allocation slope.** The form
  that allocates a One Nation surge across seats was validated on SA 2026 and
  wins there (2026-08-17, below). Applying it to Victoria means borrowing one
  number — the slope, 1.21 — from another state's party system, because
  Victoria has no 2026 outcome to estimate from. The level would come from our
  own forecast. Defensible, but it is an assumption of exactly the kind this
  project avoids, so it should be a decision rather than an implementation
  detail.

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

**Latest result** (local, from fetched data): ALP 41 (90%: 32–48), LNP 38,
GRN 5, ONP 3. Greens hold their four — Brunswick 100%, Melbourne 99.6%,
Richmond 96%, Prahran 72% — and One Nation's strength is Melton 62%,
Greenvale 39%, Sydenham 27%. Sixteen seats have a minor party above 10%.

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

## Closed session write-ups

Moved to [backlog/journal-2026-08.md](backlog/journal-2026-08.md): the
2026-08-15 review gate, the pollster scorecard build, the post-merge
publishing work, and two negative results (fat-tailed poll noise, per-horizon
bias correction). Their conclusions live in the code, `CONSTANTS.md` or
`reviews/`; the narrative does not need reloading every session.

## Also worth a look (Pete found, 2026-08-14)

- **theswingison.com** — an existing Australian forecast site. Its
  *preference simulator* (12-rule hierarchy keyed on who is eliminated and
  who remains, with a confidence score per rule tier) is genuinely better
  than a fixed flow rate and worth stealing for the seat stage. Its poll
  aggregation uses a Gaussian kernel rolling average that explicitly does
  **not** remove systematic house effects, and an outlier rule that penalises
  polls for disagreeing with the local consensus — herding by construction.

  **Audited 2026-08-18.** This previously read "weaker than ours". Half of
  that is substantiated and half is not, so the verdict is withdrawn and the
  mechanism left to speak for itself:
  - *Substantiated:* we do remove systematic house effects — estimated with a
    soft weighted sum-to-zero constraint (`R/trend.R:119`). That is real and
    it is in the shipped code.
  - *Not independently checked:* that their aggregation does not. It rests on
    Pete's reading of their published method (2026-08-14), which I have not
    verified against their site.
  - *Never measured:* **we have never compared our accuracy against either
    reference, on any output.** Every comparison in these docs is a mechanism
    argument, not a result. Removing house effects is sound reasoning for why
    ours should track better, and reasoning is not evidence.
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

## Victoria 2026 is the target — 104 days out as of 2026-08-16

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

**Seat forecast**: ALP **39 of 88** seats (50%: 33–45, 90%: 23–51),
P(ALP majority) **26%**, a median loss of 17 seats from the 56 won in 2022.

These four figures were stale until 2026-08-17 — they read 35, 29–41, 19–49
and 14.2%, the values from before the preference-flow estimator moved the
published two-party from 46.8 to 47.8. The TPP line above was updated at the
time and the seat line was not, so this file spent a day describing a
materially more pessimistic forecast than the model produced. Source of truth
is `output/vic-page-data.json`, and `scripts/fit_seats.R` reproduces it.

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

## Preference flows are estimated, not assumed (2026-08-16)

Pete's direction, and it reframed the question: **never hand-code an assumption
— derive it from data so it moves as data arrives.**

`flows_for()` estimates each party's flow as the mean of its five most recent
observed elections, pooled across regions. The estimator was chosen by strict
temporal backtest over 103 elections against eleven candidates;
`scripts/backtest_flows.R` prints all eleven and is the authority, and
`R/flow_model.R`'s header carries the ranking. `G3` re-runs it every pipeline
run with a 0.15 MAE tolerance and fails if the adopted method stops winning.

Victoria: ONP 25.5 → 33.7, GRN 81.9 → 83.5, OTH 49.3 → 48.9. **Published
two-party 46.8 → 47.8.**

**The claim that this beat both references is WITHDRAWN (2026-08-18)** — the
comparison was made on the wrong axis. Ours estimates a *scalar share to
Labor*; theswingison's twelve rules are keyed on who has been excluded and who
remains, which is how a seat is decided, and measured flows swing by tens of
points with that configuration (GRN→ALP 74.5 vs 81.5; ONP→ALP 19.3 vs 57.0).
Full correction in `R/flow_model.R` and
[reviews/clean-flow-backtest-2026-08-18.md](reviews/clean-flow-backtest-2026-08-18.md).

**Still open, and genuinely open:** per party the ranking differs — One Nation
prefers the mean of 3 (3.155 vs 3.744), the Greens prefer last-in-region.
Reported by `G3`, not acted on: 16 and 38 elections cannot support choosing an
estimator each. Revisit only if a principled grouping appears (party size, or
how much history exists) rather than per-party cherry-picking. **Note that
`last_in_region`'s apparent strength was substantially a contamination
artefact** — it fell from 2nd to 6th on a clean target set — so the Greens half
of this is weaker than it looks.

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

