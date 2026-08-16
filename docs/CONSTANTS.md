# Every hard-coded number in the model

The standing rule for this project: **an assumption should be estimated from
data so it moves when the evidence moves.** A number frozen in a file cannot
respond to a new election, and nothing fails when it goes stale — which is how
`2026,vic,ONP FP,25.5` came to sit in the published forecast for months. See
`docs/reviews/onp-preference-flows-2026-08-15.md` for how that one ended.

This file is the complete inventory. Every constant in `R/` and `scripts/` is
listed, with what it does, whether it *can* be derived from data, and its
status. **A constant that is not in this file is a bug in this file.**

Status key: **ESTIMATED** — derived from data, moves as data arrives ·
**ESTIMABLE** — could be, currently is not · **FIXED** — cannot or should not
be estimated, with the reason given.

Last audited 2026-08-16.

---

## 1. Model priors — the ones that matter

These enter the posterior directly. Getting one wrong changes the published
number without anything failing.

| Constant | Where | What it is | Status |
|---|---|---|---|
| `sigma_obs` | `trend.R` | Poll observation noise | **ESTIMATED** — `estimate_trend_sigmas()`, exact log marginal likelihood |
| `sigma_rw` | `trend.R` | Daily random-walk step | **ESTIMATED** — same |
| per-cycle sigmas | `hyperpars.R` | Volatility for one cycle | **ESTIMATED** — `estimate_cycle_sigmas()`, shrunk to pooled |
| firm noise factors | `hyperpars.R` | Per-pollster noise | **ESTIMATED** — `estimate_firm_factors()` |
| preference flows | `flow_model.R` | Where minor-party preferences go | **ESTIMATED** — mean of last 5 observed, method chosen by backtest (check `G3`) |
| scale (logit/points) | `trend.R` | Which scale each party is fitted on | **ESTIMATED** — per party by comparable log evidence |
| trend/fundamentals mix | `projection.R` | Weight by horizon | **ESTIMATED** — leave-one-election-out |
| ridge penalty | `fundamentals.R` | Fundamentals shrinkage | **ESTIMATED** — leave-one-election-out |
| **`szc_sd_pts = 0.3`** | `trend.R` | Strength of the soft sum-to-zero constraint on house effects — i.e. how far the polling industry as a *whole* may sit from the truth | **MEASURED 2026-08-16: should be ~1.5, not 0.3.** Now exposed on `fit_trend()`; change not yet made. See §6. |
| **`sigma_house_pts = 3`** | `trend.R:325`, `hyperpars.R:35,131` | Prior sd on a single pollster's house effect | **ESTIMABLE, NOT DONE.** The fitted house effects across 17+ party-cycles are exactly the data that should set this. |
| **`k0 = 25`** | `hyperpars.R:132` | Shrinkage of per-cycle sigmas toward pooled | **ESTIMABLE, NOT DONE.** An empirical-Bayes quantity, currently guessed. |
| **`k0 = 12`** | `hyperpars.R:308` | Shrinkage of firm noise factors | **ESTIMABLE, NOT DONE.** Same. |
| **`clip = c(0.6, 2.0)`** | `hyperpars.R:308` | Bounds on a firm's noise multiplier | **ESTIMABLE, NOT DONE.** Arbitrary; the observed spread of firm factors could set it. |

## 2. Reference sample sizes

| Constant | Where | What it is | Status |
|---|---|---|---|
| `n = 2500` | `fit_federal.R`, `fit_nsw.R` | Sample size for the binomial noise floor (check `H1`/`L4b`) | **FIXED — cannot be estimated.** The anchor's poll CSVs carry no sample-size column, so there is nothing to derive it from. 2500 is deliberately the *largest* common sample, giving the smallest binomial sd and therefore the weakest floor: it under-calls herding rather than over-calls it. |
| `n_ref = 1500` | `scorecard.R:173` | Reference sample for the pollster herding comparison | **FIXED, same reason** — but note it disagrees with the 2500 above. Both are defensible in isolation; using two different reference sizes for the same physical quantity is not. **Open: reconcile.** |

## 3. Data-quality thresholds

Operational guards on input parsing, not model inputs. They decide whether to
trust a file, not what the forecast says.

| Constant | Where | What it guards |
|---|---|---|
| `sum_range = c(97, 103)` | `fold.R:40` | First preferences summing near 100 → a party was folded into OTH |
| `95`–`105` | `load_polls.R:51` | Sanity bound on reported FP sums |
| `> 0.02` | `load_polls.R:56` | Share of malformed rows tolerated before erroring |
| `n > 100`, `< 60`, `< 380` | `load_polls.R:45,78`, `fundamentals.R:56` | Row-count floors that catch `fread` stopping early on a ragged row — the bug that once trained the fundamentals on 62% of the data |
| `min_year = 1990` | several | Start of the modern polling record |
| `min_polls`, `min_firm_polls` | several | Minimum data before fitting |
| `warn_days = 21`, `stale_days = 60` | `freshness.R:60` | When our copy of the poll data is old enough to warn, then stop |
| `SHARE_CLAMP = c(0.25, 99.75)` | `scales.R:19` | Keeps logit finite at the boundary |

These are **FIXED by intent.** They encode "does this input look like what we
expect", and a threshold estimated from the same data it is meant to police
would move to accommodate corruption — the guard-that-passes-wrongly failure
this codebase has hit five times.

## 4. Computation and presentation

**FIXED**, no modelling content: `n_sims` (20000/50000 simulation draws),
`w_grid`/`lambdas` (search grids, resolution not assumption), optimiser bounds
and starts in `optim_boxed`, `window = 30` (days counted as "final poll"),
`horizons = c(30, 90, 180, 365, 730)`, plot colours and alphas, the 180-day
leader-caveat window, and `G3`'s 0.15 MAE tolerance.

Two of these are closer to judgement than the rest and are worth revisiting if
they ever look load-bearing: `window = 30` decides which poll counts as a
firm's last, and the `G3` tolerance decides how far the adopted estimator may
fall behind before someone is told.

## 5. Pre-registered check bounds

Every `require ...` in `scripts/fit_*.R` — `V2` requires the 2018 endpoint in
33–46, `A1` requires 51–56, and so on. These are **FIXED and must stay so.**
They are assertions written *before* results were seen; estimating them from
the results they police would make them unfalsifiable, which is the entire
point of pre-registering them. They are listed in `ARCHITECTURE.md`, not here.

## 6. Measured: the sum-to-zero prior is 4-5x too tight

`szc_sd_pts` says how far the polling industry as a whole may sit from the
truth. It is measurable, and it was measured on 2026-08-16.

Take the consensus of the final polls at each completed election since 1990
and compare it to the result. Excluding `OTH`, whose −5.3 average miss is the
known fold-into-Others parsing artefact this codebase already corrects and not
pollster bias:

| Window | n party-elections | sd of the miss | majors only |
|---|---:|---:|---:|
| final 14 days | 147 | **1.61** | 1.71 |
| final 30 days | 187 | 1.94 | 2.03 |
| final 60 days | 209 | 2.14 | 2.34 |

The spread shrinks as the window narrows, so the wider figures partly measure
opinion genuinely moving rather than pollsters being wrong. The 14-day figure
is the cleanest available bound, and even it contains two weeks of movement.
**Industry-wide bias is therefore about 1.5 points, against a prior of 0.3.**

The mean miss is +0.09 — near zero, which is the point. The field is not
biased in a consistent direction; it misses *together*, by roughly a point and
a half, in a direction that varies by election.

**Why it matters.** Forcing house effects to cancel more tightly than reality
supports pushes genuine industry-wide error into the latent trend, where it is
treated as truth. The page's own leading caveat says "the polls could be wrong
together... nothing here detects a field-wide miss" — and the model is
structurally assuming it away rather than merely failing to detect it.

**What it would move**, from the sensitivity sweep (`fit_cycle_trends`,
Victoria 2026, other settings held):

| `szc_sd_pts` | ALP two-party | ONP first preference | max house effect |
|---:|---:|---:|---:|
| 0.3 (current) | 49.04 | 21.97 | 3.24 |
| 1.0 | 49.16 | 20.74 | 4.13 |
| 2.0 | 49.29 | 19.52 | 5.31 |

The **two-party figure barely moves** — 0.14 points across 0.1–1.0, about
0.15% of the held-out error, which by the usual sizing rule is nothing. The
**first preferences move materially**: One Nation shifts more than a point,
and the page prints that number prominently.

So this is not a headline-accuracy fix. It is a correctness fix for the
first-preference levels and for the honesty of the house-effect estimates,
and it should be made for that reason rather than sold as an accuracy gain.

**Not yet changed.** It alters published first preferences, so it wants its
own pre-registered checks: that the two-party figure stays within ~0.3 of
today's, that house effects widen rather than explode, and that the L4b
herding floor still holds.

## 7. What to do next

In priority order, by how much each touches the published number:

1. ~~**`szc_sd_pts`** — expose, then size~~ — **done 2026-08-16.** Exposed on
   `fit_trend()`, sized, and measured at ~1.5 against a prior of 0.3 (§6).
   Remaining: make the change, with the checks named there.
2. **`sigma_house_pts`** — the fitted house effects are the data for it.
3. **`n_ref` vs `n = 2500`** — reconcile to one reference sample size.
4. **`k0` (both) and `clip`** — empirical-Bayes quantities that are guessed.

Sizing comes before building in each case: if varying the constant across a
plausible range barely moves the forecast, it is a correctness matter and gets
recorded here rather than modelled.
