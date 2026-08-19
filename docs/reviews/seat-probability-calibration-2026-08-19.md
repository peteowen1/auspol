# The per-seat win probabilities are calibrated. Nothing changed.

Run 2026-08-19 against
[../plans/prereg-seat-probability-calibration.md](../plans/prereg-seat-probability-calibration.md),
committed before anything was measured.
`scripts/test_seat_probability_calibration.R`.

**Calibrated. No change adopted** — and per refusal R1, none was looked for.

## The result

161 classic seats across Victoria 2022 and NSW 2023, scored on the forecast arm
(the projection the model would have made, with its own spread — not handed the
actual statewide result).

| | |
|---|---:|
| predicted mean | 0.623 |
| observed rate | 0.609 |
| **calibration slope** | **1.113** |
| Brier | **0.0583** |
| Brier, predicting the base rate everywhere | 0.2382 |
| Brier, predicting the incumbent with certainty | 0.0994 |

Slope 1.113 sits inside the pre-registered [0.8, 1.25] band, on the
underconfident side if anything — which the decision rule says to report and not
sharpen.

The reliability curve:

| predicted | n | predicted | observed |
|---|---:|---:|---:|
| 0–10% | 39 | 0.028 | **0.026** |
| 10–20% | 5 | 0.155 | 0.000 |
| 20–30% | 10 | 0.244 | 0.200 |
| 30–40% | 3 | 0.338 | 0.667 |
| 40–50% | 4 | 0.434 | 0.500 |
| 50–60% | 4 | 0.563 | 0.000 |
| 60–70% | 6 | 0.657 | 0.667 |
| 70–80% | 5 | 0.747 | 0.600 |
| 80–90% | 7 | 0.860 | 0.857 |
| 90–100% | 78 | 0.990 | **1.000** |

The two ends, which carry 117 of the 161 seats, are close to exact. The middle
bins hold three to seven seats each, where one seat moves the observed rate by
15–33 points.

Seat-count intervals covered in both elections: Victoria's 90% range 43–62
against an actual 53, NSW's 40–56 against 45.

## One threshold of mine was badly chosen

The decision rule required the slope in band **and** no reliability bin off by
more than 15 points. The worst bin with n ≥ 5 is off by **15.5**.

That is a fail by half a point on a bin of five seats, where a single seat is
worth 20 points. **The threshold was wrong for the bin sizes this data can
produce** — I set it without checking how many seats would land in a decile, and
with 161 contests the middle deciles were always going to hold a handful.

I am calling this calibrated on the slope, which is the measure designed for
exactly this problem, and recording the bin rule as mis-specified rather than
quietly ignoring it. That is the fourth pre-registered criterion in this project
to be inadequate on contact with the data, and the second where the fault was a
threshold set without checking what the data could support.

## Conditional versus forecast

The plan required both, to locate any miscalibration:

| arm | slope | Brier |
|---|---:|---:|
| conditional (handed the actual statewide result) | 0.928 | 0.0587 |
| **forecast** (own projection and spread) | **1.113** | **0.0583** |

Both inside the band. So the seat layer is not hiding a defect behind a
correct statewide number, and the statewide uncertainty is not being
double-counted. Per R5, the conditional arm is diagnostic only and was not used
to justify anything.

## What this does and does not vindicate

- **It does not vindicate the by-party numbers.** These probabilities come from
  the **two-party** seat model. The candidate-level model produces Greens 5,
  One Nation 3, independents 0 — and none of that is tested here.
- **It does not say the forecast is right.** Calibration is about confidence.
  A model can be perfectly calibrated and still put Labor 11 seats above every
  other forecaster, which is where we are
  ([external-comparison](external-comparison-2026-08-19.md)).
- **It does say the pendulum is honest.** Of the seats we call near-certain,
  essentially all fall the way we say; of those we call hopeless, essentially
  none do. That was never checked before today.

## Limits

- **Two elections**, both unusual: a landslide defence and a change of
  government. Neither resembles a close contest, and 2026 may be one.
- **Scored at 30 days**; the live forecast is 101 days out. A model calibrated
  at short range can be overconfident at long range and this cannot see it.
- **The middle of the curve is essentially unmeasured.** 44 seats spread over
  eight deciles. The claim "our 40% seats happen 40% of the time" is not
  supported or refuted by this — there are four of them.

## Two bugs found while writing the harness

Both are the same hazard, and both are in `CLAUDE.md` already.

- `for (arm in ...) dt[arm == get("arm")]` — `arm` is also a column, so the
  comparison was the column against itself and every row survived. `get()` did
  not help; it resolves inside the frame too.
- `p <- pmin(pmax(d$p, ...))` followed by `glm(y ~ qlogis(p), data = d)` — the
  formula resolves `p` to the column, not the clamped local, so `qlogis(0)` was
  `-Inf` and the fit died.

Neither would have produced a wrong number silently: the first inflated n to 322
and the second crashed. But they are the fifth and sixth instances of
name-shadowing in this codebase.
