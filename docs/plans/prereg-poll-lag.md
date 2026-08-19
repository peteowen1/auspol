# Pre-registration: does the trend systematically sit below recent polls, and does that help or hurt?

Written 2026-08-19 (late), **before anything is measured**. Committed before running.

## Why this is being asked

The Victorian One Nation fit is **20.66** against a **23.05** mean of the 11
polls in the last 90 days, with a 95% upper bound of **22.77 -- below the poll
mean entirely**. This has been called "the One Nation lag" in this repo's queue
for two days and treated as a defect to fix before publishing.

Two prior attempts to fix it failed their own pre-registrations (the day-0
anchor strength, `ANCHOR_K`; and the One Nation seat sd). Both assumed the lag
is real and harmful. **Neither tested that assumption**, and the little evidence
there is points the other way: across the three completed cycles where One
Nation was fitted, the model **over**-stated it twice and understated once
(NSW 2019 +2.75, WA 2017 +2.84, QLD 2004 -1.33).

So the question is not "how do we raise One Nation". It is: **when the trend
sits below recent polls, is it wrong?**

## What is measured

Over the 139 party-cycles with complete actuals, for each:

- `gap = fitted_endpoint - mean(polls in the last 90 days naming that party)`;
- `err = fitted_endpoint - actual`;
- `poll_err = mean(last-90-day polls) - actual`.

Three questions, in order:

1. **Is a negative gap systematic?** Report the distribution of `gap`, pooled
   and by party class. A trend that lags polls generally is a different problem
   from one that lags only minor parties.
2. **Does the gap predict the error?** Regress `err` on `gap`. If shrinking
   toward the prior helps, cycles with a large negative gap should have `err`
   nearer zero than `poll_err` does.
3. **Would following the polls have been better?** Compare MAE and RMSE of
   `fitted` against `mean(recent polls)` as competing predictors of the actual,
   pooled and restricted to the cases that resemble Victoria 2026.

The Victoria-like subset is defined **now**, before looking: a party whose prior
is **under 3%** and whose last-90-day poll mean is **over 10%**. If that subset
is empty or smaller than 5, say so and report the pooled result only -- an
empty subset is the finding, not a licence to widen the definition until it
fills.

## Decision rule, fixed now

Criteria are stated in **standard errors, clustered on the cycle**, because
this project has twice written a threshold in fixed units that turned out to be
smaller than the sampling noise, most recently today.

- **If `fitted` beats `mean(recent polls)` on MAE**, or the difference is within
  2 clustered SE, the trend's conservatism is doing no harm. **Declare the lag
  a non-defect, close it, and change nothing.**
- **If `mean(recent polls)` beats `fitted` by more than 2 clustered SE**, the
  shrinkage is harmful, and only then is a change to the walk volatility or the
  anchor worth testing -- as its own pre-registered experiment, not here.
- **If the two disagree between the pooled set and the Victoria-like subset**,
  report both and adopt neither. With a subset this small, a reversal is not
  evidence of a special case.

## Refusal section -- what would make an apparent result unacceptable

- **P1 -- a win for "follow the polls" must survive the horizon.** The endpoint
  is where polls are densest and most recent, which flatters them. If polls beat
  the trend at the endpoint, that says nothing about a forecast 101 days out,
  which is what Victoria 2026 is. Do not read an endpoint win as a licence to
  weight polls more at long range.
- **P2 -- no per-party fix.** If One Nation specifically looks lagged, that must
  not become a One Nation adjustment. This repo has already refused one such
  change, and a party-specific constant fitted on three cycles is noise. Any
  change must be to the general mechanism.
- **P3 -- direction of the historical error disqualifies a one-way fix.** The
  three completed One Nation cycles average **+1.42 over-statement**. If this
  analysis motivates a change that would raise One Nation further, it is
  arguing against the only direct evidence available, and must be refused
  regardless of what the pooled numbers say.
- **P4 -- the poll mean is not a forecast.** `mean(last 90 days)` ignores house
  effects, which the trend corrects for. If it wins, check whether it wins
  because of house-effect correction being harmful rather than shrinkage being
  harmful, and say which.

## What the criteria cannot see

- **Whether One Nation's 23% Victorian polling is real.** Every number here
  treats the polls as the best available measurement. If Victorian pollsters are
  collectively over-stating a new entrant -- which has happened to One Nation
  before, in 1998 -- no amount of tracking them better helps.
- **Only 3 One Nation cycles have complete actuals.** Anything party-specific
  here is anecdote.
- **The 2026 cycle has no polls naming One Nation before January 2026**, so the
  walk runs unobserved for three years from a 0.28% prior. No completed cycle in
  this data has that shape, so the pooled result may not describe it.
