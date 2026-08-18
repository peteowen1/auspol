# auspol 0.4.7

The candidate-level seat simulation moves from a session scratchpad into the
package. **No published number changes**: `simulate_seats()` and the page are
untouched.

## New exported functions

- **`build_flow_matrix()`** — turns observed transfers into preference rates
  keyed on the excluded party **and the set of survivors**, because where a
  party's preferences go depends on who is still standing. Cells below `min_n`
  are withheld rather than returned, and every cell appears in a coverage
  table with its event count, so a rate resting on two exclusions is
  distinguishable from one resting on fifty.
- **`distribute_preferences()`** — runs a single seat's count: exclude the
  lowest, transfer at the estimated rate, repeat to a final two.
- **`simulate_seat_contests()`** — simulates every seat many times and returns
  a per-seat win probability by party.

Together these let a Green, an independent or One Nation win a seat. The
published two-party model gives those outcomes probability exactly zero, not
because they are unlikely but because a two-party margin is the only thing it
knows about a seat.

**None of the three needs external data.** The VEC and ECSA election data
cannot be committed pending the licence question, so the functions were
designed to take a plain transfers table and be fully testable without it.
55 tests across the three files; 300 in the suite.

Performance: 87 seats × 2,000 simulations in **9.7 seconds**, so a
20,000-simulation run is about 100 seconds. Parties are held as integer indices
and the survivor set as a bitmask; seven million named-vector lookups would
have made this slow enough that nobody re-runs it.

## Fixes

Two defects found by the pre-PR review of this same code, both reproduced
before fixing and both covered by tests verified to fail against the pre-fix
version:

- **`simulate_seat_contests()` crashed** on any flow cell naming a party that
  does not contest the seats being projected. `pidx` is an atomic vector, so
  `pidx[["missing"]]` throws rather than returning `NULL`, which made the
  adjacent `is.null()` guard dead code. Historical transfer data routinely
  contains exclusions of parties absent from a given seat set.
- **`distribute_preferences()` silently lost votes** when `shares` carried a
  duplicate name. Exclusion removes by name, so two entries labelled `IND` were
  deleted in one pass while only the smaller was redistributed — 15 of 100
  votes vanished and the count terminated a round early. Duplicates are now
  refused with the offending names reported.

## Deliberately not included

The One Nation seat allocation. Its ordering beats a uniform allocation by only
0.12 MAE and its magnitude is borrowed from South Australia's observed spread,
making it the weakest link in the prototype result. It needs its own
pre-registered treatment before anything publishes.

# auspol 0.4.6

A working seat-by-seat simulation in which minor parties can win, plus a
labelling fix to the marginal-seats output.

## The headline

The published model cannot represent a minor party winning a seat: it
simulates 83 of 88 as Labor-versus-Coalition and assumes the other five are
held, with no uncertainty. A prototype simulation now covers **87 districts
candidate-level**, distributing preferences the way the count runs — lowest
excluded, transferred at rates measured from real counts conditional on who
remains, until two are left.

| party | median seats | 90% range |
|---|---:|---|
| ALP | 41 | 32–48 |
| LNP | 35 | 29–42 |
| GRN | 5 | 4–7 |
| ONP | 5 | 1–12 |

25 seats have a minor party above 10%. The Greens hold their four and gain
Pascoe Vale at 55%; One Nation's best is Melton at 86%. Yan Yean is the
tossup, a genuine three-way at LNP 44 / ALP 31 / ONP 25.

> **Superseded.** These probabilities came from a run that rebuilt the
> statewide distribution instead of inheriting the projection, making it about
> 40% too confident. Corrected figures are in
> `docs/reviews/seat-sim-working-2026-08-18.md`; Melton is 57%, not 86%.

**Not published**, and not a replacement for the two-party model. It runs from
data fetched into a scratchpad and the VEC licence question is unresolved.

## Data

**ECSA has a public JSON API** — no key, no browser. The acquisition plan
written before checking had assumed the Angular results site required browser
automation and deprioritised South Australia for it. Reading the app's own JS
bundle found the endpoint in minutes; `HAChange/2026-03-21/0` returns 2.3 MB
carrying `finalDistribution` for all 47 districts. **294 exclusion events**,
against 97 across 16 districts from the Wikipedia sample the work had been
stuck on.

## Fixes

- **`simulate_seats()` now returns `alp_tpp_proj`**, the seat's 2022 two-party
  share plus the projected statewide swing, and `scripts/fit_seats.R` prints
  `alp_2022` and `alp_proj` with the swing stated above the table. The single
  unlabelled column made a seat on 57.2 beside a 50.2% win probability look
  like a bug; on a −7.0 point swing it is exactly right.
- **Per-party statewide uncertainty is taken from the fitted trend** rather
  than a flat assumed 2.0 points, scaled by the factor the two-party sd grows
  by to election day (×1.89 at 102 days out), with draws renormalised so the
  parties trade against each other. The answer barely moved, which says the
  assumption had been fair but underived.

## Two bugs worth recording

- **A sparse fallback row invented an answer.** With no observed cell for Labor
  excluded while the Greens and One Nation stand, the pooled Labor row was used
  — and it shows Greens 0.0%, because that configuration never arose in South
  Australia. Renormalising over the survivors handed every Labor ballot to One
  Nation, which is why the first run had One Nation winning Richmond. Absence
  of evidence had become certainty of zero. Every row is now smoothed toward
  uniform.
- **The SA-fitted One Nation allocation does not transfer to Victoria**, which
  settles a question that had been left open for Pete. Its intercept could not
  put One Nation below about 15% in any seat, and South Australia contains no
  seat resembling Brunswick to fit against. Replaced with ordering from
  Victorian federal 2025 divisions and magnitude from SA's observed spread at a
  comparable statewide level.

# auspol 0.4.5

Measurement and corrections. No model behaviour changes, no forecast number
moves. One new script.

## Added

- **`scripts/audit_flow_record.R`** — reports carried-forward duplicates in the
  observed preference-flow record, under two explicit definitions, with the
  `as_of` date printed. Exists because the first audit of this was ad hoc and a
  later run of the same logic disagreed with figures already written into
  `docs/reviews/`. An audit whose answer depends on when it ran is not an audit.

## Measured

All 88 VEC districts fetched and parsed: **452 exclusion events across 76
districts, every one reconciling exactly** against the excluded candidate's
pile. Candidate-level, so each minor party and independent is excluded
separately. The data is **not committed** — the VEC publishes no licence and
its copyright page 404s, and `R/paths.R` already states this convention for the
anchor's data.

- **The model's Greens preference flow is 4.3 points too generous to Labor**:
  79.2 measured across 29 districts and 211,842 ballots, against 83.5 used.
  Not changed — the estimator producing 83.5 was chosen by pre-registered
  temporal backtest, and substituting one election's observation after the fact
  is what that pre-registration prevents.
- **13.4% of the observed flow record is carried-forward duplicates.** Western
  Australian Nationals sit at exactly 5.0 for ten consecutive elections.
  Victorian Others is 49.25 three times. One is demonstrably wrong: Victorian
  2022 Greens, recorded 81.94, measured 79.2.
- **The estimator survives cleaning.** `mean_last5` wins all three
  pre-registered variants. But `last_in_region` sat 0.048 MAE off the winner on
  the raw target set and fell to 0.727 behind — second place to sixth — once
  carried-forward targets were removed. Its second place was substantially an
  artefact of duplicated data.
- **The OTH bucket blends opposite behaviours**: independents flow to Labor at
  61.1%, minor-right at 35.4%, against a single assumed 48.872. Per-seat implied
  flow ranges 37.1–58.7. This affects nothing published — `simulate_seats()`
  reads the anchor's notional margins, which come from the actual count — but it
  is a prerequisite for any primary-vote rebuild.

## Corrected

Three sizing errors, all found and fixed this cycle:

1. **"Correcting the Victorian flow record is worth 0.564 points of published
   two-party vote."** It is worth **zero**. `estimate_flow()` averages the five
   most recent observed elections pooled across regions, and Victoria 2022 is
   the *seventh* most recent Greens observation — the estimate is built from
   SA 2026, FED 2025, WA 2025, QLD 2024 and NSW 2023.
2. **"Contamination explains why the linear trend ranks sixth."** Tested and
   false: it ranks 6, 5, 7 across the three variants.
3. **The contamination figures themselves, twice** — first counting rows the
   observed-election filter never uses, then counting the 2026 Victorian rows
   (the election being forecast) as observed.

## Withdrawn earlier, recorded here

The claim that this project's preference handling beats AE Forecasts and
theswingison. The comparison was made on the wrong axis: ours estimates a
scalar share to Labor, theirs is keyed on who has been excluded and who
remains. Measured flows swing by tens of points with that configuration.

# auspol 0.4.4

Corrections only. No code behaviour changes, no forecast number moves.

## Claims withdrawn

Prompted by Pete, 2026-08-18: this project claimed to beat its two reference
implementations while not simulating seats at all.

- **"Our preference flows beat AE Forecasts and theswingison."** Withdrawn from
  `docs/NEXT-STEPS.md`, `docs/reviews/seat-methodology-critique-2026-08-16.md`
  and the package source at the top of `R/flow_model.R`. The comparison was
  made on the wrong axis: what we estimate is a **scalar per party, its share
  to Labor** — a two-party quantity — while theswingison's twelve rules are
  keyed on who has been excluded and who remains, which is how a seat is
  decided. A hand-authored rule modelling the right mechanism beats a
  well-estimated number for the wrong one. What survives is narrower and true:
  ours is the best estimator *of the scalar*, and the scalar is the
  approximation.

- **"Simulating every seat changes the seat count by almost nothing."**
  Withdrawn, along with the "correctness work, not accuracy work" framing that
  followed from it. It rested on an invented 50/50 split of Liberal preferences
  between One Nation and Labor — the transfer deciding every ONP-vs-ALP seat,
  and never measured. Measured from SA 2026 distributions it is **62.7% to One
  Nation**. The seat-count effect is now recorded as **unknown**.

- **"Their poll aggregation is weaker than ours."** Downgraded to its parts.
  We do remove systematic house effects, via a poll-count-weighted soft
  sum-to-zero prior (`R/trend.R:119-124`) — real and shipped. That theirs does
  not remove them rests on a reading of their published method that was never
  independently verified. And **our accuracy has never been compared against
  either reference, on any output.** Every comparison in these docs was a
  mechanism argument promoted to a verdict with no measurement in between.

## Evidence added

The estimated preference flow matrix now lives in
`docs/reviews/onp-allocation-sa-2026-08-17.md` with provenance: 97 exclusion
events from 16 SA 2026 districts, 28 conditional cells with event counts and
vote totals, and the arithmetic behind the 62.7% figure. Those numbers had been
quoted in two files with the derivation recorded in neither.

Measured conditional flows, against the model's fixed values:

| transfer | to Labor | model's fixed value |
|---|---:|---:|
| GRN excluded, ALP vs LNP remain | 74.5% | 83.5 |
| GRN excluded, ALP vs ONP remain | 81.5% | 83.5 |
| ONP excluded, ALP vs LNP remain | 57.0% | 33.7 |
| ONP excluded, ALP/GRN/LNP remain | 19.3% | 33.7 |

The same section records what the matrix cannot settle: most cells are n ≤ 2,
49 transfers in an 88-seat trial run resolved to no observed cell at all, OTH
is still collapsed to one bucket rather than the separate candidates a real
ballot carries, and everything is estimated from a single state and a single
election. Settling the seat count needs distribution-of-preferences data across
many elections — the real blocker on the rebuild.

# auspol 0.4.3

One fix. No forecast number moves — the defect was latent, not active.

## Fixes

- **The published seat total and the diagnostic seat total could diverge.**
  `scripts/fit_seats.R` added a non-classic Labor-held term to the seat count
  and `scripts/build_page.R` did not, so the published page would have
  under-counted Labor by one for every non-classic seat it held. The two
  agreed only because no non-classic seat is Labor-held in 2026 and the
  constant evaluates to zero.

  Fixed by moving the arithmetic into `simulate_seats()` rather than adding
  the missing line to the second caller — duplicating it across sister scripts
  is what allowed the drift. The function now returns **`alp_total`** (the
  publishable figure) and `alp_nonclassic` alongside `seats_won`, which keeps
  its old meaning of classic seats only and is retained for the S1/S4
  calibration and R2/R3 regional-layer diagnostics that genuinely want it.

  The regression test was verified to **fail on the pre-fix code** — 4
  failures, confined to the new test — and asserts the reverse case as well,
  so the correction cannot inflate a seat count where no non-classic seat is
  Labor-held.

  `fit_seats.R` output is unchanged: median 39, 50% 33–45, 90% 23–51,
  P(majority) 26.0%.

- **`?simulate_seats` documented the new field under the wrong argument.** The
  roxygen paragraph saying which of the two totals to publish sat directly
  under `@param region_sd` with no separating tag, so roxygen folded it into
  that argument's description. `R CMD check` cannot detect this — it is not a
  signature or default mismatch — so it would have shipped as documentation
  describing `alp_total` as though it explained regional effects. Caught by the
  pre-PR review gate.

# auspol 0.4.2

Docs only. No code changes, no forecast recomputed — but one published figure
was already wrong and is corrected.

## Corrections

- **Four stale seat figures in `docs/NEXT-STEPS.md`.** It read ALP 35 of 88,
  50% 29–41, 90% 19–49, P(majority) 14.2%. The published values are **39,
  33–45, 23–51 and 26%** (`output/vic-page-data.json`, reproducible from
  `scripts/fit_seats.R`). These were the pre-flow-update numbers: when the
  preference-flow estimator moved published two-party 46.8 → 47.8, the TPP line
  was updated and the seat line was not. The queue therefore described a
  materially more pessimistic forecast than the model produces, with
  P(majority) at roughly half its true value. Caught by the pre-PR review gate
  — after the stale figure had already propagated into two new documents,
  because they cited the hub rather than `output/`.

## Measurements recorded

Five pre-registered tests on whether the seat model should simulate every seat
from primary votes, each committed before its run: two adopted, one negative,
one void, one inconclusive. Full evidence in
`docs/reviews/onp-allocation-sa-2026-08-17.md` and
`docs/reviews/oth-flow-composition-2026-08-17.md`.

- **Adopted:** a One Nation surge is allocated across seats by a *linear* form
  on the prior minor-right vote (leave-one-seat-out MAE 4.171 against uniform
  allocation's 6.306, validated on SA 2026). The *proportional* form
  pre-registered first failed outright at 9.298 — the predictor correlates
  0.735 with the truth and the link function destroyed it.
- **Negative:** prior LNP share predicts nothing at seat level (LOO correlation
  −0.006), despite the One Nation surge genuinely coming out of the Liberal
  vote statewide.
- **Sized:** the `classic` flag (`R/seats.R:55-56`) reads 2022's final-two
  pairs forward. On a first-pass simulation One Nation reaches the final two in
  39–44 of 88 seats and Labor fails to in 23–24. But minor-right voters send
  only 0.348 of their non-Labor preferences to One Nation against a threshold
  near 0.5, so it contends in half the chamber and loses on preferences. The
  rebuild is **correctness work, not accuracy work**.
- **Inconclusive:** whether the single OTH flow suits a bucket One Nation has
  been pulled out of. Both registered estimands proved void and disagreed by
  4.2 points in opposite directions; aggregate distribution tables carry no
  vote provenance, so the quantity is not recoverable from them at all. The
  concern stands, unevaluated.

## Incidental

- Victoria did not redistribute — all 88 district names in `2026vic.txt` match
  the 2022 results — so seat-level first preferences apply directly and the
  previously queued booth-level acquisition is not needed for this work.
- First independent check of two preference flows, from a different state and
  data path: GRN 86.7% against the model's 83.5%, ONP 32.4% against 33.7%.
- Recorded unfixed: `scripts/fit_seats.R:173-175` adds `alp_extra` to the seat
  total while `scripts/build_page.R:242-244` does not. They agree only because
  it currently evaluates to 0.

# auspol 0.4.1

No forecast numbers change. Every fix here closes a gap between what the model
does and what the machinery around it claimed it does.

## Fixes

- **`G7`: the published fit is now checked.** `fit_vic.R`'s `L2`/`L3`
  structural checks run on `fit_vic.R`'s own fit, which uses per-cycle sigmas
  and per-pollster noise factors the published one does not. Since the page
  moved to its own fit, those checks were guarding a model nobody publishes:
  the published fit could have had a band below zero or first preferences
  summing to 80 with every L-check still reporting PASS. `G7` applies the same
  test where the published fit is made, and is verified to fail on both.
- `G7` itself shipped unable to fail, and was fixed: an `| is.na(lo95)` clause
  meant an *unverifiable* band counted as a pass.
- **Two binomial reference sample sizes, deliberately.** `BINOMIAL_REF_N`
  (2500) wherever a check halts a run or the page makes a claim about a named
  firm; `BINOMIAL_SENSITIVE_N` (1500) where a signal is only reported. The
  scorecard previously used the sensitive value for a **published** claim about
  named polling companies, which is the aggressive setting on the one output
  where a false positive costs someone else. No literal survives outside the
  definitions, including in printed messages — one said "n=1500" while
  computing with 2500.
- **Scorecard prose.** *Variability* was described as scatter against sampling
  error; it is a relative peer comparison where 1.00 is the average firm. The
  absolute measure exists but writes to a file the page never reads.
- The page now states which pollster figures the forecast uses: it separates
  lean from the trend, and does **not** weight polls by variability.
- `ARCHITECTURE.md` records the `G`-code registry, since three separate greps
  for those codes came back incomplete and one of those misses is why `B1`
  meant two different things.

# auspol 0.4.0

Every hard-coded number in the model is now inventoried, and the ones that
could be estimated have been.

## Constants

- `docs/CONSTANTS.md` -- the complete inventory: every constant in `R/` and
  `scripts/`, what it does, whether it *can* come from data, and its status.
  A constant missing from that file is a bug in that file.
- **`szc_sd_pts` 0.3 -> 1.5** -- how far the polling industry as a whole may
  sit from the truth. Two independent lines agree: the consensus of final
  polls against the result across 147 party-elections gives sd 1.61, and
  held-out error over a pre-registered grid falls 2.0850 to 2.0588.
- **`sigma_house_pts` stays at 3** -- the outright minimum of a smooth U, so
  the hand-set value was right. Tested rather than assumed.
- `tune_prior()` / `report_tuning()` -- shared machinery for moving a constant
  from asserted to estimated, so each new one costs a grid and a
  pre-registration rather than a copied script.
- Three constants (`k0` twice, `clip`) **cannot** be judged by forecast error,
  because none of them reaches the forecast. Recorded with what they need
  instead.

## Measured negative results

- **The fuller trend model does not forecast better.** Per-cycle volatility
  gained 0.0041 held-out MAE against a 0.02 bar, for 33x the runtime, with
  alternating signs by horizon. The published forecast loses nothing by using
  the simpler model.

## Performance

- The backtest computed the full posterior variance ~200 times and read only
  the means. `fit_trend(want_var = )` makes that optional: **40% faster on the
  hot path, identical to machine precision**; the pipeline drops 122 s to 96 s.

## Fixes

- The page drew its chart from one model fit and its headline from another --
  first preferences up to 0.54 points from the fit the headline was built on,
  so a reader adding them up could not reproduce the result. One fit now feeds
  the chart, the first preferences and the headline.
- `overrides` passed through the new `...` plumbing raised an argument-matching
  error that `tryCatch` swallowed into a `NULL`, which the backtest recorded as
  "too few polls" -- a bug removing election-horizon pairs with a reassuring
  reason attached.
- `house_effects$sd` was silently dropped rather than set to `NA` when the
  variance solve was skipped; `data.table` removes a column assigned `NULL`.
- `scale_breaches()` returned `NA` on a band-less fit, so its caller's length
  check did not short-circuit and the validity guard was silently disabled.
- `tune_prior()` accepted a parameter name belonging to a different function,
  which would have tuned the wrong quantity and reported a confident verdict
  about an unintended experiment.

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
