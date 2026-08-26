# Pre-registration: variance that scales with the level of the share

2026-08-27, written before any harness has been run with it. Replaces ticket A1,
whose original form was refuted in
`docs/reviews/conditional-variance-2026-08-27.md`.

## The change

Today every party in every seat gets `party_sd` 1.5 and `seat_sd` 3.5 — **3.81
in quadrature, one number for every level.** Measured over 9,015 seat-party
observations across 17 election pairs:

```
sd(share) = 2.01 + 7.04 * sqrt(p(1-p))
```

Slope coefficient jackknifed over the 17 pairs ranges 6.82–7.29, SE 0.15, so the
form is estimated rather than chosen. The flat model is too wide below ~7% and
too narrow above ~15%, and too narrow at the top is overconfidence about who
wins — which is what calibration slopes of 0.18–0.38 on every federal pair look
like.

Wired as a per-cell sd in `simulate_seat_contests()`, replacing the scalar. The
existing constants are recovered exactly by setting the intercept to 3.81 and
the slope to 0, which is how the no-op is proven.

## Criteria

Both must hold, on all five harnesses:

1. **Calibration** — mean |slope − 1| across pairs improves by at least
   **0.419**.
2. **Brier** — does not worsen by more than **0.0089**.

Sized from the 15 pairs measured on 2026-08-27, clustered on **harness** (5
clusters, because WA's 7 pairs share one commission, one redistribution regime
and one flow matrix). Brier SE 0.0032, calibration SE 0.150; MDE = 2.80 × SE.

**Calibration is the primary here**, unlike the joint-slope retune where both
were equal. This change moves uncertainty, not point estimates, so a large
Brier gain would be surprising and a large calibration gain is the whole claim.

## Dry-run: verdicts fixed before running

| case | expected | what it tests |
|---|---|---|
| intercept 3.81, slope 0 | **byte-identical** to published output | the no-op; if it differs the wiring is wrong and nothing else means anything |
| a seat where LNP polls 60% | sd rises 3.81 → ~5.5, so its win probability FALLS | the change must reduce certainty in safe seats, not raise it |
| a candidate polling 1% | sd falls 3.81 → ~2.7, so its win probability FALLS | must reduce no-hoper chances too — both ends move the same way |
| Dai Le, Fowler 2022 (projected 1.8%, actual 29.5%) | gets **worse**, not better | a narrower band at 1.8% makes an emergence less reachable. If this improves, the wiring is not doing what it claims |

The fourth is the important one: this change should **hurt** the emergence cases
and help the ordinary ones. An arm that improves both is not this mechanism.

## Refusal — what disqualifies a winner

- **If Brier improves substantially while calibration does not.** That would mean
  the point estimates moved, and this change must not touch them.
- **If any party's Victoria 2026 median seat count moves by more than 3.** Stop
  and hand the decision to Pete.
- **If it helps by widening alone.** Report an arm with a flat sd raised to the
  fitted average (about 4.4) alongside; if that captures the gain, ship the
  simpler thing and say so. This is the direct analogue of the
  spread-versus-slope confound that the deviation-slope refusal turned on.
- **If the gain reverses on any single harness by more than the MDE.**
- **If it makes the emergence seats better.** See the dry-run — that would mean
  it is not doing what is claimed.

## What the criteria cannot see

- **Five clusters** carry every tolerance.
- The fit pools all classes. IND may need its own curve and this does not test
  that.
- The 0–1% band breaks the pattern (4.22 against a fitted 2.7) because it
  contains the emergences. This change makes those **worse** by construction,
  and that cost is accepted here on the grounds that salience is the intended
  fix for them — but salience is unshipped, so the cost is real and current.
- Nothing here is candidate-level. It is a property of the share, not the person.
