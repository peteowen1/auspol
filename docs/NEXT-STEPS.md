# auspol — work queue

Updated 2026-08-14 (session 2, after a laptop restart mid-session).

## Awaiting Pete

- **Answer the four improvement-quiz questions** (from session chat; context in
  [ANCHOR-MODEL.md](ANCHOR-MODEL.md) "Honest assessment"): demographics in the
  seat model, seat-level preference flows, the 2019 herding problem, and the
  trend-vs-simulator scope call. #4 was pre-empted: trend built first — confirm
  or redirect.
- **Poll data licensing**: the anchor repo (d-j-hirst/aus-polling-analyser) has
  no LICENSE. We read his hand-maintained poll CSVs from a gitignored clone and
  never commit them. Recommend emailing the author (site invites use of the
  files, but formal permission is worth having for a public-facing site).
- **Create GitHub remote** for this repo (queued; outward-facing, not done
  autonomously).

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
4. **Fundamentals stage** — elastic-net regression on his authored inputs
   (prior-results, incumbency, federal-situation CSVs), leave-one-out
   validated.
5. **Stan version of the trend** (rstan is installed) — fat tails,
   campaign-varying walk, new/old house effects; validate against the
   Gaussian-exact version.

Later: projection (trend×fundamentals mix), seat simulation, ABS Census
electorate demographics (CED/SED + SA1 correspondences), website.

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

Still needed before this is a forecast rather than a trend: fundamentals +
projection (so it says something about November rather than today), and a
seat model.

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

## Done

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
