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

Last audited 2026-08-18.

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
| `szc_sd_pts` | `trend.R` | Strength of the soft sum-to-zero constraint on house effects — how far the polling industry as a *whole* may sit from the truth | **ESTIMATED 2026-08-16 — now 1.5.** Chosen by held-out error over a pre-registered grid (`scripts/tune_szc.R`, check `G4`). See §6. |
| `sigma_house_pts = 3` | `trend.R`, `hyperpars.R` | Prior sd on a single pollster's house effect | **TESTED 2026-08-16, KEPT.** Held-out error over a pre-registered grid is a smooth U with its minimum at exactly 3 (`scripts/tune_sigma_house.R`, check `G5`). See §6b. |
| `k0 = 25` | `hyperpars.R` | Shrinkage of per-cycle sigmas toward pooled | **CANNOT BE TUNED ON FORECAST ERROR — it does not reach the forecast.** See §6c. |
| `k0 = 12` | `hyperpars.R` | Shrinkage of firm noise factors | **Affects the published scorecard, not the forecast.** See §6c. |
| `clip = c(0.6, 2.0)` | `hyperpars.R` | Bounds on a firm's noise multiplier | **Affects the published scorecard, not the forecast.** See §6c. |

## 2. Reference sample sizes

| Constant | Where | What it is | Status |
|---|---|---|---|
| `BINOMIAL_REF_N = 2500` | `scales.R` | Sample size for the binomial noise floor, wherever it **halts a run or makes a published claim about a named firm** (`H1`, `L4b`, the scorecard's *Variability*) | **FIXED — cannot be estimated**, no sample-size column exists. Deliberately the *largest* common sample: smallest binomial sd, weakest floor, so it under-calls herding rather than over-calling it. |
| `BINOMIAL_SENSITIVE_N = 1500` | `scales.R` | The same floor where it only **reports** a signal (`ratio_sens` in the fit scripts) | **FIXED, deliberately different.** Smaller sample means a higher floor and a more sensitive test — right for "look here", wrong for "stop the run". Resolved 2026-08-16: this was previously mistaken for drift, and the real defect was the scorecard using the sensitive value for a published claim about named companies. |

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

## 4b. The candidate-level seat path (added 2026-08-18)

These live in `scripts/fit_seats_full.R` and the three functions it calls. The
path does not feed the published page, but the rule applies the same: a
constant absent from this file is a bug in this file.

| constant | value | where | status |
|---|---:|---|---|
| `SMOOTH` | 0.15 | `distribute_preferences()` | **FIXED, and load-bearing** |
| `min_n` | 3 | `build_flow_matrix()` | **FIXED** — judgement |
| `SEAT_SD` | 3.5 | `fit_seats_full.R` | **ESTIMATED** |
| `ONP_B1` | −0.0968 | `fit_seats_full.R` | **ESTIMATED** |
| One Nation spread | SA 2026 observed | `fit_seats_full.R` | **ESTIMATED, transferred** |
| per-party statewide sd | from the trend | `fit_seats_full.R` | **ESTIMATED** |
| `N_SIMS` | 20000 | `fit_seats_full.R` | FIXED, no modelling content |
| S5 median-gap bound | 5 seats | `fit_seats_full.R` | **FIXED** — pre-registered |
| S5 width-ratio bounds | 0.7 – 1.4 | `fit_seats_full.R` | **FIXED** — pre-registered |
| `PREV_TPP` (Victoria 2022) | 55.00 | `fit_seats_full.R`, `fit_seats.R` | **FIXED** — a recorded result |
| 2018/2014 Victorian TPP | 57.60 / 51.99 | `fit_seats_full.R`, `fit_seats.R` | **FIXED** — recorded results |

**S5's two bounds are pre-registered check bounds** and belong to the family in
§5: assertions written before the result was seen, so estimating them from the
results they police would make them unfailable. They were chosen against a
known-bad case — the pre-anchoring run had a width ratio of 0.57 and must fail,
the corrected one 0.96 and must pass — and verified to do both.

**The three Victorian two-party figures are recorded election results**, not
assumptions: 55.00 in 2022, 57.60 in 2018, 51.99 in 2014. They cannot be
estimated because they already happened. They appear in two scripts, which is
duplication worth removing if a third ever wants them.

**`SMOOTH` is not presentation.** A flow row carries 0% for a destination that
never co-occurred in the source data; renormalising that row over the survivors
hands them the entire transfer. At `SMOOTH = 0` One Nation wins Richmond. It
mixes every row with a uniform over the survivors so absence of evidence is not
read as certainty. It is **FIXED rather than estimated because there is nothing
to estimate it against** — the quantity it guards is precisely the one never
observed. Its own test asserts that a wide enough value flips the winner, so it
cannot silently become inert.

**`min_n = 3`** decides when a survivor-conditional rate is trusted over the
pooled one. Judgement, not measurement: below it a rate can rest on a single
seat. Cells below the bar are still reported in `coverage`, so what was
withheld is visible.

**`SEAT_SD = 3.5`** is the within-region seat deviation from
`seat_swing_spread()`, the same figure the two-party seat model uses.

**`ONP_B1 = −0.0968`** orders seats by Greens share, fitted on the 38 Victorian
federal 2025 divisions by leave-one-division-out over five pre-named forms.
Checked on 2026-08-18: the coefficient is negative in NSW, Queensland and WA
too, so the relationship replicates. **It beats a uniform allocation by only
0.122 MAE** — real and small. Trust the One Nation *total*, not any one seat.

**The One Nation spread** is taken from SA 2026's observed relative
distribution, measured at 22.97% statewide against Victoria's forecast 20.9%.
Estimated, but from a different state, because Victoria has never had a large
One Nation vote to measure its own. Checked within 1.41× against a 1.5 bar.
See `docs/plans/prereg-onp-allocation-vic.md`.

## 5. Pre-registered check bounds

Every `require ...` in `scripts/fit_*.R` — `V2` requires the 2018 endpoint in
33–46, `A1` requires 51–56, and so on. These are **FIXED and must stay so.**
They are assertions written *before* results were seen; estimating them from
the results they police would make them unfalsifiable, which is the entire
point of pre-registering them. They are listed in `ARCHITECTURE.md`, not here.

## 6. Estimated: the sum-to-zero prior, 0.3 -> 1.5

Resolved 2026-08-16 after one false start. Two independent lines of evidence,
and they agree.

### Line 1: what the record says the industry actually does

Consensus of the final polls at every completed election since 1990, against
the result. `OTH` excluded -- its −5.3 average miss is the known
fold-into-Others parsing artefact, not pollster bias.

| Window | n party-elections | sd of miss |
|---|---:|---:|
| final 14 days | 147 | **1.61** |
| final 30 days | 187 | 1.94 |
| final 60 days | 209 | 2.14 |

The spread shrinks as the window narrows, so wider figures partly measure
opinion moving rather than pollsters erring. **About 1.5.** Mean miss +0.09:
the field is not biased in a direction, it misses *together*, in a direction
that varies by election.

### Line 2: held-out error, over a pre-registered grid

`scripts/tune_szc.R`, criterion and grid and decision rule all fixed in
[plans/prereg-szc-v2.md](plans/prereg-szc-v2.md) and committed before running.
Leave-one-election-out, 195 election-horizon pairs:

| `szc_sd_pts` | held-out MAE |
|---:|---:|
| 0.30 (incumbent) | 2.0850 |
| 0.75 | 2.0852 |
| **1.50** | **2.0588** |
| 3.00 | 2.0593 |

**Adopted 1.5**: beats the incumbent by 0.0262, clearing the pre-registered
0.02 materiality bar; both 1.5 and 3.0 qualified and rule 5 takes the smaller.

Two things about the shape matter more than the winner. It is a **step, not a
slope** -- 0.3 and 0.75 are identical to four figures, and so are 1.5 and 3.0
-- so the gain comes from loosening the prior *at all*, not from landing on a
finely-tuned value. And the two lines of evidence were computed from entirely
different quantities and still agree on ~1.5.

**Honest caveat: the gain clears the bar by 0.006.** Had the threshold been
0.03 this would have failed. The rule is satisfied because it was fixed in
advance, but 1.3% on 195 pairs is not decisive.

### Why it matters beyond the number

Forcing house effects to cancel more tightly than reality supports pushes
genuine industry-wide error into the latent trend, where it is treated as
truth. The page's own leading caveat says the polls could be wrong together
and nothing here detects it -- at 0.3 the model was *assuming it away*, not
merely failing to notice.

### The false start, kept because the lesson is the expensive part

A first attempt picked 1.5 by judgement and tested it against four checks
written beforehand. Three passed; the fourth (SZ2: "house effects must grow")
failed, and the change was reverted as committed. SZ2 was watching the wrong
quantity -- `szc` constrains the weighted *mean* of house effects, which does
respond correctly (0.13 → 3.17 across the grid), not their individual size.

Held-out error had improved in that run too, but it was **not** a
pre-registered criterion, and adopting the change on it afterwards is exactly
what pre-registration exists to prevent. Hence v2: stop picking the value,
estimate it, and fix the criterion first. Full record in
[reviews/szc-prior-2026-08-16.md](reviews/szc-prior-2026-08-16.md).

Also recorded there: the sensitivity sweep used to justify v1 **predicted the
wrong sign** on the check it was most worried about, because it ran
`fit_cycle_trends` bare while the pipeline has firm factors, the fold
correction and estimated per-cycle sigmas. A stripped-down harness is not the
model.

### When to re-run

`scripts/tune_szc.R` takes about four minutes, too slow for every pipeline
run. Re-run it when the election record grows -- a new completed election is
new evidence about how far the industry misses -- and commit the result.

## 6b. Tested and kept: the house-effect prior

`sigma_house_pts` is the prior sd on ONE pollster's house effect, where
`szc_sd_pts` governs how far they may all sit from the truth together. Grid,
criterion and rule fixed in
[plans/prereg-sigma-house.md](plans/prereg-sigma-house.md) before running.

| `sigma_house_pts` | held-out MAE |
|---:|---:|
| 1 | 2.0689 |
| 2 | 2.0599 |
| **3 (incumbent)** | **2.0588** |
| 5 | 2.0725 |
| 8 | 2.0763 |

**Kept at 3**, which is the minimum of the grid outright rather than surviving
on the tie-break.

The shape matters as much as the winner. This is a **smooth U with an interior
minimum**, unlike the two constants tested before it: `szc_sd_pts` was a step
function where everything below 1 behaved identically and everything above did
too, and the default-versus-per-cycle model comparison was pure noise with
alternating signs. Here both directions are genuinely worse — too tight (1)
costs 0.010, too loose (8) costs 0.018 — so 3 is a real optimum and the
hand-set value was well chosen.

That is worth recording as a positive result. Three constants have now been
put through the same procedure and they came back differently: one was wrong
and moved, one is right and stays, one turned out not to matter. Auditing a
constant is not the same as changing it.

## 6c. Three constants that cannot be tuned the way the others were

Checked 2026-08-16 before running their grids, and the check is the result.

Held-out forecast error is the criterion used for `szc_sd_pts`,
`sigma_house_pts`, the mix weight, the ridge penalty and the flow estimator.
**It is the wrong criterion for these three, because none of them reaches the
forecast.**

Tracing what the published page actually depends on:

- The headline and the chart both come from `trend_as_at()`, which calls
  `fit_trend()` with `firm_factors = NULL` and default volatility.
- `output/projection-mix.csv` comes from `build_projection_data()`, same path.
- `output/trend-vic-2026.csv` is required but **no longer read**.

So:

| Constant | Reaches the forecast? | What it does reach |
|---|---|---|
| `k0 = 25` (cycle-sigma shrinkage) | **No** | The V/A/N validation checks in the fit scripts |
| `k0 = 12` (firm-factor shrinkage) | **No** | The published pollster scorecard |
| `clip = c(0.6, 2.0)` | **No** | The published pollster scorecard |

Running a held-out-MAE grid on any of them would have produced a flat line and
an authoritative-looking "KEEP", which is worse than not running it: a
meaningless number wearing the same format as three meaningful ones.

**What they would need instead.** For the firm factors, the honest question is
whether an estimated factor predicts a pollster's *future* accuracy out of
sample — a different and harder test than forecast MAE, and one the scorecard
half-implements already (`pollster_lean_predicts_error`). For `k0 = 25`, the
question is whether per-cycle shrinkage improves the validation fits, which
matters for confidence in the model rather than for the number it produces.

**Worth a decision separately:** the page publishes per-pollster noise factors
that play no part in the forecast. That is not wrong, but a reader could
reasonably assume otherwise, and the scorecard does not say so.

## 7. What to do next

In priority order, by how much each touches the published number:

1. ~~**`szc_sd_pts`**~~ — **done 2026-08-16**, now estimated at 1.5 (§6).
2. ~~**`sigma_house_pts`**~~ — **tested 2026-08-16, kept at 3** (§6b). It is
   the outright minimum of a smooth U, so the hand-set value was right.
3. ~~**`k0` and `clip`**~~ — **checked 2026-08-16**: none of them reaches the
   forecast, so held-out error cannot judge them (§6c). What they need instead
   is written there.
4. ~~**`n_ref` vs `n = 2500`**~~ — **resolved 2026-08-16**, and not as
   described: the fit scripts deliberately use both, one to halt and one to
   report. Now two named constants with their jobs written down. The real
   defect was the scorecard using the sensitive value for a published claim
   about named companies; it now uses the conservative one.

The one lesson worth carrying: **check what a constant reaches before
measuring how much it matters.** Item 3 was queued as three tuning grids and
resolved by ten minutes of tracing, because none of the three touches the
forecast at all. Running them would have produced flat lines wearing the same
format as three meaningful results.

Sizing comes before building in each case: if varying the constant across a
plausible range barely moves the forecast, it is a correctness matter and gets
recorded here rather than modelled.
