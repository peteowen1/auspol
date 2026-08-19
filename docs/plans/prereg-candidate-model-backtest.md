# Pre-registration: backtest the candidate-level seat model, and port the two-party model's one adopted improvement into it

Written 2026-08-20, **before anything is measured**. Committed before running.

## Why now

The candidate-level model publishes every seat number on the page as of
2026-08-19, and **it has never been scored against a result.** The calibration
this repo does have — slope 1.113, Brier 0.0583 over 161 seats — scores the
**two-party** model, which is now a cross-check only.

Two things forced the issue:

- The seat-swing adjustment (`seat_swing_adjustment()`, four seat-file fields
  worth 0.0371 MAE) was adopted into `simulate_seats()` — **the two-party
  path only**. A reviewer noted it never reaches the published numbers.
- Against YouGov's MRP we assign probability **0.000** to three seats they call
  at 50.3, 50.7 and 51.5. That may be right, but nothing has ever tested whether
  this model's probabilities mean what they say.

The instruction driving this is Pete's: port what the two-party model learned
into the candidate model, **measure whether error improves**, and once the
learning is transferred stop improving the two-party model at all.

## What can actually be built, and the leak in it

Only **Victoria 2022** supports a candidate-level backtest. NSW has no
candidate or transfer data in the repo, and Victoria 2018 is documented as
unavailable at every URL pattern tried
([preference-data-acquisition.md](preference-data-acquisition.md)).

So the design is:

- **Inputs, all knowable before November 2022**: `load_seats(2022, "vic")` —
  margins from 2018, incumbency, region, and the four swing predictors.
- **Conditional arm only**: hand the model the ACTUAL 2022 statewide primary
  vote. This isolates the seat layer, which is the layer being changed.
- **Truth**: the actual 2022 winner of each seat.

**The transfer matrix is a leak and this plan says so up front.** `fm` would be
built from 2022 transfers — the very election being predicted — because 2018
transfers do not exist in the repo. That inflates absolute accuracy.

The one defence, and the only claim allowed on it: **the same `fm` is used in
both arms**, so it cannot explain a *difference* between them. This is
registered as a **relative** comparison of the seat-swing adjustment, and:

> **The absolute accuracy of either arm must never be quoted as evidence that
> the candidate model is good.** Not in a review, not on the page, not in a
> commit message. If that number is interesting enough to want to quote, the
> answer is to fetch 2018 data, not to quote it.

## The two arms

- **A — as published**: the candidate model exactly as it runs today.
- **B — plus the seat swing adjustment**: `seat_swing_adjustment()` applied to
  each seat's projected shares, the same function and the same fitted
  coefficients the two-party model uses.

Nothing else differs. If B needs any other change to run, that change goes into
A as well and is reported.

## What is measured

Per seat, both arms:

- **Brier score** on the probability assigned to the party that actually won.
- **Log score**, which punishes a confident miss much harder — and confident
  misses are the specific worry raised by the YouGov comparison.
- **Winner accuracy**: did the argmax party win.
- **Calibration slope** on the log-odds, and a reliability table.

## Decision rule, fixed now

Criteria in **standard errors of the paired per-seat difference**, per the rule
added to `CLAUDE.md` yesterday after two criteria failed on size.

- **Adopt B** if its Brier score is better by more than **2 SE** of the paired
  per-seat difference, and its log score does not get worse.
- **Keep A** if the difference is within 2 SE. A change that cannot be
  distinguished from noise does not go into the published model just because it
  helped a different model.
- **If B is worse by more than 2 SE**, report that plainly. The adjustment
  helping the two-party model and hurting this one is a real possible outcome:
  the two models put the same predictors through different machinery.

**n is 88 seats but ONE election.** The effective sample is smaller than 88
because every seat shares one statewide environment, so a result at exactly 2 SE
should be treated as marginal, not as a pass.

## Refusal section — what would disqualify an apparent win

- **C1 — a win driven by the leak is not a win.** If B's advantage appears only
  in seats where the transfer matrix does heavy work (non-classic contests,
  seats decided after multiple exclusions), suspect the leak and refuse. Report
  the split classic/non-classic.
- **C2 — no re-fitting the coefficients.** `SEAT_SWING_COEF` is used exactly as
  the two-party model fitted it. Re-estimating it on Victoria 2022 and then
  scoring on Victoria 2022 is the leakage this repo has already introduced
  three times, once while fixing another instance.
- **C3 — winner accuracy alone cannot carry adoption.** With 88 seats, moving
  two seats looks like a 2.3% gain and is one coin-flip either way. Brier and
  log score are the criteria; accuracy is reported, not decided on.
- **C4 — a directional side effect on One Nation disqualifies.** Same bar as the
  first-preference correction: if B raises One Nation's expected seats by more
  than 1.0 in the LIVE 2026 forecast, stop and report rather than shipping it.
  This has now caught one change and cleared another, and it is checked
  regardless of what the backtest says.
- **C5 — verify `fed_swing` is knowable in advance.** The 2022 federal election
  was May 2022 and the Victorian state election November 2022, so the predictor
  should be legitimate — but "should be" is how the last three leaks got in.
  Confirm empirically that the 2022 seat file's `fed_swing` is the May 2022
  swing and not something later, and refuse to use the predictor if it cannot
  be established.

## What the criteria cannot see

- **One election, one state, conditional only.** This says nothing about the
  model's forecast skill, its statewide projection, or how it behaves in a close
  contest. Victoria 2022 was a Labor hold with a large majority.
- **Whether the probabilities are right for minor parties.** One Nation ran a
  negligible Victorian campaign in 2022 (0.28%), so the seats where this model
  is most doubted are exactly the ones 2022 cannot test.
- **Nothing about YouGov.** Their 17 seats are not a target and agreement with
  them is not a criterion.
