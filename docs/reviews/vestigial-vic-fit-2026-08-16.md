# fit_vic.R computes a live forecast that nothing publishes

2026-08-16. Found because a code reviewer, with the whole repository in front
of it, concluded that the published forecast down-weights noisy pollsters. It
does not — but the reasoning that led there is sound, and that is the finding.

## The reviewer's claim, and why it was wrong

> `fit_vic.R:120` computes `fac_vec` from `estimate_firm_factors()` and passes
> it into `fit_cycle()` for `ALL_CYCLES`, which includes the live 2026 cycle
> that produces the published forecast.

Every part of that is true except the last clause. `fit_vic.R` does fit the
live cycle with per-pollster noise factors. **Its output no longer reaches the
page.** Verified:

- `build_page.R` takes the headline, the chart and the first preferences from
  `trend_as_at()`, which never passes `firm_factors`; `R/projection.R` contains
  no reference to them at all, so `fit_trend()` uses its `NULL` default.
- `output/trend-vic-2026.csv` — what `fit_vic.R` writes — is **required but
  not read**. It is an ordering guard, proving `fit_vic.R` ran and its V1–V5
  checks passed.
- The scorecard runs its own fits in `fit_scorecard.R`.

So the published number weights every poll equally, and the page's claim is
correct.

## Why the wrong finding matters more than a right one would have

A reviewer with full repository access, specifically asked to check this
sentence against the code, read `fit_vic.R` fitting the live cycle and drew
the obvious conclusion. **A reader of the page has far less to go on.** If the
code misleads someone reading the code, the prose has to work harder, which is
why the paragraph now says "not used *to weight the forecast*" and names the
projection as the thing that gives every poll equal weight.

## The real defect underneath

**`fit_vic.R` fits the live 2026 cycle with the fuller model, and nothing
consumes the result.** That fit exists to produce a CSV read by no one.

This is the two-model tension from earlier today, resurfacing in a different
place. It was resolved for the page — one fit now feeds the chart, the first
preferences and the headline — but `fit_vic.R` was left computing the other
one, and its live-cycle output became vestigial without anyone noticing,
including me, because nothing failed.

It is not costing accuracy: the comparison in
[backtest-model-comparison-2026-08-16.md](backtest-model-comparison-2026-08-16.md)
showed the fuller model is worth 0.2% for 33× the runtime. It costs clarity,
and clarity is what just misled a reviewer.

## Options, not yet decided

1. **Stop fitting the live cycle in `fit_vic.R`.** It exists there for the
   V1–V5 validation checks, which are about *past* Victorian elections — 2018
   and 2022. The live cycle is fitted alongside them out of symmetry, not
   because anything needs it. Cheapest, and removes the confusion at source.
2. **Keep it and say why**, in a comment at the fit site: this is the
   validation model, deliberately fuller than the published one, and its
   output is not published.
3. **Publish from it instead** — rejected already on measurement.

Recommendation: **(1)**, with (2) as the fallback if the live fit turns out to
feed a check I have not traced. Either way the reviewer's confusion should not
be reachable by the next reader.
