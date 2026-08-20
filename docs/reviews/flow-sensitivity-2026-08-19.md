# Preference flows move the two-party headline by 0.88 points and the seat forecast by nothing

Run 2026-08-19 (overnight) against
[../plans/prereg-flow-uncertainty.md](../plans/prereg-flow-uncertainty.md),
committed before the numbers were seen. `AUSPOL_FLOW_SHIFT` in
`scripts/fit_seats_full.R`.

**Step 1's stop condition is met: a ±1 sd flow shift moves One Nation's expected
seats by 0.01 against a 0.5 threshold. Stop, adopt nothing.**

But the *reason* is not "flows do not matter", and the difference matters.

## The measurement

Flows enter the simulation as constants — one number per party, identical in all
20,000 draws. One Nation's flow to Labor has fallen from **54.4% (federal 1998)
to the 25–35% range**; the value used for Victoria 2026 is **33.7%**, and the
one-step-ahead error of "mean of the last five" is **sd 3.65 points** over 19
observations.

Shifting every party's flow down by that one standard deviation
(GRN 83.5→79.8, ONP 33.7→30.1, OTH 48.9→45.2, UAP 38.3→34.7):

| | baseline | shifted | change |
|---|---:|---:|---:|
| **Labor two-party projection** | 47.95 | **47.07** | **−0.88** |
| ALP expected seats | 39.12 | 39.12 | +0.00 |
| LNP expected seats | 39.81 | 39.81 | +0.01 |
| GRN expected seats | 4.96 | 4.96 | −0.00 |
| ONP expected seats | 3.11 | 3.10 | −0.01 |
| ONP P(≥1 seat) | 0.896 | 0.897 | +0.001 |

A 0.88-point two-party move with **no seat movement at all** is not a plausible
pairing. On a 88-seat pendulum that shift would ordinarily be worth well over a
seat.

## Why: the seat model uses the projection's spread, not its level

`simulate_seat_contests()` applies `statewide_draws[s, ] - centre`, where
`centre <- colMeans(statewide_draws)` (`R/seat_sim.R`). Only each draw's
**deviation from the mean** reaches the seats.

The anchoring block in `fit_seats_full.R` forces the statewide draws' implied
two-party onto the projection by moving `d = target - implied` points from LNP to
ALP. A flow change moves `implied`, so it moves `d`, so it moves the **mean** of
the ALP and LNP columns — and the centring subtracts exactly that back out.
Measured directly: the shift moves the ALP and LNP means by **±1.69 points** and
the seat model cannot see any of it.

**This is deliberate, and documented in the function**: the per-seat shares
already carry the central forecast, so re-adding the statewide mean would
double-count it. The anchoring exists to give the statewide draws the
projection's *spread*, and it does that correctly — `sd 2.544` against the
projection's 2.546 in both arms.

## The consequence, which is a real finding

**The published seat forecast is invariant to the published two-party
projection's level.** The page shows 47.95 for Labor two-party and a median of
40 seats, and those two numbers do not respond to the same input in the same
way: an input that moves the first by 0.88 leaves the second where it was.

The seat forecast's centre comes from the per-seat primaries and the observed
transfer matrix `fm` (built from VEC counts, `build_flow_matrix()`), which is a
**different object from `fl`** and was untouched by this experiment. That is
where seat-level preference behaviour actually lives.

Whether this is right is not settled here. Two readings, both defensible:

- **Correct.** The candidate model computes its own two-party outcomes from
  primaries and observed transfers; the statewide projection is a separate,
  coarser estimate and should not override it.
- **A gap.** The projection carries information the seat model is discarding —
  fundamentals, poll-trend mixing, horizon weighting — and a forecast whose
  headline and whose seat count can disagree without either moving is under-
  constrained.

**Recorded as an open question, not fixed.** Changing it would move every
published seat number, and it needs its own pre-registration.

## Adoption: still blocked, as pre-committed

The plan blocked adoption regardless of the sizing, because there is no
out-of-sample test — the candidate-level seat model has never been backtested,
and the calibration we have (161 seats, slope 1.113) scores the **two-party**
model, which does not use flows. Nothing here changes that. Flow uncertainty
would in any case not widen the seat intervals under the current architecture,
for the reason above.

**W4 held.** Nothing about YouGov's 17 One Nation seats entered this.

## Two failures on the way, both now in `CLAUDE.md`

- The first diagnostic shifted `flow_of()` rather than `fl`. That reaches only
  the anchoring — the inert path above — so it could never have shown anything.
- That edit ran inside a **backgrounded command**, died on an `AssertionError`,
  and the two runs launched behind it used the **unmodified script**. The output
  was byte-identical to baseline and read as "flows do not matter": a false
  conclusion from an experiment that never ran, catchable only by checking
  whether the variable had reached the code. The diagnostic now prints what it
  applied, and that line is read before the result is.
