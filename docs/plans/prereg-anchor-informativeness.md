# Pre-registration: the day-0 anchor should be as strong as the prior is informative

Written 2026-08-19, **before** anything is measured or built. Committed before
running. Only the structure of `trend_anchor()` has been read; no outcome has
been looked at.

## The defect

`R/trend.R:79-87`:

```r
trend_anchor <- function(prep, prior_result) {
  if (is.na(prior_result)) {
    list(val = prep$obs$y[which.min(prep$obs$t)],
         sd  = sd_to_link(10, prep$p_ref, prep$scale))    # no prior: sd 10
  } else {
    list(val = to_link(prior_result, prep$scale)$z,
         sd  = sd_to_link(5,  prep$p_ref, prep$scale))    # prior: sd 5
  }
}
```

A party with a previous result is anchored to it at **sd 5 points**. A party
with none is anchored to its first poll at **sd 10**.

**That is backwards for a party whose previous result is near zero.** One Nation
took **0.28%** in Victoria in 2022 and polls around **23%** now. The model pins
its day-0 level to 0.28 with the *tighter* of the two anchors — treating a
result that carries almost no information about the party's current support as
if it were highly informative.

The strength of an anchor should reflect how much the previous result tells you
about the present level. For a party on 37% it tells you a great deal. For a
party on 0.28% it tells you almost nothing, because the range of things that can
happen next is enormous relative to the anchor.

## Why this is the right thing to fix now

Both live symptoms trace here:

- **Victoria** fits One Nation at **20.4** against a 90-day poll mean of
  **23.15**. The `L3` check flags it at 2.39, just inside its 2.5 bound.
- **NSW** fits it at **19.5** against **24.67** — a breach, and what keeps the
  scheduled job red.

And two external forecasts put One Nation's Victorian primary at **23.5–24**,
both above our own 95% upper bound of 22.2
([external-comparison](../reviews/external-comparison-2026-08-19.md)).

Note this is a *different* mechanism from the one diagnosed in
[nsw-onp-walk](nsw-onp-walk-2026-08-19.md). That found NSW's One Nation denied a
per-cycle walk for having only 8 polls. **Victoria's One Nation has 19 polls,
clears that floor, gets its own walk — and still lags by 2.39.** So the walk
floor cannot be the whole story, and the anchor is the remaining candidate.

## What is proposed

Make the anchor's sd depend on the previous result. A low previous share gets a
weaker anchor; a substantial one keeps today's behaviour.

The *form* is fixed here; only the breakpoint is estimated:

```
anchor_sd_points = ANCHOR_SD_HIGH                       if prior_result >= K
                 = ANCHOR_SD_LOW  (the no-prior value)  if prior_result <  K
```

with `ANCHOR_SD_HIGH = 5` and `ANCHOR_SD_LOW = 10` — **both unchanged from
today's code**, so the only new number is `K`.

Deliberately a step and not a smooth function: a smooth one has a shape to
choose as well as a scale, and with 33 cycles there is not enough to choose
both.

## How K is chosen — the rule, fixed now

Grid: **K ∈ {1, 2, 3, 5, 8} percent.** Chosen to span "the party barely existed"
(1) to "the party was a real minor force" (8), and stopping there because above
8 the rule would start reclassifying established minor parties.

Selected by **held-out first-preference MAE** over the 33-cycle complete-actuals
record used by `scripts/calibrate_poll_tracking.R`, leave-one-cycle-out.

## Acceptance criteria, fixed now

- **A1 — do no harm.** Total held-out FP MAE across all party-cycles must not
  worsen by more than **0.02**. This change is aimed at a handful of party-
  cycles; it must not pay for them with everyone else.
- **A2 — it must reach the target.** Among party-cycles where
  |prior − final-30-day poll mean| > 10 points, the mean |fitted − polls| gap
  must **shrink**. If the intended cases do not move, nothing else matters.
- **A3 — the live checks must not degrade.** No `L3`/`FL3`/`NL3` poll-tracking
  breach may appear in a cycle that currently passes.
- **A4 — arithmetic.** Fitted shares finite, inside (0, 100).

## Refusal section — what would make an apparent win unacceptable

- **R1 — indiscriminate inflation.** A party whose polls sit *near* its low
  prior must be essentially unmoved. Test directly: among party-cycles with
  prior < K and |prior − polls| < 5, the mean |fitted − polls| gap must change
  by less than 0.25. If a weaker anchor simply raises every low-prior party
  regardless of what the polls say, it is not tracking evidence, it is adding a
  constant.
- **R2 — the wrong direction on the majors.** ALP and LNP have priors far above
  any plausible K and must be **bit-for-bit unaffected**. If any major party's
  fitted endpoint moves at all, the change is reaching cases it was not meant
  to and the implementation is wrong.
- **R3 — K at the edge of the grid.** If the selected K is 1 or 8, refuse and
  re-open with a wider grid. An argmin at the boundary means the grid did not
  contain the answer.
- **R4 — a knife-edge win.** If the best K beats the runner-up by less than
  0.01 MAE, treat the curve as flat: report it and keep today's behaviour rather
  than adopting a number the data cannot distinguish.

## What the criteria cannot see

- **Whether One Nation's Victorian level ends up right.** The criterion is
  historical FP MAE. Nothing here can confirm the live 2026 number, and the
  external comparison is not evidence that our answer is wrong — two models
  disagreeing is two models disagreeing.
- **The seat count.** This changes a primary-vote trend. Whether it moves seats
  depends on the candidate-level model, which is a separate question and must
  not be used to judge this one.
- **Anything about independents.** Unrelated.
- **The NSW walk floor.** That defect is real and stays open; this is a second,
  independent mechanism, and fixing one does not close the other.
