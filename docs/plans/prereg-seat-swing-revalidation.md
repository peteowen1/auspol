# Pre-registration: re-validate the adopted seat-swing predictors on five elections

Written 2026-08-20, **before anything is refitted**. Committed before running.

## Why

`seat_swing_adjustment()` is **adopted and live** in `simulate_seats()`. It was
validated leave-one-election-out on **two** elections — Victoria 2022 and NSW
2023 — for a 0.0371 MAE gain.

Today's independent work showed what two elections can hide: a model that
improved by 1.46 SE on one election got **worse by 2.52 SE** on six. The lesson
recorded from it is *validate across the unit that varies*, and for seat models
that unit is the election. Two is not enough to have established anything, and
this component is in the published forecast.

## What changes

Three federal elections become available: **2019, 2022 and 2025**, each with a
"before" seat file and an "after" file recording the realised swing. Five
elections in total.

**`fed_swing` is unavailable federally** — it is empty in all four federal seat
files, which is correct, since there is no separate federal swing to measure at
a federal election. So:

- **The primary test uses the three predictors present everywhere**:
  `retirement`, `soph_cand`, `soph_party`, across all five elections.
- **`fed_swing` is reported separately** on the two state elections only, and no
  claim about it is made from this exercise. It is the strongest of the four
  (t = 8.5) and it is not being re-tested here; that is a stated gap, not a
  finding.

## What is measured

Exactly as the original: predict each seat's **deviation from its election's
statewide swing**, against a baseline of uniform swing (deviation zero).

- **Leave-one-election-out MAE**, the original's criterion.
- **Per-election gain**, so no single election can carry the result.
- **Coefficient stability**: each coefficient refitted with each election held
  out, reported with its own standard error.

## Decision rule, fixed now

- **Keep the adjustment as adopted** if leave-one-election-out MAE still beats
  uniform swing, and the gain is positive in at least **3 of the 5** elections.
- **Withdraw it from the published model** if the pooled held-out MAE is worse
  than uniform swing. A component that fails its own criterion on more data does
  not stay in because it passed on less.
- **Report as unresolved** if the pooled gain is positive but concentrated in
  one or two elections.

## Refusals

- **K1 — no dropping a predictor that fails.** All three go in together, as the
  original pre-registration required when it kept `soph_party` at t = 1.2.
  Selecting on significance after the fact is the thing that rule exists to
  stop.
- **K2 — signs must hold.** Retirement must hurt the incumbent, and a first-term
  member must gain, in the pooled fit. A sign flip on more data means the
  original finding was noise, and no MAE gain rescues it.
- **K3 — federal and state are not assumed interchangeable.** Report the gain
  separately for the three federal and two state elections. If the adjustment
  helps federally and hurts at state level, the state result governs, because
  the published forecast is a state election.
- **K4 — this settles C6 or it does not.** The seat-swing port into the
  candidate model was blocked because `soph_cand` moved 54% of its value when
  refitted without NSW — on a two-election sample where that is about 1.6 SE.
  With five elections, report whether that coefficient is stable **in standard
  errors**, and treat the C6 question as answered either way rather than
  deferred again.

## What this cannot see

Three of the five elections are federal, and federal seats behave differently
from state seats — different candidate quality effects, different retirement
dynamics. Pooling them is an assumption. Reporting the split is how that
assumption stays visible.
