# Weighting by candidate count is blocked too, and the reason is a date

Written while starting the pre-registration for it. **No plan was written**,
because the application side has no usable input — measured before proposing to
build anything.

## The remedy

`reviews/m2-cell-thinning-2026-08-22.md` left two remedies for the finding that
44.5% of Victorian exclusion rounds have a class fielding more than one
candidate. `reviews/bucket-narrowing-infeasible-2026-08-22.md` eliminated the
first: no pollster reports the members of `OTH_RIGHT` separately, so narrower
classes cannot be given a statewide share.

The survivor was to **weight by candidate count inside the existing cell**:
estimate a rate per candidate rather than per class, then multiply back by how
many candidates the class fields in the seat being forecast. It needs no new
class, no new polling series, and costs no coverage.

Its difficulty was recorded in advance: estimating is easy because the transfers
already carry `to_n`; **applying** needs the number of candidates each class
will field in each Victorian seat in 2026.

## The measurement

The only available predictor is the seat's own previous count. Measured on the
federal corpus — seven elections, candidate-level first preferences, six
consecutive pairs:

| class | exact match | MAE from previous count | MAE assuming one candidate |
|---|---:|---:|---:|
| ALP | 94.6% | 0.05 | 0.03 |
| GRN | 96.3% | 0.04 | 0.02 |
| LNP | 81.0% | 0.20 | 0.12 |
| ONP | 50.9% | 0.49 | 0.12 |
| **OTH** | **33.1%** | **0.97** | **0.89** |
| **OTH_RIGHT** | **26.6%** | **1.27** | **1.11** |
| **IND** | **20.2%** | **1.06** | **0.59** |

Overall: 60.3% exact, MAE 0.56 — against **MAE 0.42 for assuming one candidate
always.**

**The predictor is worse than the assumption the model already makes**, and it
is worst precisely in the three buckets where the mechanism lives. That is not
a marginal call: for `IND` the lagged count nearly doubles the error.

The reason is visible in the same table. `ALP` and `GRN` field one candidate
almost always, so both predictors are trivially right and neither matters. The
buckets average 1.4 to 2.1 candidates with a maximum of 8, and which minor
parties bother to stand in a given division is close to noise from one election
to the next.

## So the remedy is not wrong, it is early

Nothing here says weighting by candidate count is a bad idea. It says the input
it needs does not exist **yet**.

**Nominations for the Victorian election close before polling day on 28 November
2026.** Once they do, the candidate count per class per seat is not a prediction
at all — it is a fact, known exactly, for every seat.

At that point the application side becomes free and only the estimation side
remains, which the transfers already support. The remedy is worth revisiting
**after nominations close and before the election**, and is worth nothing before
then.

## What the model assumes in the meantime, stated plainly

`simulate_seat_contests()` implicitly treats each class as fielding one
candidate per seat. Against the federal record that assumption carries an MAE of
**1.11 candidates for `OTH_RIGHT`** and 0.89 for `OTH` — it is not accurate, it
is merely *less inaccurate* than the alternative available today.

So this is a known, sized, unfixed approximation rather than an oversight, and
it is recorded here as one.

## Method note

Six consecutive federal pairs, using the AEC's candidate-level first-preference
files, which carry one row per candidate with a party name and code. Counts are
distinct `CandidateID` per division per class. Divisions appearing in only one
election of a pair are counted as zero in the other, which is right: a class
that stopped standing is a prediction error, not a missing value.

No fetcher, model or plan was modified. **Three remedies have now been closed by
measurement rather than by argument** — the multiplicity split on coverage,
bucket-narrowing on polling availability, and this one on predictor quality.
