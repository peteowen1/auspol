# Pre-registration: does a major party's seat swing depend on the OTHER major's base?

Written 2026-08-25, **before** anything is fitted. Committed before running.

Follows [../reviews/sa-four-seats-diagnosed-2026-08-25.md](../reviews/sa-four-seats-diagnosed-2026-08-25.md):
in Hammond and Ngadjuri our One Nation projection is right (off by 0.3 and 3.6
points) and the seats are still lost, because we put **Labor third** when
reality put **the Coalition third**. The exclusion order decides the winner —
the Coalition excluded first sends **54.0%** to One Nation and One Nation wins;
Labor excluded first sends its preferences to the Coalition and it does not.

## The hypothesis

**Where one major starts strong and is collapsing, the other major holds up or
rises relative to its statewide swing.**

Measured already, and not re-derived here: in SA's Coalition-held seats Labor
**rose +0.6** while falling **−2.50** statewide.

## Why the predictor is the OTHER party's base, deliberately

The obvious specification — regress a party's seat swing on **its own** base —
is the one this session already flagged as unusable:
[../reviews/swing-shape-2026-08-25.md](../reviews/swing-shape-2026-08-25.md)
records that regressing a change on its own baseline produces a negative slope
from **measurement noise alone**, and that the −0.193 found there may be
entirely that artefact.

Using the **other** major's base has no such mechanical link to the dependent
variable. It is the cleaner test and it is the one the mechanism actually
predicts.

## The estimand

For each (district, party) observation where the party is ALP or LNP:

- `y` = seat swing minus statewide swing for that party
      (`(p_b − p_a) − (sw_b − sw_a)`)
- `x` = the **other** major's 2022 seat share minus its statewide share
      (`other_p_a − other_sw_a`)

**Criterion: the coefficient of `y` on `x`, clustered on cycle-pair.**

Positive means: the more the other major over-indexes in this seat, the better
this party does relative to its own statewide swing. That is the hypothesis.

12 clusters, ~11 df, so the bar is **2.20 SE**.

## Decision rule, fixed now

Conclude the effect is real **only if all three hold**:

1. Coefficient **>= 2.20 clustered SE**, positive.
2. **Sign consistency in at least 8 of 12** cycle-pairs.
3. Applying it **does not degrade** the pooled first-preference MAE on the
   2,878-observation corpus where uniform currently wins at 3.724. Uniform has
   now survived three alternatives; a fourth must not cost accuracy to buy a
   seat.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — it must not be SA alone.** Re-run excluding South Australia. If the
  coefficient loses its sign or falls below 1 SE, it is a South Australian fact
  and must be reported as one.
- **R2 — it must not be the own-base artefact wearing a disguise.** The two
  majors' bases are strongly negatively correlated within a seat, so the other
  major's base partly proxies for the party's own. **Control for the party's
  own base and report both.** If the effect does not survive, refuse — this is
  the same control that killed the proximity test and it is expected to bite.
- **R3 — no coefficient fitted on SA 2026 may be applied to Victoria.** That is
  the `sa_ratio` circularity in a new costume. Any coefficient carried forward
  must be estimated leave-one-out or on non-SA data.
- **R4 — fixing the exclusion order is not the criterion.** Whether Hammond and
  Ngadjuri flip is a *diagnostic*, reported after the fact. If the coefficient
  fails its bar, the seats flipping is not a reason to adopt: two seats cannot
  overrule 2,878 observations.
- **R5 — it must not break the majors to fix a minor party.** Report ALP and
  LNP seat accuracy separately before and after. A rule that elects One Nation
  by making the two-major contests worse is not an improvement.

## What this cannot see

- **It is first preferences only.** Whether the count then flips depends on the
  flow matrix, which is untouched here.
- **It cannot separate "Labor gains from the Coalition" from "both respond to a
  common local factor."** The correlation is what is measured; the direction of
  causation is not.
- **MacKillop and Narungga are not addressed.** They fail differently (−6.93 SD
  and a double under-statement respectively), so even a clean pass fixes at
  most 2 of the 4.

## Prediction, written before running

Expect a **positive coefficient clearing the bar** on the raw specification,
and **R2 to be the live threat** — the two majors' bases are close to
mirror images within a seat, so the own-base control may absorb most of it.
That is exactly how the proximity test died, and the same structure is present
here.

Expect criterion 3 to pass or be near-neutral: this adds a seat-level term
with mean zero by construction, so it should not move the pooled MAE much in
either direction.
