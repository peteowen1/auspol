# Pre-registration: the seat model's own uncertainty

Written 2026-08-22, **before anything is measured**. Committed before running.

**This is a tuning experiment**, which is the kind this repo has most often got
wrong. `CLAUDE.md` requires the grid, criterion and decision rule committed
before running, plus a refusal section naming in advance what would disqualify a
winner. All of that is below, and the grid does not move afterwards.

## What forecast mode established

`reviews/forecast-mode-2026-08-22.md` closed off the obvious explanation:

- the statewide two-party projection is **honestly sized** at a one-day horizon
  — claimed sd 2.42, realised RMSE 2.42, ratio 1.00;
- feeding that honest uncertainty into the seat model makes calibration
  **worse**, not better;
- so the over-confidence is in the **seat model**, which turns a 3-point
  statewide miss into confidently wrong seat calls rather than hedged ones.

Three knobs govern how sharply that conversion happens, and all three reach the
published model:

| knob | current | what it does |
|---|---|---|
| `seat_sd` (× `AUSPOL_SEAT_SD_MULT`) | measured, ×1 | per-seat idiosyncratic spread |
| `SHRINK` | 0.10 | per-draw shrink toward a coin toss in close seats |
| `SMOOTH` | 0.15 | how sharply the flow matrix resolves a contest |

## The grid, fixed now

- `AUSPOL_SEAT_SD_MULT` ∈ **{1.0, 1.25, 1.5, 2.0}**
- `AUSPOL_SHRINK` ∈ **{0.10, 0.20, 0.30}**
- `SMOOTH` ∈ **{0.15, 0.30}**

24 combinations. `1.0 / 0.10 / 0.15` is the current model and is the incumbent
to beat.

Search runs at `n_sims = 2000` for cost; the winner and the incumbent are
re-run at 5000 before anything is decided, and **a winner that does not survive
the re-run at 5000 is Monte Carlo noise, not a result.**

## Train and test, split before looking

**Tune on the six federal elections. Test once on Victoria 2018, Victoria 2022
and South Australia 2026.**

The three test elections are not looked at until the knobs are fixed. This
replaces leave-one-election-out because it is honest about the real risk here:
24 grid points against 6 training elections will overfit, and the defence is a
held-out set that was never available to the search rather than a cleverer
resampling of the same data.

Everything runs in **forecast mode** (`AUSPOL_FORECAST_MODE=1`). That is the
configuration a rival forecaster can be compared on, and the whole reason for
the previous experiment.

## What is measured

**Per-seat log score, clustered on the election.** Log score is a *proper*
scoring rule: it rewards being right and being honest about how sure you are,
and cannot be gamed by pushing everything toward 50%.

**The calibration slope is a diagnostic and a refusal, not the criterion.**
Tuning directly on the slope would be tuning on a non-proper measure — a model
that abandoned all discrimination could score well on it. AE Forecasts' 1.14 is
the bar to approach, not the thing to optimise.

Reported alongside: accuracy, the reliability table by band, and the Victoria
2026 seat medians.

## Decision rule, fixed now

- **Adopt the best grid point if, on the three held-out elections, its log score
  beats the incumbent's by more than 1 SE**, clustered on the election.
- **1 SE, not 2**, and the reason is written down now: with three held-out
  elections there are **two degrees of freedom**. A 2 SE bar on 2 df has almost
  no power to accept anything, which is the failure this repo has recorded twice
  — a criterion with no power to accept is not conservative, it is broken. The
  cost is a higher false-positive rate, which the refusals below exist to catch.
- **If the held-out improvement is under 1 SE, refuse.** The knobs stay where
  they are and the finding is that this parameterisation does not carry.
- **The held-out set is used ONCE.** If it refuses, that is the answer. A second
  grid chosen after seeing it is a new experiment on a contaminated test set.

## Refusals

- **C1 — the published forecast does not move as part of this experiment.**
  Adopting is a separate, deliberate act after the result is read.
- **C2 — log score and slope must improve TOGETHER.** If the log score improves
  while the slope moves further from 1.0, refuse: that means the gain came from
  discrimination rather than calibration, and calibration is the stated problem.
- **C3 — accuracy may not fall by more than 1.0 point** on the held-out set.
  `SHRINK` reassigns close seats at random, so it can buy calibration with
  accuracy; past some point that is a worse model wearing better numbers.
- **C4 — the directional side effect.** If One Nation's Victoria 2026 median
  moves by more than **2 seats**, stop and report rather than ship. Named in
  advance because widening seat uncertainty *mechanically* helps a party
  clustered just below the winning line, and One Nation is the party this repo
  has the most incentive to move.
- **C5 — no re-cutting the grid.** The 24 points above are the experiment.
  Widening `seat_sd` beyond 2.0 or adding a knob after seeing the surface is a
  new plan.
- **C6 — a winner at the grid edge is reported as such.** If the best point sits
  at `seat_sd × 2.0` or `SHRINK 0.30`, the honest reading is that the optimum is
  outside the grid and the result is a lower bound, not a solution.

## What this cannot see

- **Whether these three knobs are the right parameterisation at all.** They are
  the ones that exist. A model whose over-confidence is structural — in how the
  flow matrix resolves contests, or in treating a class as one competitor — will
  not be fixed by scaling any of them, and a refusal here is evidence for that
  reading.
- **Seat-level TCP**, which we still do not produce, and which is the high-N
  metric AE Forecasts can be compared on.
- **Whether AE Forecasts' 1.14 is reachable with our structure.** Approaching it
  is the goal; the plan does not assume it is attainable.
- **Anything about the One Nation allocation**, still fitted on one election.
