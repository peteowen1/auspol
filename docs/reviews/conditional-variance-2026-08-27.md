# A1 refuted, and replaced: variance scales with LEVEL, not with candidate continuity

2026-08-27. Ticket A1 of `docs/plans/plan-candidate-level-model.md`, measured
before it was pre-registered. The hypothesis was wrong and the measurement
found the right version, so both are recorded.

## What A1 claimed, and why it is false

The persistence split showed same-candidate R² of 0.79 against 0.09 for a new
candidate, and I read that as "a new candidate is far more uncertain", proposing
a variance multiplier well above 1.

Measured, the multiplier is **0.87** — a new candidate has *lower* residual
spread:

| | n | residual sd | R² |
|---|--:|--:|--:|
| same person stands again | 538 | 5.99 | 0.756 |
| that person is gone | 5,049 | 5.20 | 0.293 |

**R² is not a measure of absolute uncertainty.** It is explained variance over
total variance, and a new candidate's prior vote is mostly zeros, so there is
almost nothing to explain. Low R² came from a flat predictor, not a noisy
outcome.

The control confirms the measure rather than the story: for ALP and LNP, where a
party always fields someone, the two groups read **7.87 and 7.80** — a
multiplier of essentially 1, which is what it must be.

**A1 as written does not ship, and would have made calibration worse** by
widening the group that is already narrower.

## What the same data does say

Residual spread tracks the **level of the share**, and today's model has one
number for every level.

| predicted band | n | residual sd |
|---|--:|--:|
| 0–1% | 804 | 4.22 |
| 1–3% | 1,096 | 2.76 |
| 3–7% | 1,857 | 4.26 |
| 7–15% | 1,806 | 4.92 |
| 15–25% | 795 | 6.04 |
| 25–40% | 1,241 | 5.93 |
| >40% | 1,416 | 6.42 |

Fitted over 9,015 seat-party observations across 17 pairs:

```
sd(share) = 2.01 + 7.04 * sqrt(p(1-p))
```

The slope coefficient is stable — jackknifed over the 17 pairs it ranges 6.82 to
7.29, SE 0.15.

**It is NOT binomial.** Normalised to the 3–7% band, `sqrt(p(1-p))` alone would
predict 9.77 at 50% against 6.42 observed. Real spread is much flatter than
sampling theory, which is expected: a seat's vote is not a random sample.

The 0–1% band breaking the pattern at 4.22 is the emergences — a party predicted
near zero that polls 30% produces a huge residual, and that is the tail salience
exists to catch, not something variance should absorb.

## What the model does today, and where it is wrong

`party_sd` 1.5 and `seat_sd` 3.5, which is **3.81 in quadrature, for every party
in every seat**:

| level | fitted | flat 3.81 | direction |
|---|--:|--:|---|
| 1% | 2.71 | 3.81 | **too wide** |
| 5% | 3.54 | 3.81 | too wide |
| 20% | 4.82 | 3.81 | too narrow |
| 50% | 5.53 | 3.81 | **too narrow** |

Both errors push the same way in a seat contest. Too wide at the bottom gives
no-hopers more chance than they have; too narrow at the top makes the leader
more certain than they are. **Too narrow at high shares is precisely
overconfidence about who wins**, which is what a calibration slope of 0.18–0.38
on every federal pair looks like.

That is a mechanism for the observed miscalibration, and it is the first one
this repo has had that is measured rather than assumed.

## Status

- A1 as originally written: **refuted**, not shipped.
- Replacement — level-dependent variance — is measured and **not yet tested on
  any harness**. It needs its own pre-registration, since a mechanism that
  explains a symptom is not evidence that fixing it helps.
- Nothing here changes the deviation-slope refusal, which stands.
