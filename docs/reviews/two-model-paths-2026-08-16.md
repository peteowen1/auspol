# The page shows one model's chart above another model's headline

2026-08-16. Found while checking whether a prior tuner actually reaches the
constant it claims to tune. Not yet fixed — the options are set out at the end.

## What is happening

There are two ways a Victorian trend gets fitted in this repo, and the
published page uses both at once.

**`fit_vic.R`** fits the full model: per-cycle sigmas from
`estimate_cycle_sigmas()`, per-pollster noise from `estimate_firm_factors()`.
It writes `output/trend-vic-2026.csv`, which becomes **the chart and the
published first-preference figures**.

**`trend_as_at()`** fits a simpler model. `R/projection.R` references no
`sigma_obs`, `sigma_rw`, `estimate_cycle_sigmas` or `firm_factors` anywhere, so
`fit_trend()` falls back to `default_sigmas()` — 0.0747 and 0.0044 on the logit
scale — and `firm_factors = NULL` makes every pollster equally noisy. This is
**the headline two-party figure**, via `build_page.R`'s
`now <- trend_as_at(...)`.

## Measured gap, same day, same polls

| Party | headline path | chart path | diff |
|---|---:|---:|---:|
| ALP | 24.87 | 25.16 | −0.29 |
| LNP | 28.38 | 28.67 | −0.29 |
| GRN | 13.12 | 13.05 | +0.07 |
| ONP | 20.00 | 20.37 | −0.37 |
| OTH | 11.12 | 10.58 | **+0.54** |
| two-party | 49.24 | 49.16 | +0.08 |

The two-party figures nearly agree. The first preferences do not: up to 0.54
points on Others and 0.37 on One Nation. **A reader adding up the first
preferences on the page cannot reproduce the headline**, because they were
produced by different fits.

## What is and is not broken

**The headline is internally consistent.** `build_projection_data()` also goes
through `trend_as_at()`, so the mix weight, the error spread and the B2/B3
coverage validation all describe the same simpler model that produces the
published number. The calibration claim is honest for the number it is
attached to.

**The chart is the odd one out.** It shows the fuller model — the one this
project spent real effort building — beside a headline from the simpler one.

**And the effort is inverted.** Estimated per-cycle volatility and per-pollster
noise factors are two of this model's better features, and the published
forecast does not use them. They inform the chart, the V1–V5 validation checks
and the pollster scorecard, but not the number on the front.

## What this means for the tuning work

`szc_sd_pts` was tuned on the backtest path, which is the headline path, so
that result stands for the number it affects. But it was tuned on a model
without estimated sigmas or firm factors, and the optimum need not be the same
once those are present. The same caveat would apply to `sigma_house_pts`,
which is why that grid was stopped before running.

## Options

1. **Make `trend_as_at()` use the full model** — estimated per-cycle sigmas and
   firm factors. Most correct, and it makes the published forecast use the
   features the project built. Costs: much slower (sigma estimation per cycle
   per horizon, ~200 refits), and every downstream number moves, so the mix
   weight, error spread, calibration and both tuned priors need re-deriving.
2. **Make the page consistent the cheap way** — publish first preferences from
   the same fit as the headline, so the page stops contradicting itself. Does
   not address the inverted effort.
3. **Document and accept** — the backtest must hold the model fixed across
   cycles to estimate the mix honestly, and defaults are a defensible way to do
   that. Then say so on the page, and stop showing the other fit's numbers
   beside it.

Recommendation: **(2) now, (1) properly**. The page contradicting itself is a
correctness bug and cheap to fix; making the published forecast use the full
model is the real work and deserves its own pre-registration, since it moves
every published number and invalidates two tuned constants.
