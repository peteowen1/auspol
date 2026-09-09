# One Nation's concentration: the "unvalidated" number has now been validated, and it looks LOW

2026-09-09. Findings only — **nothing changed in the model**. A change to the
published Victorian forecast's One Nation concentration needs its own
pre-registration and Pete's decision; this document is the evidence for that
decision.

## Two corrections to what the repo believed

**1. SA 2026 cannot test the allocation out of sample, because it IS the
training data.** `scripts/backtest_candidate_sa.R`'s header says:

> "SA 2026 is the only completed election that can test that allocation out
> of sample, and it never has been."

`fit_seats_full.R:462-463` loads `ecsa-2026-sa-onp-shares.csv` — South
Australia 2026's *observed* per-seat One Nation result — and sorts it into
`sa_ratio`, the concentration profile quantile-mapped onto Victorian seats.
Testing that profile against SA 2026 would be scoring a fit on its own
training set. The header's claim should be struck.

**2. The concentration question IS answerable, on 49 observations rather
than one.** Not by re-testing SA, but by asking how minor-party seat-level
concentration behaves across the whole corpus.

## The question the 2026-08-21 review left open

`docs/reviews/onp-concentration-2026-08-21.md` framed the problem as a choice
between two ways of carrying a concentration across a level gap, and said
they "disagree by a factor of 4.4":

| assumption | implies at 22.9% |
|---|--:|
| hold the SD in points fixed | CV 0.110 |
| hold the CV fixed | CV 0.482 |
| SA 2026 actually delivered | 0.334 |

Written as a scaling law, SD-fixed means `CV ∝ level^-1` and CV-fixed means
`CV ∝ level^0`. So the question has an empirical answer: **what is the
exponent?**

## Method

For every (election, party) in `output/candidacies.csv`: the party's
statewide level, and the coefficient of variation of its per-seat share
across **every seat in that election** (absent = 0, since a concentration
profile has to describe the whole chamber).

**The denominator is the trap, and it bit this analysis first.** Computing
the level over only the seats a party CONTESTED put One Nation's qld2017
vote at 20.8% instead of its true 13.7% — it contested 61 of 93 seats. Every
number below uses all seats in the election as the denominator.

**Structural zeros are the second trap.** A party contesting 61 of 93 seats
has 32 forced zeros, which inflate its CV as a measure of *concentration*.
Pooling those with full-contest parties gives `CV ∝ level^-0.462`
(t = -7.9, n = 88) — but that exponent is mostly measuring how many seats a
party contests, not how concentrated it is where it stands.

## Result, restricted to parties contesting ≥ 90% of seats

n = 49 observations (ONP, OTH_RIGHT, GRN, OTH across 28 elections):

```
log(CV) = -0.3475 - 0.1279 * log(level)
          (0.1495)  (0.0722)     t = -1.77, p = 0.083, R2 = 0.063
```

**The level dependence largely disappears.** The exponent is -0.128, not
-1: concentration is approximately CONSTANT with level, which is the
review's CV-fixed branch. The residual scatter is wide (sd 0.229 in logs,
about ±26%), so this is "roughly constant around 0.45-0.50 with a lot of
spread", not a precise law.

| | CV |
|---|--:|
| fitted typical, full-contest minor at 22.5% | 0.474 |
| fitted typical at 21.0% (Victoria's forecast level) | **0.479** |
| SA 2026 One Nation, actual (47 of 47 seats) | **0.346** |
| what `fit_seats_full.R` currently uses (SA's shape) | **0.334** |

SA 2026 sits **1.4 residual sd BELOW** the fitted line. It is not an
outlier, but it is on the low side of normal — and the published Victorian
forecast inherits that low value wholesale.

## Why this is decision-relevant rather than academic

`fit_seats_full.R:499` calls `sa_ratio` "the single most load-bearing
unvalidated number here", and explains why: concentration decides how many
seats One Nation LEADS, and on South Australian evidence leading is most of
winning. A concentration set ~30% below the corpus-typical value at
Victoria's forecast level will, if the corpus is the better guide, **under-
state One Nation's Victorian seat count.**

The lever already exists: `AUSPOL_ONP_CV` rescales the ratio about 1 to hit
a stated CV, and was built for exactly this ("so the seat range can be
reported at both ends of that bound instead of at one unvalidated point").

## What this does NOT establish

- **It does not say 0.334 is wrong.** SA 2026 is a real election at almost
  exactly Victoria's forecast level, and one real observation at the right
  level may beat a noisy cross-party regression. The honest statement is
  that the corpus says "typical is ~0.48 and SA was low", not "SA was
  incorrect".
- **It does not measure seats.** Nothing here runs the forecast at a
  different CV. The seat consequence is unmeasured and would be the point of
  any pre-registered arm.
- **It pools party classes.** ONP, OTH_RIGHT, GRN and OTH are treated as one
  population of "minor parties contesting nearly everywhere". A One
  Nation-specific relationship cannot be fitted — there are 6 ONP
  observations in the whole corpus, which is the same thinness that killed
  the surge-slope arm the same day.
- **It says nothing about the ORDERING** — which seats are the concentrated
  ones. That is a separate mechanism (transposed federal ONP vote) with its
  own review, and this analysis is only about the SPREAD.

## Suggested next step, for Pete's decision

Run the published Victorian forecast at `AUSPOL_ONP_CV` = 0.334 (current),
0.40 and 0.48 (corpus-typical), and report One Nation's expected seat total
and the per-seat probabilities at each. That is a **reporting range**, not a
model change, and it directly answers "how much does this load-bearing
number move the answer" — which nobody currently knows.

If the range is narrow, the concern is closed. If a shift from 0.334 to 0.48
moves One Nation's expected Victorian seats materially, then the choice of
concentration is a headline assumption of the forecast and should be stated
as one rather than inherited silently from a single election.
