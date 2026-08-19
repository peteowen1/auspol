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

---

## BLOCKED, 2026-08-20: the data does not exist yet

Investigated before running anything. **The backtest cannot be built at all**,
for a reason narrower than the plan above assumed.

The plan assumed Victoria 2022 was testable because we hold its results. It is
not. The candidate model projects each seat's primaries by swinging them off
**that seat's first preferences at the previous election**
(`shares[, p] <- mat22[, p] + (state_mean[[p]] - a22[[p]])`). To predict
Victoria 2022 it needs **Victoria 2018 seat-level first preferences.**

What the repo actually holds:

| dataset | have it? |
|---|---|
| Victoria 2022 seat-level first preferences | yes — but this is the *input* to the live 2026 forecast, not a target |
| Victoria 2022 transfers | yes |
| SA 2026 first preferences / transfers / ONP shares | yes — no SA 2022 priors, so not testable either |
| **Victoria 2018 seat-level first preferences** | **no** |
| **Any NSW candidate or transfer data** | **no** |

So we hold exactly one election's seat-level first preferences, and it is the
one the live forecast swings off. **There is nothing to score.**

Searched and ruled out:

- `external/aus-polling-analyser/` — the anchor carries `booths-2018vic.txt`,
  archived adjustments and fundamentals for 2018vic, but **no seat-level first
  preferences**. Its `analysis/seats/` holds `2019nsw.txt`, `2022vic.txt`,
  `2023nsw.txt` (margins and predictors, not first preferences).
- The VEC's 2018 results pages are JavaScript-driven; the documented URL
  patterns 404, as
  [preference-data-acquisition.md](preference-data-acquisition.md) already
  recorded.

## What unblocks it, in preference order

1. **NSW 2019 + 2023 from the NSWEC.** Enables a genuine out-of-sample backtest
   — different state, different year, a change-of-government election rather
   than a landslide hold — and the seat files (`2019nsw.txt`, `2023nsw.txt`)
   are already present, so only the first preferences and transfers are
   missing. It also yields a **second transfer matrix**, which is the other
   thing this repo needs: `fm` currently rests on one election, and the
   flow-uncertainty question could not be answered for the same reason.
2. **Victoria 2018 from the VEC.** Cheaper in principle — one state, one
   election — but the site is JS-driven and the obvious URLs are already known
   to 404, so the effort is unbounded.

## What must NOT happen meanwhile

The seat-swing adjustment stays **out** of the candidate model until it can be
measured there. It helps the two-party model by 0.0371 MAE, but the two models
put the same predictors through different machinery, and this plan's own
decision rule requires a measured improvement. Shipping it unmeasured because
it helped a different model is precisely the reasoning this repo's discipline
exists to refuse.

The live gap is recorded and real: `seat_swing_adjustment()` reaches only the
two-party cross-check, so **four predictors worth a measured improvement do not
touch a single published number.** That is an argument for getting the data, not
for skipping the measurement.

---

## UNBLOCKED and REDESIGNED, 2026-08-20, before anything was measured

NSW 2019 and 2023 were acquired
([nsw-data-acquisition](../reviews/nsw-data-acquisition-2026-08-20.md)) and the
design above is replaced. **Nothing had been run under the old design** — it was
recorded as blocked and no arm was ever scored — so this is a redesign, not an
amendment after seeing a result.

The new design is strictly stronger on every axis the old one conceded:

| | old (Victoria 2022) | **new (NSW 2023)** |
|---|---|---|
| transfer matrix | from the election being predicted — **a leak** | from **2019**, before it |
| election type | landslide hold | **change of government** |
| state | same as the live forecast | **different** |
| coefficients | fitted on the scored election | fitted **excluding** it |

The prohibition on quoting absolute accuracy is **lifted**, because the leak
that motivated it is gone. Everything else — the decision rule, the metrics, and
refusals C1 to C5 — carries over unchanged.

### Inputs, all knowable before 25 March 2023

- `load_seats(2023, "nsw")` — margins from 2019, incumbency, region, and the
  four swing predictors.
- `nswec-2019-nsw-firstprefs.csv` — each seat's 2019 first preferences, which is
  what the model swings off.
- The flow matrix built from **`nsw2019` transfers only**. `nsw2023` rows must be
  filtered out and the filter asserted, not assumed.

### Truth

Each seat's actual 2023 winner, from `nswec-2023-nsw-firstprefs.csv` put through
the same exclusion, cross-checked against the incumbent recorded in the 2027
seat file. **If those two disagree for any seat, stop** — one of them is wrong
and scoring against either would be scoring against a mistake.

### Both arms of the statewide input, as the two-party calibration did

- **conditional** — hand the model the actual 2023 statewide primaries. Isolates
  the seat layer, which is the layer being changed.
- **forecast** — the projection the model would have made. The honest
  end-to-end claim.

Both reported; **the conditional arm is the one the decision rule uses**, because
the seat-swing adjustment is a seat-layer change and a statewide error common to
both arms would only add noise to the comparison.

### The two model arms

- **A** — the candidate model as published today.
- **B** — plus `seat_swing_adjustment()`, with coefficients **refitted on
  Victoria 2022 alone**, excluding NSW 2023. The shipped `SEAT_SWING_COEF` is
  fitted on all 180 seats of Victoria 2022 *and* NSW 2023 — its own
  documentation says those "use every seat, which is the right choice for a
  forecast and the wrong one for scoring it" — so using it here would be exactly
  the leak C2 refuses.

### One addition to the refusal list

- **C6 — the held-out coefficients must be reported alongside the shipped ones.**
  If refitting on Victoria alone moves a coefficient's sign, or changes one by
  more than half its value, the predictor is not stable across two elections and
  a gain measured with it is not evidence about the third. Report and refuse.
